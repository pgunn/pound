#!/usr/bin/perl

# Administrative functions and login stuff. Is allowed to talk to database,
# but prefers not to. Is also allowed to talk HTML, and is ok with that.
# Also handles user prefs

use strict;
use DBI;
package MyApache::POUND::POUNDAdmin;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDThemes;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::POUNDBLOGDB;
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDCSS;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDSession;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDForms;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDConfigDB;
use Apache2::Const -compile => qw(:methods);

require Exporter;
require AutoLoader;

# Admin-type functions. Includes making new accounts and altering prefs on existing accounts

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_loginpage dispatch_catchloginpage dispatch_logoutpage dispatch_prefs dispatch_prefsubmit dispatch_sitecfg dispatch_blogcfg dispatch_blogcfgsubmit dispatch_newuser dispatch_newusersubmit dispatch_manage_topics dispatch_manage_topics_submit dispatch_del_topic dispatch_del_topic_submit);
our @EXPORT = @EXPORT_OK;

sub dispatch_loginpage
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $reqargs	= $args->mandate('args');
$args->argok();

if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST", 0);
		return;
		}
	my %post = post_content(apacheobj => $apache_r);
	foreach my $key (keys %post)
		{$post{$key} = de_post_mangle(post_in => $post{$key});}
	my $user = $post{user};
	my $pass = $post{pass};
	if(! (defined($user) && defined($pass)))
		{
		errorpage(text => "Login attempt failed: POST missing data");
		return;
		}
	if(login_match(user => $user, pass => $pass))
		{
		create_session(apacheobj => $apache_r, userid => uid_from_login(login => $user));
		my $mainpage = url_mainpage();
		msgpage(text => "Login Successful", url => $mainpage);
		}
	else
		{
		my $loginpage = url_loginpage();
		msgpage(text => "Login Failed", url => $loginpage);
		}
	}
else
	{ # It's the form
	sthtml(title => "Login Page");
	my $catchloginurl = url_catchloginpage();
	stform(submit_url => $catchloginurl, formid => "loginform"); # XXX Too much trouble to use validator here, I think
	form_txtfield(caption => "Login", name => 'user', size => 10, max_length => 30);
	form_privtxtfield(caption => "Pass", name => 'pass', size => 10, max_length => 30);
	endform(submit => "Login");
	endhtml();
	}
}

sub dispatch_logoutpage
{ # XXX As of right now, there are no security issues with external sites link-forcing
	# users to log out. If it becomes an issue (or the following becomes easy),
	# make it a form and guard it.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);
if(! defined($uid))
	{
	my $mainpage = url_mainpage();
	sthtml(title => "Logout");
	print "<div style=\"background:white;color:black;\">Logged out. Click " . get_htlink(target => $mainpage, content => 'here', follow_ok => 1) . " to continue.</div>\n";
	}
else
	{
	session_logout(apacheobj => $apache_r);
	my $mainpage = url_mainpage();
	sthtml(title => "Logout");
	my $user_name = login_from_uid(uid => $uid);
	print "<div style=\"background:white;color:black;\">Logged $user_name out. Click " . get_htlink(target => $mainpage, content => 'here', follow_ok => 1) . " to continue.</div>\n";
	}
}

sub dispatch_prefs
{ # Maybe display but don't let user change theme here, letting user know to change it on
  # the main page. Also note that this can be made much prettier with DIVs
  # Be sure to validate any new added values to be display safe to avoid security problems.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
my $reqargs	= $args->mandate('args');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);
if(! defined $uid)
	{dispatch_anonprefs(apacheobj => $apache_r, args => $reqargs);return;} # anonymous user setting theme
if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST", 0);
		return;
		}
	my %post = post_content(apacheobj => $apache_r);
	if($post{validcode} ne apache_session_key(apacheobj => $apache_r))
		{
		errorpage(text => 'BAD POST: Foreign source? Failed security check');
		return;
		}
	if(defined $post{personname})
		{
		uid_set_name(	userid => $uid,
				name => html_purge(data => de_post_mangle(post_in => $post{personname})));
		}
	if(defined $post{weburl})
		{ # XXX I am somewhat concerned about this functionality.
		uid_set_weburl(	userid => $uid,
				web_url => html_purge(data => de_post_mangle(post_in => $post{weburl})));
		}
	if(defined $post{descrip})
		{
		uid_set_descrip(userid => $uid,
				description => html_purge(data => de_post_mangle(post_in => $post{descrip})));
		}
	if((defined $post{pass}) && ($post{pass} ne '') )
		{
		uid_set_pass(	userid => $uid,
				password => de_post_mangle(post_in => $post{pass}) );
		}
	if( (defined $post{theme}) && ($post{theme} ne 'nochange') )
		{
		uid_set_theme(	userid => $uid,
				theme => de_post_mangle(post_in => $post{theme}));
		}
	msgpage(text => "Prefs set", url => get_htlink(url_blogbase() ));
	}
