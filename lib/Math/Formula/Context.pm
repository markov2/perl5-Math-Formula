
package Math::Formula::Context;

use warnings;
use strict;

use Log::Report 'math-formula';
use Scalar::Util qw/blessed/;

my $config;

=chapter NAME

Math::Formula::Context - calculation context

=chapter SYNOPSIS

  my $context = Math::Formula::Context->new();

=chapter DESCRIPTION

Like in web template systems, evaluation of expressions can be effected by the
computation context which contains values.  The Context object manages these
values: it runs the right expressions.

=chapter METHODS

=section Constructors

=c_method new %options
Many of the %options make sense when this context is reloaded for file.

=option formula $form|ARRAY
One or more formula, passed to M<add()>.
=cut

sub new(%) { my $class = shift; (bless {}, $class)->init({@_}) }

sub _default($$$$)
{	my ($self, $name, $type, $value, $default) = @_;
	my $form
	  = ! $value         ? $type->new(undef, $default)
	  : ! blessed $value ? ($value ? Math::Formula->new($name, $value) : undef)
	  : $value->isa('Math::Formula') ? $value
	  : error __x"unexpected value for '{name}' in #{context}", name => $name, context => $self->name;
}

sub init($)
{	my ($self, $args) = @_;
	my $name   = $self->{MFC_name}   = $args->{name} or error __x"context without a name";

	my $config = $self->{MFC_config} =  MF::FRAGMENT->new(config => $self, attributes => {
		name       => MF::NAME->new($name),
		mf_version => MF::STRING->new(undef, $Math::Formula::VERSION),
		version    => $args->{version} ? MF::STRING->new($args->{version}) : undef,
		created    => $self->_default(created => 'MF::DATETIME', $args->{created}, DateTime->now),
	});

	if(my $forms = $args->{formula})
	{	$self->add(ref $forms eq 'ARRAY' ? @$forms : $forms);
	}

	$self->{MFC_claims} = { };
	$self;
}

#--------------
=section Attributes

=method name
Contexts are required to have a name.  Usually, this is the name of the fragment as
well.

=method config
Returns an MF_OBJECT which contains all information other expressions can use about the
active context (or fragment).
=cut

sub name   { $_[0]->{MFC_name} }
sub config { $_[0]->{MFC_config} }

#--------------
=section Formula and Fragment management

=method add LIST
Add one or more items to the context.

When a LIST is used and the first argument is a name, then the data is
used to create a $formula or fragment (when the name starts with a '#').  

Otherwise, the LIST is a sequence of prepared formulas and fragments,
or a HASH with 

=examples:
  $context->add(wakeup => '07:00:00', returns => 'MF::TIME');
  
  my $form = Math::Formula->new(wakeup => '07:00:00', returns => 'MF::TIME');
  $context->add($form, @more_forms, @fragments, @hashes);
  
  my %library = (
    breakfast => 'wakeup + P2H',
	to_work   => 'PT10M',    # mind the 'T': minutes not months
    work      => [ 'breakfast + to_work', returns => 'MF::TIME' ],
	#filesys  => $fragment,
  );
  $context->add($form, \%library, $frag);

#XXX example with fragment
=cut

sub add(@)
{	my $self = shift;
	unless(ref $_[0])
	{	my $name = shift;
		return $name =~ s/^#// ? $self->addFragment($name, @_) : $self->addFormula($name, @_);
	}

	foreach my $obj (@_)
	{	if(ref $obj eq 'HASH')
		{	$self->add($_, $obj->{$_}) for keys %$obj;
		}
		elsif(blessed $obj && $obj->isa('Math::Formula'))
		{	$self->{MFC_forms}{$obj->name} = $obj;
		}
		elsif(blessed $obj && $obj->isa('Math::Formula::Context'))
		{	$self->{MFC_frags}{$obj->name} = $obj;
		}
		else
		{	panic __x"formula add '{what}' not understood", what => $obj;
		}
	}

	undef;
}

