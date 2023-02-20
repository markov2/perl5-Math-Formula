#!/usr/bin/env perl
# Prove that all modules load

use Test::More;

use_ok 'Math::Formula::Token';
use_ok 'Math::Formula::Type';
use_ok 'Math::Formula';

done_testing;

