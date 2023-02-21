use warnings;
use strict;

package Math::Formula::Token;

# Object is an ARRAY. The first element is the token. More elements
# are extension specific.

sub new(%) { my $class = shift; bless [@_], $class }

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

sub operator() { $_[0][0] }

sub _compute { die }  # must be extended

my %table;
{
	use constant LTR => 1;  #XXX loading problem issue

	# prefix operators are not needed here
	my @order = (
		[ LTR, ',' ],
		[ LTR, 'or', 'xor' ],
		[ LTR, 'and' ],
		[ LTR, '+', '-', '~' ],
		[ LTR, '*', '/', '%' ],
		[ LTR, '=~', '!~', 'like', 'unlike' ],
	);

	my $level;
	foreach (@order)
	{	my ($assoc, @line) = @$_;
		$level++;
		$table{$_} = [ $level, $assoc ] for @line;
	}
}

sub find($) { @{$table{$_[1]}} }

#-------------------
=section MF::PREFIX, monadic prefix operator
Infix operators have two arguments.

=cut

package
	MF::PREFIX;

use base 'MF::OPERATOR';

sub right() { $_[0][1] }

sub _compute($$)
{	my ($self, $context, $expr) = @_;
    my $value = $self->right->_compute($context, $expr)
		or return undef;

	# no prefix operator needs $context or $expr yet
	$value->prefix($self->operator);
}

#-------------------
=section MF::INFIX, infix (dyadic) operator
=cut

package
	MF::INFIX;

use base 'MF::OPERATOR';

sub left()  { $_[0][1] }
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
