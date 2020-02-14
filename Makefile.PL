use ExtUtils::MakeMaker;

my $pkgconfig_name = 'libunbound';

my ($cflags, $ldflags);

use Config;
use File::Temp;

use constant _TEST_C_CODE => <<END;
#include <stdio.h>
#include <unbound.h>

int main() {
    fprintf(stdout, "%s", ub_version());

    return 0;
}
END

my $ccpath = $ENV{'CC'} || $Config::Config{'cc'};
print "Your C compiler appears to be: $ccpath\n";

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
use Data::Dumper;
print STDERR Dumper($xtralibs, $bsloadlibs, $ldloadlibs, $ld_run_path, $where_ar );
print STDERR `ls -la /usr/lib/x86_64-linux-gnu/libunb*`;

    if (@$where_ar) {
        print "Libunbound found at: @$where_ar\n";
    }
    else {

        # Useful for Travis CI. Not sure if it’s relevant in production …

        warn "That didn’t work, either. This doesn’t look good. :-/\n";
        warn "As a last resort, let’s just try compiling with libunbound …\n";

        my ($tfh, $tpath) = File::Temp::tempfile( CLEANUP => 1 );
        print {$tfh} "#include <unbound.h>\nint main() { return 0; }\n";
        close $tfh;

        my $cmd = "$ccpath $cflags -xc -lunbound $tpath";
        print "Trying: `$cmd`\n";

        my $out = `$cmd`;
        if ($?) {
            warn "$ccpath failed to use libunbound (CHILD_ERROR=$?): $out";
        }
        else {
            print "Huh, weird … the compiler can use and link libunbound.\n";
            print "Maybe there’s a bug in ExtUtils::Liblist?\n";
            print "Anyway, let’s get on with our business …\n";
        }
    }

    $ldflags ||= '-lunbound';
}

print "CFLAGS: [$cflags]\n";
print "LDFLAGS: [$ldflags]\n";

my @UB_VERSION;

#{
#    print "Let’s see which libunbound version you have …\n";
#
#    my $tdir = File::Temp::tempdir( CLEANUP => 1 );
#    open my $wfh, '>', "$tdir/getversion.c";
#    print {$wfh} _TEST_C_CODE();
#    close $wfh;
#
#    my $cmd = "$ccpath $cflags -o $tdir/getversion $ldflags $tdir/getversion.c";
#
#    print "Compiling test program: `$cmd`\n";
#    system($cmd) and die "Compilation failed (CHILD_ERROR=$?)";
#
#    print "Compilation succeeded! Running compiled test program …\n";
#    my $version = `$tdir/getversion`;
#    die "Test program failed (CHILD_ERROR=$?)" if !$version;
#
#    print "Your libunbound says it’s version “$version”.\n";
#
#    @UB_VERSION = ($version =~ m<([0-9]+)\.([0-9]+)(?:\.[0-9]+)?>);
#    $UB_VERSION[2] ||= 0;
#}

@UB_VERSION = qw( 1 4 20 );

WriteMakefile(
    NAME           => 'DNS::Unbound',
    VERSION_FROM   => 'lib/DNS/Unbound.pm',
    ABSTRACT_FROM  => 'lib/DNS/Unbound.pm',
    AUTHOR         => 'Felipe Gasper (FELIPE)',
    CCFLAGS        => join(
        q< >,
        $cflags,
        '-Wall',
        '-std=c99',
        "-DDUB_UB_VERSION_MAJOR=$UB_VERSION[0]",
        "-DDUB_UB_VERSION_MINOR=$UB_VERSION[1]",
        "-DDUB_UB_VERSION_MACRO=$UB_VERSION[2]",
    ),
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
