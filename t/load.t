#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok('DNS::Unbound');

my $dns = DNS::Unbound->new();

eval {
    my $result = $dns->resolve( 'cannot.exist.invalid', 'NS' );

    diag explain $result;

    $result = $dns->resolve('com', 'NS');
    $_ = $dns->decode_name($_) for @{ $result->{'data'} };

    diag explain $result;
};

done_testing();
