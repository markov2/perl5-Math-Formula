#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Math::Formula          ();
use Math::Formula::Context ();
use Test::More;

my $expr = Math::Formula->new(
	name       => 'test',
	expression => '1',
);

### First try empty context

my $context = Math::Formula::Context->new;
isa_ok $context, 'Math::Formula::Context';

done_testing;
