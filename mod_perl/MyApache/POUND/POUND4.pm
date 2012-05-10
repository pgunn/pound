#!/usr/bin/perl

use strict;
package MyApache::POUND::POUND4;
use lib qw(/home/pgunn/mod_perl);
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDVersion;
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDCSS;
use MyApache::POUND::POUNDBLOG;
use MyApache::POUND::POUNDWiki;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDAdmin;
use MyApache::POUND::POUNDFeeds;
use MyApache::POUND::POUNDFiles;
use MyApache::POUND::POUNDPerson;
use MyApache::POUND::POUNDBLOGContent;
use MyApache::POUND::POUNDManageFiles;
use MyApache::POUND::POUNDManageMessages;
use POSIX;
use APR::Table;
use Apache2::RequestRec();
use Apache2::RequestIO();
use Apache2::RequestUtil();
use Apache2::Const -compile => qw(:methods OK);

sub handler
{
my ($apache_r) = @_;
$apache_r->content_type('text/html');
my($request, @args) = get_request_from_uri(uri => $apache_r->uri());
dispatch_handler($apache_r, $request, @args);
return Apache2::Const::OK();
}

sub dispatch_handler($@;)
{
my($apache_r, $request, @args) = @_;
# Eventually, get session info and the like here, from cookies and such.
if($request eq get_wikbase() )
	{
	dispatch_wiki(apacheobj => $apache_r, args => \@args);
	}
elsif($request eq "test")
	{
	dispatch_testpage();
	}
elsif($request eq get_notdone() )
	{
	dispatch_notdone();
	}
elsif($request eq get_blogbase() )
	{ # FIX to handle alternate users
	my $blogname = shift(@args); # Which BLOG user wants. 
	if(! defined $blogname) # Maybe should point to a list of blogs instead? Hmm. 
		{
		if(doing_frontpage() )
			{
			dispatch_frontpage(apacheobj => $apache_r); # Not implemented yet!
			return;
			}
		else
			{
			$blogname = get_main_blogname();
			redir(apacheobj => $apache_r, target_page => url_blog(blogname => $blogname) );
			return;
			}
		}
	dispatch_blogmain(apacheobj => $apache_r, blogname => $blogname, req => $request, args => \@args);
	}
elsif($request eq get_loginpage() )
	{
	dispatch_loginpage(apacheobj => $apache_r, args => \@args);
	}
elsif($request eq get_logoutpage() )
	{
	dispatch_logoutpage(apacheobj => $apache_r);
	}
elsif($request eq get_prefspage() )
	{
	dispatch_prefs(apacheobj => $apache_r, args => \@args);
	}
elsif($request eq get_manage_topics_page() )
	{
	my $blogname = shift(@args); # Which BLOG user wants. 
	dispatch_manage_topics(apacheobj => $apache_r, blogname => $blogname, args => \@args);
	}
elsif($request eq get_manage_topics_submit_page() )
	{
	dispatch_manage_topics_submit(apacheobj => $apache_r);
	}
elsif($request eq get_del_topics_page() )
	{
	my $blogname = shift(@args); # Which BLOG user wants. 
	my $topic = shift(@args); # Which topic user wants (well, really, doesn't want, haha)
	dispatch_del_topic(apacheobj => $apache_r, blogname => $blogname, topic => $topic);
	}
elsif($request eq get_del_topics_page_post() )
	{
	my $blogname = shift(@args); # Which BLOG user wants. 
	my $topic = shift(@args); # Which topic user wants (TODO: refactor above joke to apply here too)
	dispatch_del_topic_submit(apacheobj => $apache_r, blogname => $blogname, topic => $topic);
	}

elsif($request eq get_cssdir() ) 
	{
	dispatch_csspage(apacheobj => $apache_r);
	}
elsif($request eq get_rssblog() )
	{
	my $blogname = shift(@args);
	dispatch_feed(apacheobj => $apache_r, feed_type => 'rss', blogname => $blogname);
	}
elsif($request eq get_atomblog() )
	{
	my $blogname = shift(@args);
	dispatch_feed(apacheobj => $apache_r, feed_type => 'atom', blogname => $blogname);
	}
elsif($request eq get_files() )
	{
	dispatch_file(apacheobj => $apache_r, pathparts => \@args); # Parsing this is too complex to neatly be done here
	}
elsif($request eq get_sitecfgpage() )
	{
	dispatch_sitecfg(apacheobj => $apache_r, args => \@args);
	}
elsif($request eq get_personbase() )
	{
	my $person = shift(@args);
	dispatch_person(apacheobj => $apache_r, person => $person);
	}
elsif($request eq get_blogcfgpage() )
	{
	my $blogname = shift(@args); # Which BLOG user wants. 
	dispatch_blogcfg(apacheobj => $apache_r, blogname => $blogname, args => \@args);
	}
elsif($request eq get_blogcfgsubmitpage() )
	{
	dispatch_blogcfgsubmit(apacheobj => $apache_r);
	}
elsif($request eq get_newuserpage() )
	{
	dispatch_newuser(apacheobj => $apache_r, args => \@args);
	}
elsif($request eq get_manage_files() )
	{
	dispatch_manage_files(apacheobj => $apache_r, args => \@args);
	}
elsif($request eq get_upload_file() )
	{
	dispatch_upload_file(apacheobj => $apache_r, args => \@args);
	}
elsif($request eq get_manage_messages() )
	{
	dispatch_managemessages(apacheobj => $apache_r, args => \@args);
	}
else
	{ # If you don't specify a user, either point to a frontpage or
	# to a specific user's BLOG.
	if(doing_frontpage() )
		{
		dispatch_frontpage(apacheobj => $apache_r); # Not implemented yet!
		}
	else
		{
		redir(apacheobj => $apache_r, target_page => url_blogbase() );
		return;
		}
	}
}

sub dispatch_testpage
{
sthtml(title => "Test Page");
print "\n<hr>\n";
print "POUND Major version 4, minor version " . poundversion();
endhtml();
}

1;

