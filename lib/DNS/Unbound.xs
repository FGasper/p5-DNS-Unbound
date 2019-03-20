#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <stdio.h>
#include <stdlib.h>
#include <unbound.h>    /* unbound API */

static SV * _my_err( const char *class, AV *args ) {
    HV *pkg = gv_stashpv(class, GV_ADD);

    return sv_bless( newRV_inc((SV *)args), pkg );
}

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
            RETVAL = fate;
        }
        else {
            SV *val = newSVpv(str, 0);
            sv_force_normal(val);

            RETVAL = newRV_inc(val);
        }

        free(str);
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
            SV *val;

            // We have to sv_force_normal() all of the result values
            // because we’ll reap &result below.

            AV *data = newAV();
            unsigned int i = 0;

            if (result->data != NULL) {
                while (result->data[i] != NULL) {
                    val = newSVpvn(result->data[i], result->len[i]);
                    sv_force_normal(val);
                    av_push(data, val);
                    i++;
                }
            }

            HV * rh = newHV();

            val = newSVpv(result->qname, 0);
            sv_force_normal(val);
            hv_store(rh, "qname", 5, val, 0);

            val = newSVnv(result->qtype);
            sv_force_normal(val);
            hv_store(rh, "qtype", 5, val, 0);

            val = newSVnv(result->qclass);
            sv_force_normal(val);
            hv_store(rh, "qclass", 6, val, 0);

            hv_store(rh, "data", 4, newRV_inc((SV *)data), 0);

            val = newSVpv(result->canonname, 0);
            sv_force_normal(val);
            hv_store(rh, "canonname", 9, val, 0);

            val = newSVnv(result->rcode);
            sv_force_normal(val);
            hv_store(rh, "rcode", 5, val, 0);

            val = newSVnv(result->havedata);
            sv_force_normal(val);
            hv_store(rh, "havedata", 8, val, 0);

            val = newSVnv(result->nxdomain);
            sv_force_normal(val);
            hv_store(rh, "nxdomain", 8, val, 0);

            val = newSVnv(result->secure);
            sv_force_normal(val);
            hv_store(rh, "secure", 6, val, 0);

            val = newSVnv(result->bogus);
            sv_force_normal(val);
            hv_store(rh, "bogus", 5, val, 0);

            val = newSVpv(result->why_bogus, 0);
            sv_force_normal(val);
            hv_store(rh, "why_bogus", 9, val, 0);

            val = newSVnv(result->ttl);
            sv_force_normal(val);
            hv_store(rh, "ttl", 3, val, 0);

            RETVAL = newRV_inc((SV *)rh);
        }

        ub_resolve_free(result);

    OUTPUT:
        RETVAL

void
_destroy_context( struct ub_ctx *ctx )
    CODE:
        ub_ctx_delete(ctx);
