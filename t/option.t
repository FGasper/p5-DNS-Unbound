#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use DNS::Unbound ();

{
    my $dns = DNS::Unbound->new();

    my $got = $dns->set_option( verbosity => 3 );

    is(
        "$got",
        "$dns",
        'set_option() returns the object',
    );

    is(
        $dns->get_option('verbosity'),
        3,
        '… and get_option() returns what was just set',
    );

    $dns->set_option( verbosity => 2 );

    is(
        $dns->get_option('verbosity'),
        2,
        '… and it wasn’t just a default setting',
    );

    undef $dns;
}

done_testing();