else
	{
	my %person = get_personinfo(uid => $uid);
	my $submiturl = url_prefsubmit();
	
	# XXX Need to think about if picurl should be exposed here or not.
	sthtml(title => "User Prefs - $person{login}");
	print "<div style=\"background:white;color:black;\"><b>User Prefs - $person{login}</b><hr />\n";
	stform(submit_url => $submiturl, formid => 'prefsform', validator => apache_session_key(apacheobj => $apache_r) );
	form_txtfield(caption => 'Name', name => 'personname', size => 20, value => $person{name});
	form_txtfield(caption => 'URL', name => 'weburl', size => 20, value => $person{weburl});
	form_txtarea(caption => 'Description', name => 'descrip', cols => 75, rows => 4, value => $person{descrip});
	form_privtxtfield(caption => 'Password', name => 'pass', size => 20);
	stselect(caption => 'Theme', name => 'theme', default => 'No Change');
	addselect(value => 0, text => "Default Theme");
	my @themes = get_all_themeids();
	foreach my $tid (@themes)
		{
		addselect(value => $tid, text => theme_name(themeid => $tid));
		}
	endselect();
	endform(submit => 'Save');
	
	if(uid_is_super(userid => $uid))
		{
		print "<br /><br /><hr />\n";
		print get_htlink(target => url_sitecfg(), content => "Configure this site");
		}
	print "</div>\n";
	endhtml();
	}
}

sub dispatch_anonprefs
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
my $reqargs	= $args->mandate('args');
$args->argok();

if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST", 0);
		return;
		}
	my %post = post_content(apacheobj => $apache_r);
	if( (defined $post{theme}) && ($post{theme} ne 'nochange') )
		{
		set_cookie(apacheobj => $apache_r, cookiename => 'theme', value => $post{theme});
		}
	my $ppg = url_blogbase();
	sthtml(title => "Prefs set");
	print "<div style=\"background:white;color:black;\">Prefs set. Click " . get_htlink(target => $ppg, content => 'here') . " to continue.</div>\n";
	endhtml();
	}
else
	{
	sthtml(title => "User Prefs - Anonymous");
	my $submiturl = url_prefsubmit();
	print "<div style=\"background:white;color:black;\">";
	stform(submit_url => $submiturl, formid => 'prefsform');
	stselect(caption => 'Theme', name => 'theme', default => 'No Change');
	addselect(value => 0, text => "Default Theme");
	my @themes = get_all_themeids();
	foreach my $tid (@themes)
		{
		addselect(value => $tid, text => theme_name(themeid => $tid));
		}
	endselect();
	endform(submit => 'Save');
	print "</div>\n";
	endhtml();
	}
}

