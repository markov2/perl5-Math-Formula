#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Math::Formula ();
use Test::More;

my $expr = Math::Formula->new(
	name       => 'test',
	expression => '1',
);

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

my $node = MF::DATETIME->new('2023-02-20T20:17:13+0100');

my $time = $node->cast('MF::TIME');
isa_ok $time, 'MF::TIME';
is $time->token, '20:17:13+0100';

my $date = $node->cast('MF::DATE');
isa_ok $date, 'MF::DATE';
is $date->token, '2023-02-20+0100';

done_testing
