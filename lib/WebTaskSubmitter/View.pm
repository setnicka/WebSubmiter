package WebTaskSubmitter::View;

use common::sense;
use UCW::CGI;
use POSIX;
use Date::Parse;

use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		Main => shift,
		Model => shift,
		Worker => shift,
		title => undef,
		texts => default_texts(),
	};
	bless $self, $class;
	$self->{headers} = $self->default_headers();
	return $self;
}

sub set_texts($) {
	my ( $self, $texts ) = @_;
	foreach my $key (keys %$texts) {
		die "Unknown text [$key] in WebTaskSubmitter::View::set_texts()" unless exists $self->{texts}->{$key};
		$self->{texts}->{$key} = $texts->{$key};
	}
}

sub get_url($$) {
	my ($self, $page, $parameters) = @_;
	my $url = "$self->{Main}->{options}->{script_url}?page=$page";
	foreach my $param (sort keys %$parameters) {
		$url .= sprintf '&%s=%s', $param, $parameters->{$param};
	}
	return UCW::CGI::html_escape($url);
}

sub print_errors() {
	my $self = shift;
	my $errors = $self->{Main}->{errors};
	my $texts = $self->{texts};

	return "" unless keys %$errors;

	my $out = "<div class='error'><p>$texts->{errors_occured}</p><ul class='errors_list'>\n";
	foreach my $key (sort keys %$errors) {
		$out .= "<li class='error'>$errors->{$key}</li>\n";
	}
	$out .= "</ul></div>\n\n";

	return $out;
}

sub print_login_line() {
	my $self = shift;
	my $texts = $self->{texts};

	my $text = $self->{Main}->{user}->{teacher} ? $texts->{logged_in_teacher} : $texts->{logged_in_as};

	my $special = '';
	if ($self->{Main}->{user}->{teacher}) {
		my $not_sended_notifications = $self->{Model}->get_not_sended_notifications_count();
		$special = "<form method='post'><input type='submit' name='send_notifications' class='btn btn-warning btn-xs' value='$texts->{send_notifications} ($not_sended_notifications)'></form>" if $not_sended_notifications;
	}

	return sprintf "<div class='login_line'>%s $text <strong>%s</strong> <a href='%s'>[$texts->{logout}]</a></div>\n", $special, $self->{Main}->{user}->{name}, $self->get_url('logout');
}

################################################################################

sub login_page() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $texts = $self->{texts};

	$self->{title} = $texts->{login_title};

	my $out = "";

	$out .= "<p>$texts->{logout_completed}</p>\n" if $self->{Main}->{status} eq 'logout_completed';

	$out .= sprintf "<p>$texts->{login_not_logged_in} <a href='%s'>$texts->{login_registrate}</a>.</p>\n", $self->get_url('registration');
	$out .= $self->print_errors();
	$out .= "<form method='post' class='form-horizontal'><table>\n";
	$out .= sprintf "<tr><th>$texts->{form_login}:</th><td><input type='text' name='login' value='%s'></td></tr>\n", html_escape($data->{name});;
	$out .= "<tr><th>$texts->{form_password}:</th><td><input type='password' name='passwd'></td></tr>\n";
	$out .= "<tr><th colspan='2'><input type='submit' class='btn btn-primary' value='$texts->{form_submit_login}'></th></tr>\n";
	$out .= "</table></form>\n";
	return $out;
}

sub registration_page() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $texts = $self->{texts};

	$self->{title} = $texts->{registration_title};
	my $out = "";

	if ($self->{Main}->{status} eq 'registration_completed') {
		$out .= sprintf "<p>$texts->{registration_completed} <a href='%s'>$texts->{registration_login}</a>.</p>", $self->get_url('login');
	} else {
		$out .= sprintf "<p>$texts->{registration_intro} <a href='%s'>$texts->{registration_login}</a>.</p>", $self->get_url('login');
		$out .= $self->print_errors();
		$out .= "<form method='post'><table>\n",
		$out .= sprintf "<tr><th>$texts->{form_login}:</th><td><input type='text' name='login' value='%s'></td></tr>\n", html_escape($data->{login});
		$out .= "<tr><th>$texts->{form_password}:</th><td><input type='password' name='passwd'></td></tr>\n";
		$out .= "<tr><th>$texts->{form_password_check}:</th><td><input type='password' name='passwd_check'></td></tr>\n";
		$out .= sprintf "<tr><th>$texts->{form_name}:</th><td><input type='text' name='name' value='%s'></td></tr>\n", html_escape($data->{name});
		$out .= sprintf "<tr><th>$texts->{form_nick}:</th><td><input type='text' name='nick' value='%s'></td></tr>\n", html_escape($data->{nick});
		$out .= sprintf "<tr><th>$texts->{form_email}:</th><td><input type='text' name='email' value='%s'></td></tr>\n", , html_escape($data->{email});
		$out .= "<tr><th colspan='2'><input type='submit' class='btn btn-primary' value='$texts->{form_submit_registrate}'></th></tr>\n";
		$out .= "</table></form>\n";
	}
	return $out;
}

