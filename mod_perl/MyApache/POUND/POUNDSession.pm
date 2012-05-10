#!/usr/bin/perl

# Manage sessions for user

use strict;
use DBI;
package MyApache::POUND::POUNDSession;

require Exporter;
require AutoLoader;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::POUNDApache;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(create_session session_uid session_logout apache_session_key);
our @EXPORT = @EXPORT_OK;

sub create_session
{ 	# Given login info, creates a session cookie, stores it in the db
	# and gives to the user
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $userid	= $args->mandate('userid');
$args->argok();

if(get_session_by_uid(userid => $userid)) # One login per user
	{clear_session_by_uid(userid => $userid);}
my $expires = time() + 600000; # About a week, I think
my $mcookie = db_create_session(userid => $userid, expires => $expires);
set_cookie(apacheobj => $apache_r, cookiename => 'mcookie', value => $mcookie);
}

sub session_uid
{ # Retrieves cookie from user, returns userid if user is logged in
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
$args->argok();

my $sessionkey = apache_session_key(apacheobj => $apache_r);
if(! defined($sessionkey))
	{return undef;}
my $userid = get_session_by_mcookie(mcookie => de_post_mangle(post_in => $sessionkey));
if(! defined($userid))
	{return undef;}
return $userid;
}

sub apache_session_key
{ # Gets the session key from the apache_r object..
	# This is a shorthand, used so the form stuff can use this to guard
	# against external posts.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

return get_cookie(apacheobj => $apache_r, cookiename => 'mcookie');
}

sub session_logout
{ # Clears session from database and from browser
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
$args->argok();

my $sessionkey = get_cookie(apacheobj => $apache_r, cookiename => 'mcookie');
if($sessionkey)
	{
	my $uid = get_session_by_mcookie(mcookie => $sessionkey);
	clear_session_by_uid(userid => $uid);
	}
delete_cookie(apacheobj => $apache_r, cookiename => 'mcookie');
}

#################### Private methods ##################
sub get_session_by_uid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $userid = $args->mandate('userid');
$args->argok();

my $dbh = db_connect();
my $seq = $dbh->prepare("SELECT id FROM weblogin WHERE userid=?");
$seq->execute($userid);
my @results = get_dbcol($seq);
$seq->finish();
release_db($dbh);
if(defined($results[0]))
	{return $results[0];} # Sequence, so will not ever be 0
else {return 0;}
}

sub clear_session_by_uid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $userid = $args->mandate('userid');
$args->argok();

my $dbh = db_connect();
my $seq = $dbh->prepare("DELETE FROM weblogin WHERE userid=?");
$seq->execute($userid);
$seq->finish();
release_db($dbh);
}

sub get_session_by_mcookie
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $mcookie = $args->mandate('mcookie');
$args->argok();

my $dbh = db_connect();
my $seq = $dbh->prepare("SELECT userid FROM weblogin WHERE mcookie=? AND expires > ?");
$seq->execute($mcookie, time() );
my @results = get_dbcol($seq);
$seq->finish();
release_db($dbh);
if(defined($results[0]))
	{return $results[0];}
else {return undef;}
}

sub db_create_session
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $userid	= $args->mandate('userid');
my $expires	= $args->mandate('expires');
$args->argok();

my $magic_key = generate_magic_key();
while(get_session_by_mcookie(mcookie => $magic_key))
	{
	$magic_key = generate_magic_key();
	}
my $dbh = db_connect();
my $crs = $dbh->prepare("INSERT INTO weblogin(userid,expires, mcookie) VALUES(?,?,?)");
$crs->execute($userid, $expires, $magic_key);
$crs->finish();
release_db($dbh);
return $magic_key;
}

sub generate_magic_key
{ # FIXME This could be done a lot better
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

return int rand(100000);
}

1;
