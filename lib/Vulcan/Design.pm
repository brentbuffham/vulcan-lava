package Vulcan::Design;

use strict;
use warnings;
use parent 'Vulcan::Base';
use Carp qw(croak);

our $VERSION = '0.01';

=head1 NAME

Vulcan::Design - Interface to Maptek Vulcan design files (.dgd.isis)

=head1 SYNOPSIS

    use Vulcan::Design;

    my $dgd = Vulcan::Design->new(
        project_dir => '/data/projects/mymine',
        verbose     => 1,
    );

    $dgd->open_project() or die $dgd->error;

    my $design = $dgd->open_design('pit_design.dgd.isis')
        or die $dgd->error;

    # List all layers
    my @layers = $dgd->layer_names();

    # Read objects from a layer
    my $objects = $dgd->get_objects( layer => 'FINAL_PIT_CREST' );
    for my $obj (@$objects) {
        printf "Object: %s  Points: %d\n",
            $obj->{name}, scalar @{ $obj->{points} };
    }

    $dgd->close_design();

=head1 DESCRIPTION

C<Vulcan::Design> provides a Perl interface for working with Maptek Vulcan
design database files (C<.dgd.isis>).

Key capabilities:

=over 4

=item * Open and close design database files

=item * List and query layers

=item * Read and write design objects (polygons, polylines, points)

=item * Create new objects and assign attributes

=item * Export objects to common formats

=back

=head1 METHODS

=cut

# ---------------------------------------------------------------------------
# Design file management
# ---------------------------------------------------------------------------

=head2 open_design( $filename )

Open a Vulcan design database file.  Returns the object on success,
false on failure.

=cut

sub open_design {
    my ( $self, $filename ) = @_;

    croak 'filename required' unless defined $filename;

    my $path = $self->_resolve_path($filename);

    unless ( -f $path ) {
        $self->_set_error("design file not found: $path");
        return 0;
    }

    $self->{_dgd_file}   = $path;
    $self->{_dgd_layers} = {};

    $self->_log("Opened design: $path");
    return $self;
}

=head2 close_design()

Close the currently open design database.

=cut

sub close_design {
    my ($self) = @_;

    if ( $self->{_dgd_file} ) {
        $self->_log("Closed design: $self->{_dgd_file}");
        delete $self->{$_} for qw(_dgd_file _dgd_layers);
    }
    return $self;
}

=head2 design_file()

Returns the path of the currently open design file, or undef.

=cut

sub design_file {
    my ($self) = @_;
    return $self->{_dgd_file};
}

# ---------------------------------------------------------------------------
# Layer management
# ---------------------------------------------------------------------------

=head2 layer_names()

Returns a sorted list of layer names present in the design file.

=cut

sub layer_names {
    my ($self) = @_;
    return sort keys %{ $self->{_dgd_layers} // {} };
}

=head2 layer_exists( $layer )

Returns true if the named layer exists in the current design file.

=cut

sub layer_exists {
    my ( $self, $layer ) = @_;
    croak 'layer name required' unless defined $layer;
    return exists $self->{_dgd_layers}{$layer} ? 1 : 0;
}

=head2 create_layer( $layer, %attributes )

Create a new layer.  Optional attributes include C<description>,
C<colour> (integer Vulcan colour index), and C<linestyle>.

=cut

sub create_layer {
    my ( $self, $layer, %attrs ) = @_;

    croak 'layer name required' unless defined $layer;

    if ( $self->layer_exists($layer) ) {
        $self->_set_error("layer already exists: $layer");
        return 0;
    }

    $self->{_dgd_layers}{$layer} = {
        description => $attrs{description} // '',
        colour      => $attrs{colour}      // 1,
        linestyle   => $attrs{linestyle}   // 'solid',
        objects     => [],
    };

    $self->_log("Created layer: $layer");
    return $self;
}

=head2 delete_layer( $layer )

Delete a layer and all its objects.  Returns the object on success,
false if the layer does not exist.

=cut

sub delete_layer {
    my ( $self, $layer ) = @_;

    croak 'layer name required' unless defined $layer;

    unless ( $self->layer_exists($layer) ) {
        $self->_set_error("layer not found: $layer");
        return 0;
    }

    delete $self->{_dgd_layers}{$layer};
    $self->_log("Deleted layer: $layer");
    return $self;
}

# ---------------------------------------------------------------------------
# Object management
# ---------------------------------------------------------------------------

=head2 get_objects( layer => $layer )

Return an array reference of design objects in the given layer.
Each object is a hash reference with keys: C<name>, C<type>
(C<'polygon'>, C<'polyline'>, or C<'point'>), C<points> (array ref of
C<[x, y, z]> triples), and optional C<attributes>.

=cut

sub get_objects {
    my ( $self, %args ) = @_;

    my $layer = $args{layer} // croak 'layer required';

    unless ( $self->layer_exists($layer) ) {
        $self->_set_error("layer not found: $layer");
        return [];
    }

    return $self->{_dgd_layers}{$layer}{objects};
}

=head2 add_object( layer => $layer, name => $name, type => $type, points => \@pts, %attrs )

Add a design object to a layer.  C<points> is an array reference of
C<[x, y, z]> triples.  C<type> is C<'polygon'>, C<'polyline'>, or
C<'point'>.

=cut

sub add_object {
    my ( $self, %args ) = @_;

    my $layer  = $args{layer}  // croak 'layer required';
    my $name   = $args{name}   // croak 'name required';
    my $type   = $args{type}   // 'polyline';
    my $points = $args{points} // croak 'points required';

    unless ( $self->layer_exists($layer) ) {
        $self->_set_error("layer not found: $layer");
        return 0;
    }

    my $object = {
        name       => $name,
        type       => $type,
        points     => $points,
        attributes => $args{attributes} // {},
    };

    push @{ $self->{_dgd_layers}{$layer}{objects} }, $object;
    $self->_log("Added object '$name' to layer '$layer'");
    return $self;
}

=head2 object_count( $layer )

Returns the number of objects in the given layer.

=cut

sub object_count {
    my ( $self, $layer ) = @_;
    croak 'layer name required' unless defined $layer;
    return 0 unless $self->layer_exists($layer);
    return scalar @{ $self->{_dgd_layers}{$layer}{objects} };
}

# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

sub _resolve_path {
    my ( $self, $filename ) = @_;
    return $filename if $filename =~ m{^/};
    return $self->{project_dir} . '/' . $filename;
}

=head1 SEE ALSO

L<Vulcan::Base>, L<Vulcan::BlockModel>, L<Vulcan::Triangulation>,
L<Vulcan::Drillhole>, L<Vulcan::Utils>

=head1 AUTHOR

Brent Buffham

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
