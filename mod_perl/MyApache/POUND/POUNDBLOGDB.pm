#!/usr/bin/perl

# This is for BLOG code that talks heavily to the database. I'd like to keep it seperate from
# more general database code. 

use strict;
use DBI;
package MyApache::POUND::POUNDBLOGDB;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDDB;
use POSIX;
require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(get_blogcfg get_x_latest_entries get_timeinfo get_bentry get_bentry_reply_ids get_all_entryzeits get_topics_for_bentry get_all_topics_for_blog get_topic_by_id get_header_extra_for_blog bentry_by_zeit get_bcomment get_bcomment_reply_ids comentry_by_zeit get_entries_from_archive_page get_num_archivepages get_topicid_for_topic get_image_for_topic get_topicdesc_for_topic get_entries_with_topicid get_title_for_entry clean_blogentry setup_blogentry new_blogentry clean_topic setup_topic new_topic topic_exists blogid_for_blogname blogentry_set_privatep_flag get_blogentry_relatives do_post_blogcomment get_blogentry_commentable zeit_for_blogentry get_bentry_num_deepreplies get_bcomment_num_deepreplies blog_set_title blog_set_anon_and_comments blog_set_header_extra blog_set_blogimg blog_add_topic blog_mod_topic blog_delete_topic get_entryid_ancestor_of_commentid get_miscvals_for_entry clear_topic_from_entries get_bloglist get_blog_lastmodified get_blog_numentries);
our @EXPORT = @EXPORT_OK;

sub get_blogcfg
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid = $args->mandate('blogid');
$args->argok();

my $dbh = db_connect();
my $bcq = $dbh->prepare("SELECT * FROM blog WHERE id=?");
$bcq->execute($blogid);
my %cfg = get_dbresults($bcq);
$bcq->finish();
release_db($dbh);
return %cfg;
}

sub get_blogpostdefaults
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid = $args->mandate('blogid');
$args->argok();

my $dbh = db_connect();
my $bcq = $dbh->prepare("SELECT comments,anon_comments FROM blog WHERE id=?");
$bcq->execute($blogid);
my %cfg = get_dbresults($bcq);
$bcq->finish();
release_db($dbh);
return %cfg;
}

sub blogid_for_blogname
{ 
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogname = $args->mandate('blogname');
$args->argok();

return db_get_attr_from_id(	table => 'blog',
				ident_field => 'name',
				ident_value => $blogname,
				requested => 'id');
}

sub get_x_latest_entries
{ 
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid 	= $args->mandate('blogid');
my $nentries	= $args->accept('nentries', 10);
my $noprivate	= $args->accept('no_private', 0); # Allow exclusion..
$args->argok();

my $npq = '';
if($noprivate) {$npq = qq{AND private=false};}

my $dbh = db_connect();
my $bxq = $dbh->prepare("SELECT id FROM blogentry WHERE blog=? $npq ORDER BY zeit desc limit $nentries");
$bxq->execute($blogid);
my @results = get_dbcol($bxq);
$bxq->finish();
release_db($dbh);
return @results;
}

sub get_entries_from_archive_page
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid 	= $args->mandate('blogid');
my $archpage	= $args->mandate('archpage');
my $asize	= $args->accept('asize', 10);
$args->argok();

my $offset = ($archpage - 1)*$asize;
my $dbh = db_connect();
my $bxq = $dbh->prepare("SELECT id FROM blogentry WHERE blog=? ORDER BY zeit limit ? offset ?");
	# XXX Do I need to validate this input at all?
$bxq->execute($blogid, $asize, $offset);
my @results = get_dbcol($bxq);
$bxq->finish();
release_db($dbh);
return @results;
}

sub get_entries_with_topicid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $topicid = $args->mandate('topicid');
$args->argok();

my $dbh = db_connect();
my $teq = $dbh->prepare("SELECT zeit FROM entry_topic,blogentry WHERE topicid=? AND entry_topic.entryid = blogentry.id");
	# XXX Do I need to validate this input at all?
