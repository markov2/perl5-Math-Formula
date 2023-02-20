use warnings;
use strict;

package Math::Formula::Type;
use base 'Math::Formula::Token';

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

=section Constructors

=cut

#-----------------
=section Attributes
The following attributes are supported for any Type defined on this page.

Any Type can be cast into a MF::STRING.
=cut

sub cast($)
{	my ($self, $to) = @_;
	return MF::STRING->new(undef, $self->token)
		if $to eq 'MF::STRING';
}


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

### The following are for internal administration, hence not documented.

my %infix;
sub INFIX(@)
{	my $class = shift;
	while(my $def = shift)
	{	my ($op, $needs, $becomes, $handler) = @$def;
		$infix{$op}{$needs} = [ $becomes, $handler ];
	}
}

#XXX now, the search with cast() needs to start
sub prefix { undef }

#-----------------
=section MF::BOOLEAN, a thruth value
Represents a truth value, either C<true> or C<false>.

Booleans implement the prefix operator "C<+>", and infix operators 'C<and>',
'C<or>', and 'C<xor>'.
=cut

package
	MF::BOOLEAN;          # no a new line, so not in CPAN index

use base 'Math::Formula::Type';

sub prefix($)
{	my ($self, $op) = @_;
	if($op eq 'not')
	{	return MF::BOOLEAN->new(undef, ! $_[0]->value);
	}
	$self->SUPER::prefix($op);
}

__PACKAGE__->INFIX(
	[ 'and', 'MF::BOOLEAN' => 'MF::BOOLEAN', sub { $_[0]->value and $_[1]->value } ],
	[  'or', 'MF::BOOLEAN' => 'MF::BOOLEAN', sub { $_[0]->value  or $_[1]->value } ],
	[ 'xor', 'MF::BOOLEAN' => 'MF::BOOLEAN', sub { $_[0]->value xor $_[1]->value } ],
);

sub _token($) {	$_[1] ? 'true' : 'false' }
sub _value($) { $_[1] eq 'true' }

#-----------------
=section MF::STRING, contains text
Represents a sequence of UTF8 characters, which may be used single and
double quoted.

Strings may be cast into regular expressions (MF::REGEXP) when used on the right
side of a regular expression match operator ('C<=~>' and 'C<!~>').

Strings may be cast into a pattern (MF::PATTERM) when used on the right
of a pattern match operator ('C<like>' and 'C<unlike>').

Besides the four match operators, strings can be concatenated using 'C<~>'.
=cut

package
	MF::STRING;

use base 'Math::Formula::Type';

sub cast($)
{	my ($self, $to) = @_;

	  $to eq 'MF::REGEXP'  ? MF::REGEXP->_from_string($_[0])
	: $to eq 'MF::PATTERN' ? MF::PATTERN->_from_string($_[0])
	: $self->SUPER::cast($to);
}

__PACKAGE__->INFIX(
	[ '~',      'MF::STRING'  => 'MF::STRING',  sub { $_[0]->value .  $_[1]->value } ],
	[ '=~',     'MF::REGEXP'  => 'MF::BOOLEAN', sub { $_[0]->value =~ $_[1]->regexp } ],
	[ '!~',     'MF::REGEXP'  => 'MF::BOOLEAN', sub { $_[0]->value !~ $_[1]->regexp } ],
	[ 'like',   'MF::PATTERN' => 'MF::BOOLEAN', sub { $_[0]->value =~ $_[2]->regexp } ],
	[ 'unlike', 'MF::PATTERN' => 'MF::BOOLEAN', sub { $_[0]->value !~ $_[2]->regexp } ],
);

