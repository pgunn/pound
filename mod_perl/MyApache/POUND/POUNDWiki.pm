#!/usr/bin/perl

# Handles wiki page. 
use strict;
package MyApache::POUND::POUNDWiki;

use Apache2::compat;
use Apache2::Const -compile => qw(:methods);
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDCSS;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDMarkup;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDWikiDB;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDSession;
use MyApache::POUND::POUNDPermissions;
use MyApache::POUND::POUNDForms;
use MyApache::POUND::Argpass;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_wiki get_wiki_entry);
our @EXPORT = @EXPORT_OK;

sub dispatch_wiki
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $reqargs	= $args->mandate('args');
$args->argok();

my $mode = 'show'; # default
if(! @$reqargs)
	{
	wik_redir(apacheobj => $apache_r, target_page => "Main");
	return;
	}
my $request = shift(@$reqargs);
if(@$reqargs) # Watson, we are about to have options!
	{
	my $option = shift(@$reqargs);
	if($option eq 'history')
		{
		$mode = 'history';
		}
	elsif($option eq 'edit')
		{
		$mode = 'edit';
		}
	elsif($option eq 'version')
		{
		$mode = 'version';
		}
	}
if($request =~ /^Special:(.*)$/)
	{
	my $srequest = $1;
	handle_special_pagereq(special_request => $1);
	return;
	}

my $wikeid;
my $requested_page = normalise_wiki_pagetitle(pagename => $request);

if(($mode eq 'edit') || (! ($wikeid = wiki_page_exists(pagename => $requested_page))))
	{
	serve_wikedit_page(apacheobj => $apache_r, name => $requested_page, args => $reqargs);
	}
elsif($mode eq 'show')
	{
	sthtml(title => "POUNDWiki - $request", is_public => 1);
	print qq{<div id="wikpagename">$request</div>\n};
	print "<hr />\n";
	serve_wiki_page(wikentryid => $wikeid, name => $requested_page);
	}
elsif ($mode eq 'history')
	{
	sthtml(title => "POUNDWiki - History: $requested_page");
	print qq{<div id="wikpagename">$requested_page - history</div>\n};
	print "<hr />\n";
	serve_wikhistory_page(name => $requested_page);
	}
elsif($mode = 'version')
	{
	sthtml(title => "POUNDWiki - Historical: $requested_page");
	print qq{<div id="wikpagename">$requested_page (not current version)</div>\n};
	print "<hr />\n";
	my $version = $$reqargs[0];
	serve_wiki_page(wikentryid => $wikeid, name => $requested_page, version => $version);
	}

endhtml();
}

sub get_wikpage_content
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $wikeid	= $args->mandate('wikentryid');
my $version	= $args->mandate('version');
$args->argok();

my $returner;
if (! defined($version))
	{
	$version = get_latest_article_version(wikentryid => $wikeid);
	}
$returner = get_wiki_article(wikentryid => $wikeid, version => $version);
return $returner;
}

sub serve_wiki_page
{ # FIXME This is a lousy layout.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $wikeid	= $args->mandate('wikentryid');
my $page	= $args->mandate('name');
my $version	= $args->accept('version', undef);
$args->argok();

print q{<div id="wikcontent">};
	print do_markup(
		data => get_wikpage_content(wikentryid => $wikeid, version => $version),
		context => 'wiki',
		content_flags => ':');
print qq{</div>\n\n};

print qq{<div id="wikoptions">\n};
foreach my $part ('edit', 'history') # XXX If user can administer the wiki, add extra stuff here
	{
	print q{<div class="wikoption">};
	print '[' . get_htlink(target => url_wikpage(page_name => $page) . '/' . $part, content => ucfirst($part)) . ']';
	print qq{</div>\n};
	}
print qq{</div>\n};
}

sub serve_wikedit_page
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $page	= $args->mandate('name');
my $reqargs	= $args->mandate('args');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);
if(! $uid) {errorpage(text => "You must be logged in to edit wiki pages!");return;}