sub dispatch_sitecfg
{ # TODO: Finish implementing
	# 1) Provide interface to edit all keys in the 'config' and 'pathconfig' tables - DONE
	# 2) Manage CSS themes
	# 3) Bypass access restrictions to edit other accounts (posts, reset CSS to known good values, make superuser, validate user, etc)
	# 4) Have other security toggles (e.g. allow users to replace strings or not)
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
my $fargs = $args->mandate('args');
$args->argok();
my $uid = session_uid(apacheobj => $apache_r);

$apache_r->content_type('text/html');
if(! defined $uid)
	{ # Handle no uid
	errorpage(text => "You're not logged in");
	return;
	}
if(! uid_is_super(userid => $uid))
        { # Handle mismatch
        errorpage(text => "You do not have privileges to edit the site config");
        return;
        }
if(! @$fargs)
	{ # Provide the frontpage for sitecfg
	sthtml(title => "POUND Site Administration", no_css => 1);
	print qq{<h1>Pound Site Administration</h1>\n};
	my %stuff = (
			"Manage flags/values"	=> 		join('/', url_sitecfg(), 'manage_keys'),
			"Manage paths"		=> 		join('/', url_sitecfg(), 'manage_paths'),
			"Manage Themes"		=>		join('/', url_sitecfg(), 'manage_css'),
			"Manage Users"		=>		join('/', url_sitecfg(), 'manage_users'),
			"Manage Global Settings"=>		join('/', url_sitecfg(), 'manage_global_settings'),
			);
	print qq{<ul>} .
		join('',
			map	{ # Just a list...
				qq{<li>}
				. get_htlink(content => $_, target => $stuff{$_})
				. qq{</li>\n}
				} keys %stuff
			)
		. qq{</ul>\n};
	endhtml();
	return;
	}
my $sitecfgpage = shift @$fargs;
if($sitecfgpage eq 'manage_keys')
	{subdispatch_admin_keys(apacheobj => $apache_r, args => $fargs);return;}
elsif($sitecfgpage eq 'manage_keys_post')
	{subdispatch_admin_keys_post(apacheobj => $apache_r);return;}
if($sitecfgpage eq 'manage_paths')
	{subdispatch_admin_paths(apacheobj => $apache_r, args => $fargs);return;}
elsif($sitecfgpage eq 'manage_paths_post')
	{subdispatch_admin_paths_post(apacheobj => $apache_r); return;}
elsif($sitecfgpage eq 'manage_css')
	{subdispatch_admin_manage_css(apacheobj => $apache_r); return;}
elsif($sitecfgpage eq 'manage_css_post')
	{subdispatch_admin_manage_css_post(apacheobj => $apache_r); return;}
elsif($sitecfgpage eq 'manage_users')
	{subdispatch_admin_manage_users(apacheobj => $apache_r); return;}
elsif($sitecfgpage eq 'manage_users_post')
	{subdispatch_admin_manage_users_post(apacheobj => $apache_r); return;}
elsif($sitecfgpage eq 'manage_global_settings')
	{subdispatch_admin_manage_global_settings(apacheobj => $apache_r); return;}
elsif($sitecfgpage eq 'manage_global_settings_post')
	{subdispatch_admin_manage_global_settings_post(apacheobj => $apache_r); return;}
}

sub dispatch_blogcfg
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $blogname	= $args->mandate('blogname');
my $reqargs	= $args->mandate('args');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);
if(! defined $uid)
	{ # Handle no uid
	errorpage(text => "No uid");
	return;
	}
my $bid = blogid_for_blogname(blogname  => $blogname);
if(! defined($bid))
	{errorpage(text => "No such blog");return;}
my %blogcfg = get_blogcfg(blogid => $bid);
	
if($blogcfg{author} != $uid)
	{ # Handle mismatch
	errorpage(text => "You cannot edit blogs that are not yours");
	return;
	}

if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{
	if(! is_POST(apacheobj => $apache_r) )
		{
		errorpage(text => "BAD POST: Not a POST", 0);
		return;
		}
	my %postdata = post_content(apacheobj => $apache_r);
	if($postdata{validcode} ne apache_session_key(apacheobj => $apache_r))
		{
		errorpage(text => 'BAD POST: Foreign source? Failed security check');
		return;
		}
	if(0 == scalar(keys %postdata))
		{
		errorpage(text => "BAD POST: empty data", 0);
		return;
		}
	foreach my $toclean (qw{blogid title anon_comments comments header_extra blogimg tname turl tdesc})
		{
		if(defined($postdata{$toclean}))
			{$postdata{$toclean} = de_post_mangle(post_in => $postdata{$toclean});}
		}
	
	
	if($postdata{blogcfg_type} eq "basic")
		{
		$postdata{anon_comments} = ($postdata{anon_comments}?1:0); # Yay lame-o interfaces
		$postdata{comments} = ($postdata{comments}?1:0); # Ditto
		blog_set_title(blogid => $blogcfg{id}, title => $postdata{title});
		blog_set_anon_and_comments(
			blogid => $blogcfg{id},
			allow_anon_comments => $postdata{anon_comments},
			allow_comments => $postdata{comments});
	
		blog_set_header_extra(blogid => $blogcfg{id}, header_extra => $postdata{header_extra});
		blog_set_blogimg(blogid => $blogcfg{id}, image_url => $postdata{blogimg});
		}
	else
		{
		errorpage(text => "Invalid post type for blog config");
		return;
		}
	sthtml(title => "BLOG Configuration Submission");
	my $blogurl = url_blog(blogname => $blogcfg{name});
	print qq{<div class="formcaption">Changes submitted. Click <a href="$blogurl">here</a> to continue.</div>\n};
	endhtml();
	}
