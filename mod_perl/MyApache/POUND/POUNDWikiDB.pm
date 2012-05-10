#!/usr/bin/perl

use strict;
use DBI;
package MyApache::POUND::POUNDWikiDB;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::Argpass;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(wiki_page_exists wikeid_page_locked get_wiki_entry get_latest_article_version get_wiki_article new_wikventry make_new_wikentry get_all_page_titles get_all_wikversions_for_wikeid);
our @EXPORT = @EXPORT_OK;

sub wiki_page_exists
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $page = $args->mandate('pagename');
$args->argok();

my $dbh = db_connect();
my $equery = $dbh->prepare("SELECT id FROM wikentry WHERE title=?");
$equery->execute($page);
my $eres = $equery->fetchrow_hashref();
$equery->finish();
release_db($dbh);
if(defined($$eres{id}) )
	{
	return $$eres{id};
	}
else
	{
	return undef;
	}
}

sub wikeid_page_locked
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $wikeid = $args->mandate('wikentryid');
$args->argok();

return db_get_attr_from_id(	table => 'wikentry',
				ident_value => $wikeid,
				requested => 'locked');
}

sub get_wiki_entry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $page = $args->mandate('pagename');
$args->argok();

my $dbh = db_connect();
my $dbq = $dbh->prepare("SELECT * FROM wikentry WHERE title=?;");
$dbq->execute($page);
my %results = get_dbresults($dbq);
$dbq->finish();
release_db($dbh);
return %results;
}

sub get_wiki_article
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $wikeid	= $args->mandate('wikentryid');
my $version	= $args->mandate('version');
$args->argok();

my $dbh = db_connect();
my $returner;
my $dbq = $dbh->prepare("SELECT data FROM wikventry WHERE entry=? AND version=?");
$dbq->execute($wikeid, $version);
my $dbr = $dbq->fetchrow_hashref();
$returner = $$dbr{data};
$dbq->finish();
release_db($dbh);
return $returner;
}

sub get_latest_article_version
{ # Returns the version, not the article.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $wikeid	= $args->mandate('wikentryid');
$args->argok();

my $dbh = db_connect();
my $returner;
my $dbq = $dbh->prepare("SELECT version FROM wikventry WHERE entry=? ORDER BY version DESC");
$dbq->execute($wikeid);
my $dbr = $dbq->fetchrow_hashref();
$returner = $$dbr{version};
$dbq->finish();
release_db($dbh);
return $returner;
}

sub new_wikventry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $wikeid	= $args->mandate('wikentryid');
my $ver		= $args->mandate('version');
my $authorid	= $args->accept('userid', undef);
my $comments	= $args->mandate('comments');
my $text	= $args->mandate('data');
$args->argok();

my $dbh = db_connect();
my $extra_field="";
my $extra_value="";
if(defined($authorid))
	{
	$extra_field="author,";
	$extra_value="$authorid,";
	}
my $newwve = $dbh->prepare("INSERT INTO wikventry(entry,version," . $extra_field . "cmt,data) VALUES(?,?," . $extra_value . "?,?)");
$newwve->execute($wikeid,$ver,$comments,$text);
$newwve->finish();
release_db($dbh);
}

sub make_new_wikentry
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $title = $args->mandate('title');
$args->argok();

my ($pagetitle) = @_;
my $dbh = db_connect();
my $newwke = $dbh->prepare("INSERT INTO wikentry(title,locked) VALUES (?,'f')");
$newwke->execute($title);
$newwke->finish();
release_db($dbh);
}

sub get_all_page_titles
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

my $dbh = db_connect();
my $apq = $dbh->prepare("SELECT distinct title FROM wikentry ORDER BY title;");
$apq->execute();
my @returner = get_dbcol($apq);
$apq->finish();
release_db($dbh);
return @returner;
}

sub get_all_wikversions_for_wikeid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $wikeid = $args->mandate('wikentryid');
$args->argok();

my $dbh = db_connect();
my $vquery = $dbh->prepare("SELECT version,author,cmt FROM wikventry WHERE entry=? ORDER BY version DESC");
$vquery->execute($wikeid);
my @returner;
my $iter = 0;
while(my $results = $vquery->fetchrow_hashref() )
	{
	$returner[$iter]{version} = $$results{version};
	$returner[$iter]{author} = $$results{author};
	$returner[$iter]{cmt} = $$results{cmt};
	$iter++;
	}
$vquery->finish();
release_db($dbh);
return @returner;
}

1;
