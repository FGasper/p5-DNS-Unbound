# NAME

DNS::Unbound - A Perl interface to NLNetLabs’s [Unbound](https://nlnetlabs.nl/projects/unbound/)

# SYNOPSIS

    my $unbound = DNS::Unbound->new()->set_option( verbosity => 2 );

    my $result = $unbound->resolve( 'cpan.org', 'A' );

# METHODS

## _CLASS_->new()

Instantiates this class.

## $result\_hr = _OBJ_->resolve( $NAME, $TYPE \[, $CLASS \] )

Runs a query. Returns a reference to a hash with members `qname`,
`qtype`, `qclass`, `data`, `canonname`, `rcode`, `havedata`,
`nxdomain`, `secure`, `bogus`, `why_bogus`, and `ttl`.
See [libunbound(3)](https://nlnetlabs.nl/documentation/unbound/libunbound/)
for details.

Note that the items in `data` are in their DNS-native encodings.
(libunbound doesn’t track which record type uses which encoding, so
neither does DNS::Unbound.)
To decode some common record types, see ["CONVENIENCE FUNCTIONS"](#convenience-functions) below.

# CONVENIENCE FUNCTIONS

Note that `inet_ntoa()` and `inet_ntop` (useful to decode `A` and
`AAAA` records, respectively) are provided by [Socket](https://metacpan.org/pod/Socket).

The following may be called either as object methods or as static
functions:

## $decoded = decode\_name($encoded)

Decodes a DNS name. Useful for, e.g., `NS` query results.

## $strings\_ar = decode\_character\_strings($encoded)

Decodes a single TXT record into its component character-strings.
Returns an array reference of strings.
