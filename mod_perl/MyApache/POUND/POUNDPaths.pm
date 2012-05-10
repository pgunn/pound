#!/usr/bin/perl

# Generic path handling code
use strict;
use DBI;
package MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::Argpass;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(url_wikpage url_blog url_blogbase url_archpage url_nodepage url_archpage url_topic url_elist url_person url_notdone url_wikedit_submit url_nodereply_submit url_ent_reply_page url_com_reply_page url_loginpage url_catchloginpage url_mainpage url_logoutpage url_sitecss url_prefs url_prefsubmit url_blogrss url_sitecfg url_blogcfg url_blogcfg_submit url_blogatom url_wiki url_nentrypage url_nentrypost url_edentrypage url_edentrypost url_newuser url_newusersubmit url_node_reply_page url_entry_toggle_private url_manage_topics url_manage_topics_submit url_topic_edit url_delete_topic url_delete_topic_post url_filebase url_manage_files url_upload_file url_ncomicpage url_ncomicpost url_pounddistro url_manage_messages url_add_messages);
our @EXPORT = @EXPORT_OK;

sub url_wiki()
{
return join('/', get_sitebase(), get_basepath()
	, get_wikbase() );
}

sub url_wikpage
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $pname 	= $args->mandate('page_name');
my $pver	= $args->accept('version', undef);
$args->argok();

if(! defined($pver))
	{
	return join('/', get_sitebase(), get_basepath()
		, get_wikbase()
		, $pname); 
	}
else
	{
	return join('/', get_sitebase(), get_basepath()
		, get_wikbase()
		, $pname
		, q{version}
		, $pver); 
	}
}

sub url_blogbase()
{
return join('/', get_sitebase(), get_basepath()
	, get_blogbase() );
}

sub url_blog
{ # Pass in name of blog
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogname	= $args->mandate('blogname');
$args->argok();

return join('/', url_blogbase(), $blogname);
}

sub url_blogrss
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogname	= $args->mandate('blogname');
$args->argok();

return join('/', get_sitebase(), get_basepath(),
	get_rssblog(), $blogname);
}

sub url_blogatom
{ # Pass in name of BLOG
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogname	= $args->mandate('blogname');
$args->argok();

return join('/', get_sitebase(), get_basepath(),
	get_atomblog(), $blogname);
}

sub url_archpage
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogname	= $args->mandate('blogname');
my $archpage	= $args->mandate('page');
$args->argok();


return join('/', url_blog(blogname => $blogname),
	get_archivebase(), 'page' . $archpage . '.html');
}

sub url_nodepage
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogname	= $args->mandate('blogname');
my $nodeid	= $args->mandate('nodezeit');
my $nodetype	= $args->mandate('nodetype');
$args->argok();

return join('/', url_blog(blogname => $blogname),
	get_nodebase(nodetype => $nodetype), $nodetype . $nodeid . '.html');
}

sub url_node_reply_page
{ # Syntax is ($blogname, $entry)
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogname	= $args->mandate('blogname');
my $node	= $args->mandate('node');
my $nodetype	= $args->mandate('nodetype');
$args->argok();

return join('/',
	url_blog(blogname => $blogname),
	get_blognodereply_base(nodetype => $nodetype),
	$nodetype . $node . '.html');
}

sub url_topic
{ # XXX: Maybe would be good to translate spaces to underscores here?
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname	= $args->mandate('blogname');
my $tname	= $args->mandate('topicname');
$args->argok();

return join('/', url_blog(blogname => $bname),
	get_topicbase(), $tname . '.html');
}

sub url_elist
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname	= $args->mandate('blogname');
$args->argok();

return join('/', url_blog(blogname => $bname),
	get_listbase() );
}

sub url_person
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $lname = $args->mandate('login_name');
$args->argok();

return join('/', get_sitebase(),
	get_basepath(), get_personbase(), $lname . '.html');
}

sub url_notdone()
{
return join('/', get_sitebase(), get_basepath(), get_notdone());
}

sub url_wikedit_submit
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $pname 	= $args->mandate('page_name');
$args->argok();

return join('/', get_sitebase(), get_basepath()
	, get_wikbase()
	, $pname, 'edit', 'post'); 
}

sub url_nodereply_submit
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogname = $args->mandate('blogname');
my $nodetype = $args->mandate('nodetype');
$args->argok();

