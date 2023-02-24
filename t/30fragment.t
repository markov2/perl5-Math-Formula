#!/usr/bin/env perl
# Use of objects
  
use warnings;
use strict;
use utf8;

use Test::More;

use Math::Formula ();
use Math::Formula::Context ();

my $context = Math::Formula::Context->new(name => 'test');

### Simplest form

my $obj1 = MF::FRAGMENT->new('tic', $context, {}, {});
isa_ok $obj1, 'MF::FRAGMENT', 'Create first object';

{	package
		A;  # help PAUSE

	sub new { bless {}, shift }
	sub toe { MF::INTEGER->new(42) }
}

my $the_real_thing = A->new;
ok $obj1->addAttribute(tac => sub { $the_real_thing->toe }), 'add attribute';

my $tac = $obj1->attribute('tac');
ok defined $tac, '... found attr back';
isa_ok $tac, 'CODE';
my $res1 = $tac->();
isa_ok $res1, 'MF::INTEGER', '... result';
is $res1->value, 42, 'Yeh!!';


### NESTED CONTEXTS (finally!)

my $system = Math::Formula::Context->new(name => 'system');
$system->addFormula(os => '"linux"');
$context->addFragment($system);

is $context->value('.name'), 'test';
is $context->value('#system.name'), 'system';
is $context->run("#system.os"), 'linux';

done_testing;
