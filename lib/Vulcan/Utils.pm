package Vulcan::Utils;

use strict;
use warnings;
use Carp qw(croak);
use POSIX qw(floor tan);

our $VERSION = '0.01';

=head1 NAME

Vulcan::Utils - Utility functions for Maptek Vulcan Perl workflows

=head1 SYNOPSIS

    use Vulcan::Utils;

    # Coordinate transformations
    my ( $easting, $northing ) = Vulcan::Utils::latlon_to_utm( $lat, $lon, 54 );

    # String helpers
    my $padded = Vulcan::Utils::pad_name( 'DDH001', 12 );

    # Numeric helpers
    my $rounded = Vulcan::Utils::round( 3.14159, 2 );    # 3.14

    # File helpers
    my @bm_files = Vulcan::Utils::find_files( '/data', '*.bmf' );

=head1 DESCRIPTION

C<Vulcan::Utils> is a collection of standalone utility functions used
across the C<Vulcan::*> module suite.  Functions are exported individually
or all at once via C<:all>.

=head1 EXPORTS

Nothing is exported by default.  Available export tags:

=over 4

=item C<:coord>   latlon_to_utm, utm_to_latlon, dms_to_decimal, decimal_to_dms

=item C<:string>  pad_name, trim, sanitise_name

=item C<:numeric> round, clamp, interpolate

=item C<:file>    find_files, ensure_dir

=item C<:all>     All of the above

=back

=head1 FUNCTIONS

=cut

use Exporter 'import';
our @EXPORT_OK = qw(
    latlon_to_utm  utm_to_latlon
    dms_to_decimal decimal_to_dms
    pad_name trim sanitise_name
    round clamp interpolate
    find_files ensure_dir
);

our %EXPORT_TAGS = (
    coord   => [qw( latlon_to_utm utm_to_latlon dms_to_decimal decimal_to_dms )],
    string  => [qw( pad_name trim sanitise_name )],
    numeric => [qw( round clamp interpolate )],
    file    => [qw( find_files ensure_dir )],
    all     => \@EXPORT_OK,
);

# ---------------------------------------------------------------------------
# Coordinate helpers
# ---------------------------------------------------------------------------

=head2 dms_to_decimal( $degrees, $minutes, $seconds )

Convert degrees/minutes/seconds to decimal degrees.

    my $dec = Vulcan::Utils::dms_to_decimal( 34, 56, 12.5 );

=cut

sub dms_to_decimal {
    my ( $deg, $min, $sec ) = @_;
    croak 'degrees required' unless defined $deg;
    $min //= 0;
    $sec //= 0;
    my $sign = $deg < 0 ? -1 : 1;
    return $sign * ( abs($deg) + $min / 60 + $sec / 3600 );
}

=head2 decimal_to_dms( $decimal )

Convert decimal degrees to a C<[$degrees, $minutes, $seconds]> array ref.

=cut

sub decimal_to_dms {
    my ($decimal) = @_;
    croak 'decimal value required' unless defined $decimal;

    my $sign = $decimal < 0 ? -1 : 1;
    my $abs  = abs($decimal);
    my $deg  = floor($abs);
    my $min  = floor( ( $abs - $deg ) * 60 );
    my $sec  = ( $abs - $deg - $min / 60 ) * 3600;

    return [ $sign * $deg, $min, $sec ];
}

=head2 latlon_to_utm( $latitude, $longitude, $zone )

Approximate conversion from WGS-84 latitude/longitude (decimal degrees)
to UTM easting/northing for the given zone number.

Returns C<($easting, $northing)>.

B<Note>: This is a simplified approximation suitable for mine-scale work
in a single UTM zone.  For high-accuracy geodetic work, use a proper
geodesy library.

=cut

sub latlon_to_utm {
    my ( $lat, $lon, $zone ) = @_;

    croak 'latitude required'  unless defined $lat;
    croak 'longitude required' unless defined $lon;
    croak 'zone required'      unless defined $zone;

    use constant PI     => 3.14159265358979323846;
    use constant A      => 6_378_137.0;       # WGS-84 semi-major axis (m)
    use constant F      => 1 / 298.257223563; # flattening
    use constant K0     => 0.9996;            # scale factor
    use constant E0     => 500_000;           # false easting (m)

    my $e2  = 2 * F - F**2;
    my $e4  = $e2**2;
    my $e6  = $e2**3;

    my $lat_r  = $lat * PI / 180;
    my $lon_r  = $lon * PI / 180;
    my $lon0_r = ( ( $zone - 1 ) * 6 - 180 + 3 ) * PI / 180;

    my $N = A / sqrt( 1 - $e2 * sin($lat_r)**2 );
    my $T = tan($lat_r)**2;
    my $C = ( $e2 / ( 1 - $e2 ) ) * cos($lat_r)**2;
    my $A_ = cos($lat_r) * ( $lon_r - $lon0_r );

    my $M = A * (
        ( 1 - $e2 / 4 - 3 * $e4 / 64 - 5 * $e6 / 256 ) * $lat_r
      - ( 3 * $e2 / 8 + 3 * $e4 / 32 + 45 * $e6 / 1024 ) * sin( 2 * $lat_r )
      + ( 15 * $e4 / 256 + 45 * $e6 / 1024 ) * sin( 4 * $lat_r )
      - ( 35 * $e6 / 3072 ) * sin( 6 * $lat_r )
    );

    my $easting = K0 * $N * (
        $A_ + ( 1 - $T + $C ) * $A_**3 / 6
             + ( 5 - 18 * $T + $T**2 + 72 * $C - 58 * ( $e2 / ( 1 - $e2 ) ) ) * $A_**5 / 120
    ) + E0;

    my $northing = K0 * (
        $M + $N * tan($lat_r) * (
            $A_**2 / 2
          + ( 5 - $T + 9 * $C + 4 * $C**2 ) * $A_**4 / 24
          + ( 61 - 58 * $T + $T**2 + 600 * $C - 330 * ( $e2 / ( 1 - $e2 ) ) ) * $A_**6 / 720
        )
    );

    # Southern hemisphere: add false northing
    $northing += 10_000_000 if $lat < 0;

    return ( $easting, $northing );
}

