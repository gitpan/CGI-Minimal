#!/usr/bin/perl -w

use strict;
use lib ('./blib','./lib','../blib','../lib');
use CGI::Minimal;

my $do_tests = [1..2];

my $test_subs = {
  1 => { -code => \&test_calling_parms_table, -desc => 'generate calling parms table               ' },
  2 => { -code => \&test_rfc1123_date,        -desc => 'generate RFC 1123 date                     ' },
};

run_tests($test_subs,$do_tests);

exit;

###########################################################################################

sub test_calling_parms_table {
    my $calling_parms_table = eval {
        return CGI::Minimal->calling_parms_table;
    };
    if ($@) {
        return "unexpected failure $@";
    }
    if ($calling_parms_table eq '') { return 'failed to generate calling parms table'; };
    return '';
}

###########################################################################################

sub test_rfc1123_date {
    my $rfc_date = eval {
        return CGI::Minimal->date_rfc1123(0);
    };
    if ($@) {
        return "unexpected failure $@";
    }
    unless ($rfc_date eq 'Thu, 01 Jan 1970 00:00:00 GMT') {
        return "Generated unexpected date of $rfc_date for epoch date '0'";
    }
    return '';
}

###########################################################################################

sub run_tests {
    my ($test_subs,$do_tests) = @_;

    print @$do_tests[0],'..',@$do_tests[$#$do_tests],"\n";
    print STDERR "\n";
    my $n_failures = 0;
    foreach my $test (@$do_tests) {
        my $sub  = $test_subs->{$test}->{-code};
        my $desc = $test_subs->{$test}->{-desc};
        my $failure = '';
        eval { $failure = &$sub; };
        if ($@) {
            $failure = $@;
        }
        if ($failure ne '') {
            chomp $failure;
            print "not ok $test\n";
            print STDERR "    $desc - $failure\n";
            $n_failures++;
        } else {
            print "ok $test\n";
            print STDERR "    $desc - ok\n";

        }
    }
    
    print "END\n";
}

