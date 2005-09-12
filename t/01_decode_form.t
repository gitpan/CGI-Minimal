#!/usr/bin/perl -w

use strict;
use lib ('./blib','./lib','../blib','../lib');
use CGI::Minimal;

my $do_tests = [1..8];

my $test_subs = {
     1 => { -code => \&test_x_www,            -desc => 'decode application/x-www-form-urlencoded   ' },
     2 => { -code => \&test_sgml_form,        -desc => 'decode application/sgml-form-urlencoded    ' },
     3 => { -code => \&test_bad_form,         -desc => 'detect bad calls                           ' },
     4 => { -code => \&test_repeated_params,  -desc => 'decode repeated parameter options          ' },
     5 => { -code => \&test_raw_buffer,       -desc => 'raw buffer                                 ' },
     6 => { -code => \&test_no_params,        -desc => 'no parameters                              ' },
     7 => { -code => \&test_truncation,       -desc => 'detect form truncation                     ' },
     8 => { -code => \&test_multipart_form,   -desc => 'decode multipart/form-data                 ' },
};

run_tests($test_subs,$do_tests);

exit;

###########################################################################################


##############################################################
# Test raw buffer handling                                   #
##############################################################

sub test_raw_buffer {

    $ENV{'QUERY_STRING'}      = 'hello=first;hello=second;hello=third;hello=fourth';
    $ENV{'CONTENT_LENGTH'}    = length($ENV{'QUERY_STRING'});
    $ENV{'CONTENT_TYPE'}      = 'application/sgml-form-urlencoded';
    $ENV{'GATEWAY_INTERFACE'} = 'CGI/1.1'; 
    $ENV{'REQUEST_METHOD'}    = 'GET';

    ############################
    # raw buffer tests
    {
        CGI::Minimal::reset_globals;
        my $raw_buffer = CGI::Minimal::raw();
        if (defined $raw_buffer) {
            return 'failed: reset globals failed to reset raw buffer';
        }
        my $cgi     = CGI::Minimal->new;
        $raw_buffer = CGI::Minimal::raw();
        unless (defined $raw_buffer) {
            return 'failed: raw buffer was undefined when it should not have been'
        }
   
    }
    # Success is an empty string (no error message ;) )
    return '';
}

##############################################################
# Test decoding of forms with no parameters                  #
##############################################################

sub test_no_params {

    ###########################
    # no parameters
    $ENV{'QUERY_STRING'}      = '';
    $ENV{'CONTENT_LENGTH'}    = length($ENV{'QUERY_STRING'});
    $ENV{'CONTENT_TYPE'}      = 'application/sgml-form-urlencoded';
    $ENV{'GATEWAY_INTERFACE'} = 'CGI/1.1'; 
    $ENV{'REQUEST_METHOD'}    = 'GET';

    {
        CGI::Minimal::reset_globals;

        my $cgi = CGI::Minimal->new;

        my @params = $cgi->param;
        if (0 != @params) {
            return 'failed: Unexpected param keys found: ' . join(',',@params);
        }
    }
    # Success is an empty string (no error message ;) )
    return '';
}

##############################################################
# Test decoding of forms with multiple values for parameters #
##############################################################

