#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 20;
use lib '../lib';

BEGIN { use_ok('Vulcan::Drillhole') }

my $dh = Vulcan::Drillhole->new( project_dir => '/tmp', verbose => 0 );
isa_ok( $dh, 'Vulcan::Drillhole', 'new() returns correct object' );
isa_ok( $dh, 'Vulcan::Base',      'inherits from Vulcan::Base' );

# open_database with non-existent file
ok( !$dh->open_database('/nonexistent/holes.dh.isis'),
    'open_database fails for missing file' );
like( $dh->error, qr/not found/i, 'error set for missing file' );

# Set up internal state
$dh->{_dh_data} = {};

is( $dh->hole_count(), 0, 'hole_count is 0 initially' );

# add_collar
$dh->add_collar( 'DDH001',
    easting  => 10000,
    northing => 20000,
    rl       => 500,
    depth    => 200,
    azimuth  => 0,
    dip      => -90,
);

is( $dh->hole_count(), 1, 'hole_count is 1 after adding collar' );
my @ids = $dh->hole_ids();
is( $ids[0], 'DDH001', 'hole_ids returns DDH001' );

my $collar = $dh->get_collar('DDH001');
ok( defined $collar,          'get_collar returns value' );
is( $collar->{easting},  10000, 'collar easting correct' );
is( $collar->{northing}, 20000, 'collar northing correct' );
is( $collar->{depth},    200,   'collar depth correct' );

# add_interval / get_table
$dh->add_interval( 'DDH001', 'ASSAY', from => 10, to => 20, au => 1.5 );
$dh->add_interval( 'DDH001', 'ASSAY', from =>  0, to => 10, au => 0.3 );
$dh->add_interval( 'DDH001', 'ASSAY', from => 20, to => 30, au => 2.1 );

my $assay = $dh->get_table('DDH001', 'ASSAY');
is( scalar @$assay, 3, 'get_table returns 3 intervals' );
is( $assay->[0]{from}, 0, 'intervals sorted by from depth' );
is( $assay->[1]{from}, 10, 'second interval from correct' );

# table_names
my @tables = $dh->table_names('DDH001');
is( scalar @tables, 1,       'one table for DDH001' );
is( $tables[0],     'ASSAY', 'table name is ASSAY' );

# get_collar for non-existent hole
ok( !defined $dh->get_collar('NOHOLE'), 'get_collar returns undef for missing hole' );

# desurvey
my $trace = $dh->desurvey('DDH001');
ok( ref $trace eq 'ARRAY', 'desurvey returns array ref' );
ok( scalar @$trace > 1,    'desurvey returns multiple points' );
