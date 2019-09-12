package DNS::Unbound::AsyncQuery;

use strict;
use warnings;

use parent qw( Promise::ES6 );

=encoding utf-8

=head1 NAME

DNS::Unbound::AsyncQuery

=head1 SYNOPSIS

    my $dns = DNS::Unbound->new();

    my $query = $dns->resolve_async( 'example.com', 'A' );

    # Ordinary ES6 Promise semantics:
    $query->then( .. )->then( .. );

    $query->cancel();

=head1 DESCRIPTION

This object represents the result of an asynchronous L<DNS::Unbound> query.
It subclasses L<Promise::ES6> but provides a cancellation mechanism.

The promise resolves with a L<DNS::Unbound::Result> instance.
It rejects with a L<DNS::Unbound::X::ResolveError> instance
that describes the failure.

=cut

#----------------------------------------------------------------------

# A hack to prevent a circular dependency with DNS::Unbound.
# There doesn’t seem to be a better way to do this without having to
# version an XS module separately from the distribution itself,
# which is just annoying. That said, this doubles nicely as a
# mocking mechanism for tests.
our $CANCEL_CR;

#----------------------------------------------------------------------

=head1 METHODS

In addition to the methods inherited from L<Promise::ES6>, this
class provides:

=cut

=head2 I<OBJ>->cancel()

Cancels an in-progress DNS query. Returns nothing.

=cut

sub cancel {
    my ($self) = @_;

    my $dns_hr = $self->_get_dns();

    if (!$dns_hr->{'fulfilled'}) {
        if (my $ctx = delete $dns_hr->{'ctx'}) {
            $CANCEL_CR->( $ctx, $dns_hr->{'id'} );
        }
    }

    return;
}

# Leaving undocumented since as far as the caller is concerned
# this method is identical to the parent class’s.
sub then {
    my $self = shift;

    my $new = $self->SUPER::then(@_);

    $new->_set_dns( $self->_get_dns() );

    return $new;
}

# ----------------------------------------------------------------------
# Interfaces for DNS::Unbound to interact with the query’s DNS state.
# Nothing external should call these other than DNS::Unbound.

sub _set_dns {
    my ($self, $dns_hr) = @_;
    $self->{'_dns'} = $dns_hr;
    return $self;
}

sub _get_dns {
    return $_[0]->{'_dns'};
}

sub _forget_dns {
    delete $_[0]->{'_dns'};
    return $_[0];
}

1;