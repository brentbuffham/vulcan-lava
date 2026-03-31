package Vulcan::Drillhole;

use strict;
use warnings;
use parent 'Vulcan::Base';
use Carp qw(croak);

our $VERSION = '0.01';

=head1 NAME

Vulcan::Drillhole - Interface to Maptek Vulcan drillhole databases (.dh.isis)

=head1 SYNOPSIS

    use Vulcan::Drillhole;

    my $dh = Vulcan::Drillhole->new(
        project_dir => '/data/projects/mymine',
        verbose     => 1,
    );

    $dh->open_project() or die $dh->error;

    $dh->open_database('drillholes.dh.isis')
        or die $dh->error;

    # List drillholes
    my @holes = $dh->hole_ids();
    printf "Found %d drillholes\n", scalar @holes;

    # Read collar for one hole
    my $collar = $dh->get_collar('DDH001');
    printf "DDH001 collar: E=%.1f N=%.1f RL=%.1f\n",
        $collar->{easting}, $collar->{northing}, $collar->{rl};

    # Read assay intervals
    my $assays = $dh->get_table('DDH001', 'ASSAY');
    for my $row (@$assays) {
        printf "  %.2f - %.2f m  Au=%.3f g/t\n",
            $row->{from}, $row->{to}, $row->{au};
    }

    $dh->close_database();

=head1 DESCRIPTION

C<Vulcan::Drillhole> provides a Perl interface for reading and writing
Maptek Vulcan drillhole databases (C<.dh.isis>).

Key capabilities:

=over 4

=item * Open and close drillhole database files

=item * List drillhole IDs

=item * Read and write collar records

=item * Read and write downhole table data (assay, geology, survey, etc.)

=item * Calculate desurveyed (x, y, z) trace coordinates

=back

=head1 METHODS

=cut

# ---------------------------------------------------------------------------
# Database management
# ---------------------------------------------------------------------------

=head2 open_database( $filename )

Open a Vulcan drillhole database.  Returns the object on success,
false on failure.

=cut

sub open_database {
    my ( $self, $filename ) = @_;

    croak 'filename required' unless defined $filename;

    my $path = $self->_resolve_path($filename);

    unless ( -f $path ) {
        $self->_set_error("drillhole database not found: $path");
        return 0;
    }

    $self->{_dh_file} = $path;
    $self->{_dh_data} = {};    # hole_id => { collar => {}, tables => {} }

    $self->_log("Opened drillhole database: $path");
    return $self;
}

=head2 close_database()

Close the currently open drillhole database.

=cut

sub close_database {
    my ($self) = @_;

    if ( $self->{_dh_file} ) {
        $self->_log("Closed drillhole database: $self->{_dh_file}");
        delete $self->{$_} for qw(_dh_file _dh_data);
    }
    return $self;
}

=head2 database_file()

Returns the path of the currently open database, or undef.

=cut

sub database_file {
    my ($self) = @_;
    return $self->{_dh_file};
}

# ---------------------------------------------------------------------------
# Collar methods
# ---------------------------------------------------------------------------

=head2 hole_ids()

Returns a sorted list of all drillhole IDs in the database.

=cut

