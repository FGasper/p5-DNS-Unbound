use ExtUtils::MakeMaker;

my $pkgconfig_name = 'libunbound';

my ($cflags, $ldflags);

if ( eval { require ExtUtils::PkgConfig } ) {
    print "Oh good! You have ExtUtils::PkgConfig. :)\n";

    # These can fail because older libunbound versions (e.g., 1.4.22)
    # didn’t include a pkg-config file.
    $cflags = ExtUtils::PkgConfig->cflags($pkgconfig_name);
    $ldflags = ExtUtils::PkgConfig->libs($pkgconfig_name);
}
else {
    print "Hmm. You don’t seem to have ExtUtils::PkgConfig.\n";
    print "I’ll try running `pkg-config` directly …\n";

    my $cmd = "pkg-config --cflags $pkgconfig_name";

    $cflags = `$cmd`;
    if ($?) {
        warn "`$cmd` failed (CHILD_ERROR=$?)\n";
    }
    else {
        print "Cool. It looks like pkg-config works.\n";

        $ldflags = `pkg-config --libs $pkgconfig_name`;
    }

    chomp for $cflags, $ldflags;
}

# In case pkg-config didn’t give us anything.
if (!$ldflags) {
    warn "I didn’t find libunbound via pkg-config. :(\n";
    warn "Now I’ll look for libunbound via ExtUtils::Liblist …\n";

    my ($xtralibs, $bsloadlibs, $ldloadlibs, $ld_run_path, $where_ar) = ExtUtils::Liblist->ext('-lunbound', 0, 1);

    if (@$where_ar) {
        print "Libunbound found at: @$where_ar\n";
    }
    else {
        warn "That didn’t work, either. This isn’t looking good. :-/\n";
        warn "As a last resort, let’s just try compiling with libunbound …\n";

        use Config;
        my $ccpath = $ENV{'CC'} || $Config::Config{'cc'};
        print "Your C compiler appears to be: $ccpath\n";

        use File::Temp;
        my ($tfh, $tpath) = File::Temp::tempfile( CLEANUP => 1 );
        print {$tfh} "#include <unbound.h>\nint main() { return 0; }\n";
        close $tfh;

        my $cmd = "$ccpath $cflags -xc -lunbound $tpath";
        print "Trying: `$cmd`\n";

        my $out = `$cmd`;
        if ($?) {
            #die "Failed to find libunbound (CHILD_ERROR=$?): $out";
            warn "Failed to find libunbound (CHILD_ERROR=$?): $out";
        }
        else {
            print "Whew! libunbound compiles! Now let’s get on with things …\n";
        }
    }

    $ldflags ||= '-lunbound';
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
