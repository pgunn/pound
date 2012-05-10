#!/usr/bin/perl

use strict;
use DBI;
use MIME::Types;
package MyApache::POUND::POUNDFilesDB;

require Exporter;
require AutoLoader;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(file_exists all_fileinfo_from_id db_wipe_file file_wipe_file get_all_files db_register_file_blob blob_writefile blob_readfile);
our @EXPORT = @EXPORT_OK;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDUser;

# FIXME - Need to split off Postgres-specific parts into a separate file for
# 	modularity

sub file_exists
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $name	= $args->mandate('filename');
my $ns		= $args->mandate('namespace');
my $ver		= $args->accept('version', undef);
my $var		= $args->accept('variant', undef);
$args->argok();

my $dbh = db_connect();
my @args;
push(@args, $name, $ns);
my $extra='';

	{ # Build the @args array
	if(defined $ver)
		{
		$extra .= "AND version=?";
		push(@args, $ver);
		}
	if(defined($var))
		{
		$extra .= "AND variant=?";
		push(@args, $var);
		}
	}

my $feq = $dbh->prepare("SELECT id FROM files WHERE name=? AND namespace=? $extra");
$feq->execute(@args);
my %res = get_dbresults($feq);
$feq->finish();
release_db($dbh);
return $res{id};
}

sub all_fileinfo_from_id
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $fileid = $args->mandate('file_id');
$args->argok();

my $dbh = db_connect();
my $aq = $dbh->prepare("SELECT * FROM files WHERE id=?");
$aq->execute($fileid);
my @returner = get_dbresults($aq);
$aq->finish();
release_db($dbh);
return @returner;
}

sub db_wipe_file
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $fileid	= $args->mandate('file_id');
my $blobid	= $args->accept('blob_id');
$args->argok();

my $dbh = db_connect();
my $ber = $dbh->prepare("DELETE FROM pg_largeobject WHERE loid=?");
$ber->execute($blobid);
my $dbwf = $dbh->prepare("DELETE FROM files WHERE id=?");
$dbwf->execute($fileid);
$dbwf->finish();
release_db($dbh);
return 1; # XXX ?
}

sub file_wipe_file
{ # XXX Note that this will not not remove the file and all its variants from the filesystem. Should it?
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $fileid	= $args->mandate('file_id');
my $filename	= $args->mandate('filename');
$args->argok();

my $dbh = db_connect();
unlink($filename);
my $dbwf = $dbh->prepare("DELETE FROM files WHERE id=?");
$dbwf->execute($fileid);
$dbwf->finish();
release_db($dbh);
return 1; # XXX ?
}

sub get_all_files
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $owner	= $args->accept('owned_by', undef);
$args->argok();

my $dbh = db_connect();
my $extra = '';
if(defined $owner)
	{
	my $creatorid = uid_from_login(login => $owner);
	$extra = "WHERE creator=$creatorid";
	}
my $gafq = $dbh->prepare("SELECT * FROM files $extra");
$gafq->execute();
my @res;
while (my %file = get_dbresults($gafq)) # Hashes evaluate to false if they have no keys
	{ # Let's just pass back a list...
	push(@res, \%file);
	}
release_db($dbh);
return \@res;
}

sub db_register_file_blob
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $fn		= $args->mandate('name');
my $ns		= $args->mandate('namespace');
my $blobid	= $args->mandate('blobid');
my $time	= $args->mandate('timehere');
my $version	= $args->mandate('version');
my $filetype	= $args->mandate('filetype');
my $mimetype	= $args->mandate('mimetype');
my $creator	= $args->mandate('creator');
$args->argok();

my $dbh = db_connect();
my $dbr = $dbh->prepare("INSERT INTO files(name,namespace,creator,storetype,blobid,timehere,version,filetype,mimetype) VALUES(?,?,?,'blob',?,?,?,?,?)");
$dbr->execute($fn,$ns,$creator,$blobid,$time,$version,$filetype,$mimetype);
release_db($dbh);
# FIXME error checking would be nice
}

# ---

sub blob_writefile
{ # TODO eventually move to POUNDFilesDB?
  # 
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $datref	= $args->mandate('datref');
$args->argok();

my $dbh = db_connect();
my $lobj = $dbh->func($dbh->{pg_INV_WRITE}|$dbh->{pg_INV_READ}, 'lo_creat');
if(! defined($lobj))
	{errorpage(text => "lo_creat failed");} # FIXME Try to give a better error than this! Sheesh
#else
#	{print "New object with id $lobj\n";}
$dbh->{'AutoCommit'} = 0;
my $lod = $dbh->func($lobj, $dbh->{pg_INV_WRITE}, 'lo_open');
if(! defined($lod))
	{die "lo_open failed\n";}

my $nbytes = $dbh->func($lod, $$datref, length($$datref), 'lo_write');
if(! defined $nbytes)
	{errorpage(text => "lo_write failed");} # FIXME Again, ....

$dbh->func($lod, 'lo_close');
$dbh->commit();
$dbh->{'AutoCommit'} = 1;

release_db($dbh);
return $lobj; # FIXME If it fails partway through, we should probably delete the partial lobj made by lo_creat rather than leave crumbs
}

sub blob_readfile
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
my $bid = $args->mandate('blobid');
$args->argok();

my $data = '';
# Postgres-specific code
my $dbh = db_connect();
		$dbh->{'AutoCommit'} = 0; # Not sure why I need to do this, but it seems to be necessary for BLOB operations
		my $loreid = $dbh->func($bid, $dbh->{pg_INV_READ}, 'lo_open');
		if(! defined($loreid) )
			{
			$apache_r->content_type('text/plain');
			die "lo_open failed\n";
			}
my $databit;
while($dbh->func($loreid, $databit, 10000, 'lo_read') )
	{	# Read in 10k chunks at a time.
		# Maybe performance-tune this later.
	$data .= $databit;
	$databit='';
	}
$dbh->func($loreid, 'lo_close');
$dbh->commit();
$dbh->{'AutoCommit'} = 1;
release_db($dbh);
return $data;
}

1;
