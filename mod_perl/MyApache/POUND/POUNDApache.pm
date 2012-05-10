#!/usr/bin/perl

# This is to hold things that either deeply interact with Apache's guts, or deal with
# webservers in general. 

use strict;
use DBI;
package MyApache::POUND::POUNDApache;
use Apache2::Cookie;
use Apache2::Request;
use Apache2::Connection;
use Apache2::Const -compile => qw(:methods);
use URI::Escape;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(get_request_from_uri get_cookie set_cookie set_tcookie delete_cookie post_content de_post_mangle get_client_ip is_POST);
our @EXPORT = @EXPORT_OK;

use MyApache::POUND::Argpass;

sub get_request_from_uri
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uri = $args->mandate('uri');
$args->argok();

my ($cmd, @args);
my $basepath = MyApache::POUND::POUNDConfig::get_basepath();
$uri =~ s/\/$//g;
$uri =~ s/^\/$basepath\/?//;
@args = split /\//, $uri;
$cmd = shift(@args);
return ($cmd, @args);
}

sub get_cookie
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $cname	= $args->mandate('cookiename');
$args->argok();

my $cookies = Apache2::Cookie->fetch($apache_r);
if(defined($$cookies{$cname}))
	{
	if(defined($$cookies{$cname}->value()))
		{return $$cookies{$cname}->value();}
	}
return undef;
}

sub set_cookie
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $cname	= $args->mandate('cookiename');
my $cval	= $args->mandate('value');
$args->argok();

#my $c = new Apache2::Cookie(-name => $cname,
#		-value => $cval,
#		-expires => "+3M");
#$apache_r->headers_out->add("Set-Cookie" => $c);
my $c = Apache2::Cookie->new($apache_r, 
			-name => $cname, 
			-value => $cval,
			-path => '/',
			-expires => "+3M");
#$c->bake; # Documentation says to do this, but it doesn't work.
$apache_r->headers_out->add("Set-Cookie" => $c);
}

sub set_tcookie
{       # Temporary cookie
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $cname	= $args->mandate('cookiename');
my $cval	= $args->mandate('value');
$args->argok();

my $c = new Apache2::Cookie(-name => $cname,
			-value => $cval); # Expire when browser exits
$apache_r->headers_out->add("Set-Cookie" => $c);
}

sub delete_cookie
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $cname	= $args->mandate('cookiename');
$args->argok();

my $c = new Apache2::Cookie(-name => $cname,
			-expires => "-1d"); # Expires yesterday = Gone
$apache_r->headers_out->add("Set-Cookie" => $c);
}

sub post_content
{ # Much simpler, hopefully will work with POSTs that include files too
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

my %returner;
my $robj = Apache2::Request->new($apache_r);
my @rkeys = $robj->param();
foreach my $rkey (@rkeys)
	{
	$returner{$rkey} = $robj->param($rkey);
	}
return %returner;
}

sub de_post_mangle
{ # TODO: Make sure I'm using this properly everywhere
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $mangled = $args->mandate('post_in');
$args->argok();

$mangled =~ s/\+/ /g;
return uri_unescape($mangled);
}

sub get_client_ip
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

my $con = $apache_r->connection();
if(! defined($con))
	{die "Bad connection\n";}
my $sourceip = $con->remote_ip();
if(! defined($sourceip))
	{die "Bad remote host\n";}
return $sourceip;
}

sub is_POST
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

if($apache_r->method_number == Apache2::Const::M_POST() )
	{return 1;}
return 0; # Not a POST...
}

1;
