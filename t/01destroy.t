use strict;
use warnings;

use File::Temp qw(tempdir);

use Test::More;

my $has_test_warn = do {
    local $@;
    eval 'use Test::Warn';
    1;
};

if ($has_test_warn) {
    plan tests => 2;
}
else {
    plan skip_all => 'These tests require Test::Warn';
}

use_ok('Parallel::Scoreboard');

# create temporary directory
my $base_dir = tempdir(CLEANUP => 1);

# instantiate
my $sb = Parallel::Scoreboard->new(
    base_dir => $base_dir,
);

$sb->update('X');

# simulate global destruction by deleting this attribute before DESTROY is
# called
delete $sb->{base_dir};

warning_is(sub { undef $sb }, undef,
    'no warnings when object is destroyed and base_dir is undef');
