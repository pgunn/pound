#!/usr/bin/perl -w

use strict;
use DBI;
package MyApache::POUND::POUNDLj;

# A wrapper for the livejournal module

require Exporter;
require AutoLoader;
use LJ::Simple;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDDB;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(lj_post lj_update lj_login ljinfo_for_blog get_ljitem save_ljitem lj_last_posttime);
our @EXPORT = @EXPORT_OK;

sub lj_fill
{ # Called by lj_post and lj_update to fill in an entry
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $lje		= $args->mandate('lj_entry');
my $attrs	= $args->mandate('attrs');
my $entry	= $args->mandate('contents');
my $title	= $args->mandate('title');
my $lj		= $args->mandate('ljobj');
$args->argok();

my @e_tags = keys %{$$attrs{topic}};

if(length($title) > 0)
	{
	my $cleansubj = substr($title,0,254);
	$cleansubj =~ tr/\n//d;
	if(! $lj->SetSubject($lje, $cleansubj) )
		{
		return(0, "Title [$cleansubj] was not kosher");
		}
	}
$lj->SetEntry($lje, $entry);
$lj->Setprop_taglist($lje, @e_tags);

foreach my $misctype (keys %{$$attrs{misc}})
	{
	foreach my $miscval (@{$$attrs{misc}{$misctype}})
		{
		if($misctype =~ /Music/i)
			{
			$lj->Setprop_current_music($lje, $miscval);
			}
		elsif($misctype =~ /Mood/i)
			{
			$lj->SetMood($lje, $miscval);
			}
		}
	}
return 1;
}

sub lj_post
{ # Post a new entry. 
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $lj		= $args->mandate('ljobj');
my $zeit	= $args->mandate('zeit');
my $title	= $args->mandate('title');
my $entry	= $args->mandate('contents');
my $isold	= $args->mandate('is_old');
my $attrs	= $args->mandate('attrs');
$args->argok();

my %stupid; # $%$#^%^$# bloody stupid interface!
if(! $lj->NewEntry(\%stupid) )
	{
	return (0, "Failed to make a new entry");
	}
if($isold)
	{ 	# Do not do this lightly! Backdating is needed to set old dates,
		# but prevents things from showing up in friends lists
	$lj->Setprop_backdate(\%stupid, 1);
	}
$lj->SetDate(\%stupid, $zeit);

my ($ok, $msg) = lj_fill(lj_entry => \%stupid, attrs => $attrs, ljobj => $lj, contents => $entry, title => $title);
if(! $ok)
	{return ($ok, $msg);}

my ($itemid, $anum, undef) = $lj->PostEntry(\%stupid);
if(! defined($itemid))
	{
	return(0, $LJ::Simple::error);
	}
return (1, "OK", $itemid);
}

sub get_ljitem
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $eid = $args->mandate('entryid');
$args->argok();

my $dbh = db_connect();
my $dbq = $dbh->prepare("SELECT itemid FROM ljitem WHERE beid=?");
$dbq->execute($eid);
my $itemid = get_dbval($dbq);
if(! defined($itemid)) {return undef;}
return $itemid;
}

sub save_ljitem
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $eid		= $args->mandate('entryid');
my $ljitem	= $args->mandate('ljitemid');
$args->argok();

my $dbh = db_connect();
if(! get_ljitem(entryid => $eid) )
	{
	my $dbq = $dbh->prepare("INSERT INTO ljitem(beid,itemid) VALUES(?,?)");
	$dbq->execute($eid, $ljitem);
	}
}

sub lj_update
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $lj		= $args->mandate('ljobj');
my $ljeid	= $args->mandate('ljentryid');
my $title	= $args->mandate('title');
my $entry	= $args->mandate('contents');
my $attrs	= $args->mandate('attrs');
$args->argok();

my %stupids;
if(! $lj->GetEntries(\%stupids, undef, 'one', $ljeid) )
	{return(0, "GetEntries failed");}
# %stupids now has one entry (hopefully) with our entry in it.
my $winnage;
my @res = keys %stupids;
if(@res != 1)
	{return(0, "Failed to find entry\n");}

$winnage = $res[0];
if(! defined($winnage))
        {return(0, "Failed to access entry\n");}

my %holder = %{$stupids{$winnage}};
my ($ok, $msg) = lj_fill(lj_entry => \%holder, attrs => $attrs, ljobj => $lj, contents => $entry, title => $title);
if(! $ok)
	{return ($ok, $msg);}

if(! $lj->EditEntry(\%holder) )
	{
	return(0, "Failed to edit entry: $LJ::Simple::error");
	}
return(1, "OK");
}

sub lj_login
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $user	= $args->mandate('user');
my $pass	= $args->mandate('pass');
$args->argok();

my $errstr;
my $failed = 0;
my $lj = new LJ::Simple( { user => $user, pass => $pass} );
if(! defined($lj))
	{
	$failed = 1;
	$errstr = $LJ::Simple::error;
	}
return ($lj, $failed, $errstr);
}

sub ljinfo_for_blog
{ # If there exists a linked lj account for the blog, retrieve its login info
  # Else return error
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogid = $args->mandate('blogid');
$args->argok();

my $dbh = db_connect();
my $dbq = $dbh->prepare("SELECT ljid FROM blog WHERE id=?");
$dbq->execute($blogid);
my $ljid = get_dbval($dbq);
$dbq->finish();
if(! $ljid)
	{return (0, undef, undef);}
my $dbq2 = $dbh->prepare("SELECT username,pass FROM lj WHERE id=?");
$dbq2->execute($ljid);
my %res = get_dbresults($dbq2);
$dbq2->finish();
release_db($dbh);
return (1, $res{username}, $res{pass});
}

sub lj_last_posttime
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $lj = $args->mandate('ljobj');
$args->argok();

my %gehook = ();
my $ok = $lj->GetEntries(\%gehook, undef, 'one', -1);
my $ehdl = (keys(%gehook))[0];
if(! defined($ok) || (! $ehdl))
	{return (undef, "No entries found or GetEntries failed");}
my $returner = $lj->GetDate($gehook{$ehdl});
return ($returner, "Ok");
}

1;
