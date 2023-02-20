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

done_testing;
