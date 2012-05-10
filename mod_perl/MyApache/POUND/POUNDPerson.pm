#!/usr/bin/perl -w

# Handle person pages and similar 

use strict;
use DBI;
package MyApache::POUND::POUNDPerson;

require Exporter;
require AutoLoader;
use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDBLOG;
use MyApache::POUND::POUNDPaths;


our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_person);
our @EXPORT = @EXPORT_OK;

sub dispatch_person
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $person	= $args->mandate('person');
$args->argok();

$person =~ s/\.html$//;
sthtml(title => "User:$person");
my $uid = uid_from_login(login => $person);
if($uid == 0)
	{
	print qq{<div style="color:red;">Bad user!</div>\n};
	return;
	}
my %person = get_personinfo(uid => $uid);

my $bloglines = '';
my $blogs_info = get_bloglist(userid => $uid);
$bloglines .= qq{<table border=1>}
.	"<tr>"
.	join('', map{"<th>$_</th>"} qw/id name title type/)
.	"</tr>\n";
foreach my $id (keys %$blogs_info)
	{
	$bloglines .= "<tr>" . join('',map{"<td>$_</td>"}
		(
		$id,
		get_htlink(target => url_blog(blogname => $$blogs_info{$id}{name}), content => $$blogs_info{$id}{name}),
		$$blogs_info{$id}{title},
		describe_blogtype(descriptor => $$blogs_info{$id}{blogtype})
		)) . "</tr>\n"
	}

my $picpart;
$picpart = ($person{picurl}) ? qq{<center><img src="$person{picurl}" /></center>} : '';
my $privs = '';
$privs .= ($person{can_wiki}) ? qq{Can edit the wiki<br />\n} : '';
$privs .= ($person{is_super}) ? qq{Has superuser privileges<br />\n} : '';


print <<EOPERSON;
$picpart
<div style="color:orange;">
<h1>User:$person</h1>
<table border=1>
<tr>
<th>Name</th><td>$person{name}</td></tr>
<th>URL</th><td><a href="$person{weburl}">$person{weburl}</a></td></tr>
<th>Description</th><td>$person{descrip}</td></tr>
<th>Privs</th><td>$privs</td></tr>
</tr>
</table>
<br /><br />
$bloglines
</div>
EOPERSON
endhtml();
}

1;
