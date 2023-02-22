#!/usr/bin/env perl
  
use warnings;
use strict;
use utf8;

use Math::Formula ();
use Test::More;

my $expr = Math::Formula->new(test => 1);

sub try_pattern($$)
{   my ($pattern, $expect) = @_;
	my $regexp  = MF::PATTERN::_to_regexp($pattern);
	is ref $regexp, 'Regexp', "pattern '$pattern'";
	is $regexp, $expect;
}

try_pattern '',   '(?^u:^$)';
try_pattern 'a',  '(?^u:^a$)';
try_pattern 'ab', '(?^u:^ab$)';

try_pattern '*',  '(?^u:^.*$)';
try_pattern '\*', '(?^u:^\*$)';

try_pattern '?',  '(?^u:^.$)';
try_pattern '\?', '(?^u:^\?$)';

try_pattern '[a-z]', '(?^u:^[a-z]$)';
try_pattern '[!a-z!]', '(?^u:^[^a-z\!]$)';
try_pattern '[{}]', '(?^u:^[{}]$)';

try_pattern 'b,c,d', '(?^u:^b\,c\,d$)';
try_pattern 'a{b,c,d}e', '(?^u:^a(?:b|c|d)e$)';
try_pattern '{b,c,d}', '(?^u:^(?:b|c|d)$)';

done_testing;