sub tasklist_page() {
	my $self = shift;
	my $texts = $self->{texts};
	my $user = $self->{Main}->{user};

	$self->{title} = $texts->{tasklist_title};

	my $out = $self->print_login_line();
	$out .= sprintf("<a href='%s'>&rarr; $texts->{usertable_title}</a>", $self->get_url('usertable')) if $user->{teacher} || $self->{Main}->{options}->{usertable_for_students};

	$out .= "<p>$texts->{tasklist_intro}</p>\n";

	$out .= "<table class='tasklist table table-striped table-bordered'><thead>\n<tr>";
		$out .= "<th>$texts->{tasklist_task_name}</th>";
		if ($user->{teacher}) {
			$out .= "<th>$texts->{tasklist_solutions_unrated}</th>";
			$out .= "<th>$texts->{tasklist_solutions}</th>";
		} else {
			$out .= "<th>$texts->{tasklist_submit_status}</th>";
			$out .= "<th>$texts->{tasklist_points}</th>";
		}
		$out .= "<th>$texts->{tasklist_deadline}</th>";
		$out .= "<th>$texts->{tasklist_short_desc}</th>";
	$out .= "</tr>\n</thead><tbody>\n";

	my @tasks = $self->{Model}->get_enabled_tasks($user->{teacher} ? undef : $user->{uid});

	foreach my $task (@tasks) {
		my $deadline = str2time($task->{deadline});

		my @classes = ();
		my $status;
		push @classes, 'missed' if $deadline < time();
		if ($user->{type} ne 'teacher') {
			if ($task->{count_solutions} > 0) {
				push @classes, 'full_points' if $task->{max_points} <= $task->{points};
				push @classes, 'part_points' if $task->{max_points} > $task->{points} && $task->{points} > 0;
				push @classes, 'waiting' if $task->{points} == 0;

				$status = $task->{count_solutions} == $task->{count_solutions_rated} ? $texts->{status_rated} : $texts->{status_submitted};
			} else {
				push @classes, 'not_submitted';
				$status = $texts->{status_not_submitted};
			}
		} else {
			push @classes, 'waiting' if $task->{count_solutions} > $task->{count_solutions_rated};
		}
		my $classes = join(' ', @classes);

		my $points = '-';
		$points = $task->{points} if $task->{rated};

		$out .= "<tr class='$classes'>";
		$out .= sprintf "<th><a href='%s'>$task->{name}</a></th>", $self->get_url('task', {code => $task->{code}});
		if ($user->{teacher}) {
			$out .= sprintf "<th><a href='%s'>%s</a></th>", $self->get_url('task', {code => $task->{code}}), $task->{count_solutions} - $task->{count_solutions_rated};
			$out .= "<th>$task->{count_solutions}</th>";
		} else {
			$out .= "<th>$status</th>";
			$out .= "<th>$points / $task->{max_points}</th>";
		}
		$out .= "<td>$task->{deadline}</td>";
		$out .= "<td>$task->{short_desc}</td>";
		$out .= "</tr>\n";
	}
	$out .= "</tbody></table>\n";

	return $out;
}