$teq->execute($topicid);
my @results = sort {$b <=> $a} get_dbcol($teq);
$teq->finish();
release_db($dbh);
return @results;
}

sub clear_topic_from_entries
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $topicid = $args->mandate('topicid');
$args->argok();

my $dbh = db_connect();
my $tdq = $dbh->prepare("DELETE FROM entry_topic WHERE topicid=?");
$tdq->execute($topicid);
release_db($dbh);
}


sub get_num_archivepages
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid = $args->mandate('blogid');
my $asize = $args->accept('archive_page_size', 10);
$args->argok();

my $nentries = get_blog_numentries(blogid => $blogid);
my $returner = POSIX::ceil($nentries/$asize);
return $returner;
}

sub get_all_entryzeits
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid = $args->mandate('blogid');
$args->argok();

my $dbh = db_connect();
my $beq = $dbh->prepare("SELECT zeit FROM blogentry WHERE blog=?");
$beq->execute($blogid);
my @results = get_dbcol($beq);
$beq->finish();
release_db($dbh);
return @results;
}

sub get_bentry
{ # This returns a hash with an entire blog entry in it. It does no filtering of any kind.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $eid = $args->mandate('entryid');
$args->argok();

my $dbh = db_connect();
my $beq = $dbh->prepare("SELECT * FROM blogentry WHERE id=?");
$beq->execute($eid);
my %returner = get_dbresults($beq);
$beq->finish();
release_db($dbh);
return %returner;
}

sub get_bcomment
{ # This returns a hash with an entire blog comment in it. It does no filtering of any kind.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $cid = $args->mandate('commentid');
$args->argok();

my $dbh = db_connect();
my $beq = $dbh->prepare("SELECT * FROM blogcomment WHERE id=?");
$beq->execute($cid);
my %returner = get_dbresults($beq);
$beq->finish();
release_db($dbh);
return %returner;
}

sub get_blogentry_commentable
{ # checks commentable field for only a blogentry, not acls or entire blog
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $eid = $args->mandate('entryid');
$args->argok();

my $comtf = db_get_attr_from_id(table => 'blogentry',
				ident_value => $eid,
				requested => 'comments');

if( ($comtf eq 't') || ($comtf eq '1')) # Broad compatibility mandates this chk
	{return 1;}
return 0;
}

sub bentry_by_zeit
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $zeit	= $args->mandate('zeit');
$args->argok();

my $dbh = db_connect();
my $bzq = $dbh->prepare("SELECT id FROM blogentry WHERE zeit=? AND blog=?");
$bzq->execute($zeit, $blogid);
my $bzqr = $bzq->fetchrow_hashref();
$bzq->finish();
release_db($dbh);
return $$bzqr{id};
}

sub zeit_for_blogentry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bentry = $args->mandate('entryid');
$args->argok();

return db_get_attr_from_id(	table => 'blogentry',
				ident_value => $bentry,
				requested => 'zeit');
}

sub get_title_for_entry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid 	= $args->mandate('blogid');
my $zeit 	= $args->mandate('zeit');
$args->argok();

my $dbh = db_connect();
my $bzq = $dbh->prepare("SELECT title FROM blogentry WHERE blog=? AND zeit=?");
$bzq->execute($blogid, $zeit);
my $bzqr = $bzq->fetchrow_hashref();
$bzq->finish();
release_db($dbh);
return $$bzqr{title};
}

sub comentry_by_zeit
{ # XXX This solution is currently wrong. Two comments in the same blog in
  # the same second would cause bad behavior. 
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid 	= $args->mandate('blogid');
my $zeit 	= $args->mandate('zeit');
$args->argok();

my $dbh = db_connect();
my $bzq = $dbh->prepare("SELECT id FROM blogcomment WHERE zeit=? AND blog=?");
$bzq->execute($zeit, $blogid);
my $bzqr = $bzq->fetchrow_hashref();
$bzq->finish();
release_db($dbh);
return $$bzqr{id};
}

