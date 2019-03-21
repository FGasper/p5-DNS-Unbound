# NAME

DNS::Unbound - A Perl interface to NLNetLabs’s [Unbound](https://nlnetlabs.nl/projects/unbound/)

# SYNOPSIS

    my $unbound = DNS::Unbound->new()->set_option( verbosity => 2 );

    my $result = $unbound->resolve( 'cpan.org', 'A' );

# DESCRIPTION

This library implements recursive DNS queries via a popular C-based
resolver library.

# METHODS

## _CLASS_->new()

Instantiates this class.

## $result\_hr = _OBJ_->resolve( $NAME, $TYPE \[, $CLASS \] )

Runs a query. Returns a reference to a hash with members `qname`,
`qtype`, `qclass`, `data`, `canonname`, `rcode`, `havedata`,
`nxdomain`, `secure`, `bogus`, `why_bogus`, and `ttl`.
See [libunbound(3)](https://nlnetlabs.nl/documentation/unbound/libunbound/)
for details.

**NOTE:** Members of `data` are in their DNS-native encodings.
(libunbound doesn’t track which record type uses which encoding, so
neither does DNS::Unbound.)
To decode some common record types, see ["CONVENIENCE FUNCTIONS"](#convenience-functions) below.

# CONVENIENCE FUNCTIONS

Note that [Socket](https://metacpan.org/pod/Socket) provides `inet_ntoa()` and `inet_ntop` functions
for decoding `A` and `AAAA` records.

The following may be called either as object methods or as static
functions (but not as class methods):

## $decoded = decode\_name($encoded)

Decodes a DNS name. Useful for, e.g., `NS` query results.

Note that this will normally include a trailing `.` because of the
trailing NUL byte in an encoded DNS name.

## $strings\_ar = decode\_character\_strings($encoded)

Decodes a list of character-strings into component strings,
returned as an array reference. Useful for `TXT` query results.

# REPOSITORY

[https://github.com/FGasper/p5-DNS-Unbound](https://github.com/FGasper/p5-DNS-Unbound)

1;
