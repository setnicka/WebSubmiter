package WebTaskSubmitter::Worker;

use common::sense;
use Digest::SHA qw/sha1_hex/;
use Email::Valid;

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

	my $task = $self->get_task($data->{code});
	# Check if task exists...
	$self->{Main}->redirect('tasklist') unless $task;
	# ... and is enabled
	$self->{Main}->redirect('tasklist') unless $task->{enabled};
}

1;
