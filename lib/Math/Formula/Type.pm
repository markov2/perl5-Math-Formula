use warnings;
use strict;

package Math::Formula::Type;
use base 'Math::Formula::Token';

# Object is an ARRAY. The first element is the token, as read from the formula
# or constructed from a computed value.  The second is a value, which can be
# used in computation.  More elements are type specific.

sub value  { my $self = shift; $self->[1] //= $self->_value($self->[0], @_) }
sub _value { $_[1] }

__PACKAGE__->CAST(
	[ 'MF::STRING' => sub { $_[0]->token } ],
);

my %cast;
sub CAST(@)
{	my $class = shift;
	while(my $def = shift)
	{	my ($to, $handler) = @$def;
		$cast{$class}{$to} = $handler;
	}
}

my %dyop;
sub DYOP(@)
{	my $class = shift;
	while(my $def = shift)
	{	my ($op, $needs, $becomes, $handler) = @$def;
		$dyop{$op}{$needs} = [ $becomes, $handler ];
	}
}

my %preop;
sub PREOP($)
{	my $class = shift;
	while(my $def = shift)
	{	my ($op, $becomes, $handler) = @$def;
		$preop{$op} = [ $becomes, $handler ];
	}
}

sub collapsed($)
{	my ($self, $node) = @_;
	$self->token =~ s/\s+/ /gr =~ s/^ //r =~ s/ $//r;
}

###
### BOOLEAN
###

package
	MF::BOOLEAN;          # no a new line, so not in CPAN index

use base 'Math::Formula::Type';

__PACKAGE__->PREOP(
	[ 'not' => 'MF::BOOLEAN', sub { ! $_[0]->value } ],
);

__PACKAGE__->DYOP(
	[ 'and', 'MF::BOOLEAN' => 'MF::BOOLEAN', sub { $_[0]->value and $_[1]->value } ],
	[  'or', 'MF::BOOLEAN' => 'MF::BOOLEAN', sub { $_[0]->value  or $_[1]->value } ],
	[ 'xor', 'MF::BOOLEAN' => 'MF::BOOLEAN', sub { $_[0]->value xor $_[1]->value } ],
);

sub _token($) {	$_[1] ? 'true' : 'false' }

###
### STRING
###

package
	MF::STRING;

use base 'Math::Formula::Type';
use Text::Glob  qw(glob_to_regex);

__PACKAGE__->DYOP(
	[ '~',      'MF::STRING' => 'MF::STRING',  sub { $_[0]->value .  $_[1]->value } ],
	[ '=~',     'MF::STRING' => 'MF::BOOLEAN', sub { $_[0]->value =~ $_[1]->value } ],
	[ '!~',     'MF::STRING' => 'MF::BOOLEAN', sub { $_[0]->value !~ $_[1]->value } ],
	[ 'like',   'MF::STRING' => 'MF::BOOLEAN', sub { $_[0]->value =~ $_[2]->pattern } ],
	[ 'unlike', 'MF::STRING' => 'MF::BOOLEAN', sub { $_[0]->value !~ $_[2]->pattern } ],
);

sub pattern { $_[0][2] //= glob_to_regex($_[0]->value) }

sub _value($)
{	my $token = $_[1];

	  substr($token, 0, 1) eq '"'
	? $token =~ s/^"//r =~ s/"$//r =~ s/\\([\\"])/$1/gr
	: $token =~ s/^'//r =~ s/'$//r =~ s/\\([\\'])/$1/gr;
}

sub _token($) { '"' . ($_[1] =~ s/[\"]/\\$1/gr) . '"' }

###
### INTEGER
###

package
	MF::INTEGER;

use base 'Math::Formula::Type';
use Log::Report 'math-formula', import => [ qw/error __x/ ];

__PACKAGE__->CAST(
	[ 'MF::FLOAT'   => sub { MF::FLOAT->new($_[0]->value) } ],
	[ 'MF::BOOLEAN' => sub { MF::BOOLEAN->new($_[0]->value) != 0 } ],
);

__PACKAGE__->PREOP(
	[ '+' => 'MF::INTEGER', sub {   $_[0]->value } ],
	[ '-' => 'MF::INTEGER', sub { - $_[0]->value } ],
);

__PACKAGE__->DYOP(
	[ '+',   'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value  +  $_[1]->value } ],
	[ '-',   'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value  -  $_[1]->value } ],
	[ '*',   'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value  *  $_[1]->value } ],
	[ '/',   'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value  /  $_[1]->value } ],
	[ '<=>', 'MF::INTEGER' => 'MF::INTEGER', sub { $_[0]->value <=> $_[1]->value } ],
);

my $gibi        = 1024 * 1024 * 1024;

my $multipliers = '[kMGTEZ](?:ibi)?\b';
sub multipliers { $multipliers }

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

###
### DATE
###

package
	MF::DATE;

use base 'Math::Formula::Type';

# In really exceptional cases, an integer expression can be mis-detected as DATE
sub _cast_int()
{	my $self = shift;
	bless $self, 'MF::INTEGER';
	$self->[0] = $self->[1] = eval "$self->[0]";
}

sub _cast_dt()
{	my $v  = $_[0]->value;
	my $dt = $v =~ /\+/ ? $v =~ s/\+/T00:00:00+/r : $v . 'T00:00:00';
	MF::DATETIME->new($dt)
}

__PACKAGE__->CAST(
	[ 'MF::DATETIME' => \&_cast_dt  ],
	[ 'MF::INTEGER'  => \&_cast_int ],
);

__PACKAGE__->DYOP(
	[ '+', 'MF::DURATION' => 'MF::DATE', sub { ... } ],
	[ '-', 'MF::DURATION' => 'MF::DATE', sub { ... } ],
);

###
### DURATION
###

package
	MF::DURATION;

use base 'Math::Formula::Type';
use DateTime::Duration ();

__PACKAGE__->DYOP(
	[ '+',   'MF::DURATION' => 'MF::DURATION', sub { $_[0]->value->clone->add_duration($_[1]->value) } ],
	[ '-',   'MF::DURATION' => 'MF::DURATION', sub { $_[0]->value->clone->subtract_duration($_[1]->value) } ],
	[ '*',   'MF::INTEGER'  => 'MF::DURATION', sub { $_[0]->value->clone->multiply($_[1]->value) } ],
	# Comparison <=> of durations depends on moment, because normalization is not possible
);

sub _token($)
{	my ($self, $dur) = @_;
	my ($Y, $M, $D, $H, $m, $S, $n) =
		$dur->in_units(qw/years months days hours minutes seconds nanoseconds/);

	return 'P0Y' if $dur->is_zero;

	my $token = $dur->is_negative ? '-P' : 'P';
	$token   .= ($Y ? $Y.'Y' : '') . ($M ? $M.'M' : '') . ($D ? $D.'D' : '');
	if($H || $m || $S || $n)
	{	$token   .= 'T' . ($H ? $H.'H' : '') . ($m ? $m.'M' : '');
		my $sec   = $n ? sprintf("%d.%09d", ($S // 0), $n) : $S;
		$token   .= $sec . 'S' if $sec;
	}

	$token = 'P0Y' if $token eq 'P';
	$token;
}

sub _value($)
{	my ($self, $token) = @_;

	$token =~ m! ^
			P (?:([0-9]+)Y)? (?:([0-9]+)M)? (?:([0-9]+)D)?
			(?:T (?:([0-9]+)H)? (?:([0-9]+)M)? (?:([0-9]+)(?:(\.[0-9]+))?S)? )?
		!x;

	DateTime::Duration->new(
		years       => $1 // 0,
		months      => $2 // 0,
	 	weeks       => 0,
		days        => $3 // 0,
		hours       => $4 // 0,
		minutes     => $5 // 0,
		seconds     => $6 // 0,
		nanoseconds => $7 ? int($7 * 1_000_000_000) : 0,
	);
}

###
### DATETIME
###

package
	MF::DATETIME;

use base 'Math::Formula::Type';
use DateTime::Duration ();

__PACKAGE__->CAST(
	[ 'MF::TIME' => sub { $_[0]->value->clone } ],
);

__PACKAGE__->DYOP(
	[ '+',   'MF::DURATION' => 'MF::DATETIME', sub { $_[0]->value->clone->add_duration($_[1]->value) } ],
	[ '-',   'MF::DURATION' => 'MF::DATETIME', sub { $_[0]->value->clone->subtract_duration($_[1]->value) } ],
	[ '-',   'MF::DATETIME' => 'MF::DURATION', sub { $_[0]->value->clone->subtract_datetime($_[1]->value) } ],
);

###
### TIME
###

package
	MF::TIME;

use base 'Math::Formula::Type';

__PACKAGE__->CAST(
	[ 'MF::DATETIME' => sub { $_[0]->value } ],
);

sub _token($) { $_[1]->ymd }

###
### NAME
###

package
	MF::NAME;

use base 'Math::Formula::Type';

sub _value($$)
{	my ($self, $token, $expr) = @_;
}

sub _fragment()
{	my ($self, $fragment, $expr) = @_;
	my $object = $self->value($expr);
	...
}

sub _method()
{	my ($self, $method, $expr) = @_;
	my $object = $self->value($expr);
	...
}

__PACKAGE__->DYOP(
	[ '#',   'MF::NAME' => undef, \&_fragment ],
	[ '.',   'MF::NAME' => undef, \&_method   ],
);

1;
