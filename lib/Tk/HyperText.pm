package Tk::HyperText;

use strict;
use warnings;
use base qw(Tk::Derived Tk::ROText);
use Tk::PNG;
use Tk::JPEG;
use Data::Dumper;

our $VERSION = "0.04";

Construct Tk::Widget 'HyperText';

# Preload the number-to-alpha tables.
#my %ALPHA = ();
#@ALPHA{(1..26)} = ("a".."z");
#@ALPHA{(27..702)} = ("aa".."zz");

sub Populate {
	my ($cw,$args) = @_;

	# Strip out the arguments we want before passing them to ROText.
	my $opts = {
		# -autorender => re-render the entire HTML document on update
		#                (otherwise, only render incoming HTML)
		rerender   => delete $args->{'-rerender'} || 1,
		# -linkcommand => a callback when a user clicks a link
		linkcommand => delete $args->{'-linkcommand'} || sub {},
		# -titlecommand => a callback when a page sets its title
		titlecommand => delete $args->{'-titlecommand'} || sub {},
		# -basehref => the "root" of the webpage
		basehref => delete $args->{'-basehref'} || '.',
		# -attributes => define default attributes for each tag
		attributes => {
			body => {
				bgcolor   => '#FFFFFF',
				text      => '#000000',
				link      => '#0000FF',
				vlink     => '#990099',
				alink     => '#FF0000',
			},
			font => {
				family    => 'Times New Roman',
				size      => 3,  # HTML size; not point size.
				color     => '', # inherit from body
				back      => '', # inherit from body
			},
		},
	};

	# Copy attributes over.
	if (exists $args->{'-attributes'}) {
		my $attr = delete $args->{'-attributes'};
		foreach my $tag (keys %{$attr}) {
			foreach my $name (keys %{$attr->{$tag}}) {
				$opts->{attributes}->{$tag}->{$name} = $attr->{$tag}->{$name};
			}
		}
	}

	# Pass the remaining arguments to our ROText parent.
	$args->{'-foreground'} = $opts->{attributes}->{body}->{text};
	$args->{'-background'} = $opts->{attributes}->{body}->{bgcolor};
	$cw->SUPER::Populate($args);

	# Reconfigure the ROText widget with our attributes.
	$cw->SUPER::configure (
		-font       => [
			-family => $opts->{attributes}->{font}->{family},
			-size   => $cw->_size ($opts->{attributes}->{font}->{size}),
		],
	);

	$cw->{hypertext} = {
		html       => '', # holds HTML code
		rerender   => $opts->{rerender},
		attributes => $opts->{attributes},
		linkcommand => $opts->{linkcommand},
		titlecommand => $opts->{titlecommand},
		basehref     => $opts->{basehref},
		history      => {}, # a history of visited links
	};

}

sub insert {
	my $cw = shift;
	my $pos = shift;
	$pos = $cw->index ($pos);
	my $text = shift;

	# TODO: insert will only insert to the "end"
	$cw->{hypertext}->{html} .= $text;


	# If we're doing re-rendering, render the entire block of HTML at once.
	if ($cw->{hypertext}->{rerender}) {
		# Reset the title to blank.
		&{$cw->{hypertext}->{titlecommand}} ($cw,"");

		# Render the whole entire page.
		$cw->SUPER::delete ("0.0","end");
		$cw->render ($cw->{hypertext}->{html});
	}
	else {
		# Just render this text.
		$cw->render ($text);
	}
}

sub delete {
	my $cw = shift;

	# TODO: delete just deletes everything
	$cw->{hypertext}->{html} = '';
	$cw->SUPER::delete ("0.0","end");
}

sub get {
	my $cw = shift;

	# TODO: get just gets everything.
	return $cw->{hypertext}->{html};
}

sub clear {
	my $cw = shift;

	# Delete everything.
	$cw->{hypertext}->{html} = '';
	$cw->SUPER::delete ("0.0","end");
}

sub clearHistory {
	my $cw = shift;

	# Clear the history.
	$cw->{hypertext}->{history} = {};
}

