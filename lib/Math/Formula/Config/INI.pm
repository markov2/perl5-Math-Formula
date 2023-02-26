package Math::Formula::Config::INI;
use base 'Math::Formula::Config';

use warnings;
use strict;

use Log::Report 'math-formula';
use Scalar::Util 'blessed';
use Config::INI::Writer  ();

=chapter NAME

Math::Formula::Config::INI - load/save formulas to file as INI

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=section Constructors
=cut

#------------------

=method save $context, %args
Serialize the $context to INI files, as storage or to be editted by hand.
This is a usefull method when default configuration templates need to be generated.

=option filename STRING
=default filename C<< $context->name .ini>
Save under a different filename than derived from the name of the context.
=cut

sub save($%)
{	my ($self, $context, %args) = @_;
	my $name  = $context->name;

	my $index = $context->_index;
	my %tree  = (
		_        => $self->_set($index->{attributes}),
		formulas => $self->_set($index->{formulas}),
	);

	my $fn = $self->path_for($args{filename} || "$name.ini");
	Config::INI::Writer->write_file(\%tree, $fn);
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
		$v	= $what->token;
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
