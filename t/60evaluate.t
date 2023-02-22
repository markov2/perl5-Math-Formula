#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Math::Formula ();
use Test::More;

my $expr = Math::Formula->new(test => 1);

my $context = { };

sub run($$)
{   my ($expression, $expect) = @_;
    $expr->_test($expression);
    $expr->evaluate($context, expect => $expect)->value;
}

my $run0 = run '1+2', 'MF::INTEGER';
ok defined $run0, 'compute integer';
cmp_ok $run0, '==', 3;

my $run1 = run '1+2-3', 'MF::INTEGER';
ok defined $run1, '... multi op';
cmp_ok $run1, '==', 0;

my $run2 = run '1+2*3-4', 'MF::INTEGER';
ok defined $run2, '... with priority';
cmp_ok $run2, '==', 3;

done_testing;
