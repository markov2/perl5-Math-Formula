#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Math::Formula ();
use Math::Formula::Context ();
use Test::More;

my $expr = Math::Formula->new(test => 1);

is_deeply $expr->_tokenize('mark'),       [ MF::NAME->new('mark') ];
is_deeply $expr->_tokenize('_mark_42'),   [ MF::NAME->new('_mark_42') ];
is_deeply $expr->_tokenize('Зеленський'), [ MF::NAME->new('Зеленський') ];

is_deeply $expr->_tokenize('tic tac toe'), [MF::NAME->new('tic'), MF::NAME->new('tac'), MF::NAME->new('toe')];

my $context = Math::Formula::Context->new(name => 'test',
	formula => { live => '42' },
);
ok defined $context, 'Testing existence';

is $context->value('live'), 42, '... live';
is $context->run('exists live')->token, 'true';
is $context->run('not exists live')->token, 'false';
is $context->run('exists green_man')->token, 'false', '... green man';
is $context->run('not exists green_man')->token, 'true';

done_testing;
