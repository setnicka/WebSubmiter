#	Poor Man's CGI Module for Perl -- Error Handling
#
#	(c) 2002--2012 Martin Mares <mj@ucw.cz>
#
#	This software may be freely distributed and used according to the terms
#	of the GNU Lesser General Public License.

package UCW::CGI::ErrorHandler;

# E-mail address of the script admin (optional, preferably set in a BEGIN block)
our $error_mail;

# A function called for reporting of errors
our $error_hook;

# Set to true if you want to show detailed error messages to the user
our $print_errors = 0;

my $error_reported;
our $exit_code;

# XXX: Not expecting error objects, just strings
sub report_bug(@) {
	# Detect direct invocation (to keep track of context)
	my @caller = caller;
	if (@caller && $caller[0] ne 'UCW::CGI::ErrorHandler') {
		# Mimics die() behavior
		$@ = join '', @_;
		$@ =~ /\n$/ or $@ .= " at $caller[1] line $caller[2].\n";
		# This is the first die call, report_bug will be called again
		# from handler defined below.
		die $@;
	}
	# Report error
	if (!defined $error_reported) {
		$error_reported = 1;
		if (defined($error_hook)) {
			# Error hooks should have side-effect, may die (with new
			# error message)
			&$error_hook($_[0]);
		} else {
			print "Status: 500\n";
			print "Content-Type: text/plain\n\n";
			if ($print_errors) {
				print "Internal bug: ", $_[0], "\n";
			} else {
				print "Internal bug.\n";
			}
			print "Please notify $error_mail\n" if defined $error_mail;
		}
	}

	# Letting die() bubble up, where interpreter finally prints it on
	# STDERR which is usually directed to the main server error log.
	# Since die() cannot be cancelled, this is the best option.
	die @_;
}

BEGIN {
	# TODO: `man perlvar` advises in Bugs section not to use $SIG{__DIE__}
	# When executing eval, do nothing ($^S == 1)
	$SIG{__DIE__} = sub($) { die @_ if $^S; report_bug("ERROR: " . $_[0]); };
	$SIG{__WARN__} = sub($) { die @_ if $^S; report_bug("WARNING: " . $_[0]); };
	$exit_code = 0;
}

END {
	$? = $exit_code;
}

42;
