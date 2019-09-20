#!/usr/bin/env perl

use strict;
use warnings;

use DNS::Unbound;

use AnyEvent;

my $dns = DNS::Unbound->new();

my $watch = AnyEvent->io(
    fh => $dns->fd(),
    poll => 'r',
    cb => sub { $dns->process() while $dns->poll() },
);

my $cv = AnyEvent->condvar();

my $query = $dns->resolve_async('metacpan.org', 'A')->then( sub {
    my $rrs = shift()->to_net_dns_rrs();

    print( $_->string() . $/) for @$rrs;
} )->finally($cv);

my $timer = AnyEvent->timer(
    after => 10,
    cb => sub {
        $query->cancel();
        print "Timed out!$/";
        $cv->();
    },
);

$cv->recv();
