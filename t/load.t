#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok('DNS::Unbound');

#my $ctx = DNS::Unbound::create_context();
my $dns = DNS::Unbound->new();

diag explain( [$dns] );

use Data::Dumper;
$Data::Dumper::Useqq = 1;

warn Dumper($@) if !eval {
    diag Dumper( $dns->resolve( 'in-addr.arpa', $dns->RR()->{'NS'} ) );
    1;
};

diag 'after resolve';

done_testing();