sub get_timeinfo
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid 	= $args->mandate('blogid');
my $unixtime	= $args->mandate('zeit');
$args->argok();

my $dbh = db_connect();
my $minutes = (localtime($unixtime))[1] + (60 * (localtime($unixtime))[2]);
my $hquery = $dbh->prepare("select name, imageurl from timeimage where starttime <= $minutes and stoptime > $minutes AND blogid=?");
$hquery->execute($blogid);
my %returner = get_dbresults($hquery);
$returner{minutes} = $minutes;
$hquery->finish();
release_db($dbh);
return %returner;
}

sub get_bentry_num_deepreplies
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bentry = $args->mandate('entryid');
$args->argok();

my $returner = 0;
my @kids = get_bentry_reply_ids(entryid => $bentry);
foreach my $kid (@kids)
	{
	$returner += 1 + get_bcomment_num_deepreplies(commentid => $kid);
	}
return $returner;
}

sub get_bcomment_num_deepreplies
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bcom = $args->mandate('commentid');
$args->argok();

my $returner = 0;
my @kids = get_bcomment_reply_ids(commentid => $bcom);
foreach my $kid (@kids)
	{
	$returner += 1 + get_bcomment_num_deepreplies(commentid => $kid);
	}
return $returner;
}

sub get_bentry_reply_ids
{ # All first level comments (not comment on comment) to a blog entry
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bentry = $args->mandate('entryid');
$args->argok();

my $dbh = db_connect();
my $beq = $dbh->prepare("SELECT id FROM blogcomment WHERE blogparent=? AND coc IS NULL");
$beq->execute($bentry);
my @ids = get_dbcol($beq);
$beq->finish();
release_db($dbh);
return @ids;
}

sub get_bcomment_reply_ids
{ # All first level comments (not comment on comment) to a comment
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $cid = $args->mandate('commentid');
$args->argok();

my $dbh = db_connect();
my $beq = $dbh->prepare("SELECT id FROM blogcomment WHERE coc=?");
$beq->execute($cid);
my @ids = get_dbcol($beq);
$beq->finish();
release_db($dbh);
return @ids;
}

sub get_topics_for_bentry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bentry = $args->mandate('entryid');
$args->argok();

my $dbh = db_connect();
my $tq = $dbh->prepare("SELECT topicid FROM entry_topic WHERE entryid=?");
$tq->execute($bentry);
my @tids = get_dbcol($tq);
$tq->finish();
release_db($dbh);
return @tids;
}

sub get_all_topics_for_blog
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid = $args->mandate('blogid');
$args->argok();

my $dbh = db_connect();
my $tq = $dbh->prepare("SELECT id FROM topic WHERE blog=?");
$tq->execute($blogid);
my @tids = get_dbcol($tq);
$tq->finish();
release_db($dbh);
return @tids;
}

sub get_topic_by_id
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $topicid = $args->mandate('topicid');
$args->argok();

my $dbh = db_connect();
my $tq = $dbh->prepare("SELECT * FROM topic WHERE id=?");
$tq->execute($topicid);
my %topic = get_dbresults($tq);
$tq->finish();
release_db($dbh);
return %topic;
}

sub get_topicdesc_for_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $topicid 	= $args->mandate('topicid');
$args->argok();

return db_get_attr_from_id(	ident_value => $topicid,
				table => 'topic',
				requested => 'descrip');
}

sub get_image_for_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $topicid 	= $args->mandate('topicid');
$args->argok();

return db_get_attr_from_id(	ident_value => $topicid,
				table => 'topic',
				requested => 'imgurl');
}

sub get_topicid_for_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $topicname 	= $args->mandate('topicname');
my $blogid 	= $args->mandate('blogid');
$args->argok();

