package CGI::Minimal;

#######################################################################
#                                                                     #
# The most current release can always be found at                     #
# <URL:http://www.nihongo.org/snowhare/utilities/>                    #
#                                                                     #
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND WITHOUT ANY EXPRESS         #
# OR IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE           #
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A             #
# PARTICULAR PURPOSE.                                                 #
#                                                                     #
# Use of this software in any way or in any form, source or binary,   #
# is not allowed in any country which prohibits disclaimers of any    #
# implied warranties of merchantability or fitness for a particular   #
# purpose or any disclaimers of a similar nature.                     #
#                                                                     #
# IN NO EVENT SHALL I BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,    #
# SPECIAL, INCIDENTAL,  OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE   #
# USE OF THIS SOFTWARE AND ITS DOCUMENTATION (INCLUDING, BUT NOT      #
# LIMITED TO, LOST PROFITS) EVEN IF I HAVE BEEN ADVISED OF THE        #
# POSSIBILITY OF SUCH DAMAGE                                          #
#                                                                     #
# This program is free software; you can redistribute it              #
# and/or modify it under the same terms as Perl itself.               #
#                                                                     #
# Copyright 1999 Benjamin Franz. All Rights Reserved.                 #
#                                                                     #
#######################################################################

use strict;
use Carp;

use vars qw ($_query $VERSION $form_initial_read);
$VERSION = "1.04";

# check for mod_perl and include the 'Apache' module if needed
if (exists $ENV{'MOD_PERL'}) {
    $| = 1;
    require Apache;
}

# Initialize the CGI global variables
&_reset_globals;

=head1 NAME

CGI::Minimal - A lightweight CGI form processing pacakge

=head1 SYNOPSIS

 use CGI::Minimal;

 my $cgi = CGI::Minimal->new;
 if ($cgi->truncated) {
    &scream_about_bad_form;
    exit;
 }
 my ($form_field_value) = $cgi->param('some_field_name');

=head1 DESCRIPTION

Provides a micro-weight alternative to the CPAN CGI.pm module 

Rather than attempt to address every possible need of a CGI 
programmer, it provides the _minimum_ functions needed for CGI such
as form decoding (including file upload forms), URL encoding
and decoding, HTTP usable date generation (RFC1123 compliant
dates) and _basic_ escaping and unescaping of HTMLized text.

The form decoding interface is somewhat compatible with the 
CGI.pm module. No provision is made for generating HTTP or HTML
on your behalf - you are expected to be conversant with how
to put together any HTML or HTTP you need.

=head1 CHANGES

 1.04 03 April 2000 - Added capability to set params via the param() method
                      like 'CGI.pm' plus general code cleanup
 
 1.03 02 March 2000 - 'mod_perl' compatibility added 

 1.02 09 June 1999  - Initial public release.

=cut

=head1 METHODS

=cut

######################################################################

=over 4

=item new;

Creates a new instance of the CGI::Minimal object and decodes
any type of form (GET/POST). Only one 'true' object is generated - 
all subsequent calls return an alias of the one object (a 'Singleton'
pattern).

Example: 

 use CGI::Minimal;

 my $cgi = CGI::Minimal->new;

=back

=cut

sub new {

    if ($form_initial_read) {
        $_query->_read_form;
        $form_initial_read = 0;
    }
    if (exists $ENV{'MOD_PERL'}) {
        Apache->request->register_cleanup(\&CGI::Minimal::_reset_globals);
    }

    $_query;
}

#######################################################################

=over 4

=item param([$fieldname]);

Called as C<$cgi-E<gt>param();> it returns the list of all defined
form fields in the same order they appear in the data from the
user agent.

Called as C<$cgi-E<gt>param($fieldname);> it returns the value (or
array of values for multiple occurances of the same field name) assigned
to that $fieldname. If there is more than one value, the values are
returned in the same order they appeared in the data from user agent.

Examples:

  my (@form_fields) = $cgi->param;

  my (@multi_pick_field) = $cgi->param('pick_field_name');

  my ($form_field_value) = $cgi->param('some_field_name');

You can also use the param method to set param values to new values.
These values will be returned by any invokation of a CGI::Minimal object
as if they had been found in the original passed data.

