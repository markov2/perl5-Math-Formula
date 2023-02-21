use warnings;
use strict;

package Math::Formula::Token;

=chapter NAME

Math::Formula::Token - base class for all tokens

=chapter SYNOPSIS

=chapter DESCRIPTION
The page also contains documentation for all tokens which are not types.
The types are documented in M<Math::Formula::Type>.

=chapter METHODS

=section Constructors

=c_method new $token|undef, [$value]
The object is a blessed ARRAY.  On the first spot is the $token.  On the
second spot might be the decoded value of the token, in internal Perl
representation.  When no $token is passed (value C<undef> is explicit), then
you MUST provide a $value.  The token will be generated on request.
=cut

# Object is an ARRAY. The first element is the token. More elements
# are extension specific.

sub new(%) { my $class = shift; bless [@_], $class }

#-------------------
=section Attributes

=method token
Returns the token in string form.  This may be a piece of text as parsed
from the expression string, or generated when the token is computed.
=cut

sub token  { $_[0][0] //= $_[0]->_token($_[0]->value) }
sub _token { $_[1] }

#-------------------
=section MF::PARENS, parenthesis tokens
Parser object to administer parenthesis, but disappears in the AST.
=cut

package
	MF::PARENS;

use base 'Math::Formula::Token';

sub level { $_[0][1] }

#-------------------
=section MF::OPERATOR, operator of yet unknown type.
In the AST upgraded to either MF::PREFIX or MF::INFIX.
=cut

package
	MF::OPERATOR;

use base 'Math::Formula::Token';

use constant {
    # Associativity
    LTR => 1, RTL => 2, NOCHAIN => 3,
};

=method operator
Returns the operator value in this token, which "accidentally" is the same value
as the M<token()> method produces.
=cut

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

=method find $operator
Returns a list with knowledge about a know operator.

The first argument is a priority level for this operator.  The actual
priority numbers may change over releases of this module.

The second value is a constant of associativety.  Either the constant
LTR (compute left to right), RTL (right to left), or NOCHAIN (non-stackable
operator).
=cut

sub find($) { @{$table{$_[1]}} }

#-------------------
=section MF::PREFIX, monadic prefix operator
Prefix operators process the result of the expression which follows it.
This is a specialization from the MF::OPERATOR type, hence shares its methods.
=cut

package
	MF::PREFIX;

use base 'MF::OPERATOR';

=method child
Returns the AST where this operator works on.
=cut

sub child() { $_[0][1] }

sub _compute($$)
{	my ($self, $context, $expr) = @_;
    my $value = $self->child->_compute($context, $expr)
		or return undef;

	# no prefix operator needs $context or $expr yet
	$value->prefix($self->operator);
}

#-------------------
=section MF::INFIX, infix (dyadic) operator
Infix operators have two arguments.  This is a specialization from the
MF::OPERATOR type, hence shares its methods.
=cut

package
	MF::INFIX;

use base 'MF::OPERATOR';

=method left
Returns the AST left from the infix operator.
=cut

sub left()  { $_[0][1] }

=method right
Returns the AST right from the infix operator.
=cut

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
