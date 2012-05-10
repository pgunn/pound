#!/usr/bin/perl

use strict;
use DBI;
package MyApache::POUND::POUNDThemes;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::Argpass;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(get_all_themeids theme_name theme_descrip theme_id_by_name);
our @EXPORT = @EXPORT_OK;

sub get_all_themeids
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

my $dbh = db_connect();
my $tiq = $dbh->prepare("SELECT id FROM theme ORDER BY id");
$tiq->execute();
my @returner = get_dbcol($tiq);
$tiq->finish();
release_db($dbh);
return @returner;
}

sub theme_name
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $tid = $args->mandate('themeid');
$args->argok();

my $dbh = db_connect();
my $tiq = $dbh->prepare("SELECT name FROM theme WHERE id=?");
$tiq->execute($tid);
my $returner = get_dbval($tiq);
$tiq->finish();
release_db($dbh);
return $returner;
}

sub theme_id_by_name
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $tname = $args->mandate('themename');
$args->argok();

my $dbh = db_connect();
my $tiq = $dbh->prepare("SELECT id FROM theme WHERE name=?");
$tiq->execute($tname);
my $returner = get_dbval($tiq);
$tiq->finish();
release_db($tiq);
return $returner;
}

sub theme_descrip
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $tid = $args->mandate('themeid');
$args->argok();

my $dbh = db_connect();
my $tiq = $dbh->prepare("SELECT descrip FROM theme WHERE id=?");
$tiq->execute($tid);
my $returner = get_dbval($tiq);
$tiq->finish();
release_db($dbh);
return $returner;
}

1;
