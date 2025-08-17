#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package Math::Formula::Config;

use warnings;
use strict;

use Log::Report qw/math-formula/;

use File::Spec  ();

#--------------------
=chapter NAME

Math::Formula::Config - load/save formulas to file

=chapter SYNOPSIS

  my $saver = Math::Formula::Config::YAML->new(directory => $dir);
  $saver->save($context);

=chapter DESCRIPTION

The extensions of this module can be used to export and import
sets of expressions to and from a program.

The following serialization formats are supported:
=over 4
=item * JSON Math::Formula::Config::JSON
=item * YAML Math::Formula::Config::YAML
=item * INI  Math::Formula::Config::INI
=back

=chapter METHODS

=section Constructors

=c_method new %options

=requires directory DIRECTORY
In this directory, the output files will be made.  For each context (fragment),
a separate file is made.

=error Save directory required
=error Save directory '$dir' does not exist
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

#--------------------
=section Attributes

=method directory
When the configuration files will be written, and are read.
=cut

sub directory { $_[0]->{MFC_dir} }

=method path_for $file
Constructs a filename, based on the configured M<directory()>, the context's name,
and the usual filename extensions.
=cut

sub path_for($$)
{	my ($self, $file) = @_;
	File::Spec->catfile($self->directory, $file);
}

#--------------------
=section Actions

=method save $context, %options
Serialize the $context into a file as storage or to be edited by hand.
This is a useful method when default configuration templates need to
be generated.
=cut

sub save($%) { ... }

=method load $name, %options
Load a Math::Formula::Context for an INI file.

=option  filename FILENAME
=default filename <directory/$name.ini>
=cut

sub load($%) { ... }

1;
