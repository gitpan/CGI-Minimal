package CGI::Minimal;

use strict;

# This program is licensed under the same terms as Perl.
# See http://dev.perl.org/licenses/
# Copyright 1999-2004 Benjamin Franz. All Rights Reserved.
#
# I don't 'use warnings;' here because it pulls in ~ 40Kbytes of code
# I don't use vars qw ($_query $VERSION $form_initial_read $_BUFFER); for
# same reason. The code is clean - but the pragmas cause performance issues.

$CGI::Minimal::_query            = undef;
$CGI::Minimal::form_initial_read = undef;
$CGI::Minimal::_BUFFER           = undef;

BEGIN {
	$CGI::Minimal::VERSION = "1.18";
    if (exists $ENV{'MOD_PERL'}) {
	    $| = 1;
	    require Apache;
	    require CGI::Minimal::Misc;
	    require CGI::Minimal::Multipart;
    }
}

binmode STDIN;
reset_globals();

####

sub import {
	my $class = shift;
	my @values = @_;
	if (grep(/^:preload$/, @values)) {
		require CGI::Minimal::Misc;
		require CGI::Minimal::Multipart;
	}
}

####

sub new {

	if ($CGI::Minimal::form_initial_read) {
		binmode STDIN;
		$CGI::Minimal::_query->_read_form;
		$CGI::Minimal::form_initial_read = 0;
	}
	if (exists $ENV{'MOD_PERL'}) {
		Apache->request->register_cleanup(\&CGI::Minimal::reset_globals);
	}

	return $CGI::Minimal::_query;
}

####

sub reset_globals {
	$CGI::Minimal::form_initial_read = 1;
	$CGI::Minimal::_query = {};
	bless $CGI::Minimal::_query;
	my $pkg = __PACKAGE__;

	$CGI::Minimal::_BUFFER = undef;
	max_read_size(1000000);
	$CGI::Minimal::_query->{$pkg}->{'field_names'} = [];
	$CGI::Minimal::_query->{$pkg}->{'field'} = {};
	$CGI::Minimal::_query->{$pkg}->{'form_truncated'} = undef;
}

# For backward compatibility 
sub _reset_globals { reset_globals; }

###

sub delete_all { 
    my $self = shift;
    my $pkg  = __PACKAGE__;
	$CGI::Minimal::_query->{$pkg}->{'field_names'} = [];
	$CGI::Minimal::_query->{$pkg}->{'field'} = {};
    return;
}

####

sub delete {
	my $self = shift;
	my $pkg  = __PACKAGE__;
	my $vars = $self->{$pkg};
	
	my @names_list   = @_;
	my %tagged_names = map { $_ => 1 } @names_list;    
	my @parm_names   = @{$vars->{'field_names'}};
	my $fields       = [];
	my $data         = $vars->{'field'};
	foreach my $parm (@parm_names) {
		if ($tagged_names{$parm}) {
			delete $data->{$parm};
		} else {
			push (@$fields, $parm);
		}
	}
	$vars->{'field_names'} = $fields;
	return;
}

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
		require CGI::Minimal::Misc;
		$self->_internal_set($parms);
		return;

	} elsif ((@_ == 1) and (ref ($_[0]) eq 'HASH')) {
		my $parms = shift;
		require CGI::Minimal::Misc;
		$self->_internal_set($parms);
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
	if    (wantarray)     { return @result;    }
	elsif ($#result > -1) { return $result[0]; }
	return;
}

####

sub raw {
	return if (! defined $CGI::Minimal::_BUFFER);
	return $$CGI::Minimal::_BUFFER;
}


####

sub truncated {
	my $pkg = __PACKAGE__;
	shift->{$pkg}->{'form_truncated'};
}

####

sub max_read_size {
	my $pkg = __PACKAGE__;
	$CGI::Minimal::_query->{$pkg}->{'max_buffer'} = $_[0];
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
	$CGI::Minimal::_BUFFER = \$buffer;
	$vars->{'form_truncated'} = ($read_bytes < $clen) ? 1 : 0;

	my $content_type = defined($ENV{'CONTENT_TYPE'}) ? $ENV{'CONTENT_TYPE'} : '';

	# Boundaries are supposed to consist of only the following
	# (1-70 of them, not ending in ' ') A-Za-z0-9 '()+,_-./:=?

	if ($content_type =~ m/^multipart\/form-data; boundary=(.*)$/i) {
		my $bdry = $1;
		require CGI::Minimal::Multipart;
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
	$CGI::Minimal::_BUFFER = \$buffer;
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

		$name = '' unless (defined $name);
		$name =~ s/\+/ /gs;
		$name =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/egs;
		$data = '' unless (defined $data);
		$data =~ s/\+/ /gs;
		$data =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/egs;

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

sub url_encode {
	my $self = shift;
	my ($s)=@_;
	return '' if (! defined ($s));
	$s=~s/([^-_.a-zA-Z0-9])/"\%".unpack("H",$1).unpack("h",$1)/egs;
	$s;
}

####

sub param_mime     { require CGI::Minimal::Multipart; &_internal_param_mime(@_);      }
sub param_filename { require CGI::Minimal::Multipart; &_internal_param_filename(@_);  }
sub date_rfc1123   { require CGI::Minimal::Misc; &_internal_date_rfc1123(@_);         }
sub dehtmlize      { require CGI::Minimal::Misc; &_internal_dehtmlize(@_);            }
sub url_decode     { require CGI::Minimal::Misc; &_internal_url_decode(@_);           }
sub calling_parms_table { require CGI::Minimal::Misc; &_internal_calling_parms_table(@_); }

####

1;

