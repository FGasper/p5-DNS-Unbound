package DNS::Unbound;

use strict;
use warnings;

=encoding utf-8

=head1 NAME

DNS::Unbound - A Perl interface to NLNetLabs’s L<Unbound|https://nlnetlabs.nl/projects/unbound/> recursive DNS resolver

=head1 SYNOPSIS

    my $dns = DNS::Unbound->new()->set_option( verbosity => 2 );

    my $verbosity = $dns->get_option( 'verbosity' );

    $dns->set_option( verbosity => 1 + $verbosity );

    my $res_hr = $dns->resolve( 'cpan.org', 'NS' );

    # See below about encodings in “data”.
    my @ns = map { $dns->decode_name($_) } @{ $res_hr->{'data'} };

=cut

#----------------------------------------------------------------------

use XSLoader ();

use DNS::Unbound::X ();

our ($VERSION);

BEGIN {
    $VERSION = '0.04';
    XSLoader::load();
}

use constant RR => {
    A => 1,
    AAAA => 28,
    AFSDB => 18,
    ANY => 255,
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

# Copied from libunbound
use constant _ctx_err => {
    -1 => 'socket error',
    -2 => 'alloc failure',
    -3 => 'syntax error',
    -4 => 'DNS service failed',
    -5 => 'fork() failed',
    -6 => 'cfg change after finalize()',
    -7 => 'initialization failed (bad settings)',
    -8 => 'error in pipe communication with async bg worker',
    -9 => 'error reading from file',
    -10 => 'async_id does not exist or result already been delivered',
};

#----------------------------------------------------------------------

=head1 METHODS

=head2 I<CLASS>->new()

Instantiates this class.

=cut

sub new {
    bless [ _create_context() ], shift;
}

=head2 $result_hr = I<OBJ>->resolve( $NAME, $TYPE [, $CLASS ] )

Runs a synchronous query for a given $NAME and $TYPE. $TYPE may be
expressed numerically or, for convenience, as a string. $CLASS is
optional and defaults to 1 (C<IN>), which is probably what you want.

Returns a reference to a hash that corresponds
to a libunbound C<struct ub_result>
(cf. L<libunbound(3)|https://nlnetlabs.nl/documentation/unbound/libunbound/>),
excluding C<len>, C<answer_packet>, and C<answer_len>.

B<NOTE:> Members of C<data> are in their DNS-native RDATA encodings.
(libunbound doesn’t track which record type uses which encoding, so
neither does DNS::Unbound.)
To decode some common record types, see L</CONVENIENCE FUNCTIONS> below.

=cut

sub resolve {
    my $type = $_[2] || die 'Need type!';
    $type = RR()->{$type} || $type;

    my $result = _resolve( $_[0][0], $_[1], $type, $_[3] || () );

    if (!ref($result)) {
        die DNS::Unbound::X->create('ResolveError', number => $result, string => _ub_strerror($result));
    }

    return $result;
}

#----------------------------------------------------------------------

=head2 $query = I<OBJ>->resolve_async( $NAME, $TYPE [, $CLASS ] );

Like C<resolve()> but starts an asynchronous query rather than a
synchronous one.

This returns an instance of C<DNS::Unbound::AsyncQuery>, which
subclasses L<Promise::ES6>. You may C<cancel()> this promise object.
The promise resolves with either the same hash reference as
C<resolve()> returns, or it rejects with a L<DNS::Unbound::X> instance
that describes the failure.

=cut

sub resolve_async {
    my $type = $_[2] || die 'Need type!';
    $type = RR()->{$type} || $type;

    my $async_ar;

    # Prevent memory leaks.
    my $ctx = $_[0][0];
    my $name = $_[1];
    my $class = $_[3] || 1;

    my ($res, $rej);

    my $query = DNS::Unbound::AsyncQuery->new( sub {
        ($res, $rej) = @_;
    } );

    # It’s important that this be the _same_ scalar as what XS gets.
    $query->{'_dns_value'} = undef;

    $query->{'_dns_res'} = $res;
    $query->{'_dns_rej'} = $rej;

    $async_ar = _resolve_async2(
        $ctx, $name, $type, $class,
        $query->{'_dns_value'},
    );

use Data::Dumper;
#print STDERR Dumper( query => $async_ar, $ctx );

    if (my $err = $async_ar->[0]) {
        die DNS::Unbound::X->create('ResolveError', number => $err, string => _ub_strerror($err));
    }

    my $query_id = $async_ar->[1];

    $query->{'ctx'} = $ctx;
    $query->{'id'} = $query_id;

    #$state{'id'} = $query_id;

    #$query->{'_unbound'} = $query;

    #$query->_set_ctx_and_async_id( $ctx, $query_id, $res, $rej);

    $_[0][2]{ $query_id } = $query;

    return $query;
    #return DNS::Unbound::AsyncQuery->new( $_[0], $async_ar->[1] );
}

#----------------------------------------------------------------------

=head2 I<OBJ>->set_option( $NAME => $VALUE )

Sets a configuration option. Returns I<OBJ>.

=cut

sub set_option {
    my $err = _ub_ctx_set_option( $_[0][0], "$_[1]:", $_[2] );

    if ($err) {
        my $str = _ctx_err()->{$err} || "Unknown error code: $err";
        die "Failed to set “$_[1]” ($_[2]): $str";
    }

    return $_[0];
}

=head2 $value = I<OBJ>->get_option( $NAME )

Gets a configuration option’s value.

=cut

sub get_option {
    my $got = _ub_ctx_get_option( $_[0][0], $_[1] );

    if (!ref($got)) {
        my $str = _ctx_err()->{$got} || "Unknown error code: $got";
        die "Failed to get “$_[1]”: $str";
    }

    return $$got;
}

#----------------------------------------------------------------------

sub poll {
    return _ub_poll( $_[0][0] );
}

sub fd {
    return _ub_fd( $_[0][0] );
}

sub wait {
    my $ret = _ub_wait( $_[0][0] );

    $_[0]->_check_promises();

    return $ret;
}

sub process {
    my $ret = _ub_process( $_[0][0] );

    $_[0]->_check_promises();

    return $ret;
}

sub _check_promises {
    my ($self) = @_;

    my $asyncs_hr = $self->[2];

    for (values %$asyncs_hr) {
        if (defined $_->{'_dns_value'}) {
            delete $asyncs_hr->{ $_->{'id'} };

            my $key;

            if ( ref $_->{'_dns_value'} ) {
                $key = '_dns_res';
            }
            else {
                $key = '_dns_rej';

                $_->{'_dns_value'} = DNS::Unbound::X->create('ResolveError', number => $_->{'_dns_value'}, string => _ub_strerror($_->{'_dns_value'}));
            }

            $_->{'_finished'} ||= do {
                eval { $_->{$key}->($_->{'_dns_value'}) };
                1;
            };
        }
    }

    return;
}

#----------------------------------------------------------------------

=head2 I<CLASS>->unbound_version()

Gives the libunbound version string.

=cut

#----------------------------------------------------------------------

=head1 CONVENIENCE FUNCTIONS

Note that L<Socket> provides the C<inet_ntoa()> and C<inet_ntop()>
functions for decoding C<A> and C<AAAA> records.

The following may be called either as object methods or as static
functions (but not as class methods):

=head2 $decoded = decode_name($encoded)

Decodes a DNS name. Useful for, e.g., C<NS> query results.

Note that this will normally include a trailing C<.> because of the
trailing NUL byte in an encoded DNS name.

=cut

sub decode_name {
    shift if (ref $_[0]) && (ref $_[0])->isa(__PACKAGE__);
    return join( '.', @{ decode_character_strings($_[0]) } );
}

=head2 $strings_ar = decode_character_strings($encoded)

Decodes a list of character-strings into component strings,
returned as an array reference. Useful for C<TXT> query results.

=cut

sub decode_character_strings {
    shift if (ref $_[0]) && (ref $_[0])->isa(__PACKAGE__);
    return [ unpack( '(C/a)*', $_[0] ) ];
}

#----------------------------------------------------------------------

sub DESTROY {
    $_[0][1] ||= do {
        if (my $queries_hr = $_[0][2]) {
            $_->cancel() for values %$queries_hr;
            %$queries_hr = ();
        }

print STDERR "@@@@@ destroying context\n";
        _destroy_context( $_[0][0] );
        1;
    };
print STDERR "@@@@@ context is destroyed\n";
}

#----------------------------------------------------------------------
{
    package DNS::Unbound::AsyncQuery;

    use parent qw( Promise::ES6 );

    sub new {
        my ($class) = shift;

        print "XXXXXXX CREATING\n";
        my $self = $class->SUPER::new(@_);

        $self->finally( sub { $self->{'_fulfilled'} = 1; } );

        print "XXXXXXX CREATED: [$self]\n";
        return $self;
    }

    sub then {
        my $self = shift;

        my $new = $self->SUPER::then(@_);
print ",,,,,,, copying unbound from $self to $new\n";

        $new->{'_unbound'} = $self->{'_unbound'} || $self;

        return $new;
    }

#    sub _set_ctx_and_async_id {
#        my ($self, $ctx, $async_id, $res, $rej) = @_;
#
#        $self->{'_unbound'} = {
#            id => $async_id,
#            ctx => $ctx,
#            res => $res,
#            rej => $rej,
#        };
#print "---------- $self: set unbound\n";
#
#        return;
#    }

    sub cancel {
        my ($self) = @_;

        if ($self->{'_fulfilled'}) {
            print STDERR "```````````` $self: already fulfilled on DESTROY\n";
        }
        else {
            print STDERR "```````````` $self: NOT fulfilled on DESTROY\n";

            if ( my $unbound = delete $self->{'_unbound'} ) {
                print STDERR "/////// $self: has unbound on DESTROY\n";

                $unbound->{'canceled'} ||= do {
                    if (my $ctx = $unbound->{'ctx'}) {
                        print STDERR "................ canceling ($$ctx, $unbound->{'id'})\n";
                        DNS::Unbound::_ub_cancel( $ctx, $unbound->{'id'} );
                    }
else {
print STDERR "......... context is already canceled!\n";
}

                    1;
                };
            }
            else {
                print STDERR "/////// $self: NO unbound on DESTROY\n";
            }
        }

        return;
    }
}
#----------------------------------------------------------------------

1;

=head1 REPOSITORY

L<https://github.com/FGasper/p5-DNS-Unbound>

=head1 THANK YOU

Special thanks to L<ATOOMIC|https://metacpan.org/author/ATOOMIC> for
making some helpful review notes.
