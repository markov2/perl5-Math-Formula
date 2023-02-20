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

is_deeply $expr->_tokenize('48'), [ MF::INTEGER->new('48') ];

foreach (
	[ '42'          => 42          ],
	[ '43k'         => 43_000      ],
	[ '44M'         => 44_000_000  ],
	[ '45kibi'      => 45 * 1024   ],
	[ '46_000'      => 46000       ],
	[ '470_123_456' => 470_123_456 ],
	[ '470_123_456' => 470_123_456 ],
)
{   my ($token, $value) = @$_;

	my $i = MF::INTEGER->new($token);
	is $i->token, $token, "... $token";
	cmp_ok $i->value, '==', $value;
}

done_testing;
