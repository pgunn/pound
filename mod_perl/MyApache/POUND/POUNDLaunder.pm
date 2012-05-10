#!/usr/bin/perl -w

use strict;
use DBI;
package MyApache::POUND::POUNDLaunder;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(launder);
our @EXPORT = @EXPORT_OK;

use MyApache::POUND::Argpass;

# Clean user inputs of various types.

sub launder
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $illicit	= $args->mandate('psst');
my $type	= $args->mandate('type');
my $action	= $args->accept('fail', 0); # Don't try to clean noncompliant input if set true, just return undef
my $apachewarn	= $args->accept('apache_warn', 1); # Print to STDERR any warnings, goes to apache's error_log
$args->argok();

my $ret;
if($type eq 'urllike')
	{ # Only http/https and relative-url syntax are kosher

	}
elsif($type eq 'pathlike')
	{ # 

	}
elsif($type eq 'path_component')
	{

	}
elsif($type eq 'filelike')
	{

	}
# ---
elsif($type eq 'markuplike')
	{

	}
elsif($type eq 'nohtml')
	{

	}
elsif($type eq 'val_or_key')
	{

	}
else
	{
	die "launder() does not know how to launder type [$type]\n"
	}
my $ret;
}

1;
