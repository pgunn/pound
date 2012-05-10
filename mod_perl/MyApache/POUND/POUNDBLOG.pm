#!/usr/bin/perl

# This is for general BLOG-related code.

use strict;
use DBI;
package MyApache::POUND::POUNDBLOG;
use MyApache::POUND::POUNDLj;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDCSS;
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDBLOGHTML;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::POUNDBLOGDB;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDAttribs;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDPermissions;
use MyApache::POUND::POUNDSession;
use MyApache::POUND::POUNDMarkup;
use MyApache::POUND::POUNDForms;
use MyApache::POUND::POUNDBLOGContent;
use MyApache::POUND::POUNDFiles;
use MyApache::POUND::POUNDFilesDB;
use MyApache::POUND::POUNDUser;


use Apache2::Const -compile => qw(:methods);
require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_blogmain blog_post describe_blogtype dispatch_frontpage);
our @EXPORT = @EXPORT_OK;

sub dispatch_frontpage
{ # "List of all blogs"
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
$args->argok();

my $blogs = get_bloglist(); # $$blogs{id}{author,name,blogtype,title}

sthtml(title => "Blogs on this site", is_public => 1, no_css => 1);
print "<h1>Blogs on this site:</h1><hr />\n";
print "<table border=1>\n"
. 	"<tr><th></th>" . join('', map {"<th>" . $_ . "</th>"} (qw{Name Author Type Title Last-Updated})) . "</tr>\n";
foreach my $blogid (sort {$a <=> $b} keys %{$blogs})
	{
	my %bloginfo = get_blogcfg(blogid => $blogid);
	my $lastmodified = get_blog_lastmodified(blogid => $blogid);
	my $nentries = get_blog_numentries(blogid => $blogid);

	my $imgstring = '';
	if($bloginfo{blogimg})
		{
		$imgstring = get_htlink(
				content => qq{<img src="$bloginfo{blogimg}">},
				target => url_blog(blogname => $$blogs{$blogid}{name}));
		}
	print "<tr>" . join('', map {"<td>" . $_ . "</td>"}
		(
		$imgstring,
		get_htlink(
			target => url_blog(blogname => $$blogs{$blogid}{name}),
			content => $$blogs{$blogid}{name}, follow_ok => 1) . "($nentries)",
		name_from_userid(userid => $$blogs{$blogid}{author})
. 			'('
. 			login_from_uid(uid => $$blogs{$blogid}{author})
. 			')',
		describe_blogtype(descriptor => $$blogs{$blogid}{blogtype}),
		$$blogs{$blogid}{title},
		$lastmodified
		)) . "</tr>\n";
	}
print "</table>\n";
}

sub dispatch_blogmain
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogname 	= $args->mandate('blogname');
my $request 	= $args->mandate('req');
my $reqargs 	= $args->mandate('args');
$args->argok();

my $blogid = blogid_for_blogname(blogname => $blogname);
if(! $blogid)
	{
	errorpage(text => "BLOG $blogname does not exist. Sorry");
	}
else
	{
	dispatch_blog(apacheobj => $apache_r, req => $request, args => $reqargs, blogid => $blogid);
	}
do_footer();
endhtml();
}

sub dispatch_blog
{
# Handle intial filesystem/path code.
# Note: It's tempting to handle all the parsing of paths here, as it would look nice
#	and aid clarity. That'd be cool, but it's nice to allow the handlers as much
#	control/flexibility as possible, and I've decided that's more important. I want
#	sites to be able to add their own path types without gutting this section, and
#	I suspect people will be more able to cleanly tweak my code if it's engineered
#	like this.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogid 	= $args->mandate('blogid');
my $request 	= $args->mandate('req');
my $reqargs 	= $args->mandate('args');
$args->argok();

my %blogcfg = get_blogcfg(blogid => $blogid);
if(! @$reqargs)
	{
	dispatch_front(apacheobj => $apache_r, blogcfg => \%blogcfg);
	}
else # We have a path past the blogs.
	{
	my $reqp1 = shift @$reqargs; # Remove/save the specific request
	if(($reqp1 eq 'entries') && (@$reqargs) ) # /entries/entry1093454354.html
		{
		my $entryzeit = shift @$reqargs;
		dispatch_entry(apacheobj => $apache_r, entry_zeit => $entryzeit, blogcfg => \%blogcfg);
		}
	elsif(($reqp1 eq get_blognodereply_base(nodetype => 'entry') ) && (@$reqargs) ) # /reply_to_entry/entry1093454354.html
		{
		my $entryzeit = shift @$reqargs;
		dispatch_reply_entry(apacheobj => $apache_r, entry_zeit => $entryzeit, blogcfg => \%blogcfg);
		}
	elsif(($reqp1 eq get_blognodereply_base(nodetype => 'comment') ) && (@$reqargs) ) # /reply_to_comment/comment1093454354.html
		{
		my $comzeit = shift @$reqargs;
		dispatch_reply_comment(apacheobj => $apache_r, comment_zeit => $comzeit, blogcfg => \%blogcfg);
		}
	elsif(($reqp1 eq 'comments') && (@$reqargs) ) # /comments/comment1093454355.html
		{
		my $comzeit = shift @$reqargs;
		dispatch_comment(apacheobj => $apache_r, blogid => $blogid, comment_zeit => $comzeit);
		}
	elsif(($reqp1 eq 'archive') && (@$reqargs) ) # /archive/page28.html
		{
		my $archpage = shift @$reqargs;
		dispatch_archive(apacheobj => $apache_r, blogid => $blogid, page => $archpage);
		}
	elsif(($reqp1 eq 'topics') && (@$reqargs) ) # /topics/Love.html
		{
		my $topic = shift @$reqargs;
		dispatch_topic(apacheobj => $apache_r, blogid => $blogid, topic => $topic);
		}
	elsif($reqp1 eq get_listbase() )
		{
		dispatch_list(apacheobj => $apache_r, blogid => $blogid);
		}
	elsif($reqp1 eq get_nodereply_submitbase(nodetype => 'entry') )
		{
		dispatch_blogreplypost(apacheobj => $apache_r, blogid => $blogid, parent_nodetype => 'entry');
		}
	elsif($reqp1 eq get_nodereply_submitbase(nodetype => 'comment') )
		{
		dispatch_blogreplypost(apacheobj => $apache_r, blogid => $blogid, parent_nodetype => 'comment');
		}
	elsif($reqp1 eq get_nentrypage() )
		{
		dispatch_newentry(apacheobj => $apache_r, blogcfg => \%blogcfg, args => $reqargs);
		}
	elsif($reqp1 eq get_ncomicpage() )
		{
		dispatch_newcomic(apacheobj => $apache_r, blogcfg => \%blogcfg, args => $reqargs);
		}
	elsif($reqp1 eq get_edentrypage() )
		{
		my $zeit = shift(@$reqargs);
		dispatch_editentry(apacheobj => $apache_r, entryzeit => $zeit, blogcfg => \%blogcfg, args => $reqargs);
		}
	elsif($reqp1 eq get_entry_privtogglebase() )
		{
		my $priv = shift(@$reqargs);
		my $zeit = shift(@$reqargs);
		dispatch_blogentry_togglepriv(apacheobj => $apache_r, blogcfg => \%blogcfg, entryzeit => $zeit, target_priv => $priv);
		}

	else
		{ # Don't know what to make of it, so redir back to front of this blog
		redir(apacheobj => $apache_r, target_page => url_blog(blogname => $blogcfg{name}) );
		}
	return;
	}
}

