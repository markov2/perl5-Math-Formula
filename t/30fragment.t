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

{	package
		A;  # help PAUSE

	sub new { bless {}, shift }
	sub toe { MF::INTEGER->new(42) }
}

my $the_real_thing = A->new;
ok $context->addFormula(tac => sub { $the_real_thing->toe }), 'add formula';

my $tac = $context->formula('tac');
ok defined $tac, '... found attr back';
isa_ok $tac, 'Math::Formula';
my $res1 = $tac->evaluate;
isa_ok $res1, 'MF::INTEGER', '... result';
is $res1->value, 42, 'Yeh!!';


### NESTED CONTEXTS (finally!)

my $system = Math::Formula::Context->new(name => 'system');
$system->addFormula(os => '"linux"');
$context->addFragment($system);

is $context->value('.name'), 'test', 'context attribute';
is $context->value('#system.name'), 'system', 'system attribute';
is $context->value("#system.os"), 'linux', 'system formula';

#is $context->value('aap', expect => 'MF::STRING'), 'aap', 'context attribute';

done_testing;
