#!/usr/bin/perl

# Code to handle CSS. 

use strict;
use DBI;
package MyApache::POUND::POUNDCSS;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_csspage);
our @EXPORT = @EXPORT_OK;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDSession;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDDB;

sub css_defaults
{ # I thought about putting this in the database, but this is too useful for
  # demonstrating the format involved. I might provide a way for people to
  # override the default default theme using the database if people are
  # interested, instead, if people ask for it.
  # In any case, we at least know what tags need to be there from here.
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();


my %returner;
$returner{TAG}{body}{E} = "";
$returner{TAG}{body}{background} = "#aaaccc";
$returner{TAG}{body}{"font-family"} = q{"Verdana", sans-serif};
$returner{TAG}{body}{"margin"} = "0 0 0 0";
$returner{TAG}{body}{"font-size"} = q{10pt};

$returner{ID}{entrypart}{E} = "";
$returner{ID}{entrypart}{width} = "70%";
$returner{ID}{entrypart}{"margin-right"} = "12%";
$returner{ID}{entrypart}{float} = "right";

$returner{ID}{menupart}{float} = "right";
#$returner{ID}{menupart}{width} = "100px";
$returner{ID}{menupart}{width} = "15%";
$returner{ID}{menupart}{"margin-bottom"} = "1em";
$returner{ID}{menupart}{E} = "";

$returner{CLASS}{gmenu}{background} = "lightgrey";
$returner{CLASS}{gmenu}{color} = "black";
$returner{CLASS}{gmenu}{"-moz-border-radius"} = "10px";
$returner{CLASS}{gmenu}{"-webkit-border-radius"} = "10px";
$returner{CLASS}{gmenu}{"border-radius"} = "10px 10px";
$returner{CLASS}{gmenu}{border} = "2px solid #000";
$returner{CLASS}{gmenu}{"margin-right"} = "8px";
$returner{CLASS}{gmenu}{padding} = "8px";
$returner{CLASS}{gmenu}{E} = "";

$returner{CLASS}{jehead}{border} = "3px solid green";
$returner{CLASS}{jehead}{"-moz-border-radius"} = "10px";
$returner{CLASS}{jehead}{"-webkit-border-radius"} = "10px";
$returner{CLASS}{jehead}{"border-radius"} = "10px 10px";
$returner{CLASS}{jehead}{padding} = "2px";
$returner{CLASS}{jehead}{background} = "rgb(150,150,140)";

$returner{CLASS}{arentry}{background} = "lightgrey";
$returner{CLASS}{arentry}{color} = "black";
$returner{CLASS}{arentry}{B} = q{left: 0;};
$returner{CLASS}{arentry}{E} = "";

$returner{CLASS}{amentry}{background} = "lightgrey";
$returner{CLASS}{amentry}{color} = "black";
$returner{CLASS}{amentry}{E} = "";

$returner{CLASS}{tmentry}{background} = "lightgrey";
$returner{CLASS}{tmentry}{color} = "black";
$returner{CLASS}{tmentry}{B} = q{left: 0;};
$returner{CLASS}{tmentry}{E} = "";

$returner{ID}{accountmenu}{E} = "";
$returner{ID}{archmenu}{E} = "";
$returner{ID}{topicmenu}{E} = "";
$returner{CLASS}{amentry}{E} = "";
$returner{CLASS}{arentry}{E} = "";
$returner{CLASS}{tmentry}{E} = "";

$returner{ID}{nontop}{Position} = "relative";
$returner{ID}{nontop}{E} = "";

$returner{ID}{caption}{"background-color"} = "lightgrey";
$returner{ID}{caption}{"-moz-border-radius"} = "10px";
$returner{ID}{caption}{"-webkit-border-radius"} = "10px";
$returner{ID}{caption}{"border-radius"} = "10px 10px";
$returner{ID}{caption}{border} = "2px solid #000";
$returner{ID}{caption}{margin} = "5px 5px 5px 5px";
$returner{ID}{caption}{height} = "140px";
$returner{ID}{caption}{padding} = "10px";
$returner{ID}{caption}{E} = "";

$returner{ID}{picarea}{width} = "101px";
$returner{ID}{picarea}{height} = "130px";
$returner{ID}{picarea}{Position} = "absolute";
$returner{ID}{picarea}{E} = "";

$returner{ID}{toparea}{height} = "200px";

$returner{ID}{topareatext}{left} = "130px";
$returner{ID}{topareatext}{Position} = "absolute";

$returner{ID}{footer}{margin} = "0px 0px 0px 0px";
$returner{ID}{footer}{"border-top"} = "1px solid darkgrey";
$returner{ID}{footer}{width} = "100%";
$returner{ID}{footer}{height} = "3em";
$returner{ID}{footer}{background} = "black";
$returner{ID}{footer}{color} = "lightgrey";

$returner{ID}{centrearea}{Position} = "relative";
$returner{ID}{centrearea}{overflow} = "auto";
$returner{ID}{centrearea}{width} = "100%";

$returner{CLASS}{jentry}{background} = "grey";
$returner{CLASS}{jentry}{color} = "black";
$returner{CLASS}{jentry}{"-moz-border-radius"} = "10px";
$returner{CLASS}{jentry}{"-webkit-border-radius"} = "10px";
$returner{CLASS}{jentry}{"border-radius"} = "10px 10px";
$returner{CLASS}{jentry}{border} = "4px groove grey";
$returner{CLASS}{jentry}{padding} = "4px";
$returner{CLASS}{jentry}{display} = "inline-block";
$returner{CLASS}{jentry}{"min-width"} = "60%";
$returner{CLASS}{jentry}{E} = "";

$returner{CLASS}{jetimetext}{"margin-left"} = "1em";
$returner{CLASS}{jetimetext}{"margin-top"} = "0.5em";

$returner{CLASS}{jetimedesc}{float} = "left";
$returner{CLASS}{jetimedesc}{"margin-top"} = ".5em";
$returner{CLASS}{jetimedesc}{"margin-left"} = ".3em";
$returner{CLASS}{jetimedesc}{"margin-right"} = ".8em";

$returner{CLASS}{jeheadtime}{border} = "1px solid darkgrey";
$returner{CLASS}{jeheadtime}{height} = "38px";

$returner{CLASS}{jheadtimev}{float} = "left";
$returner{CLASS}{jheadtimev}{"min-height"} = "2em";
$returner{CLASS}{jheadtimev}{height} = "100%";
$returner{CLASS}{jheadtimev}{"min-width"} = "20%";

$returner{CLASS}{jeheadtimet}{"border-left"} = "1px solid darkgrey";
$returner{CLASS}{jeheadtimet}{float} = "left";
$returner{CLASS}{jeheadtimet}{height} = "100%";

$returner{CLASS}{jetailfield}{"border-left"} = "2px solid rgb(170,170,170)";

$returner{CLASS}{jbody}{background} = "lightgrey";
$returner{CLASS}{jbody}{color} = "black";
$returner{CLASS}{jbody}{"font-family"} = "Monospace";
$returner{CLASS}{jbody}{"-moz-border-radius"} = "10px";
$returner{CLASS}{jbody}{"-webkit-border-radius"} = "10px";
$returner{CLASS}{jbody}{"border-radius"} = "10px 10px";
$returner{CLASS}{jbody}{border} = "2px solid white";
$returner{CLASS}{jbody}{padding} = "2px";
$returner{CLASS}{jbody}{clear} = "left";
$returner{CLASS}{jbody}{"margin-bottom"} = ".3em";
$returner{CLASS}{jbody}{E} = "";

$returner{CLASS}{jemisc}{border} = '1px solid lightgrey';
$returner{CLASS}{jemisc}{"margin-top"} = '0px';
$returner{CLASS}{jemisc}{height} = '1.4em';

$returner{CLASS}{jetopic}{"border-left"} = '1px solid lightgrey';
$returner{CLASS}{jetopic}{float} = 'left';

$returner{CLASS}{jetitle}{"border"} = "0px solid grey";
$returner{CLASS}{jetitle}{"margin"} = "3px";
$returner{CLASS}{jetitle}{"font-family"} = "Serif";
$returner{CLASS}{jetitle}{"text-decoration"} = "underline";

	# Quoted text
$returner{CLASS}{quoted}{color} = "green";
$returner{CLASS}{quoted}{"font-family"} = "monospace";
$returner{CLASS}{quoted}{E} = "";

$returner{CLASS}{markup2}{"font-style"} = "italic";
$returner{CLASS}{markup3}{"font-weight"} = "bold";
$returner{CLASS}{markup4}{"font-style"} = "italic";
$returner{CLASS}{markup4}{"font-weight"} = "bold";

	# Holds the picture
$returner{ID}{logo}{Position} = "absolute";
$returner{ID}{logo}{B} = q{left: 0;};
$returner{ID}{logo}{width} = "101px";

$returner{ID}{nonlogoheader}{Position} = "absolute";
$returner{ID}{nonlogoheader}{B} = q{left: 105px;};
$returner{ID}{nonlogoheader}{height} = "130px";

$returner{ID}{linkarea}{Position} = "relative";

$returner{ID}{headerlinks}{color} = "white";
$returner{ID}{headerlinks}{Position} = "absolute";
$returner{ID}{headerlinks}{B} = q{left: 0;};

$returner{ID}{headermisc}{color} = "purple";
$returner{ID}{headermisc}{Position} = "absolute";

$returner{CLASS}{privatetext}{color} = "red";

$returner{CLASS}{goodlink}{color}="lightgreen";
$returner{CLASS}{noexist}{color}="red";
$returner{CLASS}{namespace}{color}="orange";

# $returner{ID}{wikoptions}{Position} = "absolute";
$returner{ID}{wikoptions}{width} = "95%";
$returner{ID}{wikoptions}{background} = "black";
$returner{ID}{wikoptions}{B} = "bottom:0;right:0;";
$returner{ID}{wikoptions}{color} = "orange";

$returner{ID}{wikpagename}{color} = "gold";
$returner{ID}{wikcontent}{background} = "lightgrey";
$returner{ID}{wikcontent}{color} = "black";

$returner{ID}{wikhistory}{background} = "lightgrey";
$returner{ID}{wikhistory}{color} = "black";

$returner{ID}{wikedit}{background} = "lightgrey";
$returner{ID}{wikedit}{color} = "black";

$returner{ID}{wikspecial}{background} = "lightgrey";
$returner{ID}{wikspecial}{color} = "black";

$returner{CLASS}{formcaption}{background} = "lightgrey";
$returner{CLASS}{formcaption}{color} = "black";

$returner{CLASS}{wikoption}{float} = q{left};

$returner{ID}{wikpagename}{'font-size'} = q{16pt};

return \%returner;
}

