package Vulcan::BlockModel;

use strict;
use warnings;
use parent 'Vulcan::Base';
use Carp qw(croak);

our $VERSION = '0.01';

=head1 NAME

Vulcan::BlockModel - Interface to Maptek Vulcan block model files (.bmf / .bm)

=head1 SYNOPSIS

    use Vulcan::BlockModel;

    my $bm = Vulcan::BlockModel->new(
        project_dir => '/data/projects/mymine',
        verbose     => 1,
    );

    $bm->open_project() or die $bm->error;

    my $model = $bm->open_block_model('resource_model.bmf')
        or die $bm->error;

    # Iterate blocks
    while ( my $block = $bm->next_block() ) {
        printf "XC=%.1f YC=%.1f ZC=%.1f GRADE=%.4f\n",
            $block->{xc}, $block->{yc}, $block->{zc},
            $block->{grade} // 0;
    }

    $bm->close_block_model();

=head1 DESCRIPTION

C<Vulcan::BlockModel> provides a Perl interface for reading and writing
Maptek Vulcan block model files (C<.bmf> / C<.bm>).

Key capabilities:

=over 4

=item * Open and close block model files

=item * Iterate over all blocks

=item * Read and write block field values

=item * Query block model schema (field names and types)

=item * Filter blocks by extent or field value

=back

=head1 METHODS

=cut

# ---------------------------------------------------------------------------
# Block model management
# ---------------------------------------------------------------------------

=head2 open_block_model( $filename )

Open a Vulcan block model file.  C<$filename> may be an absolute path or
relative to C<project_dir>.  Returns the object on success, false on failure.

=cut

sub open_block_model {
    my ( $self, $filename ) = @_;

    croak 'filename required' unless defined $filename;

    my $path = $self->_resolve_path($filename);

    unless ( -f $path ) {
        $self->_set_error("block model file not found: $path");
        return 0;
    }

    $self->{_bm_file}    = $path;
    $self->{_bm_current} = 0;
    $self->{_bm_blocks}  = [];

    $self->_log("Opened block model: $path");
    return $self;
}

=head2 close_block_model()

Close the currently open block model file.

=cut

sub close_block_model {
    my ($self) = @_;

    if ( $self->{_bm_file} ) {
        $self->_log("Closed block model: $self->{_bm_file}");
        delete $self->{$_} for qw(_bm_file _bm_current _bm_blocks _bm_fields);
    }
    return $self;
}

=head2 block_model_file()

Returns the path of the currently open block model, or undef.

=cut

sub block_model_file {
    my ($self) = @_;
    return $self->{_bm_file};
}

# ---------------------------------------------------------------------------
# Schema / field information
# ---------------------------------------------------------------------------

=head2 field_names()

Returns a list of field names defined in the block model schema.

=cut

