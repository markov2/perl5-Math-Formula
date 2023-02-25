#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Test::More;
use DateTime               ();
use DateTime::Duration     ();

use Math::Formula          ();
use Math::Formula::Context ();

### expression as string

my $expr1   = Math::Formula->new(test1 => 1);
ok defined $expr1, 'created normal formula';
is $expr1->name, 'test1';
is $expr1->expression, '1';

my $answer1 = $expr1->evaluate;
ok defined $answer1, '... got answer';
isa_ok $answer1, 'Math::Formula::Type', '...';
cmp_ok $answer1->value, '==', 1;


### expression as code

my $expr2   = Math::Formula->new(test2 => sub { MF::INTEGER->new(2) });
ok defined $expr2, 'created formula from CODE';
is $expr2->name, 'test2';
isa_ok $expr2->expression, 'CODE';

my $answer2 = $expr2->evaluate;
ok defined $answer2, '... got answer';
isa_ok $answer2, 'Math::Formula::Type', '...';
cmp_ok $answer2->value, '==', 2;

### Return a node

my $expr3 = Math::Formula->new(π => MF::FLOAT->new(undef, 3.14));
ok defined $expr3, 'formula with node';
my $answer3 = $expr3->evaluate;
ok defined $answer3, '... answer';
isa_ok $answer3, 'MF::FLOAT', '...';
is $answer3->token, '3.14';

### auto-detection of Code returns

my $timestamp = '2012-01-03T12:37:03+0410';
my $dt  = DateTime->new(year => 2012, month => 1, day => 3, hour => 12,
	minute => 37, second => 3, time_zone => '+0410');
my $duration = 'P7YT23S';
my $dur = DateTime::Duration->new(years => 7, seconds => 23);

my $context = Math::Formula::Context->new(name => 'test');

my @blessed = (
	[ $timestamp     => 'MF::DATETIME', $dt  ],
	[ $duration      => 'MF::DURATION', $dur ],
	[ test           => 'MF::FRAGMENT', $context ],
);

my @unblessed = (
	[ 42             => 'MF::INTEGER' => 42     ],
	[ 3.14           => 'MF::FLOAT'   => 3.14   ],
	[ 'true'         => 'MF::BOOLEAN' => 'true' ],
	[ '"(?^:^a.b$)"' => 'MF::REGEXP'  => qr/^a.b$/  ],
	[ $timestamp     => 'MF::DATETIME' => $timestamp ],
	[ '01:02:03'     => 'MF::TIME'    => '01:02:03' ],
	[ '01:02:03.123' => 'MF::TIME'    => '01:02:03.123' ],
	[ '2023-02-24'      => 'MF::DATE'    => '2023-02-24' ],
	[ '2023-02-25+0100' => 'MF::DATE'    => '2023-02-25+0100' ],
	[ $duration      => 'MF::DURATION'   => $duration ],
	[ '"tic"'        => 'MF::STRING'  => '"tic"' ],
	[ '"tac"'        => 'MF::STRING'  => 'tac'   ],
	[ "'toe'"        => 'MF::STRING'  => "'toe'" ],
);

foreach (@blessed, @unblessed)
{	my ($token, $type, $input) = @$_;

	my $result = $expr1->toType($input);
	ok defined $result, "result produced for $type";
	isa_ok $result, 'Math::Formula::Type', '... ';
	is ref $result, $type;

	is $result->token, $token;
}

done_testing;
