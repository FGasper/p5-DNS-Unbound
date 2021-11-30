#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;
use Test::Exception;

use File::Temp;

use_ok('DNS::Unbound');

my $dns = DNS::Unbound->new();

lives_ok(
    sub { $dns->resolvconf() },
    'no arg given',
);

throws_ok(
    sub { $dns->resolvconf('////////qqqq' . rand) },
    qr<file>i,
    'nonexistent path given',
);

done_testing();
