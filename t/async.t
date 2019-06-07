#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok('DNS::Unbound');

my $dns = DNS::Unbound->new()->enable_threads();

my $name = 'usa.gov';
#$name = 'cannot.exist.invalid';

use Carp::Always;
eval {
    my $query = $dns->resolve_async( $name, 'NS' )->then(
        sub { diag explain [ passed => @_ ] },
        sub { diag explain [ failed => @_ ] },
    );

    print ">>>>>>>>>>>>>>>>>> " . $dns->unbound_version() . $/;

    my $fd = $dns->fd();
    diag "FD: $fd";

    vec( my $rin, $fd, 1 ) = 1;
    select( my $rout = $rin, undef, undef, undef );

    diag "Ready vvvvvvvvvvvvv";
    $dns->process();
};

done_testing();
