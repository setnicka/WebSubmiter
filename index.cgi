#!/usr/bin/perl

use common::sense;

# use CGI::Carp 'fatalsToBrowser'; # TODO: remove this before production use

# To load packages from current directory
use FindBin;
use lib "$FindBin::Bin/lib";

use WebTaskSubmitter;

# Configuration for WebTaskSubmitter:
my $webTaskSubmitter = new WebTaskSubmitter({
	teacher_accounts => ['setnicka'], # usernames of teachers
	# Use only existing accounts. You have to log out and log in again to apply new roles.

	db_file => "data/webtaskdb.sqlite", # WARNING: the directory with SQLite DB file must be writable by sqlite process (chmod this directory)
	tasks_file => "data/tasks.pl",
	auth_cookie_secret => "someTotallyRandomSecretString", # Change it to YOUR secret string, used to hash login cookies

	# date_format_deadline => "%H:%M %d.%m.%Y",  # Not used yet
	# date_format_submits => "%H:%M:%S %d.%m.%Y",  # Not used yet
	usertable_for_students => 1,  # If student could see table with other students and points

	renew_password_expire => 3600,  # Default: 60m
	renew_password_enabled => 1,

	emails_enabled => 1,
	emails_immediate => 0,  # Send emails immediate after change (otherwise send all notifications at once when teacher press "send emails" button)
	emails_from => 'WebTaskSubmitter <test@test.test>',

	css_path => "./css",
	js_path => "./js",
	script_url => "" # URL used in module would be created as <script_url>?page=tasklist... (for index.cgi is value "" the best option)
});

# Pre-render worker (may do some redirection and exit)
$webTaskSubmitter->process();

# When not redirected:
# Start web page content by sending appropiate headers
print "Content-type: text/html; charset=utf-8\n\n";

my $output = $webTaskSubmitter->render();

print <<EOF
<!doctype html>
<html lang="cs">
<head>
	<title>UNIX - $webTaskSubmitter->{View}->{title}</title>
	$webTaskSubmitter->{View}->{headers}
	<link href='css/example_global.css' rel='stylesheet' type='text/css'>
</head>
<body>
<div class='container'>
<h1>$webTaskSubmitter->{View}->{title}</h1>
$output
</div>
</body>
</html>
EOF


