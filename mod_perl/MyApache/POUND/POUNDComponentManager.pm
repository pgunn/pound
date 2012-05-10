#!/usr/bin/perl -w


# A certain near-duplication of function names is likely with POUNDConfigDB - need to handle that gracefully
#	when we're further along.

##########################
use strict;
package MyApache::POUND::POUNDComponentManager;
use MyApache::POUND::Argpass;
use MyApache::POUND::POUNDConfigDB;

=pod

=head1 NAME

POUNDComponentManager - A singleton class that acts as a component/path manager.

=head1 SYNOPSIS

Using this module, POUND modules can specify, when loaded, the URLpaths that they
handle, the mappings of concepts to URLs for specific content, and configuration
keys they're configured by.

Using this module, we're aiming for:
1) Addition/maintenance of configuration for modules not needing to be "edited-in" to
	dozens of files for just basic functionality
2) Having fewer functions in the global namespace
3) Using function factories, ideally a lot less code that does basically the same thing.
4) Any exciting refactoring that becomes possible/easier/more obvious from the above

Unfortunately, by making this more dynamic, we're pushing to runtime a number of things
that Perl used to do for us at compiletime, and foregoing a lot of the nice checking it
gave us. 

Types of registration:
	DBTables are database tables that a given component needs. If I decide to go ahead with this
		idea, POUND will attempt to create said tables if they don't exist when the module loads,
		and (maybe) update the schema with column inserts or whatever if it doesn't match.
	Pathkeys are (usually database-derived) functions that return path components.
		They're registered with default values, user-readable descriptions, etc.
		The functions lazy-initialise the database config if they describe a field
		that's not yet in the pathkey registery (unless they're registered as a
		"hardcoded" pathkey). 
	Configkeys are (usually database-derived) functions that represent tweakable options
		in POUND. They're registered with default values, user-readable descriptions, etc.
		Like Pathkeys, they lazy-initialise the database unless registered as hardcoded.
	Pathfns are functions that return paths to "entire" things. The functions are usually are built on
		pathkeys and in some cases configkeys too.
	Mainhooks are functions that recieve dispatches from the main entry point in POUND. I am considering
		allowing other large entry-points (like "wiki" or "blog") to register mainhooks under their
		own contexts.
	Markuphooks are used to add another handler to the markup engine. I'm not presently sure how this
		should work
=cut

my $no_redefine=1;
##################################################
my $pcm_singleton;

sub new
{
if(! defined $pcm_singleton)
	{
	my %pathfn; # POUNDPaths
	my %mhook; # Mainhooks
	my %ckey; # configkeys
	my %pkey; # pathkeys
	$pcm_singleton =
		{
		ckey => \%ckey,		# configkey registry
		mhook => \%mhook,	# mainhook registry
		pathr => \%pathfn,	# pathpart registry
		pkey => \%pkey		# pathpart registry
		};
	bless $pcm_singleton;
	}
return $pcm_singleton;
}

##########################

sub pathkey
{
my $self = shift @_;
my $args	= Argpass::new('clean', @_);
my $key		= $args->mandate('key');
$args->argok();

if(! defined($self->{pkey}{$key}))
	{
	print STDERR "Internal error in POUND: pathkey [$key] requested but does not exist!\n";
	return '';
	}
if($self->{pkey}{$key}{static})
	{return $self->{pkey}{$key}{value};}
else
	{return get_pathkey(keyname => $self->{pkey}{$key}{dbkey});}
}

sub configkey
{
my $self = shift @_;
my $args	= Argpass::new('clean', @_);
my $key		= $args->mandate('key');
$args->argok();

if(! defined($self->{ckey}{$key}))
	{
	print STDERR "Internal error in POUND: configkey [$key] requested but does not exist!\n";
	return '';
	}
if($self->{ckey}{$key}{static})
	{return $self->{ckey}{$key}{value};}
else
	{return get_configkey(keyname => $self->{ckey}{$key}{dbkey});}
}