Examples:

    $cgi->param( 'name' => 'Joe Shmoe' );

    $cgi->param({ 'name' => 'Joe Shmoe', 'birth_date' => '06/25/1966' });

    $cgi->param({ 'pick_list' => ['01','05','07'] });

=back

=cut

sub param {
    my $self = shift;
    my $package = __PACKAGE__;

    if (@_ == 0) {
        croak(__PACKAGE__ . "::param() - No calling parameters passed");
    }    
    if (1 < @_) {
        my $n_parms = @_;
        if (($n_parms % 2) == 1) {
            croak(__PACKAGE__ . "::param() - Odd number of parameters (other than 1) passed");
        }
	my $parms = { @_ };
        $self->_set($parms);
        return;
    }
    if (ref ($_[0]) eq 'HASH') {
	my $parms = shift;
        $self->_set($parms);
        return;
    }
        
    my @result = ();
    if ($#_ == -1) {
        @result = @{$self->{$package}->{'field_names'}};
    } elsif ($#_ == 0) {
        my ($fieldname)=@_;
        if (defined($self->{$package}->{'field'}->{$fieldname})) {
            @result = @{$self->{$package}->{'field'}->{$fieldname}->{'value'}};
        }
    }
    if (wantarray) {
        return @result;
    } elsif ($#result > -1) {
        return $result[0];
    } else {
        return;
    }
}

#######################################################################

=over 4

=item param_mime([$fieldname]);

Called as C<$cgi-E<gt>param_mime();> it returns the list of all defined 
form fields in the same order they appear in the data from the
user agent.

Called as C<$cgi-E<gt>param_mime($fieldname);> it returns the MIME
type (or array of MIME types for multiple occurances of the same field 
name) assigned to that $fieldname. If there is more than one value, the 
values are returned in the same order they appeared in the data from user 
agent.

This is only meaningful when doing Form Based File Uploads and
should probably not be trusted even then since it depends on the
_browser_ correctly identifying what it is sending.

=back

=cut

sub param_mime {
    my $self    = shift;
    my $package = __PACKAGE__;

    my @result = ();
    if ($#_ == -1) {
        @result = @{$self->{$package}->{'field_names'}};
    } elsif ($#_ == 0) {
        my ($fieldname)=@_;
        if (defined($self->{$package}->{'field'}->{$fieldname})) {
            @result = @{$self->{$package}->{'field'}->{$fieldname}->{'mime_type'}};
        }
    }
    if (wantarray) {
        return @result;
    } elsif ($#result > -1) {
        return $result[0];
    } else {
        return;
    }
}

#######################################################################

=over 4

=item param_filename([$fieldname]);

Called as C<$cgi-E<gt>param_filename();> it returns the list of all 
defined form fields in the same order they appear in the data from the
user agent.

Called as C<$cgi-E<gt>param_filename($fieldname);> it returns the 
file name (or array of file names for multiple occurances of the same field 
name) assigned to that $fieldname. If there is more than one value, the 
values are returned in the same order they appeared in the data from user 
agent.

This is only meaningful when doing Form Based File Uploads.

=back

=cut

sub param_filename {
    my $self = shift;
    my $package = __PACKAGE__;

    my @result = ();
    if ($#_ == -1) {
        @result = @{$self->{$package}->{'field_names'}};
    } elsif ($#_ == 0) {
        my ($fieldname)=@_;
        if (defined($self->{$package}->{'field'}->{$fieldname})) {
            @result = @{$self->{$package}->{'field'}->{$fieldname}->{'filename'}};
        }
    }
    if (wantarray) {
        return @result;
    } elsif ($#result > -1) {
        return $result[0];
    } else {
        return;
    }
}

#######################################################################

=over 4

=item date_rfc1123($time);

Takes a unix time tick value and returns a RFC1123 compliant date
as a formatted text string suitable for direct use in Expires,
Last-Modified or other HTTP headers (with the exception of 
'Set-Cookie', which requires a different format not generated
here. See 'CGI::Cookie' for cookie generation).

Example:

 print "Expires: ",$cgi->date_rfc1123(time + 3600),"\015\012";

=back

=cut