sub render {
	my ($cw,$html) = @_;

	# Make the HTML tags easier to find.
	$html =~ s/</%TK::HYPERTEXT::START::TAG%/g;
	$html =~ s/>/%TK::HYPERTEXT::END::TAG%/g;

	# Split the tags apart.
	my @parts = split(/%TK::HYPERTEXT/, $html);

	# Make an array of default styles for this render.
	my %default = (
		bgcolor => $cw->{hypertext}->{body}->{bgcolor} || '#FFFFFF',
		text    => $cw->{hypertext}->{body}->{text} || '#000000',
		link    => $cw->{hypertext}->{body}->{link} || '#0000FF',
		vlink   => $cw->{hypertext}->{body}->{vlink} || '#990099',
		alink   => $cw->{hypertext}->{body}->{alink} || '#FF0000',
		size    => $cw->{hypertext}->{font}->{size} || 3,
		font    => $cw->{hypertext}->{font}->{family} || 'Times New Roman',
	);

	# Make an array of escape sequences.
	my @escape = (
		'&lt;'   => '<',
		'&gt;'   => '>',
		'&quot;' => '"',
		'&apos;' => "'",
		'&nbsp;' => ' ',
		'&reg;'  => chr(0x00ae),  # registered trademark
		'&copy;' => chr(0x00a9),  # copyright sign
		'&amp;'  => '&',
	);

	# Reset the configuration of our ROText widget.
	$cw->SUPER::configure (
		-background => $default{bgcolor},
		-foreground => $default{text},
		-font       => [
			-family => $default{font},
			-size   => $cw->_size ($default{size}),
		],
	);

	# Make an array of current styles for this render.
	my %style = (
		weight     => 'normal', # or 'bold'
		slant      => 'roman',  # or 'italic'
		underline  => 0,        # or 1
		overstrike => 0,        # or 1
		family     => '',
		size       => '',
		foreground => '',
		background => '',
		justify    => 'left',   # or 'center' or 'right'
		offset     => 0,        # changes for <sup> and <sub>
		lmargin1   => 0,        # for <blockquote>s
		lmargin2   => 0,        # and <ol>s
		rmargin    => 0,        # and <ul>s
		titling    => 0,        # special--for title tags
		title      => '',       # our page title
		hyperlink  => 0,        # special--for hyperlinking
		linktag    => 0,        # for hyperlinking
		pre        => 0,        # special--for <pre>formatted text
		inul       => 0,        # in a <ul> section
		inol       => 0,        # in an <ol> section
	);

	# Stack the styles up.
	my @stackFont     = ();
	my @stackColor    = ();
	my @stackBG       = ();
	my @stackSize     = ();
	my @stackAlign    = ();
	my @stackOffset   = ();
	my @stackLMargin1 = ();
	my @stackLMargin2 = ();
	my @stackRMargin  = ();
	my @stackLinks    = ();
	my @stackOLLevel  = ();
	my @stackULLevel  = ();
	my @stackList     = (); # format... <ol|ul>#<level>
	my $olLevel       = 0; # ordered list level
	my $ulLevel       = 0; # unordered list level
	my $olStyles      = {}; # ordered list styles
	my $ulStyles      = {}; # unordered list styles
	# Ex:
	# $olStyles = {
	#   1 => { # level 1
	#      style    => 1, # numbers
	#      position => 5,
	#   },
	#   2 => { # level 2
	#      style    => 'i', # lowercase roman numerals
	#      position => 0,
	#   },
	# }

	# Set this to 1 when the first line of actual text has been written.
	# Blocklevel elements like to know.
	my $lineWritten = 0;

	# Keep an array of hyperlinks.
	my %hyperlinks = ();

	# Start parsing through the HTML code.
	my $lastTag;
	foreach my $sector (@parts) {
		# Is this a tag we're in?
		if ($sector =~ /^::START::TAG%/i) {
			$sector =~ s/^::START::TAG%//; # strip it

			# Find out the name of this tag and its attributes.
			my ($name,$attr) = split(/\s+/, $sector, 2);
			$attr = '' unless defined $attr;
			$name = uc($name);

			next unless defined $name && length $name;

			# Handle the various types of tags.
			if ($name eq "HTML" || $name eq "/HTML") { # <html>, </html>
				# That was nice of the programmer.
			}
			elsif ($name eq "HEAD" || $name eq "/HEAD") { # <head>, </head>
				# We don't need to do anything with this, either.
			}
			elsif ($name eq "TITLE") { # <title>
				# They're about to tell us the title.
				$style{titling} = 1;
			}
			elsif ($name eq "/TITLE") { # </title>
				# Stop titling our page.
				$style{titling} = 0;

				# Call our title-setting callback.
				&{$cw->{hypertext}->{titlecommand}} ($cw,$style{title});
			}
			elsif ($name eq "BODY") { # <body>
				# Collect as much data as we can.
				next unless defined $attr;
				if ($attr =~ /bgcolor="(.+?)"/i) {
					$cw->SUPER::configure (-background => $1);
					$default{bgcolor} = $1;
				}
				if ($attr =~ /link="(.+?)"/i) {
					$default{link} = $1;
				}
				if ($attr =~ /vlink="(.+?)"/i) {
					$default{vlink} = $1;
				}
				if ($attr =~ /alink="(.+?)"/i) {
					$default{alink} = $1;
				}
				if ($attr =~ /text="(.+?)"/i) {
					$cw->SUPER::configure (-foreground => $1);
					$default{text} = $1;
				}
			}
			elsif ($name eq "/BODY") { # </body>
				# Technically we shouldn't allow anymore HTML at this point,
				# on account of the </body>, but let's not be too picky.
			}
			elsif ($name eq "BASEFONT") { # <basefont>
				# Collect as much data as we can.
				if ($attr =~ /face="(.+?)"/i) {
					$default{font} = $1;
				}
				if ($attr =~ /size="(.+?)"/i) {
					$default{size} = $1;
				}
				if ($attr =~ /color="(.+?)"/i) {
					$default{text} = $1;
				}
			}
			elsif ($name eq "BASE") { # <base>
				if ($attr =~ /href="(.+?)"/i) {
					$cw->{hypertext}->{basehref} = $1;
				}
			}
			elsif ($name eq "FONT") { # <font>
				# Collect info.
				if ($attr =~ /face="(.+?)"/i) {
					push (@stackFont,$1);
					$style{family} = $1;
				}
				if ($attr =~ /color="(.+?)"/i) {
					push (@stackColor,$1);
					$style{foreground} = $1;
				}
				if ($attr =~ /back="(.+?)"/i) {
					push (@stackBG,$1);
					$style{background} = $1;
				}
				if ($attr =~ /size="(.+?)"/i) {
					push (@stackSize,$1);
					$style{size} = $1;
				}
			}
			elsif ($name eq "/FONT") { # </font>
				# Revert to the previous font stack.
				pop(@stackFont);
				pop(@stackColor);
				pop(@stackBG);
				pop(@stackSize);
				$style{family} = $stackFont[-1] || '';
				$style{foreground} = $stackColor[-1] || '';
				$style{background} = $stackBG[-1] || '';
				$style{size} = $stackSize[-1] || '';
			}
			elsif ($name eq "A") { # <a>
				# Make sure this link has an href.
				if ($attr =~ /href="(.+?)"/i) {
					my $href = $1;

					# Find the target.
					my $target = "_self";
					if ($attr =~ /target="(.+?)"/i) {
						$target = $1;
					}

					# Create a unique hyperlink tag.
					my $linktag = join ("-",$target,$href);

					# Store this tag.
					$hyperlinks{$linktag} = {
						href   => $href,
						target => $target,
					};

					# Tell the tagger we're linking.
					$style{hyperlink} = 1;
					$style{linktag} = $linktag;
				}
			}
			elsif ($name eq "/A") {
				# We're not linking anymore.
				$style{hyperlink} = 0;
				$style{linktag} = '';
			}
			elsif ($name eq "BLOCKQUOTE") { # <blockquote>
				$cw->SUPER::insert ('end',"\x0a\x0a") if $lineWritten;
				$style{lmargin1} += 25;
				$style{lmargin2} += 25;
				$style{rmargin} += 25;
				push (@stackLMargin1,$style{lmargin1});
				push (@stackLMargin2,$style{lmargin2});
			}
			elsif ($name eq "/BLOCKQUOTE") { # </blockquote>
				pop(@stackLMargin1);
				pop(@stackLMargin2);
				pop(@stackRMargin);
				$style{lmargin1} = $stackLMargin1[-1] || 0;
				$style{lmargin2} = $stackLMargin2[-1] || 0;
				$style{rmargin} = $stackRMargin[-1] || 0;
				$cw->SUPER::insert ('end',"\x0a\x0a");
				$lineWritten = 0;
			}
			elsif ($name eq "DIV") { # <div>
				$cw->SUPER::insert ('end',"\x0a") if $lineWritten;
				if ($attr =~ /align="(.+?)"/i) {
					my $align = $1;
					$align = 'left' unless $align =~ /^(left|center|right)$/i;
					#print "align: $align\n";
					$align = lc($align);
					push (@stackAlign,$align);
					$style{justify} = $align;
				}
			}
			elsif ($name eq "/DIV") { # </div>
				pop(@stackAlign);
				$style{justify} = $stackAlign[-1] || 'left';
				$cw->SUPER::insert ('end',"\x0a");
			}
			elsif ($name eq "SPAN" || $name eq "/SPAN") { # <span>, </span>
				# We'll deal with this when we implement... *gasp* StyleSheets!
			}
			elsif ($name eq "P") { # <p>
				$cw->SUPER::insert ('end',"\x0a\x0a") if $lineWritten;
			}
			elsif ($name eq "/P") { # </p>
				$cw->SUPER::insert ('end',"\x0a\x0a");
				$lineWritten = 0;
			}
			elsif ($name eq "BR") { # <br>
				$cw->SUPER::insert ('end',"\x0a");
			}
			elsif ($name eq "PRE") { # <pre>
				$cw->SUPER::insert ('end',"\x0a") if $lineWritten;
				push (@stackFont,"Courier New");
				$style{family} = "Courier New";
				$style{pre} = 1;
			}
			elsif ($name eq "/PRE") { # </pre>
				pop(@stackFont);
				$style{family} = $stackFont[-1] || '';
				$style{pre} = 0;
				$cw->SUPER::insert ('end',"\x0a");
			}
			elsif ($name eq "OL") { # <ol>
				if ($style{inol} == 0 && $style{inul} == 0 && $lineWritten) {
					$cw->SUPER::insert ('end',"\x0a\x0a");
				}
				elsif ($style{inol} || $style{inul}) {
					$cw->SUPER::insert ('end',"\x0a");
				}
				$style{lmargin1} += 15;
				$style{lmargin2} += 30;
				$style{inol}++;
				$olLevel++;

				# Find out any info.
				my $type  = 1;
				my $start = 1;
				if ($attr =~ /type="(.+?)"/i) {
					$type = $1;
				}
				if ($attr =~ /start="(.+?)"/i) {
					$start = $1;
				}

				$olStyles->{$olLevel} = {
					type     => $type,
					position => $start,
				};

				push (@stackList,join("#","ol",$olLevel));
				push (@stackOLLevel,$olLevel);
				push (@stackLMargin1,$style{lmargin1});
				push (@stackLMargin2,$style{lmargin2});

				#print "<ol> found: type=$type; start=$start\n";
			}
			elsif ($name eq "/OL") { # </ol>
				pop(@stackList);
				pop(@stackLMargin1);
				pop(@stackLMargin2);
				$style{lmargin1} = $stackLMargin1[-1] || 0;
				$style{lmargin2} = $stackLMargin2[-1] || 0;
				my $lastLevel = pop(@stackOLLevel);
				$style{olLevel} = $stackOLLevel[-1] || 0;
				delete $olStyles->{$lastLevel};

				$style{inol}--;
				$olLevel--;
				$olLevel = 0 if $olLevel < 0;
				$style{inol} = 0 if $style{inol} < 0;

				if ($style{inol} || $style{inul}) {
					$cw->SUPER::insert ('end',"\x0a");
				}
				else {
					$cw->SUPER::insert ('end',"\x0a\x0a");
				}
			}
			elsif ($name eq "UL") { # <ul>
				if ($style{inol} == 0 && $style{inul} == 0 && $lineWritten) {
					$cw->SUPER::insert ('end',"\x0a\x0a");
				}
				elsif ($style{inol} || $style{inul}) {
					$cw->SUPER::insert ('end',"\x0a");
				}
				$style{lmargin1} += 15;
				$style{lmargin2} += 30;
				$style{inul}++;
				$ulLevel++;

				# Find out any info.
				my $type  = "disc";
				if ($attr =~ /type="(.+?)"/i) {
					$type = $1;
				}

				$ulStyles->{$ulLevel} = {
					type     => $type,
				};

				push (@stackList,join("#","ul",$ulLevel));
				push (@stackULLevel,$ulLevel);
				push (@stackLMargin1,$style{lmargin1});
				push (@stackLMargin2,$style{lmargin2});

				#print "<ul> found: type=$type\n";
			}
			elsif ($name eq "/UL") { # </ul>
				pop(@stackList);
				pop(@stackLMargin1);
				pop(@stackLMargin2);
				$style{lmargin1} = $stackLMargin1[-1] || 0;
				$style{lmargin2} = $stackLMargin2[-1] || 0;
				my $lastLevel = pop(@stackOLLevel);
				$style{ulLevel} = $stackULLevel[-1] || 0;
				delete $ulStyles->{$lastLevel};

				$style{inul}--;
				$ulLevel--;
				$ulLevel = 0 if $ulLevel < 0;
				$style{inul} = 0 if $style{inul} < 0;

				if ($style{inol} || $style{inul}) {
					$cw->SUPER::insert ('end',"\x0a");
				}
				else {
					$cw->SUPER::insert ('end',"\x0a\x0a");
				}
			}
			elsif ($name eq "LI") { # <li>
				# The code for this must be in-general, as both <ul> and <ol>
				# need to use this tag.
				if (scalar(@stackList)) {
					my ($family,$level) = split(/#/, $stackList[-1], 2);
					my $kind  = '';
					my $begin = 0;
					if ($family eq "ol") {
						$kind = $olStyles->{$level}->{type};
						$begin = $olStyles->{$level}->{position};
					}
					else {
						$kind = $ulStyles->{$level}->{type};
						$begin = $ulStyles->{$level}->{position};
					}

					#print "<li> found (type=$kind; start=$begin)\n";

					if ($family eq "ol") {
						$olStyles->{$level}->{position}++;
						my $symbol = $cw->_getOLsym ($kind,$begin);
						my $symTag = $cw->_makeTag (\%style,\%default,\%hyperlinks);

						#print "insert: $symbol.\n";
						$symbol .= ".";
						$symbol .= " " until length $symbol >= 8;
						$cw->SUPER::insert ('end',"$symbol",$symTag);
					}
					else {
						my $symbol = $cw->_getULsym ($kind);
						my $symTag = $cw->_makeTag (\%style,\%default,\%hyperlinks);
						$cw->SUPER::insert ('end',"$symbol  ",$symTag);
					}
				}
			}
			elsif ($name eq "/LI") { # </li>
				$cw->SUPER::insert ('end',"\x0a",$lastTag);
			}
			elsif ($name =~ /^(CODE|TT)$/) { # <code>, <tt>
				push (@stackFont,"Courier New");
				$style{family} = "Courier New";
			}
			elsif ($name =~ /^\/(CODE|TT)$/) { # </code>, </tt>
				pop(@stackFont);
				$style{family} = $stackFont[-1] || '';
			}
			elsif ($name =~ /^(CENTER|RIGHT|LEFT)$/) { # <center>, <right>, <left>
				my $align = lc($name);
				$cw->SUPER::insert ('end',"\x0a") if $lineWritten;
				push (@stackAlign, $align);
				$style{justify} = $align;
			}
			elsif ($name =~ /^\/(CENTER|RIGHT|LEFT)$/) { # </center>, </right>, </left>
				pop(@stackAlign);
				$style{justify} = $stackAlign[-1] || 'left';
				$cw->SUPER::insert ('end',"\x0a");
			}
			elsif ($name =~ /^H(1|2|3|4|5|6|7)$/) { # <h1> - <h7>
				my $size = $cw->_heading ($1);
				$cw->SUPER::insert ('end',"\x0a\x0a") if $lineWritten;
				push (@stackSize, $size);
				$style{size} = $size;
				$style{weight} = "bold";
			}
			elsif ($name =~ /^\/(H(1|2|3|4|5|6|7))$/) { # </h1> - </h7>
				pop(@stackSize);
				my $newSize = $stackSize[-1] || '';
				$style{size} = $newSize;
				$style{weight} = "normal";
				$cw->SUPER::insert ('end',"\x0a\x0a");
				$lineWritten = 0;
			}
			elsif ($name eq "SUP") { # <sup>
				if (not length $style{size}) {
					$style{size} = $default{size} - 1;
				}
				else {
					$style{size}--;
				}
				$style{size} = 0 if $style{size} < 0;
				$style{offset} += 4;
				push (@stackOffset,$style{offset});
				push (@stackSize,$style{size});
			}
			elsif ($name eq "SUB") { # <sub>
				if (not length $style{size}) {
					$style{size} = $default{size} - 1;
				}
				else {
					$style{size}--;
				}
				$style{size} = 0 if $style{size} < 0;
				$style{offset} -= 2;
				push (@stackOffset,$style{offset});
				push (@stackSize,$style{size});
			}
			elsif ($name =~ /^\/(SUP|SUB)$/) { # </sup>, </sub>
				pop(@stackOffset);
				pop(@stackSize);
				$style{size} = $stackSize[-1] || '';
				$style{offset} = $stackOffset[-1] || 0;
			}
			elsif ($name =~ /^(B|STRONG)$/) { # <b>, <strong>
				$style{weight} = "bold";
			}
			elsif ($name =~ /^\/(B|STRONG)$/) { # </b>, </strong>
				$style{weight} = "normal";
			}
			elsif ($name =~ /^(I|EM)$/) { # <i>, <em>
				$style{slant} = "italic";
			}
			elsif ($name =~ /^\/(I|EM)$/) { # </i>, </em>
				$style{slant} = "roman";
			}
			elsif ($name =~ /^(U|INS)$/) { # <u>, <ins>
				$style{underline} = 1;
			}
			elsif ($name =~ /^\/(U|INS)$/) { # </u>, </ins>
				$style{underline} = 0;
			}
			elsif ($name =~ /^(S|DEL)$/) { # <s>, <del>
				$style{overstrike} = 1;
			}
			elsif ($name =~ /^\/(S|DEL)$/) { # </s>, </del>
				$style{overstrike} = 0;
			}
			elsif ($name eq "IMG") { # <img>
				# Must have a source.
				my $base = $cw->{hypertext}->{basehref};
				if ($attr =~ /src="(.+?)"/i) {
					my $file = $1;
					my $path = join ("/",$base,$file);

					# Make sure this file exists.
					if (-f $path) {
						# Determine the type.
						my $type = '';
						if ($file =~ /\.(jpg|jpeg|jpe)$/i) {
							$type = "JPEG";
						}
						elsif ($file =~ /\.gif$/i) {
							$type = "GIF";
						}
						elsif ($file =~ /\.png$/i) {
							$type = "PNG";
						}
						elsif ($file =~ /\.bmp$/i) {
							$type = "BMP";
						}

						if (length $type) {
							# See if the user defined hspace and vspace.
							my $hspace = 0;
							my $vspace = 0;

							if ($attr =~ /hspace="(.+?)"/i) {
								$hspace = $1;
							}
							if ($attr =~ /vspace="(.+?)"/i) {
								$hspace = $1;
							}

							# Image alignment is only vertical.
							my $align = "center";
							if ($attr =~ /align="(.+?)"/i) {
								$align = $1;
							}
							$align = "baseline" unless $align =~ /^(top|center|bottom|baseline)$/i;
							$align = lc($align);

							# Create it as a child of the text widget.
							my $pic = $cw->SUPER::Photo (
								-file   => $path,
								-format => $type,
							);

							# Insert it.
							$cw->SUPER::imageCreate ("end",
								-image => $pic,
								-align => $align,
								-padx  => $hspace,
								-pady  => $vspace,
							);
						}
					}
				}
			}
			next;
		}
		elsif ($sector =~ /^::END::TAG%/i) {
			$sector =~ s/^::END::TAG%//i; # strip it
		}

		# If we're titling, don't bother with tags.
		if ($style{titling} == 1) {
			# Add this to our page title.
			$style{title} .= $sector;
			next;
		}

		# (Re)invent a new tag.
		my $tag = $cw->_makeTag (\%style,\%default,\%hyperlinks);
		$lastTag = $tag;

		# If this was a hyperlink...
		if ($style{hyperlink} == 1) {
			# Bind this tag to an event.
			my $href = $hyperlinks{$style{linktag}}->{href};
			my $target = $hyperlinks{$style{linktag}}->{target};
			$cw->SUPER::tagBind ($tag,"<Button-1>", [ sub {
				my ($parent,$tag,$href,$target) = @_;

				# Add this to the history.
				$parent->{hypertext}->{history}->{$href} = 1;

				# Recolor this link.
				$parent->SUPER::tagConfigure ($tag,
					-foreground => $default{vlink},
				);

				# Call our link command.
				&{$cw->{hypertext}->{linkcommand}} ($parent,$href,$target);
			}, $tag, $href, $target ]);

			# Set up the hand cursor.
			$cw->SUPER::tagBind ($tag,"<Any-Enter>", [ sub {
				my ($parent,$tag) = @_;
				$cw->SUPER::configure (-cursor => 'hand2');
				$cw->SUPER::tagConfigure ($tag,
					-foreground => $default{alink},
				);
			}, $tag ]);
			$cw->SUPER::tagBind ($tag,"<Any-Leave>", [ sub {
				my ($parent,$tag,$href) = @_;
				$cw->SUPER::configure (-cursor => 'xterm');

				if (exists $cw->{hypertext}->{history}->{$href}) {
					$cw->SUPER::tagConfigure ($tag,
						-foreground => $default{vlink},
					);
				}
				else {
					$cw->SUPER::tagConfigure ($tag,
						-foreground => $default{link},
					);
				}
			}, $tag, $href ]);
		}

		# If this was preformatted text, preserve the line endings and spacing.
		if ($style{pre} == 1) {
			# Leave it alone.
		}
		else {
			$sector =~ s/\x0d//smg;
			$sector =~ s/\x0a+//smg;
			$sector =~ s/\s+/ /sg;
		}

		# If we wrote something here, inform the rest of the program.
		if (length $sector) {
			$lineWritten = 1;
		}

		# Filter escape codes.
		while ($sector =~ /&#([^;]+?)\;/i) {
			my $decimal = $1;
			my $hex = sprintf ("%x", $decimal);
			my $qm = quotemeta("&#$decimal;");
			my $chr = eval "0x$hex";
			my $char = chr($chr);
			$sector =~ s~$qm~$char~i;
		}
		for (my $i = 0; $i < scalar(@escape) - 1; $i += 2) {
			my $qm = quotemeta($escape[$i]);
			my $rep = $escape[$i + 1];
			$sector =~ s~$qm~$rep~ig;
		}

		# Finally, insert this bit of text.
		$cw->SUPER::insert ('end',$sector,$tag);
	}
}

sub _makeTag {
	my ($cw,$refstyle,$refdefault,$reflinks) = @_;

	my %style = %{$refstyle};
	my %default = %{$refdefault};
	my %hyperlinks = %{$reflinks};

	# (Re)invent a new tag.
	my $tag = join ("-",
		$style{family} || $default{font},
		$style{size} || $default{size},
		$style{foreground} || $default{text},
		$style{background} || $default{bgcolor},
		$style{weight},
		$style{slant},
		$style{underline},
		$style{overstrike},
		$style{justify},
		$style{offset},
		$style{lmargin1},
		$style{lmargin2},
		$style{rmargin},
		$style{hyperlink},
		$style{linktag},
		$style{pre},
	);
	$tag =~ s/\s+/+/ig; # convert spaces to +'s.

	# Is this a special hyperlink tag?
	my $color = $style{foreground} || $default{text};
	my $uline = $style{underline};
	my $size  = (length $style{size} > 0) ? $style{size} : $default{size};
	my $ptsize = $cw->_size ($size);
	if ($style{hyperlink} == 1) {
		# Temporarily reset the color and underline.
		my $href = $hyperlinks{$style{linktag}}->{href};

		#print "link href: $href\n";

		if (exists $cw->{hypertext}->{history}->{$href}) {
			$color = $default{vlink};
		}
		else {
			$color = $default{link};
		}

		$uline = 1;
	}

	# Configure this tag.
	$cw->SUPER::tagConfigure ($tag,
		-foreground => $color,
		-background => $style{background},
		-font       => [
			-family     => $style{family} || $default{font},
			-weight     => $style{weight},
			-slant      => $style{slant},
			-size       => $ptsize,
			-underline  => $uline,
			-overstrike => $style{overstrike},
		],
		-offset     => $style{offset},
		-justify    => $style{justify},
		-lmargin1   => $style{lmargin1},
		-lmargin2   => $style{lmargin2},
		-rmargin    => $style{rmargin},
	);

	return $tag;
}

sub _size {
	my ($cw,$size) = @_;

	# Calculate the point size based on the HTML size.
	if ($size == 1) {
		return 8;
	}
	elsif ($size == 2) {
		return 9;
	}
	elsif ($size == 3) {
		return 10;
	}
	elsif ($size == 4) {
		return 12;
	}
	elsif ($size == 5) {
		return 14;
	}
	elsif ($size <= 0) {
		return 6;
	}
	elsif ($size >= 6) {
		return 16;
	}

	return 6;
}

sub _heading {
	my ($cw,$level) = @_;

	# Calculate the point size for each H level.
	my %sizes = (
		1 => 6,
		2 => 5,
		3 => 4,
		4 => 3,
		5 => 2,
		6 => 1,
		7 => 0,
	);

	return $sizes{$level};
}

sub _getOLsym {
	my ($cw,$type,$pos) = @_;

	my %letterhash = (
		0 => '',
		1 => 'A',
		2 => 'B',
		3 => 'C',
		4 => 'D',
		5 => 'E',
		6 => 'F',
		7 => 'G',
		8 => 'H',
		9 => 'I',
		10 => 'J',
		11 => 'K',
		12 => 'L',
		13 => 'M',
		14 => 'N',
		15 => 'O',
		16 => 'P',
		17 => 'Q',
		18 => 'R',
		19 => 'S',
		20 => 'T',
		21 => 'U',
		22 => 'V',
		23 => 'W',
		24 => 'X',
		25 => 'Y',
		26 => 'Z',
	);

	# Numeric types are easy.
	if ($type =~ /^[0-9]+$/) {
		return $pos;
	}
	elsif ($type eq "I") {
		return Roman($pos);
	}
	elsif ($type eq "i") {
		# Roman numerals.
		return roman($pos);
	}
	elsif ($type eq 'a' || $type eq 'A') { # letters
		my $input = $pos;
		my $string = '';
		while ($input > 26) {
			my $first = $input % 26;
			my $second = ($input - $first) / 26;
			$string = $letterhash{$first} . $string;
			$input = $second;
		}

		$string = $letterhash{$input} . $string;
		return $string;
	}
	elsif ($type eq "A") { # caps
		#return uc($ALPHA{$pos});
	}

	return $pos;
}

sub _getULsym {
	my ($cw,$type) = @_;

	my $circle = chr(0x25cb);
	my $disc   = chr(0x25cf);
	my $square = chr(0x25aa);
	my $diam   = chr(0x25c6);

	if ($type =~ /circle/i) {
		return $circle;
	}
	elsif ($type =~ /square/i) {
		return $square;
	}
	elsif ($type =~ /disc/i) {
		return $disc;
	}
	elsif ($type =~ /diam/i) {
		return $diam;
	}

	elsif ($type =~ /^#([^;]+?)$/) {
		my $decimal = $1;
		my $hex = sprintf ("%x", $decimal);
		my $qm = quotemeta("&#$decimal;");
		my $chr = eval "0x$hex";
		my $char = chr($chr);
		return $char;
	}

	return $type;
}

################################
# Copied from Roman.pm to make #
# our code more independent.   #
################################

our %roman2arabic = qw(I 1 V 5 X 10 L 50 C 100 D 500 M 1000);
my %roman_digit = qw(1 IV 10 XL 100 CD 1000 MMMMMM);
my @figure = reverse sort keys %roman_digit;
#my %roman_digit;
$roman_digit{$_} = [split(//, $roman_digit{$_}, 2)] foreach @figure;

sub isroman($) {
    my $arg = shift;
    $arg ne '' and
      $arg =~ /^(?: M{0,3})
                (?: D?C{0,3} | C[DM])
                (?: L?X{0,3} | X[LC])
                (?: V?I{0,3} | I[VX])$/ix;
}

sub arabic($) {
    my $arg = shift;
    isroman $arg or return undef;
    my($last_digit) = 1000;
    my($arabic);
    foreach (split(//, uc $arg)) {
        my($digit) = $roman2arabic{$_};
        $arabic -= 2 * $last_digit if $last_digit < $digit;
        $arabic += ($last_digit = $digit);
    }
    $arabic;
}

sub Roman($) {
    my $arg = shift;
    0 < $arg and $arg < 4000 or return undef;
    my($x, $roman);
    foreach (@figure) {
        my($digit, $i, $v) = (int($arg / $_), @{$roman_digit{$_}});
        if (1 <= $digit and $digit <= 3) {
            $roman .= $i x $digit;
        } elsif ($digit == 4) {
            $roman .= "$i$v";
        } elsif ($digit == 5) {
            $roman .= $v;
        } elsif (6 <= $digit and $digit <= 8) {
            $roman .= $v . $i x ($digit - 5);
        } elsif ($digit == 9) {
            $roman .= "$i$x";
        }
        $arg -= $digit * $_;
        $x = $i;
    }
    $roman;
}

sub roman($) {
    lc Roman shift;
}

1;

=head1 NAME

Tk::HyperText - Create and manipulate ROText widgets which render HTML code.

=head1 SYNOPSIS

  my $hypertext = $mw->Scrolled ("HyperText",
    -scrollbars   => 'e',
    -wrap         => 'word',
    -linkcommand  => \&onLink,  # what to do when <a> links are clicked
    -titlecommand => \&onTitle, # what to do when <title>s are found
  )->pack (-fill => 'both', -expand => 1);

  # insert some HTML code
  $hypertext->insert ("end","<body bgcolor=\"black\" text=\"yellow\">"
    . "Hello, <b>world!</b></body>");

=head1 WIDGET-SPECIFIC OPTIONS

=over 4

=item B<-rerender>

Boolean. When true (the default), the ENTIRE contents of your HyperText widget will
be (re)rendered every time you modify it. In this way, if you insert, e.g. a "bold"
tag and don't close it, then insert new text, the new text should logically still be
in bold, and it would be when this flag is true.

When false, only the newly inserted text will be rendered independently of what else
is already there. If re-rendering the page is too slow for you, try disabling this flag.

=item B<-titlecommand>

This should be a CODEREF pointing to a subroutine that will handle changes in a
page's title. While HTML code is being parsed, when a title tag is found, it will
call this method.

The callback will received the following variables:

  $widget = a reference to the HyperText widget that wants to set a title.
  $title  = the text in the <title> tag.

=item B<-linkcommand>

This should be a CODEREF pointing to a subroutine that will handle the clicking
of hyperlinks.

The callback will received the following variables:

  $widget = a reference to the HyperText widget that invoked the link.
  $href   = the value of the link's "href" attribute.
  $target = the value of the link's "target" attribute.

=item B<-attributes>

This option will allow you to define all of the default settings for the display
of HTML pages. Here's an example:

  my $html = $mw->Scrolled ("HyperText",
    -attributes => {
      body => {
        bgcolor => 'white',
        text    => 'black',
        link    => 'blue',
        vlink   => 'purple',
        alink   => 'red',
      },
      font => {
        family => 'Arial',
        size   => 3,
        color  => '', # inherit from <body>
        back   => '', # inherit from <body>
      },
    },
  )->pack;

=item B<-basehref>

The "base href" of the webpages being rendered. This should be the local file
path (ex. "./demolib"). The base href can be reset using the E<lt>baseE<gt> tag
in a webpage. The base href is used for locating external files, such as images.

=back

=head1 DESCRIPTION

Tk::HyperText is a derived Tk::ROText class which supports the automatic rendering
of HTML code. It's designed to be easily useable as a drop-in replacement to any
Tk::ROText widget. Rendering HTML code is as easy as B<insert>ing it as raw HTML,
as shown in the synopsis.

=head1 WIDGET METHODS

In addition to all of the methods exported by Tk::ROText and Tk::Text, the following
methods have special behaviors:

=over 4

=item I<$text-E<gt>>B<insert> I<(where, html-code)>

Insert new HTML code, and render it automatically. Note that currently, only inserting
to the "end" works. See L<"BUGS"> below.

=item I<$text-E<gt>>B<delete> I<(start, end)>

Delete content from the textbox. Note that currently you can only delete EVERYTHING.
See L<"BUGS"> below.

=item I<$text-E<gt>>B<get> I<(start, end)>

Get the HTML code back out of the widget. Note that currently this gets ALL of the code.
See L<"BUGS">. This returns the actual HTML code, not just the text that's been rendered.

=item I<$text-E<gt>>B<clear>

Clear the entire text widget display.

=item I<$text-E<gt>>B<clearHistory>

Clear the history in the text widget. This will make all the links that were "visited
links" become "unvisited links" again.

=back

=head1 SUPPORTED HTML

The following HTML tags and attributes are fully supported by this module:

  <html>, <head>
  <title>      *calls -titlecommand when found
  <body>       (bgcolor, link, vlink, alink, text)
  <basefont>   (face, size, color)
  <base>       (href)
  <font>       (face, size, color, back)
  <img>        (src, align, hspace, vspace)*
  <a>          (href, target)
  <ol>, <ul>   (type, start)
  <li>
  <div>        (align=left|center|right)
  <span>
  <blockquote>
  <p>, <br>
  <pre>
  <code>, <tt>
  <center>, <right>, <left>
  <h1> - <h6>
  <sup>, <sub>
  <b>, <strong>
  <i>, <em>
  <u>, <ins>
  <s>, <del>

* Image alignment must be "top", "middle", "bottom", or "baseline". Tk::Text doesn't
support "left" and "right" alignments.

=head1 EXAMPLE

Run the `demo.pl` program included in the distribution for a demonstration. It's a
kind of simple web browser that views HTML pages in the "demolib" directory, and
supports hyperlinks that link from one page to another.

=head1 BUGS

As noted above, the B<insert> method only inserts at the end, B<delete> deletes
everything, and B<get> gets everything. I plan on coming up with a way to fix this
in a later version.

There are some forms of HTML that might not render properly. For instance, if you
set E<lt>font back="yellow"E<gt>, then set E<lt>font color="red"E<gt>, and then
close the red font, it will also stop the yellow highlight color too. Situations
like this aren't too serious, though. So, if you set one attribute, set them all. ;)

There's a minor bug in the counting of alphabetic ordered lists. It counts them
from A to Z, then AA to AY, B, BA to BY, C, CA to CY, D, etc.

=head1 SEE ALSO

L<Tk::ROText> and L<Tk::Text>.

=head1 CHANGES

0.04 June 23, 2007

  - Added support for the <basefont> tag.
  - Added support for <ul>, <ol>, and <li>. I've even extended the HTML specs a
    little and added "diamonds" as a shape for <ul>, and allowed <ul> to specify
    a decimal escape code (<ul type="#0164">)
  - Added a "page history", so that the "visited link color" on pages can actually
    be applied to the links.
  - Fixed the <blockquote> so that the margin applies to the right side as well.

0.02 June 20, 2007

  - Bugfix: on consecutive insert() commands (without clearing it in between),
    the entire content of the HTML already in the widget would be inserted again,
    in addition to the new content. This has been fixed.

0.01 June 20, 2007

  - Initial release.

=head1 AUTHOR

Casey Kirsle, E<lt>casey at cuvou.netE<gt>

=cut

