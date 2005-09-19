use Module::Build;
my $build = Module::Build->new
      ( module_name    => 'CGI::Minimal',
        dist_author    => 'Benjamin Franz <snowhare@nihongo.org>',
        dist_abstract  => 'A lightweight CGI form processing package',
        license        => 'perl',
        requires       => { },
        build_requires => { },
      )->create_build_script;
