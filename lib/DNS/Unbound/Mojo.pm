package DNS::Unbound::Mojo;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

DNS::Unbound::Mojo

=head1 SYNOPSIS

    DNS::Unbound::Mojo->new()->resolve_p("perl.org", "A")->then(
        sub {
            my $result = shift;

            # ...
        }
    )->wait();

=head1 DESCRIPTION

This class provides native L<Mojolicious> compatibility for L<DNS::Unbound>.
In particular:

=over

=item * C<resolve_p()> is an alias for C<resolve_async()>.

=item * Returned promises subclass L<Mojo::Promise> (rather than
L<Promise::ES6>) by default.

=back

=cut

#----------------------------------------------------------------------

use parent (
    'DNS::Unbound::EventLoopBase',
    'DNS::Unbound::FDFHStorer',
);

use DNS::Unbound::AsyncQuery::MojoPromise ();

use Scalar::Util ();

use Mojo::IOLoop ();
use Mojo::Promise ();

# perl -MData::Dumper -MDNS::Unbound::Mojo -e'DNS::Unbound::Mojo->new()->resolve_async("perl.org", "A")->then( sub { print Dumper shift } )->wait()'

my %INSTANCE_HANDLE;

use constant _DEFAULT_PROMISE_ENGINE => 'Mojo::Promise';

sub new {
    my ($class, @args) = @_;

    my $self = $class->SUPER::new(@args);

    my $weak_self = $self;
    Scalar::Util::weaken($weak_self);

    my $handle = Mojo::IOLoop->singleton()->reactor()->io(
        $self->_get_fh(),
        sub { $weak_self->process() },
    );
    $INSTANCE_HANDLE{$self} = $handle;

    return $self;
}

*resolve_p = __PACKAGE__->can('resolve_async');

sub DESTROY {
    my ($self) = @_;

    delete $INSTANCE_HANDLE{$self};

    return $self->SUPER::DESTROY();
}

1;