else
	{
	$apache_r->content_type('text/html');
	
	my $submiturl = url_blogcfg_submit(blogname => $blogname);
	my @topics = get_all_topics_for_blog(blogid => $blogcfg{id}); # Use get_topic_by_id to get names and other fields
	sthtml(title => "Blog Prefs - $blogcfg{name}");
	print "<div style=\"background:white;color:black;\"><b>BLOG Prefs - $blogcfg{name}</b><hr />\n";
	stform(submit_url => $submiturl, formid => 'blogcfgform', validator => apache_session_key(apacheobj => $apache_r) );
	form_hidden(name => "blogcfg_type", value => "basic");
	form_hidden(name => "blogid", value => $blogcfg{id});
	form_txtfield(caption => "Title", name => "title", size => 50, value => $blogcfg{title}, max_length => 50);
	form_checkbox(caption => "Allow Comments", name => "comments", default => $blogcfg{comments});
	print "<br />\n";
	form_checkbox(caption => "Allow Anon Comments", name => "anon_comments", default => $blogcfg{anon_comments});
	print "<br />\n";
	form_txtarea(caption => "Header Extra HTML (be careful)", name => "header_extra", value => $blogcfg{header_extra});
	form_txtfield(caption => "Image URL", name => "blogimg", size => 50, value => $blogcfg{blogimg}, max_length => 100);
		# FIXME build interface for LJ at some point
	endform(submit => 'Save');
	
	print "<hr /><h1>OR</h1>\n";
	print get_htlink(target => url_manage_topics(blogname => $blogcfg{name}), content => "Manage Topics");
	}
}

sub dispatch_newuser
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $reqargs	= $args->mandate('args');
$args->argok();

if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST", html_started => 0);
		return;
		}
	my %postdata = post_content(apacheobj => $apache_r);
	if(0 == scalar(keys %postdata))
		{
		errorpage(text => "BAD POST: empty data");
		return;
		}
	foreach my $toclean (qw{personname weburl descrip newlogin newpass clientip})
		{
		if(defined($postdata{$toclean}))
			{$postdata{$toclean} = de_post_mangle(post_in => $postdata{$toclean});}
		}
	# Steps:
	# 1) Make sure form IP = submit IP (anti-spam measure)
	# 2) Make sure that the username is both kosher and not already used
	# 3) Make account (but leave it invalidated)
	my $sourceip = get_client_ip(apacheobj => $apache_r);
	if(($sourceip != $postdata{clientip}) && get_postguard_enabled() )
		{
		errorpage(text => "Bad registration attempt: source IP address differs between form and submit. Proxy pools (e.g. AOL) cannot presently use this registration system. Email the site maintainer for manual registration.");
		return;
		}
	my $login = $postdata{newlogin};
	if($login !~ /^[a-z][a-z0-9]{3,29}$/)
		{
		errorpage(text => "Bad registration attempt: login not acceptable\n");
		return;
		}
	if(uid_from_login(login => $login, validated_only => 0))
		{
		errorpage(text => "Bad registration attempt: login already taken\n");
		return;
		}
	my ($ok,$r) = make_account(
				name => $postdata{personname},
				weburl => $postdata{weburl},
				descrip => $postdata{descrip},
				login => $login,
				pass => $postdata{newpass}
				);
	if($ok)
		{ # FIXME Use msgpage()
		sthtml(title => "Account made");
		print "Account made - please allow a day or so for validation\n"; # TODO More?
		return;
		}
	else
		{ # FIXME Use msgpage(), also maybe give some kind of helpful error?
		sthtml(title => "Account made");
		print "Creation failed: Please contact the admin\n";
		return;
		}
	}
