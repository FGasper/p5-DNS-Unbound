package DNS::Unbound::Mojo;
use strict;
use warnings;

use parent 'DNS::Unbound::EventLoopBase';

use Scalar::Util ();

use Mojo::IOLoop ();
use Mojo::Promise ();

my %INSTANCE_HANDLE;

use constant _DEFAULT_PROMISE_ENGINE => 'Mojo::Promise';

# perl -MMojo::IOLoop -Ilib -e'use blib "."; use DNS::Unbound::Mojo; DNS::Unbound::Mojo->new()->resolve_async("usa.gov", "A")->then( sub { print shift } )->wait()'

sub new {
    my ($class, @args) = @_;

    my $self = $class->SUPER::new(@args);

    my $weak_self = $self;
    Scalar::Util::weaken($weak_self);

    open my $rfh, '<&=' . $self->fd();

    my $handle = Mojo::IOLoop->singleton()->reactor()->io(
        $rfh,
        sub { $weak_self->process() },
    );
    $INSTANCE_HANDLE{$self} = $handle;

    return $self;
}

sub DESTROY {
    my ($self) = @_;

    delete $INSTANCE_HANDLE{$self};

    return $self->SUPER::DESTROY();
}

1;