sub _token($) { '"' . ($_[1] =~ s/[\"]/\\$1/gr) . '"' }

sub _value($)
{	my $token = $_[1];

	  substr($token, 0, 1) eq '"' ? $token =~ s/^"//r =~ s/"$//r =~ s/\\([\\"])/$1/gr
	: substr($token, 0, 1) eq "'" ? $token =~ s/^'//r =~ s/'$//r =~ s/\\([\\'])/$1/gr
	: $token;  # from code
}

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

Integers can be cast to booleans, where C<0> means C<false> and all other
numbers are C<true>.

Integers support prefix operators C<+> and C<->.

Integers support infox operators C<+>, C<->, C<*>, C</>, and all numberic comparison
operators.
=cut

package
	MF::INTEGER;

use base 'Math::Formula::Type';
use Log::Report 'math-formula', import => [ qw/error __x/ ];

sub cast($)
{	my ($self, $to) = @_;
	  $to eq 'MF::BOOLEAN' ? MF::BOOLEAN->new(undef, $_[0]->value == 0 ? 0 : 1)
#	: $to eq 'MF::FLOAT'   ? MF::FLOAT->new($_[0]->value) }
	: $self->SUPER::cast($to);
}

sub prefix($)
{	my ($self, $op) = @_;
	  $op eq '+' ? $self
	: $op eq '-' ? MF::INTEGER->new(undef, - $_[0]->value)
	: $self->SUPER::prefix($op)
}

__PACKAGE__->INFIX(
	[ '+',   'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value  +  $_[1]->value } ],
	[ '-',   'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value  -  $_[1]->value } ],
	[ '*',   'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value  *  $_[1]->value } ],
	[ '/',   'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value  /  $_[1]->value } ],
	[ '<=>', 'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value <=> $_[1]->value } ],
);

my $gibi        = 1024 * 1024 * 1024;

my $multipliers = '[kMGTEZ](?:ibi)?\b';
sub _multipliers { $multipliers }

my %multipliers = (
	k => 1000, M => 1000_000, G => 1000_000_000, T => 1000_000_000_000, E => 1e15, Z => 1e18,
	kibi => 1024, Mibi => 1024*1024, Gibi => $gibi, Tibi => 1024*$gibi, Eibi => 1024*1024*$gibi,
	Zibi => $gibi*$gibi,
);

sub _value($)
{	my ($self, $value) = @_;

	my ($v, $m) = $value =~ m/^ ( [0-9]+ (?: _[0-9][0-9][0-9] )* ) ($multipliers)? $/x
		or error __x"illegal number format for '{string}'", string => $_[1];

	($1 =~ s/_//gr) * ($2 ? $multipliers{$2} : 1);
}

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
=cut

package
	MF::DATETIME;

use base 'Math::Formula::Type';
use DateTime ();

sub cast($)
{	my ($self, $to) = @_;
		$to eq 'MF::TIME' ? MF::TIME->new(undef, $_[0]->value->clone)
	  : $to eq 'MF::DATE' ? MF::DATE->new(undef, $_[0]->value->clone)
	  : $self->SUPER::cast($to);
}

__PACKAGE__->INFIX(
	[ '+',   'MF::DURATION' => 'MF::DATETIME', sub { $_[0]->value->clone->add_duration($_[1]->value) } ],
	[ '-',   'MF::DURATION' => 'MF::DATETIME', sub { $_[0]->value->clone->subtract_duration($_[1]->value) } ],
	[ '-',   'MF::DATETIME' => 'MF::DURATION', sub { $_[0]->value->clone->subtract_datetime($_[1]->value) } ],
);

sub _value($)
{	my ($self, $token) = @_;
	$token =~ m/^
		([12][0-9]{3}) \- (0[1-9]|1[012]) \- (0[1-9]|[12][0-9]|3[01]) T
		([01][0-9]|2[0-3]) \: ([0-5][0-9]) \: ([0-5][0-9]|6[01]) (?:\.([0-9]+))?
		([+-] [0-9]{4})?
	$ /x or return;

	my $tz_offset = $8 // '+0000';  # careful with named matches :-(
	my @args = ( year => $1, month => $2, day => $3, hour => $4, minute => $5, second => $6,
		nanosecond => ($7 // 0) * 1_000_000_000 );
	my $tz = DateTime::TimeZone::OffsetOnly->new(offset => $tz_offset);

	DateTime->new(@args, time_zone => $tz);
}

#-----------------
=section MF::DATE, refers to a day in some timezone
A date has format 'YYYY-MM-DD+TZ', for instance C<2023-02-20+0100>.

The date may be cast into a datetime, where the time is set to C<00:00:00>.
This transformation is actually slightly problematic: a date means "anywhere
during the day, where a datetime is a specific moment.

You may add (C<+>) and subtract (C<->) durations from a date, which result in
datetimes because the duration may contain day fragments.
=cut

package
	MF::DATE;

use base 'Math::Formula::Type';

sub _pattern { '[12][0-9]{3} \- (?: 0[1-9] | 1[012] ) \- (?: 0[1-9]|[12][0-9]|3[01])' }

sub cast($)
{   my ($self, $to) = @_;
	if($to eq 'MF::INTEGER')
	{	# In really exceptional cases, an integer expression can be mis-detected as DATE
		bless $self, 'MF::INTEGER';
		$self->[0] = $self->[1] = eval "$self->[0]";
		return $self;
	}

	if($to eq 'MF::DATETIME')
	{	my $v  = $self->token;
		my $dt = $v =~ /\+/ ? $v =~ s/\+/T00:00:00+/r : $v . 'T00:00:00';
		return MF::DATETIME->new(undef, $dt)
	}

	$self->SUPER::cast($to);
}

__PACKAGE__->INFIX(
	[ '+', 'MF::DURATION' => 'MF::DATETIME', sub { ... } ],
	[ '-', 'MF::DURATION' => 'MF::DATETIME', sub { ... } ],
);

sub _token($) { $_[1]->ymd . $_[1]->time_zone->name }

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

#-----------------
=section MF::TIME, a moment during any day
Usefull to indicate a daily repeating event.  For instance, C<start-backup: 04:00:12>. 
=cut

package
	MF::TIME;

use base 'Math::Formula::Type';

sub _pattern { '(?:[01][0-9]|2[0-3]) \: [0-5][0-9] \: (?:[0-5][0-9]|6[01]) (?:\.[0-9]+)?' }

sub _token($)
{	my $dt   = $_[1];
	my $ns   = $dt->nanosecond;
	my $frac = $ns ? sprintf(".%09d", $dt->nanosecond) =~ s/0+$//r : '';
	$dt->hms . $frac . $dt->time_zone->name;
}

sub _value($)
{	my ($self, $token) = @_;
	$token =~ m/^
		([01][0-9]|2[0-3]) \: ([0-5][0-9]) \: ([0-5][0-9]|6[01]) (?:\.([0-9]+))?
		([+-] [0-9]{4})?
	$ /x or return;

	my $tz_offset = $5 // '+0000';  # careful with named matches :-(
	my @args = ( year => 2000, hour => $1, minute => $2, second => $3, nanosecond => ($4 // 0) * 1_000_000_000);
	my $tz = DateTime::TimeZone::OffsetOnly->new(offset => $tz_offset // '+0000');

	DateTime->new(@args, time_zone => $tz);
}

#-----------------
=section MF::DURATION, a period of time
Durations are usually added to datetimes, and may be negative.  They are formatted in
ISO8601 standard format.

Durations can be added (C<+>) together, subtracted (C<->) together,
or multiplied by an integer factor.

B<Be warned> that operations may not always lead to the expected results.
A sum of 12 months will lead to 1 year, but 40 days will stay 40 days because the
day length differs per month.  This will only be resolved when the duration is added
to an actual datetime.
=cut

package
	MF::DURATION;

use base 'Math::Formula::Type';
use DateTime::Duration ();

__PACKAGE__->INFIX(
	[ '+',   'MF::DURATION' => 'MF::DURATION', sub { $_[0]->value->clone->add_duration($_[1]->value) } ],
	[ '-',   'MF::DURATION' => 'MF::DURATION', sub { $_[0]->value->clone->subtract_duration($_[1]->value) } ],
	[ '*',   'MF::INTEGER'  => 'MF::DURATION', sub { $_[0]->value->clone->multiply($_[1]->value) } ],
	# Comparison <=> of durations depends on moment, because normalization is not possible
);

sub _pattern {
	'P (?:[0-9]+Y)? (?:[0-9]+M)? (?:[0-9]+D)? (?:T (?:[0-9]+H)? (?:[0-9]+M)? (?:[0-9]+(?:\.[0-9]+)?S)? )? \b';
}

use DateTime::Format::Duration::ISO8601 ();
my $dur_format = DateTime::Format::Duration::ISO8601->new;

sub _token($) { $dur_format->format_duration($_[1]) }
sub _value($) {	$dur_format->parse_duration($_[1])  }

#-----------------
=section MF::NAME, refers to something in the context
The M<Math::Formula::Context> object contains translations for names to
contextual objects.  Names are the usual tokens: unicode alpha-numeric
characters and underscore (C<_>), where the first character cannot be
a digit.

On the right-side of a fragment indicator C<#> or method indicator C<.>,
the name will be lookup in the features of the object on the left of that
operator.

A name which is not right of a C<#> or C<.> can be cast into a object
from the context.
=cut

package
	MF::NAME;

use base 'Math::Formula::Type';
use Log::Report 'math-formula', import => [ qw/error __x/ ];

my $pattern = '[_\p{Alpha}][_\p{AlNum}]*';
my $legal   = qr/^$pattern$/o;

sub cast($)
{	my ($self, $to, $expr, $context) = @_;

	if($to eq 'MF::OBJECT')
	{	my $object = $context->object($self->token)
			or error __x"expression '{expr}', cannot find object '{name}' in context",
				expr => $expr->name, name => $self->token;

		return $object;
	}

	$self->SUPER::cast($to);
}

sub _pattern() { $pattern }

=c_method validated $string, $where
Create a MF::NAME from a $string which needs to be validated for being a valid
name.  The $where will be used in error messages when the $string is invalid.
=cut

sub validated($$)
{	my ($class, $name, $where) = @_;

    $name =~ $legal
		or error __x"Illegal name '{name}' in '{where}'",
			name => $name =~ s/[^_\p{AlNum}]/ϴ/gr, where => $where;

	$class->new($name);
}

#-----------------
=section MF::OBJECT, access to externally provided data
=cut

package
	MF::OBJECT;

use base 'Math::Formula::Type';
use Log::Report 'math-formula', import => [ qw/error __x/ ];

sub _fragment()
{	my ($self, $fragment, $expr, $context) = @_;
	...
}

sub _method()
{	my ($self, $method, $expr) = @_;
	...
}

__PACKAGE__->INFIX(
	[ '#',   'MF::NAME' => undef, \&_fragment ],
	[ '.',   'MF::NAME' => undef, \&_method   ],
);


#-----------------
=section MF::PATTERN, pattern matching
This type implements pattern matching for the C<like> and C<unlike> operators.
The patterns are similar to file-system patterns.  However, there is no special meaning
to leading dots and '/'.

Pattern matching constructs are C<*> (zero or more characters), C<?> (any single
character), and C<[abcA-Z]> (one of a, b, c, or capital), C<[!abc]> (not a, b, or c).
Besides, it supports curly alternatives like C<*.{jpg,gif,png}>.
=cut

package
    MF::PATTERN;

use base 'MF::STRING';

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

sub regexp() { $_[0][2] //= _to_regexp($_[0]->value) }

sub _from_string($)
{	my ($class, $string) = @_;
	bless $string, $class;
}


#-----------------
=section MF::REGEXP, Regular expression
This type implements regular expressions for the C<=~> and C<!~> operators.

The base of a regular expression is a single or double quote string. When the
operators are detected, those will automatically be cast into a regexp.
=cut

package
    MF::REGEXP;

use base 'MF::STRING';

sub regexp
{	my $self = shift;
	return $self->[2] if defined $self->[2];
	my $value = $self->value =~ s!/!\\/!gr;
	$self->[2] = qr/$value/xuo;
}

sub _from_string($)
{	my ($class, $string) = @_;
	bless $string, $class;
}

1;
