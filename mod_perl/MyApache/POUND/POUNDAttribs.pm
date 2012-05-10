#!/usr/bin/perl

# This is used by both pndc and POUND to parse attribute lists in messages.
# It's simple, but code drift is painful enough that it's best to use this
# package in both places.

use strict;
use DBI;
package MyApache::POUND::POUNDAttribs;

use MyApache::POUND::Argpass;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(parse_blog_attribs);
our @EXPORT = @EXPORT_OK;

sub parse_blog_attribs
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $msgref = $args->mandate('msgref');
$args->argok();

my %attr; # Hold attributes to return
my @attribstrs;
while($$msgref =~ s/\[\!(.*?)\]//)
	{push(@attribstrs, $1);}

foreach my $attribstr (@attribstrs)
	{
	print "Parse [$attribstr]\n";
	my ($attrib,$value) = split(/:/, $attribstr, 2);
	if($attrib =~ /topic/i)
		{
		$attr{topic}{$value}=1;
		}
	elsif( ($attrib =~ /subject/i) || ($attrib =~ /title/i) ) # Compatibility
		{
		print "Note title to be $value!\n";
		$attr{title}=$value;
		}
	elsif($attrib =~ /private/i)
		{
		$attr{private}=1;
		}
	elsif($attrib =~ /nocomment/i)
		{
		$attr{nocomment}=1;
		}
	elsif($attrib =~ /noacomment/i)
		{
		$attr{noacomment}=1;
		}
	elsif(! defined($value))
		{
		print "Ignoring unknown non-valued attribute $attrib\n";
		}
	else
		{
		print "Parsing misc attribute [$attrib] set to $value\n";
		push(@{$attr{misc}{$attrib}}, $value);
		}
	}
return %attr;
}

1;
