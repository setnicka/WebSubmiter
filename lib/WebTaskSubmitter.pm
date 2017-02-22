package WebTaskSubmitter;

use common::sense;

use UCW::CGI;
$UCW::CGI::utf8_mode = 1;

use DBI;
use Digest::SHA qw/sha1_hex/;

use WebTaskSubmitter::Model;
use WebTaskSubmitter::Worker;
use WebTaskSubmitter::View;

use File::Slurp;
use Data::Dumper;

use constant {
	LOGIN_COOKIE_NAME => 'webtasklogin',
	LOGIN_COOKIE_MAX_AGE=> 3600*24*30,  # 30 days
	DEFAULT_PAGE => 'tasklist',
};

sub new {
	my $class = shift;
	my $self = {
		options => shift,
		processed => 0,
		status => '',
		errors => {}
	};
	bless $self, $class;
	return $self;
}

sub redirect() {
	my ($self, $page, $parameters) = @_;
	my $location = "$self->{options}->{script_url}";
	$location .= "?page=$page"; #unless $page eq DEFAULT_PAGE;
	foreach my $param (sort keys %$parameters) {
		$location .= sprintf '&%s=%s', $param, $parameters->{$param};
	}
	print "Location: $location\n\n";
	exit 0;
}

# Method to create login cookie and send it to the client
sub login() {
	my ($self, $login, $uid, $name) = @_;
	my $login_time = time();

	my $type = 'user';
	$type = 'teacher' if $login ~~ @{$self->{options}->{teacher_accounts}};

	my $cookie_value = sprintf '%s:%d:%d:%s:%s', $type, $uid, $login_time, sha1_hex($self->{options}->{auth_cookie_secret}, $type, $uid, $login_time, $name), $name;
	UCW::CGI::set_cookie(LOGIN_COOKIE_NAME, $cookie_value, ('max-age' => LOGIN_COOKIE_MAX_AGE));
	$self->redirect(DEFAULT_PAGE);
}

sub logout() {
	my $self = shift;
	UCW::CGI::set_cookie(LOGIN_COOKIE_NAME, '', ('discard' => 1));
	$self->redirect('login');
}

sub check_login() {
	my $self = shift;

	my %cookies = UCW::CGI::parse_cookies();
	if (defined $cookies{(LOGIN_COOKIE_NAME)}) {
		my ($type, $uid, $login_time, $hash, $name) = split(/:/, $cookies{(LOGIN_COOKIE_NAME)}, 5);
		return 0 if (time() - $login_time) > LOGIN_COOKIE_MAX_AGE;
		return 0 unless $type eq 'user' || $type eq 'teacher';
		if ($hash eq sha1_hex($self->{options}->{auth_cookie_secret}, $type, $uid, $login_time, $name)) {
			utf8::decode($name);
			$self->{user} = {type => $type, uid => $uid, name => $name};
			return 1;
		}
	}
	return 0;
}

################################################################################

sub process($) {
	my $self = shift;

	# Init Worker and View
	$self->{Model} = new WebTaskSubmitter::Model($self);
	$self->{Worker} = new WebTaskSubmitter::Worker($self, $self->{Model});
	$self->{View} = new WebTaskSubmitter::View($self, $self->{Model}, $self->{Worker});

	# Load tasks database
	unless ($self->{tasks} = do "./$self->{options}->{tasks_file}") {
		die "couldn't parse tasks file: $@"	if $@;
		die "couldn't do tasks file: $!"	unless defined $self->{tasks};
		die "couldn't run tasks file"		unless $self->{tasks};
	}

	# Connect to the sqlite DB
	my $dsn = "DBI:SQLite:$self->{options}->{db_file}";
	my $userid = "";
	my $password = "";
	$self->{dbh} = DBI->connect($dsn, $userid, $password, { RaiseError => 1 }) or die $DBI::errstr;
	#$self->{dbh}->{sqlite_unicode} = 1;

	# Parse arguments from submitted form (if there are some)
	my $data = {};
	my $param_table = {
		page		=> { var => \$self->{page}, check => 'login|teacher_login|logout|registration|tasklist|task|solution', default => DEFAULT_PAGE },
		action		=> { var => \$data->{action}, check => 'new', default => '' },
		code		=> { var => \$data->{code}, check => '\w+' },
		# Login/registration related fields
		login		=> { var => \$data->{login} },
		passwd		=> { var => \$data->{passwd} },
		passwd_check	=> { var => \$data->{passwd_check} },
		name		=> { var => \$data->{name} },
		email		=> { var => \$data->{email} },
		# Solutions related fields
		sid		=> { var => \$data->{sid}, check => '\d+', default => 0},
		solution_code	=> { var => \$data->{solution_code}, multiline => 1, default => '' },
		solution_comment=> { var => \$data->{solution_comment}, multiline => 1, default => ''},
		set_points	=> { var => \$data->{set_points}, check => '\d+', default => ''},
		set_status	=> { var => \$data->{set_status}, check => 'open|rated', default => 'open' },
	};
	UCW::CGI::parse_args($param_table);
	$self->{data} = $data;

	# Is logged in?
	$self->check_login();

	################
	# Worker logic #
	################

	# 1) When not logged in, redirect to login page
	if (!defined $self->{user} && $self->{page} ne 'login' && $self->{page} ne 'teacher_login' && $self->{page} ne 'registration') {
		$self->redirect('login');
	}

	# 2) Login and registration page (accesible only when not logged in)
	if ($self->{page} eq 'login') {
		$self->redirect('tasklist') if (defined $self->{user});
		$self->{Worker}->manage_login();
	} elsif ($self->{page} eq 'registration') {
		$self->redirect('tasklist') if (defined $self->{_user});
		$self->{Worker}->manage_registration();
	} elsif ($self->{page} eq 'logout') {
		$self->{Worker}->manage_logout();
	}


	# 3) Tasks related stuff
	$self->{Worker}->manage_task() if ($self->{page} eq 'task');
	$self->{Worker}->manage_solution() if ($self->{page} eq 'solution');

	$self->{processed} = 1;
}

sub render($) {
	my $self = shift;
	die("You have to first run \$WebTaskSubmitter->process() before rendering!\n") unless $self->{processed};

	# At this point, everything is processed, we have the correct state in $self
	# and we only need to display things :-]

	if (!defined $self->{user}) {
		return $self->{View}->registration_page() if ($self->{page} eq 'registration');
		return $self->{View}->teacher_login_page() if ($self->{page} eq 'teacher_login');
		return $self->{View}->login_page();
	} else {
		return $self->{View}->task_page() if ($self->{page} eq 'task');
		return $self->{View}->solution_page() if ($self->{page} eq 'solution');
		return $self->{View}->tasklist_page();
	}
}

1;
