#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <unbound.h>    /* unbound API */

/*
       int ub_resolve_async(struct ub_ctx* ctx, char* name,
                        int rrtype, int rrclass, void* mydata,
                        ub_callback_type callback, int* async_id);

              void my_callback_function(void* my_arg, int err,
                                struct ub_result* result);
*/

struct async_result {
    int error;
    struct ub_result* result;
};

struct resrej {
    CV* res;
    CV* rej;
};

SV * _ub_result_to_svhv (struct ub_result* result) {
    SV *val;

    AV *data = newAV();
    unsigned int i = 0;

    if (result->data != NULL) {
        while (result->data[i] != NULL) {
            val = newSVpvn(result->data[i], result->len[i]);
            av_push(data, val);
            i++;
        }
    }

    HV * rh = newHV();

    val = newSVpv(result->qname, 0);
    hv_stores(rh, "qname", val);

    val = newSViv(result->qtype);
    hv_stores(rh, "qtype", val);

    val = newSViv(result->qclass);
    hv_stores(rh, "qclass", val);

    hv_stores(rh, "data", newRV_inc((SV *)data));

    val = newSVpv(result->canonname, 0);
    hv_stores(rh, "canonname", val);

    val = newSViv(result->rcode);
    hv_stores(rh, "rcode", val);

    val = newSViv(result->havedata);
    hv_stores(rh, "havedata", val);

    val = newSViv(result->nxdomain);
    hv_stores(rh, "nxdomain", val);

    val = newSViv(result->secure);
    hv_stores(rh, "secure", val);

    val = newSViv(result->bogus);
    hv_stores(rh, "bogus", val);

    val = newSVpv(result->why_bogus, 0);
    hv_stores(rh, "why_bogus", val);

    val = newSViv(result->ttl);
    hv_stores(rh, "ttl", val);

    ub_resolve_free(result);

    return (SV *)rh;
}

void _call_with_argument( CV* cb, SV* arg ) {
    // --- Almost all copy-paste from “perlcall” … blegh!
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 1);

    PUSHs( sv_2mortal(arg) );
    PUTBACK;

    call_sv(cb, G_SCALAR);

    FREETMPS;
    LEAVE;
}

void _async_resolve_callback2(void* mydata, int err, struct ub_result* result) {
    //struct resrej* promise = (struct resrej *) mydata;
fprintf( stderr, "obj pointer in callback: %llu\n", mydata);
//    char *readyptr = (char *) mydata;
//fprintf(stderr, "status now: [%s]\n", readyptr);

//fprintf(stderr, "callback\n");

    SV *result_sv = (SV *) mydata;

    if (err) {
fprintf(stderr, "failure\n");
        //_call_with_argument( promise->rej, newSViv(err) );
//        readyptr[0] = '2';
    }
    else {
        SV * svres = _ub_result_to_svhv(result);

        SvUPGRADE( result_sv, SVt_RV );
        SvRV_set( result_sv, svres );
        SvROK_on( result_sv );

fprintf(stderr, "success\n");
//        readyptr[0] = '1';
//sv_dump((SV *)promise->res);

        //_call_with_argument( promise->res, svres );
//fprintf(stderr, "after success callback\n");
    }

    //Safefree(promise);
    //free(promise);

    return;
}

/*
void _async_resolve_callback2old(void* mydata, int err, struct ub_result* result) {
fprintf( stderr, "obj pointer in callback: %llu\n", mydata);

fprintf( stderr, ">>>>>>> callback2\n" );
    //HV* obj = (HV *) mydata;
    struct resrej* promise = (struct resrej *) mydata;


//fprintf(stderr, "callback\n");

    if (err) {
fprintf( stderr, ">>>>>>> reject\n" );
//sv_dump( hv_fetchs(obj, "rej", 0) );
        //CV *cr = (CV *) hv_fetchs(obj, "rej", 0);
        //if (!cr) croak("No “rej”!");

//fprintf(stderr, "failure\n");
        //_call_with_argument( cr, newSViv(err) );
    }
    else {
fprintf( stderr, ">>>>>>> resolve\n" );
//sv_dump( hv_fetchs(obj, "res", 0) );
        //CV *cr = (CV *) hv_fetchs(obj, "res", 0);
        CV *cr = promise->res;
        if (!cr) croak("No “res”!");

        SV * svresult = _ub_result_to_svhv(result);
//fprintf(stderr, "success\n");
//sv_dump((SV *)promise->res);

        _call_with_argument( cr, svresult );
//fprintf(stderr, "after success callback\n");
    }

    return;
}
*/

MODULE = DNS::Unbound           PACKAGE = DNS::Unbound

PROTOTYPES: DISABLE

struct ub_ctx*
_create_context()
    CODE:
        struct ub_ctx* my_ctx = ub_ctx_create();

        if (!my_ctx) {
            croak("Failed to create Unbound context!");
        }

        RETVAL = my_ctx;
    OUTPUT:
        RETVAL

