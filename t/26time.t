#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Math::Formula ();
use Test::More;

use DateTime;
use DateTime::TimeZone::OffsetOnly ();

my $expr = Math::Formula->new(
	name       => 'test',
	expression => '1',
);

### PARSING

foreach my $token (
	"01:28:12",
	"01:28:12.345",
	"01:28:12+0300",
	"01:28:12.345+0300",
) {
	my $node = MF::TIME->new($token);
	is_deeply $expr->_tokenize($token), [$node], $token;

	my $dt = $node->value;
	isa_ok $dt, 'DateTime';
}

### FORMATTING

my $random = DateTime->new(year => 2000, hour => 3,
  minute => 20, second => 4, nanosecond => 1_023_000,
  time_zone => DateTime::TimeZone::OffsetOnly->new(offset => '-1012'),
);

my $node = MF::TIME->new(undef, $random);
is $node->token, '03:20:04.001023-1012', 'formatting with frac';

my $random2 = DateTime->new(year => 2000, hour => 7, minute => 12, second => 8,
  time_zone => DateTime::TimeZone::OffsetOnly->new(offset => '+0234'),
);

my $node2 = MF::TIME->new(undef, $random2);
is $node2->token, '07:12:08+0234', 'formatting without frac';

### CASTING

### PREFIX OPERATORS

### INFIX OPERATORS

my @infix = (
	[ '12:30:34+0000', 'MF::TIME', '12:00:34 + PT30M' ],
	[ '11:45:34+0000', 'MF::TIME', '12:00:34 - PT15M' ],
	[ '06:40:00+0000', 'MF::TIME', '23:40:00 + PT7H'  ],
);

foreach (@infix)
{	my ($result, $type, $rule) = @$_;

	$expr->_test($rule);
	my $eval = $expr->evaluate({});
	is $eval->token, $result, "$rule -> $result";
	isa_ok $eval, $type;
}

done_testing;
