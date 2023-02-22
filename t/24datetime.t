#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Math::Formula ();
use Test::More;

my $expr = Math::Formula->new(test => 1);

### PARSING

foreach my $token (
	"2023-02-18T01:28:12",
	"2023-02-18T01:28:12.345",
	"2023-02-18T01:28:12+0300",
	"2023-02-18T01:28:12.345+0300",
) {
	my $node = MF::DATETIME->new($token);
	is_deeply $expr->_tokenize($token), [$node], $token;

	my $dt = $node->value;
	isa_ok $dt, 'DateTime';
}

### CASTING

my $node = MF::DATETIME->new('2023-02-20T20:17:13+0100');

my $time = $node->cast('MF::TIME');
isa_ok $time, 'MF::TIME';
is $time->token, '20:17:13+0100';

my $date = $node->cast('MF::DATE');
isa_ok $date, 'MF::DATE';
is $date->token, '2023-02-20+0100';

### PREFIX OPERATORS

### INFIX OPERATORS

my @infix = (
	[	'2025-02-24T13:28:34+0000',
		'MF::DATETIME',
		'2023-02-21T11:28:34 + P2Y3DT2H'
	],
	[	'2021-02-18T09:28:34+0000',
		'MF::DATETIME',
		'2023-02-21T11:28:34 - P2Y3DT2H'
	],
	[	'P2Y3DT2H',
		'MF::DURATION',
		'2023-02-21T11:28:34 - 2021-02-18T09:28:34',
	],

	[ -1, 'MF::INTEGER', '2021-02-18T09:28:34    <=> 2023-02-21T11:28:34' ],
	[ -1, 'MF::INTEGER', '2023-02-21T11:28:34.12 <=> 2023-02-21T11:28:34.24' ],
	[  0, 'MF::INTEGER', '2023-02-21T11:28:34    <=> 2023-02-21T11:28:34' ],
	[  1, 'MF::INTEGER', '2024-12-06T20:00:00    <=> 2023-02-21T11:28:34' ],
	[  1, 'MF::INTEGER', '2023-02-21T11:28:34.24 <=> 2023-02-21T11:28:34.12' ],

	[ -1, 'MF::INTEGER', '2021-02-18T09:28:34    <=> 2023-02-21' ],
	[  0, 'MF::INTEGER', '2023-02-21T09:28:34    <=> 2023-02-21' ],
	[  1, 'MF::INTEGER', '2025-02-22T09:28:34    <=> 2023-02-21' ],
);

foreach (@infix)
{	my ($result, $type, $rule) = @$_;

	$expr->_test($rule);
	my $eval = $expr->evaluate({});
	is $eval->token, $result, "$rule -> $result";
	isa_ok $eval, $type;
}

done_testing