sub topics_from_post
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $postref = $args->mandate('post_ref');
$args->argok();

my @returner;
if((ref($$postref{posttopic}) eq '') && ($$postref{posttopic}) ) # Scalar value
	{
	push(@returner, $$postref{posttopic});
	}
elsif(ref($$postref{posttopic}) eq 'ARRAY')
	{
	push(@returner, @{@$postref{posttopic}});
	}
return @returner;
}

sub dispatch_entry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $entryzeit	= $args->mandate('entry_zeit');
my $blogcfg 	= $args->mandate('blogcfg');
$args->argok();

sthtml(title => $$blogcfg{title}, is_public => 1);
$entryzeit =~ s/^entry//;
$entryzeit =~ s/\.html//;
if($entryzeit !~ /^\d+$/) {print STDERR "POUND dispatch_entry asked for invalid entry $entryzeit\n";errorpage(text => "Bad request");return;}

my $eid = bentry_by_zeit(blogid => $$blogcfg{id}, zeit => $entryzeit);
my %entry = get_bentry(entryid => $eid);
my %zeitinfo = get_timeinfo(zeit => $entry{zeit}, blogid => $$blogcfg{id});
my $allow_replies = $$blogcfg{comments} && get_blogentry_commentable(entryid => $eid); # Don't even display the reply if comments are always verboten
my @replies = get_bentry_reply_ids(entryid => $eid);
my $deepreplies = get_bentry_num_deepreplies(entryid => $eid);
#print "<!-- " . scalar(@replies) . " replies -->\n";
my @topics = map
		{
		my %tinfo = get_topic_by_id(topicid => $_);
		\%tinfo;
		}
	get_topics_for_bentry(entryid => $eid);
my $entmisc = get_miscvals_for_entry(entryid => $eid);

print qq{<center>} . get_htlink(target => url_blog(blogname => $$blogcfg{name}), content => $$blogcfg{title}) . qq{</center>\n};
	{
	my ($prev,$next) = get_blogentry_relatives(blogid => $$blogcfg{id}, entryzeit => $entryzeit);
	print qq{<center>\n};
	if($prev)
		{
		print get_htlink(target => url_nodepage(blogname => $$blogcfg{name}, nodezeit => $prev, nodetype => 'entry'), content => '&lt;Previous', follow_ok => 1) . ' ';
		}
	if($next)
		{
		print get_htlink(target => url_nodepage(blogname => $$blogcfg{name}, nodezeit => $next, nodetype => 'entry'), content => 'Next&gt;', follow_ok => 1);
		}
	print qq{</center>\n};
	}
if($allow_replies)
	{
	print q{<center>} . get_htlink(	target => url_node_reply_page(blogname => $$blogcfg{name}, node => $entryzeit, nodetype => 'entry'),
					content => 'Post a reply') . qq{</center>\n};
	print "<hr />\n";
	}

display_bnode(	node_r => \%entry,
		nodetype => 'entry',
		replies_r => \@replies,
		num_deep_replies => $deepreplies,
		zeitinfo => \%zeitinfo,
		do_replyfield => 0,
		reply_ok => 0,
		entry_misc => $entmisc,
		entry_topics_list => \@topics,
		blogcfg => $blogcfg,
		apacheobj => $apache_r);
foreach my $reply (@replies)
	{
	my @replies = get_bcomment_reply_ids(commentid => $reply);
	my $subdeepreplies = get_bcomment_num_deepreplies(commentid => $reply);
#	print qq{<!-- R:$reply -->\n};
	my %replyinfo = get_bcomment(commentid => $reply);
	my %zeitinfo = get_timeinfo(zeit => $replyinfo{zeit}, blogid => $$blogcfg{id});
	my $do_replyfield = $$blogcfg{comments}; # Don't even display the reply if comments are always verboten
	my %personinfo = get_personinfo(uid => $replyinfo{author});
	display_bnode(		apacheobj => $apache_r,
				node_r => \%replyinfo,
				nodetype => 'comment',
				replies_r => \@replies,
				num_deep_replies => $subdeepreplies,
				zeitinfo => \%zeitinfo,
				do_replyfield => $do_replyfield,
				reply_ok => $allow_replies,
				blogcfg => $blogcfg);
	}
}

sub dispatch_comment
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogid 	= $args->mandate('blogid');
my $comzeit	= $args->mandate('comment_zeit');
$args->argok();

