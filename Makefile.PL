use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Mojolicious::Plugin::RoutesAuthDBI',
    AUTHOR           => q{Mikhail Che <mche@cpan.org>},
    VERSION_FROM     => 'lib/Mojolicious/Plugin/RoutesAuthDBI.pm',
    ABSTRACT_FROM    => 'lib/Mojolicious/Plugin/RoutesAuthDBI.pm',
    #~ ABSTRACT_FROM    => 'README.pod',
    LICENSE          => 'same terms as Perl itself',
    PL_FILES         => {},
    MIN_PERL_VERSION => 5.014,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
    },
    BUILD_REQUIRES => {
        'Test::More' => 0,
    },
    PREREQ_PM => {
        'Mojolicious'=>6.00,
        'Mojolicious::Plugin::Authentication'=>1.29,
        'DBI'=>1.6,
        'DBIx::POS::Template'=>0.0002,
        'Hash::Merge'=>0.200,
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    #~ clean => { FILES => 'Mojolicious-Plugin-RoutesAuthDBI-*' },
);
