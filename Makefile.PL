#!/usr/bin/env perl
use ExtUtils::MakeMaker;

use 5.012;

WriteMakefile
  ( NAME	 => 'Math::Formula'
  , VERSION      => '1.00'
  , PREREQ_PM    =>
    { 'Test::More'   => 0,
    , 'Log::Report'  => 0,

	, 'DateTime'           => 0,
	, 'DateTime::Duration' => 0,
    , 'DateTime::Format::Duration::ISO8601' => 0,
    }
  , AUTHOR       => 'Mark Overmeer <markov@cpan.org>'
  , ABSTRACT     => 'Play trics with hash keys'
  , LICENSE      => 'perl_5'

  , META_MERGE =>
      { 'meta-spec' => { version => 2 }
      , resources  =>
          { repository =>
              { type => 'git'
              , url  => 'https://github.com/markov2/perl5-Math-Formula.git'
              , web  => 'https://github.com/markov2/perl5-Math-Formula'
              }
          , homepage => 'http://perl.overmeer.net/CPAN/'
          , license  => [ 'http://dev.perl.org/licenses/' ]
          }
      }
  );

sub MY::postamble { <<'__POSTAMBLE' }

# for DIST
RAWDIR          = ../public_html/math-formula/raw
DISTDIR         = ../public_html/math-formula/source
LICENSE         = perl

# for POD
FIRST_YEAR      = 2023
EMAIL           = markov@cpan.org
WEBSITE         = http://perl.overmeer.net/CPAN/

__POSTAMBLE

