#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::FailWarnings;

use_ok('DNS::Unbound');

alarm 60;

my $QNAME = 'org';
my $QTYPE = 'A';

{
    my $dns = DNS::Unbound->new()->enable_threads();

    $dns->resolve_async($QNAME, $QTYPE);

    diag "resolving query ($QNAME, $QTYPE)";
    $dns->wait();

    diag 'query resolved';

    fork or exit;
    wait();

    diag 'reaped subprocess';
}

ok 1, 'Unbound object reaped';

done_testing();
