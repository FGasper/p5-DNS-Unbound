#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <unbound.h>    /* unbound API */

static SV * _my_err( const char *class, AV *args ) {
    HV *pkg = gv_stashpv(class, GV_ADD);

    return sv_bless( newRV_inc((SV *)args), pkg );
}

MODULE = DNS::Unbound           PACKAGE = DNS::Unbound

PROTOTYPES: DISABLE

TYPEMAP: <<HERE

TYPEMAP
struct ub_ctx*  T_PTROBJ

HERE

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

SV *
_ub_strerror( int err )
    CODE:
        RETVAL = ub_strerror(err);
    OUTPUT:
        RETVAL

SV *
_resolve( struct ub_ctx *ctx, SV *name, int type, int class = 1 )
    CODE:
        struct ub_result* result;
        int retval;

        retval = ub_resolve(ctx, SvPV_nolen(name), type, class, &result);

        if (retval != 0) {
            RETVAL = newSVnv(retval);
        }
        else {
            AV *data = newAV();
            unsigned int i = 0;
            while (result->data[i] != NULL) {
                av_push(data, newSVpvn(result->data[i], result->len[i]));
                i++;
            }

            HV * rh = newHV();
            hv_store(rh, "qname", 5, newSVpv(result->qname, 0), 0);
            hv_store(rh, "qtype", 5, newSVnv(result->qtype), 0);
            hv_store(rh, "qclass", 6, newSVnv(result->qtype), 0);
            hv_store(rh, "data", 4, newRV_inc((SV *)data), 0);
            hv_store(rh, "canonname", 9, newSVpv(result->canonname, 0), 0);
            hv_store(rh, "rcode", 5, newSVnv(result->rcode), 0);
            hv_store(rh, "havedata", 8, newSVnv(result->havedata), 0);
            hv_store(rh, "nxdomain", 8, newSVnv(result->nxdomain), 0);
            hv_store(rh, "secure", 6, newSVnv(result->secure), 0);
            hv_store(rh, "bogus", 5, newSVnv(result->bogus), 0);
            hv_store(rh, "why_bogus", 9, newSVpv(result->why_bogus, 0), 0);
            hv_store(rh, "ttl", 3, newSVnv(result->ttl), 0);

            RETVAL = newRV_inc((SV *)rh);
        }

        ub_resolve_free(result);

    OUTPUT:
        RETVAL

void
_destroy_context( struct ub_ctx *ctx )
    CODE:
        ub_ctx_delete(ctx);