if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST");
		return;
		}
	my %postdata = post_content(apacheobj => $apache_r);
	if(0 == scalar(keys %postdata))
		{
		errorpage(text => "BAD POST: empty data");
		return;
		}
	if($postdata{validcode} ne apache_session_key(apacheobj => $apache_r))
		{
		errorpage(text => 'BAD POST: Foreign source? Failed security check');
		return;
		}
	foreach my $toclean (qw{pagename wikarticlebox wikcomments})
		{$postdata{$toclean} = de_post_mangle(post_in => $postdata{$toclean});}
	
	my $page_name = normalise_wiki_pagetitle(pagename => $postdata{pagename});
	
	#print join("\n<br />", map{"$_:$postdata{$_}" } keys %postdata);
	my $wikeid;
	my $newver;
	if(! ($wikeid = wiki_page_exists(pagename => $page_name)))
		{
		if(! ok_wikipost(userid => $uid, entry_locked => 0) )
			{
			errorpage(text => "Wiki is not public");
			return;
			}
		# Setup New page, get wikeid for it, set $newver
		make_new_wikentry(title => $page_name);
		$wikeid = wiki_page_exists(pagename => $page_name);
		if(! $wikeid)
			{
			errorpage(text => "Could not create new article $page_name");
			return;
			}
		$newver = 1;
		}
	else
		{
		$newver = 1 + get_latest_article_version(wikentryid => $wikeid);
		}
	
	if(! ok_wikipost(userid => $uid, entry_locked => wikeid_page_locked(wikentryid => $wikeid)) )
		{
		errorpage(text => "Wiki is not public or page is locked.");
		return;
		}
	new_wikventry(	wikentryid => $wikeid,
			version => $newver,
			userid => $uid,
			comments => $postdata{wikcomments},
			data => $postdata{wikarticlebox});
	wik_redir(apacheobj => $apache_r, target_page => $page_name);
	}
else	# The form
	{
	sthtml(title => "POUNDWiki - Editing page $page");
	print "<hr />\n";
	print qq{<div id="wikpagename">Editing: $page</div>\n};
	my %wikentry = get_wiki_entry(pagename => $page);
	print qq{<div id="wikedit">\n};
	if($wikentry{locked} && (! uid_is_super(userid => $uid)) )
		{
		print "Sorry, page is locked\n";
		return;
		}
	if(! (wiki_public() || (uid_can_wiki(userid => $uid)) ) )
		{
		print "Wiki is closed for editing\n";
		return;
		}
	# Handle ACL/authentication stuff here
	
	my $articleraw; # Raw content of article
	my $wikeid = wiki_page_exists(pagename => $page);
	my $articlever; # Version of page being edited
	if(! $wikeid)
		{
		$articleraw='';
		$articlever= 0;
		}
	else
		{
		$articlever = get_latest_article_version(wikentryid => $wikeid);
		$articleraw = get_wiki_article(wikentryid => $wikeid, version => $articlever);
		}
	my $submit = url_wikedit_submit(page_name => $page);
	
	stform(submit_url => $submit, formid => 'editform', validator => apache_session_key(apacheobj => $apache_r));
	form_txtarea(caption => '', name => 'wikarticlebox', cols => 120, rows => 25, value => $articleraw);
	print "<br />";
	form_txtfield(caption => 'Comments', name => 'wikcomments', size => 50, max_length => 99);
	form_hidden(name => 'version', value => $articlever);
	form_hidden(name => 'pagename', value => $page);
	endform(submit => "SavePage"); # old val Save name SavePage
	print qq{</div>};
	}
}

sub serve_wikhistory_page
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $page	= $args->mandate('name');
$args->argok();

my $wikeid = wiki_page_exists(pagename => $page);
if(! defined($wikeid) )
	{
	print "ERROR: Database inconsistency"; # XXX Do something smarter here.
	return;
	}
my @versions = get_all_wikversions_for_wikeid(wikentryid => $wikeid);
print qq{<div id="wikhistory">\n};
print qq{<ul>Versions:\n};
foreach my $wversion (@versions)
	{
	my $version = get_htlink(target => url_wikpage(page_name => $page, version => $$wversion{version}), content => $$wversion{version});
	my $author = $$wversion{author};
	my $authorstring;
	if(defined $author)
		{
		my %ainfo = get_personinfo(uid => $author);
		$authorstring  = get_htlink(target => url_person(login_name => $ainfo{login}), content => $ainfo{name} . ' (' . $ainfo{login} . ')', follow_ok => 1);
		}
	else
		{
		$authorstring = 'Anonymous';
		}

	my $comment = $$wversion{cmt};
	if(! defined($comment)) {$comment = '';}
	print qq{\t<li>Version: $version by $authorstring : $comment\n};
	}
print qq{</ul>\n};
print qq{</div>\n};
}

sub handle_special_pagereq
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $sreq = $args->mandate('special_request');
$args->argok();

if($sreq eq 'Allpages')
	{
	handle_special_allpages();
	}
else
	{
	errorpage(text => "POUNDWiki - Unknown Special Page Requested");
	}
}

sub handle_special_allpages
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

sthtml(title => "POUNDWiki - Special:Allpages", is_public => 1);
my @titles = get_all_page_titles();
print qq{<div id="wikpagename">All pages</div>\n};
print qq{<div id="wikspecial"><ul>\n};
foreach my $title (@titles)
	{
	print "\t<li>" . get_htlink(target => url_wikpage(page_name => $title), content => $title, follow_ok => 1) . "</li>\n";
	}
print "</ul></div>\n";
}

sub normalise_wiki_pagetitle
{ # Review this, especially in light of unicode...
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $pni = $args->mandate('pagename');
$args->argok();

$pni =~ tr/\t\\ \/'`"\(\)/_________/;
$pni =~ s/\s+$//;

return $pni;
}

1;
