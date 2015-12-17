use strict;
use warnings;

use File::Temp qw(tempdir);

use Test::More tests => 5;




use_ok('Parallel::Scoreboard');

# create temporary directory
my $base_dir = '/tmp/02worker_id.d';
my $id       = int( rand( 100 ) );

# instantiate
my $sb = Parallel::Scoreboard->new(
    base_dir => $base_dir,
    worker_id => sub { $id; } 
  
);
ok($sb, 'instantiation');

# save my status (to check the behavior of fork-after-status-update)
$sb->update('me manager');


# check status
sleep 1;
my $stats = $sb->read_all();
is($stats->{$id}, 'me manager', 'check my status');

$sb->update('time to do some stuff!');
$stats = $sb->read_all();
is($stats->{$id}, 'time to do some stuff!', 'check my status 2');


$sb = Parallel::Scoreboard->new(
    base_dir => $base_dir,
    worker_id => $id 
  
);


isnt( $sb->worker_id, $id, 'Error with the worker_id reference' );
