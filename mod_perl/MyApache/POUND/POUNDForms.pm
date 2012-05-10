#!/usr/bin/perl

# Generate forms with less fuss

use strict;
use DBI;
package MyApache::POUND::POUNDForms;

require Exporter;
require AutoLoader;

use MyApache::POUND::Argpass;

our @ISA = qw(Exporter AutoLoader);
our @EXPORT_OK = qw(stform endform form_txtfield form_privtxtfield form_txtarea stselect addselect endselect form_checkbox form_hidden form_filefield);
our @EXPORT = @EXPORT_OK;

sub stform
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $submiturl	= $args->mandate('submit_url');
my $formid	= $args->mandate('formid');
my $files_kosher= $args->accept('allow_files', 0);
my $validator	= $args->accept('validator', undef); # Prevent foreign forms from posting to us
$args->argok();

my $file_extra = $files_kosher ? qq{enctype="multipart/form-data"} : '';
print qq{<form id="$formid" name="$formid" action="$submiturl" method="post" $file_extra>\n};
if(defined $validator)
	{
	form_hidden(name => 'validcode', value => $validator);
	}
}

sub endform
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $submit_string = $args->mandate('submit');
$args->argok();

if(defined($submit_string))
	{
	print qq{<input type=submit value="$submit_string" name="$submit_string">\n};
	}
print qq{</form>};
}

sub form_txtfield
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $caption 	= $args->mandate('caption');
my $name	= $args->mandate('name');
my $size	= $args->accept('size', 20);
my $value	= $args->accept('value', '');
my $maxlength	= $args->accept('max_length', undef);
$args->argok();

my $captionarea;
my $mla='';
if(! (defined($caption) && ($caption ne '')))
	{$captionarea = '';}
else
	{$captionarea = q{<span class="formcaption">} . $caption . ': </span>';}
if(defined($maxlength))
	{
	$mla = "maxlength=\"$maxlength\"";
	}
print $captionarea . qq{<input type=text value="$value" name="$name" size=$size $mla><br />\n};
}

sub form_filefield
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

print qq{<input type=file name="newfile"><br />\n};
}

sub form_privtxtfield
{ # FIXME consider merging with form_txtfield
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $caption 	= $args->mandate('caption');
my $name	= $args->mandate('name');
my $size	= $args->accept('size', 20);
my $maxlength	= $args->accept('max_length', undef);
$args->argok();

my $mla = '';
my $captionarea;
if(! (defined($caption) && ($caption ne '')))
	{$captionarea = '';}
else
	{$captionarea = q{<span class="formcaption">} . $caption . ': </span>';}
if(defined($maxlength))
	{
	$mla = "maxlength=\"$maxlength\"";
	}
print $captionarea . qq{<input type=password value="" name="$name" size=$size $mla><br />\n};
}

sub form_txtarea
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $caption 	= $args->mandate('caption');
my $name	= $args->mandate('name');
my $cols	= $args->accept('cols', 80);
my $rows	= $args->accept('rows', 24);
my $value	= $args->accept('value', '');
$args->argok();

my $captionarea;
if( (! defined($caption)) || ($caption eq ''))
	{$captionarea = '';}
else
	{$captionarea = q{<span class="formcaption">} . $caption . ': </span>';}

print $captionarea . qq{<br /><textarea name="$name" rows=$rows cols=$cols wrap="virtual">$value</textarea><br />\n};
}

sub stselect
{ # Now with multi-selects. Hurrah!
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $caption	= $args->mandate('caption');
my $name	= $args->mandate('name');
my $default	= $args->accept('default', undef);
my $multi	= $args->accept('multi', undef);
$args->argok();

my $mstring = '';
if( ( ! defined($multi) ) || ($multi < 2) )
	{undef $multi;}
else
	{$mstring = "MULTIPLE SIZE=$multi"};
if($caption)
	{
	print qq{<span class="formcaption">$caption:</span>\n};
	}
print qq{<select name="$name" $mstring>\n};
if(defined($default) && $default)
	{
	print qq{<option value="nochange">$default</option>\n};
	}
}

sub endselect
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
$args->argok();

print qq{</select><br />\n};
}

sub addselect
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $value 	= $args->mandate('value');
my $text	= $args->mandate('text');
$args->argok();

print qq{<option value="$value">$text</option>\n};
}

sub form_checkbox
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $caption	= $args->mandate('caption');
my $name	= $args->mandate('name');
my $defval	= $args->accept('default', 0);
my $rightside	= $args->accept('rightside', 0);
$args->argok();

my $checks = '';
if($defval)
	{
	$checks = 'checked ';
	}
my $left='';
my $right='';
(($rightside)?$right:$left) = qq{<span class="formcaption">$caption</span>};
print qq{$left<input type=checkbox name='$name' $checks id='$name'>$right};
}

sub form_hidden
{
my $args = MyApache::POUND::Argpass::new('clean', @_);
my $name	= $args->mandate('name');
my $value	= $args->mandate('value');
$args->argok();

print qq{<input type=hidden value="$value" name="$name">};
}

1;
