#!/usr/bin/env perl
#
# This code will be run incredabily fast, hence is tries to avoid copying etc.  It
# is not always optimally readible when your Perl skills are poor.

package Math::Formula;
use base 'Exporter';

use warnings;
use strict;
use utf8;
use re 'eval';  #XXX needed with newer than 5.16 perls?

use Log::Report;

use Math::Formula::Token;
use Math::Formula::Type;

use Data::Dumper;
$Data::Dumper::Indent = 0;

use constant {
	# Associativity
	LTR => 1, RTL => 2, NOCHAIN => 3,
};

my @associativity = qw/LTR RTL NOCHAIN/;

our %EXPORT_TAGS = ( associativity => \@associativity );
our @EXPORT_OK   = ( @associativity );

sub new(%) { my ($class, %self) = @_; (bless {}, $class)->init(\%self) }

sub init($)
{	my ($self, $args) = @_;
	$self->{MSBE_name} = $args->{name} or panic;
	$self->{MSBE_expr} = my $expr = $args->{expression} or panic;
	$self;
}

sub name()       { $_[0]->{MSBE_name} }
sub expression() { $_[0]->{MSBE_expr} }

sub _tree()
{	my $self = shift;
	$self->{MSBE_tree} ||= $self->_build_tree($self->_tokenize($self->expression), 0);
}

sub _test($$)
{	my ($self, $expr) = @_;
	$self->{MSBE_expr} = $expr;
	delete $self->{MSBE_tree};
}

###
### PARSER
###

my $multipliers = MF::INTEGER->_multipliers;
my $match_name  = MF::NAME->_pattern;
my $match_date  = MF::DATE->_pattern;
my $match_time  = MF::TIME->_pattern;
my $match_tz    = '[+-] [0-9]{4}';

my $match_duration = MF::DURATION->_pattern;

my $match_op    = join '|',
	'[*\/+\-#~.]',
	qw/=~ !~ <=>/,
	(map "$_\\b", qw/and or not xor like unlike/);

sub _tokenize($)
{	my ($self, $s) = @_;
	our @t = ();
	my $parens_open = 0;
	$s =~ m/ ^
	(?: \s*
	  (?| \# (?: \s [^\n\r]+ | $ ) \
		| ( true | false )	(?{ push @t, MF::BOOLEAN->new($+) })
		| ( \" (?: \\\" | [^"] )* \" )
							(?{ push @t, MF::STRING->new($+) })
		| ( \' (?: \\\' | [^'] )* \' )
							(?{ push @t, MF::STRING->new($+) })
		| ( $match_op )		(?{ push @t, MF::OPERATOR->new($+) })
		| ( $match_duration )
							(?{ push @t, MF::DURATION->new($+) })
		| ( $match_name )	(?{ push @t, MF::NAME->new($+) })
		| ( $match_date T $match_time (?: $match_tz )? )
							(?{ push @t, MF::DATETIME->new($+) })
		| ( $match_date (?: $match_tz )? )
							(?{ push @t, MF::DATE->new($+) })
		| ( $match_time (?: $match_tz )? )
							(?{ push @t, MF::TIME->new($+) })
		| ( [0-9][0-9_]*(?:$multipliers)? )
							(?{ push @t, MF::INTEGER->new($+) })
		| \(				(?{ push @t, MF::PARENS->new('(', ++$parens_open) })
		| \)				(?{ push @t, MF::PARENS->new(')', $parens_open--) })
		| $
		| (.+)				(?{ error __x"expression '{name}', failed at '{where}'",
								name => $self->name, where => $+ })
	  )
	)+ \z /sxo;

	! $parens_open
		or error __x"expression '{name}', parenthesis do not match", name => $self->name;

#warn Dumper \@t;
	\@t;
}

my (%prefix, %infix, %postop);
sub _build_tree($$)
{	my ($self, $t, $prio) = @_;
	return shift @$t if @$t < 2;

  PROGRESS:
	while(my $first = shift @$t)
	{
#warn "LOOP FIRST ", Dumper $first,
#warn "     MORE  ", Dumper $t;
		if($first->isa('MF::PARENS'))
		{	my $level = $first->level;

			my @nodes;
			while(my $node = shift @$t)
			{	last if $node->isa('MF::PARENS') && $node->level==$level;
				push @nodes, $node;
			}
			$first = $self->_build_tree(\@nodes, 0);
			redo PROGRESS;
		}

		if(ref $first eq 'MF::OPERATOR')  # unresolved operator
		{	my $op = $first->token;

			if($op eq '#' || $op eq '.')
			{	# Fragments and Methods are always infix, but their left-side arg
				# can be left-out.  As PREOP, they would be RTL but we need LTR
				unshift @$t, $first;
				$first = MF::NAME->new($self->defaultObjectName);
				redo PROGRESS;
			}

			my $next  = $self->_build_tree($t, $prio)
				or error __x"expression '{name}', monadic '{op}' not followed by anything useful",
				    name => $self->name, op => $op;
#warn "HERE";

			$first = MF::PREFIX->new($op, $next);
			redo PROGRESS;
		}

		my $next = $t->[0]
			or return $first;   # end of expression

ref $next or warn $next;
		ref $next eq 'MF::OPERATOR'
			or error __x"expression '{name}', expected infix operator but found '{type}'",
				name => $self->name, type => ref $next;

		my $op = $next->token;
		@$t or error __x"expression '{name}', infix operator '{op}' requires right-hand argument",
				name => $self->name, op => $op;

		my ($next_prio, $assoc) = MF::OPERATOR->find($op);

		return $first
			if $next_prio < $prio
			|| ($next_prio==$prio && $assoc==LTR);

		shift @$t;    # apply the operator
		$first = MF::INFIX->new($op, $first, $self->_build_tree($t, $next_prio));
		redo PROGRESS;
	}
}

sub defaultObjectName() { 'unit' }

=method evaluate $context, [$type]
Calculate the value for this expression given the $context.  When the expected $type
is given, the result will be guaranteed of the correct type or C<undef>.
=cut

sub evaluate($)
{	my ($self, $context, $expect) = @_;
	my $result = $self->_tree->_compute($context, $self);

	# For external evaluation calls, we must follow the request
	$expect && ! $result->isa($expect) ? $result->cast($expect) : $result;
}

1;