int
_ub_ctx_set_option( struct ub_ctx *ctx, const char* opt, const char* val)
    CODE:
        RETVAL = ub_ctx_set_option(ctx, opt, val);
    OUTPUT:
        RETVAL

SV *
_ub_ctx_get_option( struct ub_ctx *ctx, const char* opt)
    CODE:
        char *str;

        int fate = ub_ctx_get_option(ctx, opt, &str);

        if (fate) {

            // On failure, return a plain SV that gives the error.
            RETVAL = newSViv(fate);
        }
        else {
            SV *val = newSVpv(str, 0);

            // On success, return a reference to an SV that gives the value.
            RETVAL = newRV_inc(val);
        }

        free(str);
    OUTPUT:
        RETVAL

const char *
_ub_strerror( int err )
    CODE:
        RETVAL = ub_strerror(err);
    OUTPUT:
        RETVAL

int
_ub_ctx_async( struct ub_ctx *ctx, int dothread )
    CODE:
        RETVAL = ub_ctx_async( ctx, dothread );
    OUTPUT:
        RETVAL

int
_ub_poll( struct ub_ctx *ctx )
    CODE:
        RETVAL = ub_poll(ctx);
    OUTPUT:
        RETVAL

int
_ub_wait( struct ub_ctx *ctx )
    CODE:
        RETVAL = ub_wait(ctx);
    OUTPUT:
        RETVAL

int
_ub_process( struct ub_ctx *ctx )
    CODE:
        RETVAL = ub_process(ctx);
    OUTPUT:
        RETVAL

int
_ub_cancel( struct ub_ctx *ctx, int async_id )
    CODE:
        fprintf(stderr, "xxxxxxxxxxxxxxxxx canceling in XS: %d\n", async_id);
        RETVAL = ub_cancel(ctx, async_id);
    OUTPUT:
        RETVAL

int
_ub_fd( struct ub_ctx *ctx )
    CODE:
        RETVAL = ub_fd(ctx);
    OUTPUT:
        RETVAL

SV *
_resolve_async2( struct ub_ctx *ctx, const char *name, int type, int class, SV *result )
    CODE:
        int async_id = 0;

        //printf("obj in XS\n");
        //sv_dump(obj);

        //fprintf(stderr, "obj pointer in resolve: %llu\n", (void *) readyptr);

        //fprintf(stderr, "status now: [%s]\n", readyptr);

        //HV *state = (HV *) SvRV( (SV *) obj );
        //void *state = SvPV_nolen( (SV *) SvRV( obj ) );

        int reserr = ub_resolve_async(
            ctx,
            name, type, class,
            //(void *) promise, _async_resolve_callback, NULL
            (void *) result, _async_resolve_callback2, &async_id

            //(void *) &promise, _async_resolve_callback, &async_id
            //NULL, _async_resolve_callback, NULL
            //NULL, _async_resolve_callback, &async_id
        );

        AV *ret = newAV();
        av_push( ret, newSViv(reserr) );
        av_push( ret, newSViv(async_id) );

        RETVAL = newRV_inc((SV *)ret);
    OUTPUT:
        RETVAL

SV *
_resolve_async( struct ub_ctx *ctx, const char *name, int type, int class, CV *res_cv, CV *rej_cv)
    CODE:
        int async_id = 0;
//fprintf(stderr, "name: %s\n", name);
//sv_dump(res_cv);
//sv_dump(rej_cv);

        //struct resrej* promise = malloc( sizeof(struct resrej) );
        struct resrej* promise = NULL;
        Newx( promise, 1, struct resrej );

        //malloc(

        promise->res = res_cv;
        promise->rej = rej_cv;

        /*
        int reserr = ub_resolve_async(
            ctx,
            name, type, class,
            //(void *) promise, _async_resolve_callback, NULL
            //(void *) promise, _async_resolve_callback, &async_id

            //(void *) &promise, _async_resolve_callback, &async_id
            //NULL, _async_resolve_callback, NULL
            //NULL, _async_resolve_callback, &async_id
        );

        AV *ret = newAV();
        av_push( ret, newSViv(reserr) );
        av_push( ret, newSViv(async_id) );

        RETVAL = newRV_inc((SV *)ret);
        */
    OUTPUT:
        RETVAL

SV *
_resolve( struct ub_ctx *ctx, SV *name, int type, int class = 1 )
    CODE:
        struct ub_result* result;
        int retval;

        retval = ub_resolve(ctx, SvPV_nolen(name), type, class, &result);

        if (retval != 0) {
            RETVAL = newSViv(retval);
        }
        else {
            RETVAL = _ub_result_to_svhv(result);
        }

    OUTPUT:
        RETVAL

BOOT:
    HV *stash = gv_stashpvn("DNS::Unbound", 12, FALSE);
    newCONSTSUB(stash, "unbound_version", newSVpv( ub_version(), 0 ));

void
_destroy_context( struct ub_ctx *ctx )
    CODE:
        ub_ctx_delete(ctx);
