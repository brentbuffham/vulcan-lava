#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 24;
use lib '../lib';

BEGIN { use_ok('Vulcan::Utils') }

use Vulcan::Utils qw(:all);

# --- dms_to_decimal ---
my $dec = dms_to_decimal( 34, 56, 12 );
ok( abs( $dec - 34.93667 ) < 0.001, 'dms_to_decimal positive' );

my $neg = dms_to_decimal( -34, 56, 12 );
ok( $neg < 0, 'dms_to_decimal negative latitude' );

# --- decimal_to_dms ---
my $dms = decimal_to_dms(34.93667);
ok( ref $dms eq 'ARRAY', 'decimal_to_dms returns arrayref' );
is( $dms->[0], 34, 'degrees correct' );
is( $dms->[1], 56, 'minutes correct' );
ok( abs( $dms->[2] - 12 ) < 0.1, 'seconds within tolerance' );

# --- latlon_to_utm ---
my ( $e, $n ) = latlon_to_utm( -27.5, 153.0, 56 );
ok( $e > 400_000 && $e < 800_000, 'easting in plausible UTM range' );
ok( $n > 0,                       'northing positive' );

# --- trim ---
is( trim('  hello  '), 'hello', 'trim removes leading/trailing spaces' );
is( trim(''),          '',      'trim handles empty string' );
is( trim(undef),       '',      'trim handles undef' );

# --- pad_name ---
my $padded = pad_name('DDH001', 10);
is( length($padded), 10,      'pad_name pads to correct width' );
like( $padded, qr/DDH001\s+/, 'pad_name right-pads with spaces' );

# --- sanitise_name ---
is( sanitise_name('hello world'), 'hello_world', 'sanitise_name replaces spaces' );
is( sanitise_name('a-b/c+d'),    'a_b_c_d',     'sanitise_name replaces special chars' );
my $long = sanitise_name('a' x 30);
is( length($long), 24, 'sanitise_name truncates to 24 chars' );

# --- round ---
is( round(3.14159, 2), 3.14, 'round to 2 decimals' );
is( round(3.14159, 0), 3,    'round to 0 decimals' );
is( round(3.5, 0),     4,    'round 0.5 rounds up' );

# --- clamp ---
is( clamp(5, 1, 10),  5,  'clamp within range unchanged' );
is( clamp(0, 1, 10),  1,  'clamp below min returns min' );
is( clamp(15, 1, 10), 10, 'clamp above max returns max' );

# --- interpolate ---
my $interp = interpolate( 5, 0, 0, 10, 100 );
is( $interp, 50, 'interpolate midpoint correct' );