sub test_repeated_params {

    ###########################
    # repeated parameter names
    $ENV{'QUERY_STRING'}      = 'hello=first;hello=second;hello=third;hello=fourth';
    $ENV{'CONTENT_LENGTH'}    = length($ENV{'QUERY_STRING'});
    $ENV{'CONTENT_TYPE'}      = 'application/sgml-form-urlencoded';
    $ENV{'GATEWAY_INTERFACE'} = 'CGI/1.1'; 
    $ENV{'REQUEST_METHOD'}    = 'GET';

    {
        CGI::Minimal::reset_globals;
        my $cgi = CGI::Minimal->new;
    
        my $string_pairs = { 'hello' => ['first', 'second', 'third', 'fourth'], };
        my @form_keys   = keys %$string_pairs;
        my @param_keys  = $cgi->param;
        if ($#form_keys != $#param_keys) {
            return 'failed : Expected 1 parameter name from SGML form, found ' . ($#param_keys + 1);
        }
    
        my %form_keys_hash = map {$_ => $string_pairs->{$_} } @form_keys;
        foreach my $key_item (@param_keys) {
            if (! defined $form_keys_hash{$key_item}) {
                return 'failed : Parameter names did not match';
            }
            my @item_values      = $cgi->param($key_item);
            my $n_found_items    = $#item_values + 1;
            my @expected_items   = @{$form_keys_hash{$key_item}};
            my $n_expected_items = $#expected_items + 1;
            if ($n_found_items != $n_expected_items) {
                return 'failed: Expected $n_expected_items parameter values, found $n_found_items';
            }
    
            for (my $count = 0; $count < $n_expected_items; $count++) {
                unless ($item_values[$count] eq $expected_items[$count]) {
                    return 'failed: Parameter lists mis-match (' . join(',',@item_values) . ') != (' . join(',',@expected_items) . ')';
                }
            }
            my $first_element = $cgi->param($key_item);
            unless ($first_element eq $expected_items[0]) {
                return 'failed: multiple item param failed to return first element in scalar context';
            }
        }
    }

    # Success is an empty string (no error message ;) )
    return '';
}

######################################################
# Test SGML form decoding                            #
######################################################

sub test_sgml_form {
    $ENV{'QUERY_STRING'}      = 'hello=testing;hello2=SGML+encoded+FORM;nullparm=;=nullkey;submit+button=submit';
    $ENV{'CONTENT_LENGTH'}    = length($ENV{'QUERY_STRING'});
    $ENV{'CONTENT_TYPE'}      = 'application/sgml-form-urlencoded';
    $ENV{'GATEWAY_INTERFACE'} = 'CGI/1.1'; 
    $ENV{'REQUEST_METHOD'}    = 'GET';

    CGI::Minimal::reset_globals;

    my $cgi = CGI::Minimal->new;

    my $string_pairs = { 'hello'         => 'testing',
                         'hello2'        => 'SGML encoded FORM',
                         'nullparm'      => '',
                         ''              => 'nullkey',
                         'submit button' => 'submit',
    };
    my @form_keys   = keys %$string_pairs;
    my @param_keys  = $cgi->param;
    if ($#form_keys != $#param_keys) {
        my $n_expected_parms = $#form_keys + 1;
        return "failed : Expected $n_expected_parms parameters SGML form, found " . ($#param_keys + 1);
    }

    my %form_keys_hash = map {$_ => $string_pairs->{$_} } @form_keys;
    foreach my $key_item (@param_keys) {
        if (! defined $form_keys_hash{$key_item}) {
            return 'failed : Parameter names did not match';
        }
        my $item_value = $cgi->param($key_item);
        if ($form_keys_hash{$key_item} ne $item_value) {
            return 'failed : Parameter values did not match';
        }
    }
    # Unused parameter
    my $value = $cgi->param('no-such-parameter');
    if (defined $value) {
        return "failed: Got a value besides 'undef' for an undeclared parameter query";
    }

    # Success is an empty string (no error message ;) )
    return '';
}

######################################################
# Test bad form decoding                             #
######################################################

sub test_bad_form {

    $ENV{'QUERY_STRING'}      = 'hello=testing&hello2=standard+encoded+FORM&submit+button=submit';
    $ENV{'CONTENT_LENGTH'}    = length($ENV{'QUERY_STRING'});
    $ENV{'CONTENT_TYPE'}      = 'application/x-www-form-urlencoded';
    $ENV{'GATEWAY_INTERFACE'} = 'CGI/1.1'; 
    $ENV{'REQUEST_METHOD'}    = 'TRACE';

    eval {
        CGI::Minimal::reset_globals;
        my $cgi = CGI::Minimal->new;
    };
    unless ($@) {
        return 'failed: Failed to catch unsupported request method';
    }

    # Success is an empty string (no error message ;) )
    return '';
}

######################################################
# Test simple form decoding                          #
######################################################

sub test_x_www {
    $ENV{'QUERY_STRING'}      = 'hello=testing&hello2=standard+encoded+FORM&submit+button=submit';
    $ENV{'CONTENT_LENGTH'}    = length($ENV{'QUERY_STRING'});
    $ENV{'CONTENT_TYPE'}      = 'application/x-www-form-urlencoded';
    $ENV{'GATEWAY_INTERFACE'} = 'CGI/1.1'; 
    $ENV{'REQUEST_METHOD'}    = 'GET';

    CGI::Minimal::reset_globals;

    my $cgi = CGI::Minimal->new;

    my $string_pairs = { 'hello' => 'testing',
                        'hello2' => 'standard encoded FORM',
                 'submit button' => 'submit',
    };
    my @form_keys   = keys %$string_pairs;
    my @param_keys  = $cgi->param;
    if ($#form_keys != $#param_keys) {
        return 'failed : Expected 3 parameters in x-www-form-urlencoded, found ' . ($#param_keys + 1);
    }

    my %form_keys_hash = map {$_ => $string_pairs->{$_} } @form_keys;
    foreach my $key_item (@param_keys) {
        if (! defined $form_keys_hash{$key_item}) {
            return 'failed : Parameter names did not match';
        }
        my $item_value = $cgi->param($key_item);
        if ($form_keys_hash{$key_item} ne $item_value) {
            return 'failed : Parameter values did not match';
        }
    }
        

    # Success is an empty string (no error message ;) )
    return '';
}

######################################################
# Test multiparm form decoding                       #
######################################################

sub test_multipart_form {
    my ($mode) = @_;
    $mode = '' unless (defined $mode);
    local $^W;

    my $basic_boundary = 'lkjsdlkjsd';
    my @boundaries_list = ();
    my $boundary_test_code = {};
    for (my $count = 0; $count < 128; $count ++) {
        next if ((10 == $count) or (13 == $count) or (26 == $count)); # Skip CR, LF and EOF (Ctrl-Z) characters for testing
        my $test_boundary = chr($count) . $basic_boundary;
        push (@boundaries_list,$test_boundary); 
        $boundary_test_code->{$test_boundary} = $count;
    }

    foreach my $boundary (@boundaries_list) {
        my $data = multipart_data($boundary);

        $ENV{'CONTENT_LENGTH'}    = length($data);
        if ($mode eq 'truncate') { $ENV{'CONTENT_LENGTH'}  = length($data) + 1; }
        $ENV{'CONTENT_TYPE'}      = "multipart/form-data; boundary=---------------------------$boundary";
        $ENV{'GATEWAY_INTERFACE'} = 'CGI/1.1'; 
        $ENV{'REQUEST_METHOD'}    = 'POST';

        my $test_file = "test-data.$$.data";
        open (TESTFILE,">$test_file") || return ("failed : could not open test file $test_file for writing: $!");
        binmode (TESTFILE);
        print TESTFILE $data;
        close (TESTFILE);
      
        # "Bad evil naughty Zoot"
        CGI::Minimal::reset_globals;
        open (STDIN,$test_file) || return ("failed : could not open test file $test_file for reading: $!");
        my $cgi = CGI::Minimal->new;
        close (STDIN);
        unlink $test_file;
   
        if ($mode eq 'truncate') {
            unless ($cgi->truncated) { return 'failed: did not detect truncated form'; }
        } else {
            if ($cgi->truncated) { return "failed: form falsely appeared truncated for boundary char " . $boundary_test_code->{$boundary}; }
        }
        my $string_pairs = { 'hello' => 'testing',
                            'hello2' => 'testing2',
                     'submit button' => 'submit',
        };
        my %mime_types = (
                'hello'         => 'text/plain',
                'hello2'        => 'text/html',
                'submit button' => 'text/plain',
        );
        my %filenames = (
                'hello'         => 'hello1.txt',
                'hello2'        => 'example',
                'submit button' => '',
        );

        {
            my @form_keys   = keys %$string_pairs;
            my @param_keys  = $cgi->param;
            if ($#form_keys != $#param_keys) {
                return 'failed : Expected 3 parameters in multipart form, found '
                            . ($#param_keys + 1)
                            . ". testing codepoint " . $boundary_test_code->{$boundary}
                            . " "
                            . " for boundary $boundary $data";
            }
        
            my %form_keys_hash  = map {$_ => $string_pairs->{$_} } @form_keys;
            foreach my $key_item (@param_keys) {
                if (! defined $form_keys_hash{$key_item}) {
                    return 'failed : Parameter names did not match';
                }
                my $item_value = $cgi->param($key_item);
                if ($form_keys_hash{$key_item} ne $item_value) {
                    return 'failed : Parameter values did not match';
                }
                my $item_mime_type = $cgi->param_mime($key_item);
                unless ($item_mime_type eq $mime_types{$key_item}) {
                    return 'failed : Parameter MIME types did not match';
                }
                my $item_filename = $cgi->param_filename($key_item);
                unless ($item_filename eq $filenames{$key_item}) {
                    return 'failed : Parameter filenames did not match';
                }
            }
        }

        {
            my @form_keys   = keys %$string_pairs;
            my @param_keys  = $cgi->param_mime;
            if ($#form_keys != $#param_keys) {
                return 'failed : Expected 3 parameters in mime params for multipart form, found '
                            . ($#param_keys + 1)
                            . ". testing codepoint " . $boundary_test_code->{$boundary}
                            . " "
                            . " for boundary $boundary $data";
            }
        
            my %form_keys_hash  = map {$_ => $string_pairs->{$_} } @form_keys;
            foreach my $key_item (@param_keys) {
                if (! defined $form_keys_hash{$key_item}) {
                    return 'failed : MIME Parameter names did not match';
                }
            }
        }

        {
            my @form_keys   = keys %$string_pairs;
            my @param_keys  = $cgi->param_filename;
            if ($#form_keys != $#param_keys) {
                return 'failed : Expected 3 parameters in filename params for multipart form, found '
                            . ($#param_keys + 1)
                            . ". testing codepoint " . $boundary_test_code->{$boundary}
                            . " "
                            . " for boundary $boundary $data";
            }
        
            my %form_keys_hash  = map {$_ => $string_pairs->{$_} } @form_keys;
            foreach my $key_item (@param_keys) {
                if (! defined $form_keys_hash{$key_item}) {
                    return 'failed : filename Parameter names did not match';
                }
            }
        }

        my @multihello_mimes = $cgi->param_mime('hello');
        if (1 != $#multihello_mimes) {
            return 'failed: unexpected number of parameter MIME types for repeated values';
        }
        my @multihello2_mimes = $cgi->param_mime('hello2');
        if (0 != $#multihello2_mimes) {
            return 'failed: unexpected number of parameter MIME types for single value';
        }
        my @multihello_filenames = $cgi->param_filename('hello');
        if (1 != $#multihello_filenames) {
            return 'failed: unexpected number of parameter filenames for repeated values';
        }
        my @multihello2_filenames = $cgi->param_filename('hello2');
        if (0 != $#multihello2_filenames) {
            return 'failed: unexpected number of parameter filenames for single value';
        }
    }

    # Success is an empty string (no error message ;) )
    return '';
}

######################################################
# tests for detection of truncated forms             #
######################################################

sub test_truncation { test_multipart_form('truncate'); }

######################################################
# multipart test data                                #
######################################################

sub multipart_data {
    my ($boundary) = @_;
    
    my $data =<<"EOD";
-----------------------------$boundary
Content-Disposition: form-data; name="hello"; filename="hello1.txt"

testing
-----------------------------$boundary
Content-Disposition: form-data; name="hello"; filename="hello1.xml"
Content-Type: application/xml 

<data>also testing</data>
-----------------------------$boundary
Content-Disposition: form-data; name="hello2"; filename="example"
Content-Type: text/html

testing2
-----------------------------$boundary
Content-Disposition: form-data; name="submit button"

submit
-----------------------------$boundary--
EOD
    $data =~ s/\012/\015\012/gs;
    return $data;
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