my %blogcfg = get_blogcfg(blogid => $blogid);
sthtml(title => $blogcfg{title}, is_public => 1);
$comzeit =~ s/^comment//;
$comzeit =~ s/\.html//;
my $eid = comentry_by_zeit(blogid => $blogid, zeit => $comzeit);
my %entry = get_bcomment(commentid => $eid);
my %zeitinfo = get_timeinfo(zeit => $entry{zeit}, blogid => $blogcfg{id});
my $allow_replies = $blogcfg{comments}; # TODO Allow blog owner to close comments selectively? Hmm. 
my @replies = get_bcomment_reply_ids(commentid => $eid);
my $deepreplies = get_bcomment_num_deepreplies(commentid => $eid);
print "<!-- " . scalar(@replies) . " replies -->\n";
display_bnode(
	apacheobj => $apache_r,
	node_r => \%entry,
	nodetype => 'comment',
	replies_r => \@replies,
	num_deep_replies => $deepreplies,
	zeitinfo => \%zeitinfo,
	do_replyfield => 0,
	reply_ok => $allow_replies,
	blogcfg => \%blogcfg);
print "<hr />";
print qq{<center>} . get_htlink(target => url_blog(blogname => $blogcfg{name}), content => $blogcfg{title}) . qq{</center>\n};
if($allow_replies)
	{
	print q{<center>} . get_htlink(target => url_node_reply_page(blogname => $blogcfg{name}, node => $comzeit, nodetype => 'comment'), content => 'Post a reply') . qq{</center>\n};
	print "<hr />";
	}
foreach my $reply (@replies)
	{
	my @subreplies = get_bcomment_reply_ids(commentid => $reply);
	my $subdeepreplies = get_bcomment_num_deepreplies(commentid => $reply);
	my %replyinfo = get_bcomment(commentid => $reply);
	my %zeitinfo = get_timeinfo(zeit => $replyinfo{zeit}, blogid => $blogcfg{id});
	my $do_replyfield = $blogcfg{comments}; # Don't even display the reply if comments are always verboten
	my %personinfo = get_personinfo(uid => $replyinfo{author});
	display_bnode(
		apacheobj => $apache_r,
		node_r => \%replyinfo,
		nodetype => 'comment',
		replies_r => \@subreplies,
		num_deep_replies => $subdeepreplies,
		zeitinfo => \%zeitinfo,
		do_replyfield => 1,
		reply_ok => $allow_replies,
		blogcfg => \%blogcfg);
	}
}

sub dispatch_front
{ # show the "front" page of a given blog
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogcfg 	= $args->mandate('blogcfg');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);

my $num_entries = get_blog_numentries(blogid => $$blogcfg{id});
my $blogrssfeed = url_blogrss(blogname => $$blogcfg{name});
my $blogatomfeed = url_blogatom(blogname => $$blogcfg{name});

sthtml(title => $$blogcfg{title}, rssfeed => $blogrssfeed, atomfeed => $blogatomfeed, is_public => 1);
if(defined($uid))
	{
	print qq{<!-- Generated for UserID: $uid-->};
	}
else
	{
	print qq{<!-- Generated for UserID: NONE -->};
	}
display_blogmain(
		apacheobj => $apache_r,
		blogcfg => $blogcfg,
		num_entries => $num_entries,
		userid => $uid,
		blogtype => describe_blogtype(descriptor => $$blogcfg{blogtype}));
my @entries = get_x_latest_entries(blogid => $$blogcfg{id});
if(@entries)
	{
	display_entrywrapper();
	foreach my $msgid (@entries)
		{
		my @replies = get_bentry_reply_ids(entryid => $msgid);
		my $deepreplies = get_bentry_num_deepreplies(entryid => $msgid);
		my @topics = map
				{
				my %tinfo = get_topic_by_id(topicid => $_);
				\%tinfo;
				}
			get_topics_for_bentry(entryid => $msgid);

		my %entry = get_bentry(entryid => $msgid);
		my %zeitinfo = get_timeinfo(zeit => $entry{zeit}, blogid => $$blogcfg{id});
		my $do_replyfield = $$blogcfg{comments}; # Don't even display the field if comments are always verboten
		my $entmisc = get_miscvals_for_entry(entryid => $msgid);
		display_bnode(	node_r => \%entry,
				nodetype => 'entry',
				replies_r => \@replies,
				num_deep_replies => $deepreplies,
				zeitinfo => \%zeitinfo,
				do_replyfield => $do_replyfield,
				reply_ok => get_blogentry_commentable(entryid => $entry{id}),
				entry_topics_list => \@topics,
				entry_misc => $entmisc,
				blogcfg => $blogcfg,
				apacheobj => $apache_r,
				hide_cuts => 1);
		}
	close_entrywrapper();
	}
else
	{
	print "NO ENTRIES!<br />\n";
	}
}

