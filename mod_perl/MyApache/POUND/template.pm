#!/usr/bin/perl -w

use strict;
use DBI;
package MyApache::POUND::POUNDtemplate;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dbhi);
our @EXPORT = @EXPORT_OK;

sub dbhi
{
print "Hi there!\n";
}

1;
