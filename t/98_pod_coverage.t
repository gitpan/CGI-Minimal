use strict;
use warnings;

use Test::More;

use blib ('./blib','../blib');
use lib  ('./lib', '../lib');
eval "use Test::Pod::Coverage 1.06";
if ( $@ ) {
    plan skip_all => "Test::Pod::Coverage 1.06 required for testing POD coverage";
    exit;
}

plan tests => 1;

pod_coverage_ok( 'CGI::Minimal',
    {
        also_private => ['DEBUG']
    }
);