else
	{
	sthtml(title => "New User Form");
	print "<h1>New User</h1>\n";
	print "<hr />\n";
	my $sourceip = get_client_ip(apacheobj => $apache_r);
	
	my $submiturl = url_newusersubmit();
	stform(submit_url => $submiturl, formid => 'newuserform');
	form_txtfield(caption => 'Name', name => 'personname', size => 20);
	form_txtfield(caption => 'URL', name => 'weburl', size => 20);
	form_txtarea(caption => 'Description', name => 'descrip', cols => 75, rows => 4);
	form_txtfield(caption => 'Login', name => 'newlogin', size => 30);
	form_privtxtfield(caption => 'Password', name => 'newpass', size => 20);
	form_hidden(name => "clientip", value => $sourceip);
	endform(submit => 'Submit');
	print "<hr />\n";
	print "Logins should be lower-case alphanumeric and start with a letter.<br />\n";
	print "Please allow time for your submission to be approved. Until then, you will not be able to log in. Please also do not use a password you use for any other service.";
	endhtml();
	}
}

sub dispatch_manage_topics
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $blogname	= $args->mandate('blogname');
my $reqargs	= $args->mandate('args');
$args->argok();

$apache_r->content_type('text/html');
my $uid = session_uid(apacheobj => $apache_r);
my %blogcfg;

	{my $bid = blogid_for_blogname(blogname  => $blogname); if(! defined($bid)) {errorpage(text => "No such blog");return;} %blogcfg = get_blogcfg(blogid => $bid); } # Incantation to fill in blogcfg

my $submiturl = url_manage_topics_submit();
if(! defined $uid)
	{ # Handle no uid
	errorpage(text => "No uid");
	return;
	}
if($blogcfg{author} != $uid)
	{ # Handle mismatch
	errorpage(text => "You cannot configure blogs that are not yours");
	return;
	}

my @topics = get_all_topics_for_blog(blogid => $blogcfg{id});

if(! @$reqargs) # XXX Consider making both branches here subroutines
	{ # Not asked to edit a specific topic, so provide toplevel menu
	sthtml(title => "Blog Topic Management - $blogcfg{name}");
	print "<div style=\"background:white;color:black;\"><b>BLOG Topic Management- $blogcfg{name}</b><hr />\n";

# -----------------------------------------------------------------
	print "Let's make a new topic for this blog!<br />\n";
	stform(submit_url => $submiturl, formid => 'blogcfg_addtopic', validator => apache_session_key(apacheobj => $apache_r) );
	form_hidden(name => "blogcfg_type", value => "newtopic");
	form_txtfield(caption => 'Topic Name', name => 'tname', size => 20, max_length => 20);
	form_txtfield(caption => 'Topic Image URL', name => 'turl', size => 50, max_length => 100);
	form_txtarea(caption => 'Topic Description', name => 'tdesc');
	form_hidden(name => "blogid", value => $blogcfg{id});
	endform(submit => 'Add');

# -----------------------------------------------------------------
	print "<hr /><h1>OR</h1>\n";
	print "Let's list topics for this blog and let you modify/delete them!<br />\n";
	print "<b>This bit isn't done yet</b><br />\n";
	print "<ul>\n";

	map	{
		my %tinfo = get_topic_by_id(topicid => $_);
		my $numposts = scalar(get_entries_with_topicid(topicid => $_));
		print "\t<li>$tinfo{name} ($numposts) - "
			. get_htlink(	target => url_topic(blogname => $blogcfg{name}, topicname => $tinfo{name}),
					content => "view" )
			. '/'
			. get_htlink(	target => url_topic_edit(blogname => $blogcfg{name}, topicname => $tinfo{name}),
					content => 'edit' ) 
			. '/'
			. get_htlink(	target => url_delete_topic(blogname => $blogcfg{name}, topicname => $tinfo{name}),
					content => 'delete')
			. "</li>\n"
		} @topics;
	print "</ul>\n";
	}
