package CGI::Minimal;

# This program is free software; you can redistribute it
# and/or modify it under the same terms as Perl itself.
#
# Copyright 1999-2003 Benjamin Franz. All Rights Reserved.

use strict;

use vars qw ($_query $VERSION $form_initial_read $_BUFFER);
$VERSION = "1.10";

if (exists $ENV{'MOD_PERL'}) {
	$| = 1;
	require Apache;
}

# Necessary for form uploads under windows and other 7-bit defaulted OSes.
binmode STDIN;

# Initialize the CGI global variables
&reset_globals;

######################

sub new {

	if ($form_initial_read) {
		$_query->_read_form;
		$form_initial_read = 0;
	}
	if (exists $ENV{'MOD_PERL'}) {
		Apache->request->register_cleanup(\&CGI::Minimal::reset_globals);
	}

	$_query;
}

#########################

sub reset_globals {
	$form_initial_read = 1;
	$_query = {};
	bless $_query;
	my $package = __PACKAGE__;

	$_BUFFER = undef;
	max_read_size(1000000);
	$_query->{$package}->{'sgml_safe_mode'} = 0;
	$_query->{$package}->{'field_names'}    = [];
	$_query->{$package}->{'field'}          = {};
}

# For backward compatibility with anyone who ignored the
# orignal 'private' declaration notation before version 1.09.
sub _reset_globals { reset_globals; }

######################

