#!/usr/bin/perl -w

# ECFSegmentor
# ECFSegmentor.pl
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
use ecf;

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $VERSION = 0.1;

sub diffsegment
{
    my($beg1, $end1, $beg2, $end2) = @_;
    my @out =();
    
    my $beg2in = ($beg2 > $beg1 && $beg2 < $end1);
    my $end2in = ($end2 > $beg1 && $end2 < $end1);
    
    if($beg2 > $beg1 || $end2 < $end1)
    {
        if(!$beg2in && !$end2in)
        {
            push(@out, [ ($beg1, $end1) ]);
        }
        elsif(!$beg2in && $end2in)
        {
            push(@out, [ ($end2, $end1) ]);
        }
        elsif($beg2in && !$end2in)
        {
            push(@out, [ ($beg1, $beg2) ]);
        }
        elsif($beg2in && $end2in)
        {
            push(@out, [ ($beg1, $beg2) ]);
            push(@out, [ ($end2, $end1) ]);
        }
    }
    
    return @out;
}

sub multidiffsegment
{
    my($beg, $end, @segments) = @_;
    my @out;
            
    if(@segments)
    {
        for(my $i=0; $i<@segments; $i++)
        {
            push(@out, diffsegment($segments[$i][0], $segments[$i][1], $beg, $end));
        }
    }
    
    return @out;
}

sub usage
{
    print "STDEval.pl -e ecffile -r rttmfile -o outputfile\n";
    print "\n";
    print "Required file arguments:\n";
    print "  -e, --ecffile            Path to the ECF file.\n";
    print "  -r, --rttmfile           Path to the RTTM file.\n";
    print "  -o, --output-file        Path to the Output file.\n";
    print "  -V, --Version-number     ECF version.\n";
    print "\n";
}


my $ECFfile = "";
my $RTTMfile = "";
my $Outfile = "";
my $Versionnumber = "";

GetOptions
(
    'ecffile=s'                           => \$ECFfile,
    'rttmfile=s'                          => \$RTTMfile,
    'output-file=s'                       => \$Outfile,
    'Version-number=s'                    => \$Versionnumber,
    'version',                            => sub { print "ECFSegmentor version: $VERSION\n"; exit },
    'help'                                => sub { usage (); exit },
);

die "ERROR: An RTTM file must be set." if($RTTMfile eq "");
die "ERROR: An ECF file must be set." if($ECFfile eq "");
die "ERROR: An Output file must be set." if($Outfile eq "");
die "ERROR: A Version must be set." if($Versionnumber eq "");

my $RTTM = new RTTMList($RTTMfile);
my $ECF = new ecf($ECFfile);
my $ECFOUT = new_empty ecf($Outfile);

$ECFOUT->{SIGN_DUR} = $ECF->{SIGN_DUR};
$ECFOUT->{VER} = $Versionnumber;

if($ECF->{EXCERPT})
{
    for(my $i=0; $i<@{ $ECF->{EXCERPT} }; $i++)
    {
        my $file = $ECF->{EXCERPT}[$i]->{AUDIO_FILENAME};
        my $purged_file = $ECF->{EXCERPT}[$i]->{FILE};;
        my $channel = $ECF->{EXCERPT}[$i]->{CHANNEL};
        my $begt = $ECF->{EXCERPT}[$i]->{TBEG};
        my $endt = $ECF->{EXCERPT}[$i]->{TEND};
        my $dur = $ECF->{EXCERPT}[$i]->{DUR};
        my $language = $ECF->{EXCERPT}[$i]->{LANGUAGE};
        my $source_type = $ECF->{EXCERPT}[$i]->{SOURCE_TYPE};
        
        my @segments = [($begt, $endt)];

        if($RTTM->{NOSCORE}{$purged_file}{$channel})
        {
            for(my $j=0; $j<@{ $RTTM->{NOSCORE}{$purged_file}{$channel} }; $j++)
            {
                @segments = multidiffsegment($RTTM->{NOSCORE}{$purged_file}{$channel}[$j]->{BT}, $RTTM->{NOSCORE}{$purged_file}{$channel}[$j]->{ET}, @segments);
            }
            
            if(@segments)
            {
                for(my $j=0; $j<@segments; $j++)
                {
                    push(@{ $ECFOUT->{EXCERPT} }, new ecf_excerpt($file, $channel, $segments[$j][0], sprintf("%.4f", $segments[$j][1]-$segments[$j][0]), $language, $source_type) );
                }
            }
        }
        else
        {
            push(@{ $ECFOUT->{EXCERPT} }, new ecf_excerpt($file, $channel, $begt, $dur, $language, $source_type) );
        }
    }
}

$ECFOUT->SaveFile();

