# NAME

DNS::Unbound - NLNetLabs’s [Unbound](https://nlnetlabs.nl/projects/unbound/about/) in Perl

# SYNOPSIS

    my $unbound = DNS::Unbound->new()->set_option( verbosity => 2 );

    my $result = $unbound->resolve( 'cpan.org', 'A' );
