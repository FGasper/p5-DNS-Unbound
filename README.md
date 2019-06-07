# NAME

DNS::Unbound - libunbound in Perl

# SYNOPSIS

    my $dns = DNS::Unbound->new()->set_option( verbosity => 2 );

    my $verbosity = $dns->get_option( 'verbosity' );

    $dns->set_option( verbosity => 1 + $verbosity );

Synchronous queries:

    my $res_hr = $dns->resolve( 'cpan.org', 'NS' );

    # See below about encodings in “data”.
    my @ns = map { $dns->decode_name($_) } @{ $res_hr->{'data'} };

Asynchronous queries use [the “Promise” pattern](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises):

    my $query1 = $dns->resolve_async( 'usa.gov', 'A' )->then(
        sub { my $data = shift()->{'data'}; ... },  # success handler
        sub { ... },                                # failure handler
    );

    my $query2 = $dns->resolve_async( 'in-addr.arpa', 'NS' )->then(
        sub { ... },
        sub { ... },
    );

    # As an alternative to wait(), see below for documentation on
    # the fd(), poll(), and process() methods.

    $dns->wait();

# DESCRIPTION

This library is a Perl interface to NLNetLabs’s widely-used
[Unbound](https://nlnetlabs.nl/projects/unbound/) recursive DNS resolver.

# METHODS

## _CLASS_->new()

Instantiates this class.

## $result\_hr = _OBJ_->resolve( $NAME, $TYPE \[, $CLASS \] )

Runs a synchronous query for a given $NAME and $TYPE. $TYPE may be
expressed numerically or, for convenience, as a string. $CLASS is
optional and defaults to 1 (`IN`), which is probably what you want.

Returns a reference to a hash that corresponds
to a libunbound `struct ub_result`
(cf. [libunbound(3)](https://nlnetlabs.nl/documentation/unbound/libunbound/)),
excluding `len`, `answer_packet`, and `answer_len`.

**NOTE:** Members of `data` are in their DNS-native RDATA encodings.
(libunbound doesn’t track which record type uses which encoding, so
neither does DNS::Unbound.)
To decode some common record types, see ["CONVENIENCE FUNCTIONS"](#convenience-functions) below.

Also **NOTE:** libunbound’s facilities for timing out a synchronous query
are rather lackluster. If that’s relevant for you, you probably want
to use `resolve_async()` instead.

## $query = _OBJ_->resolve\_async( $NAME, $TYPE \[, $CLASS \] );

Like `resolve()` but starts an asynchronous query rather than a
synchronous one.

This returns an instance of `DNS::Unbound::AsyncQuery`, which
subclasses [Promise::ES6](https://metacpan.org/pod/Promise::ES6). You may `cancel()` this promise object.
The promise resolves with either the same hash reference as
`resolve()` returns, or it rejects with a [DNS::Unbound::X](https://metacpan.org/pod/DNS::Unbound::X) instance
that describes the failure.

## _OBJ_->enable\_threads()

Sets _OBJ_’s asynchronous queries to use threads rather than forking.
Off by default. Throws an exception if called after an asynchronous query has
already been sent.

Returns _OBJ_.

**NOTE:** Perl’s relationship with threads is … complicated.
This option is not well-tested. If in doubt, just skip it.

## _OBJ_->set\_option( $NAME => $VALUE )

Sets a configuration option. Returns _OBJ_.

## $value = _OBJ_->get\_option( $NAME )

Gets a configuration option’s value.

## $str = _CLASS_->unbound\_version()

Gives the libunbound version string.

# METHODS FOR DEALING WITH ASYNCHRONOUS QUERIES

The following methods correspond to their equivalents in libunbound:

## _OBJ_->poll()



## _OBJ_->fd()



## _OBJ_->wait()



## _OBJ_->process()



# CONVENIENCE FUNCTIONS

Note that [Socket](https://metacpan.org/pod/Socket) provides the `inet_ntoa()` and `inet_ntop()`
functions for decoding `A` and `AAAA` records.

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

# THANK YOU

Special thanks to [ATOOMIC](https://metacpan.org/author/ATOOMIC) for
making some helpful review notes.