sub dispatch_csspage
{ # Handle css requests, doing global and then user (by login) css
	# FIXME: Serve more than just the default CSS, and do per-user code
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

$apache_r->content_type('text/css');
my $csshash = css_defaults();
merge_specific_css(apacheobj => $apache_r, css => $csshash);
print formatcss(css => $csshash);
}

sub formatcss
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $csshash = $args->mandate('css');
$args->argok();

my $returner = "";
my @types_to_handle = keys %$csshash;
foreach my $type (@types_to_handle)
	{
	my $intro_prefix;
	if($type eq "CLASS")
		{
		$intro_prefix = '.';
		}
	elsif($type eq "ID")
		{
		$intro_prefix = '#';
		}
	elsif($type eq "TAG")
		{
		$intro_prefix = '';
		}
	else
		{die "Internal Error in CSS_code\n";}

	foreach my $css_thingy (keys %{$$csshash{$type}})
		{
		$returner .= "$intro_prefix$css_thingy\n{\n";
		foreach my $component (keys %{$$csshash{$type}{$css_thingy}})
			{
			my $content = $$csshash{$type}{$css_thingy}{$component};
			if( ($component eq 'E') || ($component eq 'B'))
				{
				if($content ne '')
					{$returner .= "$content\n";}
				}
			else
				{
				$returner .= "$component: $content;\n";
				}
			}
		$returner .= "}\n\n";
		}
	}
