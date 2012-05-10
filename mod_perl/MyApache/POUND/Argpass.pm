#!/usr/bin/perl -w

use strict;
use Carp;
package MyApache::POUND::Argpass;


=pod

=head1 NAME

Argpass -- A class that make named-arguments easier in Perl, and
define a discipline that provides some safety in doing so.

=head1 SYNOPSIS

 use Argpass;

 sub test1
 {
 my $args = Argpass::new('clean', @_);
 my $argthree = $args->accept("argthree", "my default");
 my $argtwo = $args->mandate("argtwo");
 $args->mandate("argone");
 $args->mandate("argfour");
 $args->argok();
 }

For the verification tools, pass the simple sigil for the perl type you would
verify (e.g. '$', '\$', '\@', ..). The module will not verify multiple levels
of references or object classes.

=head1 METHODS

=cut

=pod

B<Argpass::new(POLICY, ARGS)>

Instantiate a new object with policy POLICY (changable) fed from arguments
ARGS.

=cut

sub new
{
my ($policy, %args) = @_;
if( ($policy ne 'loose') && ($policy ne 'clean'))
	{
	Carp::confess "Argpass asked to assume unknown policy $policy\n";
	}
my $self =
	{
	args => \%args,
	pol => $policy
	};
bless $self;
return $self;
}

=pod

B<accept(KEY, DEFAULT)>

Return value of argument with key KEY (or DEFAULT if does not exist).

=cut

sub accept($$$)
{
my ($self, $key, $default) = @_;
if(exists $self->{args}{$key}) # _not_ defined() - value may be undef, which still overrides default.
	{
	my $ret = $self->{args}{$key};
	delete $self->{args}{$key};
	return $ret;
	}
else
	{return $default;}
}

=pod

B<accept_v(SIGNATURE, KEY, DEFAULT)>

Return value of argument with key KEY (or DEFAULT if does not exist).
Dies if key present but value does not match signature SIGNATURE.

=cut

sub accept_v($$$$)
{
my ($self, $sig, $key, $default) = @_;
if(exists $self->{args}{$key}) # If it exists, verify type and accept
	{
	if(verify($sig, $self->{args}{$key}))
		{
		my $ret = $self->{args}{$key};
		delete($self->{args}{$key}); # Remove it from the hash entirely.
		return $ret;
		}
	else
		{
		Carp::confess "Invalid argument: signature $sig not matched! ";
		}
	}
# otherwise, just accept default
return $default;
}

=pod

B<mandate(KEY)>

Return value of argument with key KEY. Dies if key not present.

=cut

sub mandate($$)
{
my ($self, $key) = @_;
if(exists $self->{args}{$key})
	{
	my $ret = $self->{args}{$key};
	delete $self->{args}{$key};
	return $ret;
	}
Carp::confess "Mandated argument $key not present! ";
}

=pod

B<mandate_v(SIG, KEY)>

Return value of argument with key KEY. Dies if key not present or if
the value does not match the signature SIG.

=cut

sub mandate_v($$$)
{
my ($self, $sig, $key) = @_;
if(exists $self->{args}{$key}) # If it exists, verify type and accept
	{
	if(verify($sig, $self->{args}{$key}))
		{
		my $ret = $self->{args}{$key};
		delete($self->{args}{$key}); # Remove it from the hash entirely.
		return $ret;
		}
	else
		{
		Carp::confess "Invalid argument: signature $sig not matched! ";
		}
	}
Carp::confess "Mandated argument $key not present! ";
}

=pod

B<policy(POLICY)>

Set policy to either 'clean' or 'loose'. Clean mandates that no arguments be
passed to the function that are not retrieved (for young interfaces). Loose
allows spurious arguments at the cost of less checking for typos/etc (for
older interfaces). These are checked at the time argok() is called.

=cut

sub policy($)
{ # Hmm. Need some some inner state or disallow nesting arg handling. 
my ($self, $policy) = @_;
$self->{pol} = $policy; # TODO Check for invalid values..
}

=pod

B<argok()>

Give notice that everything has been parsed, allow policy checking and discard
unneeded state.

=cut

sub argok($)
{
my ($self) = @_;
if($self->{pol} eq 'clean')
	{
	if( (keys %{$self->{args}}) != 0)
		{
		Carp::confess "Argpass policy violation: Unknown keys " . join(' ', keys %{$self->{args}}) . "\n";
		}
	}
}

sub verify($$)
{
my ($sig, $var) = @_; # MUST allow $var to be undef, handle appropriately
if($sig eq '$')
	{
	if(ref($var))
		{Carp::confess "Verification failed in argument passing: $var is not a scalar\n";}
	}
elsif($sig =~ /^r(.)/)
	{ # reference
	my $reft = $1;
	my $refto = ref($var);
	if(! $refto)
		{Carp::confess "Verification failed in argument passing: $var is not a reference\n";}
	if(
	(($reft eq '$') && ($refto ne 'SCALAR'))
	||
	(($reft eq '@') && ($refto ne 'ARRAY'))
	||
	(($reft eq '%') && ($refto ne 'HASH'))
	||
	(($reft eq '&') && ($refto ne 'CODE'))
	||
	(($reft eq '\\') && ($refto ne 'REF'))
	 )
		{
		Carp::confess "Verification failed in argument passing: $var is not of type $reft\n";
		}
	}
else
	{Carp::confess "Unknown verification standard [$sig]\n";}
return 1;
}

1;

__END__

=pod

=head1 TO DO

Think about other disciplines, better typechecking for _v functions, implement verification

=head1 BUGS

None

=head1 COPYRIGHT

Public Domain

=head1 AUTHORS

Pat Gunn <pgunn@dachte.org>

=cut

