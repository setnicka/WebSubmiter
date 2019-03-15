package WebTaskSubmitter::Email;

use common::sense;
#use Mail::Sendmail;
use Email::MIME;
use Email::Sender::Simple qw(sendmail);
use Encode;
use Time::Piece;

sub new {
	my $class = shift;
	my $self = {
		Main => shift,
		Model => shift,
		texts => default_texts(),
	};
	bless $self, $class;
	return $self;
}

use utf8;

sub send_email {
	my ($from, $to, $subject, $body) = @_;

	#my $efrom = Encode::encode('MIME-Header', $from);
	#my $eto = Encode::encode('MIME-Header', $to);
	#my $esubject = Encode::encode('MIME-Header', $subject);

	my $message = Email::MIME->create(
		header_str => [
			From    => $from,
			To      => $to,
			Subject => $subject,
		],
		attributes => {
			encoding => 'quoted-printable',
			charset  => 'UTF-8',
		},
		body_str => $body,
	);
	sendmail($message);
}

sub get_url($$) {
	my ($self, $page, $parameters) = @_;
	my $url = 'http';
	if ($ENV{HTTPS} = "on") {
		$url .= "s";
	}
	my $uri = $ENV{REQUEST_URI};
	$uri =~ s/\?.*//;
	$url .= "://$ENV{SERVER_NAME}$uri?page=$page";
	foreach my $param (sort keys %$parameters) {
		$url .= sprintf '&%s=%s', $param, UCW::CGI::url_escape($parameters->{$param});
	}
	return $url;
}

sub notify_comment() {
	my ($self, $uid, $sid, $task_code, $cid, $text) = @_;
	my $options = $self->{Main}->{options};
	my $texts = $self->{texts};
	my $task = $self->{Model}->get_task_simple($task_code);
	utf8::decode($task->{name});

	my $sended = 0;
	# Send email if immediate emails:
	if ($options->{emails_enabled} && $options->{emails_immediate}) {
		my $subject = sprintf "$texts->{subject_prefix}$texts->{subject_comment_added} %s", $task->{name};
		my $content = sprintf "%s:\n%s\n", $texts->{email_comment_added}, $text;
		my $body = sprintf($texts->{email_template},
			$task->{name}, $self->get_url('solution', {sid => $sid}),
			$content
		);

		$body .= $texts->{email_footer};
		my $user = $self->{Model}->get_user($uid);
		utf8::decode($user->{name});
		send_email($options->{emails_from}, sprintf("%s <%s>", $user->{name}, $user->{email}), $subject, $body);
		$sended = 1;
	}

	# Save into DB:
	$self->{Model}->add_notification('comment', $uid, $sid, $cid, '', $sended);
}

sub notify_points_changed() {
	my ($self, $uid, $sid, $task_code, $old, $new) = @_;
	my $options = $self->{Main}->{options};
	my $texts = $self->{texts};
	my $task = $self->{Model}->get_task_simple($task_code);
	utf8::decode($task->{name});

	return if $old->{points} == $new->{points} && $old->{rated} == $new->{rated};

	my $status_text = '';
	$status_text .= sprintf " * %s: %d -> %d\n", $texts->{points_changed}, $old->{points}, $new->{points} if $old->{points} != $new->{points};
	$status_text .= sprintf " * %s: %s -> %s\n", $texts->{status_changed},
		($old->{rated} ? $texts->{status_rated} : $texts->{status_not_rated}),
		($new->{rated} ? $texts->{status_rated} : $texts->{status_not_rated})
		if $old->{rated} != $new->{rated};

	my $sended = 0;
	# Send email if immediate emails:
	if ($options->{emails_enabled} && $options->{emails_immediate}) {
		my $subject = sprintf "$texts->{subject_prefix}$texts->{subject_points_changed} %s", $task->{name};
		my $content = sprintf "%s:\n%s\n", $texts->{email_points_changed}, $status_text;
		my $body = sprintf($texts->{email_template},
			$task->{name}, $self->get_url('solution', {sid => $sid}),
			$content
		);

		$body .= $texts->{email_footer};
		my $user = $self->{Model}->get_user($uid);
		utf8::decode($user->{name});
		send_email($options->{emails_from}, sprintf("%s <%s>", $user->{name}, $user->{email}), $subject, $body);

		$sended = 1;
	}

	# Save into DB:
	$self->{Model}->add_notification('points_changed', $uid, $sid, 0, $status_text, $sended);
}

################################################################################

