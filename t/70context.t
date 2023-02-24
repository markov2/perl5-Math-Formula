#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Math::Formula          ();
use Math::Formula::Context ();
use Test::More;

### First try empty context

my $context = Math::Formula::Context->new(name => 'test');
ok defined $context, 'created a context';
isa_ok $context, 'Math::Formula::Context';
is $context->name, 'test';

my $config = $context->config;
ok defined $config, 'collected context config';
isa_ok $config, 'MF::FRAGMENT', '...';
my $name_attr = $config->attribute('name');
ok defined $name_attr, '... has a name';
isa_ok $name_attr, 'MF::NAME', '...';
is $name_attr->value, 'test';

### Create formulas verbose

my $f1 = $context->addFormula(wakeup => '07:00:00', returns => 'MF::TIME');
ok defined $f1, 'created a first formula';
isa_ok $f1, 'Math::Formula', '...';
is $f1->name, 'wakeup';
is $f1->expression, '07:00:00';

my $f1b = $context->formula('wakeup');
ok defined $f1b,  '... retrieved';
is $f1b->name, 'wakeup';
is $f1b->expression, '07:00:00';


my $f2 = $context->addFormula(gosleep => [ '23:30:00', returns => 'MF::TIME' ]);
ok defined $f2, 'formula with params as array';

isa_ok $f2, 'Math::Formula', '...';
is $f2->name, 'gosleep';
is $f2->expression, '23:30:00';

my $f2b = $context->formula('gosleep');
ok defined $f2b,  '... retrieved';
is $f2b->name, 'gosleep';
is $f2b->expression, '23:30:00';

my $f3 = my $awake =
	Math::Formula->new(awake => 'gosleep - wakeup', returns => 'MF::DURATION');
ok defined $f3, 'pass pre-created formula';
my $f3b = $context->addFormula($f3);
ok defined $f3b, '... add does return form';
is $f3b->name, 'awake';


my $f4 = $context->addFormula(renamed => $awake);
ok defined $f4, 'add form under a different name';
is $f4->name, 'awake';

my $f4b = $context->formula('renamed');
ok defined $f4b,  '... retrieved';
is $f4b->name, 'awake';


### Now, create all in one go!

my $c2 = Math::Formula::Context->new(name => 'test');
$c2->add($awake, {
	wakeup  => '07:00:00',
	gosleep => [ '23:30:00', returns => 'MF::TIME' ],
	renamed => $awake,
});

ok $c2->formula('wakeup' )->name, 'wakeup';
ok $c2->formula('gosleep')->name, 'gosleep';
ok $c2->formula('awake'  )->name, 'awake';
ok $c2->formula('renamed')->name, 'awake';


### Even nicer

my %rules = (
	wakeup  => '07:00:00',
	gosleep => [ '23:30:00', returns => 'MF::TIME' ],
	renamed => $awake,
);

my $c3 = Math::Formula::Context->new(name => 'test',
	formula => [ $awake, \%rules ],
);

ok $c3->formula('wakeup' )->name, 'wakeup';
ok $c3->formula('gosleep')->name, 'gosleep';
ok $c3->formula('awake'  )->name, 'awake';
ok $c3->formula('renamed')->name, 'awake';

### RUN without operators

my $wakeup = $c3->evaluate('wakeup');
ok defined $wakeup, 'evaluate wakeup';
isa_ok $wakeup, 'MF::TIME';
is $wakeup->token, '07:00:00';

### RUN with INFIX operators

my $run2 = $c3->evaluate('awake');
ok defined $run2, 'run with infix operator';
isa_ok $run2, 'MF::DURATION';
is $run2->token, 'PT16H30M0S';

### RUN with PREFIX operators

ok 1, 'test context in infix op';
$c3->add(asleep => 'PT24H + -awake');
is $c3->formula('asleep')->name, 'asleep', 'test context in prefix op';

done_testing;
