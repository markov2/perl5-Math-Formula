package Math::Formula::Config::YAML;
use base 'Math::Formula::Config';

use warnings;
use strict;

use Log::Report 'math-formula';

use YAML::XS 0.81;
use boolean ();
use File::Slurper 'read_binary';

# It is not possible to use YAML.pm, because it cannot produce output where
# boolean true and a string with content 'true' can be distinguished.

use Scalar::Util 'blessed';

=chapter NAME

Math::Formula::Config::YAML - load/save formulas to file in YAML

=chapter SYNOPSIS

  my $context = Math::Formula::Content->new(name => 'test');
  my $config  = Math::Formula::Config::YAML->new(directory => $dir);

  $config->save($context);
  my $context = $config->load('test');

=chapter DESCRIPTION

Write a Context to file, and read it back again.

The attributes, formulas, and fragments are written as three separate documents.

You need to have installed B<YAML::XS>, minimal version 0.81 (for security reasons)
and module C<boolean.pm>.  They are not in the dependencies of this packages, because
we do not want to add complications to the main code.

=chapter METHODS

=section Constructors
=cut

#----------------------
=section Actions

=method save $context, %args
Serialize the $context to YAML files, as storage or to be editted by hand.
This is a usefull method when default configuration templates need to be generated.

=option filename STRING
=default filename C<< $context->name .yml>
Save under a different filename than derived from the name of the context.
=cut

sub save($%)
{	my ($self, $context, %args) = @_;
	my $name  = $context->name;

 	local $YAML::XS::Boolean = "boolean";
	my $index = $context->_index;

	my $fn = $self->path_for($args{filename} || "$name.yml");
	open my $fh, '>:encoding(utf8)', $fn
		or fault __x"Trying to save context '{name}' to {fn}", name => $name, fn => $fn;

	$fh->print(Dump $self->_set($index->{attributes}));
	$fh->print(Dump $self->_set($index->{formulas}));
	$fh->print(Dump $self->_set($index->{fragments}));

	$fh->close
		or fault __x"Error on close while saving '{name}' to {fn}", name => $name, fn => $fn;
}

sub _set($)
{	my ($self, $set) = @_;
	my %data;
	$data{$_ =~ s/^ctx_//r} = $self->_serialize($_, $set->{$_}) for keys %$set;
	\%data;
}

sub _serialize($$)
{	my ($self, $name, $what) = @_;
	my %attrs;

	if(blessed $what && $what->isa('Math::Formula'))
	{	if(my $r = $what->returns) { $attrs{returns} = $r };
		$what = $what->expression;
	}

	my $v = '';
	if(blessed $what && $what->isa('MF::STRING'))
	{	$v = $what->value;
	}
	elsif(blessed $what && $what->isa('Math::Formula::Type'))
	{	$v	= $what->isa('MF::INTEGER') || $what->isa('MF::FLOAT') ? $what->value
			: $what->isa('MF::BOOLEAN') ? ($what->value ? boolean::true : boolean::false)
			: '=' . $what->token;
	}
	elsif(ref $what eq 'CODE')
	{	warning __x"cannot (yet) save CODE, skipped '{name}'", name => $name;
		return undef;
	}
	elsif(length $what)
	{	$v = '=' . $what;
	}

	if(keys %attrs)
	{	$v .= '; ' . (join ', ', map "$_='$attrs{$_}'", sort keys %attrs);
	}

	return $v;
}

=method load $name, %options
Load a M<Math::Formula::Context> for a yml file.

=option  filename FILENAME
=default filename <directory/$name.yml>

=cut

sub load($%)
{	my ($self, $name, %args) = @_;
	my $fn   = $self->path_for($args{filename} || "$name.yml");

	local $YAML::XS::Boolean = "boolean";
	my ($attributes, $forms, $frags) = Load(read_binary $fn);

	my $attrs = $self->_set_decode($attributes);
	Math::Formula::Context->new(name => $name,
		%$attrs,
		formulas => $self->_set_decode($forms),
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

	if(ref $encoded eq 'boolean')
	{	return MF::BOOLEAN->new(undef, $encoded);
	}

	if($encoded =~ m/^\=(.*?)(?:;\s*(.*))?$/)
	{	my ($expr, $attrs) = ($1, $2 // '');
		my %attrs = $attrs =~ m/(\w+)\='([^']+)'/g;
		return Math::Formula->new($name, $expr =~ s/\\"/"/gr, %attrs);
	}

	  $encoded =~ qr/^[0-9]+$/           ? MF::INTEGER->new($encoded)
	: $encoded =~ qr/^[0-9][0-9.e+\-]+$/ ? MF::FLOAT->new($encoded)
	: MF::STRING->new(undef, $encoded);
}

#----------------------
=chapter DETAILS

YAML has a super powerfull syntax, which natively supports integers,
floats, booleans, and strings.  But it can do so much more!  (What we
are not gonna use (yet))

The Context's attributes are in the first document.  The formulas are
in the second document.  The fragments will get a place in the third
document (but are not yet supported).

On Perl, you will need M<YAML::XS> to be able to treat booleans
correctly.  For instance, C<YAML.pm> will create a string with content
'true' without quotes... which makes it a boolean.

=example
  ---
  created: =2023-02-27T15:54:54+0000
  mf_version: ''
  name: test
  updated: =2023-02-27T15:54:54+0000
  version: '1.00'
  ---
  expr1: =1 + 2 * 3
  expr2: ="abc".size + 3k; returns='MF::INTEGER'
  fakes: false
  float: 3.14
  int: 42
  longer: abc def yes no
  no_quotes: abc
  some_truth: true
  string: 'true'
  ---
=cut

1;
