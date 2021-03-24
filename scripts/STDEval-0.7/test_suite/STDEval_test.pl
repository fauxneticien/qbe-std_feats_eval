#!/usr/bin/perl -w

# STDEval
# STDEval_test.pl
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
use lib qw(../src);
use RTTMList;
use ecf;
use STDAlignment;
use Trials;
use DETCurve;

sub File2String
{
    my($filename) = @_;
    
    open(FILE, $filename) or die "Cannot open '$filename'";
    
    my $string = "";

    while (<FILE>)
    {
        chomp;
        $string .= $_;
    }

    close(FILE);

    #clean unwanted spaces
    $string =~ s/\s+/ /g;
    $string =~ s/> </></g;
    $string =~ s/^\s*//;
    $string =~ s/\s*$//;

    return $string;
}

if(RTTMList::unitTest())
{
    print "  SUCCESS!\n\n";
}
else
{
    die "  FAILED!";
}

if(ecf::unitTest())
{
    print "  SUCCESS!\n\n";
}
else
{
    die "  FAILED!";
}

if(STDAlignment::unitTest())
{
    print "  SUCCESS!\n\n";
}
else
{
    die "  FAILED!";
}

if(Trials::unitTest())
{
    print "  SUCCESS!\n\n";
}
else
{
    die "  FAILED!";
}

if(DETCurve::unitTest())
{
    print "  SUCCESS!\n\n";
}
else
{
    die "  FAILED!";
}

print "Test DataCalculation\n";

print " Alignments... ";

system("perl -I../src ../src/STDEval.pl -e test3.ecf.xml -r test3.rttm -s test3.stdlist.xml -t test3.tlist.xml -a test3.output.AlignReport.txt 1>/dev/null");

my $test3_out = File2String("test3.output.AlignReport.txt");
my $test3_gen = File2String("test3.AlignReport.txt");

if($test3_gen eq $test3_out)
{
    print "OK\n";
}
else
{
    print "FAILED!\n";
    exit 0;
}

print " Occurrences... ";

system("perl -I../src ../src/STDEval.pl -e test3.ecf.xml -r test3.rttm -s test3.stdlist.xml -t test3.tlist.xml -o test3.output.OccurrenceReport.txt -A 1>/dev/null");
    
$test3_out = File2String("test3.output.OccurrenceReport.txt");   
$test3_gen = File2String("test3.OccurrenceReport.txt");

if($test3_gen eq $test3_out)
{
    print "OK\n";
}
else
{
    print "FAILED!\n";
    exit 0;
}

print " Conditional Occurrences... ";
system("perl -I../src ../src/STDEval.pl -e test3.ecf.xml -r test3.rttm -s test3.stdlist.xml -t test3.tlist.xml -Y BN+CTS:BNEWS,CTS -Y MTG:CONFMTG -O test3.output.CondOccurrenceReport.txt -A 1>/dev/null");

if(File2String("test3.output.CondOccurrenceReport.txt") eq File2String("test3.CondOccurrenceReport.txt"))
{
    print "OK\n";
}
else
{
    print "FAILED!\n";
    exit 0;
}

print " Alignments with ECF Filtering... ";

system("perl -I../src ../src/STDEval.pl -e test3.ecf.xml -r test3.rttm -s test3.stdlist.xml -t test3.tlist.xml -a test3.output.AlignReport.txt -E 1>/dev/null");

$test3_out = File2String("test3.output.AlignReport.txt");
$test3_gen = File2String("test3.AlignReport.txt");

if($test3_gen eq $test3_out)
{
    print "OK\n";
}
else
{
    print "FAILED!\n";
    exit 0;
}

print " Alignments with Scoring ECF Filtering... ";

system("perl -I../src ../src/STDEval.pl -e test3.scoring.ecf.xml -r test3.rttm -s test3.stdlist.xml -t test3.tlist.xml -a test3.output.scoringECF.AlignReport.txt -E 1>/dev/null");

$test3_out = File2String("test3.output.scoringECF.AlignReport.txt");
$test3_gen = File2String("test3.scoringECF.AlignReport.txt");

if($test3_gen eq $test3_out)
{
    print "OK\n";
}
else
{
    print "FAILED!\n";
    exit 0;
}

print "  SUCCESS!\n\n";

print "Test Caching\n";
print " Generate Cache...         ";

system("perl -I../src ../src/STDEval.pl -e test2.ecf.xml -r test2.rttm -s test2.stdlist.xml -t test2.tlist.xml -o test2.output.without-caching.txt -A -c test2.output.cache 1>/dev/null");

print "OK\n";

print " Generate cached Report... ";

system("perl -I../src ../src/STDEval.pl -e test2.ecf.xml -r test2.rttm -s test2.stdlist.xml -t test2.tlist.xml -o test2.output.with-caching.txt -A -c test2.output.cache 1>/dev/null");

print "OK\n";

print " Validate Cache...         ";

my $caching = File2String("test2.output.with-caching.txt");
my $nocaching = File2String("test2.output.without-caching.txt");

if($nocaching eq $caching)
{
    print "OK\n";
}
else
{
    print "FAILED!\n";
    exit 0;
}

print "  SUCCESS!\n\n";

print "ALL TESTS SUCCESSED!\n";

1;
