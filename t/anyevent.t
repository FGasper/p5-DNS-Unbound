#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use MyTest;

MyTest::set_timeout();

for my $mod ( qw( AnyEvent ) ) {
    eval "require $mod" or plan skip_all => "No $mod: $@";
}

use Data::Dumper;
$Data::Dumper::Useqq = 1;

use_ok('DNS::Unbound::AnyEvent');

my $name = 'example.com';

my $cv = AnyEvent->condvar();

DNS::Unbound::AnyEvent->new()->resolve_async($name, 'NS')->then(
    sub {
        my ($result) = @_;

        isa_ok( $result, 'DNS::Unbound::Result', 'promise resolution' );

        diag "passed: $name";
    },
    sub {
        my $why = shift;
        fail $why;
    },
)->finally($cv);

$cv->recv();

done_testing();