sub param {
	my $self = shift;
	my $package = __PACKAGE__;

	if (1 < @_) {
		my $n_parms = @_;
		if (($n_parms % 2) == 1) {
            require Carp;
			Carp::croak(__PACKAGE__ . "::param() - Odd number of parameters (other than 1) passed");
		}
			my $parms = { @_ };
		$self->_set($parms);
		return;
	}
	if ((@_ == 1) and (ref ($_[0]) eq 'HASH')) {
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

######################

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

######################

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

######################

sub raw {
	my $self = shift;
	return if (not defined $_BUFFER);
	return $$_BUFFER;
}

######################

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

######################

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
        my $field_data = $self->{$package}->{'field'}->{$fieldname};
		my ($fieldmime,$fieldfile,$fieldvalue);
		my ($sub_field_counter)= $#{$field_data->{'value'}};
		for (my $fieldn=0;$fieldn <= $sub_field_counter;$fieldn++) {
			$fieldmime  = $field_data->{'mime_type'}->[$fieldn];
			$fieldfile  = $field_data->{'filename'}->[$fieldn];
			$fieldvalue = '[non-text value]';
			if ($fieldmime =~ m#^text/#oi) {
				$fieldvalue = $self->htmlize($field_data->{'value'}->[$fieldn]);
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

######################

sub url_encode {
	my ($self) = shift;

	my ($line)=@_;

	return ('') if (! defined ($line));

	$line=~s/([\000-\054\072-\100\176-\377])/"\%".unpack("H",$1).unpack("h",$1)/egos;
	$line;
}

######################

sub url_decode {
	my ($self) = shift;

	my ($line) = @_;

	return ('') if (! defined($line));
	$line =~ s/\+/ /gos;
	$line =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/egos;
	$line;
}

######################

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

######################

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

######################

sub truncated {
	my $self = shift;
	my $package = __PACKAGE__;

	$self->{$package}->{'form_truncated'};
}

#######################

sub max_read_size {
	my $size = shift;
	my $package = __PACKAGE__;

	$_query->{$package}->{'max_buffer'} = $size;
}

#######################
# Wrapper for form reading for GET, HEAD and POST methods

sub _read_form {
	my ($self) = shift;

	if (! defined($ENV{"REQUEST_METHOD"})) {
		my $input = <STDIN>;
		$input = '' if (not defined $input);
		$ENV{'QUERY_STRING'} = $input;
		chomp $ENV{'QUERY_STRING'};
		$self->_read_get;
		return;
	}

	my ($request_method)=$ENV{"REQUEST_METHOD"};

	if ($request_method eq 'POST') {
		$self->_read_post;
	} elsif (($request_method eq 'GET') || ($request_method eq 'HEAD')) {
		$self->_read_get;
	}
}

#######################
# Performs form reading for POST method

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
		$_BUFFER    = \$buffer;
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

	# Boundaries are _supposed_ to consist of only the following
	# characters (1-70 of them, not ending in ' '). This
	# is not the same as saying that is what they _do_ consist of.

	# A-Za-z0-9 '()+,_-./:=?

	if ($content_type =~ m#^multipart/form-data; boundary=(.*)$#oi) {
		my $boundary = $1;
		$self->_burst_multipart_buffer ($buffer,$boundary);

	} elsif ($content_type =~ m#^application/x-www-form-urlencoded$#oi) {
		$self->_burst_URL_encoded_buffer($buffer,"xwwwformurlencoded");

	} elsif ($content_type =~ m#^application/sgml-form-urlencoded$#oi) {
		$self->_burst_URL_encoded_buffer($buffer,"sgmlformurlencoded");
	}
}

#######################
# Performs form reading for GET and HEAD methods

sub _read_get {
	my $self = shift;
	my $package = __PACKAGE__;

	my ($buffer)='';
	if (exists $ENV{'MOD_PERL'}) {
			  $buffer = Apache->request->args;
	} else {
			  $buffer = $ENV{'QUERY_STRING'} if (defined $ENV{'QUERY_STRING'});
	}
	$_BUFFER = \$buffer;
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

#########################
# Bursts normal URL encoded buffers
# Takes: $buffer   - the actual data to be burst
#        $form_type - 'xwwwformurlencoded','sgmlformurlencoded'
#                'xwwwformurlencoded' is old style forms
#                'sgmlformurlencoded' is new style SGML compatible forms

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

###########################
# Sets values into the object directly
# Pass an anon hash for name/value pairs. Values may be
# anon lists or simple strings

sub _set {
	my $self = shift;
	my $package = __PACKAGE__;

	my $parms = {};
	if (1 < @_) {
		$parms = { @_ };
	} elsif ((1 == @_) and (ref($_[0]) eq 'HASH')) {
		($parms) = @_;
	} else {
        require Carp;
		Carp::croak (__PACKAGE__ . "::_set() - Invalid or no parameters passed");
	}
	foreach my $name (keys %$parms) {
		my $value = $parms->{$name};
		my $data  = [];
		my $data_type = ref $value;
		if (not $data_type) {
			$data = [ $value ];

		} elsif ($data_type eq 'ARRAY') {
			# Shallow copy the anon array to prevent action at a distance
			@$data = @$value;

		} else {
            require Carp;
			Carp::croak (__PACKAGE__ . "::_set() - Parameter '$name' has illegal data type of '$data_type'");
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

#########################
# Bursts multipart mime encoded buffers
# Takes: $buffer   - the actual data to be burst
#        $boundary - the mime boundary to split on

sub _burst_multipart_buffer {
	my $self = shift;
	my $package = __PACKAGE__;

	my ($buffer,$boundary)=@_;

	# Special case boundaries causing problems with 'split'
	# by changing them to something safe.
	# we can't just use 'quotemeta' on the boundary because
	# split doesn't actually use regexes - it just looks like
	# it does.
	if ($boundary =~ m#[$()*+?\[\]\\^|]#s) {
		my $new_boundary = $boundary;
		$new_boundary    =~ tr/$()*+?[]\\^|/ABCDEFGHIJKL/;
		my $quoted_boundary = quotemeta ($new_boundary);
		while ($buffer =~ m/$quoted_boundary/s) {
			$new_boundary    = CGI::Minimal->url_encode($new_boundary);
			$quoted_boundary = quotemeta ($new_boundary);
		}
		my $old_boundary = quotemeta($boundary);
		$buffer          =~ s/$old_boundary/$new_boundary/gs;
		$boundary        = $new_boundary;
	}

	$boundary = "--$boundary(--)?\015\012";

	# Split the name-value pairs
	my @pairs = split(/$boundary/, $buffer);

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
			my ($fieldname,$fielddata) = split(/: /,$headfield,2);
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

#########################

1;
