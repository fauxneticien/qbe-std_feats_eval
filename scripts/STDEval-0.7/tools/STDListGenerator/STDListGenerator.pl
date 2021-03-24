#!/usr/bin/perl -w

# STDListGenerator
# STDListGenerator.pl
# Author: Jerome Ajot
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
use STDList;
use STDDetectedList;

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $VERSION = 0.1;

sub usage
{
    print "STDEval.pl -e ecffile -r rttmfile -o outputfile\n";
    print "\n";
    print "Required file arguments:\n";
    print "  -t, --termfile           Path to the Term file.\n";
    print "  -r, --rttmfile           Path to the RTTM file.\n";
    print "  -o, --output-file        Path to the Output file.\n";
    print "  -F, --Find-threshold     Threshold.\n";
    print "\n";
}


my $Termfile = "";
my $RTTMfile = "";
my $Outfile = "";
my $thresholdFind = 0.5;

GetOptions
(
    'termfile=s'                          => \$Termfile,
    'rttmfile=s'                          => \$RTTMfile,
    'output-file=s'                       => \$Outfile,
    'Find-threshold=f'                    => \$thresholdFind,
    'version',                            => sub { print "STDListGenerator version: $VERSION\n"; exit },
    'help'                                => sub { usage (); exit },
);

die "ERROR: An RTTM file must be set." if($RTTMfile eq "");
die "ERROR: An Term file must be set." if($Termfile eq "");
die "ERROR: An Output file must be set." if($Outfile eq "");

my $RTTM = new RTTMList($RTTMfile);
my $TERM = new TermList($Termfile);
my $STDOUT = new_empty STDList($Outfile);

$STDOUT->{LANGUAGE} = $TERM->{LANGUAGE};
$STDOUT->{TERMLIST_FILENAME} = $Termfile;

foreach my $termsid(sort keys %{ $TERM->{TERMS} })
{
    my $terms = $TERM->{TERMS}{$termsid}->{TEXT};
    my $occurrences = $RTTM->findTermOccurrences($terms, $thresholdFind);
    
    my $detectedterm = new STDDetectedList($termsid, 0, 0);
    
    for(my $i=0; $i<@$occurrences; $i++)
    {
        my $file = @{ $occurrences->[$i] }[0]->{FILE};
        my $chan = @{ $occurrences->[$i] }[0]->{CHAN};
        my $bt = @{ $occurrences->[$i] }[0]->{BT};
        my $numberoftoken = @{ $occurrences->[$i] };
        my $et = @{ $occurrences->[$i] }[$numberoftoken-1]->{ET};
        my $dur = sprintf("%.4f", $et - $bt);
        my $rttm = \@{ $occurrences->[$i] };
	my $score = 0.0;
	for (my $t=0; $t<$numberoftoken; $t++){
	    $score += @{ $occurrences->[$i] }[$t]->{CONF};
	}
	$score /= $numberoftoken;
                
        push( @{ $detectedterm->{TERMS} }, new STDTermRecord($file, $chan, $bt, $dur, $score, "YES"));
    }
    
    $STDOUT->{TERMS}{$termsid} = $detectedterm;
}

$STDOUT->saveFile();