sub dispatch_archive
{ # Like dispatch_main, but with the order reversed and as a selected slice of pages.
# TODO: Eventually let users tweak, via login prefs, how many pages they want to see in an
#	archive page. Note that this WILL BREAK, for those users, links to an
#	archive page, as the contents of such a page will differ per user. That's ok.
#	we'll ask spiders not to visit archive pages. 

my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogid 	= $args->mandate('blogid');
my $archpage	= $args->mandate('page');
$args->argok();

$archpage =~ s/^page//;
$archpage =~ s/\.html//;

my %blogcfg = get_blogcfg(blogid => $blogid);

my $num_archivepages = get_num_archivepages(blogid => $blogid);
if( ($archpage < 1) || ($archpage > $num_archivepages) )
	{ # Asked for nonexistant archive page.
	redir(apacheobj => $apache_r, target_page => url_blog(blogname => $blogcfg{name}));
	}
my $nav = '';
if($archpage > 1)
	{
	my $backlink = url_archpage(blogname => $blogcfg{name}, page => ($archpage - 1));
	$nav .= '[' . get_htlink(target => $backlink, content => 'Past', follow_ok => 1) . ']';
	}
if($archpage < $num_archivepages)
	{
	my $fwdlink = url_archpage(blogname => $blogcfg{name}, page => ($archpage + 1));
	$nav .= '[' . get_htlink(target => $fwdlink, content => 'Future', follow_ok => 1) . ']';
		# TODO Maybe move Past/Future strings, other strings into BLOG-dependant, DB-stored prefs
	}

sthtml(title => $blogcfg{title}, is_public => 1);
do_blog_captionarea(blogimg => $blogcfg{blogimg}, hdrtxt => "Archives, page $archpage", caption_extra => $nav);
my @entries = get_entries_from_archive_page(blogid => $blogid, archpage => $archpage);
if(@entries)
	{
	foreach my $msgid (@entries)
		{
		my @replies = get_bentry_reply_ids(entryid => $msgid);
		my $deepreplies = get_bentry_num_deepreplies(entryid => $msgid);
		my @topics = map
				{
				my %tinfo = get_topic_by_id(topicid => $_);
				\%tinfo;
				}
			get_topics_for_bentry(entryid => $msgid);

		my %entry = get_bentry(entryid => $msgid);
		my %zeitinfo = get_timeinfo(zeit => $entry{zeit}, blogid => $blogcfg{id});
		my $do_replyfield = $blogcfg{comments}; # Don't even display the reply if comments are always verboten
		my $reply_ok = $entry{comments}; # If comments are generally kosher but not for this entry, display the bar but tell user it's verboten
		my $entmisc = get_miscvals_for_entry(entryid => $msgid);
		display_bnode(	node_r => \%entry,
				nodetype => 'entry',
				replies_r => \@replies,
				num_deep_replies => $deepreplies,
				zeitinfo => \%zeitinfo,
				do_replyfield => $do_replyfield,
				reply_ok => get_blogentry_commentable(entryid => $entry{id}),
				entry_topics_list => \@topics,
				entry_misc => $entmisc,
				blogcfg => \%blogcfg,
				apacheobj => $apache_r,
				hide_cuts => 1);
		}
	}
else
	{
	print "NO ENTRIES!<br />\n";
	}
}

sub dispatch_list
{ # table of entry links with date and subject
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogid 	= $args->mandate('blogid');
$args->argok();

my %blogcfg = get_blogcfg(blogid => $blogid);
my @entries = sort{$b <=> $a} get_all_entryzeits(blogid => $blogid);
sthtml(title => $blogcfg{title});
display_elistpage(blogid => $blogid, blogname => $blogcfg{name}, entries_r => \@entries);
}

sub dispatch_topic
{ # Intro to a topic, then a list of articles with that topic.
# FIXME CSS: make it so it's not so easy to end up with an unreadable page, but smarter
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogid 	= $args->mandate('blogid');
my $topic	= $args->mandate('topic');
$args->argok();

$topic =~ s/\.html//;

my %blogcfg = get_blogcfg(blogid => $blogid);
my $topicid = get_topicid_for_topic(blogid => $blogid, topicname => $topic);
if(! defined($topicid))
	{ # Bounce nonexistant topics back to main page.
	redir(apacheobj => $apache_r, target_page => url_blog(blogname => $blogcfg{name}) );
	}
my %tinfo = get_topic_by_id(topicid => $topicid);

sthtml(title => $blogcfg{title}, is_public => 1);
print qq{<div style="background:black;color:grey;">\n};
print "<h1>$topic</h1><br />\n";

my $timg = get_image_for_topic(topicid => $topicid);
if(defined($timg) && ($timg !~ /^\s*$/))
	{
	print qq{<img src="$timg" alt="Image for topic" /><br />\n};
	}
my $tdesc = get_topicdesc_for_topic(topicid => $topicid);
if(defined($tdesc) && ($tdesc !~ /^\s*$/))
	{
	print qq{$tdesc<br />\n};
	}

print "<hr /><br />\n";
# FIXME Insert topic blurb here
my @entries = get_entries_with_topicid(topicid => $topicid);
if(@entries)
	{
	print qq{There are } . scalar(@entries) . qq{ entries for this topic\n};
	print "<ul>\n";
	foreach my $eid (@entries)
		{
		my $url = url_nodepage(blogname => $blogcfg{name}, nodezeit => $eid, nodetype => 'entry');
		print q{<li>}
			. get_htlink(target => $url, content => get_title_for_entry(blogid => $blogid, zeit => $eid), follow_ok => 1)
			. ' - '
			. localtime($eid)
			. "\n";
		}
	print "</ul>\n";
	}
else
	{
	print "NO ENTRIES!<br />\n";
	}
print qq{</div>\n};
}

sub blog_post
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $zeit	= $args->mandate('entryzeit');
my $content	= $args->mandate('content');
my $attrs	= $args->mandate('attrs'); # FIXME Redo this
$args->argok();

my %returner;
my %se_state = setup_blogentry(blogid => $blogid, entryzeit => $zeit, content => $content, attrs => $attrs);
if($se_state{fail} == 1) # Complete failure
	{return %se_state;}
my $state = $se_state{fail}; # 0 for complete success so far, 2 for partial success that won't hamper LJ
my $ljerr = "";
my $lj_fail = 0;

my $eid = $se_state{entryid};

