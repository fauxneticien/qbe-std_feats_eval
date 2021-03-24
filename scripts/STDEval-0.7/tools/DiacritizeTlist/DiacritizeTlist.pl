#!/usr/bin/perl -w

# DiacritizeTlist
# DiacritizeTlist.pl
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
use RTTMList;
use TermList;
use TermListRecord;
use STDList;
use STDDetectedList;
use Data::Dumper;

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $VERSION = 0.1;

sub usage
{
    print "STDEval.pl -t tlist -r rttmfile -o output_tlist [ -f threshhold ]\n";
    print "\n";
    print "Required file arguments:\n";
    print "  -t, --termfile           Path to the Term file.\n";
    print "  -r, --rttmfile           Path to the RTTM file.\n";
    print "  -o, --output-file        Path to the Output Tlist file.\n";
    print "  -f, --find-threshold     Filter the term set to exclude\n";
    print "                           terms not present in the RTTM using\n";
    print "                           the time threshhold\n";
    print "\n";
}


my $Termfile = "";
my $RTTMfile = "";
my $Outfile = "";
my $findTermThreshold = -1;

GetOptions
(
    'termfile=s'                          => \$Termfile,
    'rttmfile=s'                          => \$RTTMfile,
    'output-file=s'                       => \$Outfile,
    'find-threshhold'                     => \$findTermThreshold,
    'version',                            => sub { print "STDListGenerator version: $VERSION\n"; exit },
    'help'                                => sub { usage (); exit },
);

die "ERROR: An RTTM file must be set." if($RTTMfile eq "");
die "ERROR: An Term file must be set." if($Termfile eq "");
die "ERROR: An Output file must be set." if($Outfile eq "");

my $RTTM = new RTTMList($RTTMfile);
my $TERM = new TermList($Termfile);
my $TERMOUT = new_empty TermList($Outfile, $TERM->{ECF_FILENAME}, $TERM->{VERSION}, $TERM->{LANGUAGE});

### Loop through the RTTM file, building a mapping table for undiactrized lexemes
my %base2diaLUT = ();
foreach my $file(keys %{ $RTTM->{DATA} }){
    foreach my $chan(keys %{ $RTTM->{DATA}{$file} }){
	foreach my $rttmrec(@{ $RTTM->{DATA}{$file}{$chan} }){
	    my $token = $rttmrec->{TOKEN};
	    $token =~ tr/A-Z/a-z/;
	    ## Remove diacritics
	    my $base = $token;
	    $base =~ s/(\331\216|\331\220|\331\221|\331\222|\331\217)//g;
	    $base2diaLUT{$base}{$token} = 0 if (! exists($base2diaLUT{$base}{token}));
	    $base2diaLUT{$base}{$token}++;
	}
    }
}

### Loop through the terms.  Building ALL the variants
#foreach my $term(sort keys %{ $TERM->{TERMS} }){
#    print "------------------------------------------------------------------\n";
#    print "$term $TERM->{TERMS}{$term}->{TEXT}\n";
#    my @expansions = ();
#    foreach my $base(split(/\s+/,$TERM->{TERMS}{$term}->{TEXT})){
# 	$base =~ tr/A-Z/a-z/;
# 	if (exists($base2diaLUT{$base})){
# 	    push @expansions, [ $base2diaLUT{$base} ];
# 	} else {
# 	    push @expansions, [ ("N/A") ];
# 	}
#    }
# 
#    ### Make the variants
#    #print Dumper(\@expansions);
#}

foreach my $term(sort keys %{ $TERM->{TERMS} })
{
    my @expansions = ();
    
    foreach my $base(split(/\s+/, $TERM->{TERMS}{$term}->{TEXT}))
    {
        $base =~ tr/A-Z/a-z/;
        
        if (exists($base2diaLUT{$base}))
        {
            push @expansions, [ keys %{ $base2diaLUT{$base} } ];
        } 
        else 
        {
            push @expansions, [ ($base) ];
        }
    }
    
    #print Dumper(\@expansions);
    
    my %current;
    my %maxi;
    my $bigmaxi = 1;

    for(my $i=0; $i<@expansions; $i++)
    {
        $current{$i} = 0;
        $maxi{$i} = scalar @{ $expansions[$i] };
        $bigmaxi *= $maxi{$i}; 
    }
    
    my $cur = 0;
    $current{0} = -1;
    my $realTerms = 0;
    my $firstNewTerm = "";
    
    while($cur < $bigmaxi)
    {
        my $curpos = 0;
        my $ok = 0;
        
        while(!$ok)
        {
            $current{$curpos}++;
            
            if($current{$curpos} == $maxi{$curpos})
            {
                $current{$curpos} = 0;
                $curpos++;
            }
            else
            {
                $ok = 1;
            }
        }
     
        my $newterm = "$expansions[0][$current{0}]";
           
        for(my $i=1; $i<@expansions; $i++)
        {
            my $word = $expansions[$i][$current{$i}];
            $newterm .= " $word";
        }
        
        $cur++;
        my $displaycount = sprintf("%04d", $cur);
        my $newtermid = "$term" . "-$displaycount";
        $firstNewTerm = $newterm if ($firstNewTerm eq "");

	if ($findTermThreshold >= 0)
	{
	    my $occ = $RTTM->findTermOccurences($newterm, $findTermThreshold);
	    if (@{ $occ } > 0){
		$TERMOUT->{TERMS}{$newtermid} = new TermListRecord($newtermid, $newterm);
#		print "Add $newtermid\n";
		$realTerms++;
#	    } else {
#		print "Skipping $newtermid\n";
	    }
	} else {
	    $TERMOUT->{TERMS}{$newtermid} = new TermListRecord($newtermid, $newterm);
	    $realTerms++;
#	    print "Add $newtermid\n";
	}        
    }
    if ($realTerms == 0){
#	print "Adding term that already was an OOV $term\n";
	$TERMOUT->{TERMS}{$term} = new TermListRecord($term, $TERM->{TERMS}{$term}->{TEXT});
    }
}

$TERMOUT->saveFile();

