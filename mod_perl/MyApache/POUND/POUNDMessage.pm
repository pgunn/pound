#!/usr/bin/perl -w

use strict;
package MyApache::POUND::POUNDMessage;
use DBI;
use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDDB;

###########################################
# Manage a queue of things that users want to be
# notified about. This module will be both used by the POUND
# mod_perl component and a daemon that periodically examines the
# database for things to do. Said module should handle the
# notification part using its own modules - the mod_perl component
# doesn't need to know about IM/email/web notifications, even if it
# shares this module and the database with software tools that do.
#
# Note as well that this does not manage the hooks that generate the
# messages in responses to events.
###########################################

###########################################
# CREATE TABLE msgmeths
# (
# id SERIAL PRIMARY KEY NOT NULL,
# uid INTEGER REFERENCES person NOT NULL, -- Note that this is not unique - a person can have multiple such prefs, will go to all set
# method VARCHAR(10) NOT NULL, -- Yeah yeah, whatever. It's inefficient. Whatever. Present OK values are 'email', 'xmpp', 'web'
# username VARCHAR(30), -- first part of username@host - used by email and xmpp so far
# hostname VARCHAR(50), -- latter part of username@host - also used by email and xmpp so far
# validreq TIMESTAMP,  -- When the user requested validation..
# passkey VARCHAR(50), -- Generated when user registers a new notification method, user gets one notification through the method
# 			-- asking them to go to an URL that contains this passkey, after which the method is marked as ok.
# 			-- naturally, we need to add a handler for that. URL could be something like
# 			-- /pound/notify/validate/$uid/$meth/passkey ?
# valid BOOLEAN DEFAULT('f') NOT NULL -- prevent spam
# );
#
# CREATE TABLE messages
# (
# id SERIAL PRIMARY KEY NOT NULL,
# recipient INTEGER REFERENCES person NOT NULL,
# class VARCHAR(20), -- Or should this be an integer? Hmm...
# autodisarm BOOLEAN NOT NULL,
# subject VARCHAR(80) NOT NULL,
# body TEXT NOT NULL,
# lastnagged TIMESTAMP
# );
###########################################

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(add_msg ls_msgs get_msg rm_msg msg_update_nagtime add_notify_method ls_notify_methods get_notify_method rm_notify_method prep_notify_validate try_validate get_notify_methods);
our @EXPORT = @EXPORT_OK;

sub add_msg
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("user_id");
my $subj	= $args->accept("subject", "POUND Notification");
my $msg		= $args->mandate("body");
my $class	= $args->accept("class", 'GENERAL'); # Make this more meaningful later
my $autod	= $args->accept("auto_disarm", 1); # Whether to remove from queue after send or if
						# some kind of a response is required
$args->argok();

my $dbh = db_connect();
my $msga = $dbh->prepare("INSERT INTO messages(recipient,class,autodisarm,subject,body) VALUES (?,?,?,?,?)");
$msga->execute($uid, $class, $autod, $subj, $msg);
# XXX Probably should do error checking?
# FIXME Consider either making a wrapper that does so or having this refuse to add messages for users that don't
# have a delivery method set..
}

sub ls_msgs
{ # FIXME Add option to select only messages with either NULL "lastnagged" or within a specified distance of that value
  # (which will facilitate timed nagging...)
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->accept("for_user_id", undef); # By default, list events for all users
my $nagdist	= $args->accept("nag_dist", undef); # If set, return only:
						# 1) messages that clear-on-send AND
						# 2) messages that nag that have not nagged for nag_dist
						#	hours
$args->argok();
my $dbh = db_connect();
my $lsm;
my $extra_str = "";
my @extra_cnst;
my @extra_flds;

if(defined $uid)
	{
	push(@extra_cnst, "recipient = ?");
	push(@extra_flds, $uid);
	}
if(defined $nagdist)
	{
	push(@extra_cnst, "(lastnagged + interval ? < now() )"); # XXX Needs testing!
	push(@extra_flds, "$nagdist hours");
	}
if(scalar(@extra_cnst))
	{
	$extra_str = " WHERE " . join(" AND ", @extra_cnst);
	}
$lsm = $dbh->prepare("SELECT id FROM messages$extra_str");
$lsm->execute(@extra_flds);

my @msgids = get_dbcol($lsm);
release_db($dbh);
return @msgids;
}