my ($ok, $lju, $ljp) = ljinfo_for_blog(blogid => $blogid);
if($ok)
	{ # We have LJ linkage!
	my %blogcfg = get_blogcfg(blogid => $blogid);
	if($$attrs{private}) # Don't bother posting these to LJ
		{return (fail => $se_state{fail});}
	my ($ljc, $bad, $badmsg) = lj_login(user => $lju, pass => $ljp);
	if(! $bad) # XXX Need to find a good way to pass this back up to
			# either pndc or the web client, as appropriate
		{
		my $privatetext = "<br />(section not shown)<br />";
		$content = do_markup(data => $content, context => $blogcfg{name}, content_flags => ':for_lj:');
		$content =~ s/<PRIVATE>.*?<\/PRIVATE>/$privatetext/msig;
		$content = purge_newlines_outside_blocks(in => $content);
		my $ljitem = get_ljitem(entryid => $eid);
		if(! $ljitem) # Post does not exist
			{
			my ($lastlj, $msg) = lj_last_posttime(ljobj => $ljc);
			if(! $lastlj) {print "Warning: LJ Post failed to get last time, cancelled post: [$msg]\n";return;}
			my $backdate = 0;
			if($lastlj > ($zeit + (24*60*60))) # XXX Heuristic - if we can trust there to be
							# no TZ BS, we can certainly do better
				{$backdate = 1;}
			my ($pok, $perr, $itemid) = lj_post(
							ljobj		=> $ljc,
							zeit		=> $zeit,
							title		=> $$attrs{title},
							attrs		=> $attrs,
							contents 	=> $content,
							is_old		=> $backdate);

			if($pok) # If it went ok, save the id for later editing.
				{
				save_ljitem(entryid => $eid, ljitemid => $itemid);
				}
			else
				{
				$state = 2; # Partial success
				$lj_fail = 1;
				$ljerr = $perr;
				}
			}
		else # We already have a post, so let's update it instead
			{ # Note: The post's itemid is $ljitem
			my ($pok, $perr) =
			lj_update(
				ljobj		=> $ljc,
				ljentryid	=> $ljitem,
				title		=> $$attrs{title},
				attrs		=> $attrs,
				contents	=> $content);
			if(! $pok) {$lj_fail = 1; $ljerr = $perr;$state = 2;}
			}
		}
	}
return (fail => $state, post_fail => $se_state{fail}, reason => $se_state{reason} . $ljerr, lj_fail => $lj_fail);
}

sub describe_blogtype
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $desc = $args->mandate('descriptor');
$args->argok();

if($desc eq 'b') {return 'blog';}
elsif($desc eq 'c') {return 'webcomic';}
else {return "type [$desc] unknown to describe_blogtype()";}
}

##########################################
### Stuff that doesn't just display data

sub dispatch_newentry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogcfg 	= $args->mandate('blogcfg');
my $reqargs	= $args->mandate('args');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);
if(! defined($uid))
	{
	errorpage(text => "User not logged in!");
	return;
	}
if($uid != $$blogcfg{author})
	{
	errorpage(text => "You cannot post to other BLOGs!");
	return;
	}
if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST", 0);
		return;
		}
	my %vals = post_content(apacheobj => $apache_r);
	if($vals{validcode} ne apache_session_key(apacheobj => $apache_r))
		{
		errorpage(text => 'BAD POST: Foreign source? Failed security check');
		return;
		}
	my %attrs = parse_blog_attribs(msgref => \$vals{body});
	if(defined($vals{subject}))
		{
		$attrs{title} = de_post_mangle(post_in => $vals{subject});
		}
	if($vals{private})
		{$attrs{private} = 1;}
	if($vals{nocomment})
		{$attrs{comments} = 0;}
	if($vals{noacomment})
		{$attrs{anoncomments} = 0;}
	
	foreach my $topicid (topics_from_post(post_ref => \%vals))
		{
		my %topicinfo = get_topic_by_id(topicid => $topicid);
		my $topicname = $topicinfo{name}; # XXX Is this in any way a security risk? Do we need to strip HTML and similar?
		$attrs{topic}{$topicname} = 1;
		}
	my $msgid = time();
	new_blogentry(blogid => $$blogcfg{id}, msgid => $msgid);
	my %res = blog_post(blogid => $$blogcfg{id}, entryzeit => $msgid, content => de_post_mangle(post_in => $vals{body}), attrs => \%attrs);
	
	if($res{fail} == 1) 
	        {
	        errorpage(text => $res{reason});
	        return; 
	        }
	my $next = url_blog(blogname => $$blogcfg{name});
	if($res{fail} == 2) 
	        {
	        my $msg = "";
	                if($res{post_fail})
	                        {$msg .= "Post partially failed<br />\n";}
	                if($res{lj_fail})
	                        {$msg .= "LJ sync failed<br />\n";}
	                $msg .= $res{reason};
	        msgpage(text => $msg, url => $next);
	        return;
	        }
	
	msgpage(text => "Completed OK.", url => $next);
	return;
	}

else # Initial request
	{
	sthtml(title => "Post new entry");
	stform(submit_url => url_nentrypost(blogname => $$blogcfg{name}), formid => 'postentry', validator => apache_session_key(apacheobj => $apache_r) ); # XXX Or should url_nentrypage be extended instead?
	form_txtfield(caption => "Subject", name => "subject");
	my @topicchoices = get_all_topics_for_blog(blogid => $$blogcfg{id});
	stselect(caption => 'Topics:', name => 'posttopic', multi => 6);
	map
		{
		my %topicinfo = get_topic_by_id(topicid => $_);
		addselect(value => $_, text => $topicinfo{name});
		}
		(sort @topicchoices);
	endselect();

	form_txtarea(caption => "Body", name => "body", cols => 80, rows => 24);
######################################
# FIXME: Attribs below should default to the journal's defaults instead of false.
	form_checkbox(caption => 'Private', name => 'private');
	form_checkbox(caption => 'Disallow Comments', name => 'nocomment');
	form_checkbox(caption => 'Disallow Anon Comments', name => 'noacomment');
	print "<br />\n";

# FIXME Add code for radio-button select for private/public and similar
	endform(submit => "Post");
	print "Or you can " . get_htlink(target => url_ncomicpage(blogname => $$blogcfg{name}) , content => "post an image (comic) entry");
	}
}

sub dispatch_newcomic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogcfg 	= $args->mandate('blogcfg');
my $reqargs	= $args->mandate('args');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);
if(! defined($uid))
	{
	errorpage(text => "User not logged in!");
	return;
	}
if($uid != $$blogcfg{author})
	{
	errorpage(text => "You cannot post to other BLOGs!");
	return;
	}
