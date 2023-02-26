
package Math::Formula::Context;

use warnings;
use strict;

use Log::Report 'math-formula';
use Scalar::Util qw/blessed/;

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

=option  formula $form|ARRAY
=default formula C< [] >
One or more formula, passed to M<add()>.
=cut

sub new(%) { my $class = shift; (bless {}, $class)->init({@_}) }

sub _default($$$$)
{	my ($self, $name, $type, $value, $default) = @_;
	my $form
	  = ! $value         ? $type->new(undef, $default)
	  : ! blessed $value ? ($value ? Math::Formula->new($name, $value) : undef)
	  : $value->isa('Math::Formula')       ? $value
	  : $value->isa('Math::Formula::Type') ? $value
	  : error __x"unexpected value for '{name}' in #{context}", name => $name, context => $self->name;
}

sub init($)
{	my ($self, $args) = @_;
	my $name   = $args->{name} or error __x"context requires a name";
	my $node   = blessed $name ? $name : MF::STRING->new(undef, $name);
	$self->{MFC_name}   = $node->value;

	my $now;
	$self->{MFC_attrs} = {
		ctx_name       => $node,
		ctx_version    => $self->_default(version => 'MF::STRING',   $args->{version}, "1.00"),
		ctx_created    => $self->_default(created => 'MF::DATETIME', $args->{created}, $now = DateTime->now),
		ctx_updated    => $self->_default(updated => 'MF::DATETIME', $args->{updated}, $now //= DateTime->now),
		ctx_mf_version => $self->_default(mf_version => 'MF::STRING', $args->{mf_version}, $Math::Formula::VERSION),
	};

	$self->{MFC_forms}  = { };
	$self->{MFC_frags}  = { };
	if(my $forms = $args->{formulas})
	{	$self->add(ref $forms eq 'ARRAY' ? @$forms : $forms);
	}

	$self->{MFC_claims} = { };
	$self;
}

# For save()
sub _index()
{	my $self = shift;
	 +{	attributes => $self->{MFC_attrs},
		formulas   => $self->{MFC_forms},
		fragments  => $self->{MFC_frags},
	  };
}

#--------------
=section Attributes

=method name
Contexts are required to have a name.  Usually, this is the name of the fragment as
well.

=cut

sub name   { $_[0]->{MFC_name} }

#--------------
=section Fragment (this context) attributes

Basic data types usually have attributes (string C<length>), which operator on the type
to produce some fact.  The fragment type (which manages Context objects), however,
cannot distinguish between attributes and formula names: both use the dot (C<.>)
operator.  Therefore, all context attributes will start with C<ctx_>.

The following attributes are currently defined:

  ctx_name        MF::STRING    same as $context->name
  ctx_version     MF::STRING    optional version of the context data
  ctx_created     MF::DATETIME  initial creation of this context data
  ctx_updated     MF::DATETIME  last save of this context data
  ctx_mf_version  MF::STRING    Math::Formula version, useful for read/save

=method attribute $name
=cut

sub attribute($)
{	my ($self, $name) = @_;
	my $def = $self->{MFC_attrs}{$name} or return;
	Math::Formula->new($name => $def);
}

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

=cut
#XXX example with fragment

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
  $context->addFormula(wakeup => sub { '07:00:00' }, returns => 'MF::TIME' ]);
  $context->addFormula(wakeup => MF::TIME->new('07:00:00'));
=cut

sub addFormula(@)
{	my ($self, $first) = (shift, shift);
	my $next = $_[0];

	my ($name, $form) =
	  !@_ && blessed $first && $first->isa('Math::Formula')
	? ($first->name, $first)
	: @_==1 && !ref $first && blessed $next && $next->isa('Math::Formula')
	? ($first, $next)
	: @_==1 && !ref $first && ref $next eq 'ARRAY'
	? ($first, Math::Formula->new($first, @{$next}))
	: @_ && !ref $first &&
		 (!ref $next || ref $next eq 'CODE' || blessed $next && $next->isa('Math::Formula::Type'))
	? ($first, Math::Formula->new($first, @_))
	: panic __x"formula declaration '{name}' not understood", name => $first;

	$self->{MFC_forms}{$name} = $form;
}

=method formula $name
Returns the formula with this specified name.
=cut

sub formula($) { $_[0]->{MFC_forms}{$_[1]} }

=method addFragment [$name], $fragment
A $fragment is simply a different Context.  Fragments are addressed via the '#'
operator.
=cut

sub addFragment($;$)
{	my $self = shift;
	my ($name, $fragment) = @_==2 ? @_ : ($_[0]->name, $_[0]);
	$self->{MFC_frags}{$name} = MF::FRAGMENT->new($name, $fragment);
}

=method fragment $name
Returns the fragment (context) with $name.  This is not sufficient to switch
between contexts, which is done during execution.
=cut

sub fragment($) { $_[0]->{MFC_frags}{$_[1]} }

=method evaluate $name, %options
Evaluate the expresion with the $name.  Returns a types object, or C<undef>
when not found.  The %options are passed to M<Math::Formula::evaluate()>.
=cut

