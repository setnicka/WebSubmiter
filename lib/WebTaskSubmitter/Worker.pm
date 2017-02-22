package WebTaskSubmitter::Worker;

use common::sense;
use Digest::SHA 'sha1_hex';
use Email::Valid;
use Text::Markdown 'markdown';

use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		Main => shift,
		Model => shift,
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

	if (length $data->{login} && length $data->{passwd}) {
		my $user = $self->{Model}->get_user_by_login($data->{login});
		if (defined $user) {
			my $hash = sha1_hex($user->{salt}, $data->{passwd});
			if ($user->{passwd} eq $hash) {
				$self->{Main}->login($data->{login}, $user->{uid}, $user->{name});
			}
		}
		$self->{Main}->{errors}->{login} = $texts->{error_login_failed};
	}
}

sub registration_check() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $texts = $self->{Main}->{View}->{texts};

	my $errors = {};

	my $user = $self->{Model}->get_user_by_login($data->{login});

	$errors->{login} = $texts->{error_login_used} if defined $user;
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

	return unless length($data->{login});
	return unless $self->registration_check();

	$self->{Model}->register_new_user($data);

	$self->{Main}->{status} = 'registration_completed';
}

sub manage_logout() {
	my $self = shift;
	$self->{Main}->{status} = 'logout_completed';
	$self->{Main}->logout();
}

sub manage_task() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $taskdb = $self->{Main}->{tasks};
	my $dbh = $self->{Main}->{dbh};

	my $task = $self->{Model}->get_task($data->{code});
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

sub manage_solution() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $dbh = $self->{Main}->{dbh};
	my $user = $self->{Main}->{user};

	my $row = $self->{Model}->get_solution($data->{sid});
	$self->{Main}->redirect('tasklist') unless ($row);
	# Test if logged in user (or teacher)
	$self->{Main}->redirect('tasklist') unless ($user->{type} eq 'teacher' || $row->{uid} == $user->{uid});

	# If there is comment submitted
	if (length($data->{solution_comment})) {
		my $html = markdown($data->{solution_comment});

		my $sth = $dbh->prepare('INSERT INTO comments(sid, uid, teacher, text, html, date) VALUES(?,?,?,?,?,CURRENT_TIMESTAMP)');
		$sth->execute($data->{sid}, $user->{uid}, ($user->{type} eq 'teacher'), $data->{solution_comment}, $html);

		$self->{Main}->redirect('solution', {sid => $data->{sid}});
	}

	if ($user->{type} eq 'teacher' && length($data->{set_points})) {
		my $sth = $dbh->prepare('UPDATE solutions SET points=?, rated=? WHERE sid=?');
		$sth->execute($data->{set_points}, ($data->{set_status} eq 'rated'), $data->{sid});

		$self->{Main}->redirect('solution', {sid => $data->{sid}});
	}
}

1;
