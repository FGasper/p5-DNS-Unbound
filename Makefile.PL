use ExtUtils::MakeMaker 7.12; # for XSMULTI option

my $pkgconfig_name = 'libunbound';

# If these fail, just assume that libunbound is installed
# and is reachable simply via -lunbound.
my $cflags = `pkg-config --cflags $pkgconfig_name`;
my $ldflags = `pkg-config --libs $pkgconfig_name`;

chomp for $cflags, $ldflags;

# Just in case.
#$ldflags ||= '-lunbound';
$ldflags = '-lunbound';

WriteMakefile(
    NAME           => 'DNS::Unbound',
    VERSION_FROM   => 'lib/DNS/Unbound.pm',
    ABSTRACT_FROM  => 'lib/DNS/Unbound.pm',
    AUTHOR         => 'Felipe Gasper (FELIPE)',
    CCFLAGS        => "$cflags -Wall -std=c99",
    LIBS           => [ $ldflags ],
    LICENSE        => 'perl',
    XSMULTI        => 1,

    PREREQ_PM => {
        'ExtUtils::MakeMaker' => '7.12',
        'X::Tiny' => 0,
    },

    TEST_REQUIRES => {
        'Test::More'      => 0,
    },
);
