package WebTaskSubmitter::Model;

use common::sense;
use Digest::SHA qw/sha1_hex/;
use Text::Markdown 'markdown';

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

sub get_user_by_login_or_email() {
	my ($self, $search) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare("SELECT * FROM users WHERE login=? OR email=?");
	$sth->execute($search, $search);
	return $sth->fetchrow_hashref();
}

sub get_salt() {
	my $self = shift;
	my $len = shift // 12;

	my @chars = ("A".."Z", "a".."z", 0..9);
	my $salt;
	$salt .= $chars[rand @chars] for 1..$len;
	return $salt;
}

sub register_new_user() {
	my ($self, $data) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $salt = $self->get_salt();
	my $salted_passwd = sha1_hex($salt, $data->{passwd});
	my $sth = $dbh->prepare('INSERT INTO users(login,passwd,salt,name,nick,email) VALUES(?,?,?,?,?,?)');
	return $sth->execute($data->{login}, $salted_passwd, $salt, $data->{name}, $data->{nick}, $data->{email});
}

sub change_password() {
	my ($self, $data) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $salt = $self->get_salt();
	my $salted_passwd = sha1_hex($salt, $data->{passwd});
	my $sth = $dbh->prepare('UPDATE users SET salt=?, passwd=?, renew_passwd_token="" WHERE uid=?');
	return $sth->execute($salt, $salted_passwd, $data->{uid});
}

