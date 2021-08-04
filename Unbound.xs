#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <unbound.h>    /* unbound API */
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>

#define UNUSED(x) (void)(x)

#define DEBUG 0

#ifdef MULTIPLICITY
#define NEED_THX 1
#else
#define NEED_THX 0
#endif

#define _DEBUG(str, ...) if (DEBUG) fprintf(stderr, str "\n", ##__VA_ARGS__);

typedef struct {
    pid_t pid;
    struct ub_ctx* ub_ctx;
    HV* queries;
    unsigned refcount;
} DNS__Unbound__Context;

typedef struct {
#if NEED_THX
    tTHX my_aTHX;
#endif

    pid_t pid;

    DNS__Unbound__Context* ctx;

    int id;

    SV* callback;
} dub_query_ctx_t;

// ----------------------------------------------------------------------

#define _increment_dub_ctx_refcount(ctx) ctx->refcount++;

static void _decrement_dub_ctx_refcount (pTHX_ DNS__Unbound__Context* dub_ctx) {
    if (!--dub_ctx->refcount) {
        _DEBUG("Freeing DNS__Unbound__Context");

        if (getpid() == dub_ctx->pid && PL_dirty) {
            warn("Freeing DNS::Unbound context at global destruction; memory leak likely!");
        }

        // Workaround for https://github.com/NLnetLabs/unbound/issues/39:
        ub_ctx_debugout(dub_ctx->ub_ctx, stderr);

        ub_ctx_delete(dub_ctx->ub_ctx);
        dub_ctx->ub_ctx = NULL;

        SvREFCNT_dec((SV*) dub_ctx->queries);

        Safefree(dub_ctx);
    }
}

#define _QueryContext_to_query_ctx(qc_sv) ( (void *) SvUV( SvRV(qc_sv) ) )

// ----------------------------------------------------------------------

#define _query_id_str(async_id) form("%d", async_id)

static dub_query_ctx_t* _store_query (pTHX_ DNS__Unbound__Context* ctx, dub_query_ctx_t* query_ctx, int async_id, SV* callback) {

    *query_ctx = (dub_query_ctx_t) {
#if NEED_THX
        .my_aTHX = aTHX,
#endif
        .pid = getpid(),
        .ctx = ctx,
        .id  = async_id,
        .callback = newSVsv(callback),
    };

    _increment_dub_ctx_refcount(ctx);

    const char* id_str = _query_id_str(async_id);

    SV* val = sv_setref_uv(newSV(0), "DNS::Unbound::QueryContext", PTR2UV(query_ctx));
    hv_store(ctx->queries, id_str, strlen(id_str), val, 0);

    return query_ctx;
}

static dub_query_ctx_t* _fetch_query (pTHX_ DNS__Unbound__Context* ctx, int async_id) {
    _DEBUG("%s %p %d", __func__, ctx, async_id);
    const char* id_str = _query_id_str(async_id);

    SV** entry = hv_fetch(ctx->queries, id_str, strlen(id_str), 0);

    // Sanity-check:
    if (!entry || !*entry) croak("no query with ID %s found?!?", id_str);

    _DEBUG("end %s %p %d", __func__, ctx, async_id);

    return (void *) _QueryContext_to_query_ctx(*entry);
}

static SV* _unstore_query (pTHX_ DNS__Unbound__Context* ctx, int async_id) {
    _DEBUG("%s %p %d", __func__, ctx, async_id);
    dub_query_ctx_t* query_ctx = _fetch_query(aTHX_ ctx, async_id);

    SV* callback = sv_2mortal(query_ctx->callback);

    const char* id_str = _query_id_str(async_id);
    hv_delete(ctx->queries, id_str, strlen(id_str), 0);

    _decrement_dub_ctx_refcount(aTHX_ ctx);

    _DEBUG("end %s %p", __func__, ctx);

    return callback;
}

// ----------------------------------------------------------------------

