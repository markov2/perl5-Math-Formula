use warnings;
use strict;
use v5.16;  # fc

package Math::Formula::Type;
use base 'Math::Formula::Token';

#!!! The declarations of all other packages in this file are indented to avoid
#!!! indexing by CPAN.

use Log::Report 'math-formula', import => [ qw/warning error __x/ ];

# Object is an ARRAY. The first element is the token, as read from the formula
# or constructed from a computed value.  The second is a value, which can be
# used in computation.  More elements are type specific.

=chapter NAME

Math::Formula::Type - variable types for Math::Formular

=chapter SYNOPSIS
  my $string = MF::STRING->new("example");
  my $answer = MF::INTEGER->new(42);

  # See more details per section

=chapter DESCRIPTION
This page describes are Types used by M<Math::Formula>. All parts of an
expression has a known type, and also the type of the result of an expression
is known beforehand.

=chapter METHODS

=section Constructors

=c_method new $token|undef, [$value], %options
The object is a blessed ARRAY.  On the first spot is the $token.  On the
second spot might be the decoded value of the token, in internal Perl
representation.  When no $token is passed (value C<undef> is explicit), then
you MUST provide a $value.  The token will be generated on request.

=option  attributes HASH
=default attributes {}
(MF::FRAGMENT only) Initial attributes, addressed with infix operator C<.> (dot).

=cut

#-----------------
=section MF::Formula::Type
The following methods and features are supported for any Type defined on this page.

All types can be converted into a string:

  "a" ~ 2          -> STRING "a2"

All types may provide B<attributes> (calls) for objects of that type.  Those
get inherited (of course).  For instance:

   02:03:04.hour   -> INTEGER 2

=method cast $type
Type-convert a typed object into an object with a different type.  Sometimes, the 
represented value changes a little bit, but usually not.

Any Type can be cast into a MF::STRING. Read the documentation for other types to
see what they offer.
=cut

sub cast($)
{	my ($self, $to, $context) = @_;

	return MF::STRING->new(undef, $self->token)
		if $to eq 'MF::STRING';

	undef;
}

=method token
Returns the token in string form.  This may be a piece of text as parsed
from the expression string, or generated when the token is computed.
=cut
# token() is implemented in de base-class ::Token, but documented here


# Returns a value as result of a calculation.
# nothing to compute for most types: simply itself
sub _compute { $_[0] }

=method value
Where M<token()> returns a string representation of the instance, the
C<value()> produces its translation into internal Perl values or objects,
ready to be involved in computations.
=cut