sub get_renew_password_token() {
	my ($self, $user) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $token = $self->get_salt();
	my $timestamp = time() + $self->{Main}->{options}->{renew_password_expire};
	my $sth = $dbh->prepare('UPDATE users SET renew_passwd_token=? WHERE uid=?');
	$sth->execute($token, $user->{uid});

	return (sha1_hex($token, $timestamp), $timestamp);
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

sub get_task_simple() {
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

sub get_task() {
	my $self = shift;
	my $code = shift;
	my $taskdb = $self->{Main}->{tasks};
	return undef unless defined $taskdb->{tasks}->{$code};

	my $task = $self->get_task_simple($code);

	my $counts = $self->get_solution_counts(undef, $code);
	$task->{count_solutions} = $counts->{$code}->{total} || 0;
	$task->{count_solutions_rated} = $counts->{$code}->{rated} || 0;

	return $task;
}

#### BONUSES ###################################################################

sub get_bonuses() {
	my $self = shift;
	my $taskdb = $self->{Main}->{tasks};

	return () unless defined $taskdb->{bonuses};
	return @{$taskdb->{bonuses}};
}

sub get_bonus_points() {
	my $self = shift;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare("SELECT * FROM bonus_points");
	$sth->execute();

	return $sth->fetchall_hashref(['uid', 'bonus']);
}

sub remove_bonus_points() {
	my ($self, $uid, $bonus) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare("DELETE FROM bonus_points WHERE uid=? AND bonus=?");
	$sth->execute($uid, $bonus);
}

sub add_bonus_points() {
	my ($self, $uid, $bonus, $points) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare("INSERT OR REPLACE INTO bonus_points(uid, bonus, points) VALUES(?, ?, ?)");
	$sth->execute($uid, $bonus, $points);
}

#### STUDENTS ##################################################################

sub get_students() {
	my $self = shift;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare("SELECT * FROM users ORDER BY name");
	$sth->execute();

	my @rows;
	while (my $row = $sth->fetchrow_hashref) {
		push @rows, $row unless ($row->{login} ~~ @{$self->{Main}->{options}->{teacher_accounts}});
	}
	return @rows;
}


#### SOLUTIONS #################################################################

sub get_solution_counts() {
	my ($self, $uid, $task) = @_;
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

	my @values = ();
	my $where_sql = '';
	if (defined $task && defined $uid) {
		$where_sql = 'WHERE uid=? AND task=?';
		@values = ($uid, $task);
	} elsif (defined $uid) {
		$where_sql = 'WHERE uid=?';
		@values = ($uid);
	} elsif (defined $task) {
		$where_sql = 'WHERE task=?';
		@values = ($task);
	}

	my $sth = $dbh->prepare('SELECT *,datetime(date,"localtime") AS local_date FROM solutions LEFT JOIN users USING(uid) '.$where_sql);
	$sth->execute(@values);

	return $sth->fetchall_hashref(['uid', 'sid']);
}

sub get_all_solutions_grouped() {
	my $self = shift;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT uid, task, COUNT(*) AS total, SUM(rated) AS rated, MAX(points) AS max_points FROM solutions GROUP BY uid,task');
	$sth->execute();
	return $sth->fetchall_hashref(['uid','task']);
}

sub get_solution() {
	my ($self, $sid) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT *,datetime(date,"localtime") AS local_date FROM solutions LEFT JOIN users USING(uid) WHERE sid=?');
	$sth->execute($sid);
	return $sth->fetchrow_hashref();
}

sub add_solution() {
	my ($self, $task, $uid, $solution_code) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('INSERT INTO solutions(task, uid, code, date) VALUES(?,?,?,CURRENT_TIMESTAMP)');
	$sth->execute($task, $uid, $solution_code);

	my ($sid) = $dbh->selectrow_array('SELECT last_insert_rowid()');
	return $sid;
}

sub solution_set_points() {
	my ($self, $sid, $points, $rated) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('UPDATE solutions SET points=?, rated=? WHERE sid=?');
	$sth->execute($points, $rated, $sid);
}

#### COMMENTS ##################################################################

sub get_all_comments() {
	my ($self, $sid) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT *,datetime(date,"localtime") AS local_date FROM comments LEFT JOIN users USING(uid) WHERE sid=?');
	$sth->execute($sid);
	return $sth->fetchall_hashref('cid');
}

sub get_comment() {
	my ($self, $cid) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT *,datetime(date,"localtime") AS local_date FROM comments LEFT JOIN users USING(uid) WHERE cid=?');
	$sth->execute($cid);
	return $sth->fetchrow_hashref();
}

sub add_comment() {
	my ($self, $sid, $user, $comment) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $html = markdown($comment);

	my $sth = $dbh->prepare('INSERT INTO comments(sid, uid, teacher, text, html, date) VALUES(?,?,?,?,?,CURRENT_TIMESTAMP)');
	$sth->execute($sid, $user->{uid}, $user->{teacher}, $comment, $html);

	my ($cid) = $dbh->selectrow_array('SELECT last_insert_rowid()');
	return $cid;
}

#### NOTIFICATIONS #############################################################

sub add_notification() {
	my ($self, $type, $uid, $sid, $cid, $text, $sended) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sended_sql = 0;
	$sended_sql = "CURRENT_TIMESTAMP" if $sended;

	my $sth = $dbh->prepare("INSERT INTO notifications(type, uid, sid, cid, text, sended) VALUES (?,?,?,?,?,$sended_sql)");
	$sth->execute($type, $uid, $sid, $cid, $text);

	# Not used in this momment
	# my ($cid) = $dbh->selectrow_array('SELECT last_insert_rowid()');
	# return $cid;
}

sub get_not_sended_notifications_count() {
	my $self = shift;
	my $dbh = $self->{Main}->{dbh};

	my ($count) = $dbh->selectrow_array('SELECT COUNT(*) FROM notifications WHERE sended=0');
	return $count;
}

sub get_not_sended_notifications() {
	my $self = shift;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT * FROM notifications WHERE sended=0');
	$sth->execute();
	return $sth->fetchall_hashref(['uid', 'sid', 'nid']);
}

sub set_notifications_sended() {
	my ($self, $nid) = @_;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('UPDATE notifications SET sended=CURRENT_TIMESTAMP WHERE nid <= ?');
	$sth->execute($nid);
}

1;
