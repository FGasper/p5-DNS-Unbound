package DNS::Unbound::Result;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

DNS::Unbound::Result

=head1 DESCRIPTION

This class represents a DNS query result from L<DNS::Unbound>.

=head1 ACCESSORS

The following correspond to the members of C<struct ub_result>
(cf. L<libunbound(3)|https://nlnetlabs.nl/documentation/unbound/libunbound/>):

The following all return scalars:

=over

=item * C<qname()>, C<qtype()>, C<qclass()>, C<ttl()>

=item * C<rcode()>, C<nxdomain()>, C<havedata()>, C<canonname()>

=item * C<secure()>, C<bogus()>, C<why_bogus()>

=back

C<data()> returns an array reference of strings that contain the query
result in DNS-native RDATA encoding.

Since that’s not usually very convenient, this class also exposes a
C<to_net_dns()> method that returns a reference to an array of
L<Net::DNS::RR> instances.

So, for example, to get a TXT query result’s value as a list of
character strings, you could do:

    @cstrings = map { $_->txtdata() } @{ $result->to_net_dns() }

=cut

use Class::XSAccessor {
    constructor => 'new',

    getters => {
        qname => 'qname',
        qtype => 'qtype',
        qclass => 'qclass',
        data => 'data',
        canonname => 'canonname',
        rcode => 'rcode',
        havedata => 'havedata',
        nxdomain => 'nxdomain',
        secure => 'secure',
        bogus => 'bogus',
        why_bogus => 'bogus',
        ttl => 'ttl',
    },
};

sub to_net_dns {
    my ($self) = @_;

    local ($@, $!);
    require Net::DNS::RR;

    my @rrset = map {
        Net::DNS::RR->new(
            owner => $self->{'qtype'},
            type => $self->{'qtype'},
            class => $self->{'qclass'},
            ttl => $self->{'ttl'},
            rdata => $_,
        );
    } @{ $self->{'data'} };

    return \@rrset;
}

1;
