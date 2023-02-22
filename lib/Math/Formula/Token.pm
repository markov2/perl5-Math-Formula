use warnings;
use strict;

package Math::Formula::Token;

#!!! Classes and methods which are of interest of normal users are documented
#!!! in ::Types, because the package set-up caused too many issues with OODoc.

# The object is an ARRAY.
sub new(%) { my $class = shift; bless [@_], $class }


# Returns the token in string form.  This may be a piece of text as parsed
# from the expression string, or generated when the token is computed.

sub token  { $_[0][0] //= $_[0]->_token($_[0]->value) }
sub _token { $_[1] }

#-------------------
# MF::PARENS, parenthesis tokens
# Parser object to administer parenthesis, but disappears in the AST.

package
	MF::PARENS;

use base 'Math::Formula::Token';

sub level { $_[0][1] }

#-------------------
# MF::OPERATOR, operator of yet unknown type.
# In the AST upgraded to either MF::PREFIX or MF::INFIX.

package
	MF::OPERATOR;

use base 'Math::Formula::Token';

use constant {
    # Associativity
    LTR => 1, RTL => 2, NOCHAIN => 3,
};

# method operator(): Returns the operator value in this token, which
# "accidentally" is the same value as the M<token()> method produces.
sub operator() { $_[0][0] }

sub _compute { die }  # must be extended

my %table;
{
	# Prefix operators and parenthesis are not needed here
    # Keep in sync with the table in Math::Formula
	my @order = (
#		[ LTR, ',' ],   ? :
		[ LTR, 'or', 'xor' ],
		[ LTR, 'and' ],
		[ LTR, '+', '-', '~' ],
		[ LTR, '*', '/', '%' ],
		[ LTR, '=~', '!~', 'like', 'unlike' ],
		[ LTR, '#', '.' ],
	);

	my $level;
	foreach (@order)
	{	my ($assoc, @line) = @$_;
		$level++;
		$table{$_} = [ $level, $assoc ] for @line;
	}
}

# method find($operator)
# Returns a list with knowledge about a know operator.
#   The first argument is a priority level for this operator.  The actual
# priority numbers may change over releases of this module.
#   The second value is a constant of associativety.  Either the constant
# LTR (compute left to right), RTL (right to left), or NOCHAIN (non-stackable
# operator).

sub find($) { @{$table{$_[1]}} }

#-------------------
# MF::PREFIX, monadic prefix operator
# Prefix operators process the result of the expression which follows it.
# This is a specialization from the MF::OPERATOR type, hence shares its methods.

package
	MF::PREFIX;

use base 'MF::OPERATOR';

# method child(): Returns the AST where this operator works on.
sub child() { $_[0][1] }

sub _compute($$)
{	my ($self, $context, $expr) = @_;
    my $value = $self->child->_compute($context, $expr)
		or return undef;

	# no prefix operator needs $context or $expr yet
	$value->prefix($self->operator);
}

#-------------------
# MF::INFIX, infix (dyadic) operator
# Infix operators have two arguments.  This is a specialization from the
# MF::OPERATOR type, hence shares its methods.

package
	MF::INFIX;

use base 'MF::OPERATOR';

# method left(): Returns the AST left from the infix operator.
sub left()  { $_[0][1] }

# method right(): Returns the AST right from the infix operator.
sub right() { $_[0][2] }

sub _compute($$)
{	my ($self, $context, $expr) = @_;

    my $left  = $self->left->_compute($context, $expr)
		or return undef;

	my $right = $self->right->_compute($context, $expr)
		or return undef;

	$left->infix($self->operator, $right, $context, $expr);
}

1;
