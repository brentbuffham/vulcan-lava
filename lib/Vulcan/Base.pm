package Vulcan::Base;

use strict;
use warnings;
use Carp qw(croak confess);

our $VERSION = '0.01';

=head1 NAME

Vulcan::Base - Base class providing common functionality for Maptek Vulcan Perl modules

=head1 SYNOPSIS

    use Vulcan::Base;

    my $vulcan = Vulcan::Base->new(
        project_dir => '/path/to/vulcan/project',
        verbose     => 1,
    );

    $vulcan->open_project() or die $vulcan->error;

=head1 DESCRIPTION

C<Vulcan::Base> provides the foundational interface for interacting with
Maptek Vulcan projects via Perl. It handles project connection, error
management, logging, and common utility methods shared across all
C<Vulcan::*> modules.

This module is intended to be used directly or subclassed by more
specialised modules such as L<Vulcan::BlockModel>, L<Vulcan::Design>,
L<Vulcan::Triangulation>, and L<Vulcan::Drillhole>.

=head1 METHODS

=cut

# ---------------------------------------------------------------------------
# Constructor
# ---------------------------------------------------------------------------

=head2 new( %args )

Create a new C<Vulcan::Base> instance.

  my $v = Vulcan::Base->new(
      project_dir => '/data/projects/mymine',
      verbose     => 0,   # optional, default 0
  );

=cut

sub new {
    my ( $class, %args ) = @_;

    my $self = {
        project_dir => $args{project_dir} // '',
        verbose     => $args{verbose}     // 0,
        _error      => '',
        _connected  => 0,
    };

    bless $self, $class;
    return $self;
}

# ---------------------------------------------------------------------------
# Project management
# ---------------------------------------------------------------------------

=head2 open_project()

Open (connect to) the Vulcan project specified at construction time.
Returns true on success, false on failure (see L</error>).

=cut

sub open_project {
    my ($self) = @_;

    unless ( $self->{project_dir} ) {
        $self->_set_error('project_dir not set');
        return 0;
    }

    unless ( -d $self->{project_dir} ) {
        $self->_set_error("project directory does not exist: $self->{project_dir}");
        return 0;
    }

    $self->{_connected} = 1;
    $self->_log("Opened project: $self->{project_dir}");
    return 1;
}

=head2 close_project()

Close the connection to the current Vulcan project.

=cut

sub close_project {
    my ($self) = @_;

    if ( $self->{_connected} ) {
        $self->{_connected} = 0;
        $self->_log("Closed project: $self->{project_dir}");
    }
    return 1;
}

=head2 is_connected()

Returns true if a project is currently open.

=cut

sub is_connected {
    my ($self) = @_;
    return $self->{_connected} ? 1 : 0;
}

=head2 project_dir()

Returns the project directory path.

=cut

sub project_dir {
    my ($self) = @_;
    return $self->{project_dir};
}

# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------

=head2 error()

Return the last error message, or an empty string if there was no error.

=cut

sub error {
    my ($self) = @_;
    return $self->{_error};
}

=head2 clear_error()

Clear the stored error message.

=cut

sub clear_error {
    my ($self) = @_;
    $self->{_error} = '';
    return $self;
}

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

=head2 verbose( [$bool] )

Get or set the verbose flag.  When true, informational messages are printed
to STDOUT via L</_log>.

=cut

sub verbose {
    my ( $self, $val ) = @_;
    $self->{verbose} = $val if defined $val;
    return $self->{verbose};
}

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

sub _set_error {
    my ( $self, $msg ) = @_;
    $self->{_error} = $msg;
    warn "Vulcan::Base error: $msg\n" if $self->{verbose};
    return $self;
}

sub _log {
    my ( $self, $msg ) = @_;
    print "Vulcan: $msg\n" if $self->{verbose};
    return $self;
}

=head1 SEE ALSO

L<Vulcan::BlockModel>, L<Vulcan::Design>, L<Vulcan::Triangulation>,
L<Vulcan::Drillhole>, L<Vulcan::Utils>

=head1 AUTHOR

Brent Buffham

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
