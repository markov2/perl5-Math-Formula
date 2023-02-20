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

is_deeply $expr->_tokenize('" bc d "'), [MF::STRING->new('" bc d "')];
is_deeply $expr->_tokenize('"a\"b"')->[0]->value, 'a"b';
is_deeply $expr->_tokenize("'c\\'d'")->[0]->value, "c'd";

my $node1 = MF::STRING->new(" \tx\r\n \ny zw\t\t\na\n \n" );
is $node1->collapsed, 'x y zw a', '... collapsed string';

my $node2 = MF::STRING->new(undef, "ab*c");
my $r2 = $node2->cast('MF::REGEXP');
isa_ok $r2, 'MF::REGEXP', 'cast regexp';
is $r2->token, '"ab*c"';
is ref $r2->regexp, 'Regexp';
is $r2->regexp, '(?^ux:ab*c)';

my $node3 = MF::STRING->new(undef, "ab*c");
my $r3 = $node3->cast('MF::PATTERN');
isa_ok $r3, 'MF::PATTERN', 'cast pattern';
is $r3->token, '"ab*c"';
is ref $r3->regexp, 'Regexp';
is $r3->regexp .'', '(?^u:^ab.*c$)';

done_testing;
