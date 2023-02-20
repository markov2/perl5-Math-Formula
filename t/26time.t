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

done_testing;
