package WebTaskSubmitter::View;

use common::sense;
use UCW::CGI;
use POSIX;

use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		Main => shift,
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

sub get_url() {
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
	my $taskdb = $self->{Main}->{tasks};

	return sprintf "<div class='login_line'>$texts->{logged_in_as} <strong>%s</strong> <a href='%s'>[$texts->{logout}]</a></div>\n", $self->{Main}->{user}->{name}, $self->get_url('logout');
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
		$out .= sprintf "<tr><th>$texts->{form_email}:</th><td><input type='text' name='email' value='%s'></td></tr>\n", , html_escape($data->{email});
		$out .= "<tr><th colspan='2'><input type='submit' class='btn btn-primary' value='$texts->{form_submit_registrate}'></th></tr>\n";
		$out .= "</table></form>\n";
	}
	return $out;
}

sub tasklist_page() {
	my $self = shift;
	my $texts = $self->{texts};
	my $taskdb = $self->{Main}->{tasks};

	$self->{title} = $texts->{tasklist_title};

	my $out = $self->print_login_line();
	$out .= "<p>$texts->{tasklist_intro}</p>\n";

	$out .= "<table class='table table-striped table-bordered'><thead>\n<tr>";
		$out .= "<th>$texts->{tasklist_task_name}</th>";
		$out .= "<th>$texts->{tasklist_submit_status}</th>";
		$out .= "<th>$texts->{tasklist_points}</th>";
		$out .= "<th>$texts->{tasklist_deadline}</th>";
		$out .= "<th>$texts->{tasklist_short_desc}</th>";
	$out .= "</tr>\n</thead><tbody>\n";
	foreach my $t (@{$taskdb->{enabled_tasks}}) {
		my $taskcode = $t->{task};
		my $deadline = $t->{deadline};
		my $max_points = $t->{max_points};
		my $task = $taskdb->{tasks}->{$taskcode};

		my $points = 0;
		my $status = 'new';

		$out .= "<tr class='$status'>";
		$out .= sprintf "<th><a href='%s'>$task->{name}</a></th>", $self->get_url('task', {code => $taskcode});
		$out .= "<td>--TODO--</td>";
		$out .= "<td>$points/$max_points</td>";
		$out .= "<td>$deadline</td>";
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
	my $taskdb = $self->{Main}->{tasks};
	my $options = $self->{Main}->{options};

	my $task = $self->{Worker}->get_task($data->{code});

	# my $all_solutions = $self->{Worker}->get_all_solutions();

	my $points = 0;

	#################
	$self->{title} = "$texts->{task_title} $task->{name}";

	my $out = $self->print_login_line();

	$out .= "<strong>$texts->{task_deadline}:</strong> $task->{deadline}<br>\n";
	$out .= "<strong>$texts->{task_points}:</strong> <strong>$points</strong>/$task->{max_points}<br>\n";
	$out .= "<strong>$texts->{task_description}:</strong><br>\n<div class='task_description'>\n";
	$out .= $task->{text};
	$out .= "\n</div>\n\n";

	# TODO: List of submitted solutions

	$out .= "<h3>$texts->{solution_submit_new}</h3>\n";
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
	my $taskdb = $self->{Main}->{tasks};
	my $options = $self->{Main}->{options};
	my $user = $self->{Main}->{user};

	my $solution = $self->{Worker}->get_solution($data->{sid});
	my $task = $self->{Worker}->get_task($solution->{task});

	my $points = 0;

	################
	$self->{title} = "$texts->{solution_title} $task->{name}";

	my $out = $self->print_login_line();

	$out .= "<strong>$texts->{task_deadline}:</strong> $task->{deadline}<br>\n";
	$out .= "<strong>$texts->{task_points}:</strong> <strong>$points</strong>/$task->{max_points}<br>\n";
	$out .= "<strong>$texts->{task_description}:</strong><br>\n<div class='task_description'>\n";
	$out .= $task->{text};
	$out .= "\n</div>\n\n";

	# TODO: List of submitted solutions

	$out .= "<h3>$texts->{solution_submitted_solution}</h3>\n";
	$out .= "<strong>$texts->{solution_submit_date}:</strong> $solution->{date}<br>\n";
	$out .= "<strong>$texts->{solution_points}:</strong> <strong>$solution->{points}</strong>/$task->{max_points}<br>\n";
	$out .= sprintf "<div class='solution_code'><textarea disabled class='form-control' id='solution_code'>%s</textarea></div>\n\n", html_escape($solution->{code});

	foreach my $js ('codemirror/codemirror.js', 'codemirror/matchbrackets.js', 'codemirror/active-line.js', 'codemirror/shell.js', 'epiceditor.min.js') {
		$self->{headers} .= "<script src='$options->{js_path}/$js'></script>\n";
	}
	$self->{headers} .= "<link rel='stylesheet' href='$options->{css_path}/codemirror/codemirror.css'><link rel='stylesheet' href='$options->{css_path}/codemirror/midnight.css'>\n";
	$out .= "<script type='text/javascript'>
	var codeMirror = CodeMirror.fromTextArea(document.getElementById('solution_code'), {
		mode: 'shell',
		lineNumbers: true,
		styleActiveLine: true,
		matchBrackets: true,
		theme: 'midnight',
		readOnly: 'nocursor'
	});
	</script>\n";

	$out .= "<h3>$texts->{solution_comments}</h3>\n";

	my $comments = $self->{Worker}->get_all_comments($data->{sid});
	for my $key (sort keys %$comments) {
		my $comment = $comments->{$key};
		utf8::decode($comment->{html});

		my $author = ($comment->{teacher} ? $options->{teacher_name} : $user->{name});
		my $teacher_class = ($comment->{teacher} ? ' teacher' : '');

		$out .= "<div class='comment$teacher_class'>\n";
		$out .= "<span class='date'>$comment->{date}</span><span class='author'>$texts->{comment_author}: <strong>$author</strong></span>\n";
		$out .= $comment->{html};
		$out .= "</div>\n";
	}

	$out .= "<form method='post'>\n";
	$out .= "<div class='form-group'>\n<label for='solution_comment'>$texts->{form_comment}:</label>\n";
	$out .= "<div id='epiceditor'><textarea class='form-control' name='solution_comment' id='solution_comment'></textarea></div>\n</div>\n";
	$out .= "<button type='submit' class='btn btn-primary'>$texts->{form_submit_add_comment}</button>\n";
	$out .= "</form>\n";
	$out .= $self->get_epiceditor();

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

sub default_texts() {
	return {
		logged_in_as => 'Přihlášen jako',
		logout => 'odhlásit se',

		form_login => 'Login',
		form_password => 'Heslo',
		form_password_check => 'Heslo pro kontrolu',
		form_name => 'Name',
		form_email => 'Email',
		form_solution_code => 'Kód řešení',
		form_comment => 'Komentář',

		form_submit => 'Odeslat',
		form_submit_login => 'Přihlásit',
		form_submit_registrate => 'Registrovat',
		form_submit_add_comment => 'Přidat komentář',

		# Global handling:
		errors_occured => 'Při zpracování formuláře se vyskytly chyby:',
		# Errors:
		error_login_failed => 'Přihlášení selhalo, nesprávné přihlašovací údaje',
		error_login_empty => 'Login nemůže být prázdný',
		error_login_used => 'Tento login je již používaný, zvolte jiný',
		error_passwd_min_length => 'Minimální délka hesla je %d',
		error_passwd_mismatch => 'Hesla se neshodují',
		error_name_empty => 'Jméno nemůže být prázdné',
		error_email_wrong => 'Email není ve správném formátu',

		################################################################
		logout_completed => 'Odhlášení úspěšné',

		login_title => 'Přihlášení',
		login_not_logged_in => 'Nejste přihlášení, zadejte login a heslo k přihlášení. Pokud ještě nemáte účet, můžete se',
		login_registrate => 'registrovat',

		registration_title => 'Vytvoření nového účtu',
		registration_intro => 'Pro vytvoření nového účtu a možnost odevzdávání úkolů vyplňte formulář níže. Pokud již máte účet, můžete se',
		registration_login => 'přihlásit',
		registration_completed => 'Registrace úspěšná, nyní se můžete',

		tasklist_title => 'Seznam úloh',
		tasklist_intro => 'Vyberte si úlohu',
		tasklist_submit_status => 'Stav',
		tasklist_task_name => 'Úloha',
		tasklist_points => 'Body',
		tasklist_short_desc => 'Popis',
		tasklist_deadline => 'Termín',

		task_title => 'Úloha',
		task_deadline => 'Deadline',
		task_points => 'Získané body',
		task_description => 'Zadání',

		solution_title => 'Řešení úlohy',
		solution_submit_new => 'Vložit nové řešení',
		solution_submitted_solution => 'Odeslané řešení',
		solution_submit_date => 'Datum odeslání',
		solution_points => 'Body za řešení',
		solution_code => 'Kód řešení',

		comment_author => 'Autor',
		comment_date => 'Datum',
	}
}

1;
