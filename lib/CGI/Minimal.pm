package CGI::Minimal;

# This program is licensed under the same terms as Perl.
# See http://dev.perl.org/licenses/
# Copyright 1999-2004 Benjamin Franz. All Rights Reserved.

use strict;

# don't 'use warnings;' here because it pulls in ~ 20Kbytes of code

use vars qw ($_query $VERSION $form_initial_read $_BUFFER);
$VERSION = "1.12";

if (exists $ENV{'MOD_PERL'}) {
	$| = 1;
	require Apache;
}

# Necessary for form uploads under 7-bit defaulted OSes.
binmode STDIN;

&reset_globals;

####

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

####

sub reset_globals {
	$form_initial_read = 1;
	$_query = {};
	bless $_query;
	my $pkg = __PACKAGE__;

	$_BUFFER = undef;
	max_read_size(1000000);
	$_query->{$pkg}->{'field_names'} = [];
	$_query->{$pkg}->{'field'} = {};
}

# For backward compatibility 
sub _reset_globals { reset_globals; }

####

sub param {
	my $self = shift;
	my $pkg = __PACKAGE__;

	if (1 < @_) {
		my $n_parms = @_;
		if (($n_parms % 2) == 1) {
			require Carp;
			Carp::croak("${pkg}::param() - Odd number of parameters (other than 1) passed");
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
	my $vars = $self->{$pkg};
	my @result = ();
	if ($#_ == -1) {
		@result = @{$vars->{'field_names'}};
	} elsif ($#_ == 0) {
		my ($fname)=@_;
		if (defined($vars->{'field'}->{$fname})) {
			@result = @{$vars->{'field'}->{$fname}->{'value'}};
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

####

sub param_mime {
	my $pkg = __PACKAGE__;
    my $vars = shift->{$pkg};

	my @result = ();
	if ($#_ == -1) {
		@result = @{$vars->{'field_names'}};
	} elsif ($#_ == 0) {
		my ($fname)=@_;
		if (defined($vars->{'field'}->{$fname})) {
			@result = @{$vars->{'field'}->{$fname}->{'mime_type'}};
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

####

sub param_filename {
	my $pkg = __PACKAGE__;
	my $vars = shift->{$pkg};

	my @result = ();
	if ($#_ == -1) {
		@result = @{$vars->{'field_names'}};
	} elsif ($#_ == 0) {
		my ($fname)=@_;
		if (defined($vars->{'field'}->{$fname})) {
			@result = @{$vars->{'field'}->{$fname}->{'filename'}};
		}
	}
	if (wantarray) { return @result; }
	elsif ($#result > -1) { return $result[0]; }
	else { return; }
}

####

sub raw {
	return if (! defined $_BUFFER);
	return $$_BUFFER;
}

####

sub date_rfc1123 {
	my $self = shift;

	my ($tick) = @_;

	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst)=gmtime($tick);

	my $wkday = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat')[$wday];
	my $month = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec')[$mon];
	$year += 1900;
	my $date = sprintf('%s, %02d %s %s %02d:%02d:%02d GMT',$wkday,$mday,$month,$year,$hour,$min,$sec);

	$date;
}

####

sub calling_parms_table {
	my $self = shift;
	my $pkg = __PACKAGE__;
    my $vars = $self->{$pkg};

	my $outs = <<"EOF";
<table border="1" cellspacing="0">
<tr>
 <th colspan="4">Form Fields</th>
</tr>

<tr>
 <th>Field</th>
 <th>Value</th>
 <th>mime Type</th>
 <th>File Name</th>
</tr>
EOF
	foreach my $fname (sort @{$vars->{'field_names'}}) {
		my $f_data = $vars->{'field'}->{$fname};
		my ($fmime,$ffile,$fvalue);
		my ($sub_field_counter)= $#{$f_data->{'value'}};
		for (my $fn=0;$fn <= $sub_field_counter;$fn++) {
			$fmime  = $f_data->{'mime_type'}->[$fn];
			$ffile  = $f_data->{'filename'}->[$fn];
			$fvalue = '[non-text value]';
			if ($fmime =~ m#^text/#oi) {
				$fvalue = $self->htmlize($f_data->{'value'}->[$fn]);
			}
		$outs .= <<"EOF";
<tr>
 <td>$fname (#$fn)</td>
 <td> $fvalue </td>
 <td>$fmime</td>
 <td>$ffile</td>
</tr>
EOF
		}
	}
	$outs .= <<"EOF";
<tr>
  <th colspan="4">Environment Variables</th>
</tr>

<tr>
  <th>Variable</th>
  <th colspan="3">Value</th>
</tr>
EOF

	foreach my $fname (sort keys (%ENV)) {
		$outs .= "<tr>\n  <td>$fname</td>\n  <td colspan=\"3\">" .
			$self->htmlize($ENV{$fname}) . "</td>\n</tr>\n";
	}

	$outs .= "</table>\n";

	$outs;
}

####

sub url_encode {
	my $self = shift;

	my ($s)=@_;

	return '' if (! defined ($s));

	$s=~s/([\000-\054\072-\100\176-\377])/"\%".unpack("H",$1).unpack("h",$1)/egs;
	$s;
}

####

sub url_decode {
	my $self = shift;

	my ($s) = @_;

	return '' if (! defined($s));
	$s =~ s/\+/ /gs;
	$s =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/egs;
	$s;
}

####

sub htmlize {
	my $self = shift;

	my ($s)=@_;

	return ('') if (! defined($s));

	$s =~ s/\&/\&amp;/gs;
	$s =~ s/>/\&gt;/gs;
	$s =~ s/</\&lt;/gs;
	$s =~ s/"/\&quot;/gs;
	$s;
}

####

sub dehtmlize {
	my $self = shift;

	my($s)=@_;;

	return ('') if (! defined($s));

	$s=~s/\&gt;/>/gs;
	$s=~s/\&lt;/</gs;
	$s=~s/\&quot;/\"/gs;
	$s=~s/\&amp;/\&/gs;

	$s;
}

####

sub truncated {
	my $pkg = __PACKAGE__;
	shift->{$pkg}->{'form_truncated'};
}

####

sub max_read_size {
	my $pkg = __PACKAGE__;
	$_query->{$pkg}->{'max_buffer'} = $_[0];
}

####
# Wrapper for form reading for GET, HEAD and POST methods

sub _read_form {
	my $self = shift;

	my $req_method=$ENV{"REQUEST_METHOD"};
	if (! defined $req_method) {
		my $input = <STDIN>;
		$input = '' if (! defined $input);
		$ENV{'QUERY_STRING'} = $input;
		chomp $ENV{'QUERY_STRING'};
		$self->_read_get;
		return;
	}

	if ($req_method eq 'POST') {
		$self->_read_post;
	} elsif (($req_method eq 'GET') || ($req_method eq 'HEAD')) {
		$self->_read_get;
	}
}

####
# Performs form reading for POST method

sub _read_post {
	my $self = shift;
	my $pkg  = __PACKAGE__;
    my $vars = $self->{$pkg};

	my $read_length = $vars->{'max_buffer'};
    my $clen = $ENV{'CONTENT_LENGTH'};
	if ($clen < $read_length) {
		$read_length = $clen;
	}

	my $buffer = '';
	my $read_bytes = 0;
	if ($read_length) {
		$read_bytes = read(STDIN, $buffer, $read_length,0);
	}
	$_BUFFER = \$buffer;
	$vars->{'form_truncated'} = ($read_bytes < $clen) ? 1 : 0;

	my $content_type = defined($ENV{'CONTENT_TYPE'}) ? $ENV{'CONTENT_TYPE'} : '';

	# Boundaries are supposed to consist of only the following
	# (1-70 of them, not ending in ' ') A-Za-z0-9 '()+,_-./:=?

	if ($content_type =~ m/^multipart\/form-data; boundary=(.*)$/i) {
		my $bdry = $1;
		$self->_burst_multipart_buffer ($buffer,$bdry);

	} else {
		$self->_burst_URL_encoded_buffer($buffer,'[;&]');
	}
}

####
# Performs reading for GET and HEAD methods

sub _read_get {
	my $self = shift;

	my $buffer = '';
	if (exists $ENV{'MOD_PERL'}) {
		$buffer = Apache->request->args;
	} else {
		$buffer = $ENV{'QUERY_STRING'} if (defined $ENV{'QUERY_STRING'});
	}
	$_BUFFER = \$buffer;
	$self->_burst_URL_encoded_buffer($buffer,'[;&]');
}

####
# Bursts normal URL encoded buffers
#: $buffer -  data to be burst
#  $spliton   - split pattern

sub _burst_URL_encoded_buffer {
	my $self = shift;
	my $pkg = __PACKAGE__;
	my $vars = $self->{$pkg};

	my ($buffer,$spliton)=@_;

	my ($mime_type) = "text/plain";
	my ($filename) = "";

	my @pairs = $buffer ? split(/$spliton/, $buffer) : ();
	$vars->{'field'} = {};
	$vars->{'field_names'} = [];

	foreach my $pair (@pairs) {
		my ($name, $data) = split(/=/,$pair,2);

		$name = $self->url_decode($name);
		$data = $self->url_decode($data);

		if (! defined ($vars->{'field'}->{$name}->{'count'})) {
			push (@{$vars->{'field_names'}},$name);
			$vars->{'field'}->{$name}->{'count'} = 0;
		}
		my $record  = $vars->{'field'}->{$name};
		my $f_count = $record->{'count'};
		$record->{'count'}++;
		$record->{'value'}->[$f_count] = $data;
		$record->{'filename'}->[$f_count]  = $filename;
		$record->{'mime_type'}->[$f_count] = $mime_type;
	}
}

####
# Sets values 
# Pass an anon hash for name/value pairs. Values may be
# anon lists or strings

sub _set {
	my $pkg = __PACKAGE__;
    my $vars = shift->{$pkg};

	my $parms = {};
	if (1 < @_) {
		$parms = { @_ };
	} elsif ((1 == @_) and (ref($_[0]) eq 'HASH')) {
		($parms) = @_;
	} else {
		require Carp;
		Carp::croak ("${pkg}::_set() - Invalid or no parameters passed");
	}
	foreach my $name (keys %$parms) {
		my $value = $parms->{$name};
		my $data  = [];
		my $data_type = ref $value;
		if (! $data_type) {
			$data = [ $value ];

		} elsif ($data_type eq 'ARRAY') {
			@$data = @$value; # Shallow copy

		} else {
			require Carp;
			Carp::croak ("${pkg}::_set() - Parameter '$name' has illegal data type of '$data_type'");
		}

		if (! defined ($vars->{'field'}->{$name}->{'count'})) {
			push (@{$vars->{'field_names'}},$name);
		}
		my $record = {};
		$vars->{'field'}->{$name} = $record;
		$record->{'count'} = @$data;
		$record->{'value'} = $data;
		my $data_entries = @$data;
		for (my $f_count=0;$f_count < $data_entries;$f_count++) {
			$record->{'filename'}->[$f_count]  = '';
			$record->{'mime_type'}->[$f_count] = 'text/plain';
		}
	}
}

####

sub _burst_multipart_buffer {
	my $self = shift;
	my $pkg = __PACKAGE__;

	my ($buffer,$bdry)=@_;

	my $vars = $self->{$pkg};

	# Special case boundaries causing problems with 'split'
	if ($bdry =~ m#[^A-Za-z0-9',-./:=]#s) {
		my $nbdry = $bdry;
		$nbdry =~ s/([^A-Za-z0-9',-.\/:=])/ord($1)/egs;
		my $quoted_boundary = quotemeta ($nbdry);
		while ($buffer =~ m/$quoted_boundary/s) {
			$nbdry = $self->url_encode($nbdry);
			$quoted_boundary = quotemeta ($nbdry);
		}
		my $old_boundary = quotemeta($bdry);
		$buffer =~ s/$old_boundary/$nbdry/gs;
		$bdry   = $nbdry;
	}

	$bdry = "--$bdry(--)?\015\012";
	my @pairs = split(/$bdry/, $buffer);

	$vars->{'field'} = {};
	$vars->{'field_names'} = [];

	foreach my $pair (@pairs) {
		next if (! defined $pair);
		chop $pair; # Trailing \015 
		chop $pair; # Trailing \012
		last if ($pair eq "--");
		next if (! $pair);

		my ($header, $data) = split(/\015\012\015\012/s,$pair,2);

		# parse the header
		$header =~ s/\015\012/\012/osg;
		my @headerlines = split(/\012/so,$header);
		my $name = '';
		my $filename = '';
		my $mime_type = 'text/plain';

		foreach my $headfield (@headerlines) {
			my ($fname,$fdata) = split(/: /,$headfield,2);
			if ($fname =~ m/^Content-Type$/io) {
				$mime_type=$fdata;
			}
			if ($fname =~ m/^Content-Disposition$/io) {
				my @dispositionlist = split(/; /,$fdata);
				foreach my $dispitem (@dispositionlist) {
					next if ($dispitem eq 'form-data');
					my ($dispfield,$dispdata) = split(/=/,$dispitem,2);
					$dispdata =~ s/^\"//o;
					$dispdata =~ s/\"$//o;
					$name = $dispdata if ($dispfield eq 'name');
					$filename = $dispdata if ($dispfield eq 'filename');
				}
			}
		}

		if (! defined ($vars->{'field'}->{$name}->{'count'})) {
			push (@{$vars->{'field_names'}},$name);
			$vars->{'field'}->{$name}->{'count'} = 0;
		}
		my $record = $vars->{'field'}->{$name};
		my $f_count = $record->{'count'};
		$record->{'count'}++;
		$record->{'value'}->[$f_count] = $data;
		$record->{'filename'}->[$f_count]  = $filename;
		$record->{'mime_type'}->[$f_count] = $mime_type;
	}
}

####

1;
