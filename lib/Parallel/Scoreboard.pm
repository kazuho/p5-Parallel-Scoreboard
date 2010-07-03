package Parallel::Scoreboard;

use Digest::MD5 qw(md5);
use Fcntl qw(:flock);
use POSIX qw(:fcntl_h);

use strict;
use warnings;

our $VERSION = 0.01;

sub new {
    my $klass = shift;
    my %args = @_;
    die "mandatory parameter:base_dir is missing"
        unless $args{base_dir};
    # create base_dir if necessary
    if (! -e $args{base_dir}) {
        mkdir $args{base_dir}
            or die "failed to create directory:$args{base_dir}:$!";
    }
    # build object
    my $self = bless {
        %args,
    }, $klass;
    # remove my status file, just in case
    unlink $self->_build_filename();
    
    return $self;
}

sub DESTROY {
    my $self = shift;
    # if file is open, close and unlink
    if ($self->{fh}) {
        close $self->{fh};
        my $fn = $self->_build_filename();
        unlink $fn;
    }
}

sub update {
    my ($self, $status) = @_;
    # open file at the first invocation (tmpfn => lock => rename)
    if ($self->{fh} && $self->{pid_for_fh} != $$) {
        # fork? close but do not unlock
        close $self->{fh};
        undef $self->{fh};
    }
    unless ($self->{fh}) {
        my $fn = $self->_build_filename();
        open my $fh, '>', "$fn.tmp"
            or die "failed to open file:$fn.tmp:$!";
        autoflush $fh 1;
        flock $fh, LOCK_EX
            or die "failed to flock file:$fn.tmp:$!";
        rename "$fn.tmp", $fn
            or die "failed to rename file:$fn.tmp to $fn:$!";
        $self->{fh} = $fh;
        $self->{pid_for_fh} = $fh;
    }
    # write to file with size of the status and its checksum
    seek $self->{fh}, SEEK_SET, 0
        or die "seek failed:$!";
    print {$self->{fh}} (
        md5($status),
        pack("N", length $status),
        $status,
    );
}

sub read_all {
    my $self = shift;
    my %ret;
    $self->_for_all(
        sub {
            my ($pid, $fh) = @_;
            # detect collision using md5
            for (1..10) {
                seek $fh, SEEK_SET, 0
                    or die "seek failed:$!";
                my $data = do { local $/; join '', <$fh> };
                # silently ignore if data is too short
                return if length($data) < 16 + 4;
                # parse input
                my $md5 = substr($data, 0, 16);
                my $size = unpack("N", substr($data, 16, 4));
                my $status = substr($data, 20, $size);
                # compare md5 to detect collision
                next
                    if md5($status) ne $md5;
                # have read correct data, save and return
                $ret{$pid} = $status;
                return;
            }
            # failed to read data in 10 consecutive attempts, bug?
            warn "failed to read status of pid:$pid, skipping";
        }
    );
    \%ret;
}

sub cleanup {
    my $self = shift;
    $self->_for_all(sub {});
}

sub _for_all {
    my ($self, $cb) = @_;
    my @files = glob "$self->{base_dir}/status_*";
    for my $fn (@files) {
        # obtain pid from filename (or else ignore)
        $fn =~ m|/status_(\d+)$|
            or next;
        my $pid = $1;
        # ignore files removed after glob but before open
        open my $fh, '<', $fn
            or next;
        # check if the file is still opened by the owner process using flock
        if ($pid != $$ && flock $fh, LOCK_EX | LOCK_NB) {
            # the owner has died, remove status file
            close $fh;
            unlink $fn
                or warn "failed to remove an obsolete scoreboard file:$fn:$!";
            next;
        }
        # invoke
        $cb->($pid, $fh);
        # close
        close $fh;
    }
}

sub _build_filename {
    my $self = shift;
    return "$self->{base_dir}/status_$$";
}

1;
__END__

=head1 NAME

Parallel::Scoreboard - A scoreboard for monitoring status of many processes

=head1 SYNOPSIS

  use Parallel::Scoreboard;

  my $scoreboard = new Parallel::Scoreboard(
      base_dir => '/tmp/my_scoreboard'
  ...

  # in each worker process
  $scoreboard->update('this is my current status');

  # to read status of all worker processes
  my $stats = $scoreboard->read_all();
  for my $pid (sort { $a <=> $b } keys %$stats) {
      print "status for pid:$pid is: ", $stats->{$pid}, "\n";
  }

=head1 DESCRIPTION

Parallel::Scoreboard is a pure-perl implementation of a process scoreboard.  By using the module it is easy to create a monitor for many worker process, like the status module of the Apache HTTP server.

Unlike other similar modules, Parallel::Scoreboard is easy to use and has no limitation on the format or the length of the statuses to be stored.  Any arbitrary data (like JSON or frozen perl object) can be saved by the worker processes as their status and read from the manager process.

=head1 METHODS

=head2 new(base_dir => $base_dir)

instantiation.  Receives the directory name in which the scoreboard files will be stored.  The directory will be created if it does not exist already.

=head2 update($status)

saves the status of the process

=head2 read_all()

reads the status of all worker processes that are alive and that have called update() more than once.  Returned value is a hashref with process ids as keys and the statuses of each processes as corresponding values.

=head2 cleanup()

remove obsolete status files found in base_dir.  The files are normally removed upon the termination of worker process, however they might be left unremoved if the worker process was killed for some reason.  The detection and removal of the obsolete status files is performed by read_all() as well.

=head1 SEE ALSO

L<IPC::ScoreBoard>
L<Proc::Scoreboard>

=head1 AUTHOR

Kazuho Oku E<lt>kazuhooku gmail.comE<gt>

=head1 LICENSE

This program is free software, you can redistribute it and/or modify it under the same terms as Perl 5.10.

=cut
