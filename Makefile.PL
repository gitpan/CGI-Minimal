use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	     => 'CGI::Minimal',
    'VERSION_FROM'   => 'lib/CGI/Minimal.pm',
    'linkext'        => { LINKTYPE=>'' },	# no link needed
    'dist'           => {'COMPRESS'=>'gzip -9f', 'SUFFIX' => 'gz',
	                 'ZIP'=>'/usr/bin/zip','ZIPFLAGS'=>'-rl'},
    'PREREQ_PM'      => {
               'Carp' => 0,
    }, 
);
