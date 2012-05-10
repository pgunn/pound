#!/usr/bin/perl -w

use DBI;

fix_schema();

sub db_connect
{
my $dbh = DBI->connect("dbi:Pg:dbname=pound", "pgunn", $ARGV[0]);
if($dbh->ping)
	{
#	if($debug) {print "Connected";}
	}
else    
	{die "Not connected: $!\n";}
return $dbh;
}

sub fix_schema
{
my $dbh = db_connect();
my $dbq = $dbh->prepare("select tablename from pg_tables where schemaname=?");
$dbq->execute('public');
my @tables = get_dbcol($dbq);
foreach my $table (@tables)
	{
	print "Fix table $table\n";
	my $dbfix = $dbh->prepare("GRANT ALL ON $table to apache");
	$dbfix->execute();
	}
}

sub get_dbcol($)
{ # No fetchcol_array, so pass me an executed statement
# and I'll fake it for you. 
my ($dbq) = @_;
my $reshdl = $dbq->fetchall_arrayref();
return map{$$_[0]} @{$reshdl};
}
