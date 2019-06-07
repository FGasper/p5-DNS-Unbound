#!/usr/bin/env perl

use strict;
use warnings;
use autodie;

use Test::More;
use Test::FailWarnings;

use File::Temp;

use_ok('DNS::Unbound');

my $fh = File::Temp::tempfile();

my $dns = DNS::Unbound->new()->debuglevel(2);
$dns->debugout($fh);
$dns->resolve( '.', 'NS' );

my $len = 0 + sysseek($fh, 0, 1);
ok( $len, "debugout() and debuglevel() ($len)" );

sysseek($fh, 0, 0);
sysread( $fh, my $output, $len );

like( $output, qr<unbound>, 'output is as expected' );