SV* _ub_result_to_svhv_and_free (struct ub_result* result) {

    AV *data = newAV();
    unsigned datasize = 0;

    if (result->data != NULL) {
        while (result->data[datasize] != NULL) {
            datasize++;
        }

        if (datasize) {
            av_extend(data, datasize - 1);

            for (unsigned i=0; i<datasize; i++) {
                av_store(data, i, newSVpvn(result->data[i], result->len[i]));
            }
        }
    }

    HV * rh = newHV();

    hv_stores(rh, "qname", newSVpv(result->qname, 0));

    hv_stores(rh, "qtype", newSViv(result->qtype));

    hv_stores(rh, "qclass", newSViv(result->qclass));

    hv_stores(rh, "data", newRV_noinc((SV *)data));

    hv_stores(rh, "canonname", newSVpv(result->canonname, 0));

    hv_stores(rh, "rcode", newSViv(result->rcode));

    /* Ideally these could use boolSV(), but the efficiency gains
       probably don’t justify the API change. libunbound(3) documents
       these as ints, not bools, so we should preserve that. */
    hv_stores(rh, "havedata",   newSViv(result->havedata));
    hv_stores(rh, "nxdomain",   newSViv(result->nxdomain));
    hv_stores(rh, "secure",     newSViv(result->secure));
    hv_stores(rh, "bogus",      newSViv(result->bogus));

    hv_stores(rh, "why_bogus",
#if HAS_WHY_BOGUS
        newSVpv(result->why_bogus, 0)
#else
        &PL_sv_undef
#endif
    );

    hv_stores(rh, "ttl",
#if HAS_TTL
        newSViv(result->ttl)
#else
        &PL_sv_undef
#endif
    );

    hv_stores(rh, "answer_packet", newSVpvn(result->answer_packet, result->answer_len));

    ub_resolve_free(result);

    return newRV_noinc( (SV *)rh );
}

void _async_resolve_callback(void* mydata, int err, struct ub_result* result) {
    _DEBUG("RESOLVE CALLBACK (mydata=%p)\n", mydata);

    dub_query_ctx_t *query_ctx = mydata;
    _DEBUG("RESOLVE CALLBACK 2 (ID=%d)\n", query_ctx->id);

#if NEED_THX
    pTHX = query_ctx->my_aTHX;
    _DEBUG("RESOLVE CALLBACK 3");
#endif

    SV* result_sv;
    _DEBUG("err: %d\n", err);

    if (err) {
        result_sv = newSViv(err);
    }
    else {
        result_sv = _ub_result_to_svhv_and_free(result);
    }

    SV* callback = _unstore_query(aTHX_ query_ctx->ctx, query_ctx->id );

    // --------------------------------------------------

    dSP;
    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 1);
    mPUSHs(result_sv);
    //mPUSHs(newSVuv(42));
    PUTBACK;

    // Nothing should croak here:
    call_sv(callback, G_VOID | G_DISCARD);
_DEBUG("after callback");

    FREETMPS;
    LEAVE;

    return;
}

// ----------------------------------------------------------------------

MODULE = DNS::Unbound           PACKAGE = DNS::Unbound

PROTOTYPES: DISABLE

const char*
_get_fd_mode_for_fdopen(int fd)
    CODE:
        int flags = fcntl( fd, F_GETFL );

        if ( flags == -1 ) {
            SETERRNO( errno, 0 );
            RETVAL = "";
        }
        else {
            RETVAL = (flags & O_APPEND) ? "a" : "w";
        }
    OUTPUT:
        RETVAL

const char *
_ub_strerror( int err )
    CODE:
        RETVAL = ub_strerror(err);
    OUTPUT:
        RETVAL

#if HAS_UB_VERSION
SV*
unbound_version(...)
    CODE:
        UNUSED(items);
        RETVAL = newSVpv( ub_version(), 0 );

    OUTPUT:
        RETVAL

#endif

# ----------------------------------------------------------------------

MODULE = DNS::Unbound           PACKAGE = DNS::Unbound::Context

PROTOTYPES: DISABLE

int
_ub_ctx_set_option( DNS__Unbound__Context* ctx, const char* opt, SV* val_sv)
    CODE:
        char *val = SvPVbyte_nolen(val_sv);
        RETVAL = ub_ctx_set_option(ctx->ub_ctx, opt, val);
    OUTPUT:
        RETVAL