if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST", 0);
		return;
		}
	my %vals = post_content(apacheobj => $apache_r);
	if($vals{validcode} ne apache_session_key(apacheobj => $apache_r))
		{
		errorpage(text => 'BAD POST: Foreign source? Failed security check');
		return;
		}
	if(! defined($vals{namespace}))
		{print STDERR "No namespace defined, got just these keys: " . join(',', keys %vals) . "\n";}
	if(defined($vals{subject}))
		{
		$vals{title} = de_post_mangle(post_in => $vals{subject});
		}
	my $reqobj = Apache2::Request->new($apache_r);
	
	my $filename;
	if(my $uphandle = $reqobj->upload("newfile") ) # Apache2::Upload
		{
		my $data;
		my $size = $uphandle->slurp($data); # sigh
		print STDERR "Got here, with size $size\n";
		$filename = $uphandle->filename(); # Need to sanitize this if we're to use it - may contain a path..
		# TODO now to handle it sensibly...
		my $filetype; # extension. Disallow uploads without one.
		my $mimetype; # inferred from filetype
	
		print STDERR "Input filename of $filename\n";
		$filename =~ /^.*\.(.+)$/; # Snag the extension
		$filetype = $1;
		print STDERR "Extracted extn of $filetype\n";
		if(! $filetype) {errorpage(text => "Uploaded file [$filename] lacks an extension, upload cancelled");}
		$mimetype = infer_mimetype_from_filetype(filetype => $filetype);
		if(! $mimetype) {errorpage(text => "Could not infer mime type from extention [$filetype], upload cancelled");}
			# XXX Consider whitelisting kosher mimetypes
	
		# I have decided, for now, to require extensions on files rather than letting the user specify them. I know that I
		# don't have to do it this way.
	
		my $lobj = blob_writefile(datref => \$data); # postgres-specific code
		db_register_file_blob(name => $filename, namespace => $vals{namespace}, blobid => $lobj, timehere => time(), version => 1, filetype => $filetype, mimetype => $mimetype, creator => $uid);
		}
	else
		{
		errorpage(text => "Upload failed");
		return;
		}
	
	# Now we have to make "content" based on the following:
	#	submitted file
	#	$attrs{subtext}
	my $content = <<EOGENCONTENT;
[[Media:$vals{namespace}:$filename|alt=$vals{subtext}]]
	
EOGENCONTENT
	
	my $msgid = time();
	new_blogentry(blogid => $$blogcfg{id}, msgid => $msgid);
	my %res = blog_post(blogid => $$blogcfg{id}, entryzeit => $msgid, content => $content, attrs => {title=>$vals{title}});
	
	if($res{fail} == 1) 
	        {
	        errorpage(text => $res{reason});
	        return; 
	        }
	my $next = url_blog(blogname => $$blogcfg{name});
	if($res{fail} == 2) 
	        {
	        my $msg = "";
	                if($res{post_fail})
	                        {$msg .= "Post partially failed<br />\n";}
	                if($res{lj_fail})
	                        {$msg .= "LJ sync failed<br />\n";}
	                $msg .= $res{reason};
	        msgpage(text => $msg, url => $next);
	        return;
	        }
	
	msgpage(text => "Completed OK.", url => $next);
	return;
	
	}
else	# This is the form
	{
	sthtml(title => "Post new comic/imagepost");
	stform(submit_url => url_ncomicpost(blogname => $$blogcfg{name}), formid => "postcomic", allow_files => 1, validator => apache_session_key(apacheobj => $apache_r) );
	form_hidden(name => 'namespace', value => $$blogcfg{name});
	form_txtfield(caption => "Subject", name => "subject");
	form_filefield();
	form_txtfield(caption => "Subtext", name => "subtext");
	
	######################################
	# FIXME: Attribs below should default to the journal's defaults instead of false.
	form_checkbox(caption => 'Private', name => 'private');
	form_checkbox(caption => 'Disallow Comments', name => 'nocomment');
	form_checkbox(caption => 'Disallow Anon Comments', name => 'noacomment');
	print "<br />\n";
	
	endform(submit => "Post");
	print "Or you can " . get_htlink(target => url_nentrypage(blogname => $$blogcfg{name}) , content => "post a text (blog) entry");
	}
}

sub dispatch_editentry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $entryzeit	= $args->mandate('entryzeit');
my $blogcfg 	= $args->mandate('blogcfg');
my $reqargs	= $args->mandate('args');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);

if(! defined($uid)) {errorpage(text => "User not logged in!");return;}
if($uid != $$blogcfg{author}) {errorpage(text => "You cannot post to other blogs!");return;}
if($entryzeit !~ /^\d+$/) {errorpage(text => "Invalid edit");return;}

if(@$reqargs && $$reqargs[0] eq 'post') # This is the POST
	{ # TODO: Try to merge these code paths more...
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST", 0);
		return;
		}
	my %vals = post_content(apacheobj => $apache_r);
	if($vals{validcode} ne apache_session_key(apacheobj => $apache_r))
		{
		errorpage(text => 'BAD POST: Foreign source? Failed security check');
		return;
		}
	my %attrs = parse_blog_attribs(msgref => \$vals{body});
	if(! defined($vals{zeit}))
		{
		errorpage(text => "No edit identifier passed\n");
		}
	my %bres = clean_blogentry(blogid => $$blogcfg{id}, zeit => $vals{zeit}); # Empty out the old content
	if($bres{fail})
		{errorpage(text => "Failed: $bres{reason}");return;}
	if(defined($vals{subject}))
		{
		$attrs{title} = de_post_mangle(post_in => $vals{subject});
		}
	foreach my $topicid (topics_from_post(post_ref => \%vals))
		{
		my %topicinfo = get_topic_by_id(topicid => $topicid);
		my $topicname = $topicinfo{name}; # FIXME Error checking might be good?
		$attrs{topic}{$topicname} = 1;
		}
	my %res = blog_post(blogid => $$blogcfg{id}, entryzeit => $vals{zeit}, content => de_post_mangle(post_in => $vals{body}), attrs => \%attrs);
	if($res{fail} == 1)
		{
		errorpage(text => $res{reason});
		return;
		}
	my $next = url_blog(blogname => $$blogcfg{name});
	if($res{fail} == 2)
		{
		my $msg = "";
	                if($res{post_fail})
	                        {$msg .= "Post partially failed<br />\n";}
	                if($res{lj_fail})
	                        {$msg .= "LJ sync failed<br />\n";}
	                $msg .= $res{reason};
		msgpage(text => $msg, url => $next);
		return;
		}
	
	msgpage(text => "Completed OK.", url => $next);
	# Do we need blogentry_mark_private($blogid, $msgid); ?
	}
