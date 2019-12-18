package DNS::Unbound::XSPromise;

use strict;
use warnings;

use AnyEvent::XSPromises ();

use experimental 'signatures';

sub new ($class, $cr) {
    my $deferred = AnyEvent::XSPromises::deferred();

    my $self = [ $deferred->promise(), $deferred ];

    $cr->(
        sub { $deferred->resolve(shift) },
        sub { $deferred->reject(shift) },
    );

    return bless $self, $class;
}

sub then ($self, $on_res, $on_rej) {
    return bless [ $self->[0]->then( $on_res, $on_rej ) ];
}

sub catch ($self, $on_rej) {
    return $self->then( undef, $on_rej );
}

sub finally ($self, $cr) {
    return $self->then( $cr, $cr );
}

sub all ($self, $things_ar) {
    my @things = map { _is_promise($_) ? $_ : AnyEvent::XSPromises::resolved($_) } @$things_ar;

    return AnyEvent::XSPromises::collect(@things);
}

sub race ($self, $things_ar) { ... }

sub _is_promise($thing) {
    local $@;
    return eval {$thing->isa(__PACKAGE__)};
}

1;