sub task_page() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $texts = $self->{texts};
	my $options = $self->{Main}->{options};
	my $user = $self->{Main}->{user};

	my $task = $self->{Model}->get_task($data->{code});
	my $counts = $self->{Model}->get_solution_counts($user->{teacher} ? undef : $user->{uid}, $data->{code})->{$data->{code}};

	my $all_solutions = $self->{Model}->get_all_solutions($user->{teacher} ? undef : $user->{uid}, $data->{code});

	#################
	$self->{title} = "$texts->{task_title} $task->{name}";

	my $out = $self->print_login_line();
	$out .= sprintf "<a href='%s'>$texts->{task_back_to_tasklist}</a><br>\n", $self->get_url('tasklist');

	$out .= "<strong>$texts->{task_deadline}:</strong> $task->{deadline}<br>\n";
	$out .= "<strong>$texts->{task_points}:</strong> <strong>$counts->{max_points}</strong> / $task->{max_points}<br>\n" unless $user->{teacher};
	$out .= "<strong>$texts->{task_description}:</strong><br>\n<div class='task_description'>\n";
	$out .= $task->{text};
	$out .= "\n</div>\n\n";

	# TODO: List of submitted solutions

	$out .= "<hr><h3>$texts->{solutions_list}</h3>\n";

	if (%$all_solutions) {
		$out .= "<table class='solutions table table-stripped table-bordered'>";
		for my $uid (sort { $a <=> $b } keys %$all_solutions) {
			my $user_solutions = $all_solutions->{$uid};
			$out .= "<thead id='user$uid'>\n<tr>";
				$out .= "<th>$texts->{solutions_user}</th>" if $user->{teacher};
				$out .= "<th>$texts->{solutions_date}</th>";
				$out .= "<th>$texts->{solutions_status}</th>";
				$out .= "<th>$texts->{solutions_points}</th>";
				$out .= "<th>$texts->{solutions_detail}</th>";
			$out .= "</tr>\n</thead><tbody>\n";

			for my $key (sort { $a <=> $b } keys %$user_solutions) {
				my $solution = $user_solutions->{$key};
				utf8::decode($solution->{name});

				my $class = $solution->{points} == $counts->{max_points} ? 'full_points' : 'part_points';
				$class = 'waiting' unless $solution->{rated};

				my $status = $solution->{rated} ? $texts->{status_rated} : $texts->{status_submitted};

				$out .= "<tr class='$class'>";
				$out .= sprintf "<td>%s</td>", html_escape($solution->{name}) if $user->{teacher};
				$out .= "<td>$solution->{local_date}</td><td>$status</td><td>$solution->{points} / $task->{max_points}</td>";
				$out .= sprintf "<td><a href='%s'>$texts->{solutions_detail}</a></td></tr>\n", $self->get_url('solution', {sid => $solution->{sid}});
			}

			$out .= "</tbody>\n";
		}
		$out .= "</table>\n";
	} else {
		$out .= "<i>$texts->{solutions_no_solutions}</i><br>\n";
	}

	return $out if $user->{teacher};  # Teachers cannot add new solutions
	unless ($data->{action} eq 'new') {
		$out .= sprintf "<a href='%s'>$texts->{solution_submit_new}</a>\n", $self->get_url('task', {code => $data->{code}, action => 'new'});
		return $out;
	}

	$out .= "<hr><h3>$texts->{solution_submit_new}</h3>\n";
	$out .= "<form method='post'>\n";
	$out .= "<div class='form-group'>\n<label for='solution_code'>$texts->{form_solution_code}:</label>\n";
	$out .= "<textarea class='form-control' name='solution_code' id='solution_code'></textarea>\n</div>\n";
	$out .= "<div class='form-group'>\n<label for='solution_comment'>$texts->{form_comment}:</label>\n";
	$out .= "<div id='epiceditor'><textarea class='form-control' name='solution_comment' id='solution_comment'></textarea></div>\n</div>\n";
	$out .= "<button type='submit' class='btn btn-primary'>$texts->{form_submit}</button>\n";
	$out .= "</form>\n";

	foreach my $js ('codemirror/codemirror.js', 'codemirror/matchbrackets.js', 'codemirror/active-line.js', 'codemirror/shell.js', 'epiceditor.min.js') {
		$self->{headers} .= "<script src='$options->{js_path}/$js'></script>\n";
	}
	foreach my $css ('codemirror/codemirror.css', 'codemirror/midnight.css') {
		$self->{headers} .= "<link rel='stylesheet' href='$options->{css_path}/$css'>\n";
	}
	$out .= "<script type='text/javascript'>
	var codeMirror = CodeMirror.fromTextArea(document.getElementById('solution_code'), {
		mode: 'shell',
		lineNumbers: true,
		styleActiveLine: true,
		matchBrackets: true,
		theme: 'midnight'
	});
	</script>\n";
	$out .= $self->get_epiceditor();

	return $out;
}