else
	{
	my $topic = shift(@$reqargs);
	sthtml(title => "Blog Topic Management - $blogcfg{name} - $topic");
	if(! grep {$_ eq $topic} map {my %tmp = get_topic_by_id(topicid => $_); $tmp{name} } @topics)
		{errorpage(text => "Asked to edit nonexistant topic $topic in blog $blogcfg{name}"); return;}
	print "<div style=\"background:white;color:black;\"><h1>Editing topic $topic</h1>\n";
	my %tinfo = get_topic_by_id(topicid => 
					get_topicid_for_topic(topicname => $topic, blogid => blogid_for_blogname(blogname => $blogcfg{name}))
					);
	stform(submit_url => $submiturl, formid => 'blogcfg_modtopic', validator => apache_session_key(apacheobj => $apache_r) ); # The same as above, with existing values as defaults
	form_hidden(name => "blogcfg_type", value => 'modtopic');
	form_txtfield(caption => 'Topic Name', name => 'tname', size => 20, max_length => 20, value => $tinfo{name});
	form_txtfield(caption => 'Topic Image URL', name => 'turl', size => 50, max_length => 100, value => $tinfo{imgurl});
	form_txtarea(caption => 'Topic Description', name => 'tdesc', value => $tinfo{descrip});
	form_hidden(name => "blogid", value => $blogcfg{id});
	form_hidden(name => "tname_old", value => $topic); # This lets people rename their topic.
	endform(submit => 'Modify');
	print qq{</div>\n};
	}
}

sub dispatch_manage_topics_submit
{ # 2 modes (blogcfg_type)
	# 1) newtopic (blogid=number,tname=stirng, turl=url,tdesc=string)
	# 2) modtopic (not fully defined yet)
	# FIXME Not done yet
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

if(! is_POST(apacheobj => $apache_r) )
	{
	errorpage(text => "BAD POST: Not a POST", 0);
	return;
	}
my $uid = session_uid(apacheobj => $apache_r);
my %postdata = post_content(apacheobj => $apache_r);
if(0 == scalar(keys %postdata))
	{
	errorpage(text => "BAD POST: empty data", 0);
	return;
	}
foreach my $toclean (qw{blogid title anon_comments comments header_extra blogimg tname turl tdesc tname_old})
	{
	if(defined($postdata{$toclean}))
		{$postdata{$toclean} = de_post_mangle(post_in => $postdata{$toclean});}
	}

my %blogcfg = get_blogcfg(blogid => $postdata{blogid});

if(! defined $uid)
	{ # Handle no uid
	errorpage(text => "No uid");
	return;
	}
if($blogcfg{author} != $uid)
	{ # Handle mismatch
	errorpage(text => "You cannot edit blogs that are not yours");
	return;
	}
elsif($postdata{blogcfg_type} eq "newtopic")
	{ # tname, turl, tdesc
	if(topic_exists(blogid => $blogcfg{id}, topicname => $postdata{tname}) )
		{errorpage(text => "Topic $blogcfg{tname} already exists!\n");}
	elsif( ($postdata{tname} eq "") || ($postdata{tname} =~ /[><&]+/))
		{errorpage(text => "Invalid characters in topic.");return;} # FIXME be more strict
	blog_add_topic(	blogid => $blogcfg{id},
			topic_name => $postdata{tname},
			topic_url => $postdata{turl},
			topic_desc => $postdata{tdesc});
	}
elsif($postdata{blogcfg_type} eq "modtopic")
	{ # tname, turl, tdesc, tname_old
	if(! topic_exists(blogid => $blogcfg{id}, topicname => $postdata{tname_old}) )
		{errorpage(text => "Topic $blogcfg{tname_old} does not exist, cannot modify nonexistent topics!\n");}
	elsif( ($postdata{tname} eq "") || ($postdata{tname} =~ /[><&]+/))
		{errorpage(text => "Invalid characters in topic.");return;} # FIXME be more strict
	blog_mod_topic(	blogid => $blogcfg{id},
			topic_name => $postdata{tname},
			topicid	=> get_topicid_for_topic(topicname => $postdata{tname_old}, blogid => $blogcfg{id}), 
			topic_url => $postdata{turl},
			topic_desc => $postdata{tdesc});
	}
else
	{
	errorpage(text => "Invalid post type for blog config");
	return;
	}
sthtml(title => "BLOG Configuration Submission");
my $blogurl = url_blog(blogname => $blogcfg{name});
print qq{<div class="formcaption">Changes submitted. Click <a href="$blogurl">here</a> to continue.</div>\n};
endhtml();
}