my $dbh = db_connect();
my $tq = $dbh->prepare("SELECT id FROM topic WHERE name=? AND blog=?");
$tq->execute($topicname, $blogid);
my $hr = $tq->fetchrow_hashref();
$tq->finish();
release_db($dbh);
if(defined($hr))
	{
	return $$hr{id};
	}
else
	{return undef;}
}

sub get_header_extra_for_blog
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid = $args->mandate('blogid');
$args->argok();

return db_get_attr_from_id(	table => 'blog',
				ident_value => $blogid,
				requested => 'header_extra');
}

sub topic_exists
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $tname	= $args->mandate('topicname');
$args->argok();

my $dbh = db_connect();
my $beq = $dbh->prepare("SELECT name FROM topic WHERE blog=? AND name=?");
$beq->execute($blogid, $tname);
my @exists = get_dbcol($beq);
$beq->finish();
release_db($dbh);
if(@exists)
	{return 1;}
return 0;
}

sub clean_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $tname	= $args->mandate('topicname');
$args->argok();

my $dbh = db_connect();
my $cleaner = $dbh->prepare("UPDATE topic SET imgurl=NULL,descrip=NULL WHERE blog=? AND name=?");
$cleaner->execute($blogid, $tname);
$cleaner->finish();
release_db($dbh);
}

sub new_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $tname	= $args->mandate('topicname');
$args->argok();

my $dbh = db_connect();
my $newt = $dbh->prepare("INSERT INTO topic(blog,name) VALUES (?,?)");
$newt->execute($blogid, $tname);
$newt->finish();
release_db($dbh);
}

sub setup_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $tname	= $args->mandate('topicname');
my $desc	= $args->mandate('description');
my $imgurl	= $args->mandate('image_url');
$args->argok();

my $dbh = db_connect();
my $sett = $dbh->prepare("UPDATE topic SET imgurl=?,descrip=? WHERE blog=? AND name=?");
$sett->execute($imgurl, $desc, $blogid, $tname);
$sett->finish();
release_db($dbh);
}

sub clean_blogentry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $msgzeit	= $args->mandate('zeit');
$args->argok();

if($msgzeit !~ /^\d+$/){errorpage(text => "Invalid");return;}
my $eid = bentry_by_zeit(blogid => $blogid, zeit => $msgzeit);
if(! defined($eid) )
	{
	return(fail => 1, reason => "Invalid blogentry $eid from $msgzeit!");
	}

my %blogpostdefaults = get_blogpostdefaults(blogid => $blogid);

my $dbh = db_connect();
my $zaptopics = $dbh->prepare("DELETE FROM entry_topic WHERE entryid=?");
$zaptopics->execute($eid);
my $zapmisc = $dbh->prepare("DELETE FROM entry_misc WHERE entryid=?");
$zapmisc->execute($eid);

my $clrentry = $dbh->prepare("UPDATE blogentry SET private='f',comments='" . $blogpostdefaults{comments} . "',anon_comments='" . $blogpostdefaults{anon_comments} . "',title=NULL,body=NULL WHERE id=?");
$clrentry->execute($eid);
$clrentry->finish();
release_db($dbh);
return(fail => 0);
}

sub new_blogentry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $msgid	= $args->mandate('msgid');
$args->argok();

my $dbh = db_connect();
my $newb = $dbh->prepare("INSERT INTO blogentry(blog,zeit) VALUES (?,?)");
$newb->execute($blogid,$msgid);
$newb->finish();
release_db($dbh);
}

sub blogentry_set_privatep_flag
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bentry	= $args->mandate('bentry');
my $private	= $args->mandate('private');
$args->argok();

my $privtxt = ($private) ? 't':'f';

my $dbh = db_connect();
my $privset = $dbh->prepare("UPDATE blogentry set private='$privtxt' WHERE id=?");
$privset->execute($bentry);
$privset->finish();
release_db($dbh);
}

sub setup_blogentry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $zeit	= $args->mandate('entryzeit');
my $content	= $args->mandate('content');
my $attrs	= $args->mandate('attrs');
$args->argok();
my $failedp = 0;
my $failedmsg = "";

