#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 19;
use lib '../lib';

BEGIN { use_ok('Vulcan::Design') }

my $dgd = Vulcan::Design->new( project_dir => '/tmp', verbose => 0 );
isa_ok( $dgd, 'Vulcan::Design', 'new() returns correct object' );
isa_ok( $dgd, 'Vulcan::Base',   'inherits from Vulcan::Base' );

# open_design with non-existent file
ok( !$dgd->open_design('/nonexistent/design.dgd.isis'),
    'open_design fails for missing file' );
like( $dgd->error, qr/not found/i, 'error set for missing file' );

# Manually set up internal state for unit tests (no actual file needed)
$dgd->{_dgd_file}   = '/tmp/fake.dgd.isis';
$dgd->{_dgd_layers} = {};

# layer_names / create_layer / layer_exists
my @init_layers = $dgd->layer_names();
is( scalar @init_layers, 0, 'no layers initially' );

ok( $dgd->create_layer( 'PIT_CREST', colour => 3 ),
    'create_layer succeeds' );
ok( $dgd->layer_exists('PIT_CREST'), 'layer_exists returns true' );
my @post_layers = $dgd->layer_names();
is( scalar @post_layers, 1, 'one layer after create' );

# duplicate layer
ok( !$dgd->create_layer('PIT_CREST'), 'duplicate create_layer fails' );
like( $dgd->error, qr/already exists/i, 'error set for duplicate layer' );

# add_object / get_objects / object_count
$dgd->add_object(
    layer  => 'PIT_CREST',
    name   => 'pit_crest_1',
    type   => 'polygon',
    points => [ [0,0,0], [10,0,0], [10,10,0], [0,10,0] ],
);

is( $dgd->object_count('PIT_CREST'), 1, 'object_count is 1' );

my $objs = $dgd->get_objects( layer => 'PIT_CREST' );
is( scalar @$objs, 1, 'get_objects returns 1 object' );
is( $objs->[0]{name}, 'pit_crest_1', 'object name correct' );
is( $objs->[0]{type}, 'polygon',     'object type correct' );
is( scalar @{ $objs->[0]{points} }, 4, 'object has 4 points' );

# get_objects for non-existent layer
my $none = $dgd->get_objects( layer => 'NO_SUCH_LAYER' );
is( ref $none, 'ARRAY', 'get_objects returns arrayref for missing layer' );
is( scalar @$none, 0,   'get_objects returns empty for missing layer' );

# delete_layer
ok( $dgd->delete_layer('PIT_CREST'), 'delete_layer succeeds' );