else
	{
	my %bentry = get_bentry(entryid => bentry_by_zeit(blogid => $$blogcfg{id}, zeit => $entryzeit));
	sthtml(title => "Edit existing entry");
	stform(
		submit_url => url_edentrypost(
			blogname => $$blogcfg{name},
			entryzeit => $entryzeit),
		formid => "editentry",
		validator => apache_session_key(apacheobj => $apache_r) );

	form_hidden(name => 'zeit', value => $entryzeit); # Difference!
	form_txtfield(caption => "Subject", name => "subject", size => 20, value => $bentry{title});
	my @topicchoices = get_all_topics_for_blog(blogid => $$blogcfg{id});
	stselect(caption => 'Topics:', name => 'posttopic', multi => 6);
	map
		{
		my %topicinfo = get_topic_by_id(topicid => $_);
		addselect(value => $_, text => $topicinfo{name});
		}
		(sort @topicchoices);
	endselect();
	
	form_txtarea(caption => "Body", name => "body", cols => 80, rows => 48, value => $bentry{body});
	# FIXME Add code for radio-button select for private/public and similar
	endform(submit => "Post");
	}
}

# FIXME In order to unify blogreplypost into calling code, need to merge reply_entry and reply_comment
# first!

sub dispatch_reply_entry
{ # Form for people to comment on entries
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $entryzeit	= $args->mandate('entry_zeit');
my $blogcfg 	= $args->mandate('blogcfg');
$args->argok();

if($entryzeit !~ /^\d+$/) {errorpage(text => "Invalid reply");return;}

# Fields: blogname, blogentry, replytitle, replytext
sthtml(title => $$blogcfg{title});
my $clientip = get_client_ip(apacheobj => $apache_r);
$entryzeit =~ s/^entry//;
$entryzeit =~ s/\.html//;
print qq{<div id="title">Reply to message $entryzeit</div>\n};
my $beid = bentry_by_zeit(blogid => $$blogcfg{id}, zeit => $entryzeit);
my %bentry = get_bentry(entryid => $beid);
my @replies = get_bentry_reply_ids(entryid => $beid);
my $deepreplies = get_bentry_num_deepreplies(entryid => $beid);
my @topics = map
		{
		my %tinfo = get_topic_by_id(topicid => $_);
		\%tinfo;
		}
	get_topics_for_bentry(entryid => $beid);
my %zeitinfo = get_timeinfo(zeit => $bentry{zeit}, blogid => $$blogcfg{id});
my $entmisc = get_miscvals_for_entry(entryid => $beid);

display_bnode(	node_r => \%bentry,
		nodetype => 'entry',
		replies_r => \@replies,
		num_deep_replies => $deepreplies,
		zeitinfo => \%zeitinfo,
		do_replyfield => 0,
		reply_ok => 0,
		entry_topics_list => \@topics,
		entry_misc => $entmisc,
		blogcfg => $blogcfg,
		apacheobj => $apache_r);
print "\n<hr />\n";
my $submiturl = url_nodereply_submit(blogname => $$blogcfg{name}, nodetype => 'entry');

if(defined apache_session_key(apacheobj => $apache_r)) # XXX If we ever refactor to need uid above, change this!
	{
	stform(submit_url => $submiturl, formid => 'replyform', validator => apache_session_key(apacheobj => $apache_r));
	}
else
	{
	stform(submit_url => $submiturl, formid => 'replyform');
	}
form_txtfield(caption => 'Title', name => 'replytitle', size => 50, max_length => 99);
form_txtarea(caption => '', name => 'replytext', cols => 120, rows => 25);
print "<br />\n";
form_hidden(name => "blogname", value => $$blogcfg{name});
form_hidden(name => "blogentry", value => $entryzeit);
form_hidden(name => "clientip", value => $clientip);
endform(submit => 'Post');
}

sub dispatch_reply_comment
{ # Form for people to comment on entries
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $comzeit	= $args->mandate('comment_zeit');
my $blogcfg 	= $args->mandate('blogcfg');
$args->argok();

# Fields: blogname, blogentry, replytitle, replytext
sthtml(title => $$blogcfg{title});
my $clientip = get_client_ip(apacheobj => $apache_r);
$comzeit =~ s/^comment//;
$comzeit =~ s/\.html//;
print qq{<div id="title">Reply to comment $comzeit</div>\n};
my $comid = comentry_by_zeit(blogid => $$blogcfg{id}, zeit => $comzeit);
my %comentry = get_bcomment(commentid => $comid);
my %bentry = get_bentry(entryid => $comentry{blogparent});
my $bezeit = $bentry{zeit};
my @replies = get_bcomment_reply_ids(commentid => $comid);
my $deepreplies = get_bcomment_num_deepreplies(commentid => $comid);
my %zeitinfo = get_timeinfo(zeit => $comentry{zeit}, blogid => $$blogcfg{id});
display_bnode(
		apacheobj => $apache_r,
		node_r => \%comentry,
		nodetype => 'comment',
		replies_r => \@replies,
		num_deep_replies => $deepreplies,
		zeitinfo => \%zeitinfo,
		do_replyfield => 0,
		reply_ok => 0,
		blogcfg => $blogcfg);
print "\n<hr />\n";
my $submiturl = url_nodereply_submit(blogname => $$blogcfg{name}, nodetype => 'comment');
if(defined apache_session_key(apacheobj => $apache_r)) # XXX If we ever refactor to need uid above, change this!
	{
	stform(submit_url => $submiturl, formid => 'replyform', validator => apache_session_key(apacheobj => $apache_r) );
	}
else
	{
	stform(submit_url => $submiturl, formid => 'replyform');
	}
form_txtfield(caption => 'Title', name => 'replytitle', size => 50, max_length => 99);
form_txtarea(caption => '', name => 'replytext', cols => 120, rows => 25);
print "<br />\n";
form_hidden(name => "blogname", value => $$blogcfg{name});
form_hidden(name => "commententry", value => $comzeit);
form_hidden(name => "blogentry", value => $bezeit);
form_hidden(name => "clientip", value => $clientip);
endform(submit => 'Post');
}

