#!/usr/bin/perl -wT

################################################################
# 
# An example of a script that performs a simple CGI function
# in a robust way. This script would form an acceptable framework
# structure for most kinds of CGI scripts.
#
# If your script can't run clean with taint, warnings and strict
# on, it isnt' ready to be deployed because you probably have
# significant code errors and/or security holes.
#
# Notice that there are NO GLOBAL VARIABLES.
# This is important when running in mod_perl or other
# persistent execution environments. Global variables
# may (not necessarily *will*, but *may*)
# persist between script executions in persistent
# execution environments (even worse, they may persist
# between unrelated scripts). It is not necessarily an
# error to have globals, but it is frequently a sign of having
# not actually thought out the code. They just are not
# actually needed that often.
#
# Notice also that we only send output from the script
# in *one* place. This means that we don't get trapped
# with having part of a page already sent to a user
# when we discover we need to output an error or
# handle an unexpected program branch.
#
# Lastly, the main execution path is almost entirely contained
# in an 'eval' block. There is no performance penalty for
# this and it provides some robustness to the script,
# particularly during development.
#

use strict;
use CGI::Minimal;

# main execution block
{
    # $output is the output of the CGI script, ready for sending
    # to the web browser
    my $output = eval {
        my $cgi = CGI::Minimal->new;

        # A dispatch table makes it easy to add new branches
        # to the program functionality without having to
        # have endless 'if..ifelse..ifelse..else' clauses
        my %dispatch_table = (
            'show_form' => \&show_form,
            'plus'      => \&add_numbers,
            'minus'     => \&subtract_numbers,
            'times'     => \&multiply_numbers,
            'divide'    => \&divide_numbers,
        );

        my $action        = $cgi->param('action');
        $action           = defined($action) ? $action : 'show_form';
        my $action_call   = $dispatch_table{$action};
        my $script_output = format_output(defined($action_call) ? &$action_call($cgi) : bad_call($cgi));
        return $script_output;
    };
    # Ordinary 'the program blew up' errors
    if ($@) {
        $output = "Status: 500 Server Error\015\012Content-Type: text/plain\015\012\015\012Fatal Script Error: $@\n";

    # Unusual 'the program just didn't output anything' errors
    } elsif ((! defined $output) || ($output eq '')) {
        $output = "Status: 500 Server Error\015\012Content-Type: text/plain\015\012\015\012Script Error: No output generated by script.\n";

    }
    print $output; 
}

#################################################
# Adds a 'Status: 200 OK' header (if there isn't a CGI
# Status header already), adds a Content-Length header,
# and ensures that we are compliant to the internet EOL
# convention of \015\012 for the headers

sub format_output {
    my ($source_output) = @_;

    my ($headers, $break, $body) = $source_output =~ m/^(.+?)(\015\012\015\012|\012\012|\015\015)(.*)$/s;
    unless (defined $break) {
        $headers = "Content-Type: text/plain; charset=utf-8";
        $body    = "Script Error: Unable to identify HTTP headers and body of output? Something is wrong....:\n$source_output";
    }
    my @header_lines = split(/[\015\012]+/,$headers);
    unless (grep(/^Status: /i, @header_lines)) {
        unshift(@header_lines, 'Status: 200 OK');
    }
    my $content_length = length($body);
    push(@header_lines, "Content-Length: $content_length");
    my $output = join("\015\012",@header_lines,'',$body);
    return $output;
}

#################################################

sub bad_call {
    my ($cgi) = @_;
    my $errors =<<"EOT";
 <p>Something isn't right, the script was called with an 'action' it does not understand.</p>
EOT
    return show_form($cgi,'',$errors);
}

#################################################

sub show_form {
    my ($cgi,$result,$errors) = @_;
    my $script_name = script_name();

    $result = defined($result) ? $result : '?';
    $errors = defined($errors) ? $errors : '';

    my $number1 = $cgi->param('number1');
    $number1    = defined($number1) ? $number1 : 1;
    my $number2 = $cgi->param('number2');
    $number2    = defined($number2) ? $number2 : 1;
    my $action  = $cgi->param('action');
    $action     = defined($action) ? $action : 'times';

    my $number_options = {
        '1'  => '<option value="1" selected="selected">one</<option>',
        '5'  => '<option value="5" selected="selected">five</<option>',
        '10' => '<option value="10" selected="selected">ten</<option>',
    };
    my $action_options = {
        'times'  => '<option value="times"  selected="selected">*</option>',
        'divide' => '<option value="divide" selected="selected">/</option>',
        'plus'   => '<option value="plus"   selected="selected">+</option>',
        'minus'  => '<option value="minus"  selected="selected">-</option>',
    };
    my $number1_selected = defined($number_options->{$number1}) ? $number_options->{$number1} : '';
    my $number2_selected = defined($number_options->{$number2}) ? $number_options->{$number2} : '';
    my $action_selected  = defined($action_options->{$action})  ? $action_options->{$action}  : '';
    my $form_guts =<<"EOT";
    <select name="number1">
     $number1_selected
     <option value="1">one</<option>
     <option value="5">five</<option>
     <option value="10">ten</<option>
    </select>
    <select name="action">
     $action_selected
     <option value="times">*</option>
     <option value="divide">/</option>
     <option value="plus">+</option>
     <option value="minus">-</option>
    </select>
    <select name="number2">
     $number2_selected
     <option value="1">one</<option>
     <option value="5">five</<option>
     <option value="10">ten</<option>
    </select>
    = $result
    <br />
    <input type="submit" value="Do It"/>
EOT

    my $output_text =<<"EOT";
Content-Type: text/html; charset=utf-8

<html>
 <head>
  <title>Simple CGI Example</title>
 </head>
 <body>
 <h2>Example of a simple POST form</h2>
 $errors
 <form action="$script_name" method="POST" enctype="application/x-www-form-urlencoded">$form_guts</form>
 <h2>Example of a simple GET form</h2>
 <form action="$script_name" method="GET" enctype="application/x-www-form-urlencoded">$form_guts</form>
 </body>
</html>
EOT
}

#################################################

sub multiply_numbers {
    my ($cgi) = @_;
    my $number1 = $cgi->param('number1');
    my $number2 = $cgi->param('number2');
    my $result = $number1 * $number2;
    return show_form($cgi,$result);
}

#################################################

sub divide_numbers {
    my ($cgi) = @_;
    my $number1 = $cgi->param('number1');
    my $number2 = $cgi->param('number2');
    my $result = $number1 / $number2;
    return show_form($cgi,$result);
}

#################################################

sub subtract_numbers {
    my ($cgi) = @_;
    my $number1 = $cgi->param('number1');
    my $number2 = $cgi->param('number2');
    my $result = $number1 - $number2;
    return show_form($cgi,$result);
}

#################################################

sub add_numbers {
    my ($cgi) = @_;
    my $number1 = $cgi->param('number1');
    my $number2 = $cgi->param('number2');
    my $result = $number1 + $number2;
    return show_form($cgi,$result);
}

#################################################

sub script_name { return CGI::Minimal->htmlize($ENV{'SCRIPT_NAME'}); }

#################################################