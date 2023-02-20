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

my $string = MF::INTEGER->new(42)->cast('MF::STRING');
ok defined $string, 'cast to string';
isa_ok $string, 'MF::STRING';
is $string->token, '"42"';

my $bool1 = MF::INTEGER->new(2)->cast('MF::BOOLEAN');
isa_ok $bool1, 'MF::BOOLEAN', 'cast to true';
is $bool1->value, 1;
is $bool1->token, 'true';

my $bool2 = MF::INTEGER->new(0)->cast('MF::BOOLEAN');
isa_ok $bool2, 'MF::BOOLEAN', 'cast to false';
is $bool2->value, 0;
is $bool2->token, 'false';

$expr->_test('+4');
cmp_ok $expr->evaluate({})->value, '==', 4, 'prefix +';

$expr->_test('-4');
cmp_ok $expr->evaluate({})->value, '==', -4, 'prefix -';

$expr->_test('+-++--4');
cmp_ok $expr->evaluate({})->value, '==', -4, 'prefix list';

done_testing;