sub dispatch_blogreplypost
{ # FIXME this will need tweaking when we implement ACLs
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $blogid 	= $args->mandate('blogid');
my $pnodetype	= $args->mandate('parent_nodetype');
$args->argok();

# Steps:
# 1) Parse the request
# 2) Figure out permissions
# 3) Post
if(! is_POST(apacheobj => $apache_r))
	{
	errorpage(text => "BAD POST: Not a POST");
	return;
	}
my $uid = session_uid(apacheobj => $apache_r);
my %postdata = post_content(apacheobj => $apache_r);
if(0 == scalar(keys %postdata))
	{
	print qq{<html><body style="background: red;">Bad POST: empty data</body></html>};
	return;
	}
if($uid && ($postdata{validcode} ne apache_session_key(apacheobj => $apache_r))) # No security check for those not logged in, but they may not be allowed to reply depending on policy
	{
	errorpage(text => 'BAD POST: Foreign source? Failed security check');
	return;
	}
foreach my $toclean (qw{blogname blogentry commententry replytitle replytext})
	{
	if(defined($postdata{$toclean}))
		{
		$postdata{$toclean} = de_post_mangle(post_in => $postdata{$toclean});
		}
	}
my @bannedwords = get_bannedwords();
foreach my $bword (@bannedwords)
	{
	if($postdata{replytext} =~ /$bword/)
		{
		errorpage(text => "Bad POST: Spam detected!");
		return;
		}
	}

my $sourceip = get_client_ip(apacheobj => $apache_r);
print "Sourceip: $sourceip\n";

if(($sourceip != $postdata{clientip}) && get_postguard_enabled() && (! $uid)) # Allow logged-in users to bypass
	{
	errorpage(text => "Bad POST: source address differs between form and submit. Proxy pools (e.g. AOL) cannot post.");
	return;
	}
if((! defined($sourceip)) && get_postguard_enabled() )
	{
	errorpage(text => "Bad POST: source IP address not retrievable?");
	return;
	}

if(! $blogid)
	{
	errorpage(text => "Bad blog name");
	return;
	}
my %blogcfg = get_blogcfg(blogid => $blogid);
my $eid;
my $replytime = time();
my $canpost;
my $redirurl;
if($pnodetype eq 'entry') # FIXME Unify these if feasable
	{
	$eid = bentry_by_zeit(blogid => $blogid, zeit => $postdata{blogentry});
	$canpost = ok_blogentry_reply(
				userid => $uid, 
				entry_writable => get_blogentry_commentable(entryid => $eid),
				blog_writable => $blogcfg{comments}
				);
	$redirurl = url_nodepage(blogname => $blogcfg{name}, nodezeit => $postdata{blogentry}, nodetype => $pnodetype);
	}
else
	{
	$eid = get_entryid_ancestor_of_commentid(comment_id => comentry_by_zeit(blogid => $blogcfg{id}, zeit => $postdata{commententry}));
	$canpost = ok_blogcomment_reply(
				userid => $uid,
				entry_writable => get_blogentry_commentable(entryid => $eid),
				blog_writable => $blogcfg{comments}
				);
	$redirurl = url_nodepage(blogname => $blogcfg{name}, nodezeit => $postdata{commententry}, nodetype => $pnodetype);
	}

if(! $canpost)
	{
#	errorpage(text => "Cannot post: Not open for reply, OE=$pnodetype/$eid/$postdata{blogentry}, EW=" . get_blogentry_commentable(entryid => $eid) . ", BW=" . $blogcfg{comments});
	errorpage(text => "Cannot post: Not open for reply");
	return;
	}
do_post_blogcomment
	(
	userid => $uid,
	comzeit => $replytime,
	entryid => $eid,
	title => $postdata{replytitle},
	content => html_purge(data => $postdata{replytext}), # Security!!!
	commentid => comentry_by_zeit(blogid => $blogcfg{id}, zeit => $postdata{commententry}),
	parent_nodetype => $pnodetype, # There's got to be a smarter way to do this..
	blogid => $blogcfg{id},
	sourceip => $sourceip
	);

redir(apacheobj => $apache_r, target_page => $redirurl);
}

sub dispatch_blogentry_togglepriv
{ # FIXME - Should this update LJ?
# FIXME Possible cross-site POSTs need to be addressed here. This must be made into a POST and given a validator
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r 	= $args->mandate('apacheobj');
my $entryzeit	= $args->mandate('entryzeit');
my $blogcfg 	= $args->mandate('blogcfg');
my $priv	= $args->mandate('target_priv');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);

if(! defined($uid)){errorpage(text => "User not logged in!");return;}
if($uid != $$blogcfg{author}){errorpage(text => "Not your blog.");return;}
if($entryzeit !~ /^\d+$/) {errorpage(text => "Invalid toggle");return;}

my $entryid = bentry_by_zeit(blogid => $$blogcfg{id}, zeit => $entryzeit);
blogentry_set_privatep_flag(bentry => $entryid, private => $priv);
msgpage(text => "Privacy toggle of $entryzeit on blog $$blogcfg{name} completed OK.", url => url_blog(blogname => $$blogcfg{name}));
}

1;