sub get_path
{
my $self = shift @_;
my $args	= Argpass::new('clean', @_);
my $key		= $args->mandate('key', @_);
my $params	= $args->mandate('params', @_);
$args->argok();
if(! defined $self->{pathr}{$key})
	{return (0, "No such path [$key] registered");}
return &{$self->{pathr}{$key}}(%$params); # Hopefully I have the syntax right!
}

sub mainhooks
{
my $self = @_;
my $args = Argpass::new('clean', @_);
$args->argok();

return keys %{$self->{mhook}};
}

sub dispatch_mainhook
{
my $self = shift @_;
my $args	= Argpass::new('clean', @_);
my $key		= $args->mandate('key', @_);
my $params	= $args->mandate('params', @_);
$args->argok();

if(! defined $self->{mhook}{$key})
	{return (0, "No such mhook [$key] registered");}
return &{$self->{mhook}{$key}}(%$params);
}

##########################
sub register_pathkey
{
my $self = shift @_;
my $args	= Argpass::new('clean', @_);
my $key		= $args->mandate('key');
my $default	= $args->accept('default', undef);
my $descrip	= $args->accept('description', undef);
my $dbkey	= $args->accept('dbkey', $key); # This is a bit novel in our Argpass regime...
my $nodb	= $args->accept('hardcoded', 0); # Set to 1 if the configkey is not registered in the database.
$args->argok();

if((! $nodb) && (! get_pathkey(keyname => $dbkey)) )
	{ # Pathkey does not already exist, so let's make an entry for it
	db_register_pathkey(keyname => $dbkey, description => $descrip, value => $default);
	}
$self->{pkey}{$key}{static} = $nodb;
if(! $nodb)
	{$self->{pkey}{$key}{dbkey} = $dbkey; }
else
	{$self->{pkey}{$key}{value} = $default;} # This is how hardcoding works
}

sub register_configkey
{
my $self = shift @_;
my $args	= Argpass::new('clean', @_);
my $key		= $args->mandate('key');
my $default	= $args->accept('default', undef);
my $descrip	= $args->accept('description', undef);
my $dbkey	= $args->accept('dbkey', $key); # This is a bit novel in our Argpass regime...
my $avals	= $args->accept('avalues', undef); # This is a bit novel in our Argpass regime...
my $nodb	= $args->accept('hardcoded', 0); # Set to 1 if the configkey is not registered in the database.
$args->argok();

if((! $nodb) && (! get_configkey(keyname => $dbkey)) )
	{ # Configkey does not already exist, so let's make an entry for it
	db_register_configkey(keyname => $dbkey, description => $descrip, value => $default, avalues => $avals);
	}
$self->{ckey}{$key}{static} = $nodb;
if(! $nodb)
	{$self->{ckey}{$key}{dbkey} = $dbkey; }
else
	{$self->{ckey}{$key}{value} = $default;} # This is how hardcoding works
}

sub register_mainhook
{ # Is there a good way to declare what arguments mainhook functions should take?
my $self = shift @_;
my $args	= Argpass::new('clean', @_);
my $key		= $args->mandate('key');
	# What should this argument be? Presumably the same as a pathpart.
my $fnref	= $args->mandate('hook');
$args->argok();

if($no_redefine && defined $self->{mhook}{$key})
	{return (0, "Attempt to redefine mhook [$key]");}
$self->{mhook}{$key} = $fnref;
}

sub register_pathfn
{ # We'll get the most benefit when the functions we're passed are made by factory methods...
my $self = shift @_;
my $args	= Argpass::new('clean', @_);
my $key		= $args->mandate('key');
my $resolver	= $args->mandate('resolve_hook');
# Path not taken: allow "contexts" and implement module namespaces
$args->argok();

if($no_redefine && defined $self->{pathr}{$key})
	{return (0, "Attempt to redefine path [$key]");}
$self->{pathr}{$key} = $resolver;
}


1;