void
_ub_ctx_debuglevel( DNS__Unbound__Context* ctx, int d )
    CODE:
        ub_ctx_debuglevel(ctx->ub_ctx, d);

void
_ub_ctx_debugout( DNS__Unbound__Context* ctx, int fd, SV *mode_sv )
    CODE:
        char *mode = SvPVbyte_nolen(mode_sv);
        FILE *fstream;

        // Since libunbound does equality checks against stderr,
        // let’s ensure we use that same pointer.
        if (fd == fileno(stderr)) {
            fstream = stderr;
        }
        else if (fd == fileno(stdout)) {
            fstream = stdout;
        }
        else {

            // Linux doesn’t care, but MacOS will segfault if you
            // setvbuf() on an append stream opened on a non-append fd.
            fstream = fdopen( fd, mode );

            if (fstream == NULL) {
                fprintf(stderr, "fdopen failed!!\n");
            }

            setvbuf(fstream, NULL, _IONBF, 0);
        }

        ub_ctx_debugout( ctx->ub_ctx, fstream );



SV*
_ub_ctx_get_option( DNS__Unbound__Context* ctx, SV* opt)
    CODE:
        char *str;

        char *opt_str = SvPVbyte_nolen(opt);

        int fate = ub_ctx_get_option(ctx->ub_ctx, opt_str, &str);

        if (fate) {

            // On failure, return a plain SV that gives the error.
            RETVAL = newSViv(fate);
        }
        else {
            SV *val = newSVpv(str, 0);

            // On success, return a reference to an SV that gives the value.
            RETVAL = newRV_noinc(val);
        }

        free(str);
    OUTPUT:
        RETVAL

int
_ub_ctx_add_ta( DNS__Unbound__Context* ctx, SV *ta )
    CODE:
        char *ta_str = SvPVbyte_nolen(ta);
        RETVAL = ub_ctx_add_ta( ctx->ub_ctx, ta_str );
    OUTPUT:
        RETVAL

#if HAS_UB_CTX_ADD_TA_AUTR
int
_ub_ctx_add_ta_autr( DNS__Unbound__Context* ctx, SV *fname )
    CODE:
        char *fname_str = SvPVbyte_nolen(fname);
        RETVAL = ub_ctx_add_ta_autr( ctx->ub_ctx, fname_str );
    OUTPUT:
        RETVAL

#endif

int
_ub_ctx_resolvconf( DNS__Unbound__Context* ctx, SV *fname_sv )
    CODE:
        char *fname = SvOK(fname_sv) ? SvPVbyte_nolen(fname_sv) : NULL;

        RETVAL = ub_ctx_resolvconf( ctx->ub_ctx, fname );
    OUTPUT:
        RETVAL

int
_ub_ctx_hosts( DNS__Unbound__Context* ctx, SV *fname_sv )
    CODE:
        char *fname = SvOK(fname_sv) ? SvPVbyte_nolen(fname_sv) : NULL;

        RETVAL = ub_ctx_hosts( ctx->ub_ctx, fname );
    OUTPUT:
        RETVAL

int
_ub_ctx_add_ta_file( DNS__Unbound__Context* ctx, SV *fname )
    CODE:
        char *fname_str = SvPVbyte_nolen(fname);
        RETVAL = ub_ctx_add_ta_file( ctx->ub_ctx, fname_str );
    OUTPUT:
        RETVAL

int
_ub_ctx_trustedkeys( DNS__Unbound__Context* ctx, SV *fname )
    CODE:
        char *fname_str = SvPVbyte_nolen(fname);
        RETVAL = ub_ctx_trustedkeys( ctx->ub_ctx, fname_str );
    OUTPUT:
        RETVAL

int
_ub_ctx_async( DNS__Unbound__Context* ctx, int dothread )
    CODE:
        RETVAL = ub_ctx_async( ctx->ub_ctx, dothread );
    OUTPUT:
        RETVAL

int
_ub_poll( DNS__Unbound__Context* ctx )
    CODE:
        RETVAL = ub_poll(ctx->ub_ctx);
    OUTPUT:
        RETVAL

int
_ub_wait( DNS__Unbound__Context* ctx )
    CODE:
        RETVAL = ub_wait(ctx->ub_ctx);
    OUTPUT:
        RETVAL

