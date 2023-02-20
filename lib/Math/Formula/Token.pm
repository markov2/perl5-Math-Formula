use warnings;
use strict;

package Math::Formula::Token;

# Object is an ARRAY. The first element is the token. More elements
# are extension specific.

sub new(%) { my $class = shift; bless [@_], $class }

sub token  { $_[0][0] //= $_[0]->_token($_[0][1]) }
sub _token { $_[1] }

###
### PARENS
###

package
	MF::PARENS;

use base 'Math::Formula::Token';

sub level { $_[0][1] }

###
### OPERATOR
###

package
	MF::OPERATOR;

use base 'Math::Formula::Token';


package
	MF::PREFIX;

use base 'MF::OPERATOR';

sub tree() { $_[0][1] }


package
	MF::INFIX;

use base 'MF::OPERATOR';

sub left()  { $_[0][1] }
sub right() { $_[0][2] }

1;
