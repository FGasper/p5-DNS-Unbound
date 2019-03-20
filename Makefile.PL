use 5.008005;
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
  PREREQ_PM      => { 'ExtUtils::MakeMaker' => '7.12' },
  ABSTRACT_FROM  => 'lib/DNS/Unbound.pm',
  AUTHOR         => 'Felipe Gasper <felipe@cpan.org>',
  CCFLAGS        => "$cflags -Wall -std=c99",
  LIBS           => [ $ldflags ],
  #OPTIMIZE       => '-O',
  LICENSE        => 'perl5',
  XSMULTI        => 1,
);
