
package Math::Formula::Context;

use warnings;
use strict;

use Scalar::Util qw/blessed/;

my $config;

=chapter NAME

Math::Formula::Context - calculation context

=chapter SYNOPSIS

  my $context = Math::Formula::Context->new();

  my $object = MF::OBJECT->new('config');
  $context->changeObject($object);

  my $full   = Math::Formula->new(
    name       => 'is-full',
    expression => 'config.count > 1M',
    returns    => 'MF::BOOLEAN',
  );

  # single shot
  my $value  = $full->evaluate($context);

  # This value is cached
  $context->changeExpression($object, $full);  # at init
  my $value  = $context->evaluate($object, 'is-full');

  # Or even
  $context->newFormula($object, name => ...);

=chapter DESCRIPTION

Like in web template systems, evaluate of expressions can be effected by a
computation context which contains values.

=chapter METHODS

=secion Constructors

=c_method new %options

=option  objects ARRAY
=default objects []
=cut

sub new(%) { my $class = shift; (bless {}, $class)->init({@_}) }

sub init($)
{	my ($self, $args) = @_;

	$self->{MFC_objects} = { };
	$self->{MFC_cache}   = { };
	$self;
}

#--------------
=section Attributes
=cut

#--------------
=section Object management

=method object NAME
Returns the object with the indicated C<NAME>, which is either a C<MF::NAME> type
or a string.
=cut

sub object($)
{	my ($self, $name) = @_;

	$name = MF::NAME->validated($name, 'context get object')
		unless blessed $name;

	$self->{MFC_objects}{$name};
}

=method changeObject [OBJECT]
Set or change an object (C<MF::OBJECT>) in the Context.  When there is already
a different object with the same name defined, it will get unused first.
=cut

sub changeObject($)
{	my ($self, $object) = @_;
	my $name    = $object->name;
	my $objects = $self->{MFC_objects};

	if(my $old = $objects->{$name})
	{	return if $object==$old;    # no change
		$self->unuseObject($old);
	}
	else
	{	$objects->{$name} = $object;
	}

	$self;
}

=method unuseObject NAME|OBJECT
=cut

sub unuseObject($)
{	my ($self, $which) = @_;

	my $name
	  = ! blessed $which ? MF::NAME->validated($which, 'context unuse object')
	  ? $which->isa('MF::OBJECT') ? $which->name
	  : $which;

	my $objects = $self->{MFC_objects};
	$self->invalidate(delete $objects->{$name});

	$self;
}

#--------------
=section Configuration parameters

Configuration parameters are expressions: they may refer to other configuration
parameters in the same context.  The lazily computed values are carefully cached.

=method config NAME
Return the result of the configuration parameter with NAME.
=cut

sub config($)
{	my ($self, $name) = @_;
	$name = MF::NAME->validated($name, 'context get config')
		unless blessed $name;

	$self->evaluate($self->{MFC_config}, $name);
}

#--------------
=section Caching

=method invalidate OBJECT
Remove the cached value of all registed expressions.
=cut

# $cache = { $object->name => { $expression->name => $value }}

sub invalidate($)
{	my ($self, $object) = @_;
	$object or return;

	my $cache = $self->{MFC_cache};
	delete $cache->{$object->name};

	while(my ($obj_name, $cached) = each %$cache)
	{	my $object = $self->object($obj_name);
		foreach my $expr_name (keys %$cached)
		{	delete $cached->{$expr_name}
				if $object->expression($expr_name)->usesObject($object);
		}
	}

	$self;
}

=method cached OBJECT, NAME
Check whether there is a cached value for the expression with NAME in the OBJECT.
=cut

sub cached($$)
{	my ($self, $object, $expr_name) = @_;
	$self->{MFC_cache}{$object->name}{$expr_name};
}

1;
