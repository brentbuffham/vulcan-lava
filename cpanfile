# Core Perl modules required for the Vulcan::* module suite
requires 'perl', '5.010';
requires 'Carp';
requires 'POSIX';
requires 'Exporter';
requires 'File::Path';

# Test dependencies
on 'test' => sub {
    requires 'Test::More', '0.98';
};