int
_ub_process( DNS__Unbound__Context* ctx )
    CODE:

        // Never ub_ctx_delete(ub_ctx) while using ub_ctx:
        _increment_dub_ctx_refcount(ctx);

        RETVAL = ub_process(ctx->ub_ctx);

        _decrement_dub_ctx_refcount(aTHX_ ctx);

    OUTPUT:
        RETVAL

unsigned
_count_pending_queries ( DNS__Unbound__Context* ctx )
    CODE:
        RETVAL = hv_iterinit(ctx->queries);

    OUTPUT:
        RETVAL

#if HAS_UB_CANCEL
int
_ub_cancel( DNS__Unbound__Context* ctx, int async_id )
    CODE:
        int result = ub_cancel(ctx->ub_ctx, async_id);

        if (!result) {
            _unstore_query(aTHX_ ctx, async_id);
        }

        RETVAL = result;
    OUTPUT:
        RETVAL

#endif

int
_ub_fd( DNS__Unbound__Context* ctx )
    CODE:
        RETVAL = ub_fd(ctx->ub_ctx);
    OUTPUT:
        RETVAL

SV*
_resolve_async( DNS__Unbound__Context* ctx, SV *name_sv, int type, int class, SV *callback )
    CODE:
        char *name = SvPVbyte_nolen(name_sv);

        int async_id = 0;

        dub_query_ctx_t* query_ctx;
        Newx(query_ctx, 1, dub_query_ctx_t);

        int reserr = ub_resolve_async(
            ctx->ub_ctx,
            name, type, class,
            (void *) query_ctx, _async_resolve_callback, &async_id
        );

        AV *ret = newAV();
        av_extend(ret, 1);  // 2 elems - 1
        av_store( ret, 0, newSViv(reserr) );
        av_store( ret, 1, newSViv(async_id) );

        if (reserr) {
            Safefree(query_ctx);
        }
        else {
            _store_query(aTHX_ ctx, query_ctx, async_id, callback);
            _DEBUG("New query ID: %d", async_id);
        }

        RETVAL = newRV_noinc((SV *)ret);
    OUTPUT:
        RETVAL

SV*
_resolve( DNS__Unbound__Context* ctx, SV *name, int type, int class = 1 )
    CODE:
        struct ub_result* result;
        int retval;

        retval = ub_resolve(ctx->ub_ctx, SvPVbyte_nolen(name), type, class, &result);

        if (retval != 0) {
            RETVAL = newSViv(retval);
        }
        else {
            RETVAL = _ub_result_to_svhv_and_free(result);
        }

    OUTPUT:
        RETVAL

DNS__Unbound__Context*
create()
    CODE:
        struct ub_ctx* my_ctx = ub_ctx_create();

        if (!my_ctx) {
            croak("Failed to create Unbound context!");
        }

        DNS__Unbound__Context* dub_ctx;
        Newx(dub_ctx, 1, DNS__Unbound__Context);

        *dub_ctx = (DNS__Unbound__Context) {
            .pid = getpid(),
            .ub_ctx = my_ctx,
            .queries = newHV(),
            .refcount = 1,
        };

        RETVAL = dub_ctx;
    OUTPUT:
        RETVAL

void
DESTROY (DNS__Unbound__Context* dub_ctx)
    CODE:
#ifdef PL_phase
        _DEBUG("DESTROY context; time=%d\n", PL_phase);
#else
        _DEBUG("DESTROY context; destruct? %d\n", PL_dirty);
#endif

        _decrement_dub_ctx_refcount(aTHX_ dub_ctx);

# ----------------------------------------------------------------------

MODULE = DNS::Unbound   PACKAGE = DNS::Unbound::QueryContext

void
DESTROY (SV* self_sv)
    CODE:
        _DEBUG("%s", __func__);

        dub_query_ctx_t* query_ctx = _QueryContext_to_query_ctx(self_sv);

        if (getpid() == query_ctx->pid && PL_dirty) {
            warn("Freeing %" SVf " at global destruction; memory leak likely!", self_sv);
        }

        Safefree(query_ctx);
