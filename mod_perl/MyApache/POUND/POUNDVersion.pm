#!/usr/bin/perl

# Just handles version code

use strict;
use DBI;
package MyApache::POUND::POUNDVersion;

# This doesn't work as automagically as I would like.

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(poundversion);
our @EXPORT = @EXPORT_OK;

sub poundversion
{
my $returner = "4.2";
return $returner;
}

2;
