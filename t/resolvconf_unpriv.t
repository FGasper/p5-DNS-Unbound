#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;
use Test::Exception;
use Test::Deep;

use File::Temp;

use DNS::Unbound;

my $dns = DNS::Unbound->new();

lives_ok(
    sub { $dns->resolvconf() },
    'no arg given',
);

dies_ok(
    sub { $dns->resolvconf('////////qqqq' . rand) },
    'nonexistent path given',
);

my $err = $@;

cmp_deeply(
    $err,
    all(
        Isa('DNS::Unbound::X::Unbound'),
        methods(
            [ get => 'number' ] => DNS::Unbound::UB_READFILE,
            [ get => 'string' ] => re(qr<file>i),
        ),
    ),
    'error thrown',
) or diag explain $err;

done_testing();
