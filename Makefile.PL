use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'Vulcan',
    AUTHOR           => 'Brent Buffham',
    VERSION_FROM     => 'lib/Vulcan/Base.pm',
    ABSTRACT         => 'Perl interface modules for Maptek Vulcan mine-planning software',
    LICENSE          => 'perl',
    MIN_PERL_VERSION => '5.010',
    PREREQ_PM        => {
        'strict'   => 0,
        'warnings' => 0,
        'Carp'     => 0,
        'POSIX'    => 0,
        'Exporter' => 0,
        'File::Path' => 0,
    },
    TEST_REQUIRES => {
        'Test::More' => '0.98',
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources   => {
            repository => {
                type => 'git',
                url  => 'https://github.com/brentbuffham/vulcan-lava.git',
                web  => 'https://github.com/brentbuffham/vulcan-lava',
            },
        },
    },
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz' },
    clean => { FILES    => 'Vulcan-*' },
);
