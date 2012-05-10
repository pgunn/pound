#!/usr/bin/perl

# Handle BLOG display content. Sits above the generic HTML facility

use strict;
use DBI;
package MyApache::POUND::POUNDBLOGContent;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDSession;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDBLOGDB;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDVersion;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(display_blogmain display_elistpage do_blog_captionarea dispatch_notdone display_entrywrapper close_entrywrapper do_footer);
our @EXPORT = @EXPORT_OK;

sub display_blogmain
{ # XXX Consider completely redoing this
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $cfg 	= $args->mandate('blogcfg');
my $num_entries	= $args->mandate('num_entries');
my $blogtype	= $args->accept('blogtype', 'blog');
my $user	= $args->accept('userid', 0);
$args->argok();

my $settingspart;
my $loginpart;
my $logoutpart;
my $tmhtml="\n";
$tmhtml .= join "\n", map	{
				q{<div class="tmentry">}
				. get_htlink(target => url_topic(blogname => $$cfg{name}, topicname => $_), content => $_, follow_ok => 1)
				. qq{</div>\n};
				}
				sort {$a cmp $b}
				map {my %topicall = get_topic_by_id(topicid => $_);$topicall{name};}
				(get_all_topics_for_blog(blogid => $$cfg{id}));
my $headerlinks = get_header_extra_for_blog(blogid => $$cfg{id});
my $blogimg=""; # FIXME Note that the div where this is referenced should not be using an IMG tag. Should be done with CSS, and that CSS should check for exist of a blog image
if(defined($$cfg{blogimg}) )
	{
	$blogimg = $$cfg{blogimg};
	}
my $owner = login_from_uid(uid => $$cfg{author}); 
my $jtitle = $$cfg{title};

my $num_archive_pages;
	{
	$num_archive_pages = POSIX::ceil($num_entries/entries_per_archpage() );
	}
my $getacctpart;
if($user)
	{
	$getacctpart = qq{<div class="disabled">GetAcct</div>\n};
	$loginpart = "Login\n";
	$settingspart = get_htlink(target => url_prefs(), content => 'Settings') . "\n";
	$logoutpart = get_htlink(target => url_logoutpage(), content => 'Logout') . "\n";
	}
else
	{
	$getacctpart = get_htlink(target => url_newuser(), content => 'GetAcct') . "\n";
	$settingspart = get_htlink(target => url_prefs(), content => 'Settings (Cookies)') . "\n";
	$loginpart = get_htlink(target => url_loginpage(), content => 'Login') . "\n";
	$logoutpart = "Logout\n";
	}
my $archfirstpage = url_archpage(blogname => $$cfg{name}, page => 1);
my $archlastpage = url_archpage(blogname => $$cfg{name}, page => $num_archive_pages);
my $elisturl = url_elist(blogname => $$cfg{name});
my $ownerrealname = name_from_userid(userid => $$cfg{author});
my $rss_stream = url_blogrss(blogname => $$cfg{name});
my $atom_stream = url_blogatom(blogname => $$cfg{name});
my $notdoneurl = url_notdone();
my $feedbit='';
if(defined($rss_stream) || defined($atom_stream))
	{
	$feedbit = q{<font size="-1">(<img src="} . get_feedicon() . q{" />}
.	(defined($atom_stream) ? get_htlink(target => $atom_stream, content => 'Atom', follow_ok => 1):'')
.	((defined($rss_stream) && defined($atom_stream)) ? '/' : '')
.	(defined($rss_stream) ? get_htlink(target => $rss_stream, content => 'RSS', follow_ok => 1):'')
. 	q{)</font>};
	}

my $capextra = qq{A $blogtype by $ownerrealname $feedbit<br />\n}
	. qq{\t\t<div id="headermisc">See also:}
	. '[' . get_htlink(target => url_wiki(), content => 'Wiki') . ']'
	. (($$cfg{author}==$user && $$cfg{blogtype} eq 'b')?(get_htlink(target => url_nentrypage(blogname => $$cfg{name}), content => '[POST]')):'')
	. (($$cfg{author}==$user && $$cfg{blogtype} eq 'c')?(get_htlink(target => url_ncomicpage(blogname => $$cfg{name}), content => '[POST]')):'')
	. (($$cfg{author}==$user)?(get_htlink(target => url_blogcfg(blogname => $$cfg{name}), content => '[Settings]')):'')
	. "$headerlinks\n"
	. qq{\t</div><!-- headermisc -->\n}; # Close linkarea
do_blog_captionarea(blogimg => $blogimg, hdrtxt => $jtitle, caption_extra => $capextra);

my $helppart = get_htlink(target => $notdoneurl, content => 'Help', follow_ok => 1);

my $archpart = join '', map {q{<div class="arentry">} . $_ . qq{</div>\n} }
		(
		get_htlink(target => $archfirstpage	, content => 'First Page'	, follow_ok => 1),
		get_htlink(target => $archlastpage	, content => 'Last Page'	, follow_ok => 1),
		get_htlink(target => $elisturl		, content => 'Entry List'	, follow_ok => 1),
		get_htlink(target => $notdoneurl	, content => 'Search'		, follow_ok => 1)
		);
		
print <<EOFHDR;

<div id="centrearea">
<div id="menupart">
	<div id="accountmenu" class="gmenu">
		Accounts
		<div class="amentry">$getacctpart</div>
		<div class="amentry">$loginpart</div>
		<div class="amentry">$settingspart</div>
		<div class="amentry">$logoutpart</div>
		<div class="amentry">$helppart</div>
	</div><!-- accountmenu -->
	<br />

	<div id="archmenu" class="gmenu">
        	Archives
		$archpart
	</div><!-- archmenu -->
	<br />

	<div id="topicmenu" class="gmenu">
	Topics
	$tmhtml
	</div><!-- topicmenu -->
	<br />
</div> <!-- menupart -->
EOFHDR
}

