#!/usr/bin/perl

use strict;
use DBI;
package MyApache::POUND::POUNDFeeds;

require Exporter;
require AutoLoader;

use MIME::Base64;
use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDConfig;
use MyApache::POUND::POUNDBLOGDB;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDMarkup;
use XML::Atom::Feed;
use XML::Atom::Entry;
use XML::RSS;
use DateTime;
use DateTime::Format::W3CDTF; # *SIGH*
$XML::Atom::DefaultVersion = "1.0";

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_feed);
our @EXPORT = @EXPORT_OK;


sub dispatch_feed
{ # Given a blogid, returns a RSS stream for that BLOG
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $feedtype	= $args->mandate('feed_type');
my $blogname	= $args->mandate('blogname');
$args->argok();

$apache_r->content_type('application/xhtml+xml');
my $blogid = blogid_for_blogname(blogname => $blogname);
if(! defined $blogid)
	{return;}
my %blogcfg = get_blogcfg(blogid => $blogid);
my @bentries = get_x_latest_entries(blogid => $blogid, nentries => size_xmlfeed(), no_private => 1);
if($feedtype eq 'atom')
	{ 
	return dispatch_atom(blogcfg => \%blogcfg, blogentries => \@bentries);
	}
elsif($feedtype eq 'rss')
	{
	return dispatch_rss(apacheobj => $apache_r, blogcfg => \%blogcfg, blogentries => \@bentries);
	}
else
	{
	errorpage(text => "Unrecognised Feed Type");
	return;
	}
}

sub dispatch_atom
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogcfg	= $args->mandate('blogcfg');
my $bentriesref	= $args->mandate('blogentries');
$args->argok();

my $feed = XML::Atom::Feed->new(Version => 1.0);
$feed->set(undef, 'id', url_blog(blogname => $$blogcfg{name}));
$feed->title($$blogcfg{title});

	{ # Snippet to get modified field - consider using get_blog_lastmodified()
	my ($lastentry, undef) = get_x_latest_entries(blogid => $$blogcfg{id}, nentries => 1);
	my %bentry = get_bentry(entryid => $lastentry); # Inefficient, but .. eh..
	my $lastmodified = get_w3c_datestring(unixtime => $bentry{zeit});
	$feed->set(undef, 'updated', $lastmodified);
	}

	{ # Author snippet
	my $author = XML::Atom::Person->new();
	my $url_toblog = url_blog(blogname => $$blogcfg{name});
	my %authorinfo = get_personinfo(uid => $$blogcfg{author});
	$author->name($authorinfo{name});
	$feed->author($author);
	}

	{ # self-link snippet
	my $selflink = XML::Atom::Link->new();
	$selflink->rel('self'); # Atom self-links point back to the ATOM feed
	$selflink->href( url_blogatom(blogname => $$blogcfg{name}) );
	$feed->add_link($selflink);
	}
if(defined $$blogcfg{blogimg})
	{
        $feed->set(undef, 'icon', $$blogcfg{blogimg});
        $feed->set(undef, 'logo', $$blogcfg{blogimg});
	}

foreach my $bentry (sort @$bentriesref)
	{
	my $entry = XML::Atom::Entry->new();
	my %bguts = get_bentry(entryid => $bentry);
	my $burl = url_nodepage(blogname => $$blogcfg{name}, nodezeit => $bguts{zeit}, nodetype => 'entry');
	$bguts{body} =~ s/<PRIVATE>.*?<\/PRIVATE>/'''PRIVATE SECTION NOT SHOWN'''/msig;
	my $content = do_markup(data => $bguts{body}, context => $$blogcfg{name}, content_flags => ':feed:atom:hidecuts:');
	my $entdate = get_w3c_datestring(unixtime => $bguts{zeit}); # Is this still useful?
	if($bguts{private})
		{
		$content = q{ENTRY IS PRIVATE};
		}
	# And now, to fill the stuff in...
	$entry->title($bguts{title});
	$entry->content("<br />Date: " . localtime($bguts{zeit}) . "<br />\n" . $content . "\n");
	my $entrylink = XML::Atom::Link->new();
	$entrylink->type('text/html');
	$entrylink->rel('alternate');
	$entrylink->href($burl);
	$entry->add_link($entrylink);
        $entry->set(undef, 'updated', $entdate);
        $entry->set(undef, 'id', $burl);
	$feed->add_entry($entry);
	}
print $feed->as_xml();
}

sub dispatch_rss
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $blogcfg	= $args->mandate('blogcfg');
my $bentriesref	= $args->mandate('blogentries');
$args->argok();

my $url_toblog = url_blog(blogname => $$blogcfg{name});
my %author= get_personinfo(uid => $$blogcfg{author});
$apache_r->content_type('text/xml');

print <<EORFEEDSTART;
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
xmlns:dc="http://purl.org/dc/elements/1.1/"
xmlns:sy="http://purl.org/rss/1.0/modules/syndication/"
xmlns:content="http://purl.org/rss/1.0/modules/content/"
xmlns="http://purl.org/rss/1.0/">
<channel rdf:about="$url_toblog">
<title>$$blogcfg{title}</title>
<link>$url_toblog</link>
<description>Blog of $author{name}</description>
<language>en-us</language>
<items>
<rdf:Seq>
EORFEEDSTART

foreach my $bentry (@$bentriesref)
	{
	my %bguts = get_bentry(entryid => $bentry); # Inefficient
	my $burl = url_nodepage(blogname => $$blogcfg{name}, nodezeit => zeit_for_blogentry(entryid => $bentry), nodetype => 'entry');
	print qq{<rdf:li rdf:resource="$burl" />\n};
	}
print <<EORLLEHDR;
</rdf:Seq>
</items>
</channel>
EORLLEHDR
foreach my $bentry (sort @$bentriesref)
	{
	my %bguts = get_bentry(entryid => $bentry);
	rss_do_entry(blogcfg => $blogcfg, bguts => \%bguts);
	}
}

sub rss_do_entry
{ # TODO Verify stream for correctness
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $blogcfg	= $args->mandate('blogcfg');
my $bguts	= $args->mandate('bguts');
$args->argok();

my $burl = url_nodepage(blogname => $$blogcfg{name}, nodezeit => $$bguts{zeit}, nodetype => 'entry');
my $descrip = $$bguts{title}; 
my $author = name_from_userid(userid => $$blogcfg{author}); 
my $entdate = get_w3c_datestring(unixtime => $$bguts{zeit});
my $entbody;

if($$bguts{private})
	{
	$entbody = q{ENTRY IS PRIVATE};
	}
else
	{
	$$bguts{body} =~ s{<PRIVATE>.*?</PRIVATE>}{'''PRIVATE PART'''}msig;
	$entbody = do_markup(data => $$bguts{body}, context => $$blogcfg{name}, content_flags => ':feed:rss1:hidecuts');
	$entbody =~ tr/][/__/; # Just to be safe for the parser
	$entbody =~ s{</?content.*?>}{}; # Also just to be safe. Need to
					# research specs for safe escapes.
	}

print <<ENTCSS;
<item rdf:about="$burl">
<title>$$bguts{title}</title>
<link>$burl</link>
<description>$descrip</description>
<dc:creator>$author</dc:creator>
<dc:date>$entdate</dc:date>
<content:encoded><![CDATA[$entbody]]></content:encoded>
</item>
ENTCSS
}

sub get_w3c_datestring
{ # RSS Date formatting needs this format
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $unixtime = $args->mandate('unixtime');
$args->argok();

my $dtime = DateTime->from_epoch(epoch => $unixtime);
return DateTime::Format::W3CDTF->format_datetime($dtime);
}

1;

