package WebTaskSubmitter::Model;

use common::sense;
use Digest::SHA qw/sha1_hex/;

sub new {
	my $class = shift;
	my $self = {
		Main => shift,
	};
	bless $self, $class;
	return $self;
}

#### USERS #####################################################################

sub get_user() {
	my ($self, $uid) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare("SELECT * FROM users WHERE uid=?");
	$sth->execute($uid);
	return $sth->fetchrow_hashref();
}

sub get_user_by_login() {
	my ($self, $login) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare("SELECT * FROM users WHERE login=?");
	$sth->execute($login);
	return $sth->fetchrow_hashref();
}

sub register_new_user() {
	my ($self, $data) = @_;
	my $dbh = $self->{Main}->{dbh};

	my @chars = ("A".."Z", "a".."z", 0..9);
	my $salt;
	$salt .= $chars[rand @chars] for 1..8;
	my $salted_passwd = sha1_hex($salt, $data->{passwd});
	my $sth = $dbh->prepare('INSERT INTO users(login,passwd,salt,name,email) VALUES(?,?,?,?,?)');
	return $sth->execute($data->{login}, $salted_passwd, $salt, $data->{name}, $data->{email});
}

#### TASKS (not in SQLite) #####################################################

# uid may be undef, when it is -1 it computes statistics
sub get_enabled_tasks() {
	my ($self, $uid) = @_;
	my $taskdb = $self->{Main}->{tasks};

	my $counts = $self->get_solution_counts($uid);

	my @tasks = ();
	foreach my $t (@{$taskdb->{enabled_tasks}}) {
		my $taskcode = $t->{task};
		my $task = $taskdb->{tasks}->{$taskcode};
		$task->{code} = $taskcode;
		$task->{deadline} = $t->{deadline};
		$task->{max_points} = $t->{max_points};
		$task->{count_solutions} = $counts->{$taskcode}->{total} || 0;
		$task->{count_solutions_rated} = $counts->{$taskcode}->{rated} || 0;
		$task->{points} = $counts->{$taskcode}->{max_points} || 0;
		push @tasks, $task;
	}
	return @tasks;
}

sub get_task() {
	my $self = shift;
	my $code = shift;
	my $taskdb = $self->{Main}->{tasks};

	return undef unless defined $taskdb->{tasks}->{$code};

	my $task = $taskdb->{tasks}->{$code};
	my @enabled = grep($_->{task} eq $code, @{$taskdb->{enabled_tasks}});

	$task->{enabled} = (scalar @enabled);
	$task->{deadline} = @enabled[0]->{deadline} if $task->{enabled};
	$task->{max_points} = @enabled[0]->{max_points} if $task->{enabled};

	return $task;
}

#### SOLUTIONS #################################################################

sub get_solution_counts() {
	my ($self, $uid, $task) = shift;
	my $dbh = $self->{Main}->{dbh};

	my @values = ();
	my $where_sql = '';
	if (defined $uid && defined $task) {
		$where_sql = 'WHERE uid=? AND task=?';
		@values = ($uid, $task);
	} elsif (defined $uid) {
		$where_sql = 'WHERE uid=?';
		@values = ($uid);
	} elsif (defined $task) {
		$where_sql = 'WHERE task=?';
		@values = ($task);
	}

	my $sth = $dbh->prepare("SELECT task, COUNT(*) AS total, SUM(rated) AS rated, MAX(points) AS max_points FROM solutions $where_sql GROUP BY task");
	$sth->execute(@values);

	return $sth->fetchall_hashref('task');
}

sub get_all_solutions() {
	my ($self, $uid, $task) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth;
	if (defined $task && defined $uid) {
		$sth = $dbh->prepare('SELECT * FROM solutions WHERE uid=? AND task=?');
		$sth->execute($uid, $task);
	} elsif (defined $uid) {
		$sth = $dbh->prepare('SELECT * FROM solutions WHERE uid=?');
		$sth->execute($uid);
	} elsif (defined $task) {
		$sth = $dbh->prepare('SELECT * FROM solutions WHERE task=?');
		$sth->execute($task);
	}
	return $sth->fetchall_hashref('sid');
}

sub get_solution() {
	my ($self, $sid) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT * FROM solutions WHERE sid=?');
	$sth->execute($sid);
	return $sth->fetchrow_hashref();
}

#### COMMENTS ##################################################################

sub get_all_comments() {
	my $self = shift;
	my $sid = shift;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT * FROM comments WHERE sid=?');
	$sth->execute($sid);
	return $sth->fetchall_hashref('cid');
}

1;