if($zeit !~ /^\d+$/){errorpage(text => "Invalid");return;}

my $eid = bentry_by_zeit(blogid => $blogid, zeit => $zeit);
if(! defined($eid) )
	{return (fail => 1, reason => "Invalid blogentry!");}
my $dbh = db_connect();

if(defined($$attrs{title}))
	{
	my $topset = $dbh->prepare("UPDATE blogentry set title=? WHERE id=?");
	$topset->execute($$attrs{title}, $eid);
	$topset->finish();
	}
my $bodyset = $dbh->prepare("UPDATE blogentry set body=? WHERE id=?");
$bodyset->execute($content, $eid);
$bodyset->finish();
if($$attrs{private})
	{
	my $topset = $dbh->prepare("UPDATE blogentry set private=? WHERE id=?");
	$topset->execute('true', $eid);
	$topset->finish();
	}
else # Not private
	{
	my $topset = $dbh->prepare("UPDATE blogentry set private=? WHERE id=?");
	$topset->execute('false', $eid);
	$topset->finish();
	}
if(defined $$attrs{comments})
	{
	my $topset = $dbh->prepare("UPDATE blogentry set comments=? WHERE id=?");
	$topset->execute($$attrs{comments}, $eid);
	$topset->finish();
	}
else
	{ # Set by blog defaults
	my $topset = $dbh->prepare("UPDATE blogentry set comments=(SELECT comments FROM blog WHERE id=?) WHERE id=?");
	$topset->execute($blogid, $eid);
	$topset->finish();
	}
if(defined $$attrs{anoncomments})
	{
	my $topset = $dbh->prepare("UPDATE blogentry set anon_comments=? WHERE id=?");
	$topset->execute($$attrs{anon_comments}, $eid);
	$topset->finish();
	}
else
	{ # Set by blog defaults
	my $topset = $dbh->prepare("UPDATE blogentry set anon_comments=(SELECT anon_comments FROM blog WHERE id=?) WHERE id=?");
	$topset->execute($blogid, $eid);
	$topset->finish();

	}
foreach my $topic (keys %{$$attrs{topic}})
	{
	my $topicid = get_topicid_for_topic(blogid => $blogid, topicname => $topic);
	if(! defined($topicid))
		{
		$failedmsg .= "Topic $topic does not exist. Entry incomplete.";
		$failedp = 2;
		}
	assign_topic_to_entry(entryid => $eid, topicid => $topicid);
	}
foreach my $misctype (keys %{$$attrs{misc}})
	{
	foreach my $miscval (@{$$attrs{misc}{$misctype}})
		{
		assign_miscval_to_entry(entryid => $eid, misc_type => $misctype, value => $miscval);
		}
	}
release_db($dbh);
return (fail => $failedp, post_fail => $failedp, reason => $failedmsg, entryid => $eid);
}

sub assign_topic_to_entry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $eid		= $args->mandate('entryid');
my $tid		= $args->mandate('topicid');
$args->argok();

my $dbh = db_connect();
my $ast = $dbh->prepare("INSERT INTO entry_topic(entryid,topicid) VALUES (?,?)");
$ast->execute($eid,$tid);
$ast->finish();
release_db($dbh);
}

sub assign_miscval_to_entry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $eid		= $args->mandate('entryid');
my $mt		= $args->mandate('misc_type');
my $val		= $args->mandate('value');
$args->argok();

my $dbh = db_connect();
my $mia = $dbh->prepare("INSERT INTO entry_misc(entryid,misctype,miscdata) VALUES (?,?,?)");
$mia->execute($eid,$mt,$val);
$mia->finish();
release_db($dbh);
}

sub get_miscvals_for_entry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $eid = $args->mandate('entryid');
$args->argok();

my @returner;
my $dbh = db_connect();
my $mvq = $dbh->prepare("SELECT misctype,miscdata FROM entry_misc WHERE entryid=?");
$mvq->execute($eid);