sub evaluate($$%)
{	my ($self, $name) = (shift, shift);

	# Wow, I am impressed!  Caused by prefix(#,.) -> infix
	length $name or return $self;

	my $form = $name =~ /^ctx_/ ? $self->attribute($name) : $self->formula($name);
	unless($form)
	{	warning __x"no formula '{name}' in {context}", name => $name, context => $self->name;
		return undef;
	}

	my $claims = $self->{MFC_claims};
	! $claims->{$name}++
		or error __x"recursion in expression '{name}' at {context}",
			name => $name, context => $self->name;

	my $result = $form->evaluate($self, @_);

	delete $claims->{$name};
	$result;
}

=method run $expression, %options
Singleshot an expression: the expression will be run in this context but
not get a name.  A temporary M<Math::Formula> object is created and
later destroyed.  The %options are passed to M<Math::Formula::evaluate()>.

=option  name $name
=default name <caller's filename and linenumber>
The name may appear in error messages.
=cut

sub run($%)
{	my ($self, $expr, %args) = @_;
	my $name  = delete $args{name} || join '#', (caller)[1,2];
	my $result = Math::Formula->new($name, $expr)->evaluate($self, %args);

	while($result && $result->isa('MF::NAME'))
	{	$result = $self->evaluate($result->token, %args);
	}

	$result;
}

=method value $expression, %options
First run the $expression, then return the value of the returned type object.
All options are passed to M<run()>.
=cut

sub value($@)
{	my $self = shift;
	my $result = $self->run(@_);
	$result ? $result->value : undef;
}

#--------------
=chapter DETAILS

=section Creating an interface to an object (fragment)

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
  my $interface = Math::Formala::Context->new(name => $name);
  $interface->addAttribute(size => \&handle_size);
  $context->addFragment($interface);

  my $expr   = Math::Formula->new(allocate => '#file.size * 10k');
  my $result = $expr->evaluate($context, expect => 'MF::INTEGER');
  print $result->value;

Of course, there are various simplifications possible, when the calculations
are not too complex:

  my $filename  = '...';
  my $fragment = Math::Formula::Context->new(name => 'file',
    attributes => {
      name     => sub { MF::STRING->new($filename) },
      size     => sub { MF::INTEGER->new(-s $filename) },
      is_image => 'name =~ "*.{jpg,png,gif}"',
	  π        => MF::FLOAT->new(undef, 3.14),    # constant
    });
  $context->addAttribute(allocate => '#file.size * 10k');
  print $context->value('#file.allocate');

In above example, the return type of the CODE for C<size> is explicit: this is
the fastest and safest way to return data.  However, it can also be guessed:

      size     => sub { -s $filename },

For clarity: the three syntaxes:

  .name           an attribute to the context
  allocate        a formula in the context
  allocate.abs    an attribute of the expression result
  #file           interface to an object, registered in the context
  #file.size      an attribute to an object
  #filesys.file(name).size   file(name) produces an object

=section Aliasing

It is possible to produce an alias formula to hide or simplify the fragment.
This also works for formulas and attributes!

  fs   => '#filesys'         # alias fragment
  dt   => '#system#datetime' # alias nested fragments
  size => '"abc".size'       # alias attribute
  now  => 'dt.now'           # alias formula

=section CODE as expression

It should be the common practice to use strings as expressions.  Those strings get
tokenized and evaluated.  However, when you need calculations which are not offered
by this module, or need connections to objects (see fragments in M<Math::Formula::Context>),
then you will need CODE references as expression.

The CODE reference returns either an B<explicit type> or a guessed type.
When the type is explicit, you MUST decide whether the data is a "token"
(in normalized string representation) or a "value" (internal data format).

Math::Formula's internal types are bless ARRAYs with (usually) two fields.
The first is the I<token>, the second the I<value>.  When the token is
known, but the value is needed, the token will get parsed.  And vice
versa: the token can be generated from the value when required.

Some examples of explicit return object generation:

  my $int = MF::INTEGER->new("3k", undef);  # token 3k given
  my $int = MF::INTEGER->new("3k");         # same
  say $int->token;  -> 3k
  say $int->value;  -> 3000                 # now, conversion was run

  my $dt  = DateTime->now;
  my $now = MF::DATETIME->new(undef, $dt);  # value is given
  my $dt2 = $now->value;                    # returns $dt
  say $now->token;  -> 2032-02-24T10:00:15+0100

See M<Math::Formula::Type> for detailed explanation for the types which
can be returned.  These are the types with examples for tokens and values:

  MF::BOOLEAN   'true'            1        # anything !=0 is true
  MF::STRING    '"tic"'           'tic'    # the token has quotes!
  MF::INTEGER   '42'              42
  MF::FLOAT     '3.14'            3.14
  MF::DATETIME  '2023-...T09:...' DateTime-object
  MF::DATE      '2023-02-24+0100' DateTime-object
  MF::TIME      '09:12:24'        some HASH
  MF::DURATION  'P3Y2MT12M'       DateTime::Duration-object
  MF::NAME      'tac'             'tac'
  MF::PATTERN   '"*c"'            qr/^.*c$/ # like understands MF::REGEXP
  MF::REGEXP    '"a.b"'           qr/^a.b$/
  MF::FRAGMENT  'toe'             ::Context-object

When you decide to be lazy, Math::Formula will attempt to auto-detect the
type.  This is helped by the fact that operator will cast types which they
need, for instance MF::FLOAT to MF::INTEGER or the reverse.

=cut

1;
