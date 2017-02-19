#!/usr/bin/perl

use common::sense;

# use CGI::Carp 'fatalsToBrowser'; # TODO: remove this before production use

# To load packages from current directory
use FindBin;
use lib "$FindBin::Bin/lib";

use WebTaskSubmitter;

# Configuration for WebTaskSubmitter:
my $webTaskSubmitter = new WebTaskSubmitter({
	teacher_name => "Reginald Barclay", # name to display in discussion and etc
	teacher_passwd => "myTestPassword",

	db_file => "data/webtaskdb.sqlite",
	tasks_file => "data/tasks.pl",
	auth_cookie_secret => "someTotallyRandomSecretString", # Change it to YOUR secret string, used to hash login cookies

	date_format_deadline => "%H:%M %d.%m.%Y",
	date_format_submits => "%H:%M:%S %d.%m.%Y",

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