# ---------------------------------------------------------------------------
# String helpers
# ---------------------------------------------------------------------------

=head2 trim( $string )

Remove leading and trailing whitespace from a string.

=cut

sub trim {
    my ($str) = @_;
    return '' unless defined $str;
    $str =~ s/^\s+|\s+$//g;
    return $str;
}

=head2 pad_name( $name, $width )

Right-pad a string with spaces to the given width.

=cut

sub pad_name {
    my ( $name, $width ) = @_;
    croak 'width required' unless defined $width;
    $name //= '';
    return sprintf "%-${width}s", $name;
}

=head2 sanitise_name( $name )

Replace characters that are invalid in Vulcan field/object names with
underscores and truncate to 24 characters.

=cut

sub sanitise_name {
    my ($name) = @_;
    return '' unless defined $name;
    $name =~ s/[^A-Za-z0-9_]/_/g;
    return substr( $name, 0, 24 );
}

# ---------------------------------------------------------------------------
# Numeric helpers
# ---------------------------------------------------------------------------

=head2 round( $value, $decimals )

Round C<$value> to C<$decimals> decimal places.

=cut

sub round {
    my ( $value, $decimals ) = @_;
    croak 'value required' unless defined $value;
    $decimals //= 0;
    my $factor = 10**$decimals;
    return int( $value * $factor + 0.5 ) / $factor;
}

=head2 clamp( $value, $min, $max )

Clamp C<$value> to the range C<[$min, $max]>.

=cut

sub clamp {
    my ( $value, $min, $max ) = @_;
    croak 'value required' unless defined $value;
    croak 'min required'   unless defined $min;
    croak 'max required'   unless defined $max;
    return $min if $value < $min;
    return $max if $value > $max;
    return $value;
}

=head2 interpolate( $x, $x0, $y0, $x1, $y1 )

Linear interpolation: given two points C<($x0, $y0)> and C<($x1, $y1)>,
return the Y value at C<$x>.

=cut

sub interpolate {
    my ( $x, $x0, $y0, $x1, $y1 ) = @_;
    croak 'all five values required'
        unless defined $x && defined $x0 && defined $y0
            && defined $x1 && defined $y1;
    return $y0 if $x1 == $x0;
    return $y0 + ( $y1 - $y0 ) * ( $x - $x0 ) / ( $x1 - $x0 );
}

# ---------------------------------------------------------------------------
# File helpers
# ---------------------------------------------------------------------------

=head2 find_files( $directory, $pattern )

Return a list of files under C<$directory> whose names match the glob
C<$pattern> (e.g. C<'*.bmf'>).

=cut

sub find_files {
    my ( $dir, $pattern ) = @_;

    croak 'directory required' unless defined $dir;
    croak 'pattern required'   unless defined $pattern;

    return () unless -d $dir;

    # Convert glob pattern to regex
    my $regex = $pattern;
    $regex =~ s/\./\\./g;
    $regex =~ s/\*/.*/g;
    $regex =~ s/\?/./g;
    $regex = qr/^$regex$/i;

    my @files;
    _find_recursive( $dir, $regex, \@files );
    return @files;
}

sub _find_recursive {
    my ( $dir, $regex, $files ) = @_;

    opendir( my $dh, $dir ) or return;
    while ( my $entry = readdir($dh) ) {
        next if $entry =~ /^\./;
        my $path = "$dir/$entry";
        if ( -d $path ) {
            _find_recursive( $path, $regex, $files );
        }
        elsif ( $entry =~ $regex ) {
            push @$files, $path;
        }
    }
    closedir($dh);
}

=head2 ensure_dir( $path )

Create C<$path> and any required parent directories if they do not already
exist.  Returns true on success, false on failure.

=cut

sub ensure_dir {
    my ($path) = @_;
    croak 'path required' unless defined $path;
    return 1 if -d $path;

    require File::Path;
    eval { File::Path::make_path($path) };
    return $@ ? 0 : 1;
}

=head1 SEE ALSO

L<Vulcan::Base>, L<Vulcan::BlockModel>, L<Vulcan::Design>,
L<Vulcan::Triangulation>, L<Vulcan::Drillhole>

=head1 AUTHOR

Brent Buffham

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
