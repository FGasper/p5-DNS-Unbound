# NAME

DNS::Unbound - Query DNS recursively via [libunbound](https://www.nlnetlabs.nl/documentation/unbound/libunbound/)

<div>
    <a href='https://coveralls.io/github/FGasper/p5-DNS-Unbound?branch=master'><img src='https://coveralls.io/repos/github/FGasper/p5-DNS-Unbound/badge.svg?branch=master' alt='Coverage Status' /></a>
</div>

# SYNOPSIS

    my $dns = DNS::Unbound->new()->set_option( verbosity => 2 );

    # Faster, but dicey if you fork:
    $dns->enable_threads();

    my $verbosity = $dns->get_option( 'verbosity' );

    $dns->set_option( verbosity => 1 + $verbosity );

Synchronous queries:

    my $res_hr = $dns->resolve( 'cpan.org', 'NS' );

    # See below about encodings in “data”.
    my @ns = map { $dns->decode_name($_) } @{ $res_hr->data() };

Asynchronous queries use [the “Promise” pattern](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Using_promises). Assuming you’re using
an off-the-shelf event loop, you can do something like:

    my $dns = DNS::Unbound::AnyEvent->new();

    my $query1 = $dns->resolve_async( 'usa.gov', 'A' )->then(
        sub { my $data = shift()->data(); ... },  # success handler
        sub { ... },                              # failure handler
    );

    my $query2 = $dns->resolve_async( 'in-addr.arpa', 'NS' )->then(
        sub { ... },
        sub { ... },
    );

You can also integrate with a custom event loop; see ["EVENT LOOPS"](#event-loops) below.

# DESCRIPTION

Typical DNS lookups involve a request to a local server that caches
information from DNS. The caching makes it fast, but it also means
updates to DNS aren’t always available via that local server right away.
Most applications don’t need to care and so can enjoy the speed of
cached results.

Applications that need up-to-date DNS query results, though, need
_fully-recursive_ DNS queries. NLnet Labs’s
[libunbound](https://www.nlnetlabs.nl/documentation/unbound/libunbound/)
is a popular solution for such queries; the present Perl module is an
interface to that library.

# CHARACTER ENCODING

DNS doesn’t know about character encodings, so neither does Unbound.
Thus, all strings given to this module must be **byte** **strings**.
All returned strings will be byte strings as well.

# EVENT LOOPS

This distribution includes the classes [DNS::Unbound::AnyEvent](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AAnyEvent),
[DNS::Unbound::IOAsync](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AIOAsync), and [DNS::Unbound::Mojo](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AMojo), which provide
out-of-the-box compatibility with those popular event loop interfaces.
You should probably use one of these.

You can also integrate with a custom event loop via the `fd()` method
of this class: wait for that file descriptor to be readable, then
call this class’s `perform()` method.

# MEMORY LEAK DETECTION

Objects in this namespace will, if left alive at global destruction,
throw a warning about memory leaks. To silence these warnings, either
allow all queries to complete, or cancel queries you no longer care about.

# ERRORS

This library throws 3 kinds of errors:

- Plain strings. Generally thrown in “simple” failure cases,
e.g., invalid inputs.
- [DNS::Unbound::X::Unbound](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AX%3A%3AUnbound) instances. Thrown whenever
Unbound gives an error.
- [DNS::Unbound::X::ResolveError](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AX%3A%3AResolveError) instances. A subclass
of the last kind, for (Unbound-reported) resolution failures.
(This is **NOT** for DNS-reported failures.)

# CONSTANTS

The following from `libunbound/context.h` are defined here:
`UB_NOERROR`, `UB_SOCKET`, `UB_NOMEM`, `UB_SYNTAX`, `UB_SERVFAIL`,
`UB_FORKFAIL`, `UB_AFTERFINAL`, `UB_INITFAIL`, `UB_PIPE`,
`UB_READFILE`, `UB_NOID`

# METHODS

## _CLASS_->new()

Instantiates this class.

## $result\_obj = _OBJ_->resolve( $NAME, $TYPE \[, $CLASS \] )

Runs a synchronous query for a given $NAME and $TYPE. $TYPE may be
expressed numerically or, for convenience, as a string. $CLASS is
optional and defaults to 1 (`IN`), which is probably what you want.

Returns a [DNS::Unbound::Result](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AResult) instance.

**NOTE:** libunbound doesn’t seem to offer effective controls for
timing out a synchronous query.
If timeouts are relevant for you, you probably need
to use `resolve_async()` instead.

## $query\_obj = _OBJ_->resolve\_async( $NAME, $TYPE \[, $CLASS \] );

Like `resolve()` but starts an asynchronous query rather than a
synchronous one.

This returns an instance of [DNS::Unbound::AsyncQuery](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AAsyncQuery) (a subclass
thereof, to be precise).

If you’re using one of the special event interface subclasses
(e.g., [DNS::Unbound::IOAsync](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AIOAsync)) then the returned promise will resolve
as part of the event loop’s normal operation. Otherwise,
[see below](#custom-event-loop-integration) for the methods you’ll need
to use in tandem with this one to get your query result.

## _OBJ_->enable\_threads()

Sets _OBJ_’s asynchronous queries to use threads rather than forking.
Off by default. Throws an exception if called after an asynchronous query has
already been sent.

This is more performant than the default (forking) mode, but it can cause
problems if your application forks; thus, threaded Unbounds **CANNOT** be
used in subprocesses.

Returns _OBJ_.

## _OBJ_->set\_option( $NAME => $VALUE )

Sets a configuration option. Returns _OBJ_.

Note that this is basically just a passthrough to the underlying
`ub_ctx_set_option()` function and is thus subject to the same limitations
as that function; for example, you can’t set `verbosity` after the
configuration has been “finalized”. (So use `debuglevel()` for that
instead.)

## $value = _OBJ_->get\_option( $NAME )

Gets a configuration option’s value.

## _OBJ_->debuglevel( $LEVEL )

Sets the debug level (an integer). Returns _OBJ_.

As of libunbound v1.9.2, this is just a way to set the `verbosity`
option regardless of whether the configuration is finalized.

## _OBJ_->debugout( $FD\_OR\_FH )

Accepts a file descriptor or Perl filehandle and designates that
as the destination for libunbound diagnostic information.

Returns _OBJ_.

## $str = _CLASS_->unbound\_version()

Gives the libunbound version string.

# METHODS FOR ALTERING RESOLVER LOGIC

The following parallel their equivalents in libunbound.
They return _OBJ_ and throw errors on failure.

## _OBJ_->hosts( $FILENAME )



## _OBJ_->resolveconf( $FILENAME )



# CUSTOM EVENT LOOP INTEGRATION

Unless otherwise noted, the following methods correspond to their
equivalents in libunbound. They return the same values as the
libunbound equivalents.

You don’t need these if you use one of the event loop subclasses
(which is recommended).

## _OBJ_->poll()



## _OBJ_->fd()



## _OBJ_->wait()



## _OBJ_->process()



## _OBJ_->count\_pending\_queries()

Returns the number of outstanding asynchronous queries.

# METHODS FOR DEALING WITH DNSSEC

The following correspond to their equivalents in libunbound
and will only work if the underlying libunbound version supports them.

They return _OBJ_ and throw errors on failure.

## _OBJ_->add\_ta( $TA )



## _OBJ_->add\_ta\_autr( $PATH )

(Available only if libunbound supports it.)

## _OBJ_->add\_ta\_file( $PATH )



## _OBJ_->trustedkeys( $PATH )



# CONVENIENCE FUNCTIONS

The following may be called either as object methods or as static
functions (but not as class methods). In addition to these,
[Socket](https://metacpan.org/pod/Socket) provides the `inet_ntoa()` and `inet_ntop()`
functions for decoding the values of `A` and `AAAA` records.

**NOTE:** Consider parsing [DNS::Unbound::Result](https://metacpan.org/pod/DNS%3A%3AUnbound%3A%3AResult)’s `answer_packet()`
as a more robust, albeit heavier, way to parse query result data.
[Net::DNS::Packet](https://metacpan.org/pod/Net%3A%3ADNS%3A%3APacket) and [AnyEvent::DNS](https://metacpan.org/pod/AnyEvent%3A%3ADNS)’s `dns_unpack()` are two good
ways to parse DNS packets.

## $decoded = decode\_name($encoded)

Decodes a DNS name. Useful for, e.g., `NS`, `CNAME`, and `PTR` query
results.

Note that this function’s return will normally include a trailing `.`
because of the trailing NUL byte in an encoded DNS name. This is normal
and expected.

## $strings\_ar = decode\_character\_strings($encoded)

Decodes a list of character-strings into component strings,
returned as an array reference. Useful for `TXT` query results.

# SEE ALSO

[Net::DNS::Resolver::Recurse](https://metacpan.org/pod/Net%3A%3ADNS%3A%3AResolver%3A%3ARecurse) provides comparable logic to this module
in pure Perl. Like Unbound, it is maintained by
[NLnet Labs](https://nlnetlabs.nl/).

[Net::DNS::Resolver::Unbound](https://metacpan.org/pod/Net%3A%3ADNS%3A%3AResolver%3A%3AUnbound) is another XS binding to Unbound,
implemented as a subclass of [Net::DNS::Resolver](https://metacpan.org/pod/Net%3A%3ADNS%3A%3AResolver).

# LICENSE & COPYRIGHT

Copyright 2019-2022 Gasper Software Consulting.

This library is licensed under the same terms as Perl itself.

# REPOSITORY

[https://github.com/FGasper/p5-DNS-Unbound](https://github.com/FGasper/p5-DNS-Unbound)

# THANK YOU

Special thanks to [ATOOMIC](https://metacpan.org/author/ATOOMIC) for
making some helpful review notes.