return $returner;
}

sub merge_specific_css
{ # If user has theme selected or specific css, manipulate it into csshash
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $csshash	= $args->mandate('css');
$args->argok();

my $uid = session_uid(apacheobj => $apache_r);
my $themeid=0;
if(defined($uid))
	{
	$themeid = get_themeid_for_uid(userid => $uid);
	}
else # Look for theme from cookie
	{
	$themeid = get_themeid_from_cookie(apacheobj => $apache_r);
	}

if(defined $themeid)
	{
	apply_theme_to_csshash(css => $csshash, themeid => $themeid);
	}
if(defined $uid)
	{
	apply_usercss_to_csshash(css => $csshash, userid => $uid);
	}
}

sub get_themeid_for_uid
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $uid = $args->mandate('userid');
$args->argok();

my $dbh = db_connect();
my $thq = $dbh->prepare("SELECT sitetheme FROM person WHERE id=?");
$thq->execute($uid);
my $thm = $thq->fetchrow_hashref();
$thq->finish();
release_db($dbh);
return $$thm{sitetheme};
}

sub get_themeid_from_cookie
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
$args->argok();

my $themeid = get_cookie(apacheobj => $apache_r, cookiename => 'theme');
if(! defined $themeid) {return undef;}

$themeid =~ s/^.*?(\d+)/$1/; # Safety filter
if($themeid !~ /^\d+$/) {return undef;}
return $themeid;
}

sub apply_theme_to_csshash
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $csshash = $args->mandate('css');
my $themeid = $args->mandate('themeid');
$args->argok();

my $dbh = db_connect();
my $theq = $dbh->prepare("SELECT * from themedata WHERE themeid=?");
$theq->execute($themeid);
while(my $thiscss = $theq->fetchrow_hashref() )
	{
	$$csshash{$$thiscss{csstype}}{$$thiscss{csselem}}{$$thiscss{cssprop}} = $$thiscss{cssval};
	}
$theq->finish();
release_db($dbh);
}

sub apply_usercss_to_csshash
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $csshash	= $args->mandate('css');
my $uid		= $args->mandate('userid');
$args->argok();

my $dbh = db_connect();
my $theq = $dbh->prepare("SELECT * from person_css WHERE personid=?");
$theq->execute($uid);
while(my $thiscss = $theq->fetchrow_hashref() )
	{
	$$csshash{$$thiscss{csstype}}{$$thiscss{csselem}}{$$thiscss{cssprop}} = $$thiscss{cssval};
	}
$theq->finish();
release_db($dbh);
}

1;
