#!/usr/bin/perl

# Web interface to message stuff...
use strict;
package MyApache::POUND::POUNDManageMessages;

use Apache2::compat;
use Apache2::Const -compile => qw(:methods);
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDCSS;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDMarkup;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDSession;
use MyApache::POUND::POUNDMessage;
use MyApache::POUND::POUNDForms;
use MyApache::POUND::Argpass;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_managemessages);
our @EXPORT = @EXPORT_OK;

sub dispatch_managemessages
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $reqargs	= $args->mandate('args');
$args->argok();

my $mode = 'show'; # default
my $uid = session_uid(apacheobj => $apache_r);
if(! defined $uid)
	{
	errorpage(text => 'No messages for people not logged in!');
	return;
	}

if(! @$reqargs)
	{ # Base page...
	dispatch_showmessages(apacheobj => $apache_r, user => $uid);
	}
else
	{ # We have arguments..
	my $request = shift(@$reqargs);
# get_manage_messages_ackpage()
	if($request = get_manage_messages_ackpage() ) # ...
		{

		}
	if($request = get_add_messages() )
		{

		}
	else
		{
		errorpage(text => "Unknown request made of message management code");
		return;
		}
	}
endhtml();
}

sub dispatch_showmessages
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $uid		= $args->mandate('user');
$args->argok();

if(! $uid) {errorpage(text => "You're not logged in!");return;}

sthtml(title => "POUND - Manage Messages", no_css => 1);
my @msgids = ls_msgs(for_user_id => $uid); # right now, nsg_dist is unimplemented..
if(! @msgids)
	{print "No messages\n";}
else
	{
# FIXME Move this into the CSS file - embedding CSS is bad (but good for first drafts!)
	foreach my $msgid (sort @msgids)
		{
		print <<EOBLKSTART;
<div style="
padding: 10px;
-moz-border-radius: 10px;
background: lightgrey;
height: auto;
border: 2px solid #000;
color: black;
border-radius: 10px 10px;
background-color: lightgrey;
-webkit-border-radius: 10px;
margin: 5px 5px 5px 5px;">
EOBLKSTART
		my %msg = get_msg(message_id => $msgid);
		print "ID: $msg{id}<br />\n";
		print "CLASS: $msg{class}<br />\n";
		print "AUTODISARM: $msg{autodisarm}<br />\n";
		print "Subject: $msg{subject}<br />\n";
		print "Body: $msg{body}<br />\n"; # This actually needs processing..
		print "Lastnagged: $msg{lastnagged}<br />\n";
		stform(submit_url => join(	'/',
						url_manage_messages(),
						get_manage_messages_ackpage() ),
			formid => "msgack$msg{id}",
			validator => apache_session_key(apacheobj => $apache_r) );
		form_hidden(name => 'msgid', value => $msg{id});
		endform(submit => "Acknowledge");
		print "</div>\n";
		}
	}
# FIXME Add footer?
endhtml();

}

sub dispatch_delmessage
{ # This will probably be a POST.. 
# !!! 

sthtml(title => "POUND - Delete Messages");
#
#if($postdata{validcode} ne apache_session_key(apacheobj => $apache_r))
#	{
#	errorpage(text => 'BAD POST: Foreign source? Failed security check');
#	return;
#	}

}

1;
