use Module::Build;;
my $build = Module::Build->new
    (
        dist_author => 'Benjamin Franz <snowhare@freerun.com>',
        module_name => 'CGI::Minimal',
        license     => 'perl',
        );
$build->create_build_script;
