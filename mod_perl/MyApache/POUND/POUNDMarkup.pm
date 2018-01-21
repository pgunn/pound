#!/usr/bin/perl

# Handles the markup. This code is awful.

use strict;
use DBI;
package MyApache::POUND::POUNDMarkup;
use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDWikiDB;
use MyApache::POUND::POUNDFiles;
use MyApache::POUND::POUNDFilesDB;

require Exporter;
require AutoLoader;

# Handles stuff relating to the Wiki formatting. 

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(do_markup html_purge purge_newlines_outside_blocks);
our @EXPORT = @EXPORT_OK;

sub do_markup
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $data	= $args->mandate('data');
my $context	= $args->mandate('context');
my $contype	= $args->mandate('content_flags');
my $cutref	= $args->accept('cut_target', undef);
$args->argok();

# XXX Think about ways to make contype more flexible/intelligent
my %attrs = doclevel_markup(data => \$data, context => $context);
my $pdatref = linelevel_markup(data => \$data); # Returns a string because it's easier in this case
elevel_markup(data => $pdatref, context => $context); # Mutation is easier here

$$pdatref =~ s/<lj-cut>/<cut>/ig;
$$pdatref =~ s/<\/lj-cut>/<\/cut>/ig;
if(defined($contype) && ($contype =~ /:hidecuts:/))
	{
	my $text;
	if($cutref)
		{
		$text = get_htlink(
			target => $cutref,
			content => q{(view full entry for contents)}); # XXX Do we want to set follow_ok to 1?
		}
	else
		{$text = q{(view full entry for contents)};}
	
	$$pdatref =~ s/<cut>.*?<\/cut>/$text/sig; # Context type directed us to not display this content
	}
if(defined($contype) && ($contype =~ /:for_lj:/))
	{
	$$pdatref =~ s/<cut>/<lj-cut>/ig; # For this case, lj wants the tag to be lj-cut
	$$pdatref =~ s/<\/cut>/<\/lj-cut>/ig;
	}
return $$pdatref;
}

sub html_purge
# return the html-rendered version of the exact passed text
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $data = $args->mandate('data');
$args->argok();

$data =~ s/\&/\&amp;/g;
$data =~ s/</\&lt;/g;
$data =~ s/>/\&gt;/g;
return $data;
}

