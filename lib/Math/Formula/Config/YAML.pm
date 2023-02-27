package Math::Formula::Config::YAML;
use base 'Math::Formula::Config';

use warnings;
use strict;

use Log::Report 'math-formula';

use YAML;
use Scalar::Util 'blessed';

=chapter NAME

Math::Formula::Config::YAML - load/save formulas to file in YAML

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=section Constructors
=cut

#------------------

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

	my $index = $context->_index;

	my $fn = $self->path_for($args{filename} || "$name.yml");
	open my $fh, '>:encoding(utf8)', $fn
		or fault __x"Trying to save context '{name}' to {fn}", name => $name, fn => $fn;

	local $YAML::UseHeader = 0;
	$fh->print("--- context attributes\n");
	$fh->print(Dump $self->_set($index->{attributes}));
	$fh->print("--- formulas\n");
	$fh->print(Dump $self->_set($index->{formulas}));
	$fh->print("--- fragments\n");

	$fh->close
		or fault __x"Error on close while saving '{name}' to {fn}", name => $name, fn => $fn;
}

sub _set($)
{	my ($self, $set) = @_;
	my %data;
	$data{$_ =~ s/^ctx_//r} = $self->_serialize($_, $set->{$_}) for keys %$set;

	$data{noq} = 'aap';
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
	{	$v	= ($what->isa('MF::INTEGER') || $what->isa('MF::FLOAT') ? '' : '=')
			. $what->token;
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

1;
