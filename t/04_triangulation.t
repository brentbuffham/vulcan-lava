#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 16;
use lib '../lib';

BEGIN { use_ok('Vulcan::Triangulation') }

my $tri = Vulcan::Triangulation->new( project_dir => '/tmp', verbose => 0 );
isa_ok( $tri, 'Vulcan::Triangulation', 'new() returns correct object' );
isa_ok( $tri, 'Vulcan::Base',          'inherits from Vulcan::Base' );

# open_triangulation with non-existent file
ok( !$tri->open_triangulation('/nonexistent/surface.00t'),
    'open_triangulation fails for missing file' );
like( $tri->error, qr/not found/i, 'error set for missing file' );

# Set up internal state for unit tests
$tri->{_tri_vertices}  = [];
$tri->{_tri_triangles} = [];

is( $tri->vertex_count(),   0, 'vertex_count is 0 initially' );
is( $tri->triangle_count(), 0, 'triangle_count is 0 initially' );
ok( !defined $tri->extents(), 'extents returns undef with no vertices' );

# Build a simple tetrahedron (4 vertices, 4 triangles)
my $i0 = $tri->add_vertex(  0,  0,  0 );
my $i1 = $tri->add_vertex( 10,  0,  0 );
my $i2 = $tri->add_vertex(  5, 10,  0 );
my $i3 = $tri->add_vertex(  5,  5, 10 );

is( $tri->vertex_count(), 4, 'vertex_count is 4 after adding vertices' );

$tri->add_triangle( $i0, $i1, $i2 );
$tri->add_triangle( $i0, $i1, $i3 );
$tri->add_triangle( $i0, $i2, $i3 );
$tri->add_triangle( $i1, $i2, $i3 );

is( $tri->triangle_count(), 4, 'triangle_count is 4 after adding triangles' );

# extents
my $ext = $tri->extents();
ok( defined $ext, 'extents returns a value' );
is( $ext->{xmin},  0, 'xmin correct' );
is( $ext->{xmax}, 10, 'xmax correct' );
is( $ext->{zmax}, 10, 'zmax correct' );

# calculate_area and calculate_volume return numeric values
my $area   = $tri->calculate_area();
my $volume = $tri->calculate_volume();
ok( $area   > 0, 'calculate_area returns positive value' );
ok( $volume > 0, 'calculate_volume returns positive value' );
