#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;

use_ok('DNS::Unbound');

my $dns = DNS::Unbound->new();
#$dns->set_option( verbosity => 2 );

diag explain( [ 'verbosity' => $dns->get_option('verbosity') ] );

diag explain( [$dns] );

use Data::Dumper;
$Data::Dumper::Useqq = 1;

my $result = $dns->resolve( 'felipegasper.com', 'NS' );

#$_ = join('.', unpack '(C/a)*', $_) for @{ $result->{'data'} };

diag explain $result;

diag 'after resolve';

done_testing();
