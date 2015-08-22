use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Fandom::EPluribusHugo',
    license             => 'perl',
    dist_author         => 'Galen Charlton <gmcharlt@gmail.com>',
    dist_version_from   => 'lib/Fandom/EPluribusHugo.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'Fandom-EPluribusHugo-*' ],
);

$builder->create_build_script();
