#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use MyTest;

MyTest::set_timeout();

for my $mod ( qw( IO::Async::Loop  IO::Async::Handle ) ) {
    eval "require $mod" or plan skip_all => "No $mod: $@";
}

use Data::Dumper;
$Data::Dumper::Useqq = 1;

use_ok('DNS::Unbound::IOAsync');

my $name = 'example.com';

my $loop = IO::Async::Loop->new();

DNS::Unbound::IOAsync->new($loop)->resolve_async($name, 'NS')->then(
    sub {
        my ($result) = @_;

        isa_ok( $result, 'DNS::Unbound::Result', 'promise resolution' );

        diag "passed: $result";
    },
    sub {
        my $why = shift;
        fail $why;
    },
)->finally( sub { $loop->stop() } );

$loop->run();

done_testing();
