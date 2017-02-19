package WebTaskSubmitter::Worker;

use common::sense;
use Digest::SHA qw/sha1_hex/;
use Email::Valid;
use Text::Markdown 'markdown';

use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		Main => shift,
	};
	bless $self, $class;
	return $self;
}

sub randStr {
	return join('', map{('a'..'z','A'..'Z',0..9)[rand 62]} 0..shift);
}

# Presumptions: not logged in user
sub manage_login() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $texts = $self->{Main}->{View}->{texts};
	my $dbh = $self->{Main}->{dbh};

	if (length $data->{login} && length $data->{passwd}) {
		my $sth = $dbh->prepare('SELECT * FROM users WHERE login=?');
		$sth->execute($data->{login});
		if (my $row = $sth->fetchrow_hashref()) {
			my $hash = sha1_hex($row->{salt}, $data->{passwd});
			if ($row->{passwd} eq $hash) {
				$self->{Main}->login('user', $row->{uid}, $row->{name});
			}
		}
		$self->{Main}->{errors}->{login} = $texts->{error_login_failed};
	}
}

sub registration_check() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $texts = $self->{Main}->{View}->{texts};
	my $dbh = $self->{Main}->{dbh};

	my $errors = {};

	my $sth = $dbh->prepare('SELECT * FROM users WHERE login=?');
	$sth->execute($data->{login});
	$errors->{login} = $texts->{error_login_used} if ($sth->fetchrow_array);
	$errors->{login} = $texts->{error_login_empty} unless length($data->{login});

	$errors->{passwd} = sprintf($texts->{error_passwd_min_length}, 5) if length($data->{passwd}) < 5;
	$errors->{passwd} = $texts->{error_passwd_mismatch} if $data->{passwd} ne $data->{passwd_check};
	$errors->{name} = $texts->{error_name_empty} unless length($data->{name});
	$errors->{email} = $texts->{error_email_wrong} unless Email::Valid->address($data->{email});

	$self->{Main}->{errors} = $errors;

	return not keys %$errors;
}

sub manage_registration() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $texts = $self->{Main}->{View}->{texts};
	my $dbh = $self->{Main}->{dbh};

	return unless length($data->{login});
	return unless $self->registration_check();

	my @chars = ("A".."Z", "a".."z", 0..9);
	my $salt;
	$salt .= $chars[rand @chars] for 1..8;
	my $salted_passwd = sha1_hex($salt, $data->{passwd});
	my $sth = $dbh->prepare('INSERT INTO users(login,passwd,salt,name,email) VALUES(?,?,?,?,?)');
	$sth->execute($data->{login}, $salted_passwd, $salt, $data->{name}, $data->{email});

	$self->{Main}->{status} = 'registration_completed';
}

sub manage_logout() {
	my $self = shift;
	$self->{Main}->{status} = 'logout_completed';
	$self->{Main}->logout();
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

sub manage_task() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $taskdb = $self->{Main}->{tasks};
	my $dbh = $self->{Main}->{dbh};

	my $task = $self->get_task($data->{code});
	# Check if task exists...
	$self->{Main}->redirect('tasklist') unless $task;
	# ... and is enabled
	$self->{Main}->redirect('tasklist') unless $task->{enabled};

	# If there is solution submitted
	if (length($data->{solution_code})) {
		my $sth = $dbh->prepare('INSERT INTO solutions(task, uid, code, date) VALUES(?,?,?,CURRENT_TIMESTAMP) ');
		$sth->execute($data->{code}, $self->{Main}->{user}->{uid}, $data->{solution_code});

		my ($sid) = $dbh->selectrow_array('SELECT last_insert_rowid()');
		my $html = markdown($data->{solution_comment});

		$sth = $dbh->prepare('INSERT INTO comments(sid, teacher, text, html, date) VALUES(?,0,?,?,CURRENT_TIMESTAMP)');
		$sth->execute($sid, $data->{solution_comment}, $html);

		$self->{Main}->redirect('solution', {sid => $sid});
	}
}

sub get_solution() {
	my $self = shift;
	my $sid = shift;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT * FROM solutions WHERE sid=?');
	$sth->execute($sid);
	return $sth->fetchrow_hashref();
}

sub get_all_comments() {
	my $self = shift;
	my $sid = shift;
	my $dbh = $self->{Main}->{dbh};

	my $sth = $dbh->prepare('SELECT * FROM comments WHERE sid=?');
	$sth->execute($sid);
	return $sth->fetchall_hashref('cid');
}

sub manage_solution() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $dbh = $self->{Main}->{dbh};
	my $user = $self->{Main}->{user};

	my $row = $self->get_solution($data->{sid});
	$self->{Main}->redirect('tasklist') unless ($row);
	# Test if logged in user (or teacher)
	$self->{Main}->redirect('tasklist') unless ($user->{type} eq 'teacher' || $row->{uid} == $user->{uid});

	# If there is comment submitted
	if (length($data->{solution_comment})) {
		my $html = markdown($data->{solution_comment});

		my $sth = $dbh->prepare('INSERT INTO comments(sid, teacher, text, html, date) VALUES(?,?,?,?,CURRENT_TIMESTAMP)');
		$sth->execute($data->{sid}, 0, $data->{solution_comment}, $html);

		$self->{Main}->redirect('solution', {sid => $data->{sid}});
	}

	# TODO teacher
}

1;