sub date_rfc1123 {
    my ($self) = shift;

    my ($tick) = @_;

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime($tick);

    my $wkday = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat')[$wday];
    my $month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')[$mon];
    $year += 1900;
    my $date = sprintf('%s, %02d %s %s %02d:%02d:%02d GMT',$wkday,$mday,$month,$year,$hour,$min,$sec);

    $date;
}

#######################################################################

=over 4

=item calling_parms_table;

Returns a formatted HTML table containing all the form and environment
variables for debugging purposes

Example:

  print $cgi->calling_parms_table;

=back

=cut

sub calling_parms_table {
    my $self = shift;
    my $package = __PACKAGE__;

    my $outputstring = <<"EOF";
<table border=1 cellspacing=0>
<tr>
  <th colspan=4>Form Fields</th>
</tr>

<tr>
  <th>Field</th>
  <th>Value</th>
  <th>mime Type</th>
  <th>File Name</th>
</tr>
EOF
    my ($fieldname);
    foreach $fieldname (sort @{$self->{$package}->{'field_names'}}) {
        my ($fieldmime,$fieldfile,$fieldvalue);
        my ($sub_field_counter)= $#{$self->{$package}->{'field'}->{$fieldname}->{'value'}};
        for (my $fieldn=0;$fieldn <= $sub_field_counter;$fieldn++) {
            $fieldmime  = $self->{$package}->{'field'}->{$fieldname}->{'mime_type'}->[$fieldn];
            $fieldfile  = $self->{$package}->{'field'}->{$fieldname}->{'filename'}->[$fieldn]; 
            $fieldvalue = '[non-text value]';
            if ($fieldmime =~ m#^text/#oi) {
                $fieldvalue = $self->htmlize($self->{$package}->{'field'}->{$fieldname}->{'value'}->[$fieldn]);
            }
        $outputstring .= <<"EOF";
<tr>
  <td>$fieldname (#$fieldn)</td>
  <td> $fieldvalue </td>
  <td>$fieldmime</td>
  <td>$fieldfile</td>
</tr>
EOF
        }
    }
    $outputstring .= <<"EOF";
<tr>
  <th colspan=4>Environment Variables</th>
</tr>

<tr>
  <th>Variable</th>
  <th colspan=3>Value</th>
</tr>
EOF

    foreach $fieldname (sort keys (%ENV)) {
        $outputstring .= "<tr>\n  <td>$fieldname</td>\n  <td colspan=3>" .
            $self->htmlize($ENV{$fieldname}) . "</td>\n</tr>\n";
    }

    $outputstring .= "</table>\n";

    $outputstring;
}

#######################################################################

=over 4

=item url_encode($string);

Returns URL encoding of input string (URL unsafe codes are 
escaped to %xx form)

Example:

 my $url_encoded_string = $cgi->url_encode($string);

=back

=cut

sub url_encode {
    my ($self) = shift;

    my ($line)=@_;

    return ('') if (! defined ($line));

    $line=~s/([\000-\054\072-\100\176-\377])/"\%".unpack("H",$1).unpack("h",$1)/egos;
    $line;
}

#######################################################################

=over 4

=item url_decode($string);

Returns URL *decoding* of input string (%xx substitutions
are decoded to their actual values).

Example:

 my $url_decoded_string = $cgi->url_decode($string);

=back

=cut

sub url_decode {
    my ($self) = shift;

    my ($line) = @_;

    return ('') if (! defined($line));
    $line =~ s/\+/ /gos;
    $line =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/egos;
    $line;
}

#######################################################################

=over 4

=item htmlize($string);

Returns HTML 'safe' encoding of input string. Replaces &,>,< and "
with their named entity codes (&amp, &gt; &lt; and &quot;)

Example:

 my $html_escaped_string = $cgi->htmlize($string);

=back

=cut

sub htmlize {
    my ($self) = shift;

    my ($line)=@_; 

    return ('') if (! defined($line));

    $line =~ s/\&/\&amp;/gos; 
    $line =~ s/>/\&gt;/gos;
    $line =~ s/</\&lt;/gos;
    $line =~ s/"/\&quot;/gos;
    $line;
}

#######################################################################

=over 4

=item dehtmlize($string);

Undoes basic HTML encoding of input string. Replaces &amp;,
&gt;, &lt; and &quot; named entity codes with their actual values.
NOT a general purpose entity decoder.

=back

=cut

sub dehtmlize {
    my ($self) = shift;

    my($line)=@_;;
        
    return ('') if (! defined($line));

    $line=~s/\&gt;/>/go;
    $line=~s/\&lt;/</go;
    $line=~s/\&quot;/\"/go;
    $line=~s/\&amp;/\&/go;

    $line;
}  

#######################################################################

=over 4

=item truncated;

Returns '1' if the read form was shorter than the
Content-Length that was specified by the submitting
user agent (ie the data from a form uploaded by a 
web browser was cut off before all the data was received). 

Returns '0' if the form was NOT truncated.

Example:

  use CGI::Minimal;

  my $cgi = CGI::Minimal->new;
  if ($cgi->truncated) {
    &bad_form_upload;
  } else {
    &good_form_upload;
  }

'truncated' will also return '1' if the form length
received would have exceeded the set 'max_read_length'.

=back

=cut

sub truncated {
    my $self = shift;
    my $package = __PACKAGE__;

    $self->{$package}->{'form_truncated'};
}

########################################################################

=over 4

=item CGI::Minimal::max_read_size($size);

Sets the maximum number of bytes/octets that the
CGI decoder will accept. By default, 1000000 bytes/octets.
This must be called *BEFORE* calling 'new' for the first
time for it to actually affect form decoding.

Example:

  use CGI::Minimal;

  CGI::Minimal::max_read_size(1000000);
  my $cgi = CGI::Minimal->new;

=back

=cut

sub max_read_size {
    my $size = shift;
    my $package = __PACKAGE__;

    $_query->{$package}->{'max_buffer'} = $size;
}

########################################################################
# Wrapper for form reading for GET, HEAD and POST methods              #
########################################################################
sub _read_form {
    my ($self) = shift;

    return if (! defined($ENV{"REQUEST_METHOD"})); 

    my ($request_method)=$ENV{"REQUEST_METHOD"};

    if ($request_method eq 'POST') {
        $self->_read_post;
    } elsif (($request_method eq 'GET') || ($request_method eq 'HEAD')) {
        $self->_read_get;
    }
}

########################################################################
# Performs form reading for POST method                                #
########################################################################
sub _read_post {
    my ($self) = shift;
    my $package = __PACKAGE__;

    my $read_length = $self->{$package}->{'max_buffer'};
    
    if ($ENV{'CONTENT_LENGTH'} < $read_length) {
        $read_length= $ENV{'CONTENT_LENGTH'};
    }

    my ($buffer)     = '';
    my ($read_bytes) = 0;
    if ($read_length) {
        $read_bytes = read(STDIN, $buffer, $read_length,0);
    }
    if ($read_bytes < $ENV{'CONTENT_LENGTH'}) {
        $self->{$package}->{'form_truncated'} = 1;
    } else {
        $self->{$package}->{'form_truncated'} = 0;
    }

    # Default to this if they don't tell us
    my ($content_type) = 'application/x-www-form-urlencoded';

    if (defined($ENV{'CONTENT_TYPE'})) {
        $content_type = $ENV{'CONTENT_TYPE'};
    }

    my ($boundary,$form_type);
    if ($content_type =~ m#^multipart/form-data; boundary=(.*)$#oi) {
        $form_type="multipart";
        $boundary="--$1(--)?\015\012"; # Why the extra '--'? 
        $self->_burst_multipart_buffer ($buffer,$boundary);
    } elsif ($content_type =~ m#^application/x-www-form-urlencoded$#oi) {
        $form_type="xwwwformurlencoded";
        $self->_burst_URL_encoded_buffer($buffer,$form_type);
    } elsif ($content_type =~ m#^application/sgml-form-urlencoded$#oi) {
        $form_type="sgmlformurlencoded";
        $self->_burst_URL_encoded_buffer($buffer,$form_type);
    }
}

########################################################################
# Performs form reading for GET and HEAD methods                       #
########################################################################
sub _read_get {
    my $self = shift;
    my $package = __PACKAGE__;

    my ($buffer)='';
    if (exists $ENV{'MOD_PERL'}) {
              $buffer = Apache->request->args;
    } else {
              $buffer = $ENV{'QUERY_STRING'} if (defined $ENV{'QUERY_STRING'});
    }
    my ($form_type);

    if ( (! defined($ENV{'CONTENT_TYPE'})) || 
        ($ENV{'CONTENT_TYPE'} =~ m/^application\/x-www-form-urlencoded$/oi)) {
        $form_type="xwwwformurlencoded";

        # if running in SGML safe mode, do that ol' black magic
        if ($self->{$package}->{'sgml_safe_mode'}) {
            if ($buffer) {
                $buffer =~ s/\&/;/gos;
                $buffer = "?${buffer}";
            }
            print "Status: 302 Moved Temporarily\015\012",
                "Location: $ENV{SCRIPT_NAME}$ENV{PATH_INFO}$buffer\015\012\015\012";
            exit; # We're done.
        }
    } elsif ($ENV{'CONTENT_TYPE'} =~ m/^application\/sgml-form-urlencoded$/oi) {
        $form_type="sgmlformurlencoded";
    } else {
        $form_type='xwwwformurlencoded';
    }

    $self->_burst_URL_encoded_buffer($buffer,$form_type);
}

##########################################################################
# Bursts normal URL encoded buffers                                      #
# Takes: $buffer   - the actual data to be burst                         #
#        $form_type - 'xwwwformurlencoded','sgmlformurlencoded'          #
#                'xwwwformurlencoded' is old style forms                 #
#                'sgmlformurlencoded' is new style SGML compatible forms #
##########################################################################
sub _burst_URL_encoded_buffer {
    my $self = shift;
    my $package = __PACKAGE__;

    my ($buffer,$form_type)=@_;

    my ($spliton)  = '&';
    my ($mime_type) = "text/plain";
    my ($filename) = "";

    $spliton       = ';' if ($form_type eq 'sgmlformurlencoded'); # if they understand SGML encoding - do it.

    # Split the name-value pairs on the selected split char
    my @pairs = ();
    if ($buffer) {
        @pairs = split(/$spliton/, $buffer);
    }

    # Initialize the field hash and the field_names array
    $self->{$package}->{'field'}       = {};
    $self->{$package}->{'field_names'} = [];

    my $pair;
    foreach $pair (@pairs) {
        my ($name, $data) = split(/=/,$pair,2);
       
        # De-URL encode plus signs and %-encoding
        $name = $self->url_decode($name);
        $data = $self->url_decode($data);

        if (! defined ($self->{$package}->{'field'}->{$name}->{'count'})) {
            push (@{$self->{$package}->{'field_names'}},$name);
            $self->{$package}->{'field'}->{$name}->{'count'} = 0;
        }
        my $record      = $self->{$package}->{'field'}->{$name};
        my $field_count = $record->{'count'};
        $record->{'count'}++;
        $record->{'value'}->[$field_count]     = $data;
        $record->{'filename'}->[$field_count]  = $filename;
        $record->{'mime_type'}->[$field_count] = $mime_type;
    }
}

##################################################################
#
# Sets values into the object directly
# Pass an anon hash for name/value pairs. Values may be
# anon lists or simple strings
#
##################################################################

sub _set {
    my $self = shift;
    my $package = __PACKAGE__;

    my $parms = {};
    if (1 < @_) {
        $parms = { @_ };
    } elsif ((1 == @_) and (ref($_[0]) eq 'HASH')) {
        ($parms) = @_;
    } else {
        croak (__PACKAGE__ . "::_set() - Invalid or no parameters passed");
    }
    foreach my $name (keys %$parms) {
        my $value = $parms->{$name};
        my $data  = [];
        my $data_type = ref $value;
        if (not $data_type) {
            $data = [ $value ];
        } elsif ($data_type eq 'ARRAY') { 
            # Shallow copy the anon array to prevent action at a distance
            @$data = map {$_} @$value;
        } else {
            croak (__PACKAGE__ . "::_set() - Parameter '$name' has illegal data type of '$data_type'");
        }
       
        if (! defined ($self->{$package}->{'field'}->{$name}->{'count'})) {
            push (@{$self->{$package}->{'field_names'}},$name);
        }
        my $record = {};
        $self->{$package}->{'field'}->{$name} = $record;
        $record->{'count'} = @$data;
        $record->{'value'} = $data;
	my $data_entries = @$data;
        for (my $field_count=0;$field_count < $data_entries;$field_count++) {
            $record->{'filename'}->[$field_count]  = '';
            $record->{'mime_type'}->[$field_count] = 'text/plain';
        }    
    }
}

##########################################################################
# Bursts multipart mime encoded buffers                                  
# Takes: $buffer   - the actual data to be burst                         
#        $boundary - the mime boundary to split on                       
##########################################################################
sub _burst_multipart_buffer {
    my $self = shift;
    my $package = __PACKAGE__;

    my ($buffer,$boundary)=@_;

    # Split the name-value pairs
    $boundary   = quotemeta($boundary);
    my (@pairs) = split(/$boundary/, $buffer);

    # Initialize the field hash and the field_names array
    $self->{$package}->{'field'}       = {};
    $self->{$package}->{'field_names'} = [];

    my ($pair);
    foreach $pair (@pairs) {
        next if (! defined ($pair));
        chop $pair; # Trailing \015 left over from the boundary
        chop $pair; # Trailing \012 left over from the boundary
        last if ($pair eq "--");
        next if (not $pair);
        # Split the header off from the actual data
        my ($header, $data) = split(/\015\012\015\012/so,$pair,2);

        # parse the header lines
        $header =~ s/\015\012/\012/osg; # change all the \r\n to \n
        my (@headerlines) = split(/\012/so,$header);
        my ($name)        = '';
        my ($filename)    = '';
        my ($mime_type)    = 'text/plain';

        my ($headfield);
        foreach $headfield (@headerlines) {
            my ($fieldname,$fielddata) = split(/: /,$headfield);
            if ($fieldname =~ m/^Content-Type$/io) {
                $mime_type=$fielddata;
            }
            if ($fieldname =~ m/^Content-Disposition$/io) {
                my (@dispositionlist) = split(/; /,$fielddata);
                my ($dispitem);
                foreach $dispitem (@dispositionlist) {
                    next if ($dispitem eq 'form-data');
                    my ($dispfield,$dispdata) = split(/=/,$dispitem,2);
                    $dispdata =~ s/^\"//o;
                    $dispdata =~ s/\"$//o;
                    $name = $dispdata if ($dispfield eq 'name');
                    $filename = $dispdata if ($dispfield eq 'filename');
                }
            }
        }

        if (! defined ($self->{$package}->{'field'}->{$name}->{'count'})) {
            push (@{$self->{$package}->{'field_names'}},$name);
            $self->{$package}->{'field'}->{$name}->{'count'} = 0;
        }
        my $record      = $self->{$package}->{'field'}->{$name};
        my $field_count = $record->{'count'};
        $record->{'count'}++;
        $record->{'value'}->[$field_count]     = $data;
        $record->{'filename'}->[$field_count]  = $filename;
        $record->{'mime_type'}->[$field_count] = $mime_type;
    }
}

##########################################################################
# _reset_globals;
#
# Sets the CGI::Minimal object to it's initial state (before
# calling 'new' for the first time in a CGI interaction)
#
##########################################################################
sub _reset_globals {
    $form_initial_read = 1;
    $_query = {};
    bless $_query;
    my $package = __PACKAGE__;

    max_read_size(1000000);
    $_query->{$package}->{'sgml_safe_mode'} = 0;
    $_query->{$package}->{'field_names'}    = [];
    $_query->{$package}->{'field'}          = {};
}

##########################################################################

=head1 BUGS

None known.

=head1 TODO

Who knows?

=head1 AUTHORS 

Benjamin Franz <snowhare@nihongo.org>

=head1 VERSION

Version 1.04 April 2000

=head1 COPYRIGHT

Copyright (c) Benjamin Franz 1999,2000. All rights reserved.

 This program is free software; you can redistribute it
 and/or modify it under the same terms as Perl itself.

=head1 SEE ALSO

CGI

=cut

1;
