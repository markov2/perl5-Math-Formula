#!/usr/bin/env perl
#
# This code will be run incredabily fast, hence is tries to avoid copying etc.  It
# is not always optimally readible when your Perl skills are poor.

package Math::Formula;

use warnings;
use strict;
use utf8;

use Log::Report 'math-formula';
use Scalar::Util qw/blessed/;

use Math::Formula::Token;
use Math::Formula::Type;

=chapter NAME

Math::Formula - expressions on steriods

=chapter SYNOPSIS

  my $formula = Math::Formula->new('size', '42k + 324', %options);
  my $size    = $formula->evaluate;

  my $context = Math::Formula::Context->new(name => 'example');
  $context->add( { size => '42k', header => '324', total => 'size + header' });
  my $total   = $context->value(total);

  my $formula = Math::Formula->new(size => \&own_sub, %options);
  my $formual = Math::Formula->new(π => MF::FLOAT->new(undef, 3.14))

=chapter DESCRIPTION

B<WARNING:> This is not a programming language: it lacks control structures
like loops and blocks.  This can be used to get (very) flexible configuration
files for your program.

B<What makes Math::Formula special?> Zillions of expression evaluators
have been written in the past.  The application where this module was
written for has special needs which were not served by them.
This expression evaluator can do things which are usually hidden behind
library calls.

For instance, where are many types which you can use in your configuration
lines to calculate directly (examples far down on this page)

  true and false               # real booleans
  "abc"  'abc'                 # the usual strings
  7  89k  5Mibi                # integers with multiplier support
  =~ "c$"                      # regular expressions
  like "*c"                    # pattern matching
  2023-02-18T01:28:12+0300     # date-times
  2023-02-18                   # dates
  01:18:12                     # times
  P2Y3DT2H                     # duration
  name                         # outcome of other expressions
  #unit.owner                  # fragments (context, namespaces)
  file.size                    # attributes
  (1 + 2) * 3                  # parenthesis

With this, your expressions can look like this:

  my_age   = (#system.now.date - 1966-05-04).years
  is_adult = my_age >= 18

Expressions can refer to values computed by other expressions.  The results are
cached within the context.  Also, external objects can maintain libraries of
formulas or produce compatible data.

B<Why do I need it?> My application has many kinds of configurable
rules, often with dates and durations in it, to arrange processing.
Instead of fixed, processed values in my configuration, each line can
now be a smart expression.  Declarative programming.

=section Plans

=over 4
=item * the C<?:> (ternary if-then-else)
=item * parameterized formulas would be nice
=item * loading and saving contexts in INI, YAML, and JSON format
=back

=cut

#--------------------------
=chapter METHODS

=section Constructors

=c_method new $name, $expression, %options

=requires name $name
The expression need a name, to be able to produce desent error messages.
But also to be able to cache the results in the "Context".  Expressions
can refer to each other via this name.

=requires expression $expression
The expression is usually a (utf8) string, which will get parsed and
evaluated on demand.  The $expresion may also be a prepared node (any
<Math::Formula::Type> object.

As special hook, you may also provide a CODE as $expression.  This will
be called as

  $expression->($context, $this_formula, %options_to_evaluate);

Optimally, the expression returns any M<Math::Formula::Type> object.  Otherwise,
autodetection kicks in.  More details below in L<Math::Formula::Context/"CODE as expression">.

=option  returns $type
=default returns C<undef>
Enforce that the type produced by the calculation of this $type.  Otherwise, it may
be different when other people are permitted to configure the formulas... people can
make mistakes.
=cut

sub new(%)
{	my ($class, $name, $expr, %self) = @_;
	$self{_name} = $name;
	$self{_expr} = $expr;
	(bless {}, $class)->init(\%self) }

sub init($)
{	my ($self, $args) = @_;
	$self->{MSBE_name}    = $args->{_name} or panic "every formular requires a name";
	$self->{MSBE_expr}    = $args->{_expr} or panic "every formular requires an expression";
	$self->{MSBE_returns} = $args->{returns};
	$self;
}

#--------------------------
=section Accessors

=method name
Returns the name of this expression.

=method expression
Returns the expression string, which was used at creation.

=method returns
Set when the expression promisses to produce a certain type.
=cut

sub name()       { $_[0]->{MSBE_name} }
sub expression() { $_[0]->{MSBE_expr} }
sub returns()    { $_[0]->{MSBE_returns} }

=method tree $expression
Returns the Abstract Syntax Tree of the $expression. Some of the types
are only determined at the first run, for optimal laziness.
=cut

sub tree($)
{	my ($self, $expression) = @_;
	$self->{MSBE_ast} ||= $self->_build_ast($self->_tokenize($expression), 0);
}

# For testing only: to load a new expression without the need to create
# a new object.
sub _test($$)
{	my ($self, $expr) = @_;
	$self->{MSBE_expr} = $expr;
	delete $self->{MSBE_ast};
}

###
### PARSER
###

my $multipliers = MF::INTEGER->_multipliers;
my $match_float = MF::FLOAT->_match;
my $match_name  = MF::NAME->_match;
my $match_date  = MF::DATE->_match;
my $match_time  = MF::TIME->_match;
my $match_dt    = MF::DATETIME->_match;
my $match_dur   = MF::DURATION->_match;

my $match_op    = join '|',
	'[*\/+\-#~.%]',
	qw/=~ !~
	 <=> <= >= == != < > /,  # order is important
	( map "$_\\b", qw/
		and or not xor
		like unlike
		cmp lt le eq ne ge gt/
	);

sub _tokenize($)
{	my ($self, $s) = @_;
	our @t = ();
	my $parens_open = 0;

	use re 'eval';  #XXX needed with newer than 5.16 perls?

	$s =~ m/ ^
	(?: \s*
	  (?| \# (?: \s [^\n\r]+ | $ ) \
		| ( true | false )	(?{ push @t, MF::BOOLEAN->new($+) })
		| ( \" (?: \\\" | [^"] )* \" )
							(?{ push @t, MF::STRING->new($+) })
		| ( \' (?: \\\' | [^'] )* \' )
							(?{ push @t, MF::STRING->new($+) })
		| ( $match_dur )	(?{ push @t, MF::DURATION->new($+) })
		| ( $match_op )		(?{ push @t, MF::OPERATOR->new($+) })
		| ( $match_name )	(?{ push @t, MF::NAME->new($+) })
		| ( $match_dt )		(?{ push @t, MF::DATETIME->new($+) })
		| ( $match_date )	(?{ push @t, MF::DATE->new($+) })
		| ( $match_time )	(?{ push @t, MF::TIME->new($+) })
		| ( $match_float )	(?{ push @t, MF::FLOAT->new($+) })
		| ( [0-9][0-9_]*(?:$multipliers)? )
							(?{ push @t, MF::INTEGER->new($+) })
		| \(				(?{ push @t, MF::PARENS->new('(', ++$parens_open) })
		| \)				(?{ push @t, MF::PARENS->new(')', $parens_open--) })
		| $
		| (.+)				(?{ error __x"expression '{name}', failed at '{where}'",
								name => $self->name, where => $+ })
	  )
	)+ \z /sxo;

	! $parens_open
		or error __x"expression '{name}', parenthesis do not match", name => $self->name;

	\@t;
}

