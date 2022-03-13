#!/usr/bin/env perl

use Test::More;
use Test::FailWarnings;

use FindBin;
use lib "$FindBin::Bin/lib";
use MyTest;

MyTest::set_timeout();

use DNS::Unbound;
use DNS::Unbound::AsyncQuery;

my $dns = DNS::Unbound->new();

my $result = $dns->resolve_async('a.root-servers.net', 'A');
$result->cancel();

ok 1, 'cancel() succeeds if AsyncQuery is loaded at compile time.';

done_testing();
