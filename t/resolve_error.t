#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use DNS::Unbound;

my $dns = DNS::Unbound->new();

my $err;
eval { $dns->resolve('...', 'A') };
$err = $@;

isa_ok( $err, 'DNS::Unbound::X::ResolveError', 'exception' );

# TODO: should be a named constant
is($err->get('number'), -3, 'number()');

like( $err->get('string'), qr<.>, 'string()' );

diag explain $err;

done_testing;
