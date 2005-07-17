use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Maypole::FormBuilder',
    license             => 'perl',
    dist_author         => 'David Baird <cpan@riverside-cms.co.uk>',
    dist_version_from   => 'lib/Maypole/FormBuilder.pm',
    requires => {
        'Test::More' => 0,
        'Class::DBI' => 0,
        'Class::DBI::Loader' => 0,
        'Class::DBI::AbstractSearch' => 0,
        'Class::DBI::Plugin::RetrieveAll' => 0,
        'Class::DBI::FormBuilder' => 0.3452,
        'Class::DBI::Pager' => 0,
        'Class::DBI::Plugin::Type' => 0,
        'Maypole::Model::Base' => 0,
        'NEXT' => 0,
        'UNIVERSAL::require' => 0,
        'Maypole::Config' => 0,
        
    },
    add_to_cleanup      => [ 'Maypole-FormBuilder-*' ],
    create_makefile_pl  => 'traditional',
);

$builder->create_build_script();
