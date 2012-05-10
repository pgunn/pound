#!/usr/bin/perl

use strict;
use MIME::Types;
package MyApache::POUND::POUNDFiles;

require Exporter;
require AutoLoader;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_file url_file embed_media infer_mimetype_from_filetype);
our @EXPORT = @EXPORT_OK;

use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDFilesDB;

# POUNDFiles is used to provide a uniform way to refer to "files"
# in the system. This should, in order to be compatible with multiple
# kinds of databases people might be using, support both BLOB storage
# and traditional file-based storage. 
# Note that this is used for articles and for BLOG entries, and so must
# include namespace support. It also should support multiple named variants
# of a given file so articles might decide, for example, to request a
# certain image size and the software might, either when it learns about
# the size possibly being requested (article edit/blog post time) or at
# runtime, use image conversion tools to do an in-memory transform and
# re-store the results back into the primary store (whatever that may be)
# for future requests.
# One design issue is that we don't want some user uploading a file called
# cat.jpg and having that name be taken for everyone, thus namespaces must
# be used consistantly, with each render type defaulting appropriately for
# what we're rendering at the moment and what client uploaded the file.
#
# For now, no security is present on files managed by POUND -- at best things
# stored are hard to see by virtue of obscurity, but I won't even guarantee
# that. I don't yet have worked out how to securely allow files to be updated
# by intended people and not others. Perhaps that'll become more clear by
# the time I have ACLs/permissions worked out.
#
# Because it might possibly be cool, there should be an ability to do find the
# version of a file at a given time so historical queries on wiki articles might,
# as an option, show the page content with images that were present in the database
# at that time. It also may be cool to eventually create a meta-fileid that could
# be stored in the wiki entry, instead of the filename itself, and have file changes
# propogate to articles referenced by them so changes to them can show in article
# history (so we'll have the concept of a document having all its content as part of
# it instead of having only really weak ties between article entries and file content).
# This is a blue-sky featre for future versions of POUND. It might not be
# too tricky, but I want to get this thing working without making it more complex yet.

# FIXME - Need to split off Postgres-specific parts into a separate file for
# 	modularity

sub dispatch_file
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $pathparts	= $args->mandate('pathparts');
$args->argok();

my ($namespace, $name, $variant, $version) = parse_fileargs(pathparts => $pathparts);

if(! defined($name) ) {return;}
my $fid;
if(! ($fid = file_exists(filename => $name, namespace => $namespace) ) )
	{
	$apache_r->content_type("text/plain");
	print "Namespace: $namespace\n";
	print "File: $name\n";
	if(defined $variant)
		{print "Variant: $variant\n";}
	if(defined $version)
		{print "Version: $version\n";}
	print "File does not exist\n";
	}
else # FIXME -- if file does exist...
	{
	my %finfo = all_fileinfo_from_id(file_id => $fid);
	my $data; # Holds content
	if($finfo{storetype} eq 'blob')
		{
		$data = blob_readfile(apacheobj => $apache_r, blobid => $finfo{blobid});
		}
	elsif($finfo{storetype} eq 'file') # Stored as a file
		{
		open(BFILE, $finfo{filename});
		local $/;
		$data = <BFILE>; # Slurrrrrrrrrrrp
		close(BFILE);
		}
	elsif($finfo{storetype} eq 'url')
		{
		# FIXME: Give a 304 to wherever the url is
		errorpage(text => "Internal error in POUNDFiles: URL filetype not yet supported");return;
		}
	else
		{ 
		errorpage(text => "Internal error in POUNDFiles: Unknown filetype requested");return;
		}
	$apache_r->content_type($finfo{mimetype});
	print $data;
	}
}

sub url_file
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $name	= $args->mandate('filename');
my $namespace	= $args->mandate('namespace');
my $version	= $args->accept('version', undef); # Eventually files will have versions as well as..
my $variant	= $args->accept('variant', undef); # variants, e.g. multiple dynamically created cached resizings of an image
$args->argok();