while(my $hr = $mvq->fetchrow_hashref() )
	{
	push(@returner, $hr);
	}
return \@returner;
}

sub get_blogentry_relatives
{ # Finds entryzeit of previous and next entries in this blog
  # for the given entry
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid		= $args->mandate('blogid');
my $entryzeit		= $args->mandate('entryzeit');
$args->argok();

my $dbh = db_connect();
my $bnewer = $dbh->prepare("SELECT zeit FROM blogentry WHERE blog=? AND zeit > ? ORDER BY zeit ASC LIMIT 1");
$bnewer->execute($blogid, $entryzeit);
my @a_nextentry = get_dbcol($bnewer);
$bnewer->finish();
my $bolder = $dbh->prepare("SELECT zeit FROM blogentry WHERE blog=? AND zeit < ? ORDER BY zeit DESC LIMIT 1");
$bolder->execute($blogid,$entryzeit);
my @a_preventry = get_dbcol($bolder);
$bolder->finish();
my($preventry,$nextentry);
if(@a_preventry)
	{
	$preventry = $a_preventry[0];
	}
if(@a_nextentry)
	{
	$nextentry = $a_nextentry[0];
	}
release_db($dbh);
return ($preventry,$nextentry);
}

sub do_post_blogcomment
{ # XXX Think about if/how to refactor this interface... issue: comment-on-comment vs comment-on-entry
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate('userid');
my $replytime	= $args->mandate('comzeit');
my $bentryid	= $args->mandate('entryid');
my $title	= $args->mandate('title');
my $text	= $args->mandate('content');
my $bcommentid	= $args->accept('commentid', undef);	# Only meaningful if...
my $pnodetype	= $args->mandate('parent_nodetype');	# the type is 'comment'
my $blogid	= $args->mandate('blogid');
my $sourceip	= $args->mandate('sourceip');
$args->argok();

my $dbh = db_connect();
if($pnodetype eq 'entry')
	{
	my $brpost = $dbh->prepare("INSERT INTO blogcomment(zeit, title, body, blogparent, blog, sourceip) VALUES(?,?,?,?,?,?)");
	$brpost->execute($replytime, $title, $text, $bentryid, $blogid, $sourceip);
	$brpost->finish();
	if(defined($uid))
		{
		my $brauth = $dbh->prepare("UPDATE blogcomment SET author=? WHERE id=?");
		$brauth->execute($uid, comentry_by_zeit(blogid => $blogid, zeit => $replytime) );
		$brauth->finish();
		}
	}
else
	{
	my $brpost = $dbh->prepare("INSERT INTO blogcomment(zeit, title, body, blogparent, coc, blog, sourceip) VALUES(?,?,?,?,?,?,?)");
	$brpost->execute($replytime, $title, $text, $bentryid, $bcommentid, $blogid, $sourceip);
	$brpost->finish();
	if(defined($uid))
		{
		my $brauth = $dbh->prepare("UPDATE blogcomment SET author=? WHERE id=?");
		$brauth->execute($uid, comentry_by_zeit(blogid => $blogid, zeit => $replytime) );
		$brauth->finish();
		}
	}
release_db($dbh);
}

sub blog_set_title
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $title	= $args->mandate('title');
$args->argok();

db_set_attr_with_id(	table => 'blog', 
			requested => 'title',
			value => $title,
			ident_value => $blogid);
}

sub blog_set_anon_and_comments
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $anonc	= $args->mandate('allow_anon_comments');
my $normc	= $args->mandate('allow_comments');
$args->argok();

db_set_attr_with_id(	table => 'blog', 
			requested => 'anon_comments',
			value => $anonc,
			ident_value => $blogid);
db_set_attr_with_id(	table => 'blog', 
			requested => 'comments',
			value => $normc,
			ident_value => $blogid);
}

sub blog_set_header_extra
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $headerex	= $args->mandate('header_extra');
$args->argok();

