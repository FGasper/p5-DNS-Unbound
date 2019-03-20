use ExtUtils::MakeMaker 7.12; # for XSMULTI option

my $pkgconfig_name = 'libunbound';

#my $cflags = `pkg-config --static --libs --cflags $pkgconfig_name`;
my $cflags = `pkg-config --cflags $pkgconfig_name`;
die if $?;

my $ldflags = `pkg-config --libs $pkgconfig_name`;

chomp for $cflags, $ldflags;

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
