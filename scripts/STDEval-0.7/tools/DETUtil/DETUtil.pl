#!/usr/bin/perl -w

# DETUtil
# DETUtil.pl
# Author: Jonathan Fiscus
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. asclite is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use Getopt::Long;
use Data::Dumper;

use lib qw(../../src);
use DETCurve;

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $VERSION = 0.1;

sub usage
{
    print "DETUtil.pl [ [-s|-e] exp ]* [ -t TMPDIR ] -o outputPNG [ searializedDET1, searializedDET2, ...]\n";
    print "\n";
    print "Required file arguments:\n";
    print "  -o, --output-png         Path to write the PNG to\n";
    print "Optional arguments:\n";
    print "  -t, --tmpdir             Path to write temporary files in.\n";
    print "  -k                       Keep the .plt and dat files instead of deleting them\n";
    print "  -s, --select-filter exp  Reduce the combined printout by only including the curves\n";
    print "                           that match the regular expression:\n";
    print "                               title:exp forces the match on the title\n"; 
    print "  -e, --edit-filter exp    Edit the titles to reduce/expand the elements printed in the combined\n";
    print "                           plot with the regular expression:\n";
    print "                              title:exp edits the title\n"; 
    print "Graph tweaks:\n";
    print "  -Title STR               Use STR for the title of the plot\n";    
    print "  -lineTitle STR           Modify the output line title by removing default information. STR\n";
    print "                           can include any number of these characters\n";
    print "                               P -> removes the Maximum Value Point Coordinates\n";
    print "                               T -> removes the DET Curve Type\n";
    print "                               M -> removes the Maximum Value\n";
    print "  -KeyLoc STR              Place the key at one of the locations: \n";
    print "                               STR => left | right | top | bottom | outside | below\n";
    print "  -Scale Xmin:Xmax:Ymin:Ymax   Sets the X and Y axis ranges to the values.  All points must be\n";
    print "                           present\n";
    print "\n";
}


my $OutPNGfile = "";
my $tmpDir = "/tmp";
my @selectFilters = ();
my @editFilters = ();
my $keepFiles = 0;
my $title = undef;
my $scale = undef;
my $lineTitleModification = "";
my $keyLoc = undef;
GetOptions
(
    'output-png=s'                       => \$OutPNGfile,
    'tmpdir=s'                           => \$tmpDir,
    'select-filter=s'                    => \@selectFilters,
    'edit-filter=s'                      => \@editFilters,
    'keepFiles'                          => \$keepFiles,
    'Title=s'                            => \$title,
    'lineTitle=s'                        => \$lineTitleModification,
    'Scale=s'                            => \$scale,
    'KeyLoc=s'                           => \$keyLoc,
    'version',                           => sub { print "STDListGenerator version: $VERSION\n"; exit },
    'help'                               => sub { usage (); exit },
);

die "ERROR: An Output file must be set." if($OutPNGfile eq "");
### Check the filter syntax
foreach $_(@selectFilters){
    die "Error: Select Filter '$_' does not match a legal expression" if ($_ !~ /^title:.+$/);
}
foreach $_(@editFilters){
    die "Error: Edit Filter '$_' does not match a legal expression" if ($_ !~ /^title:s\/[^\/]+\/[^\/]*\/(g|i|gi|ig|)$/);
}

my %options = ();
$options{title} = $title if (defined $title);
$options{noSerialize} = 1;

$options{lTitleNoDETType} = 1 if ($lineTitleModification =~ /T/);
$options{lTitleNoPointInfo} = 1 if ($lineTitleModification =~ /P/);
$options{lTitleNoMaxValue} = 1 if ($lineTitleModification =~ /M/);

if (defined($scale)){
    die "Error: Invalid Scale '$scale'. must match N:N:N:N" if ($scale !~ /^(\d+|\d+.\d+):(\d+|\d+.\d+):(\d+|\d+.\d+):(\d+|\d+.\d+)$/);
    $options{Xmin} = $1;
    $options{Xmax} = $2;
    $options{Ymin} = $3;
    $options{Ymax} = $4;
}

if (defined($keyLoc)){
    die "Error: Invalid key location '$keyLoc'" if ($keyLoc !~ /^(left|right|top|bottom|outside|below)$/);
    $options{KeyLoc} = $keyLoc;
}

### make a temporary dirctory
my $temp = "$tmpDir/DET.$$";

my @dets = ();
foreach my $srl(@ARGV){
    my $det = DETCurve::readFromFile($srl);
    my $keep = 0;
    $keep = 1 if (@selectFilters == 0);
    foreach $_(@selectFilters){
	my ($field, $exp) = split(/:/,$_,2);
	if ($field eq "title"){
	    $keep = 1 if ($det->{LINETITLE} =~ /$exp/);
	}
    }
    if ($keep){
	foreach $_(@editFilters){
	    my ($field, $exp) = split(/:/,$_,2);
	    my ($op, $op1, $op2, $cond) = split(/\//,$exp,4);
	    $cond = "" if (! defined($cond));
	    if ($field eq "title"){
		if ($cond eq "g"){
		    $det->{LINETITLE} =~ s/$op1/$op2/g;
		} elsif ($cond eq "i") {
		    $det->{LINETITLE} =~ s/$op1/$op2/i;
		} elsif (($cond eq "gi") || ($cond eq "ig")) {
		    $det->{LINETITLE} =~ s/$op1/$op2/gi;
        } else {
		    $det->{LINETITLE} =~ s/$op1/$op2/;
		}
	    }
	}	
	push @dets, $det;
    }
}

### Setup a cleanup signal
sub cleanup {
    system "rm -rf $temp";
}
$SIG{INT} = \&cleanup;

system "mkdir $temp";
DETCurve::writeMultiDetGraph("$temp/merge", \@dets, \%options);
system "cp $temp/merge.png $OutPNGfile";
cleanup() if (! $keepFiles);
