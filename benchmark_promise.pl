#!/usr/bin/env perl

use strict;
use warnings;

use DNS::Unbound;

use blib "/Users/felipe/code/p5-Promise-XS";
use Promise::XS;
use AnyEvent::XSPromises;
use Promise::ES6;

use AnyEvent;

my $dns = DNS::Unbound->new()->enable_threads();

my @promises;

for (1 .. 100000) {
    push @promises, $dns->resolve_async('cpanel.net', 'NS');
}

my $cv = AnyEvent->condvar();

print "$_$/" for sort keys %INC;

if ($ENV{'DNS_UNBOUND_USE_PROMISE_XS'}) {
    Promise::XS::all(@promises)->then($cv);
}
elsif ($ENV{'DNS_UNBOUND_USE_ANYEVENT_XSPROMISES'}) {
    AnyEvent::XSPromises::collect(@promises)->then($cv);
}
else {
    Promise::ES6->all(\@promises)->then($cv);
}
