#!/usr/bin/perl -w

# ConditionalQueryTList
# ConditionalQueryTList.pl
# Author: Jerome Ajot
# 
# This software was developed at the National Institute of Standards and Technology by
# employees of the Federal Government in the course of their official duties.  Pursuant to
# Title 17 Section 105 of the United States Code this software is not subject to copyright
# protection within the United States and is in the public domain. STDEval is
# an experimental system.  NIST assumes no responsibility whatsoever for its use by any party.
# 
# THIS SOFTWARE IS PROVIDED "AS IS."  With regard to this software, NIST MAKES NO EXPRESS
# OR IMPLIED WARRANTY AS TO ANY MATTER WHATSOEVER, INCLUDING MERCHANTABILITY,
# OR FITNESS FOR A PARTICULAR PURPOSE.

use strict;
use Getopt::Long;
use Data::Dumper;

use lib qw(../../src);
use TermList;

Getopt::Long::Configure(qw( auto_abbrev no_ignore_case ));

my $VERSION = 0.1;

sub usage
{
    print "STDEval.pl -t termfile -q query -q query\n";
    print "\n";
    print "Required file arguments:\n";
    print "  -t, --termfile           Path to the Term file.\n";
    print "  -q, --query              Query.\n";
    print "\n";
}

sub union_intersection
{
    my($list1, $list2, $out_union, $out_intersection) = @_;
    
    my %union;
    my %isect;    
    foreach my $e (@{ $list1 }, @{ $list2 }) { $union{$e}++ && $isect{$e}++ }

    @{ $out_union } = keys %union;
    @{ $out_intersection } = keys %isect;
}

sub multiarray
{
    my($list1, $list2, $multi) = @_;
    
    foreach my $e1 (@{ $list1 })
    {
        foreach my $e2 (@{ $list2 })
        {
            push(@{$multi}, ($e1 ne "")?"$e1|$e2":"$e2");
        }
    }
}

my $Termfile = "";
my @Queries;

GetOptions
(
    'termfile=s' => \$Termfile,
    'query=s@'   => \@Queries,
    'help'       => sub { usage (); exit },
);

die "ERROR: A TermList file must be set." if($Termfile eq "");
die "ERROR: At least Query file must be set." if(scalar(@Queries) == 0);

my $TERM = new TermList($Termfile);

my %attributes;

foreach my $termid(keys %{ $TERM->{TERMS} } )
{
    foreach my $attrib_name(keys %{ $TERM->{TERMS}{$termid} })
    {
        if( ($attrib_name ne "TERMID") && ($attrib_name ne "TEXT") )
        {
            $attributes{$attrib_name} = 1;
        }
    }
}

foreach my $quer(@Queries)
{
    die "ERROR: $quer is not a valid attribute." if(!$attributes{$quer});
}

my %hashterm;

foreach my $termid(keys %{ $TERM->{TERMS} } )
{
    foreach my $attrib_name(keys %{ $TERM->{TERMS}{$termid} })
    {
        if( ($attrib_name ne "TERMID") && ($attrib_name ne "TEXT") )
        {
            my $attribute_value = $TERM->{TERMS}{$termid}->{$attrib_name};
            push(@{ $hashterm{$attrib_name}{$attribute_value} }, $termid);
        }
    }
}

my @multivalues = ("");
my @sorted_queries = sort @Queries;

foreach my $quer(@sorted_queries)
{
    my @values = sort keys %{ $hashterm{$quer} };
    my @finalmulti;
    multiarray(\@multivalues, \@values, \@finalmulti);
    @multivalues = @finalmulti;
}

my %hashlistterms;

foreach my $multivalue(@multivalues)
{
    my @values = split(/\|/, $multivalue);

    my @listterm = @{ $hashterm{$sorted_queries[0]}{$values[0]} };
    my $title = "$sorted_queries[0] $values[0]";
    
    for(my $i=1; $i<@sorted_queries; $i++)
    {
        my @outtmp;
        my @out_inter;
        union_intersection(\@listterm, \@{ $hashterm{$sorted_queries[$i]}{$values[$i]} }, \@outtmp, \@out_inter);
        @listterm = @out_inter;
        $title .= "|$sorted_queries[$i] $values[$i]";
    }
    
    $title =~ s/ /_/g;

    push(@{ $hashlistterms{$title} }, @listterm);
}

foreach my $finalkey(sort keys %hashlistterms)
{
    my $tmp = join(',', @{ $hashlistterms{$finalkey} });
    print "$finalkey:$tmp\n";
}
