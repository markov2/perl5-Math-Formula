#!/usr/bin/env perl
#
# This code will be run incredabily fast, hence is tries to avoid copying etc.  It
# is not always optimally readible when your Perl skills are poor.

package Math::Formula;

use warnings;
use strict;
use utf8;

use Log::Report;

use Math::Formula::Token;
use Math::Formula::Type;

use Data::Dumper;
$Data::Dumper::Indent = 0;

=chapter NAME

Math::Formula - expressions on steriods

=chapter SYNOPSIS

  my $formula = Math::Formula->new('size', '42k + 324', %options);
  my $size    = $formula->evaluate($context, expect => 'MF::INTEGER');

Or better

  $context->add(size => '42k + 324');
  my $size = $context->calc('size', expect => 'MF::INTEGER');
  my $size = $context->value('size');

=chapter DESCRIPTION

B<What makes Math::Formula special?> Many expression evaluators have been written
in the past.  The application where this module was written for has special needs,
so this expression evaluator can do things which are usually hidden behind library
calls.  For instance, where are many types which you can use to calculate directly
(examples far below on this page)

  true and false               # real booleans
  "abc"  'abc'                 # the usual strings
  7  89k  5Mibi                # integers with multiplier support
  =~ "c$"                      # regular expressions and patterns
  like "*c"                    # pattern matching
  2023-02-18T01:28:12+0300     # date-times
  2023-02-18                   # dates
  01:18:12                     # times
  P2Y3DT2H                     # duration
  system                       # external objects
  unit#owner                   # fragments (object lookups)
  file.size                    # attributes

For instance,

  my_age   = (system.now.date - 1966-05-04).years
  is_adult = my_age >= 18

Expressions can refer to values computed by other expressions.  The results are
cached within the context.

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

=cut

sub new(%)
{	my ($class, $name, $expr, %self) = @_;
	$self{name} = $name;
	$self{expr} = $expr;
	(bless {}, $class)->init(\%self) }

sub init($)
{	my ($self, $args) = @_;
	$self->{MSBE_name} = $args->{name};
	$self->{MSBE_expr} = $args->{expr};
	$self;
}

#--------------------------
=section Accessors

=method name
Returns the name of this expression.
=cut

sub name()       { $_[0]->{MSBE_name} }

=method expression
Returns the expression string, which was used at creation.
=cut

sub expression() { $_[0]->{MSBE_expr} }

=method tree
Returns the Abstract Syntax Tree of the expression. Some of the types
are only determined at run-time, for optimal laziness.
=cut

sub tree()
{	my $self = shift;
	$self->{MSBE_tree} ||= $self->_build_tree($self->_tokenize($self->expression), 0);
}

# For testing only: to load a new expression without the need to create
# a new object.
sub _test($$)
{	my ($self, $expr) = @_;
	$self->{MSBE_expr} = $expr;
	delete $self->{MSBE_tree};
}

###
### PARSER
###

my $multipliers = MF::INTEGER->_multipliers;
my $match_float = MF::FLOAT->_pattern;
my $match_name  = MF::NAME->_pattern;
my $match_date  = MF::DATE->_pattern;
my $match_time  = MF::TIME->_pattern;
my $match_tz    = '[+-] [0-9]{4}';

my $match_duration = MF::DURATION->_pattern;

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
		| ( $match_duration )
							(?{ push @t, MF::DURATION->new($+) })
		| ( $match_op )		(?{ push @t, MF::OPERATOR->new($+) })
		| ( $match_name )	(?{ push @t, MF::NAME->new($+) })
		| ( $match_date T $match_time (?: $match_tz )? )
							(?{ push @t, MF::DATETIME->new($+) })
		| ( $match_date (?: $match_tz )? )
							(?{ push @t, MF::DATE->new($+) })
		| ( $match_time (?: $match_tz )? )
							(?{ push @t, MF::TIME->new($+) })
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

sub _build_tree($$)
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
			$first = $self->_build_tree(\@nodes, 0);
			redo PROGRESS;
		}

		if(ref $first eq 'MF::OPERATOR')  # unresolved operator
		{	my $op = $first->token;

			if($op eq '#' || $op eq '.')
			{	# Fragments and Methods are always infix, but their left-side arg
				# can be left-out.  As PREFIX, they would be RTL but we need LTR
				unshift @$t, $first;
				$first = MF::NAME->new('context');
				redo PROGRESS;
			}

			my $next  = $self->_build_tree($t, $prio)
				or error __x"expression '{name}', monadic '{op}' not followed by anything useful",
				    name => $self->name, op => $op;
#warn "HERE";

			$first = MF::PREFIX->new($op, $next);
			redo PROGRESS;
		}

		my $next = $t->[0]
			or return $first;   # end of expression

ref $next or warn $next;
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
		$first = MF::INFIX->new($op, $first, $self->_build_tree($t, $next_prio));
		redo PROGRESS;
	}
}

#--------------------------
=section Running

=method evaluate $context, [$type]
Calculate the value for this expression given the $context.  When the expected $type
is given, the result will be guaranteed of the correct type or C<undef>.
=cut

sub evaluate($)
{	my ($self, $context, $expect) = @_;
	my $result = $self->tree->_compute($context, $self);

	# For external evaluation calls, we must follow the request
	$expect && ! $result->isa($expect) ? $result->cast($expect) : $result;
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

This can also be written in one line:

  age: (#system.now.date - 1966-04-05).years

=section Operators

As prefix operator, you can use C<not>, C<->, C<+> on applicable data
types.  The C<#> (fragment) and C<.> (attributes) prefixes are weird cases:
see M<Math::Formula::Context>.

The infix operators have the following priorities: (from low to higher,
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
