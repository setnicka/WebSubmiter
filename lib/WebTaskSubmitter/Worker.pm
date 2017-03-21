package WebTaskSubmitter::Worker;

use common::sense;
use Digest::SHA 'sha1_hex';
use Email::Valid;

use Data::Dumper;

use WebTaskSubmitter::Email;

sub new {
	my $class = shift;
	my $self = {
		Main => shift,
		Model => shift,
		Email => shift,
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
	$errors->{nick} = $texts->{error_nick_empty} unless length($data->{nick});
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
	my $user = $self->{Main}->{user};

	my $task = $self->{Model}->get_task($data->{code});
	# Check if task exists...
	$self->{Main}->redirect('tasklist') unless $task;
	# ... and is enabled
	$self->{Main}->redirect('tasklist') unless $task->{enabled};

	# If there is solution submitted
	if (length($data->{solution_code})) {
		my $sid = $self->{Model}->add_solution($data->{code}, $user->{uid}, $data->{solution_code});
		$self->{Model}->add_comment($sid, $user, $data->{solution_comment}) if length($data->{solution_comment});
		$self->{Main}->redirect('solution', {sid => $sid});
	}
}

sub manage_solution() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $user = $self->{Main}->{user};

	my $row = $self->{Model}->get_solution($data->{sid});
	$self->{Main}->redirect('tasklist') unless ($row);
	# Test if logged in user (or teacher)
	$self->{Main}->redirect('tasklist') unless ($user->{teacher} || $row->{uid} == $user->{uid});

	# If there is comment submitted
	if (length($data->{solution_comment})) {
		my $cid = $self->{Model}->add_comment($data->{sid}, $user, $data->{solution_comment});

		$self->{Email}->notify_comment($row->{uid}, $data->{sid}, $row->{task}, $cid, $data->{solution_comment}) if $user->{teacher};
		$self->{Main}->redirect('solution', {sid => $data->{sid}});
	}

	if ($user->{teacher} && length($data->{set_points})) {
		my $rated = ($data->{set_status} eq 'rated');

		return if $row->{points} == $data->{set_points} && $row->{rated} == $rated;

		$self->{Model}->solution_set_points($data->{sid}, $data->{set_points}, $rated);

		$self->{Email}->notify_points_changed($row->{uid}, $data->{sid}, $row->{task}, $row, {points => $data->{set_points}, rated => $rated});
		$self->{Main}->redirect('solution', {sid => $data->{sid}});
	}
}

sub manage_usertable() {
	my $self = shift;
	my $user = $self->{Main}->{user};

	$self->{Main}->redirect('tasklist') unless $user->{teacher} || $self->{Main}->{options}->{usertable_for_students};
}

sub manage_bonustable() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $user = $self->{Main}->{user};

	$self->{Main}->redirect('tasklist') unless $user->{teacher};
	return unless $data->{bonus_submit};
	# Only teacher can modify points

	my @students = $self->{Model}->get_students();
	my @bonuses = $self->{Model}->get_bonuses();

	# 1. Get submitted form with points
	my $bonuspoints = {};
	my $bonuspoints_param_table = {};
	for my $student (@students) {
		for my $bonus (@bonuses) {
			$bonuspoints_param_table->{"bonus$student->{uid}$bonus->{bonus}"} = { var => \$bonuspoints->{"$student->{uid}$bonus->{bonus}"}, check => '\d+' };
		}
	}
	UCW::CGI::parse_args($bonuspoints_param_table);

	# 2. Get current points from the DB
	my $saved_points = $self->{Model}->get_bonus_points();

	# 3. Check what to add/delete/update
	# Delete not existing inputs or zeroes
	for my $uid (keys %{$saved_points}) {
		for my $bonus (keys %{$saved_points->{$uid}}) {
			next if defined $bonuspoints->{"${uid}${bonus}"} && $bonuspoints->{"${uid}${bonus}"} != 0;
			$self->{Model}->remove_bonus_points($uid, $bonus);
		}
	}

	# Add/update if changed
	for my $student (@students) {
		for my $bonus (@bonuses) {
			my $uid = $student->{uid};
			my $bonus = $bonus->{bonus};
			my $points = $bonuspoints->{"${uid}${bonus}"};
			next if $points == 0 || (defined $saved_points->{$uid}->{$bonus} && $saved_points->{$uid}->{$bonus} == $points);
			$self->{Model}->add_bonus_points($uid, $bonus, $points);
		}
	}

	$self->{Main}->redirect('bonustable');
}

1;
