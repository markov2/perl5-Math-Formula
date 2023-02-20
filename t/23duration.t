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

is_deeply $expr->_tokenize('P1Y'),    [MF::DURATION->new('P1Y')];
my $long_duration = 'P2Y5M12DT11H45M12.345S';
is_deeply $expr->_tokenize($long_duration), [MF::DURATION->new($long_duration )];

my $dur1 = MF::DURATION->new('P1Y')->value;
isa_ok $dur1, 'DateTime::Duration';
cmp_ok $dur1->in_units('months'), '==', 12;  # only limited conversion support by D::D

my $dur2a = MF::DURATION->new('P20DT10H15S')->value;
isa_ok $dur2a, 'DateTime::Duration';
is $dur2a->in_units('days'), 20;    # ->days must be used icw weeks: 6 days + 2 weeks :-(
is $dur2a->hours,   10;
is $dur2a->seconds, 15;

my $dur3 = MF::DURATION->new(undef, DateTime::Duration->new);
is $dur3->token, 'PT0H0M0S';

done_testing;