sub dispatch_del_topic
{ # Are you sure? You will remove this topic from these entries....
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $blogname	= $args->mandate('blogname');
my $topic	= $args->mandate('topic');
$args->argok();

$apache_r->content_type('text/html');
my $uid = session_uid(apacheobj => $apache_r);
my %blogcfg;

	{my $bid = blogid_for_blogname(blogname  => $blogname); if(! defined($bid)) {errorpage(text => "No such blog");return;} %blogcfg = get_blogcfg(blogid => $bid); } # Incantation to fill in blogcfg

if(! defined $uid)
	{ # Handle no uid
	errorpage(text => "No uid");
	return;
	}
if($blogcfg{author} != $uid)
	{ # Handle mismatch
	errorpage(text => "You cannot configure blogs that are not yours");
	return;
	}
my %topicinfo = get_topic_by_id(topicid => get_topicid_for_topic(topicname => $topic, blogid => $blogcfg{id}));
my $numposts = scalar(get_entries_with_topicid(topicid => $topicinfo{id}));
print "<div style=\"background:white;color:black;\"><b>BLOG Topic Management- $blogcfg{name} - Delete $topic</b><hr />\n";
print "This topic has $numposts entries. Deletion will remove this topic from all those entries.<br />\n";
print get_htlink(target => url_delete_topic_post(blogname => $blogname, topicname => $topic), content => "Confirm", follow_ok => 0);
print "</div>";
endhtml();
}

sub dispatch_del_topic_submit
{ # Actually do it...
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $blogname	= $args->mandate('blogname');
my $topic	= $args->mandate('topic');
$args->argok();

$apache_r->content_type('text/html');
my $uid = session_uid(apacheobj => $apache_r);
my %blogcfg;

	{my $bid = blogid_for_blogname(blogname  => $blogname); if(! defined($bid)) {errorpage(text => "No such blog");return;} %blogcfg = get_blogcfg(blogid => $bid); } # Incantation to fill in blogcfg

if(! defined $uid)
	{ # Handle no uid
	errorpage(text => "No uid");
	return;
	}
if($blogcfg{author} != $uid)
	{ # Handle mismatch
	errorpage(text => "You cannot configure blogs that are not yours");
	return;
	}
my $tid = get_topicid_for_topic(topicname => $topic, blogid => $blogcfg{id});
my ($ok,$r) = clear_topic_from_entries(topicid => $tid);
if(! $ok)
	{errorpage(text => "Failed to remove topic $topic from existing entries: $r");return;}
blog_delete_topic(blogid => $blogcfg{id}, topicid => $tid); # FIXME error checking might be nice

msgpage(text => "Topic deleted", url => url_manage_topics(blogname => $blogname) );
endhtml();
}

#########################################
# Site config subdispatches
# Below here, all functions assume the user has been authenticated
# TODO: All of this

sub subdispatch_admin_keys
{ # TODO: A lot
	# Handle both showing all keys (links to individual keys) and providing fields to actually change a single value
	# The existing code is just a "proof of concept"
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $fargs	= $args->mandate('args');
$args->argok();

if(! @$fargs) # The "show all keys" behaviour
	{
	sthtml(title => "POUND Site Administration : Keys", no_css => 1);
	print "<table border=1><tr><th>Key</th><th>Val</th><th>Description</th><th>Allowed Values</th></tr>\n";
	my %conf_keys = get_configkeys();
	foreach my $keyname (sort keys %conf_keys)
		{
		my $keyurl = join('/', url_sitecfg(), 'manage_keys', $keyname);
		print qq{<tr><td>} . get_htlink(content => $keyname, target => $keyurl) . qq{</td><td>$conf_keys{$keyname}{value}</td><td>$conf_keys{$keyname}{description}</td><td>$conf_keys{$keyname}{avalues}</td></tr>\n};
		}
	print "</table>\n";
	endhtml();
	}
else # The "show a key in a form for editing" behaviour
	{ # XXX Consider telling the user if they request a nonexistent key
	my $keyname = shift @$fargs;
	sthtml(title => "POUND Site Administration : Keys", no_css => 1);
	print <<EOPATHWARN;
<b>Note:You should be careful not to give keys values that do not match what is appropriate for their type, as this will rarely do anything useful and might easily break the software.</b><br /><br />
EOPATHWARN
	print "The appropriate type for this key is as follows: <b>";
	my $keytype = get_configkey_type(keyname => $keyname);
	print describe_config_type(keytype => $keytype);
	print "</b><br />";
	print "Key $keyname is described as <b>" . get_configkey_description(keyname => $keyname) . "</b><br /><hr />\n";

	stform(submit_url => join('/', url_sitecfg(), 'manage_keys_post'), formid => "pathedit", validator => apache_session_key(apacheobj => $apache_r) ); # We're hardcoding paths here because allowing users to configure this could easily hose them. FIXME still this should be in POUNDPaths as a hardcoded value there.
	form_hidden(name => 'keyname', value => $keyname);
	form_txtfield(caption => "Key <b>$keyname</b>", name => 'value', value => get_configkey(keyname => $keyname) );
	endform(submit => "Ok");
	endhtml();
	}
}

