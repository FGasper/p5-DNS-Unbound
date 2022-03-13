package MyTest;

use Test::More;

use constant _1_MINUTE => 60;

my $TIMEOUT = 5 * _1_MINUTE;

sub set_timeout {
    alarm $TIMEOUT;

    my $caller_filename = (caller 0)[1];

    $SIG{'ALRM'} = sub {
        diag "$caller_filename: Timeout after $TIMEOUT seconds!";
        exit 99;
    };
}

1;