db_set_attr_with_id(	table => 'blog', 
			requested => 'header_extra',
			value => $headerex,
			ident_value => $blogid);
}

sub blog_set_blogimg
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $img_url 	= $args->mandate('image_url');
$args->argok();

db_set_attr_with_id(	table => 'blog', 
			requested => 'blogimg',
			value => $img_url,
			ident_value => $blogid);
}

sub blog_add_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $tname	= $args->mandate('topic_name');
my $tdesc	= $args->mandate('topic_desc');
my $turl	= $args->mandate('topic_url');
$args->argok();

my $dbh = db_connect();
my $bst = $dbh->prepare("INSERT INTO topic(name,imgurl,descrip,blog) VALUES (?,?,?,?)");
$bst->execute($tname,$turl, $tdesc, $blogid);
release_db($dbh);
}

sub blog_mod_topic
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $topicid	= $args->mandate('topicid');
my $tname	= $args->mandate('topic_name');
my $tdesc	= $args->mandate('topic_desc');
my $turl	= $args->mandate('topic_url');
$args->argok();

my $dbh = db_connect();
my $bst = $dbh->prepare("UPDATE topic SET name=?,imgurl=?,descrip=? WHERE id=? AND blog=?");
$bst->execute($tname,$turl, $tdesc, $topicid, $blogid);
release_db($dbh);
}

sub blog_delete_topic
{ # FIXME make an interface for this.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid	= $args->mandate('blogid');
my $tid		= $args->mandate('topicid');
$args->argok();

my $dbh = db_connect();
my $bst = $dbh->prepare("DELETE FROM topic WHERE id=? AND blog=?");
$bst->execute($tid, $blogid); # If we just allowed deletion by topicid, people could delete other peoples topics!
release_db($dbh);
}

sub get_entryid_ancestor_of_commentid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $cid	= $args->mandate('comment_id');
$args->argok();

my $parent = db_get_attr_from_id(table => 'blogcomment', ident_value => $cid, requested => 'coc');
my $savedparent = $cid; # Initialise to avoid boundary..
while($parent = db_get_attr_from_id(	table => 'blogcomment',
					ident_value => $parent,
					requested => 'coc'))
			{$savedparent = $parent;} # Will loop if database ever is hosed by circular comments

return db_get_attr_from_id(	table => 'blogcomment',
				ident_value => $savedparent,
				requested => 'blogparent');
}

sub get_bloglist
{ # Returns a list (in a hash) of blog/blogtypes affiliated with a given user
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->accept("userid", undef);
$args->argok();

my %ret;
my $dbh = db_connect();
my $lq;
if(defined $uid)
	{
	$lq = $dbh->prepare("SELECT id,name,title,blogtype,author FROM blog WHERE author=? ORDER BY id");
	$lq->execute($uid);
	}
else
	{
	$lq = $dbh->prepare("SELECT id,name,title,blogtype,author FROM blog ORDER BY id");
	$lq->execute();
	}

while(my %res = get_dbresults($lq))
	{
	$ret{$res{id}}{name} = $res{name};
	$ret{$res{id}}{title} = $res{title};
	$ret{$res{id}}{blogtype} = $res{blogtype};
	$ret{$res{id}}{author} = $res{author};
	}
return \%ret;
}

sub get_blog_lastmodified
{ # XXX Like most database calls I've done so far, this can be done much more efficiently
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $bid = $args->mandate('blogid');
$args->argok();

my ($lastentry, undef) = get_x_latest_entries(
				blogid => $bid,
				nentries => 1);
my %bentry = get_bentry(entryid => $lastentry);
return scalar localtime $bentry{zeit};
}

sub get_blog_numentries
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid = $args->mandate('blogid');
$args->argok();

my $dbh = db_connect();
my $beq = $dbh->prepare("SELECT COUNT(*) FROM blogentry WHERE blog=?");
$beq->execute($blogid);
return get_dbval($beq);
}

1;
