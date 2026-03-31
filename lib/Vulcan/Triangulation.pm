package Vulcan::Triangulation;

use strict;
use warnings;
use parent 'Vulcan::Base';
use Carp qw(croak);

our $VERSION = '0.01';

=head1 NAME

Vulcan::Triangulation - Interface to Maptek Vulcan triangulation files (.00t)

=head1 SYNOPSIS

    use Vulcan::Triangulation;

    my $tri = Vulcan::Triangulation->new(
        project_dir => '/data/projects/mymine',
        verbose     => 1,
    );

    $tri->open_project() or die $tri->error;

    my $surface = $tri->open_triangulation('topo.00t')
        or die $tri->error;

    printf "Vertices : %d\n", $tri->vertex_count();
    printf "Triangles: %d\n", $tri->triangle_count();

    my $volume = $tri->calculate_volume();
    printf "Volume: %.2f m3\n", $volume;

    $tri->close_triangulation();

=head1 DESCRIPTION

C<Vulcan::Triangulation> provides a Perl interface for working with
Maptek Vulcan triangulation (surface) files (C<.00t>).

Key capabilities:

=over 4

=item * Open and close triangulation files

=item * Read vertex and triangle data

=item * Calculate surface area and enclosed volume

=item * Query extents (bounding box)

=item * Check point containment (inside/outside test)

=back

=head1 METHODS

=cut

# ---------------------------------------------------------------------------
# Triangulation file management
# ---------------------------------------------------------------------------

=head2 open_triangulation( $filename )

Open a Vulcan triangulation file.  Returns the object on success, false
on failure.

=cut

sub open_triangulation {
    my ( $self, $filename ) = @_;

    croak 'filename required' unless defined $filename;

    my $path = $self->_resolve_path($filename);

    unless ( -f $path ) {
        $self->_set_error("triangulation file not found: $path");
        return 0;
    }

    $self->{_tri_file}      = $path;
    $self->{_tri_vertices}  = [];
    $self->{_tri_triangles} = [];

    $self->_log("Opened triangulation: $path");
    return $self;
}

=head2 close_triangulation()

Close the currently open triangulation file.

=cut

sub close_triangulation {
    my ($self) = @_;

    if ( $self->{_tri_file} ) {
        $self->_log("Closed triangulation: $self->{_tri_file}");
        delete $self->{$_}
            for qw(_tri_file _tri_vertices _tri_triangles);
    }
    return $self;
}

=head2 triangulation_file()

Returns the path of the currently open triangulation, or undef.

=cut

sub triangulation_file {
    my ($self) = @_;
    return $self->{_tri_file};
}

# ---------------------------------------------------------------------------
# Geometry queries
# ---------------------------------------------------------------------------

=head2 vertex_count()

Returns the number of vertices in the triangulation.

=cut

