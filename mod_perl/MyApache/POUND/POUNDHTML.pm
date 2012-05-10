#!/usr/bin/perl

# This module handles most of the HTML-specific display code.

# I'm trying to avoid database callbacks in this code. I'm not sure if it's going to
# work out, but it'll be nice and clean if that's possible. On the other hand, if it is
# not possible in the end, we can simplify a lot of the interfaces and make the code
# faster by eliminating some of the abstraction.

use strict;
use DBI;
package MyApache::POUND::POUNDHTML;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDSession;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDBLOGDB;
use MyApache::POUND::POUNDUser;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(sthtml endhtml redir wik_redir get_htlink errorpage msgpage);
our @EXPORT = @EXPORT_OK;

sub wik_redir
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
my $targ = $args->mandate('target_page');
$args->argok();

redir(apacheobj => $apache_r, target_page => url_wikpage(page_name => $targ) );
}

sub redir
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
my $targ = $args->mandate('target_page');
$args->argok();

$apache_r->status(302); # 302 = redirect
$apache_r->header_out(Location => $targ);
}

sub sthtml
{ # Starts the HTML stuff
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $title = $args->accept('title', 'POUND');
my $rssfeed = $args->accept('rssfeed', undef);
my $atomfeed = $args->accept('atomfeed', undef);
my $nocss = $args->accept('no_css', 0);
my $is_public = $args->accept('is_public', 0);
$args->argok();

my $privtext='';
unless($is_public)
	{
	$privtext = qq{<META name="ROBOTS" content="NOINDEX">\n};
	}
my $rsstext = '';
if(defined($rssfeed))
	{
	$rsstext= qq{<link rel="alternate" type="application/rss+xml" title="RSS" href="$rssfeed" />};
	}
my $atomtext = '';
if(defined($atomfeed))
	{
	$atomtext= qq{<link rel="alternate" type="application/atom+xml" title="Atom" href="$atomfeed" />};
	}

my $cssurl = url_sitecss();
my $css = qq{
<style type="text/css">
\@import url("$cssurl");
</style>
};

if($nocss) {$css = '';}

print <<EOSTATICSTART
<!DOCTYPE html PUBLIC "-//W3C/DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
$css
<title>$title</title>
$rsstext
$atomtext
$privtext
</head>
<body>
EOSTATICSTART
}

sub endhtml
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();
print <<EOEHTML;

</body></html>
EOEHTML
}

sub get_htlink
{ # Returns HTML with a given link wrapper around text. Nicely wraps public/private links
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $target = $args->mandate("target");
my $content = $args->mandate("content");
my $follow_ok = $args->accept("follow_ok", 0);
$args->argok();

my $nff = '';
unless($follow_ok)
	{$nff = q{ rel="nofollow"};}
return qq{<a href="$target"$nff>$content</a>};
}

sub errorpage
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $text = $args->mandate("text");
my $html_started = $args->accept("html_started", 0);
$args->argok();

my $datestring = localtime();
if(! $html_started)
	{
	print <<EOERHEDD;
<html><head><title>Error Page</title></head>
<body style="background:white;color:black;">
EOERHEDD
	}
print <<EOERR;
<h1>Error</h1>
<hr />
$text
<hr />
$datestring
</body></html>
EOERR
}

sub msgpage
{ # FIXME: My handling of CSS here is poor
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $msg = $args->mandate("text");
my $urlcont = $args->accept("url", undef);
$args->argok();

sthtml(title => "Message", no_css => 1);
my $contbit = "";
if(defined $urlcont)
	{
	$contbit = qq{<div style="color:blue;background:grey;">Click <a href="$urlcont">here</a> to continue.};
	}
my $datestring = localtime();
print <<EMSG;
<h1 style="color:green;">Message:</h1>
<hr />
<div style="color:green;">$msg</div><br />$contbit
<hr />
$datestring
</body></html>
EMSG
}


1;
