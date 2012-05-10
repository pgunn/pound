#!/usr/bin/perl

use strict;
use DBI;
package MyApache::POUND::POUNDPermissions;

require Exporter;
require AutoLoader;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(ok_blogentry_reply ok_blogcomment_reply ok_wikipost);
our @EXPORT = @EXPORT_OK;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDUser;

sub ok_blogentry_reply
{ # FIXME user and acls are unimplemented
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $user	= $args->mandate('userid');
my $entry_wri	= $args->mandate('entry_writable');
my $blog_wri	= $args->mandate('blog_writable');
my $blog_acls	= $args->accept('blog_acls', undef);
my $entry_acls	= $args->accept('entry_acls', undef);
$args->argok();

if($blog_wri && $entry_wri)
	{return 1;}

return 0;
}

sub ok_blogcomment_reply
{ # FIXME user and acls are unimplemented
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $user	= $args->mandate('userid');
my $entry_wri	= $args->mandate('entry_writable');
my $blog_wri	= $args->mandate('blog_writable');
my $blog_acls	= $args->accept('blog_acls', undef);
my $entry_acls	= $args->accept('entry_acls', undef);
$args->argok();

if($blog_wri && $entry_wri)
	{return 1;}

return 0;
}

sub ok_wikipost
{ # FIXME ACLs are not yet implemented
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $userid	= $args->mandate('userid');
my $entry_locked= $args->mandate('entry_locked');
my $wiki_acls	= $args->accept('wiki_acls', undef);
my $entry_acls	= $args->accept('entry_acls', undef);
$args->argok();

if(wiki_public() || uid_can_wiki(userid => $userid) )
	{
	if( (! $entry_locked) || (uid_is_super(userid => $userid) ) )
		{
		return 1;
		}
	}
return 0;
}

1;
