
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

  my $full   = Math::Formula->new(is_full => 'config.count > 1M');

  # single shot
  my $value  = $full->evaluate($context)->value;
  my $value  = $full->value($context);

  # Or even
  $context->newFormula($object, name => ...);

=chapter DESCRIPTION

Like in web template systems, evaluate of expressions can be effected by a
computation context which contains values.

=chapter METHODS

=section Constructors

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

=method addObject [OBJECT]
Add an object (C<MF::OBJECT>) in the Context.  When there is already
a different object with the same name defined, it will get unused first.
=cut

sub addObject($)
{	my ($self, $object) = @_;
	$self->{MFC_objects}{$object->name} = $object;
}

=method unuseObject NAME|OBJECT
=cut

sub unuseObject($)
{	my ($self, $which) = @_;

	my $name
	  = ! blessed $which ? MF::NAME->validated($which, 'context unuse object')
	  : $which->isa('MF::OBJECT') ? $which->name
	  : $which;

	my $objects = $self->{MFC_objects};
	delete $objects->{$name};

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

=method cached OBJECT, NAME
Check whether there is a cached value for the expression with NAME in the OBJECT.
=cut

sub cached($$)
{	my ($self, $object, $expr_name) = @_;
	$self->{MFC_cache}{$object->name}{$expr_name};
}

1;