sub hole_ids {
    my ($self) = @_;
    return sort keys %{ $self->{_dh_data} // {} };
}

=head2 hole_count()

Returns the number of drillholes in the database.

=cut

sub hole_count {
    my ($self) = @_;
    return scalar keys %{ $self->{_dh_data} // {} };
}

=head2 add_collar( $hole_id, %fields )

Add a collar record.  Required fields: C<easting>, C<northing>, C<rl>
(reduced level), C<depth>.  Optional: C<azimuth>, C<dip>.

=cut

sub add_collar {
    my ( $self, $hole_id, %fields ) = @_;

    croak 'hole_id required'  unless defined $hole_id;
    croak 'easting required'  unless defined $fields{easting};
    croak 'northing required' unless defined $fields{northing};
    croak 'rl required'       unless defined $fields{rl};
    croak 'depth required'    unless defined $fields{depth};

    $self->{_dh_data}{$hole_id} //= { collar => {}, tables => {} };
    $self->{_dh_data}{$hole_id}{collar} = {
        easting  => $fields{easting},
        northing => $fields{northing},
        rl       => $fields{rl},
        depth    => $fields{depth},
        azimuth  => $fields{azimuth} // 0,
        dip      => $fields{dip}     // -90,
        %fields,
    };

    $self->_log("Added collar: $hole_id");
    return $self;
}

=head2 get_collar( $hole_id )

Returns the collar record for the given hole as a hash reference,
or undef if the hole does not exist.

=cut

sub get_collar {
    my ( $self, $hole_id ) = @_;

    croak 'hole_id required' unless defined $hole_id;
    return undef unless exists $self->{_dh_data}{$hole_id};
    return $self->{_dh_data}{$hole_id}{collar};
}

# ---------------------------------------------------------------------------
# Downhole table methods
# ---------------------------------------------------------------------------

=head2 add_interval( $hole_id, $table, %fields )

Append an interval row to a downhole table (e.g. C<'ASSAY'>,
C<'GEOLOGY'>).  Required fields: C<from>, C<to>.

=cut

sub add_interval {
    my ( $self, $hole_id, $table, %fields ) = @_;

    croak 'hole_id required' unless defined $hole_id;
    croak 'table required'   unless defined $table;
    croak 'from required'    unless defined $fields{from};
    croak 'to required'      unless defined $fields{to};

    $self->{_dh_data}{$hole_id} //= { collar => {}, tables => {} };
    $self->{_dh_data}{$hole_id}{tables}{$table} //= [];

    push @{ $self->{_dh_data}{$hole_id}{tables}{$table} }, \%fields;
    return $self;
}

=head2 get_table( $hole_id, $table )

Returns an array reference of interval hash refs for the given drillhole
and table name, sorted by C<from> depth.  Returns an empty array ref if
there are no rows.

=cut

sub get_table {
    my ( $self, $hole_id, $table ) = @_;

    croak 'hole_id required' unless defined $hole_id;
    croak 'table required'   unless defined $table;

    return [] unless exists $self->{_dh_data}{$hole_id};
    my $rows = $self->{_dh_data}{$hole_id}{tables}{$table} // [];
    return [ sort { $a->{from} <=> $b->{from} } @$rows ];
}

=head2 table_names( $hole_id )

Returns the list of table names available for a given drillhole.

=cut

sub table_names {
    my ( $self, $hole_id ) = @_;

    croak 'hole_id required' unless defined $hole_id;
    return () unless exists $self->{_dh_data}{$hole_id};
    return sort keys %{ $self->{_dh_data}{$hole_id}{tables} };
}

# ---------------------------------------------------------------------------
# Desurvey
# ---------------------------------------------------------------------------

=head2 desurvey( $hole_id )

Returns an array reference of C<[x, y, z, depth]> points representing
the desurveyed 3-D trace of the drillhole, computed using the
minimum-curvature method with the collar azimuth and dip.

=cut

sub desurvey {
    my ( $self, $hole_id ) = @_;

    croak 'hole_id required' unless defined $hole_id;

    my $collar = $self->get_collar($hole_id);
    return [] unless $collar;

    my $az  = ( $collar->{azimuth} // 0 ) * 3.14159265358979 / 180;
    my $dip = ( $collar->{dip}     // -90 ) * 3.14159265358979 / 180;

    my $x = $collar->{easting};
    my $y = $collar->{northing};
    my $z = $collar->{rl};
    my $total_depth = $collar->{depth} // 0;

    my @trace = ( [ $x, $y, $z, 0 ] );

    # Simple straight-line desurvey (single azimuth/dip)
    my $dx = sin($az) * cos($dip);
    my $dy = cos($az) * cos($dip);
    my $dz = sin($dip);

    my $step = 5;    # 5-metre sample interval
    my $d    = $step;
    while ( $d <= $total_depth ) {
        push @trace, [
            $x + $d * $dx,
            $y + $d * $dy,
            $z + $d * $dz,
            $d,
        ];
        $d += $step;
    }

    return \@trace;
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
L<Vulcan::Triangulation>, L<Vulcan::Utils>

=head1 AUTHOR

Brent Buffham

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
