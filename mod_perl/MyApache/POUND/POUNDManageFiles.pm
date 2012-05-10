#!/usr/bin/perl

use strict;
use DBI;
package MyApache::POUND::POUNDManageFiles;

require Exporter;
require AutoLoader;
our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(dispatch_upload_file dispatch_manage_files);
our @EXPORT = @EXPORT_OK;

use Apache2::Upload;
use Apache2::Request;
use MyApache::POUND::POUNDDB;
use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDApache;
use MyApache::POUND::POUNDFiles;
use MyApache::POUND::POUNDPerson;
use MyApache::POUND::POUNDUser;
use MyApache::POUND::POUNDSession;
use MyApache::POUND::POUNDPaths;
use MyApache::POUND::POUNDForms;
use MyApache::POUND::POUNDHTML;
use MyApache::POUND::POUNDFilesDB;

# Provide an interface to manage files

sub dispatch_upload_file
{ # Interface to upload files... See pndc as an example of how to do this, but use blob_writefile from POUNDFiles instead
	# TODO Manage versioning
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r	= $args->mandate('apacheobj');
my $fargs 	= $args->mandate('args');
$args->argok();
my $uid = session_uid(apacheobj => $apache_r);
if(! defined $uid)
	{ # Handle no uid
	errorpage(text => "You're not logged in");
	return;
	}
if(! uid_can_upload(userid => $uid) )
	{
	errorpage(text => "Your account privileges do not permit uploading");
	return;
	}
if(! @$fargs)
	{ # XXX Right now we only support BLOBs. Eventually do non-BLOB uploads based on site config, and also offer option of
		# reference to external URL "files"
	sthtml(title => "POUND: Upload a File",  no_css => 1);
	stform(submit_url => join('/', url_upload_file(), 'post'), formid => 'upload_file', allow_files => 1, validator => apache_session_key(apacheobj => $apache_r));
	form_txtfield(caption => 'Filename', name => 'filename');
	form_txtfield(caption => 'Namespace', name => 'namespace');
	form_hidden(name => 'creator', value => $uid); # Consider allowing superusers to override this. Also, check this in the POST
	form_filefield();
	endform(submit => 'Upload');
	endhtml();
	}
else # We have a POST, in theory
	{
	if(! is_POST(apacheobj => $apache_r))
		{
		errorpage(text => "BAD POST: Not a POST", 0);
		return;
		}
	my %post = post_content(apacheobj => $apache_r);
	foreach my $key (qw/filename namespace creator/)
		{
		$post{$key} = lc de_post_mangle(post_in => $post{$key}); # No uppercase! XXX Document this. Maybe allow as an option?
		}
	if( ($post{creator} != $uid)
&&		(! uid_is_super(userid => $uid) ) )
		{
		errorpage(text => "Submitted userid does not match your userid");
		return;
		}

	if($post{validcode} ne apache_session_key(apacheobj => $apache_r))
		{
		errorpage(text => 'BAD POST: Foreign source? Failed security check');
		return;
		}
	
# TODO Figure out when people are trying to write into somebody else's namespace and disallow it
	my $reqobj = Apache2::Request->new($apache_r);
	if(my $uphandle = $reqobj->upload("newfile") ) # Apache2::Upload
		{
		my $data;
		my $size = $uphandle->slurp($data); # sigh
		print STDERR "Got here, with size $size\n";
		my $filename = $uphandle->filename(); # Need to sanitize this if we're to use it - may contain a path..
		# TODO now to handle it sensibly...
		my $filetype; # extension. Disallow uploads without one.
		my $mimetype; # inferred from filetype

		print STDERR "Input filename of $post{filename}\n";
		$post{filename} =~ /^.*\.(.+)$/; # Snag the extension
		my $filetype = $1;
		print STDERR "Extracted extn of $filetype\n";
		if(! $filetype) {errorpage(text => "Uploaded file [$post{filename}] lacks an extension, upload cancelled");}
		my $mimetype = infer_mimetype_from_filetype(filetype => $filetype);
		if(! $mimetype) {errorpage(text => "Could not infer mime type from extention [$filetype], upload cancelled");}
			# XXX Consider whitelisting kosher mimetypes

		# I have decided, for now, to require extensions on files rather than letting the user specify them. I know that I
		# don't have to do it this way.

		my $lobj = blob_writefile(datref => \$data); # postgres-specific code
		db_register_file_blob(name => $post{filename}, namespace => $post{namespace}, blobid => $lobj, timehere => time(), version => 1, filetype => $filetype, mimetype => $mimetype, creator => $post{creator});
		msgpage(text => "Upload finished", url => url_manage_files() );
		}
	else
		{
		errorpage(text => "Upload failed");
		return;
		}
	}
}