sub solution_page() {
	my $self = shift;
	my $data = $self->{Main}->{data};
	my $texts = $self->{texts};
	my $options = $self->{Main}->{options};
	my $user = $self->{Main}->{user};

	my $solution = $self->{Model}->get_solution($data->{sid});
	my $task = $self->{Model}->get_task($solution->{task});
	my $counts = $self->{Model}->get_solution_counts($user->{teacher} ? undef : $user->{uid}, $solution->{task})->{$solution->{task}};
	utf8::decode($solution->{code});
	utf8::decode($solution->{name});

	################
	$self->{title} = "$texts->{solution_title} $task->{name}";

	my $out = $self->print_login_line();
	$out .= sprintf "<a href='%s'>$texts->{task_back_to_tasklist}</a> | <a href='%s'>$texts->{solution_back_to_task}</a><br>\n", $self->get_url('tasklist'), $self->get_url('task', {code => $solution->{task}});

	$out .= "<strong>$texts->{task_deadline}:</strong> $task->{deadline}<br>\n";
	$out .= "<strong>$texts->{task_points}:</strong> <strong>$counts->{max_points}</strong> / $task->{max_points}<br>\n" unless $user->{teacher};
	$out .= "<strong>$texts->{task_description}:</strong><br>\n<div class='task_description'>\n";
	$out .= $task->{text};
	$out .= "\n</div>\n\n";

	my $status = $solution->{rated} ? $texts->{status_rated} : $texts->{status_submitted};

	$out .= "<hr><h3>$texts->{solution_submitted_solution}</h3>\n";
	$out .= sprintf "<strong>$texts->{solution_author}:</strong> %s &lt;<a href='mailto:%s'>%s</a>&gt;<br>\n",
		html_escape($solution->{name}), html_escape($solution->{email}), html_escape($solution->{email}) if $user->{teacher};
	$out .= "<strong>$texts->{solution_submit_date}:</strong> $solution->{local_date}<br>\n";
	$out .= "<strong>$texts->{solution_status}:</strong> $status<br>\n";
	$out .= "<strong>$texts->{solution_points}:</strong> <strong>$solution->{points}</strong> / $task->{max_points}<br>\n";
	$out .= sprintf "<div class='solution_code'><textarea disabled class='form-control' id='solution_code'>%s</textarea></div>\n\n", html_escape($solution->{code});

	foreach my $js ('codemirror/codemirror.js', 'codemirror/matchbrackets.js', 'codemirror/shell.js', 'epiceditor.min.js') {
		$self->{headers} .= "<script src='$options->{js_path}/$js'></script>\n";
	}
	$self->{headers} .= "<link rel='stylesheet' href='$options->{css_path}/codemirror/codemirror.css'><link rel='stylesheet' href='$options->{css_path}/codemirror/midnight.css'>\n";
	$out .= "<script type='text/javascript'>
	var codeMirror = CodeMirror.fromTextArea(document.getElementById('solution_code'), {
		mode: 'shell',
		lineNumbers: true,
		matchBrackets: true,
		theme: 'midnight',
		readOnly: 'nocursor'
	});
	</script>\n";

	$out .= "<h3>$texts->{solution_comments}</h3>\n";

	my $comments = $self->{Model}->get_all_comments($data->{sid});
	for my $key (sort { $a <=> $b } keys %$comments) {
		my $comment = $comments->{$key};
		utf8::decode($comment->{html});
		utf8::decode($comment->{name});

		my $teacher_class = ($comment->{teacher} ? ' teacher' : '');
		my $author = html_escape($comment->{name});
		$author .= " ($texts->{comment_teacher})" if $comment->{teacher};

		$out .= "<div class='comment$teacher_class'>\n";
		$out .= "<span class='date'>$comment->{local_date}</span><span class='author'>$texts->{comment_author}: <strong>$author</strong></span>\n";
		$out .= $comment->{html};
		$out .= "</div>\n";
	}

	$out .= "<form method='post'>\n";
	$out .= "<div class='form-group'>\n<label for='solution_comment'>$texts->{form_comment}:</label>\n";
	$out .= "<div id='epiceditor'><textarea class='form-control' name='solution_comment' id='solution_comment'></textarea></div>\n</div>\n";
	$out .= "<button type='submit' class='btn btn-primary'>$texts->{form_submit_add_comment}</button>\n";
	$out .= "</form>\n";
	$out .= $self->get_epiceditor();

	return $out unless $user->{teacher};

	$out .= "<hr><form class='form-inline' method='post'>\n";
	$out .= "<div class='form-group'>\n<label for='set_points'>$texts->{form_set_points}:</label>\n";
	$out .= "<input type='text' size='4' value='$solution->{points}' id='set_points' name='set_points'>\n</div>\n";
	$out .= "<strong>$texts->{form_set_status}:</strong> ";
	$out .= sprintf "<label class='radio-inline'><input type='radio' name='set_status' value='open' %s>$texts->{form_status_open}</label>\n", $solution->{rated} ? '': 'checked';
	$out .= sprintf "<label class='radio-inline'><input type='radio' name='set_status' value='rated' %s>$texts->{form_status_rated}</label>\n", $solution->{rated} ? 'checked' : '';
	$out .= "<button type='submit' class='btn btn-primary'>$texts->{form_submit_set}</button>\n";
	$out .= "</form>\n";

	return $out;
}