sub display_elistpage
{ # FIXME: Eventually clean up blogid/uid redundancy
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $blogname	= $args->mandate('blogname');
my $entries	= $args->mandate('entries_r');
$args->argok();

print scalar(@$entries) . qq{ entries:\n};
print qq{<table border="1" bgcolor="grey">\n};
print qq{<tr><td>entry<td>subject</td><td>date</td></tr>\n};
foreach my $entry (@$entries)
	{
	my $title = get_title_for_entry(blogid => $blogid, zeit => $entry);
	my $url = url_nodepage(blogname => $blogname, nodezeit => $entry, nodetype => 'entry');
	print q{<tr>}
		. qq{<td>}
			. get_htlink(target => $url, content => $entry, follow_ok => 1)
		. q{</td>}
		. qq{<td>$title</td>}
		. q{<td>} . localtime($entry) . q{</td>}
		. qq{</tr>\n};
	}
print "</table>\n";
}

sub do_blog_captionarea
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogimg	= $args->mandate('blogimg');
my $hdrtxt	= $args->mandate('hdrtxt');
my $capextra	= $args->mandate('caption_extra');
$args->argok();

print <<EOCAP;

<div id="toparea">
<div id="caption">
	<div id="picarea">
	<img src="$blogimg" />
	</div> <!-- picarea -->
<div id="topareatext">
<h1>$hdrtxt</h1>
$capextra
</div> <!-- topareatext -->
</div> <!-- caption -->
</div> <!-- toparea -->
EOCAP
}

sub dispatch_notdone(;)
{
print <<ENOTDONE;
<html><head><title>POUND - Not done</title></head>
<body style="background: red;">
You tried to use a feature of the software that is not yet implemented.
</body></html>
ENOTDONE
}

sub display_entrywrapper
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();
print qq{<div id="entrypart">\n};
}

sub close_entrywrapper
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();
print qq{</div><!-- entrypart -->\n};
print qq{</div><!-- centre area -->\n};
}

sub do_footer
{
my $pound = get_htlink(target => url_pounddistro(), content => 'POUND') ;
my $namehost = get_name_of_host();
my $urlhost = get_url_of_host();
my $hostlink = get_htlink(content => $namehost, target => $urlhost);

print <<EOFOOT;
<div id="footer"><!-- footer -->
Site hosted on $hostlink, content served by $pound, a Public Domain Wiki/Blog engine.
</div><!-- footer -->
EOFOOT
}

1;