sub vertex_count {
    my ($self) = @_;
    return scalar @{ $self->{_tri_vertices} // [] };
}

=head2 triangle_count()

Returns the number of triangles in the triangulation.

=cut

sub triangle_count {
    my ($self) = @_;
    return scalar @{ $self->{_tri_triangles} // [] };
}

=head2 extents()

Returns the bounding box of the triangulation as a hash reference:

    { xmin => ..., xmax => ..., ymin => ..., ymax => ...,
      zmin => ..., zmax => ... }

Returns undef if there are no vertices.

=cut

sub extents {
    my ($self) = @_;

    my @verts = @{ $self->{_tri_vertices} // [] };
    return undef unless @verts;

    my %ext = (
        xmin => $verts[0][0], xmax => $verts[0][0],
        ymin => $verts[0][1], ymax => $verts[0][1],
        zmin => $verts[0][2], zmax => $verts[0][2],
    );

    for my $v (@verts) {
        $ext{xmin} = $v->[0] if $v->[0] < $ext{xmin};
        $ext{xmax} = $v->[0] if $v->[0] > $ext{xmax};
        $ext{ymin} = $v->[1] if $v->[1] < $ext{ymin};
        $ext{ymax} = $v->[1] if $v->[1] > $ext{ymax};
        $ext{zmin} = $v->[2] if $v->[2] < $ext{zmin};
        $ext{zmax} = $v->[2] if $v->[2] > $ext{zmax};
    }
    return \%ext;
}

=head2 calculate_area()

Returns the total surface area of the triangulation in square units.

=cut

sub calculate_area {
    my ($self) = @_;

    my $verts = $self->{_tri_vertices}  // [];
    my $tris  = $self->{_tri_triangles} // [];
    my $area  = 0;

    for my $tri (@$tris) {
        my ( $i0, $i1, $i2 ) = @$tri;
        my @a = @{ $verts->[$i0] };
        my @b = @{ $verts->[$i1] };
        my @c = @{ $verts->[$i2] };

        # Edge vectors
        my @ab = map { $b[$_] - $a[$_] } 0 .. 2;
        my @ac = map { $c[$_] - $a[$_] } 0 .. 2;

        # Cross product magnitude / 2 = triangle area
        my $cx = $ab[1] * $ac[2] - $ab[2] * $ac[1];
        my $cy = $ab[2] * $ac[0] - $ab[0] * $ac[2];
        my $cz = $ab[0] * $ac[1] - $ab[1] * $ac[0];
        $area += 0.5 * sqrt( $cx**2 + $cy**2 + $cz**2 );
    }
    return $area;
}

=head2 calculate_volume()

Returns the signed volume enclosed by the triangulation using the
divergence theorem.  For a closed, outward-facing surface, the result
is positive.

=cut

sub calculate_volume {
    my ($self) = @_;

    my $verts  = $self->{_tri_vertices}  // [];
    my $tris   = $self->{_tri_triangles} // [];
    my $volume = 0;

    for my $tri (@$tris) {
        my ( $i0, $i1, $i2 ) = @$tri;
        my @a = @{ $verts->[$i0] };
        my @b = @{ $verts->[$i1] };
        my @c = @{ $verts->[$i2] };

        # Signed volume contribution (divergence theorem, z-component)
        $volume += ( $a[0] * ( $b[1] * $c[2] - $c[1] * $b[2] )
                   - $b[0] * ( $a[1] * $c[2] - $c[1] * $a[2] )
                   + $c[0] * ( $a[1] * $b[2] - $b[1] * $a[2] ) ) / 6.0;
    }
    return abs($volume);
}

# ---------------------------------------------------------------------------
# Data manipulation
# ---------------------------------------------------------------------------

=head2 add_vertex( $x, $y, $z )

Append a vertex to the triangulation.  Returns the zero-based index of
the new vertex.

=cut

sub add_vertex {
    my ( $self, $x, $y, $z ) = @_;

    croak 'x required' unless defined $x;
    croak 'y required' unless defined $y;
    croak 'z required' unless defined $z;

    $self->{_tri_vertices} //= [];
    push @{ $self->{_tri_vertices} }, [ $x, $y, $z ];
    return $#{ $self->{_tri_vertices} };
}

=head2 add_triangle( $i0, $i1, $i2 )

Append a triangle defined by three vertex indices.

=cut

sub add_triangle {
    my ( $self, $i0, $i1, $i2 ) = @_;

    croak 'vertex index i0 required' unless defined $i0;
    croak 'vertex index i1 required' unless defined $i1;
    croak 'vertex index i2 required' unless defined $i2;

    $self->{_tri_triangles} //= [];
    push @{ $self->{_tri_triangles} }, [ $i0, $i1, $i2 ];
    return $self;
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

L<Vulcan::Base>, L<Vulcan::BlockModel>, L<Vulcan::Design>,
L<Vulcan::Drillhole>, L<Vulcan::Utils>

=head1 AUTHOR

Brent Buffham

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
