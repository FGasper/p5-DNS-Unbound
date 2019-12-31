package DNS::Unbound::AsyncQuery;

use strict;
use warnings;

our @ISA;

BEGIN {
    if ($ENV{'DNS_UNBOUND_USE_PROMISE_XS'}) {
        use blib "/Users/felipe/code/p5-Promise-XS";
        require Promise::XS;
        push @ISA, 'Promise::XS::Promise';
    }
    elsif ($ENV{'DNS_UNBOUND_USE_ANYEVENT_XSPROMISES'}) {
        require AnyEvent::XSPromises;
        push @ISA, 'AnyEvent::XSPromises::PromisePtr';
    }
    else {
        require Promise::ES6;
        push @ISA, 'Promise::ES6';
    }
}

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

B<NOTE:> This will leave the promise I<unresolved>.

=cut

sub cancel {
    my ($self) = @_;

    my $dns_hr = $self->_get_dns();

    if (!$dns_hr->{'fulfilled'}) {
        if (my $ctx = delete $dns_hr->{'ctx'}) {
            delete $dns_hr->{'queries_lookup'}{ $dns_hr->{'id'} };
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
    bless $new, ref $self;  # for XSPromises

    $new->_set_dns( $self->_get_dns() );

    return $new;
}

# Promise::XS doesn’t, as of this release, define catch() or finally()
# as a wrapper around then(). So let’s force that.
sub catch {
    return $_[0]->then( undef, $_[1] );
}

sub finally {
    return $_[0]->then( $_[1], $_[1] );
}

# ----------------------------------------------------------------------
# Interfaces for DNS::Unbound to interact with the query’s DNS state.
# Nothing external should call these other than DNS::Unbound.

my %QUERY_OBJ_DNS;

sub _set_dns {
    my ($self, $dns_hr) = @_;

    $QUERY_OBJ_DNS{$self} = $dns_hr;

    return $self;
}

sub _get_dns {
    return $QUERY_OBJ_DNS{$_[0]};
}

sub DESTROY {
    my $self = shift;

    delete $QUERY_OBJ_DNS{$self};

    $self->SUPER::DESTROY() if $ISA[0]->can('DESTROY');

    return;
}

1;