################################################################################
sub default_headers() {
	my $self = shift;
	my $options = $self->{Main}->{options};
	my $out = "";
	$out .= "<link href='$options->{css_path}/bootstrap.css' rel='stylesheet' type='text/css'>\n";
	$out .= "<link href='$options->{css_path}/webtasksubmitter.css' rel='stylesheet' type='text/css'>\n";

	return $out;
}

sub get_epiceditor() {
	my $self = shift;
	my $options = $self->{Main}->{options};
	return "<script type='text/javascript'>
	var editor = new EpicEditor({
		container: 'epiceditor',
		textarea: 'solution_comment',
		clientSideStorage: false,
		autogrow: true,
		autogrow: {
			minHeight: 150,
			maxHeight: 400
		},
		basePath: '$options->{css_path}/',
		theme: {
			base: 'epiceditor/epiceditor.css',
			editor: 'epiceditor/epic-dark.css',
			preview: 'bootstrap.css'
		},
		button: {
			bar: 'show'
		}
	}).load();
	document.getElementById('solution_comment').style.display='none';\n</script>\n"
}

sub usertable_page() {
	my $self = shift;
	my $texts = $self->{texts};
	my $user = $self->{Main}->{user};

	$self->{title} = $texts->{usertable_title};

	my @tasks = $self->{Model}->get_enabled_tasks();
	my @students = $self->{Model}->get_students();
	my $all_solutions = $self->{Model}->get_all_solutions_grouped();

	my $out = $self->print_login_line();
	$out .= sprintf "<a href='%s'>&rarr; $texts->{tasklist_title}</a>", $self->get_url('tasklist');

	$out .= "<table class='usertable table table-bordered'><thead>\n<tr><th>$texts->{usertable_student}</th>";
	for my $task (@tasks) {
		$out .= sprintf "<th class='vertical'><a href='%s'>$task->{name}</a></th>", $self->get_url('task', {code => $task->{code}});
	}
	$out .= "<th>$texts->{usertable_sum}</th></tr>\n</thead><tbody>\n";
	for my $student (@students) {
		utf8::decode($student->{name});
		utf8::decode($student->{nick});

		my $grouped_solutions = $all_solutions->{$student->{uid}};
		my $sum = 0;

		$out .= sprintf("<tr><th>%s (%s)</th>", html_escape($student->{name}), html_escape($student->{nick})) if $user->{teacher};
		$out .= sprintf("<tr><th>%s</th>", html_escape($student->{nick})) unless $user->{teacher};

		for my $task (@tasks) {
			my $max_points = $grouped_solutions->{$task->{code}}->{max_points};
			$sum += $max_points;
			$max_points = '-' unless length($max_points);
			$out .= "<td>$max_points</td>" unless $user->{teacher};
			$out .= sprintf("<td><a href='%s#user$student->{uid}'>$max_points</a></td>", $self->get_url('task', {code => $task->{code}})) if $user->{teacher};
		}
		$out .= "<th>$sum</th></tr>\n";
	}
	$out .= "</tbody>\n</table>\n";

	return $out;
}


