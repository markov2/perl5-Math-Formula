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

my $node2a = MF::STRING->new(" \tx\r\n \ny zw\t\t\na\n \n" );
is $node2a->collapsed, 'x y zw a', '... collapsed string';

done_testing;
