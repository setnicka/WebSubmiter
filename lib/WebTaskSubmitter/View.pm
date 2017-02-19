package WebTaskSubmitter::View;

use common::sense;
use UCW::CGI;

use Data::Dumper;

sub new {
	my $class = shift;
	my $self = {
		Main => shift,
		title => undef,
		texts => default_texts(),
		headers => default_headers(),
	};
	bless $self, $class;
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

	my $task = $self->{Main}->{Worker}->get_task($data->{code});

	my $points = 0;

	#################
	$self->{title} = "$texts->{task_title} $task->{name}";

	my $out = $self->print_login_line();

	$out .= "<strong>$texts->{task_deadline}:</strong> $task->{deadline}<br>\n";
	$out .= "<strong>$texts->{task_points}:</strong> <strong>$points</strong>/$task->{max_points}<br>\n";
	$out .= "<strong>$texts->{task_description}:</strong><br>\n<div class='task_description'>\n";
	$out .= $task->{text};
	$out .= "\n</div>\n\n";

	return $out;
}

################################################################################
sub default_headers() {
	my $self = shift;
	my $out = "";
	$out .= "<link href='css/bootstrap.css' rel='stylesheet' type='text/css'>\n";
	$out .= "<link href='css/webtasksubmitter.css' rel='stylesheet' type='text/css'>\n";

	return $out;
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
		form_submit => 'Odeslat',
		form_submit_login => 'Přihlásit',
		form_submit_registrate => 'Registrovat',

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
	}
}

1;
