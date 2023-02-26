package Math::Formula::Config;

use warnings;
use strict;
 
use File::Spec ();
use Log::Report 'math-formula';

=chapter NAME

Math::Formula::Config - load/save formulas to file

=chapter SYNOPSIS

  my $saver = Math::Formula::Config::YAML->new(directory => $dir);
  $saver->save($context);

=chapter DESCRIPTION

The extensions of this module can be used to export and import
sets of expressions to and from a program.

The following formats are supported:
=over 4
=item * JSON M<Math::Formula::Config::JSON>
=item * YAML M<Math::Formula::Config::YAML>
=item * INI  M<Math::Formula::Config::INI>
=back

At the moment, B<loading is not yet supported>.  That implementation will
certainly impact the output format.  The current version is ment for
studying.

=chapter METHODS

=section Constructors

=c_method new %options

=requires directory DIRECTORY
In this directory, the output files will be made.  For each context (fragment),
a separate file is made.
=cut

sub new(%) { my $class = shift; (bless {}, $class)->init({@_}) }

sub init($)
{	my ($self, $args) = @_;
	my $dir = $self->{MFC_dir} = $args->{directory}
		or error __x"Save directory required";

	-d $dir
		or error __x"Save directory '{dir}' does not exist", dir => $dir;

	$self;
}

#----------------------
=section Attributes

=method directory
=cut

sub directory { $_[0]->{MFC_dir} }

=method path_for $file
=cut

sub path_for($$)
{	my ($self, $file) = @_;
	File::Spec->catfile($self->directory, $file);
}

#----------------------
=section Actions

=method save $context, %args
Serialize the $context to a files as storage or to be editted by hand.
This is a usefull method when default configuration templates need to
be generated.
=cut


1;
