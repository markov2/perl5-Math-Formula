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

is_deeply $expr->_tokenize('true'),     [MF::BOOLEAN->new('true')];
is_deeply $expr->_tokenize('false'),    [MF::BOOLEAN->new('false')];

my @tests = (
	# Prefix operators
	[ false => 'not true'  ],
	[ true  => 'not false' ],

	# Infix operators
	[ true  => 'true  and true'  ],
	[ false => 'false and true'  ],
	[ false => 'true  and false' ],
	[ false => 'false and false' ],

	[ true  => 'true  or  true'  ],
	[ true  => 'false or  true'  ],
	[ true  => 'true  or  false' ],
	[ false => 'false or  false' ],

	[ false => 'false and true or false' ],

	# with cast
	[ true  => 'true and 1' ],
	[ false => 'true and 0' ],
);

foreach (@tests)
{	my ($result, $rule) = @$_;

	$expr->_test($rule);
	is $expr->evaluate({})->token, $result, "$rule -> $result";
}

done_testing;
