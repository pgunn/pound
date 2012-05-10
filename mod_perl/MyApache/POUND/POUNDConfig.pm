#!/usr/bin/perl

# Interface to configuration. Some of these are statically defined, some live in the
# database and are configurable at runtime.

use strict;
use DBI;
package MyApache::POUND::POUNDConfig;

use MyApache::POUND::POUNDDB;
use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDConfigDB;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(get_name_of_host get_url_of_host get_basepath get_sitebase get_blogbase get_blogstatic get_main_blogname doing_frontpage get_wikbase url_to_wikpage entries_per_archpage get_nodebase get_archivebase get_topicbase get_personbase get_notdone wiki_public get_nodereply_submitbase get_blognodereply_submitbase get_loginpage get_catchloginpage get_logoutpage get_cssdir get_sitecss size_xmlfeed get_rssblog get_prefspage get_prefsubmit get_atomblog get_sitecfgpage get_sitecfgpage get_blogcfgpage get_blogcfgsubmitpage get_nentrypage get_edentrypage get_edentrypost get_bannedwords get_postguard_enabled get_newuserpage get_newusersubmit get_blognodereply_base get_blogcommentreply_submitbase get_entry_privtogglebase get_listbase get_manage_topics_page get_manage_topics_submit_page get_del_topics_page get_del_topics_page_post get_files get_manage_files get_upload_file get_ncomicpage get_feedicon get_manage_messages get_manage_messages_ackpage get_add_messages);
our @EXPORT = @EXPORT_OK;

# You will need to edit these three when installing POUND

sub get_basepath()
{ # Leave as static because it MUST match the mod_perl configuration
  # or things won't work. 
return q{pound};
}

sub get_sitecfgpage()
{ # Leave as static as a standard entry point for when people badly configure the site
return q{sitecfg};
}

sub get_sitebase()
{ # Not configurable at runtime
return q{http://localhost};
#return q{http://blog.dachte.org};
}

sub get_name_of_host()
{ # User readable name of host.
return q{Dachte.org};
}

sub get_url_of_host()
{ # Link to hosting site
return q{http://dachte.org};
}

# -----------------


sub get_blogstatic()
{
return get_configkey(keyname => "blogstatic");
#return q{http://localhost}; 
#return q{http://blog.dachte.org};
}

sub get_main_blogname()
{
return get_configkey(keyname => "main_blogname");
}

sub doing_frontpage()
{
return get_configkey(keyname => "doing_frontpage");
}

sub entries_per_archpage()
{
return get_configkey(keyname => "entries_per_archpage");
}

sub wiki_public()
{
return get_configkey(keyname => "wiki_public");
}

sub size_xmlfeed()
{
return get_configkey(keyname => "xmlfeed");
}

sub get_bannedwords
{
return qw/ringtones propecia ultram phentermine fioricet diazepam freewebtown/;
}

sub get_postguard_enabled
{ # POSTs must have same IP as form that generated them. Anti-spam measure
return get_configkey(keyname => "postguard");
}

# -- Pathkeys --

# generic paths

sub get_notdone()
{
return get_pathkey(keyname => "notdonepage");
}

sub get_cssdir()
{ # For the general site css, not for per-blog or for wiki.
  # Note that it is variate depending on user, doing cookie things as needed
return get_pathkey(keyname => "cssdir");
}

sub get_sitecss()
{
return get_pathkey(keyname => "sitecss");
}

# wiki

sub get_wikbase()
{
return get_pathkey(keyname => "wikbase");
}

# blog

sub get_blogbase()
{
return get_pathkey(keyname => "blogbase");
}

sub get_rssblog()
{
return get_pathkey(keyname => "rssblog");
}

sub get_atomblog()
{
return get_pathkey(keyname => "atomblog");
}

sub get_archivebase()
{
return get_pathkey(keyname => "archivebase");
}

sub get_personbase()
{
return get_pathkey(keyname => "personbase");
}

sub get_topicbase()
{
return get_pathkey(keyname => "topicbase");
}

sub get_nodebase
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $nodetype = $args->mandate('nodetype');
$args->argok();

if($nodetype eq 'entry')
	{
	return get_pathkey(keyname => "entbase");
	}
else
	{
	return get_pathkey(keyname => "combase");
	}
}

sub get_blognodereply_base
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $nodetype = $args->mandate('nodetype');
$args->argok();

if($nodetype eq 'entry')
	{
	return get_pathkey(keyname => "blogreply_base");
	}
else
	{
	return get_pathkey(keyname => "blogcommentreply_base");
	}
}

sub get_nodereply_submitbase
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $nodetype = $args->mandate('nodetype');
$args->argok();
if($nodetype eq 'entry')
	{
	return get_pathkey(keyname => "blogreply_submitbase");
	}
else
	{
	return get_pathkey(keyname => "blogcommentreply_submitbase");
	}
}

sub get_listbase()
{
return get_pathkey(keyname => "listbase");
}

# Login/logout

sub get_loginpage()
{
return get_pathkey(keyname => "loginpage");
}

sub get_catchloginpage()
{
return get_pathkey(keyname => "catchloginpage");
}

sub get_logoutpage()
{
return get_pathkey(keyname => "logoutpage");
}

# User prefs

sub get_prefspage()
{
return get_pathkey(keyname => "prefspage");
}

sub get_prefsubmit()
{
return get_pathkey(keyname => "prefsubmit");
}

# Blog configuration

sub get_blogcfgpage()
{
return get_pathkey(keyname => "blogcfgpage");
}

sub get_blogcfgsubmitpage()
{
return get_pathkey(keyname => "blogcfgsubmitpage");
}

sub get_manage_topics_page()
{
return get_pathkey(keyname => "manage_topics");
}

sub get_manage_topics_submit_page()
{
return get_pathkey(keyname => "manage_topics_submit");
}

sub get_del_topics_page()
{
return get_pathkey(keyname => 'del_topics_page');
}

sub get_del_topics_page_post()
{
return get_pathkey(keyname => 'del_topics_page_post');
}

# Managing entries

sub get_nentrypage()
{
return get_pathkey(keyname => "nentrypage");
}

sub get_ncomicpage()
{
return get_pathkey(keyname => "ncomicpage");
}

sub get_edentrypage()
{
return get_pathkey(keyname => "edentrypage");
}

sub get_entry_privtogglebase()
{
return get_pathkey(keyname => "entry_privtogglebase");
}

# New users..

sub get_newuserpage
{
return get_pathkey(keyname => "newuser");
}

sub get_newusersubmit
{
return get_pathkey(keyname => "newusersubmit");
}

# Files

sub get_files()
{
return get_pathkey(keyname => "filebase");
}

sub get_manage_files()
{
return get_pathkey(keyname => "manage_files_base");
}

sub get_upload_file()
{
return get_pathkey(keyname => "upload_files_base");
}

sub get_feedicon()
{
return get_sitebase() . q{/feed-icon-14x14.png};
}

# Messages

sub get_manage_messages
{
return get_pathkey(keyname => "manage_messages");
}

sub get_manage_messages_ackpage
{
return get_pathkey(keyname => 'manage_messages_ackpage');
}

sub get_add_messages()
{
return get_pathkey(keyname => 'add_messages');
}

1;