sub default_texts() {
	return {
		logged_in_as => 'Přihlášen jako',
		logged_in_teacher => 'Přihlášen učitel',
		logout => 'odhlásit se',

		status_not_submitted => 'Neodevzdáno',
		status_submitted => 'Odevzdáno',
		status_rated => 'Ohodnoceno',

		form_login => 'Login',
		form_password => 'Heslo',
		form_password_check => 'Heslo pro kontrolu',
		form_name => 'Jméno a příjmení',
		form_nick => 'Přezdívka',
		form_email => 'Email',
		form_solution_code => 'Kód řešení',
		form_comment => 'Komentář',
		form_set_points => 'Body',
		form_set_status => 'Stav',
		form_status_open => 'Neohodnoceno',
		form_status_rated => 'Ohodnoceno',

		form_submit => 'Odeslat',
		form_submit_login => 'Přihlásit',
		form_submit_registrate => 'Registrovat',
		form_submit_add_comment => 'Přidat komentář',
		form_submit_set => 'Nastav',

		send_notifications => 'Odeslat dávkově upozornění studentům',

		# Global handling:
		errors_occured => 'Při zpracování formuláře se vyskytly chyby:',
		# Errors:
		error_login_failed => 'Přihlášení selhalo, nesprávné přihlašovací údaje',
		error_login_empty => 'Login nemůže být prázdný',
		error_login_used => 'Tento login je již používaný, zvolte jiný',
		error_passwd_min_length => 'Minimální délka hesla je %d',
		error_passwd_mismatch => 'Hesla se neshodují',
		error_name_empty => 'Jméno nemůže být prázdné',
		error_nick_empty => 'Přezdívka nemůže být prázdná',
		error_email_wrong => 'Email není ve správném formátu',

		################################################################
		logout_completed => 'Odhlášení úspěšné',

		login_title => 'Přihlášení',
		login_not_logged_in => 'Nejste přihlášení, zadejte login a heslo k přihlášení. Pokud ještě nemáte účet, můžete se',
		login_registrate => 'registrovat',

		registration_title => 'Vytvoření nového účtu',
		registration_intro => 'Pro vytvoření nového účtu a možnost odevzdávání úkolů vyplňte formulář níže. Přezdívka se použije při zobrazení vašeho jména
		ostatním studentům (učitel vidí celé jméno). Pokud již máte účet, můžete se',
		registration_login => 'přihlásit',
		registration_completed => 'Registrace úspěšná, nyní se můžete',

		tasklist_title => 'Seznam úloh',
		tasklist_intro => 'Vyberte si úlohu',
		tasklist_submit_status => 'Stav',
		tasklist_task_name => 'Úloha',
		tasklist_points => 'Body',
		tasklist_short_desc => 'Popis',
		tasklist_deadline => 'Termín',
		tasklist_solutions => 'Celkem řešení',
		tasklist_solutions_unrated => 'Neohodnocených řešení',

		task_title => 'Úloha',
		task_deadline => 'Deadline',
		task_points => 'Získané body',
		task_description => 'Zadání',
		task_back_to_tasklist => 'Zpět na seznam úloh',

		solutions_list => 'Seznam odevdaných řešení',
		solutions_no_solutions => 'Zatím žádná odevzdaná řešení',
		solutions_date => 'Datum odevzdání',
		solutions_status => 'Stav řešení',
		solutions_points => 'Udělené body',
		solutions_detail => 'Detail',

		solution_title => 'Řešení úlohy',
		solution_author => 'Autor řešení',
		solution_submit_new => 'Vložit nové řešení',
		solution_submitted_solution => 'Odeslané řešení',
		solution_submit_date => 'Datum odeslání',
		solution_points => 'Body za řešení',
		solution_status => 'Stav řešení',
		solution_code => 'Kód řešení',
		solution_back_to_task => 'Zpět na zadání úlohy',

		comment_author => 'Autor',
		comment_date => 'Datum',
		comment_teacher => 'učitel',

		usertable_title => 'Tabulka bodů',
		usertable_student => 'Student',
		usertable_sum => 'Součet',
	}
}

1;
