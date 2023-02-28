package Math::Formula::Config::JSON;
use base 'Math::Formula::Config';

use warnings;
use strict;

use Log::Report 'math-formula';
use Scalar::Util  'blessed';
use File::Slurper 'read_binary';
use Cpanel::JSON::XS  ();

my $json = Cpanel::JSON::XS->new->pretty->utf8->canonical(1);

=chapter NAME

Math::Formula::Config::JSON - load/save formulas to file

=chapter SYNOPSIS

  my $context = Math::Formula::Content->new(name => 'test');
  my $config = Math::Formula::Config::INI->JSON(directory => $dir);

  $config->save($context);
  my $context = $config->load('test');

=chapter DESCRIPTION

Save and load a M<Math::Formula::Context> to JSON files.

You need to have installed B<Cpanel::JSON::XS>.  That module is not in the
dependencies of this packages, because we do not want to add complications
to the main code.

=chapter METHODS

=section Constructors
=cut

#----------------------
=section Actions

=method save $context, %args
Serialize the $context to JSON files, as storage or to be editted by hand.
This is a usefull method when default configuration templates need to be generated.

=option filename STRING
=default filename C<< $context->name .json>
Save under a different filename than derived from the name of the context.
=cut

sub save($%)
{	my ($self, $context, %args) = @_;
	my $name  = $context->name;

	my $index = $context->_index;
	my $tree  = $self->_set($index->{attributes});
	$tree->{formulas} = $self->_set($index->{formulas});

	my $fn = $self->path_for($args{filename} || "$name.json");
	open my $fh, '>:raw', $fn
		or fault __x"Trying to save context '{name}' to {fn}", name => $name, fn => $fn;

	$fh->print($json->encode($tree));
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
	if(blessed $what && $what->isa('Math::Formula::Type'))
	{	# strings without quote
		$v	= $what->isa('MF::STRING')  ? $what->value
			: $what->isa('MF::BOOLEAN') ? ($what->value ? Cpanel::JSON::XS::true : Cpanel::JSON::XS::false)
			: $what->isa('MF::FLOAT')   ? $what->value  # otherwise JSON writes a string
			: $what->token;
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
	my $fn   = $self->path_for($args{filename} || "$name.json");

	my $tree     = $json->decode(read_binary $fn);
	my $formulas = delete $tree->{formulas};

	my $attrs = $self->_set_decode($tree);
	Math::Formula::Context->new(name => $name,
		%$attrs,
		formulas => $self->_set_decode($formulas),
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

	if(ref $encoded eq 'JSON::PP::Boolean')
	{	return MF::BOOLEAN->new(undef, $encoded);
	}

	if($encoded =~ m/^\=(.*?)(?:;\s*(.*))?$/)
	{	my ($expr, $attrs) = ($1, $2 // '');
		my %attrs = $attrs =~ m/(\w+)\='([^']+)'/g;
		return Math::Formula->new($name, $expr =~ s/\\"/"/gr, %attrs);
	}

	# No JSON implementation parses floats and ints cleanly into SV
	# So, we need to check it by hand.  Gladly, ints are converted
	# to strings again when that was the intention.

	  $encoded =~ qr/^[0-9]+$/           ? MF::INTEGER->new(undef, $encoded + 0)
	: $encoded =~ qr/^[0-9][0-9.e+\-]+$/ ? MF::FLOAT->new(undef, $encoded + 0.0)
	: MF::STRING->new(undef, $encoded);
}

#----------------------
=chapter DETAILS

JSON seems to be everyone's favorit serialization syntax, nowadays.  It natively
supports integers, floats, booleans, and strings.  Formulas get a leading '='
(not yet configurable).

=example
{
   "created" : "2023-02-28T16:30:27+0000",
   "formulas" : {
      "expr1" : "=1 + 2 * 3",
      "expr2" : "=\"abc\".size + 3k; returns='MF::INTEGER'",
      "fakes" : false,
      "float" : 3.14,
      "int" : 42,
      "longer" : "abc def yes no",
      "no_quotes" : "abc",
      "some_truth" : true,
      "string" : "true"
   },
   "mf_version" : "",
   "name" : "test",
   "updated" : "2023-02-28T16:30:27+0000",
   "version" : 1.0
}
=cut

1;
