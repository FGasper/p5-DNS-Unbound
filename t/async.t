#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok('DNS::Unbound');

my $dns = DNS::Unbound->new()->set_option( verbosity => 2 );

my $name = 'google.com';    # 'cannot.exist.invalid'

use Carp::Always;
eval {
    my $query = $dns->resolve_async( $name, 'NS' )->then(
        sub { diag explain [ passed => @_ ] },
        sub { diag explain [ failed => @_ ] },
    );
print "after resolve_async: [$query]\n";

#    $query->cancel();
#diag "------- after cancel";

    my $fd = $dns->fd();
    diag "FD: $fd";

    vec( my $rin, $fd, 1 ) = 1;
    select( my $rout = $rin, undef, undef, undef );

    diag "Ready vvvvvvvvvvvvv";
    $dns->process();
};
warn if $@;

done_testing();
