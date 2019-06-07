#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok('DNS::Unbound');

my $dns = DNS::Unbound->new();

{
    my $name = 'usa.gov';
    #$name = 'cannot.exist.invalid';

    my $query = $dns->resolve_async( $name, 'NS' )->then(
        sub { diag explain [ passed => @_ ] },
        sub { diag explain [ failed => @_ ] },
    );

    my $fd = $dns->fd();

    vec( my $rin, $fd, 1 ) = 1;
    select( my $rout = $rin, undef, undef, undef );

    diag "Ready vvvvvvvvvvvvv";
    $dns->process();
}

#----------------------------------------------------------------------

{
    my @tlds = qw( example.com in-addr.arpa ip6.arpa com org );

    my $done_count = 0;

    my @queries = map {
        $dns->resolve_async( $_, 'NS' )->then(
            sub { diag explain [ passed => @_ ] },
            sub { diag explain [ failed => @_ ] },
        )->then( sub { $done_count++ } );
    } @tlds;

    $dns->wait() while $done_count < @tlds;
}

done_testing();
