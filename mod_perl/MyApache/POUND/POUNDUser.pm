#!/usr/bin/perl

# Handles user-related code from the database.

use strict;
use DBI;
package MyApache::POUND::POUNDUser;

require Exporter;
require AutoLoader;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDDB;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(uid_from_login login_from_uid descrip_from_uid get_personinfo name_from_userid login_match uid_set_name uid_set_weburl uid_set_descrip uid_set_pass uid_can_wiki uid_is_super uid_set_theme make_account uid_can_upload uid_blogs);
our @EXPORT = @EXPORT_OK;

sub uid_from_login
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $login 	= $args->mandate("login");
my $reqv	= $args->accept("validated_only", 1);
$args->argok();

my $valid_string = "AND validated=true";
if(! $reqv)
	{$valid_string = "";}

my $dbh = db_connect();
my $lq = $dbh->prepare("SELECT id FROM person WHERE login=? $valid_string");
$lq->execute($login);
my %res = get_dbresults($lq);
$lq->finish();
release_db($dbh);
if(! defined($res{id}))
	{return 0;}
return $res{id};
}

sub login_from_uid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid = $args->mandate("uid");
$args->argok();

return db_get_attr_from_id(	ident_value => $uid,
				table => 'person',
				requested => 'login');
}

sub descrip_from_uid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid = $args->mandate("uid");
$args->argok();

return db_get_attr_from_id(	ident_value => $uid,
				table => 'person',
				requested => 'descrip');
}

sub get_personinfo
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid = $args->mandate("uid");
$args->argok();

my $dbh = db_connect();
my $lq = $dbh->prepare("SELECT * FROM person WHERE id=?");
$lq->execute($uid);
my %person = get_dbresults($lq);
$lq->finish();
release_db($dbh);
return %person;
}

sub name_from_userid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid = $args->mandate("userid");
$args->argok();

return db_get_attr_from_id(	ident_value => $uid,
				table => 'person',
				requested => 'name');
}

sub login_match
{ # True if login matches
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $user = $args->mandate("user");
my $pass = $args->mandate("pass");
$args->argok();

my $dbh = db_connect();
my $lq = $dbh->prepare("SELECT id FROM person WHERE login=? AND pass=? AND validated=true");
$lq->execute($user,$pass);
my @rhol = get_dbcol($lq);
$lq->finish();
release_db($dbh);
if(@rhol > 0)
	{return $rhol[0];}
return undef;
}

sub uid_set_name
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid = $args->mandate("userid");
my $name= $args->mandate("name");
$args->argok();

my $dbh = db_connect();
my $unq = $dbh->prepare("UPDATE person SET name=? WHERE id=?");
$unq->execute($name, $uid);
$unq->finish();
release_db($dbh);
}

sub uid_set_weburl
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("userid");
my $weburl	= $args->mandate("web_url");
$args->argok();

my $dbh = db_connect();
my $uwq = $dbh->prepare("UPDATE person SET weburl=? WHERE id=?");
$uwq->execute($weburl, $uid);
$uwq->finish();
release_db($dbh);
}

sub uid_set_theme
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("userid");
my $theme	= $args->mandate("theme");
$args->argok();

my $dbh = db_connect();
my $uwq = $dbh->prepare("UPDATE person SET sitetheme=? WHERE id=?");
$uwq->execute($theme, $uid);
$uwq->finish();
release_db($dbh);
}

sub uid_set_descrip
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("userid");
my $descrip	= $args->mandate("description");
$args->argok();

my $dbh = db_connect();
my $udq = $dbh->prepare("UPDATE person SET descrip=? WHERE id=?");
$udq->execute($descrip, $uid);
$udq->finish();
release_db($dbh);
}

sub uid_set_pass
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("userid");
my $pass	= $args->mandate("password");
$args->argok();

my $dbh = db_connect();
my $udq = $dbh->prepare("UPDATE person SET pass=? WHERE id=?");
$udq->execute($pass, $uid);
$udq->finish();
release_db($dbh);
}

sub uid_can_wiki
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("userid");
$args->argok();

return db_get_attr_from_id(	table => 'person',
				ident_value => $uid,
				requested => 'can_wiki');
}

sub uid_is_super
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("userid");
$args->argok();

return db_get_attr_from_id(	table => 'person',
				ident_value => $uid,
				requested => 'is_super');
}

sub uid_can_upload
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid		= $args->mandate("userid");
$args->argok();

return db_get_attr_from_id(	table => 'person',
				ident_value => $uid,
				requested => 'can_upload');
}

sub make_account
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $name 	= $args->mandate("name");
my $login	= $args->mandate("login");
my $pass 	= $args->mandate("pass");
my $weburl 	= $args->accept("weburl", "");
my $descrip 	= $args->accept("descrip", "");
my $validated 	= $args->accept("valid", 0);
my $is_super 	= $args->accept("super", 0);
my $can_wiki	= $args->accept("wiki", 0);
my $picurl	= $args->accept("picurl", "");
$args->argok();

my $dbh = db_connect();
my $unq = $dbh->prepare("INSERT INTO person(login,pass,name,weburl,descrip,can_wiki,is_super,picurl,validated) values(?,?,?,?,?,?,?,?,?);");
$unq->execute($login, $pass, $name, $weburl, $descrip, $can_wiki, $is_super, $picurl, $validated);
$unq->finish();
release_db($dbh);
if(! uid_from_login(login => $login, validated_only => 0))
	{return (0, "Unknown failure");}
else
	{return (1, "OK");}
}

1;
