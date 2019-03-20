package DNS::Unbound;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

DNS::Unbound - NLNetLabs’s L<Unbound|https://nlnetlabs.nl/projects/unbound/about/> in Perl

=cut

our $VERSION = 0.01;

use constant RR => {
    A => 1,
    AAAA => 28,
    AFSDB => 18,
    APL => 42,
    CAA => 257,
    CDNSKEY => 60,
    CDS => 59,
    CERT => 37,
    CNAME => 5,
    DHCID => 49,
    DLV => 32769,
    DNAME => 39,
    DNSKEY => 48,
    DS => 43,
    HIP => 55,
    HINFO => 13,
    IPSECKEY => 45,
    KEY => 25,
    KX => 36,
    LOC => 29,
    MX => 15,
    NAPTR => 35,
    NS => 2,
    NSEC => 47,
    NSEC3 => 50,
    NSEC3PARAM => 51,
    OPENPGPKEY => 61,
    PTR => 12,
    RRSIG => 46,
    RP => 17,
    SIG => 24,
    SMIMEA => 53,
    SOA => 6,
    SRV => 33,
    SSHFP => 44,
    TA => 32768,
    TKEY => 249,
    TLSA => 52,
    TSIG => 250,
    TXT => 16,
    URI => 256,
};

require XSLoader;

XSLoader::load();

use DNS::Unbound::X ();

sub new {
    bless [ _create_context() ], shift;
}

sub resolve {
    my $result = _resolve( $_[0][0], @_[ 1 .. $#_ ] );

    if (!ref($result)) {
        die DNS::Unbound::X->create('ResolveError', number => $result, string => _ub_strerror($result));
    }
}

sub DESTROY {
    _destroy_context( $_[0][0] );
}

1;
