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

done_testing;
