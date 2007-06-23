#!/usr/bin/perl -w

# Tk::HyperText Demonstration: The browsing of a very simple "web site"

use strict;
use warnings;
use lib "./lib";
use Tk;
use Tk::HyperText;

# Create the MainWindow.
our $mw = MainWindow->new (
	-title => 'Tk::HyperText',
);
$mw->geometry ('550x400');

# Some variables for our browser.
my $url     = "index.html";
my @history = ();
my $index   = 0;

###############################
# Draw the toolbars           #
###############################

my $toolbar = $mw->Frame (
	-borderwidth => 2,
	-relief      => 'raised',
)->pack (-side => 'top', -fill => 'x');

my $btnBack = $toolbar->Button (
	-text    => "Back",
	-command => \&goBack,
)->pack (-side => 'left');
my $btnForward = $toolbar->Button (
	-text    => "Forward",
	-command => \&goForward,
)->pack (-side => 'left');
my $btnReload = $toolbar->Button (
	-text    => "Reload",
	-command => \&reload,
)->pack (-side => 'left', -padx => 5);
my $btnHome = $toolbar->Button (
	-text    => "Home",
	-command => \&home,
)->pack (-side => 'left');
my $btnClear = $toolbar->Button (
	-text    => "Clear History",
	-command => \&history,
)->pack (-side => 'left');
my $btnExit = $toolbar->Button (
	-text    => "Exit",
	-command => sub {
		exit(0);
	},
)->pack (-side => 'right');

###############################
# Draw the HyperText Widget   #
###############################

my $mainframe = $mw->Frame (
)->pack (-fill => 'both', -expand => 1);

my $hypertext = $mainframe->Scrolled ("HyperText",
	-scrollbars   => 'e',
	-titlecommand => \&onTitle,
	-linkcommand  => \&onLink,
	-basehref     => "./demolib",
	-wrap         => 'word',
)->pack (-fill => 'both', -expand => 1);

# Link to our homepage.
&openPage ("index.html");

$mw->bind ('<Control-s>', sub {
	my $code = $hypertext->get ("0.0","end");
	print $code . "\n";
});

MainLoop;

###############################
# Our Subroutines             #
###############################

# This sub opens a page for display in our "browser"
sub openPage {
	my $page = shift;
	my $history = shift || 0; # clicked back or forward
	$url = $page;

	print "Opening page: $page\n";
	push (@history,$page);
	$index = scalar(@history) - 1 unless $history;

	my @html = ();
	if (-f "./demolib/$page") {
		open (PAGE, "./demolib/$page");
		@html = <PAGE>;
		close (PAGE);
		chomp @html;
	}
	else {
		@html = ("<html>",
			"<head>",
			"<title>404 Page Not Found</title>",
			"</head>",
			"<body>",
			"<h1>404 Page Not Found</h1>",
			"The page $page was not found.",
			"</body>",
			"</html>");
	}

	# Clear the page viewer.
	$hypertext->clear;

	# Insert the HTML code.
	$hypertext->insert ("end",join ("\n",@html));
}

# The Back, Forward, and Home buttons.
sub goBack {
	# Minus the index.
	$index--;
	if (defined $history[$index]) {
		&openPage($history[$index],1);
	}
}
sub goForward {
	# Plus the index.
	$index++;
	if (defined $history[$index]) {
		&openPage($history[$index],1);
	}
}
sub reload {
	&openPage ($url,1);
}
sub home {
	&openPage ("index.html");
}
sub history {
	$hypertext->clearHistory;
	&openPage ($url,1);
}

# This sub gets called when a page sets a <title>
sub onTitle {
	my ($cw,$title) = @_;

	# Set our MW title.
	$mw->title ("$title - Tk::HyperText");
}

# This sub gets called when we click on a hyperlink.
sub onLink {
	my ($cw,$href,$target) = @_;

	print "Link clicked: open $href in $target\n";

	# If target="_blank", open this link in our own web browser.
	if ($target eq "_blank") {
		my $htmlview = ($^O =~ /win32/i) ? "start" : "htmlview";
		system ("$htmlview $href");
	}
	else {
		# Load this page in our own "browser"
		&openPage ($href);
	}
}