sub _build_ast($$)
{	my ($self, $t, $prio) = @_;
	return shift @$t if @$t < 2;

  PROGRESS:
	while(my $first = shift @$t)
	{
#warn "LOOP FIRST ", Dumper $first,
#warn "     MORE  ", Dumper $t;
		if($first->isa('MF::PARENS'))
		{	my $level = $first->level;

			my @nodes;
			while(my $node = shift @$t)
			{	last if $node->isa('MF::PARENS') && $node->level==$level;
				push @nodes, $node;
			}
			$first = $self->_build_ast(\@nodes, 0);
			redo PROGRESS;
		}

		if(ref $first eq 'MF::OPERATOR')  # unresolved operator
		{	my $op = $first->token;

			if($op eq '#' || $op eq '.')
			{	# Fragments and Methods are always infix, but their left-side arg
				# can be left-out.  As PREFIX, they would be RTL but we need LTR
				unshift @$t, $first;
				$first = MF::NAME->new('');
				redo PROGRESS;
			}

			my $next  = $self->_build_ast($t, $prio)
				or error __x"expression '{name}', monadic '{op}' not followed by anything useful",
				    name => $self->name, op => $op;
#warn "HERE";

			$first = MF::PREFIX->new($op, $next);
			redo PROGRESS;
		}

		my $next = $t->[0]
			or return $first;   # end of expression

		ref $next eq 'MF::OPERATOR'
			or error __x"expression '{name}', expected infix operator but found '{type}'",
				name => $self->name, type => ref $next;

		my $op = $next->token;
		@$t or error __x"expression '{name}', infix operator '{op}' requires right-hand argument",
				name => $self->name, op => $op;

		my ($next_prio, $assoc) = MF::OPERATOR->find($op);

		return $first
			if $next_prio < $prio
			|| ($next_prio==$prio && $assoc==MF::OPERATOR::LTR);

		shift @$t;    # apply the operator
		$first = MF::INFIX->new($op, $first, $self->_build_ast($t, $next_prio));
		redo PROGRESS;
	}
}

#--------------------------
=section Running

=method evaluate [ $context, %options ]
Calculate the value for this expression given the $context.  The Context groups the expressions
together so they can refer to eachother.  When the expression does not contain Names, than you
may go without context.

=option  expect $type
=default expect <any ::Type>
When specified, the result will be of the expected $type or C<undef>.  This overrules
M<new(returns)>.  Without either, the result type depends on the evaluation of the
expression.
=cut

