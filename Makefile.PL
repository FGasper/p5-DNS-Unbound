use ExtUtils::MakeMaker;

my $pkgconfig_name = 'libunbound';

my ($cflags, $ldflags);

if ( eval { require ExtUtils::PkgConfig } ) {
    print "Oh good! You have ExtUtils::PkgConfig.\n";

    # These can fail because older libunbound versions (e.g., 1.4.22)
    # didn’t include a pkg-config file.
    $cflags = ExtUtils::PkgConfig->cflags($pkgconfig_name);
    $ldflags = ExtUtils::PkgConfig->libs($pkgconfig_name);

    1;
}
else {
    print "Hmm. You don’t seem to have ExtUtils::PkgConfig.\n";
    print "We’ll try to run `pkg-config $pkgconfig_name` directly …\n";

    $cflags = `pkg-config --cflags $pkgconfig_name`;
    $ldflags = `pkg-config --libs $pkgconfig_name`;

    chomp for $cflags, $ldflags;
}

# In case pkg-config didn’t give us anything.
if (!$ldflags) {
    warn "I didn’t find libunbound via pkg-config.\n";
    warn "Testing manually for libunbound availability …\n";

    use Config;
    my $ccpath = $ENV{'CC'} || $Config::Config{'cc'};

    use File::Temp;
    my ($tfh, $tpath) = File::Temp::tempfile( CLEANUP => 1 );
    print {$tfh} "#include <unbound.h>\nint main() { return 0; }\n";
    close $tfh;

    my $out = `$ccpath $cflags -xc -lunbound $tpath`;
    if ($?) {
        die "Failed to find libunbound: $out";
    }
    else {
        print "Good news: I found your libunbound!\n";

        $ldflags ||= '-lunbound';
    }
}

print "CFLAGS: [$cflags]\n";
print "LDFLAGS: [$ldflags]\n";

WriteMakefile(
    NAME           => 'DNS::Unbound',
    VERSION_FROM   => 'lib/DNS/Unbound.pm',
    ABSTRACT_FROM  => 'lib/DNS/Unbound.pm',
    AUTHOR         => 'Felipe Gasper (FELIPE)',
    CCFLAGS        => "$cflags -Wall -std=c99",
    LIBS           => [ $ldflags ],
    LICENSE        => 'perl',

    PREREQ_PM => {
        'Class::XSAccessor' => 0.10,
        'Net::DNS'  => 0,
        'Promise::ES6' => 0.04,
        'X::Tiny' => 0,
        'XSLoader' => 0.24,
    },

    TEST_REQUIRES => {
        'Test::DescribeMe' => 0,
        'Test::More'            => 0,
        'Test::FailWarnings'    => 0,
        'Test::Exception' => 0,
        'File::Temp' => 0,
        'Net::DNS::Nameserver' => 0,
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            bugtracker => {
                web => 'https://github.com/FGasper/p5-DNS-Unbound/issues',
            },
            repository => {
                type => 'git',
                url  => 'https://github.com/FGasper/p5-DNS-Unbound.git',
                web  => 'https://github.com/FGasper/p5-DNS-Unbound',
            },
        },

        recommends => {
            'ExtUtils::PkgConfig' => 0,
        },
    },
);
