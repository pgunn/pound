#!/usr/bin/perl

# Database code for managing configuration options.

use strict;
use DBI;
package MyApache::POUND::POUNDConfigDB;

use MyApache::POUND::POUNDDB;
use MyApache::POUND::Argpass;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(get_configkey get_configkey_type get_configkey_description describe_config_type set_configkey list_configkeys get_configkeys get_pathkey get_pathkey_description set_pathkey list_pathkeys get_pathkeys db_register_pathkey db_register_configkey);
our @EXPORT = @EXPORT_OK;

sub get_configkey
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $key = $args->mandate('keyname');
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT value FROM config WHERE name=?");
$cq->execute($key);
my $returner = get_dbval($cq);
$cq->finish();
release_db($dbh);
return $returner;
}

sub get_configkey_description
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $key = $args->mandate('keyname');
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT description FROM config WHERE name=?");
$cq->execute($key);
my $returner = get_dbval($cq);
$cq->finish();
release_db($dbh);
return $returner;
}

sub get_configkey_type
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $key = $args->mandate('keyname');
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT avalues FROM config WHERE name=?");
$cq->execute($key);
my $returner = get_dbval($cq);
$cq->finish();
release_db($dbh);
return $returner;
}

sub set_configkey
{ # TODO Error checking
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $key		= $args->mandate('keyname');
my $value	= $args->mandate('value');
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("UPDATE config SET value=? WHERE name=?");
$cq->execute($value, $key);
$cq->finish();
}

sub list_configkeys
{ # Just gives names
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT name FROM config");
$cq->execute();
my @returner = get_dbcol($cq);
$cq->finish();
release_db($dbh);
return @returner;
}

sub get_configkeys
{ # Just gives names
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT name,value,description,avalues FROM config");
$cq->execute();
my %returner;
while(my %key = get_dbresults($cq))
	{
	$returner{$key{name}}{value} = $key{value};
	$returner{$key{name}}{description} = $key{description};
	$returner{$key{name}}{avalues} = $key{avalues};
	}
$cq->finish();
release_db($dbh);
return %returner;
}

sub describe_config_type
{ # Not actually a database call, but belongs here with the rest. Given an
  # avalue, tells the user what values are kosher for it
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $keytype = $args->mandate('keytype');
$args->argok();

if($keytype eq 'b')
	{return "Binary: 0 = false, 1 = true";}
elsif($keytype eq 't')
	{return "Text";}
elsif($keytype eq 't[URL]')
	{return q{Text (URL, e.g. "http://www.foo.com/somewhere")} }
elsif($keytype =~ /^i(\[.*\])?/)
	{return "Integer $1";}
else
	{return "Non-described keytype $keytype - this is probably a bug!";}
}

sub db_register_configkey
{
my $args = Argpass::new('clean', @_);
my $keyname = $args->mandate('keyname');
my $descrip = $args->mandate('description');
my $default = $args->accept('value', undef);
my $avals   = $args->accept('avalues', undef);
$args->argok();

my $dbh = db_connect();
my $rpq = $dbh->prepare("INSERT INTO config(name,value,description,avalues) VALUES(?,?,?,?)");
$rpq->execute($keyname, $default, $descrip, $avals);
}

# ---

sub db_register_pathkey
{
my $args = Argpass::new('clean', @_);
my $keyname = $args->mandate('keyname');
my $descrip = $args->mandate('description');
my $default = $args->accept('value', undef);
$args->argok();

my $dbh = db_connect();
my $rpq = $dbh->prepare("INSERT INTO pathconfig(name,value,description) VALUES(?,?,?)");
$rpq->execute($keyname, $default, $descrip);
}

sub get_pathkey
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $key = $args->mandate('keyname');
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT value FROM pathconfig WHERE name=?");
$cq->execute($key);
my $returner = get_dbval($cq);
$cq->finish();
release_db($dbh);
return $returner;
}

sub get_pathkey_description
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $key = $args->mandate('keyname');
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT description FROM pathconfig WHERE name=?");
$cq->execute($key);
my $returner = get_dbval($cq);
$cq->finish();
release_db($dbh);
return $returner;
}

sub set_pathkey
{ # TODO Error checking
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $key		= $args->mandate('keyname');
my $value	= $args->mandate('value');
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("UPDATE pathconfig SET value=? WHERE name=?");
$cq->execute($value, $key);
$cq->finish();
}

sub list_pathkeys
{ # Just gives names
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT name FROM pathconfig");
$cq->execute();
my @returner = get_dbcol($cq);
$cq->finish();
release_db($dbh);
return @returner;
}

sub get_pathkeys
{ # Just gives names
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

my $dbh = db_connect();
my $cq = $dbh->prepare("SELECT name,value,description FROM pathconfig");
$cq->execute();
my %returner;
while(my %key = get_dbresults($cq))
	{
	$returner{$key{name}}{value} = $key{value};
	$returner{$key{name}}{description} = $key{description};
	$returner{$key{name}}{avalues} = $key{avalues};
	}
$cq->finish();
release_db($dbh);
return %returner;
}


1;