return join('/', url_blogbase(), $blogname, get_nodereply_submitbase(nodetype => $nodetype) );
}

sub url_loginpage()
{
return join('/', get_sitebase(), get_basepath(), get_loginpage() );
}

sub url_logoutpage()
{
return join('/', get_sitebase(), get_basepath(), get_logoutpage() );
}

sub url_catchloginpage()
{
return join('/', get_sitebase(), get_basepath(), get_loginpage(), 'post');
}

sub url_mainpage()
{
return join('/', get_sitebase(), get_basepath());
}

sub url_sitecss()
{
return join('/', get_sitebase(), get_basepath(), get_cssdir(), get_sitecss() );
}

sub url_prefs()
{
return join('/', get_sitebase(), get_basepath(), get_prefspage() );
}

sub url_prefsubmit()
{
return join('/', get_sitebase(), get_basepath(), get_prefspage(), 'post' );
}

sub url_manage_topics
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
$args->argok();

return join('/', get_sitebase(), get_basepath(), get_manage_topics_page(), $bname );
}

sub url_topic_edit
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
my $tname = $args->mandate('topicname');
$args->argok();

return join('/', get_sitebase(), get_basepath(), get_manage_topics_page(), $bname, $tname);
}

sub url_manage_topics_submit()
{
return join('/', get_sitebase(), get_basepath(), get_manage_topics_submit_page() );
}


sub url_delete_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
my $tname = $args->mandate('topicname');
$args->argok();

return join('/', get_sitebase(), get_basepath(), get_del_topics_page(), $bname, $tname);
}

sub url_delete_topic_post
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
my $tname = $args->mandate('topicname');
$args->argok();

return join('/', get_sitebase(), get_basepath(), get_del_topics_page_post(), $bname, $tname);
}

sub url_sitecfg()
{
return join('/', get_sitebase(), get_basepath(), get_sitecfgpage() );
}

sub url_blogcfg
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
$args->argok();

return join('/', get_sitebase(), get_basepath(), get_blogcfgpage(), $bname);
}

sub url_blogcfg_submit
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
$args->argok();

return join('/', get_sitebase(), get_basepath(), get_blogcfgpage(), $bname, 'post');
}

sub url_nentrypage
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
$args->argok();

return join('/', url_blogbase(), $bname, get_nentrypage() );
}

sub url_nentrypost
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
$args->argok();

return join('/', url_blogbase(), $bname, get_nentrypage(), 'post' );
}

sub url_ncomicpage
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
$args->argok();

return join('/', url_blogbase(), $bname, get_ncomicpage() );
}

sub url_ncomicpost
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname = $args->mandate('blogname');
$args->argok();

return join('/', url_blogbase(), $bname, get_ncomicpage(), 'post' );
}



sub url_edentrypage
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname	= $args->mandate('blogname');
my $zeit	= $args->mandate('entryzeit');
$args->argok();

return join('/', url_blogbase(), $bname, get_edentrypage(), $zeit);
}

sub url_entry_toggle_private
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname	= $args->mandate('blogname');
my $zeit	= $args->mandate('entryzeit');
my $priv	= $args->mandate('to_private');
$args->argok();

return join('/', url_blogbase(), $bname, get_entry_privtogglebase(), $priv, $zeit);
}

sub url_edentrypost
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bname	= $args->mandate('blogname');
my $zeit	= $args->mandate('entryzeit');
$args->argok();
return join('/', url_blogbase(), $bname, get_edentrypage(), $zeit, 'post');
}

sub url_newuser()
{
return join('/', get_sitebase(), get_basepath(), get_newuserpage() );
}

sub url_newusersubmit()
{
return join('/', get_sitebase(), get_basepath(), get_newuserpage(), 'post');
}

sub url_filebase()
{
return join('/', get_sitebase(), get_basepath(), get_files() );
}

sub url_manage_files()
{
return join('/', get_sitebase(), get_basepath(), get_manage_files() );
}

sub url_upload_file()
{
return join('/', get_sitebase(), get_basepath(), get_upload_file() );
}

sub url_pounddistro()
{
return qq{http://dachte.org/tech/code/POUND-29nov2008.tar.bz2};
}

sub url_manage_messages()
{
return join('/', get_sitebase, get_basepath(), get_manage_messages() );
}

sub url_add_messages()
{
return join('/', get_sitebase, get_basepath(), get_manage_messages(), get_add_messages() );
}

1;
