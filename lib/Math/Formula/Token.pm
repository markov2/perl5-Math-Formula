use warnings;
use strict;

package Math::Formula::Token;

# Object is an ARRAY. The first element is the token. More elements
# are extension specific.

sub new(%) { my $class = shift; bless [@_], $class }

sub token  { $_[0][0] //= $_[0]->_token($_[0][1]) }
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

#-------------------
=section MF::INFIX, infix (dyadic) operator
Infix operators have two arguments.

=cut

package
	MF::PREFIX;

use base 'MF::OPERATOR';

sub right() { $_[0][1] }

sub _compute($$)
{	my ($self, $context, $expr) = @_;
    my $value = $self->right->_compute
		or return undef;

	# no prefix op requires $context or $expr yet
	$value->prefix($self->operator);
}

#-------------------
=section MF::INFIX,
=cut

package
	MF::INFIX;

use base 'MF::OPERATOR';

sub left()  { $_[0][1] }
sub right() { $_[0][2] }

1;
