#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

for my $mod ( qw( Mojolicious Mojo::Promise Mojo::IOLoop ) ) {

    # In some older Mojo versions a spurious warning happens when you
    # load successive Mojo modules.
    # http://www.cpantesters.org/cpan/report/8c3f856a-f4e9-11eb-9602-c4651f24ea8f
    #
    if (!$mod->can('new')) {
        eval "require $mod" or plan skip_all => "No $mod: $@";
    }
}

diag "Using Mojolicious $Mojolicious::VERSION";

use Data::Dumper;
$Data::Dumper::Useqq = 1;

use_ok('DNS::Unbound::Mojo');

my $name = 'example.com';

is(
    DNS::Unbound::Mojo->can('resolve_p'),
    DNS::Unbound::Mojo->can('resolve_async'),
    'resolve_p() alias',
);

SKIP: {
    eval { my $p = Mojo::Promise->new( sub { } ); 1 } or do {
        my $err = $@;
        require Mojolicious;
        skip "This Mojo::Promise ($Mojolicious::VERSION) isn’t ES6-compatible: $err", 1;
    };

    DNS::Unbound::Mojo->new()->resolve_p($name, 'NS')->then(
        sub {
            my ($result) = @_;

            isa_ok( $result, 'DNS::Unbound::Result', 'promise resolution' );

            diag explain [ passed => $result ];
        },
        sub {
            my $why = shift;
            fail $why;
        },
    )->wait();
}

done_testing();
