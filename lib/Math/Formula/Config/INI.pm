#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Math::Formula::Config::INI;
use parent 'Math::Formula::Config';

use warnings;
use strict;

use Log::Report 'math-formula';
use Scalar::Util 'blessed';

use Config::INI::Writer  ();
use Config::INI::Reader  ();

use Math::Formula::Context ();
use Math::Formula          ();

#--------------------
=chapter NAME

Math::Formula::Config::INI - load/save formulas to file as INI

=chapter SYNOPSIS

  my $context = Math::Formula::Content->new(name => 'test');
  my $config  = Math::Formula::Config::INI->new(directory => $dir);

  $config->save($context);
  my $context = $config->load('test');

=chapter DESCRIPTION

Save and load a Math::Formula::Context to INI files.  The INI file
is not too complex.

You need to have installed B<Config::INI>.  That module is not in the
dependencies of this packages, because we do not want to add complications
to the main code.

=chapter METHODS

=section Constructors
=cut

#--------------------
=section Actions

=method save $context, %options
Serialize the $context to INI files, as storage or to be edited by hand.
This is a useful method when default configuration templates need to be generated.

=option filename STRING
=default filename C<< $context->name .ini >>
Save under a different filename than derived from the name of the context.

=warning cannot (yet) save CODE, skipped '$name'
=cut

sub save($%)
{	my ($self, $context, %args) = @_;
	my $name  = $context->name;

	my $index = $context->_index;
	my %tree  = (
		_        => $self->_set_encode($index->{attributes}),
		formulas => $self->_set_encode($index->{formulas}),
	);

	my $fn = $self->path_for($args{filename} || "$name.ini");
	Config::INI::Writer->write_file(\%tree, $fn);
}

sub _set_encode($)
{	my ($self, $set) = @_;
	my %data;
	$data{$_ =~ s/^ctx_//r} = $self->_serialize($_, $set->{$_}) for keys %$set;
	\%data;
}

sub _double_quoted($) { '"' . ($_[0] =~ s/"/\\"/gr) . '"' }

sub _serialize($$)
{	my ($self, $name, $what) = @_;
	my %attrs;

	if(blessed $what && $what->isa('Math::Formula'))
	{	if(my $r = $what->returns) { $attrs{returns} = $r };
		$what = $what->expression;
	}

	my $v = '';
	if(blessed $what && $what->isa('Math::Formula::Type'))
	{	# No attributes possible for simple types
		return $what->value
			if $what->isa('MF::STRING') || $what->isa('MF::FLOAT') || $what->isa('MF::INTEGER');

		$v = _double_quoted($what->token);
	}
	elsif(ref $what eq 'CODE')
	{	warning __x"cannot (yet) save CODE, skipped '{name}'", name => $name;
		return undef;
	}
	elsif(length $what)
	{	$v = _double_quoted $what;
	}

	if(keys %attrs)
	{	$v .= '; ' . (join ', ', map "$_='$attrs{$_}'", sort keys %attrs);
	}

	return $v;
}

=method load $name, %options
Load a Math::Formula::Context for an INI file.

=option  filename FILENAME
=default filename <directory/$name.ini>

=cut

sub load($%)
{	my ($self, $name, %args) = @_;
	my $fn = $self->path_for($args{filename} || "$name.ini");

	my $read  = Config::INI::Reader->read_file($fn);
	my $attrs = $self->_set_decode($read->{_});
	Math::Formula::Context->new(name => $name, %$attrs,
		formulas => $self->_set_decode($read->{formulas}),
	);
}

sub _set_decode($)
{	my ($self, $set) = @_;
	$set or return {};

	my %forms;
	$forms{$_} = $self->_unpack($_, $set->{$_}) for keys %$set;
	\%forms;
}

sub _unpack($$)
{	my ($self, $name, $encoded) = @_;
	my $dummy = Math::Formula->new('dummy', '7');

	if($encoded =~ m/^"(.*?)"(?:;\s*(.*))?$/)
	{	my ($expr, $attrs) = ($1, $2 // '');
		my %attrs = $attrs =~ m/(\w+)\='([^']+)'/g;
		return Math::Formula->new($name, $expr =~ s/\\"/"/gr, %attrs);
	}

	  $encoded =~ qr/^[0-9]+$/           ? MF::INTEGER->new($encoded)
	: $encoded =~ qr/^[0-9][0-9.e+\-]+$/ ? MF::FLOAT->new($encoded)
	: MF::STRING->new(undef, $encoded);
}

#--------------------
=chapter DETAILS

L<According to Wikipedia|https://en.wikipedia.org/wiki/INI_file>, INI files only
support strings and numbers.  To stay as close as possible to that
description, everything else is put between double quotes (also the
booleans).

Only the quoted data may contain attributes.

=example
  name    = test
  version = 1
  created = "2023-02-26T20:07:54+0000"
  updated = "2023-02-26T20:07:54+0000"
  mf_version = 0

  [formulas]
  expr2 = "\"abc\".size + 3k"; returns='MF::INTEGER'
  fakes = "false"
  dinertime = "18:05:07"
  expr1 = "1 + 2 * 3"
  string = abc
  some_truth = "true"
=cut

1;
