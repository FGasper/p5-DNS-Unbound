package DNS::Unbound::AnyEvent;

use strict;
use warnings;

# This class does NOT need to be an FDFHStorer because AnyEvent
# works with FDs without needing to create Perl filehandles out of them.
use parent 'DNS::Unbound::EventLoopBase';

use Scalar::Util ();

use AnyEvent ();

# perl -MData::Dumper -MAnyEvent -e'use DNS::Unbound::AnyEvent; my $cv = AnyEvent->condvar(); DNS::Unbound::AnyEvent->new()->resolve_async("perl.org", "A")->then( sub { print Dumper shift } )->finally($cv); $cv->recv()'

my %INSTANCE_WATCHER;

sub new {
    my ($class, @args) = @_;

    my $self = $class->SUPER::new(@args);

    my $weak_self = $self;
    Scalar::Util::weaken($weak_self);

    $INSTANCE_WATCHER{$self} = AnyEvent->io(
        fh => $self->fd(),
        poll => 'r',
        cb => sub { $weak_self->process() },
    );

    return $self;
}

sub DESTROY {
    my ($self) = @_;

    delete $INSTANCE_WATCHER{$self};

    return $self->SUPER::DESTROY();
}

1;
