#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Test::More;

use Math::Formula ();

### expression as string

my $expr1   = Math::Formula->new(test1 => 1);
ok defined $expr1, 'created normal formula';
is $expr1->name, 'test1';
is $expr1->expression, '1';

my $answer1 = $expr1->evaluate({});
ok defined $answer1, '... got answer';
isa_ok $answer1, 'Math::Formula::Type', '...';
cmp_ok $answer1->value, '==', 1;


### expression as code

my $expr2   = Math::Formula->new(test2 => sub { MF::INTEGER->new(2) });
ok defined $expr2, 'created formula from CODE';
is $expr2->name, 'test2';
isa_ok $expr2->expression, 'CODE';

my $answer2 = $expr2->evaluate({});
ok defined $answer2, '... got answer';
isa_ok $answer2, 'Math::Formula::Type', '...';
cmp_ok $answer2->value, '==', 2;

done_testing;
