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

is($err->get('number'), DNS::Unbound::UB_SYNTAX, 'number()');

like( $err->get('string'), qr<syntax>i, 'string()' );

my $str_content = $err->get('string');

like(
    $err->get_message(),
    qr<\Q$str_content\E>,
    'get_message()',
);

done_testing;