if(file_exists(filename => $name, namespace => $namespace, version => $version, variant => $variant) )
	{
	my $url = join('/', url_filebase(), $namespace);
	my $attrpart = remix_attrs(version => $version, variant => $variant);
	if( (defined $attrpart) && ($attrpart ne '') )
		{
		$url .= "/$attrpart";
		}
	$url .= "/$name";
	}
else
	{ # Not yet sure what to do here

	}
}

sub parse_fileargs
{
# Syntax is either
# /live/files/NAMESPACE/foo.jpg
# or
# /live/files/NAMESPACE/(optional string identifying variant and version)/filename.jpg

my $args = MyApache::POUND::Argpass::new('clean', @_);
my $pathparts = $args->mandate('pathparts');
$args->argok();

if(@$pathparts < 2)
	{
	errorpage(text => "Invalid URL");
	return;
	}

my $space = $$pathparts[0];
my $name = $$pathparts[-1]; # In both cases, is last component
my $variant;
my $ver;
if(@$pathparts > 2) # Syntax 2
	{ # Goal: Break into $variant and $ver
	my %attrs;
	my $attrs = $$pathparts[1];
	my @attlist = split(',', $attrs);
	while(my $attpair = shift @attlist)
		{
		my ($attkey, $attval) = split('=', $attpair, 2);
		if($attkey eq 'ver')
			{
			$ver = $attval;
			}
		else
			{
			$attrs{$attkey}=$attval;
			} 
		}
	if((scalar keys %attrs) > 0)
		{
		local $_;
		$variant = join(',',
				map {$_ . '=' . $attrs{$_};} (sort keys %attrs));
		}
	}
return ($space, $name, $variant, $ver);
}

sub remix_attrs
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $ver		= $args->accept('version', undef);
my $variant	= $args->accept('variant', undef);
$args->argok();

my $returner;
my %attrs;
if(defined $variant)
	{
	my @attlist = split(',', $variant);
	while(my $attpair = shift @attlist)
		{
		my ($attkey, $attval) = split('=', $attpair, 2);
		$attrs{$attkey}=$attval;
		}
	}
if(defined $ver)
	{
	$attrs{ver} = $ver;
	}
if((scalar keys %attrs) > 0)
	{
	local $_;
	$returner = join(',',
			map {$_ . '=' . $attrs{$_};} (sort keys %attrs));
	}
}

sub wipe_file
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $name	= $args->mandate('filename');
my $ns		= $args->mandate('namespace');
my $ver		= $args->accept('version', undef);
my $var		= $args->accept('variant', undef);
$args->argok();

my $id = file_exists(filename => $name, namespace => $ns, version => $ver, variant => $var);
if(! $id) {return 0;}
my %fileinfo = all_fileinfo_from_id(file_id => $id);
if($fileinfo{storetype} eq 'file')
	{
	return db_wipe_file(file_id => $id, blob_id => $fileinfo{blobid});
	}
else
	{
	return file_wipe_file(file_id => $id, filename => $fileinfo{filename});
	}
}

sub embed_media
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $fileid	= $args->mandate('file_id');
my $fname	= $args->mandate('filename');
my $context	= $args->mandate('context');
my $alt		= $args->accept('alt_text', undef);
$args->argok();

my %fileinfo = all_fileinfo_from_id(file_id => $fileid);
if(! defined $fileinfo{mimetype})
	{
	return "Failed Inner Link: Bad mimetype for mediaid $fileid\n";
	}
my $prologue;
my $postlogue;
my $alttext='';
if($fileinfo{mimetype} =~ /^image/)
	{
	$prologue = q{<img src="};
	$postlogue = q{ />};
	if(defined $alt) {$alttext = qq{ title="$alt" alt="$alt"};}
	}
elsif($fileinfo{mimetype} =~ /^audio/)
	{
	$prologue = q{<embed src="};
	$postlogue = q{ />};
	}
return $prologue . url_file(filename => $fname, namespace => $context) . q{"} . $alttext . $postlogue;
}

sub infer_mimetype_from_filetype
{ # Yay, found a module to do this!
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $filetype = $args->mandate('filetype');
$args->argok();

my $mimetypes = MIME::Types->new;
return $mimetypes->mimeTypeOf($filetype);
}

1;