sub send_prepared_notifications() {
	my $self = shift;
	my $options = $self->{Main}->{options};
	my $texts = $self->{texts};

	return unless $options->{emails_enabled};

	my $notifications = $self->{Model}->get_not_sended_notifications();
	my $max_nid = 0;

	for my $uid (sort keys %{$notifications}) {
		my $user = $self->{Model}->get_user($uid);

		my $body = '';
		my $type_comment = 0;
		my $type_points = 0;
		my $count_solutions = 0;

		my $task;
		for my $sid (sort keys %{$notifications->{$uid}}) {
			my $solution = $self->{Model}->get_solution($sid);
			$task = $self->{Model}->get_task_simple($solution->{task});
			utf8::decode($task->{name});
			$count_solutions++;

			my $content = '';

			for my $nid (sort keys %{$notifications->{$uid}->{$sid}}) {
				my $notification = $notifications->{$uid}->{$sid}->{$nid};

				if ($notification->{type} eq 'comment') {
					my $comment = $self->{Model}->get_comment($notification->{cid});
					utf8::decode($comment->{text});
					$content .= sprintf "%s (%s):\n%s\n\n", $texts->{subject_comment_added}, $comment->{local_date}, $comment->{text};
					$type_comment++;
				} elsif ($notification->{type} eq 'points_changed') {
					utf8::decode($notification->{text});
					$content .= sprintf "%s:\n%s\n", $texts->{email_points_changed}, $notification->{text};
					$type_points++;
				}
				$max_nid = $nid if $nid > $max_nid;
			}

			$body .= sprintf($texts->{email_template},
				$task->{name}, $self->get_url('solution', {sid => $sid}),
				$content
			);
		}

		my $subject;
		$subject = sprintf "$texts->{subject_prefix}$texts->{subject_comment_added} %s", $task->{name} if $type_comment;
		$subject = sprintf "$texts->{subject_prefix}$texts->{subject_points_changed} %s", $task->{name} if $type_points;
		$subject = sprintf "$texts->{subject_prefix}$texts->{subject_comment_and_points} %s", $task->{name} if $type_comment && $type_points;
		$subject = "$texts->{subject_prefix}$texts->{subject_multiple_solutions}" if $count_solutions > 1;

		$body .= $texts->{email_footer};
		utf8::decode($user->{name});
		send_email($options->{emails_from}, sprintf("%s <%s>", $user->{name}, $user->{email}), $subject, $body);
	}

	$self->{Model}->set_notifications_sended($max_nid);
}

sub send_renew_password_email() {
	my ($self, $user, $token, $timestamp) = @_;
	my $options = $self->{Main}->{options};
	my $texts = $self->{texts};

	utf8::decode($user->{name});

	my $subject = "$texts->{subject_prefix}$texts->{subject_renew_password}";
	my $body = sprintf($texts->{renew_password_template},
		$user->{login}, $user->{name},
		$self->get_url('renew_password', {uid => $user->{uid}, token => $token, timestamp => $timestamp}),
		localtime($timestamp)->strftime('%F %T')
	);
	$body .= $texts->{email_footer};

	send_email($options->{emails_from}, sprintf("%s <%s>", $user->{name}, $user->{email}), $subject, $body);
}

################################################################################

sub default_texts() {
	return {
		subject_prefix => '[UNIX submitter] ',
		subject_comment_added => 'Přidán nový komentář k řešení úlohy',
		subject_points_changed => 'Změna v bodování řešení úlohy',
		subject_comment_and_points => 'Přidán komentář a změna bodování u řešení úlohy',
		subject_multiple_solutions => 'Změny u více řešení',
		subject_renew_password => 'Obnovení zapomenutého hesla',

		points_changed => 'Změna bodů',
		status_changed => 'Změna stavu',
		status_rated => 'ohodnoceno',
		status_not_rated => 'neohodnoceno',

		renew_password_template => <<EOF,
Byl přijat požadavek na změnu hesla v odevzdávacím systému úkolů
z UNIXu pro účet %s (%s).

Pokud chcete heslo změnit, přistupte na následující odkaz:

%s

Pokud heslo změnit nechcete, tak email ignorujte, platnost tokenu vyprší
%s.

EOF

		email_template => <<EOF,
Změny u řešení úlohy %s:
(%s)

%s----------

EOF
		email_footer => "Váš systém na odevzdávání úkolů z UNIXu\nWebTaskSubmitter :-]",
		email_comment_added => 'Přidán komentář',
		email_points_changed => 'Změna bodování',
	}
}


1;