sub subdispatch_admin_keys_post
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

if(! is_POST(apacheobj => $apache_r) )
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
foreach my $toclean (qw/keyname value/)
	{
	$postdata{$toclean} = de_post_mangle(post_in => $postdata{$toclean});
	}
sthtml(title => "POUND Site Administration : Paths (POST)", no_css => 1);
print "Submitting...<br />\n";
# TODO: How about some error checking?
# Also, for this function, consider validating by specified type before setting
set_configkey(keyname => $postdata{keyname}, value => $postdata{value}); # This fn cannot create new keys
print get_htlink(content => "Continue", target => join('/', url_sitecfg(), 'manage_keys'));
endhtml();
}

sub subdispatch_admin_paths
{ # TODO: For now, make it like subdispatch_admin_keys, later do specific validation
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $fargs 	= $args->mandate('args');
$args->argok();

if(! @$fargs) # The "show all keys" behaviour
	{
	sthtml(title => "POUND Site Administration : Paths", no_css => 1);
	print "<table border=1><tr><th>Key</th><th>Val</th><th>Description</th></tr>\n";
	my %path_keys = get_pathkeys();
	foreach my $keyname (sort keys %path_keys)
		{
		my $keyurl = join('/', url_sitecfg(), 'manage_paths', $keyname);
		print qq{<tr><td>} . get_htlink(content => $keyname, target => $keyurl) . qq{</td><td>$path_keys{$keyname}{value}</td><td>$path_keys{$keyname}{description}</td></tr>\n};
		}
	print "</table>\n";
	endhtml();
	}
else # The "show a key in a form for editing" behaviour
	{ # XXX Consider telling the user if they request a nonexistent key
	my $keyname = shift @$fargs;
	sthtml(title => "POUND Site Administration : Paths", no_css => 1);
	print <<EOPATHWARN;
<hr />
<b>Note:You should be sure not to put spaces or other characters in this field that would cause problems. For maximal safety and friendliness, use only lowercase letters and underscores.</b><br /><br />
EOPATHWARN
	print "Path $keyname is described as <b>" . get_pathkey_description(keyname => $keyname) . "</b><br /><hr />\n";

	stform(submit_url => join('/', url_sitecfg(), 'manage_paths_post'), formid => 'pathedit', validator => apache_session_key(apacheobj => $apache_r) ); # We're hardcoding paths here because allowing users to configure this could easily hose them. FIXME still this should be in POUNDPaths as a hardcoded value there.
	form_hidden(name => 'keyname', value => $keyname);
	form_txtfield(caption => "Key <b>$keyname</b>", name => 'value', value => get_pathkey(keyname => $keyname) );
	endform(submit => "Ok");
	endhtml();
	}
}

sub subdispatch_admin_paths_post
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

if(! is_POST(apacheobj => $apache_r) )
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
foreach my $toclean (qw/keyname value/)
	{
	$postdata{$toclean} = de_post_mangle(post_in => $postdata{$toclean});
	}
sthtml(title => "POUND Site Administration : Paths (POST)", no_css => 1);
print "Submitting...<br />\n";
# TODO: How about some error checking?
# Also, we might consider some validation, like preventing empty values restricting valid input characters, and possibly enforcing uniqueness of pathkey values
set_pathkey(keyname => $postdata{keyname}, value => $postdata{value}); # This fn cannot create new keys
print get_htlink(content => "Continue", target => join('/', url_sitecfg(), 'manage_paths'));
endhtml();
}

sub subdispatch_admin_manage_css
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();
}

sub subdispatch_admin_manage_css_post
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();
}

sub subdispatch_admin_manage_users
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();
}

sub subdispatch_admin_manage_users_post
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();
}

sub subdispatch_admin_manage_global_settings
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();
}

sub subdispatch_admin_manage_global_settings_post
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();
}



1;