sub value  { my $self = shift; $self->[1] //= $self->_value($self->[0], @_) }
sub _value { $_[1] }

=method collapsed
Returns the normalized version of the M<token()>: leading and trailing blanks
removed, intermediate sequences of blanks shortened to one blank.
=cut

sub collapsed($) { $_[0]->token =~ s/\s+/ /gr =~ s/^ //r =~ s/ $//r }

sub prefix()
{   my ($self, $op, $context) = @_;

	error __x"cannot find prefx operator '{op}' on a {child}",
		op => $op, child => ref $self;
}

sub attribute {
	warning __x"cannot find attribute '{attr}' for {class} '{token}'",
		attr => $_[1], class => ref $_[0], token => $_[0]->token;
	undef;
}

sub infix($@)
{   my $self = shift;
	my ($op, $right, $context) = @_;

	if($op eq '.' && $right->isa('MF::NAME'))
	{	if(my $attr = $self->attribute($right->token))
		{	return ref $attr eq 'CODE' ? $attr->($self, @_) : $attr;
		}
	}

	# object used as string
	return $self->cast('MF::STRING', $context)->infix(@_)
		if $op eq '~';

	error __x"cannot match infix operator '{op}' for ({left} -> {right})",
		op => $op, left => ref $self, right => ref $right;
}

#-----------------
=section MF::BOOLEAN, a thruth value
Represents a truth value, either C<true> or C<false>.

Booleans implement the prefix operator "C<+>", and infix operators 'C<and>',
'C<or>', and 'C<xor>'.

=examples for booleans

  true    false     # the only two values
  0                 # will be cast to false in boolean expressions
  42                # any other value is true, in boolean expressions

  not true        -> BOOLEAN false
  true and false  -> BOOLEAN false
  true  or false  -> BOOLEAN true
  true xor false  -> BOOLEAN true

=cut

package
	MF::BOOLEAN;

use base 'Math::Formula::Type';

sub prefix($)
{	my ($self, $op, $context) = @_;
	if($op eq 'not')
	{	return MF::BOOLEAN->new(undef, ! $self->value);
	}
	$self->SUPER::prefix($op, $context);
}

sub infix($$$)
{	my $self = shift;
	my ($op, $right, $context) = @_;

	if(my $r = $right->isa('MF::BOOLEAN') ? $right : $right->cast('MF::BOOLEAN', $context))
	{	my $v = $op eq 'and' ? ($self->value and $r->value)
	  		  : $op eq  'or' ? ($self->value  or $r->value)
	  		  : $op eq 'xor' ? ($self->value xor $r->value)
	  		  : undef;

		return MF::BOOLEAN->new(undef, $v) if defined $v;
	}

	$self->SUPER::infix(@_);
}

sub _token($) { $_[1] ? 'true' : 'false' }
sub _value($) { $_[1] eq 'true' }

#-----------------
=section MF::STRING, contains text
Represents a sequence of UTF8 characters, which may be used single and
double quoted.

Strings may be cast into regular expressions (MF::REGEXP) when used on the right
side of a regular expression match operator ('C<=~>' and 'C<!~>').

Strings may be cast into a pattern (MF::PATTERN) when used on the right
of a pattern match operator ('C<like>' and 'C<unlike>').

Besides the four match operators, strings can be concatenated using 'C<~>'.

Strings also implement textual comparison operators C<lt>, C<le>, C<eq>,
C<ne>, C<ge>, C<gt>, and C<cmp>.  Read its section in M<Math::Formula>.
These comparisons use L<Unicode::Collate> in an attempt to get correct
utf8 sorting.

=examples of strings

  "double quoted string"
  'single quoted string'   # alternative

  "a" + 'b'           -> STRING  "ab"
  "a" =~ "regexp"     -> BOOLEAN, see MF::REGEXP
  "a" like "pattern"  -> BOOLEAN, see MF::PATTERN

  "a" gt "b"          -> BOOLEAN
  "a" cmp "b"         -> INTEGER -1, 0, 1

Attributes:

   "abc".length       -> INTEGER  3
   "".is_empty        -> BOOLEAN true   # only white-space
   "ABC".lower        -> STRING "abc", lower-case using utf8 folding
=cut

package
	MF::STRING;

use base 'Math::Formula::Type';

use Unicode::Collate ();
my $collate = Unicode::Collate->new;  #XXX which options do we need?

# Perl's false is 'undef': convert it to '0'
sub new($$@)
{	my ($class, $token, $value) = (shift, shift, shift);
	$value //=0 unless defined $token;
	$class->SUPER::new($token, $value, @_);
}

sub _token($) { '"' . ($_[1] =~ s/[\"]/\\$1/gr) . '"' }

sub _value($)
{	my $token = $_[1];

	  substr($token, 0, 1) eq '"' ? $token =~ s/^"//r =~ s/"$//r =~ s/\\([\\"])/$1/gr
	: substr($token, 0, 1) eq "'" ? $token =~ s/^'//r =~ s/'$//r =~ s/\\([\\'])/$1/gr
	: $token;  # from code
}

sub cast($)
{	my ($self, $to) = @_;

	  ref $self eq __PACKAGE__ && $to eq 'MF::REGEXP'  ? MF::REGEXP->_from_string($self)
	: ref $self eq __PACKAGE__ && $to eq 'MF::PATTERN' ? MF::PATTERN->_from_string($self)
	: $self->SUPER::cast($to);
}

sub infix($$$)
{	my $self = shift;
	my ($op, $right, $context) = @_;

	if($op eq '~')
	{	my $r = $right->isa('MF::STRING') ? $right : $right->cast('MF::STRING', $context);
		return MF::STRING->new(undef, $self->value . $r->value) if $r;
	}
	elsif($op eq '=~' || $op eq '!~')
	{	my $r = $right->isa('MF::REGEXP') ? $right : $right->cast('MF::REGEXP', $context);
		my $v = ! $r ? undef
			  : $op eq '=~' ? $self->value =~ $r->regexp : $self->value !~ $r->regexp;
		return MF::BOOLEAN->new(undef, $v) if $r;
	}
	elsif($op eq 'like' || $op eq 'unlike')
	{	# When expr is CODE, it may produce a qr// instead of a pattern.
		my $r = $right->isa('MF::PATTERN') || $right->isa('MF::REGEXP') ? $right : $right->cast('MF::PATTERN', $context);
		my $v = ! $r ? undef
			  : $op eq 'like' ? $self->value =~ $r->regexp : $self->value !~ $r->regexp;
		return MF::BOOLEAN->new(undef, $v) if $r;
	}
	elsif($op eq 'cmp')
	{	my $r = $right->isa('MF::STRING') ? $right : $right->cast('MF::STRING', $context);
		return MF::INTEGER->new(undef, $collate->cmp($self->value, $right->value));
	}

	$self->SUPER::infix(@_);
}

my %string_attrs = (
	length   => sub { MF::INTEGER->new(undef, length($_[0]->value))  },
	is_empty => sub { MF::BOOLEAN->new(undef, $_[0]->value !~ m/\P{Whitespace}/) },
	lower    => sub { MF::STRING->new(undef, fc($_[0]->value)) },
);

sub attribute($) { $string_attrs{$_[1]} || $_[0]->SUPER::attribute($_[1]) }

#-----------------
=section MF::INTEGER, a long whole number
Integers contain a sequence of ASCII digits, optionally followed by a multiplier.
Numbers may use an underscore ('C<_>') on the thousands, to be more readible.
For instance, 'C<42k>' is equal to 'C<42_000>'.

Supported multipliers are
=over 4
=item * 1000-based C<k>, C<M>, C<G>, C<T>, C<E>, and C<Z>;
=item * 1024-based C<kibi>, C<Mibi>, C<Gibi>, C<Tibi>, C<Eibi>, and C<Zibi>;
=back

The current guaranteed value boundaries are C<±2⁶³> which is about
9 Zeta, just below C(10¹)>.

Integers can be cast to booleans, where C<0> means C<false> and all other
numbers are C<true>.

Integers support prefix operators C<+> and C<->.

Integers support infix operators C<+>, C<->, C<*>, C<%> (modulo) which result
in integers.  Infix operator C</> returns a float.  All numeric comparison operators
return a boolean.

Integers implement the numeric sort operator C<< <=> >>, which may be mixed
with floats.

=examples of integers

  42        # the answer to everything
  8T        # how my disk was sold to me
  7451Mibi  # what my system tells me the space is
  -12       # negatives
  1_234_567 # _ on the thousands, more readible

  + 2          -> INTEGER   2      # prefix op
  - 2          -> INTEGER   -2     # prefix op
  - -2         -> INTEGER   2      # prefix op, negative int
  
  1 + 2        -> INTEGER   3      # infix op
  5 - 9        -> INTEGER   -4     # infix op
  3 * 4        -> INTEGER   12
  12 % 5       -> INTEGER   2
  12 / 5       -> FLOAT     2.4

  1 < 2        -> BOOLEAN   true
  1 <=> 2      -> INTEGER   -1     # -1, 0, 1

  not 0        -> BOOLEAN   true
  not 42       -> BOOLEAN   false

Attributes

  (-3).abs     -> INTEGER   3      # -3.abs == -(3.abs)

=cut

package
	MF::INTEGER;

use base 'Math::Formula::Type';
use Log::Report 'math-formula', import => [ qw/error __x/ ];

sub cast($)
{	my ($self, $to) = @_;
	  $to eq 'MF::BOOLEAN' ? MF::BOOLEAN->new(undef, $_[0]->value == 0 ? 0 : 1)
	: $to eq 'MF::FLOAT'   ? MF::FLOAT->new(undef, $_[0]->value)
	: $self->SUPER::cast($to);
}

sub prefix($)
{	my ($self, $op, $context) = @_;
	  $op eq '+' ? $self
	: $op eq '-' ? MF::INTEGER->new(undef, - $self->value)
	: $self->SUPER::prefix($op, $context);
}

sub infix($$$)
{	my $self = shift;
	my ($op, $right, $context) = @_;

	return $self->cast('MF::BOOLEAN', $context)->infix(@_)
		if $op eq 'and' || $op eq 'or' || $op eq 'xor';

	if($right->isa('MF::INTEGER') || $right->isa('MF::FLOAT'))
	{   my $v = $op eq '+' ? $self->value + $right->value
			  : $op eq '-' ? $self->value - $right->value
			  : $op eq '*' ? $self->value * $right->value
			  : $op eq '%' ? $self->value % $right->value
			  : undef;
		return ref($right)->new(undef, $v) if defined $v;

		return MF::INTEGER->new(undef, $self->value <=> $right->value)
			if $op eq '<=>';

		return MF::FLOAT->new(undef, $self->value / $right->value)
			if $op eq '/';
	}

	return $right->infix($op, $self, @_[2..$#_])
		if $op eq '*' && $right->isa('MF::DURATION');

	$self->SUPER::infix(@_);
}

my $gibi        = 1024 * 1024 * 1024;

my $multipliers = '[kMGTEZ](?:ibi)?\b';
sub _multipliers { $multipliers }

my %multipliers = (
	k => 1000, M => 1000_000, G => 1000_000_000, T => 1000_000_000_000, E => 1e15, Z => 1e18,
	kibi => 1024, Mibi => 1024*1024, Gibi => $gibi, Tibi => 1024*$gibi, Eibi => 1024*1024*$gibi,
	Zibi => $gibi*$gibi,
);

sub _value($)
{	my ($v, $m) = $_[1] =~ m/^ ( [0-9]+ (?: _[0-9][0-9][0-9] )* ) ($multipliers)? $/x
		or error __x"illegal number format for '{string}'", string => $_[1];

	($1 =~ s/_//gr) * ($2 ? $multipliers{$2} : 1);
}

my %int_attrs = (
   abs => sub { $_[0]->value < 0 ? MF::INTEGER->new(undef, - $_[0]->value) : $_[0] },
);
sub attribute($) { $int_attrs{$_[1]} || $_[0]->SUPER::attribute($_[1]) }

#-----------------
=section MF::FLOAT, floating-point numbers
Floating point numbers.  Only a limited set of floating point syntaxes is permitted, see
examples.  Especially: a float SHALL contain a dot or 'e'.  When it contains a dot, there
must be a digit on both sides.

Floats support prefix operators C<+> and C<->.

Floats support infix operators C<+>, C<->, C<*>, C<%> (modulo), and C</> which result
in floats.  All numeric comparison operators are supported, also in combination with
integers.

=examples of floats

  0.0        # leading zero obligatory
  0e+0
  0.1234
  3e+10
  -12.345

  3.14 / 4
  2.7 < π        -> BOOLEAN true
  2.12 <=> 4.89  -> INTEGER -1    # -1, 0, 1
  
=cut

package
	MF::FLOAT;

use base 'Math::Formula::Type';
use POSIX  qw/floor/;

sub _match  { '[0-9]+ (?: \.[0-9]+ (?: e [+-][0-9]+ )? | e [+-][0-9]+ )' }
sub _value($) { $_[1] + 0.0 }
sub _token($) { my $t = sprintf '%g', $_[1]; $t =~ /[e.]/ ?  $t : "$t.0" }

sub cast($)
{	my ($self, $to) = @_;
	  $to eq 'MF::INTEGER' ? MF::INTEGER->new(undef, floor($_[0]->value))
	: $self->SUPER::cast($to);
}

sub prefix($$)
{	my ($self, $op, $context) = @_;
	  $op eq '+' ? $self
	: $op eq '-' ? MF::FLOAT->new(undef, - $self->value)
	: $self->SUPER::prefix($op, $context)
}

sub infix($$$)
{	my $self = shift;
	my ($op, $right, $context) = @_;

	return $self->cast('MF::BOOLEAN', $context)->infix(@_)
		if $op eq 'and' || $op eq 'or' || $op eq 'xor';

	if($right->isa('MF::FLOAT') || $right->isa('MF::INTEGER'))
	{	# Perl will upgrade the integers
		my $v = $op eq '+' ? $self->value + $right->value
			  : $op eq '-' ? $self->value - $right->value
			  : $op eq '*' ? $self->value * $right->value
			  : $op eq '%' ? $self->value % $right->value
			  : $op eq '/' ? $self->value / $right->value
			  : undef;
		return MF::FLOAT->new(undef, $v) if defined $v;

		return MF::INTEGER->new(undef, $self->value <=> $right->value)
			if $op eq '<=>';
	}
	$self->SUPER::infix(@_);
}

# I really do not want a math library in here!  Use formulas with CODE expr
# my %float_attrs;
#sub attribute($) { $float_attrs{$_[1]} || $_[0]->SUPER::attribute($_[1]) }


#-----------------
=section MF::DATETIME, refers to a moment of time
The datetime is a complex value.  The ISO8601 specification offers many, many options which
make interpretation expensive.  To simplify access, one version is chosen.  This is an
example of that version:

  yyyy-mm-ddThh:mm:ss.sss+hhmm
  2013-02-20T15:04:12.231+0200

Mind the 'C<T>' between the date and the time components.  Second fractions are optional.

The timezone is relative to UTC.  The first two digits reflect an hour difference, the
latter two are minutes.

Datetimes can be cast to a time or a date, with loss of information.

It is possible to add (C<+>) and subtract (C<->) durations from a datetime, which result
in a new datetime.  When you subtract one datetime from another datetime, the result is
a duration.

Compare a datetime with an other datetime numerically (implemented as text comparison).
When the datetime is compared with a date, it is checked whether the point of time is
within the specified date range (from 00:00:00 in the morning upto 23:59:61 at night).

=examples for datetime

  2023-02-18T01:28:12
  2023-02-18T01:28:12.345
  2023-02-18T01:28:12+0300
  2023-02-18T01:28:12.345+0300

  2023-02-21T11:28:34 + P2Y3DT2H -> DATETIME  2025-02-24T13:28:34
  2023-02-21T11:28:34 - P2Y3DT2H -> DATETIME  2021-02-18T09:28:34
  2023-02-21T11:28:34 - 2021-02-18T09:28:34 -> DURATION P2Y3DT2H

Attributes: (the date and time attributes combined)

  date = 2006-11-21T12:23:34.56+0110
  dt.year    -> INTEGER 2006
  dt.month   -> INTEGER 11
  dt.day     -> INTEGER 21
  dt.hour    -> INTEGER 12
  dt.minute  -> INTEGER 23
  dt.second  -> INTEGER 34
  dt.fracsec -> FLOAT   34.56
  dt.tz      -> STRING  +0110
  dt.time    -> TIME    12:23:34.56
  dt.date    -> DATE    2006-11-21+0110
=cut

package
	MF::DATETIME;

use base 'Math::Formula::Type';
use DateTime ();
 
sub _match {
	  '[12][0-9]{3} \- (?:0[1-9]|1[012]) \- (?:0[1-9]|[12][0-9]|3[01]) T '
	. '(?:[01][0-9]|2[0-3]) \: [0-5][0-9] \: (?:[0-5][0-9]) (?:\.[0-9]+)?'
	. '(?:[+-][0-9]{4})?';
}

sub _token($) { $_[1]->datetime . ($_[1]->time_zone->name =~ s/UTC$/+0000/r) }

sub _value($)
{	my ($self, $token) = @_;
	$token =~ m/^
		([12][0-9]{3}) \- (0[1-9]|1[012]) \- (0[1-9]|[12][0-9]|3[01]) T
		([01][0-9]|2[0-3]) \: ([0-5][0-9]) \: ([0-5][0-9]|6[01]) (?:(\.[0-9]+))?
		([+-] [0-9]{4})?
	$ /x or return;

	my $tz_offset = $8 // '+0000';  # careful with named matches :-(
	my @args = ( year => $1, month => $2, day => $3, hour => $4, minute => $5, second => $6,
		nanosecond => ($7 // 0) * 1_000_000_000 );
	my $tz = DateTime::TimeZone::OffsetOnly->new(offset => $tz_offset);

	DateTime->new(@args, time_zone => $tz);
}

sub _to_time($)
{	+{ hour => $_[0]->hour, minute => $_[0]->minute, second => $_[0]->second, ns => $_[0]->nanosecond };
}

sub cast($)
{	my ($self, $to) = @_;
		$to eq 'MF::TIME' ? MF::TIME->new(undef, _to_time($_[0]->value))
	  : $to eq 'MF::DATE' ? MF::DATE->new(undef, $_[0]->value->clone)
	  : $self->SUPER::cast($to);
}

sub infix($$$@)
{	my $self = shift;
	my ($op, $right, $context) = @_;

	if($op eq '+' || $op eq '-')
	{	my $dt = $self->value->clone;
		if($right->isa('MF::DURATION'))
		{	my $v = $op eq '+' ?  $dt->add_duration($right->value) : $dt->subtract_duration($right->value);
			return MF::DATETIME->new(undef, $v);
		}
		if($op eq '-')
		{	my $r = $right->isa('MF::DATETIME') ? $right : $right->cast('MF::DATETIME', $context);
			return MF::DURATION->new(undef, $dt->subtract_datetime($right->value));
		}
	}

	if($op eq '<=>')
	{	return MF::INTEGER->new(undef, DateTime->compare($self->value, $right->value))
			if $right->isa('MF::DATETIME');

		if($right->isa('MF::DATE'))
		{	# Many timezone problems solved by DateTime
			my $date  = $right->token;
			my $begin = $self->_value($date =~ /\+/ ? $date =~ s/\+/T00:00:00+/r : $date.'T00:00:00');
			return MF::INTEGER->new(undef, -1) if DateTime->compare($begin, $self->value) > 0;

			my $end   = $self->_value($date =~ /\+/ ? $date =~ s/\+/T23:59:59+/r : $date.'T23:59:59');
			return MF::INTEGER->new(undef, DateTime->compare($self->value, $end) > 0 ? 1 : 0);
		}
	}

	$self->SUPER::infix(@_);
}

my %dt_attrs = (
	'time'  => sub { MF::TIME->new(undef, _to_time($_[0]->value)) },
	date    => sub { MF::DATE->new(undef, $_[0]->value) },  # dt's are immutable
	hour    => sub { MF::INTEGER->new(undef, $_[0]->value->hour)  },
	minute  => sub { MF::INTEGER->new(undef, $_[0]->value->minute) },
	second  => sub { MF::INTEGER->new(undef, $_[0]->value->second) },
	fracsec => sub { MF::FLOAT  ->new(undef, $_[0]->value->fractional_second) },
);

sub attribute($)
{	   $dt_attrs{$_[1]} || $MF::DATE::date_attrs{$_[1]} || $_[0]->SUPER::attribute($_[1]);
}

#-----------------
=section MF::DATE, refers to a day in some timezone
A date has format 'YYYY-MM-DD+TZ', for instance C<2023-02-20+0100>.

The date may be cast into a datetime, where the time is set to C<00:00:00>.
This transformation is actually slightly problematic: a date means "anywhere
during the day, where a datetime is a specific moment.

You may add (C<+>) and subtract (C<->) durations from a date, which result in
a new date.  Those durations cannot contain a time component.

An subtract (C<->) from a date produces a duration.

You may also add a time to a date, forming a datetime.  Those may be in diffent
timezones.  You may also numerically compare dates, but only when they are not
in the same timezone, this will return false.

=examples for date

  1966-12-21        # without timezone, default from context
  1966-12-21+0200   # with explicit timezone info

  2023-02-21+0200 - P3D            -> DATE     2023-02-18+0200
  2012-03-08+0100 + 06:07:08+0200  -> DATETIME 2012-03-08T06:07:08+0300
  2023-02-26 - 2023-01-20          -> DURATION P1M6D
  2023-02-22 < 1966-04-05          -> BOOLEAN  false
  2023-02-22 <=> 1966-04-05        -> INTEGER 1      # -1, 0 1

  4 + 2000-10-20 -> INTEGER 1974  # parser accident repaired

Attributes:

  date = 2006-11-21+0700
  date.year      -> INTEGER 2006
  date.month     -> INTEGER 11
  date.day       -> INTEGER 21
  date.tz        -> STRING  "+0700"
=cut

package
	MF::DATE;

use base 'Math::Formula::Type';

use Log::Report 'math-formula', import => [ qw/error warning __x/ ];

use DateTime::TimeZone  ();
use DateTime::TimeZone::OffsetOnly ();

sub _match { '[12][0-9]{3} \- (?:0[1-9]|1[012]) \- (?:0[1-9]|[12][0-9]|3[01]) (?:[+-][0-9]{4})?' }

sub _token($) { $_[1]->ymd . ($_[1]->time_zone->name =~ s/UTC$/+0000/r) }

sub _value($)
{	my ($self, $token) = @_;
	$token =~ m/^
		([12][0-9]{3}) \- (0[1-9]|1[012]) \- (0[1-9]|[12][0-9]|3[01])
		([+-] [0-9]{4})?
	$ /x or return;

	my $tz_offset = $4 // '+0000';  # careful with named matches :-(
	my @args = ( year => $1, month => $2, day => $3);
	my $tz = DateTime::TimeZone::OffsetOnly->new(offset => $tz_offset);

	DateTime->new(@args, time_zone => $tz);
}

sub cast($)
{   my ($self, $to) = @_;
	if($to eq 'MF::INTEGER')
	{	# In really exceptional cases, an integer expression can be mis-detected as DATE
		bless $self, 'MF::INTEGER';
		$self->[0] = $self->[1] = eval "$self->[0]";
		return $self;
	}

	if($to eq 'MF::DATETIME')
	{	my $t  = $self->token;
		my $dt = $t =~ /\+/ ? $t =~ s/\+/T00:00:00+/r : $t . 'T00:00:00';
		return MF::DATETIME->new($dt);
	}

	$self->SUPER::cast($to);
}

sub infix($$@)
{	my $self = shift;
	my ($op, $right, $context) = @_;

	if($op eq '+' && $right->isa('MF::TIME'))
	{	my $l = $self->value;
		my $r = $right->value;
		my $v = DateTime->new(year => $l->year, month => $l->month, day => $l->day,
			hour => $r->{hour}, minute => $r->{minute}, second => $r->{second},
			nanosecond => $r->{ns}, time_zone => $l->time_zone);

		return MF::DATETIME->new(undef, $v);
	}

	if($op eq '-' && $right->isa('MF::DATE'))
	{	return MF::DURATION->new(undef, $self->value->clone->subtract_datetime($right->value));
	}

	if($op eq '+' || $op eq '-')
	{	my $r = $right->isa('MF::DURATION') ? $right : $right->cast('MF::DURATION', $context);
		! $r || $r->token !~ m/T.*[1-9]/
			or error __x"only duration with full days with DATE, found '{value}'",
				value => $r->token;

		my $dt = $self->value->clone;
		my $v = $op eq '+' ? $dt->add_duration($right->value) : $dt->subtract_duration($right->value);
		return MF::DATE->new(undef, $v);
	}

	if($op eq '<=>')
	{	my $r   = $right->isa('MF::DATE') ? $right : $right->cast('MF::DATE', $context);
		my ($ld, $ltz) = $self->token =~ m/(.{10})(.*)/;
		my ($rd, $rtz) =    $r->token =~ m/(.{10})(.*)/;

		# It is probably a configuration issue when you configure this.
		$ld ne $rd || ($ltz //'') eq ($rtz //'')
			or warning __x"dates '{first}' and '{second}' do not match on timezone",
				first => $self->token, second => $r->token;

		return MF::INTEGER->new(undef, $ld cmp $rd);
	}

	$self->SUPER::infix(@_);
}

our %date_attrs = (
   year     => sub { MF::INTEGER->new(undef, $_[0]->value->year)  },
   month    => sub { MF::INTEGER->new(undef, $_[0]->value->month) },
   day      => sub { MF::INTEGER->new(undef, $_[0]->value->day) },
   tz       => sub { MF::STRING ->new(undef, $_[0]->value->time_zone->name) },
);
sub attribute($) { $date_attrs{$_[1]} || $_[0]->SUPER::attribute($_[1]) }

#-----------------
=section MF::TIME, a moment during any day
Usefull to indicate a daily repeating event.  For instance, C<start-backup: 04:00:12>.
Times do no have a timezone: it only gets a meaning when added to a (local) time.

Time supports numeric comparison.  When you add (C<+>) a (short) duration to a time, it
will result in a new time (modulo 24 hours).

When you subtract (C<->) one time from another, you will get a duration modulo 24 hours.
This does not take possible jumps to and from Daylight Savingstime into
account.  When you care about that, than create a formular involving
the actual date:

  bedtime = 23:00:00
  wakeup  = 06:30:00
  now     = #system.now
  sleep   = ((now+P1D).date + wakeup) - (now.date + bedtime)  #DURATION

=examples for time

  12:00:34      # lunch-time, in context default time-zone
  23:59:61      # with max leap seconds
  09:11:11.111  # precise time (upto nanoseconds)

  12:00:34 + PT30M -> TIME 12:30:34   # end of lunch
  12:00:34 - PT15M -> TIME 11:45:34   # round-up coworkers
  23:40:00 + PT7H  -> TIME 06:40:00   # early rise
  07:00:00 - 23

  18:00:00+0200 ==  17:00:00+0100 -> BOOLEAN
  18:00:00+0200 <=> 17:00:00+0100 -> INTEGER

Attributes:

  time = 12:23:34.56+0110
  time.hour        -> INTEGER 12
  time.minute      -> INTEGER 23
  time.second      -> INTEGER 34
  time.fracsec     -> FLOAT   34.56
  time.tz          -> STRING  +0110

=cut

package
	MF::TIME;
use base 'Math::Formula::Type';

use constant GIGA => 1_000_000_000; 

sub _match { '(?:[01][0-9]|2[0-3]) \: [0-5][0-9] \: (?:[0-5][0-9]) (?:\.[0-9]+)?' }

sub _token($)
{	my $time = $_[1];
	my $ns   = $time->{ns};
	my $frac = $ns ? sprintf(".%09d", $ns) =~ s/0+$//r : '';
	sprintf "%02d:%02d:%02d%s", $time->{hour}, $time->{minute}, $time->{second}, $frac;
}

sub _value($)
{	my ($self, $token) = @_;
	$token =~ m/^ ([01][0-9]|2[0-3]) \: ([0-5][0-9]) \: ([0-5][0-9]) (?:(\.[0-9]+))? $/x
		or return;

	+{ hour => $1+0, minute => $2+0, second => $3+0, ns => ($4 //0) * GIGA };
}

our %time_attrs = (
	hour     => sub { MF::INTEGER->new(undef, $_[0]->value->{hour})  },
	minute   => sub { MF::INTEGER->new(undef, $_[0]->value->{minute}) },
	second   => sub { MF::INTEGER->new(undef, $_[0]->value->{second}) },
	fracsec  => sub { my $t = $_[0]->value; MF::FLOAT->new(undef, $t->{second} + $t->{ns}/GIGA) },
);

sub attribute($) { $time_attrs{$_[1]} || $_[0]->SUPER::attribute($_[1]) }

sub _sec_diff($$)
{	my ($self, $diff, $ns) = @_;
	if($ns < 0)       { $ns += GIGA; $diff -= 1 }
	elsif($ns > GIGA) { $ns -= GIGA; $diff += 1 }

	my $sec = $diff % 60;  $diff /= 60;
	my $min = $diff % 60;
	my $hrs = ($diff / 60) % 24;
	+{ hour => $hrs, minute => $min, second => $sec, nanosecond => $ns};
}

sub infix($$@)
{	my $self = shift;
	my ($op, $right, $context) = @_;

	if($op eq '+' || $op eq '-')
	{	# normalization is a pain, so bluntly convert to seconds
		my $time = $self->value;
		my $was  = $time->{hour} * 3600 + $time->{minute} * 60 + $time->{second};

		if(my $r = $right->isa('MF::TIME') ? $right : $right->cast('MF::TIME', $context))
		{	my $v    = $r->value;
			my $min  = $v->{hour} * 3600 + $v->{minute} * 60 + $v->{second};
			my $diff = $self->_sec_diff($was - $min, $time->{ns} - $v->{ns});
			my $frac = $diff->{nanosecond} ? sprintf(".%09d", $diff->{nanosecond}) =~ s/0+$//r : '';
			return MF::DURATION->new(sprintf "PT%dH%dM%d%sS", $diff->{hour}, $diff->{minute},
				$diff->{second}, $frac);
		}

		if(my $r = $right->isa('MF::DURATION') ? $right : $right->cast('MF::DURATION', $context))
	 	{	my (undef, $hours, $mins, $secs, $ns) =
				$r->value->in_units(qw/days hours minutes seconds nanoseconds/);

			my $dur  = $hours * 3600 + $mins * 60 + $secs;
			my $diff = $op eq '+' ? $was + $dur       : $was - $dur;
			my $nns  = $op eq '+' ? $time->{ns} + $ns : $time->{ns} - $ns;
			return MF::TIME->new(undef, $self->_sec_diff($diff, $ns));
		}
	}

	$self->SUPER::infix(@_);
}

#-----------------
=section MF::DURATION, a period of time
Durations are usually added to datetimes, and may be negative.  They are formatted in
ISO8601 standard format, which is a bit akward, to say the least.

Durations can be added (C<+>) together, subtracted (C<->) together,
or multiplied by an integer factor.  The prefix C<+> and C<-> are also supported.

B<Be warned> that operations may not always lead to the expected results.
A sum of 12 months will lead to 1 year, but 40 days will stay 40 days because the
day length differs per month.  This will only be resolved when the duration is added
to an actual datetime.

Two durations can be compared numerically.  However: a bit of care must be taken.
Sometimes, it is only clear what the ordering is when seend from a certain datetime.
For instance, which is longer: P1M or P30D?  The current time ("now") is used as
reference point.  Otherwise, add some other datetime to both durations before
comparison.

=examples for duration

  P1Y2M5D          # duration one year, 2 months, 5 days
  PT1M             # mind the "T" before smaller than day values!
  P3MT5M           # confusing: 3 months + 5 minutes
  PT3H4M8.2S       # duration 3 hours, 4 minutes, just over 8 seconds

  - -P1Y           # prefix + and =
  P3Y2M + P1YT3M5S  -> DURATION P4Y2MT3M5S
  P1Y2MT3H5M - P3Y8MT5H13M14S -> DURATION -P2Y6MT2H8M14S
  P1DT2H * 4        -> DURATION P4DT8H
  4 * P1DT2H        -> DURATION P4DT8H

  P1Y > P1M         -> BOOLEAN true
  PT20M <=> PT19M   => INTEGER 1     # -1, 0, 1
=cut

package
	MF::DURATION;
use base 'Math::Formula::Type';

use DateTime::Duration ();

sub _match { '[+-]? P (?:[0-9]+Y)? (?:[0-9]+M)? (?:[0-9]+D)? '
	. ' (?:T (?:[0-9]+H)? (?:[0-9]+M)? (?:[0-9]+(?:\.[0-9]+)?S)? )? \b';
}

use DateTime::Format::Duration::ISO8601 ();
my $dur_format = DateTime::Format::Duration::ISO8601->new;
# Implementation dus not like negatives, but DateTime::Duration does.

sub _token($) { ($_[1]->is_negative ? '-' : '') . $dur_format->format_duration($_[1]) }

sub _value($)
{	my $value    = $_[1];
	my $negative = $value =~ s/^-//;
	my $duration = $dur_format->parse_duration($value);
	$negative ? $duration->multiply(-1) : $duration;
}

sub prefix($$)
{   my ($self, $op, $context) = @_;
		$op eq '+' ? $self
	  : $op eq '-' ? MF::DURATION->new('-' . $self->token)
	  : $self->SUPER::prefix($op, $context);
}

sub infix($$@)
{	my $self = shift;
	my ($op, $right, $context) = @_;

	if($op eq '+' || $op eq '-')
	{	my $r  = $right->isa('MF::DURATION') ? $right : $right->cast('MF::DURATION', $context);
		my $v  = $self->value->clone;
		my $dt = ! $r ? undef : $op eq '+' ? $v->add_duration($r->value) : $v->subtract_duration($r->value);
		return MF::DURATION->new(undef, $dt) if $r;
	}
	elsif($op eq '*')
	{	my $r  = $right->isa('MF::INTEGER') ? $right : $right->cast('MF::INTEGER', $context);
		return MF::DURATION->new(undef, $self->value->clone->multiply($r->value)) if $r;
	}
	elsif($op eq '<=>')
	{	my $r  = $right->isa('MF::DURATION') ? $right : $right->cast('MF::DURATION', $context);
		return MF::INTEGER->new(undef, DateTime::Duration->compare($self->value, $r->value)) if $r;
	}

	$self->SUPER::infix(@_);
}

my %dur_attrs;   # Sorry, the attributes of DateTime::Duration make no sense
sub attribute($) { $dur_attrs{$_[1]} || $_[0]->SUPER::attribute($_[1]) }

#-----------------
=section MF::NAME, refers to something in the context
The M<Math::Formula::Context> object contains translations for names to
contextual objects.  Names are the usual tokens: unicode alpha-numeric
characters and underscore (C<_>), where the first character cannot be
a digit.

On the right-side of a fragment indicator C<#> or method indicator C<.>,
the name will be lookup in the features of the object on the left of that
operator.

A name which is not right of a C<#> or C<.> can be cast into an object
from the context.

Names are symbol: are not a value by themselves, so have no values to
be ordered.  However, they may exist however: test it with prefix operator
C<exists>.

=examples of names

  tic
  route66
  the_boss
  _42       # and '_' works as a character
  αβΩ       # unicode alpha nums allowed

  7eleven   # not allowed: no start with number

  See "Math::Formula::Context" for the following
  #frag     # (prefix #) fragment of default object
  .method   # (prefix .) method on default object
  name#frag # fragment of object 'name'
  file.size # method 'size' on object 'file'

Attributes on names

  exists live     -> BOOLEAN    # does formula 'live' exist?
  not exists live -> BOOLEAN

=cut

package
	MF::NAME;
use base 'Math::Formula::Type';

use Log::Report 'math-formula', import => [ qw/error __x/ ];

my $pattern = '[_\p{Alpha}][_\p{AlNum}]*';
sub _match() { $pattern }

sub value($) { error __x"name '{name}' cannot be used as value.", name => $_[0]->token }

=c_method validated $string, $where
Create a MF::NAME from a $string which needs to be validated for being a valid
name.  The $where will be used in error messages when the $string is invalid.
=cut

sub validated($$)
{	my ($class, $name, $where) = @_;

	$name =~ qr/^$pattern$/o
		or error __x"Illegal name '{name}' in '{where}'",
			name => $name =~ s/[^_\p{AlNum}]/ϴ/gr, where => $where;

	$class->new($name);
}

sub cast(@)
{	my ($self, $type, $context) = @_;

	if($type->isa('MF::FRAGMENT'))
	{	my $frag = $self->token eq '' ? $context : $context->fragment($self->token);
		return MF::FRAGMENT->new($frag->name, $frag) if $frag;
	}

	$context->evaluate($self->token, expect => $type);
}

sub prefix($$)
{	my ($self, $op, $context) = @_;

	return MF::BOOLEAN->new(undef, defined $context->formula($self->token))
		if $op eq 'exists';

	$self->SUPER::prefix($op, $context);
}

sub infix(@)
{	my $self = shift;
	my ($op, $right, $context) = @_;
	my $name = $self->token;

	if($op eq '.')
	{	my $left = $name eq '' ? MF::FRAGMENT->new($context->name, $context) : $context->evaluate($name);
		return $left->infix(@_) if $left;
	}

	if($op eq '#')
	{	my $left = $name eq '' ? MF::FRAGMENT->new($context->name, $context) : $context->fragment($name);
		return $left->infix(@_) if $left;
	}

	my $left = $context->evaluate($name);
	$left ? $left->infix($op, $right, $context): undef;
}


#-----------------
=section MF::PATTERN, pattern matching
This type implements pattern matching for the C<like> and C<unlike> operators.
The patterns are similar to file-system patterns.  However, there is no special meaning
to leading dots and '/'.

Pattern matching constructs are C<*> (zero or more characters), C<?> (any single
character), and C<[abcA-Z]> (one of a, b, c, or capital), C<[!abc]> (not a, b, or c).
Besides, it supports curly alternatives like C<*.{jpg,gif,png}>.

=examples of patterns

  "abc" like "b"     -> BOOLEAN false
  "abc" like "*b*"   -> BOOLEAN false
  "abc" like "*c"    -> BOOLEAN true

  "abc" unlike "b"   -> BOOLEAN true
  "abc" unlike "*b*" -> BOOLEAN true
  "abc" unlike "*c"  -> BOOLEAN false

=cut

package
	MF::PATTERN; 
use base 'MF::STRING';

use Log::Report 'math-formula', import => [ qw/warning __x/ ];

sub _token($) {
	warning __x"cannot convert qr back to pattern, do {regexp}", regexp => $_[1];
    "pattern meaning $_[1]";
}

sub _from_string($)
{	my ($class, $string) = @_;
	$string->token;        # be sure the pattern is kept as token: cannot be recovered
	bless $string, $class;
}

sub _to_regexp($)
{	my @chars  = $_[0] =~ m/( \\. | . )/gxu;
	my (@regexp, $in_alts, $in_range);

	foreach my $char (@chars)
	{	if(length $char==2) { push @regexp, $char; next }
		if($char !~ /^[\[\]*?{},!]$/) { push @regexp, $in_range ? $char : quotemeta $char }
		elsif($char eq '*') { push @regexp, '.*' }
		elsif($char eq '?') { push @regexp, '.' }
		elsif($char eq '[') { push @regexp, '['; $in_range++ }
		elsif($char eq ']') { push @regexp, ']'; $in_range=0 }
		elsif($char eq '!') { push @regexp, $in_range && $regexp[-1] eq '[' ? '^' : '\!' }
		elsif($char eq '{') { push @regexp, $in_range ? '{' : '(?:'; $in_range or $in_alts++ }
		elsif($char eq '}') { push @regexp, $in_range ? '}' : ')';   $in_range or $in_alts=0 }
		elsif($char eq ',') { push @regexp, $in_alts ? '|' : '\,' }
		else {die}
	}
	my $regexp = join '', @regexp;
	qr/^${regexp}$/u;
}

=method regexp
Returns the pattern as compiled regular expression object (qr).
=cut

sub regexp() { $_[0][2] //= _to_regexp($_[0]->value) }

#-----------------
=section MF::REGEXP, Regular expression
This type implements regular expressions for the C<=~> and C<!~> operators.

The base of a regular expression is a single or double quote string. When the
operators are detected, those will automatically be cast into a regexp.

=examples of regular expressions

  "abc" =~ "b"       -> BOOLEAN true
  "abc" =~ "c$"      -> BOOLEAN true
  "abc" !~ "b"       -> BOOLEAN false
  "abc" !~ "c$"      -> BOOLEAN false
=cut

package
	MF::REGEXP;
use base 'MF::STRING';

sub _from_string($)
{	my ($class, $string) = @_;
	bless $string, $class;
}

=method regexp
Returns the regular expression as compiled object (qr).
=cut

sub regexp
{	my $self = shift;
	return $self->[2] if defined $self->[2];
	my $value = $self->value =~ s!/!\\/!gr;
	$self->[2] = qr/$value/xu;
}

#-----------------
=section MF::FRAGMENT, access to externally provided data

The used of this type is explained in M<Math::Formula::Context>.

=cut

package
	MF::FRAGMENT;
use base 'Math::Formula::Type';

use Log::Report 'math-formula', import => [ qw/panic error __x/ ];

sub name    { $_[0][0] }
sub context { $_[0][1] }

sub infix($$@)
{	my $self = shift;
	my ($op, $right, $context) = @_;
	my $name = $right->token;

	if($op eq '#' && $right->isa('MF::NAME'))
	{	my $fragment = $self->context->fragment($name)
			or error __x"cannot find fragment '{name}' in '{context}'",
				name => $name, context => $context->name;

		return $fragment;
	}

	if($op eq '.' && $right->isa('MF::NAME'))
	{	my $result = $self->context->evaluate($name);
		return $result if $result;
	}

	$self->SUPER::infix(@_);
}

1;
