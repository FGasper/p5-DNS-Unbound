package DNS::Unbound::IOAsync;

use strict;
use warnings;

use parent (
    'DNS::Unbound::EventLoopBase',
    'DNS::Unbound::FDFHStorer',
);

use Scalar::Util ();

use IO::Async::Handle ();

my %INSTANCE_LOOP;
my %INSTANCE_HANDLE;

# perl -MData::Dumper -MIO::Async::Loop -MDNS::Unbound::IOAsync -e'my $loop = IO::Async::Loop->new(); DNS::Unbound::IOAsync->new($loop)->resolve_async("perl.org", "A")->then( sub { print Dumper shift } )->finally( sub { $loop->stop() } ); $loop->run()'

sub new {
    my ($class, $loop, @args) = @_;

    my $self = $class->SUPER::new(@args);

    $INSTANCE_LOOP{$self} = $loop;

    my $weak_self = $self;
    Scalar::Util::weaken($weak_self);

    my $handle = IO::Async::Handle->new(
        read_handle => $self->_get_fh(),
        on_read_ready => sub { $weak_self->process() },
    );
    $INSTANCE_HANDLE{$self} = $handle;

    $loop->add($handle);

    return $self;
}

sub DESTROY {
    my ($self) = @_;

    delete $INSTANCE_LOOP{$self};
    delete $INSTANCE_HANDLE{$self};

    return $self->SUPER::DESTROY();
}

1;