sub evaluate($)
{	my ($self, $context, %args) = @_;
	my $expr   = $self->expression;

	my $result
	  = ref $expr eq 'CODE' ? $self->toType($expr->($context, $self, %args))
	  : ! blessed $expr     ? $self->tree($expr)->_compute($context, $self)
	  : $expr->isa('Math::Formula::Type') ? $expr
	  : panic;

	# For external evaluation calls, we must follow the request
	my $expect = $args{expect} || $self->returns;
	$result && $expect && ! $result->isa($expect) ? $result->cast($expect, $context) : $result;
}

=method toType $data
Convert internal Perl data into a Math::Formula internal types.  For most
times, this guess cannot go wrong. In other cases a mistake is not problematic.

In a small number of cases, auto-detection may break: is C<'true'> a
boolean or a string?  Gladly, this types will be cast into a string when
used as a string; a wrong guess without consequences.  It is preferred
that your CODE expressions return explicit types: for optimal safety and
performance.

See L<Math::Formula::Context/"CODE as expression"> for details.
=cut

my %_match = map { my $match = $_->_match; ( $_ => qr/^$match$/x ) }
	qw/MF::DATETIME MF::TIME MF::DATE MF::DURATION/;

sub toType($)
{	my ($self, $data) = @_;
	if(blessed $data)
	{	return $data if $data->isa('Math::Formula::Type');  # explicit type
		return MF::DATETIME->new(undef, $data) if $data->isa('DateTime');
		return MF::DURATION->new(undef, $data) if $data->isa('DateTime::Duration');
		return MF::FRAGMENT->new($data->name, $data) if $data->isa('Math::Formula::Context');
	}

	my $match = sub { my $type = shift; my $match = $type->_match; qr/^$match$/ };

	return 
	    $data =~ /^[+-]?[0-9]+$/         ? MF::INTEGER->new(undef, $data)
	  : $data =~ /^[+-]?[0-9]+\./        ? MF::FLOAT->new(undef, $data)
	  : $data =~ /^(?:true|false)$/      ? MF::BOOLEAN->new($data)
	  : ref $data eq 'Regexp'            ? MF::REGEXP->new(undef, $data)
	  : $data =~ $_match{'MF::DATETIME'} ? MF::DATETIME->new($data)
	  : $data =~ $_match{'MF::TIME'}     ? MF::TIME->new($data)
	  : $data =~ $_match{'MF::DATE'}     ? MF::DATE->new($data)
	  : $data =~ $_match{'MF::DURATION'} ? MF::DURATION->new($data)
	  : $data =~ /^(['"]).*\1$/          ? MF::STRING->new($data)
	  :                                    MF::STRING->new(undef, $data);
}

#--------------------------
=chapter DETAILS

=section Formulas

=subsection explaining types

Let's start with a large group of related formulas, and the types they produce:

  birthday: 1966-04-05      # DATE
  os_lib: #system           # external OBJECT
  now: os_lib.now           # DATETIME 'now' is an attribute of system
  today: now.date           # DATE 'date' is an attribute of DATETIME
  alive: today - birthday   # DURATION
  age: alive.years          # INTEGER 'years' is an attr of DURATION

  # this can also be written in one line:

  age: (#system.now.date - 1966-04-05).years

Or some backup configuration lines:

  backup_needed: #system.now.day_of_week <= 5    # Monday = 1
  backup_start: 23:00:00
  backup_max_duration: PT2H30M
  backup_dir: "/var/tmp/backups"
  backup_name: backup_dir ~ '/' ~ "backup-" ~ weekday ~ ".tgz"

The application which uses this configuration, will run the expressions with
the names has listed.  It may also provide some own formulas, fragments, and
helper methods.

=section Operators

As B<prefix> operator, you can use C<not>, C<->, C<+> on applicable data
types.  The C<#> (fragment) and C<.> (attributes) prefixes are weird cases:
see M<Math::Formula::Context>.

Operators work on explicit data types.
Of course, you can use parenthesis for grouping.

The B<infix> operators have the following priorities: (from low to higher,
each like with equivalent priority)

  LTR       or   xor
  LTR       and
  NOCHAIN	<    >    <=   ==   !=   <=>   # numeric comparison
  NOCHAIN	lt   gt   le   eq   ne   cmp   # string comparison
  LTR       +    -    ~
  LTR       *    /    %
  LTR       =~   !~   like  unlike         # regexps and patterns
  LTR       #    .                         # fragments and attributes

The first value is a constant representing associativety.  Either the constant
LTR (compute left to right), RTL (right to left), or NOCHAIN (non-stackable
operator).

=section Comparison operators

Some data types support numeric comparison (implement C<< <=> >>, the
spaceship operator), other support textual comparison (implement C< cmp >),
where also some types have no intrinsic order.

The C<< <=> >> and C< cmp > return an integer: -1, 0, or 1, representing
smaller, equal, larger.

  =num  =text
    <     lt      less than/before
    <=    le      less-equal
    ==    eq      equal/the same
    !-    ne      unequal/different
    >=    ge      greater-equal
    >     gt      greater/larger

String comparison uses L<Unicode::Collate>, which might be a bit expensive,
but at least a better attempt to order utf8 correctly.

=cut

1;