=method addFormula LIST
Add a single formula to this context.  The formula is returned.
=examples
  $context->addFormula($form);            # already created somewhere else
  $context->addFormula(wakeup => $form);  # register under a (different) name
  $context->addFormula(wakeup => '07:00:00', returns => 'MF::TIME');
  $context->addFormula(wakeup => [ '07:00:00', returns => 'MF::TIME' ]);
=cut

sub addFormula(@)
{	my ($self, $first) = (shift, shift);

	my ($name, $form) =
	  !@_ && blessed $first && $first->isa('Math::Formula')
	? ($first->name, $first)
	: @_==1 && !ref $first && blessed $_[0] && $_[0]->isa('Math::Formula')
	? ($first, $_[0])
	: @_==1 && !ref $first && ref $_[0] eq 'ARRAY'
	? ($first, Math::Formula->new($first, @{$_[0]}))
	: @_ && !ref $first && !ref $_[0]
	? ($first, Math::Formula->new($first, @_))
	: panic __x"formula declaration '{name}' not understood", name => $first;

	$self->{MFC_forms}{$name} = $form;
}

=method formula $name
Returns the formula with this specified name.
=cut

sub formula($) { $_[0]->{MFC_forms}{$_[1]} }

=method evaluate $name, %options
Evaluate the expresion with the $name.  Returns a types object, or C<undef>
when not found.
=cut

sub evaluate($$%)
{	my ($self, $name) = (shift, shift);

	# Wow, I am impressed!
	length $name or return $self->config;

	# silently ignore missing tags
	my $form = $self->formula($name);
	unless($form)
	{	warning __x"no formula '{name}' in {context}", name => $name, context => $self->name;
panic;
		return undef;
	}

	my $claims = $self->{MFC_claims};
	! $claims->{$name}++
		or error __x"recursion in expression '{name}' at {context}", name => $name, context => $self->name;

	my $result = $form->evaluate($self, @_);

	delete $claims->{$name};
	$result;
}

#--------------
=section Caching
=cut

#--------------
=chapter DETAILS

=section Creating an interface to an object

For safity reasons, the formulars can not directly call methods on data
objects, but need to use a well defined interface which hides the internals
of your program.  Some (Perl) people call this "inside-out objects".

With introspection, it would be quite simple to offer access to, for instance,
a DateTime object which implements the DATETIME logic.  This would, however,
open a pit full of security and compatibility worms.  So: the DATETIME object
will only offer a small set of B<attributes>, which produce results also
provided by other time computing libraries.

The way to create an interface looks: (first the long version)

  use Math::Formula::Type;
  my $object    = ...something in the program ...;
  sub handle_size($$%)
  {   my ($context, $expr, %args) = @_;
      MF::INTEGER->new($object->compute_the_size);
  }

  my $name      = $object->name;  # f.i. "file"
  my $interface = MF::OBJECT->new($name);
  $interface->addAttribute(size => \&handle_size);
  $context->addFragment($interface);

  my $expr   = Math::Formula->new(allocate => '#file.size * 10k');
  my $result = $expr->evaluate($context, expect => 'MF::INTEGER');
  print $result->value;

Of course, there are various simplifications possible, when the calculations
are not too complex:

  my $filename  = '...';
  $context->addFragment(file =>
    attributes => {
      name     => $filename
      size     => sub { MF::INTEGER->new(-s $filename) },
      is_image => 'name =~ "*.{jpg,png,gif}"',
    });
  $context->addAttribute(allocate => '#file.size * 10k');
  print $context->value('#file.allocate');

For clarity: the three syntaxes:

  .name           an attribute to the context
  allocate        a formula in the context
  allocate.abs    an attribute of the expression result
  #file           interface to an object, registered in the context
  #file.size      an attribute to an object
  #filesys.file(name).size   file(name) produces an object

=cut

1;
