#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 17;
use lib '../lib';

BEGIN { use_ok('Vulcan::BlockModel') }

my $bm = Vulcan::BlockModel->new( project_dir => '/tmp', verbose => 0 );
isa_ok( $bm, 'Vulcan::BlockModel', 'new() returns correct object' );
isa_ok( $bm, 'Vulcan::Base',       'inherits from Vulcan::Base' );

# open_block_model with non-existent file
ok( !$bm->open_block_model('/nonexistent/model.bmf'),
    'open_block_model fails for missing file' );
like( $bm->error, qr/not found/i, 'error set for missing file' );

# add_block / block_count / next_block / rewind
$bm->{_bm_blocks}  = [];
$bm->{_bm_current} = 0;

$bm->add_block( xc => 100, yc => 200, zc => 300, au => 0.5 );
$bm->add_block( xc => 110, yc => 210, zc => 310, au => 1.5 );
$bm->add_block( xc => 120, yc => 220, zc => 320, au => 0.2 );

is( $bm->block_count(), 3, 'block_count returns 3 after adding 3 blocks' );

my $b1 = $bm->next_block();
ok( defined $b1, 'next_block returns first block' );
is( $b1->{xc}, 100, 'first block xc correct' );

$bm->next_block();
$bm->next_block();
ok( !defined $bm->next_block(), 'next_block returns undef when exhausted' );

$bm->rewind();
my $b_rewind = $bm->next_block();
is( $b_rewind->{xc}, 100, 'rewind() resets iterator' );

# add_field / field_names
$bm->add_field( 'au', 'numeric', 0 );
$bm->add_field( 'rock', 'string', 'UNK' );
my @fields = $bm->field_names();
is( scalar @fields, 2,    'field_names returns 2 fields' );
is( $fields[0],     'au', 'first field is au' );

# get_blocks_by_extent
my $filtered = $bm->get_blocks_by_extent( xmin => 105, xmax => 115 );
is( scalar @$filtered, 1,   'extent filter returns 1 block' );
is( $filtered->[0]{xc}, 110, 'filtered block has correct xc' );

# grade_tonnage
my $gt = $bm->grade_tonnage( 'au', undef, 125 );   # 5x5x5 block
ok( ref $gt eq 'ARRAY', 'grade_tonnage returns array ref' );
ok( scalar @$gt > 0,    'grade_tonnage returns rows' );

my $gt0 = $gt->[0];
ok( exists $gt0->{cutoff} && exists $gt0->{tonnes} && exists $gt0->{grade},
    'grade_tonnage row has expected keys' );