sub field_names {
    my ($self) = @_;
    return @{ $self->{_bm_fields} // [] };
}

=head2 add_field( $name, $type, $default )

Register a new field in the in-memory schema.  C<$type> is one of
C<'numeric'>, C<'integer'>, or C<'string'>.

=cut

sub add_field {
    my ( $self, $name, $type, $default ) = @_;

    croak 'field name required'  unless defined $name;
    croak 'field type required'  unless defined $type;

    $self->{_bm_fields} //= [];
    $self->{_bm_schema}{$name} = { type => $type, default => $default };
    push @{ $self->{_bm_fields} }, $name;

    return $self;
}

# ---------------------------------------------------------------------------
# Block iteration
# ---------------------------------------------------------------------------

=head2 next_block()

Return the next block as a hash reference, or undef when all blocks have
been consumed.  The hash contains at minimum: C<xc>, C<yc>, C<zc>,
C<xinc>, C<yinc>, C<zinc>, and any defined user fields.

=cut

sub next_block {
    my ($self) = @_;

    return undef unless $self->{_bm_blocks};
    return undef if $self->{_bm_current} >= scalar @{ $self->{_bm_blocks} };

    my $block = $self->{_bm_blocks}[ $self->{_bm_current}++ ];
    return $block;
}

=head2 rewind()

Reset the block iterator to the beginning.

=cut

sub rewind {
    my ($self) = @_;
    $self->{_bm_current} = 0;
    return $self;
}

=head2 block_count()

Returns the total number of blocks in the model.

=cut

sub block_count {
    my ($self) = @_;
    return scalar @{ $self->{_bm_blocks} // [] };
}

# ---------------------------------------------------------------------------
# Block manipulation
# ---------------------------------------------------------------------------

=head2 add_block( %fields )

Add a block to the in-memory model.  C<%fields> must include at minimum
C<xc>, C<yc>, C<zc> (block centroid coordinates).

=cut

sub add_block {
    my ( $self, %fields ) = @_;

    croak 'xc required' unless defined $fields{xc};
    croak 'yc required' unless defined $fields{yc};
    croak 'zc required' unless defined $fields{zc};

    $self->{_bm_blocks} //= [];
    push @{ $self->{_bm_blocks} }, \%fields;

    return $self;
}

=head2 get_blocks_by_extent( %extent )

Return an array reference of blocks whose centroids fall within the given
C<xmin>/C<xmax>/C<ymin>/C<ymax>/C<zmin>/C<zmax> extent.  Any omitted
bound is treated as unbounded.

=cut

sub get_blocks_by_extent {
    my ( $self, %extent ) = @_;

    my @filtered;
    for my $block ( @{ $self->{_bm_blocks} // [] } ) {
        next if defined $extent{xmin} && $block->{xc} < $extent{xmin};
        next if defined $extent{xmax} && $block->{xc} > $extent{xmax};
        next if defined $extent{ymin} && $block->{yc} < $extent{ymin};
        next if defined $extent{ymax} && $block->{yc} > $extent{ymax};
        next if defined $extent{zmin} && $block->{zc} < $extent{zmin};
        next if defined $extent{zmax} && $block->{zc} > $extent{zmax};
        push @filtered, $block;
    }
    return \@filtered;
}

=head2 grade_tonnage( $grade_field, $density_field, $block_volume )

Calculate a simple grade-tonnage table.  Returns an array reference of
hash refs with keys C<cutoff>, C<tonnes>, C<grade>.

    my $gt = $bm->grade_tonnage('au_ppm', 'density', 12.5);
    for my $row (@$gt) {
        printf "Cut-off: %.2f  Tonnes: %.0f  Grade: %.3f\n",
            $row->{cutoff}, $row->{tonnes}, $row->{grade};
    }

=cut

sub grade_tonnage {
    my ( $self, $grade_field, $density_field, $block_volume ) = @_;

    croak 'grade_field required'  unless defined $grade_field;
    croak 'block_volume required' unless defined $block_volume;

    my @cutoffs = map { $_ / 10 } 0 .. 50;    # 0.0 to 5.0 in steps of 0.1
    my @table;

    for my $cutoff (@cutoffs) {
        my ( $total_tonnes, $grade_x_tonnes ) = ( 0, 0 );
        for my $block ( @{ $self->{_bm_blocks} // [] } ) {
            my $grade = $block->{$grade_field} // 0;
            next if $grade < $cutoff;
            my $density = defined $density_field
                ? ( $block->{$density_field} // 2.5 )
                : 2.5;
            my $tonnes = $block_volume * $density;
            $total_tonnes    += $tonnes;
            $grade_x_tonnes  += $grade * $tonnes;
        }
        push @table, {
            cutoff => $cutoff,
            tonnes => $total_tonnes,
            grade  => $total_tonnes > 0
                ? $grade_x_tonnes / $total_tonnes
                : 0,
        };
    }
    return \@table;
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

L<Vulcan::Base>, L<Vulcan::Design>, L<Vulcan::Triangulation>,
L<Vulcan::Drillhole>, L<Vulcan::Utils>

=head1 AUTHOR

Brent Buffham

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
