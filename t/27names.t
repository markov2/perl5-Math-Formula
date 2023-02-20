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

is_deeply $expr->_tokenize('mark'),       [ MF::NAME->new('mark') ];
is_deeply $expr->_tokenize('_mark_42'),   [ MF::NAME->new('_mark_42') ];
is_deeply $expr->_tokenize('Зеленський'), [ MF::NAME->new('Зеленський') ];

is_deeply $expr->_tokenize('tic tac toe'), [MF::NAME->new('tic'), MF::NAME->new('tac'), MF::NAME->new('toe')];

done_testing;