sub dispatch_manage_files
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $apache_r = $args->mandate('apacheobj');
my $fargs 	= $args->mandate('args');
$args->argok();
my $uid = session_uid(apacheobj => $apache_r);
if(! defined $uid)
	{ # Handle no uid
	errorpage(text => "You're not logged in");
	return;
	}
my $super = uid_is_super(userid => $uid); # Manage ALL files if super, otherwise just the user's stuff

# TODO finish this up...
if(! @$fargs)
	{ # Main page
		# FIXME Make this pretty
	my $files; # reference to a list of hashes containing a tuple for each of the user's (or all) files
	if(! $super)
		{$files = get_all_files(owned_by => $uid);} # XXX Make sure this works - a bit of debugging suggests maybe it's broken?
	else
		{$files = get_all_files();}
	sthtml(title => "POUND - File management", no_css => 1);
	my @rows = qw/creator namespace name version variant timehere/; 
	print "<table border=1><tr>" . join('', map{"<th>$_</th>"} @rows) . "</tr>\n";
	foreach my $file (@$files)
		{
		my %uf_args = (filename => $$file{name}, namespace => $$file{namespace}); # Preparing args to get path to a file
		if($$file{version}) { $uf_args{version} = $uf_args{version};} # Most of the time, these won't
		if($$file{variant}) { $uf_args{variant} = $uf_args{variant};} # be needed.

		print "<tr>" . join('', map{"<td>$_</td>"}
			(
			uid_from_login(login => $$file{creator}), # Numeric owner-ids are probably not helpful to anyone
			$$file{namespace},
			$$file{name},
			$$file{version},
			$$file{variant},
			$$file{timehere},
			get_htlink(target => url_file(%uf_args), content => "View"),
			get_htlink(target => join('/', url_manage_files(), 'manage', $$file{id}), content => "Delete"),
			get_htlink(target => join('/', url_manage_files(), 'delete', $$file{id}), content => "Manage"),
			)) . "</tr>\n";
		}
	print "</table>\n";
	endhtml();
	}
else
	{ # Manage a file. 
		# Actions:
		# manage/fileid/variable
		# delete/fileid
	my $action = shift(@$fargs);
	my $fileid = shift(@$fargs);
	if($action eq 'manage')
		{
		subdispatch_manage_files_manage(fileid => $fileid, args => $fargs, userid => $uid, is_super => $super);
		}
	elsif($action eq 'delete')
		{
		subdispatch_manage_files_delete(fileid => $fileid, args => $fargs, userid => $uid, is_super => $super);
		}
	else
		{errorpage(text => 'Unknown action in file management');return;}
	}
}

sub subdispatch_manage_files_manage
{ # TODO: Figure out what this function should do
	# Note that we should check permissions
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $fileid	= $args->mandate('fileid');
my $fargs	= $args->mandate('args');
my $uid		= $args->mandate('userid');
my $super	= $args->mandate('is_super');
$args->argok();

}

sub subdispatch_manage_files_delete
{ # TODO: Implement. The idea is that we tell the user everything about the file, and
	# if the information is handy, what uses the file, and give them a delete button, which
	# points us right back here but passes us a flag (which we check for) telling us to parse the POST
	# Note that we should check permissions
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $fileid	= $args->mandate('fileid');
my $fargs	= $args->mandate('args');
my $uid		= $args->mandate('userid');
my $super	= $args->mandate('is_super');
$args->argok();

}

1;
