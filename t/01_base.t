#!/usr/bin/perl

use strict;
use warnings;
use Test::More tests => 14;
use lib '../lib';

# Test Vulcan::Base
BEGIN { use_ok('Vulcan::Base') }

my $v = Vulcan::Base->new( verbose => 0 );
isa_ok( $v, 'Vulcan::Base', 'new() returns correct object' );

# project_dir not set
ok( !$v->open_project(), 'open_project fails with no project_dir' );
like( $v->error, qr/project_dir not set/i, 'error set when project_dir missing' );

# non-existent project_dir
$v = Vulcan::Base->new( project_dir => '/nonexistent/path' );
ok( !$v->open_project(), 'open_project fails with missing directory' );
like( $v->error, qr/does not exist/i, 'error set for missing directory' );

# valid project_dir (use /tmp)
my $tmpdir = '/tmp';
$v = Vulcan::Base->new( project_dir => $tmpdir );
ok( $v->open_project(), 'open_project succeeds with valid directory' );
ok( $v->is_connected(), 'is_connected returns true after open_project' );
is( $v->project_dir(), $tmpdir, 'project_dir returns correct path' );

# close project
$v->close_project();
ok( !$v->is_connected(), 'is_connected returns false after close_project' );

# error / clear_error
$v = Vulcan::Base->new();
$v->_set_error('test error');
is( $v->error(), 'test error', 'error() returns set message' );
$v->clear_error();
is( $v->error(), '', 'clear_error() resets error message' );

# verbose getter/setter
$v = Vulcan::Base->new( verbose => 0 );
is( $v->verbose(), 0, 'verbose defaults to 0' );
$v->verbose(1);
is( $v->verbose(), 1, 'verbose setter works' );
