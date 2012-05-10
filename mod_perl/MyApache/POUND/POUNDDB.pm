#!/usr/bin/perl

# General database code.
# Many of the functions here do not use Argpass - this is so they continue to resemble the DBI calls.

use strict;
use DBI;
package MyApache::POUND::POUNDDB;
use MyApache::POUND::Argpass;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(db_connect release_db get_dbresults get_dbcol get_dbval db_get_attr_from_id db_set_attr_with_id);
our @EXPORT = @EXPORT_OK;

sub db_connect
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $dbuser	= $args->accept("db_user", "apache");
my $dbpass	= $args->accept("db_user", "posterkid");
my $dbdb	= $args->accept("db_db", "pound");
$args->argok();

my $dbh = DBI->connect("dbi:Pg:dbname=$dbdb", $dbuser, $dbpass);
if($dbh->ping)
	{
#	if($debug) {print "Connected";}
	}
else    
	{die "Not connected: $!\n";}
return $dbh;
}

sub release_db($)
{
my ($dbh) = @_;
$dbh->disconnect();
}

sub get_dbresults($)
{ # Returns a proper hash instead of a reference to one, for FIRST record returned
my ($dbq) = @_;
my $reshdl = $dbq->fetchrow_hashref();
my %returner;
if(defined($reshdl))
	{
	%returner = %$reshdl;
	}
return %returner;
}

sub get_dbcol($)
{ # No fetchcol_array, so pass me an executed statement
# and I'll fake it for you. 
my ($dbq) = @_;
my $reshdl = $dbq->fetchall_arrayref();
return map{$$_[0]} @{$reshdl};
}

sub get_dbval($)
{ 	# Return result from a query that at most generates a single value
	# Is this the fastest way to do this?!
my ($dbq) = @_;
my $res = $dbq->fetchall_arrayref();
return $$res[0][0];
}

sub db_get_attr_from_id
{ # Given a unique column in a table and a value for it, retrieve a named other element of the tuple uniquely identified by that.
	# NOTE: Unvalidated input would be a bad thing to mix in.
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $ident_f	= $args->accept('ident_field', 'id'); # Assume 'id' is the name of the field unless told otherwise
my $ident_v	= $args->mandate('ident_value');
my $table	= $args->mandate('table'); # Name of the table
my $req		= $args->mandate('requested'); # Field requested..
$args->argok();

my $dbh = db_connect();
my $genq = $dbh->prepare("SELECT $req FROM $table WHERE $ident_f=?");
$genq->execute($ident_v);
my $rep = $genq->fetchrow_hashref();
$genq->finish();
return $$rep{$req};
}

sub db_set_attr_with_id
{ # Like db_get_attr_from_id, but updates a named tuple member instead
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $ident_f	= $args->accept('ident_field', 'id'); # Assume 'id' is the name of the field unless told otherwise
my $ident_v	= $args->mandate('ident_value');
my $table	= $args->mandate('table'); # Name of the table
my $req		= $args->mandate('requested'); # Field to update
my $val		= $args->mandate('value'); # New value
$args->argok();

my $dbh = db_connect();
my $genq = $dbh->prepare("UPDATE $table SET $req=? WHERE $ident_f=?");
$genq->execute($val, $ident_v);
$genq->finish();
return;
}

1;