sub purge_newlines_outside_blocks
{ # Presently used for LJ posting, remove all newlines outside of PRE tags
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $guts = $args->mandate('in');
$args->argok();

my $in_pre = 0;
my @parts = split(/(<\/?pre[^>]*>)/i, $guts); # Parantheses keep the pattern
my @returner;
foreach my $part (@parts)
	{
	if($part =~ /<pre/i) # Start of a pre block
		{$in_pre = 1;next;}
	elsif($part =~ /<\/pre/i) # End of a pre block
		{$in_pre = 0;next;}
	if(! $in_pre) {$part =~ tr/\n\r\f//d;}
	push(@returner, $part);
	}
return join('', @returner);
}

# Private functions below

sub linelevel_markup
{ # line/block level markup
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $datref = $args->mandate('data');
$args->argok();

my (@lines) = split(/\n/, $$datref);
my @outlines;
my $returner;

# Initialize state machine
my %parser;
$parser{listsig} = ''; # Block-level information
$parser{lastblank} = 1; # Coalesce multiple blank lines into one
		# init as 1 so we eat all the opening spaces before we start
# End state machine init
foreach my $line (@lines) # Run the state machine
	{
	if(	($parser{listsig} ne '') || # We're in a block of some sort, start, continue or end it
		($line =~ /^[*#: ]+/)  )
		{
		handle_block(\$line, \$parser{listsig}, \@outlines);
		}
	elsif($parser{lastblank}) # Last line was blank. Either clear that flag (if this line is not), or
				# ignore this line (if this line is)
		{
		if($line =~ /^\s*$/) {next;}
		else
			{
			$parser{lastblank}=0;
			push(@outlines, "<p>"); # paragraph!
			push(@outlines, $line); # paragraph!
			}
		}
	elsif($line =~ /^\s*$/) # Blank line that is not after another
		{
		$parser{lastblank}=1;
		push(@outlines, "</p>");
		}
	else # Line with content that we haven't yet handled
		{
		push(@outlines, $line);
		}
	}

# And now, close any outstanding tags by making a blank line and passing it to the block handler
if($parser{listsig} ne '')
	{
	my $fakeline='';
	handle_block(\$fakeline, \$parser{listsig}, \@outlines);
	}
$returner = join("\n", @outlines);
return \$returner;
}

sub elevel_markup
{ # Element-level markup
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $datref	= $args->mandate('data');
my $context	= $args->mandate('context');
$args->argok();

$$datref =~ s/\{\{([^}]*)\}\}/markup_template($1, $context)/egsm;
$$datref =~ s/''''(.*?)''''/markup_emphasis($1,4)/egsm;
$$datref =~ s/'''(.*?)'''/markup_emphasis($1,3)/egsm;
$$datref =~ s/''(.*?)''/markup_emphasis($1,2)/egsm;
$$datref =~ s/\[\[(.*?)\]\]/markup_inner_link($1,$context)/egsm;
$$datref =~ s/\[(.*?)\]/markup_ext_link($1)/egsm;
}

sub doclevel_markup
{ # Idea: Maybe share this between document input and document display?
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $datref	= $args->mandate('data');
my $context	= $args->mandate('context');
$args->argok();

my %attrs;
while($$datref =~ s{\[\!(.*?)\]}{}g)
	{
	my $tag = $1;
	my @tagparts = split(/:/, $tag, 2);
	if(@tagparts == 1)
		{
		$attrs{$tagparts[0]} = 1;
		}
	else
		{
		$attrs{$tagparts[0]} = $tagparts[1];
		}
	}
return %attrs;
}

=noteson
Things we need to implement:

sections:
== section ==
=== subsection ===
==== sub-subsection ====

text-formatting:
drop single newlines
empty line is paragraph break
space at start of line starts a literal block
colon indents a paragraph if it starts it, otherwise just that line
	(this is done using the dl tag??)
--- alone on a line becomes a hr
Emphasis
	''Italics'' '''bold''' ''''bold italics''''
<nowiki>foo</nowiki> - disable wiki markup inside the nowiki tags

lists:
*foo
**deeper
*** lala

#numbered list
##deeper

#*mixed list
links:
[[foo]] is a link, but for me, perhaps it'll just be a link to
	a date or some other page on my blog? I'll need to add
	semantics
[[foo#bar]] syntax as anchor
[[foo|Page Foo]]
[http://external.link External]
http://autolink
=cut

sub markup_emphasis($$)
{
my ($data, $level) = @_;
$data = "<span class=\"markup$level\">" . $data . "</span>";
return $data;
}

sub markup_template
{
my ($name, $context) = @_;
return qq{\n\nERROR: TEMPLATES ARE NOT IMPLEMENTED YET\n\n};
}

sub markup_inner_link
{ # For inner links, link format is RESOURCE:TARG|TEXT with the 
# resource part optional. If no resource is provided, assume link is an internal
# wiki link. If one is, lookup the appropriate external link format in the
# database, and substitute the wiktitle in as appropriate to build the
# link. TEXT is optional too.
# FIXME Needs a lot of cleanup
my ($link, $context) = @_;
my @linkparts = split(/\|/, $link);
if(($link eq "") || (@linkparts > 2))
	{
	return("!BAD_LINK!");
	}
if(@linkparts==0) # Is this needed?
	{
	$linkparts[0] = $link;
	}

my @aparts = split(/\:/, $linkparts[0], 2);
if(@aparts == 0)
	{$aparts[0] = $linkparts[0];}

my $link_text= $linkparts[0];
my $link_target;
my $link_status='unknown'; # default
if(@linkparts == 2) # use url_wikpage and wiki_page_exists
	{
	$link_text = $linkparts[1];
	}
if(@aparts == 1) # No namespace shift
	{
	my $article_name = ucfirst($aparts[0]);
	$link_target = url_wikpage(page_name => $article_name);
	if(wiki_page_exists(pagename => $article_name) )
		{
		$link_status='goodlink';
		}
	else
		{
		$link_status='noexist';
		}
	}
else
	{ # This entire section will need cleanup when we do this right
	$link_status='namespace';
	if($aparts[0] eq 'Special')
		{
		my $article_name = ucfirst($linkparts[0]);
		$link_target = url_wikpage(page_name => $article_name); # For Special only.
		}
	elsif($aparts[0] eq 'Media')
		{
		my $filename_unsplit = $aparts[1];
		my @fn_parts = split(':', $filename_unsplit);
		my $filename = $fn_parts[-1];
		if(@fn_parts > 1)
			{
			$context = $fn_parts[0]; # between parts are reserved.
			}
		shift @linkparts;
		return generate_media_link($filename, $context, @linkparts);
		}
	else
		{
		my $err;
		($link_target, $err) = handle_namespaced_link(@aparts);
		if($err) {$link_text = $link_target; $link_target='';} # Allows errors as link text
		}
	}
#if(@linkparts == 2) # use url_wikpage and wiki_page_exists
#	{
#	$link_text = $linkparts[1];
#	}
return qq{<a href="$link_target" class="$link_status">$link_text</a>};
}

sub handle_namespaced_link
{
my @aparts = @_;
my $err = 0;
my $returner = '';
my $namespace = $aparts[0];
if($aparts[0] eq 'BLOG')
	{
	my $blogguts = $aparts[1];
	my ($blogname, $blogzeit) = split(':', $blogguts);
	$returner = url_nodepage(blogname => $blogname, nodezeit => $blogzeit, nodetype => 'entry');
	}
else
	{
	$err = 1;
	$returner .= "DEBUG: " . join('*', @aparts);
	$returner .= "!UNIMPLEMENTED_NAMESPACED_LINK!";
	}
return ($returner, $err);
}

sub markup_ext_link
{ # External links are easy. Format is URL|TEXT, with the text part optional.
my ($link) = @_;
my ($url,$text,undef) = split(/\|/, $link);
if(! defined($text)) {$text = 'LINK';}
return qq{<a href="$url">$text</a>};
}

sub generate_media_link($$@)
{
my ($target, $context, @aparts) = @_;
my $returner = '';
my $id;
if($id = file_exists(filename => $target, namespace => $context) ) # FIXME Pass in aparts appropriately
	{
	my %attrs = media_parse_aparts(\@aparts);
	my $alttext;
	if($attrs{alt})
		{
		$alttext = $attrs{alt};
		}
	$returner = embed_media(file_id => $id, filename => $target, context => $context, alt_text => $alttext);
	}
else
	{
	$returner .= "Target: $target<br />\n";
	$returner .= "Context: $context<br />\n";
	$returner .= "Aparts: " . join(',', @aparts);
	}
return $returner;
}

sub markup_for_lspart($)
{
my ($listsig) = @_;
if($listsig eq '#')
	{
	return(qq{<ol>\n},qq{</ol>\n});
	}
elsif($listsig eq '*')
	{
	return(qq{<ul>\n},qq{</ul>\n});
	}
elsif($listsig eq ':')
	{
	return(qq{<dl>\n},qq{</dl>\n});
	}
elsif($listsig eq ' ')
	{
	return(qq{<pre>\n},qq{</pre>\n});
	}
else
	{
	errorpage(text => "Internal error in get_markup_for_last_listpart: [$listsig] is not valid key!\n");
	}
}

sub markup_for_lspart_item($)
{
my ($listsig) = @_;
if($listsig eq '#')
	{
	return(qq{<li>},qq{</li>});
	}
elsif($listsig eq '*')
	{
	return(qq{<li>},qq{</li>});
	}
elsif($listsig eq ':')
	{
	return(qq{<dd>},qq{</dd>});
	}
elsif($listsig eq ' ')
	{
	return('',''); # Predefined blocks have nothing like this
	}
else
	{
	errorpage(text => "Internal error in markup_for_lspart_item: [$listsig] is not valid key!\n");
	}
}

sub lspart_diff($$)
{ # Given two listparts, finds the html to rewind and to establish to go from the old to the new
my ($new, $old) = @_;
my $returner = '';
my @newparts = split(//, $new);
my @oldparts = split(//, $old);

oloop: while( scalar(@newparts) || scalar(@oldparts))
{
if(scalar(@oldparts))
	{
	my $oldbit = shift(@oldparts);
	if(scalar(@newparts))
		{ # Differential!
		my $newbit = shift(@newparts);
		if($newbit ne $oldbit)
			{ # Close all the rest from oldparts, then open all the rest from newparts
			$returner .= lspart_closeall(@oldparts);
			$returner .= lspart_openall(@newparts);
			last oloop;
			}
		# Otherwise, just keep going
		}
	else
		{ # Just close off the oldparts
		unshift(@oldparts, $oldbit);
		$returner .= lspart_closeall(@oldparts);
		last oloop;
		}
	}
else
	{ # Just open newparts
	$returner .= lspart_openall(@newparts);
	last oloop;
	}
}
return $returner;
}

sub lspart_closeall($)
{ # markup_for_lspart returns opentag, closetag
my @str = @_;
my $returner = '';
foreach my $sp (reverse @str)
	{
	my $retpart;
	(undef, $retpart) = markup_for_lspart($sp);
	$returner .= $retpart;
	}
return $returner;
}

sub lspart_openall($)
{
my @str = @_;
my $returner = '';
foreach my $sp (@str)
	{
	my $retpart;
	($retpart, undef) = markup_for_lspart($sp);
	$returner .= $retpart;
	}
return $returner;
}

sub handle_block($$$)
{
my ($lineref, $lsigref, $outlineref) = @_;
my $sig = build_sig_from_line($lineref);
my @sigparts = split(//, $sig);
if($sig eq $$lsigref)
	{
	my ($iopener, $icloser) = markup_for_lspart_item($sigparts[-1]);
	push(@$outlineref, qq{$iopener$$lineref$icloser});
	}
elsif($sig ne '')
	{
	my ($iopener, $icloser) = markup_for_lspart_item($sigparts[-1]);
	push(@$outlineref, lspart_diff($sig, $$lsigref) . $iopener . $$lineref . $icloser);
	$$lsigref = $sig;
	}
else # We're just here to close the tags
	{
	push(@$outlineref, lspart_diff('', $$lsigref) . $$lineref);
	$$lsigref='';
	}
}

sub build_sig_from_line($)
{
my ($lr) = @_;
my $returner='';
while($$lr =~ s/^([*#: ])//)
	{
	chomp($$lr);
	$returner .= $1;
	if($1 eq ' ')
		{last;} # Disallow nesting other structures inside preformatted text
	}
return $returner;
}

sub media_parse_aparts
{
my ($in) = @_;
my %ret;

foreach my $inv (@$in)
	{
	if($inv =~ /^([^=]+)=([^=]+)$/)
		{ # this-equals-that type params
		$ret{$1} = $2;
		}
	else
		{ # params set by their name
		$ret{$1} = undef;
		}
	}
return %ret;
}

1;
