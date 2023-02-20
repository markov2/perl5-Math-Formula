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

my $context = {};

foreach my $token (
	"2023-02-18",
	"2023-02-18+0300",
) {
	my $node = MF::DATE->new($token);
	is_deeply $expr->_tokenize($token), [$node], $token;

	my $dt = $node->value;
	isa_ok $dt, 'DateTime';
}

my $random = DateTime->new(year => 2023, month => 2, day => 20,
	time_zone => DateTime::TimeZone::OffsetOnly->new(offset => '+0100')
);
my $node = MF::DATE->new(undef, $random);
is $node->token, '2023-02-20+0100', 'format';

# Rare case where int calc looks like date
my $tokens1 = $expr->_test('2023-02-18');
my $node1   = $expr->_tree;
ok defined $node1,  '... date as int';
isa_ok $node1, 'MF::DATE';

my $value1a = $expr->evaluate($context, 'MF::DATE');
isa_ok $value1a, 'MF::DATE', 'not converted';

my $value1b = $expr->evaluate($context, 'MF::INTEGER');
isa_ok $value1b, 'MF::INTEGER', 'converted to int';
cmp_ok $value1b->value, '==', 2003;

done_testing;