sub get_msg
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $qid = $args->mandate("message_id");
$args->argok();

my $dbh = db_connect();
my $gmq = $dbh->prepare("SELECT * FROM messages WHERE id = ?");
$gmq->execute($qid);
my %returner = get_dbresults($gmq);
$gmq->finish(); # Not sure why it nagged me about this....
release_db($dbh);
return %returner;
}

sub rm_msg
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $qid = $args->mandate("queueid");
$args->argok();

my $dbh = db_connect();
my $rmsg = $dbh->prepare("DELETE FROM messages WHERE id=?");
$rmsg->execute($qid);
# XXX Error checking?
}

sub msg_update_nagtime
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $qid = $args->mandate("queueid");
$args->argok();

my $dbh = db_connect();
my $unt = $dbh->prepare("UPDATE messages SET nagtime='now' WHERE id=?");
$unt->execute($qid);
}

sub add_notify_method
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("user_id");
my $method	= $args->mandate("method"); # right now, let's assume a protocol of 'email', 'xmpp', or 'web'
my $user	= $args->accept("username", ''); # Mandated by xmpp/email methods
my $host	= $args->accept("hostname", '');
$args->argok();

my $dbh = db_connect();
my $mna = $dbh->prepare("INSERT INTO msgmeths(uid,method,username,hostname) VALUES (?,?,?,?)");
$mna->execute($uid, $method, $user, $host); # If/when methods get more complex, split this up into separate db calls

}

sub get_notify_methods
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("user_id");
my $ivok	= $args->accept("invalid_ok", 0);
$args->argok();

my $suffix = "";
unless($ivok) {$suffix = "AND valid=true"}
my $dbh = db_connect();
my $gnm = $dbh->prepare("SELECT id FROM msgmeths WHERE uid=? $suffix");
$gnm->execute($uid);
my @gnms = get_dbcol($gnm);
release_db($dbh);
return @gnms;
}

sub get_notify_method
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $nmid = $args->mandate("method_id");
$args->argok();

my $dbh = db_connect();
my $gnm = $dbh->prepare("SELECT * FROM msgmeths WHERE id=");
$gnm->execute($nmid);
my %returner = get_dbresults($gnm);
release_db($dbh);
return %returner;
}

sub rm_notify_method
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $nmt	= $args->mandate("notify_method");
$args->argok();

my $dbh = db_connect();
my $rnm = $dbh->prepare("DELETE FROM msgmeths WHERE id=");
$rnm->execute($nmt);
release_db($dbh);
# XXX Error handling?
}

sub try_validate
{ # If succeeds, mark a given notify method as kosher
  # else fail
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $mid	= $args->mandate("methid");
my $skey= $args->mandate("submit_key");
$args->argok();

my $rkey = db_get_attr_from_id(	table=>'msgmeths',
				ident_value => $mid,
				requested => 'passkey');
if($skey != $rkey) # Failed validation attempt
	{return 0;}
my $dbh = db_connect();
my $upd = $dbh->prepare("UPDATE msgmeths SET valid=1 WHERE id=?");
$upd->execute($mid);
return 1;
}

sub prep_notify_validate
{ # Generate a new string which the user must provide, set the time of the req so people can't try forever, start accepting..
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $mid	= $args->mandate("methid");
$args->argok();

my $key = int rand(100000); # FIXME Kind of a lousy key...
my $dbh = db_connect();
my $pnv = $dbh->prepare("UPDATE msgmeths SET validreq='now',passkey=? WHERE id=?");
$pnv->execute($key, $mid);
}


1;
