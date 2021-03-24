# STDEval
# DETCurve.pm
# Author: Jon Fiscus
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
#
# This package implements partial DET curves which means that not a TARGET trials have scores
# and not all NONTARG Trials have scores.  

package DETCurve;

use strict;
use Trials;
use Data::Dumper;

sub new {
    my ($class, $trials, $style, $block, $lineTitle, $valueV, $valueC, $probOfTerm) = @_;
    
    my $self = { TRIALS => $trials,
		 STYLE => undef,
		 LINETITLE => $lineTitle,
		 MINSCORE => undef,
		 MAXSCORE => undef,
		 VALUE_V => $valueV,
		 VALUE_C => $valueC,
		 BETA => $valueC / $valueV * ((1 / $probOfTerm) - 1),		 
		 PROB_OF_TERM => $probOfTerm,
		 MAXVALUE => { DETECTIONSCORE => undef, VALUE => undef, PFA => undef, PMISS => undef },
		 SYSTEMDECISIONVALUE => undef,  ### this is the value based on the system's hard decisions
		 POINTS => undef,  ## 2D array (score, Pmiss, Pfa, value);  IF style is blocked, then (sampleStandardDev(Pmiss), ssd(Pfa), ssd(ssdValue), $numBlocks) 
		 LAST_GNU_DETFILE_PNG => "",
		 LAST_GNU_THRESHPLOT_PNG => "",
		 LAST_SERIALIZED_DET => "",
		 MESSAGES => "",
	     };
    bless $self;
    die "Error: Style must be '(pooled|blocked|block=\\S+)' not '$style'" if ($style !~ /^(pooled|blocked|block=(\S+))$/);
    if ($style eq "pooled" || $style eq "blocked") {
	$self->{STYLE} = "$style";
    } else {
	die "Error: Curve style '$style' not implemented";
    }
    $self->computePoints();
    
    return $self;
}

sub thisabs{ ($_[0] < 0) ? $_[0]*(-1) : $_[0]};

sub unitTest{
    print "Test DETCurve\n";

    my $trial = new Trials("Term Detection", "Term", "Occurrence");
    
    $trial->addTrial("she", 0.1, "NO", 0);
    $trial->addTrial("she", 0.2, "NO", 0);
    $trial->addTrial("she", 0.3, "NO", 1);
    $trial->addTrial("she", 0.4, "NO", 0);
    $trial->addTrial("she", 0.5, "NO", 0);
    $trial->addTrial("she", 0.6, "NO", 0);
    $trial->addTrial("she", 0.7, "NO", 1);
    $trial->addTrial("she", 0.8, "YES", 0);
    $trial->addTrial("she", 0.9, "YES", 1);
    $trial->addTrial("she", 1.0, "YES", 1);
    $trial->addTrial("he", 0.41, "NO", 1);
    $trial->addTrial("he", 0.51, "YES", 0);
    $trial->addTrial("he", 0.61, "YES", 0);
    $trial->addTrial("he", 0.7, "YES", 1);

    print " Computing pooled curve...";
#    print $trial->dump(*STDOUT,"");
    my $det = new DETCurve($trial, "pooled", undef, "footitle", 1, 0.1, 0.0001);
    print "  OK\n";

    ## This was built from DETtesting-v2 with MissingTarg=0, MissingNonTarg=0
    #               Thr    Pmiss  Pfa    val
    my @points = [ (0.1,   0.000, 1.000, 0.867) ];
    push @points, [ (0.2,  0.000, 0.875, 0.883) ];
    push @points, [ (0.3,  0.000, 0.750, 0.900) ];
    push @points, [ (0.4,  0.167, 0.750, 0.733) ];
    push @points, [ (0.41, 0.167, 0.625, 0.750) ];
    push @points, [ (0.5,  0.333, 0.625, 0.583) ];
    push @points, [ (0.51, 0.333, 0.500, 0.600) ];
    push @points, [ (0.6,  0.333, 0.375, 0.617) ];
    push @points, [ (0.61, 0.333, 0.250, 0.633) ];
    push @points, [ (0.7,  0.333, 0.125, 0.650) ];
    push @points, [ (0.7,  0.500, 0.125, 0.483) ];
    push @points, [ (0.8,  0.667, 0.125, 0.317) ];
    push @points, [ (0.9,  0.667, 0.000, 0.333) ];
    push @points, [ (1.0,  0.833, 0.000, 0.167) ];
    print " Checking points...";
    for (my $i=0; $i<@points; $i++){
	die "Error: Det point isn't correct for point $i expected '".join(",",@{$points[$i]}).
	    "' got '".join(",",@{ $det->{POINTS}[$i]})."'"
	    if ($points[$i][0] != $det->{POINTS}[$i][0] ||
		thisabs($points[$i][1] - sprintf("%.3f",$det->{POINTS}[$i][1])) > 0.001 ||
		thisabs($points[$i][2] - sprintf("%.3f",$det->{POINTS}[$i][2])) > 0.001 ||
		thisabs($points[$i][3] - sprintf("%.3f",$det->{POINTS}[$i][3])) > 0.001);
    }
    print "  OK\n";
    print " Checking MaxValue...";
    my ($scr, $val, $Pmiss, $Pfa) = ($det->getMaxValueDetectionScore(),
				     $det->getMaxValueValue(),
				     $det->getMaxValuePMiss(),
				     $det->getMaxValuePFA());
    die "Error: Max value detection score incorrect $scr != 1.00" if (thisabs($scr - 0.30) > 0.001);
    die "Error: Max value value incorrect $val != 0.900" if (thisabs($val - 0.900) > 0.001);
    print "  OK\n";
    $det->setSystemDecisionValue(0.5);
#    $det->writeGNUGraph("foo");

    print " Computing pooled curve with nonTargetDenominator...";
    $trial->setPooledTotalTrials(40);
    $trial->addTrial("he", undef, "OMITTED", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);
    my $detFixDenom = new DETCurve($trial, "pooled", undef, "TargetDenom", 1.0, 0.1, 0.0001);
    print "  OK\n";
#    $detFixDenom->writeGNUGraph("fooDen");
    @points = ();
    ## This was built from DETtesting-v2 with MissingTarg=4, MissingNonTarg=22
    #               Thr    Pmiss  Pfa    val
    @points = [ (0.1,   0.400, 0.267, 0.520) ];
    push @points, [ (0.2,  0.400, 0.233, 0.530) ];
    push @points, [ (0.3,  0.400, 0.200, 0.540) ];
    push @points, [ (0.4,  0.500, 0.200, 0.440) ];
    push @points, [ (0.41, 0.500, 0.167, 0.450) ];
    push @points, [ (0.5,  0.600, 0.167, 0.350) ];
    push @points, [ (0.51, 0.600, 0.133, 0.360) ];
    push @points, [ (0.6,  0.600, 0.100, 0.370) ];
    push @points, [ (0.61, 0.600, 0.067, 0.380) ];
    push @points, [ (0.7,  0.600, 0.033, 0.390) ];
    push @points, [ (0.7,  0.700, 0.033, 0.290) ];
    push @points, [ (0.8,  0.800, 0.033, 0.190) ];
    push @points, [ (0.9,  0.800, 0.000, 0.200) ];
    push @points, [ (1.0,  0.900, 0.000, 0.100) ];
    print " Checking points...";
    for (my $i=0; $i<@points; $i++){
	die "Error: Det point isn't correct for point $i expected '".join(",",@{$points[$i]}).
	    "' got '".join(",",@{ $detFixDenom->{POINTS}[$i]})."'"
	    if ($points[$i][0] != $detFixDenom->{POINTS}[$i][0] ||
		thisabs($points[$i][1] - $detFixDenom->{POINTS}[$i][1]) > 0.001 ||
		thisabs($points[$i][2] - $detFixDenom->{POINTS}[$i][2]) > 0.001 ||
		thisabs($points[$i][3] - $detFixDenom->{POINTS}[$i][3]) > 0.001);
    }
    print "  OK\n";

    blockWeightedUnitTest();

#    unitTestMultiDet();

    return 1;
}

sub blockWeightedUnitTest(){
    print " Computing blocked curve without data...";
    
    #####################################  Without data  ###############################    
    my $emptyTrial = new Trials("Term Detection", "Term", "Occurrence");

    $emptyTrial->setPooledTotalTrials(100);

    $emptyTrial->addTrial("he", undef, "OMITTED", 1);
    $emptyTrial->addTrial("he", undef, "OMITTED", 1);
    $emptyTrial->addTrial("he", undef, "OMITTED", 1);
    $emptyTrial->addTrial("she", undef, "OMITTED", 1);
    $emptyTrial->addTrial("she", undef, "OMITTED", 1);
    $emptyTrial->addTrial("she", undef, "OMITTED", 1);

    my $emptydet = new DETCurve($emptyTrial, "blocked", undef, "footitle", 1, 0.1, 0.0001);
    die "Error: Empty det should not be successful()" if ($emptydet->successful());
    print "  OK\n";

    #####################################  With data  ###############################    
    print " Computing blocked curve with data...";
    my $trial = new Trials("Term Detection", "Term", "Occurrence");

    $trial->addTrial("she", 0.1, "NO", 0);
    $trial->addTrial("she", 0.2, "NO", 0);
    $trial->addTrial("she", 0.3, "NO", 1);
    $trial->addTrial("she", 0.4, "NO", 0);
    $trial->addTrial("she", 0.5, "NO", 0);
    $trial->addTrial("she", 0.6, "NO", 0);
    $trial->addTrial("she", 0.7, "NO", 1);
    $trial->addTrial("she", 0.8, "YES", 0);
    $trial->addTrial("she", 0.9, "YES", 1);
    $trial->addTrial("she", 1.0, "YES", 1);

    $trial->addTrial("he", 0.41, "NO", 1);
    $trial->addTrial("he", 0.51, "YES", 0);
    $trial->addTrial("he", 0.61, "YES", 0);
    $trial->addTrial("he", 0.7, "YES", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);
    $trial->addTrial("he", undef, "OMITTED", 1);

    $trial->addTrial("skip", 0.41, "NO", 0);
    $trial->addTrial("skip", 0.51, "YES", 0);
    $trial->addTrial("skip", 0.61, "YES", 0);
    $trial->addTrial("skip", 0.7, "YES", 0);

    $trial->addTrial("notskip", 0.41, "NO", 0);
    $trial->addTrial("notskip", 0.51, "YES", 0);
    $trial->addTrial("notskip", 0.61, "YES", 0);
    $trial->addTrial("notskip", 0.7, "YES", 0);
    $trial->addTrial("notskip", undef, "OMITTED", 1);
    $trial->addTrial("notskip", undef, "OMITTED", 1);

    $trial->setPooledTotalTrials(10);

    my $blockdet = new DETCurve($trial, "blocked", undef, "footitle", 1, 0.1, 0.0001);
    print "  OK\n";

    ## This was built from DETtesting-v2 with MissingTarg=0, MissingNonTarg=0
    #    
    #               Thr    Pmiss  Pfa    TWval     SSDPmiss, SSDPfa, SSDValue, #blocks
    my @points = [  (0.1,  0.500, 0.611, -610.550, 0.500,    0.347,  346.550,   3) ];
    push @points, [ (0.2,  0.500, 0.556, -555.000, 0.500,    0.255,  254.235,   3) ];
    push @points, [ (0.3,  0.500, 0.500, -499.450, 0.500,    0.167,  166.401,   3) ];
    push @points, [ (0.4,  0.583, 0.500, -499.533, 0.382,    0.167,  166.525,   3) ];
    push @points, [ (0.41,  0.583, 0.444, -443.983, 0.382,    0.096,   96.288,   3) ];
    push @points, [ (0.5, 0.667, 0.403, -402.404, 0.382,    0.087,   86.407,   3) ];
    push @points, [ (0.51,  0.667, 0.347, -346.854, 0.382,    0.024,   24.344,   3) ];
    push @points, [ (0.6, 0.667, 0.250, -249.642, 0.382,    0.083,   83.076,   3) ];
    push @points, [ (0.61,  0.667, 0.194, -194.092, 0.382,    0.048,   48.397,   3) ];
    push @points, [ (0.7, 0.667, 0.097,  -96.879, 0.382,    0.087,   86.568,   3) ];
    push @points, [ (0.8,  0.833, 0.056,  -55.383, 0.289,    0.096,   95.927,   3) ];
    push @points, [ (0.9,  0.833, 0.000,    0.167, 0.289,    0.000,    0.289,   3) ];
    push @points, [ (1.0,  0.917, 0.000,    0.083, 0.144,    0.000,    0.144,   3) ];
    push @points, [ (1.0,  1.000, 0.000,    0.000, 0.000,    0.000,    0.000,   3) ];
    print " Checking points...";
    for (my $i=0; $i<@points; $i++){
	die "Error: Det point isn't correct for point $i expected '".join(",",@{$points[$i]}).
	    "' got '".join(",",@{ $blockdet->{POINTS}[$i]})."'"
	    if ($points[$i][0] != $blockdet->{POINTS}[$i][0] ||
		thisabs($points[$i][1] - sprintf("%.3f",$blockdet->{POINTS}[$i][1])) > 0.001 ||
		thisabs($points[$i][2] - sprintf("%.3f",$blockdet->{POINTS}[$i][2])) > 0.001 ||
		thisabs($points[$i][3] - sprintf("%.3f",$blockdet->{POINTS}[$i][3])) > 0.001 ||
		thisabs($points[$i][4] - sprintf("%.3f",$blockdet->{POINTS}[$i][4])) > 0.001 ||
		thisabs($points[$i][5] - sprintf("%.3f",$blockdet->{POINTS}[$i][5])) > 0.001 ||
		thisabs($points[$i][6] - sprintf("%.3f",$blockdet->{POINTS}[$i][6])) > 0.001 ||
		thisabs($points[$i][7] - sprintf("%.3f",$blockdet->{POINTS}[$i][7])) > 0.001);
    }

#    $blockdet->writeGNUGraph("fooblock");
    
    print "  OK\n";
}

sub unitTestMultiDet{
    print " Checking multi...";

    my $trial = new Trials("Term Detection", "Term", "Occurrence");
    
    $trial->addTrial("she", 0.10, "NO", 0);
    $trial->addTrial("she", 0.15, "NO", 0);
    $trial->addTrial("she", 0.20, "NO", 0);
    $trial->addTrial("she", 0.25, "NO", 0);
    $trial->addTrial("she", 0.30, "NO", 1);
    $trial->addTrial("she", 0.35, "NO", 0);
    $trial->addTrial("she", 0.40, "NO", 0);
    $trial->addTrial("she", 0.45, "NO", 1);
    $trial->addTrial("she", 0.50, "NO", 0);
    $trial->addTrial("she", 0.55, "YES", 1);
    $trial->addTrial("she", 0.60, "YES", 1);
    $trial->addTrial("she", 0.65, "YES", 0);
    $trial->addTrial("she", 0.70, "YES", 1);
    $trial->addTrial("she", 0.75, "YES", 1);
    $trial->addTrial("she", 0.80, "YES", 1);
    $trial->addTrial("she", 0.85, "YES", 1);
    $trial->addTrial("she", 0.90, "YES", 1);
    $trial->addTrial("she", 0.95, "YES", 1);
    $trial->addTrial("she", 1.0, "YES", 1);

    my $trial2 = new Trials("Term Detection", "Term", "Occurrence");
    
    $trial2->addTrial("she", 0.10, "NO", 0);
    $trial2->addTrial("she", 0.15, "NO", 0);
    $trial2->addTrial("she", 0.20, "NO", 0);
    $trial2->addTrial("she", 0.25, "NO", 0);
    $trial2->addTrial("she", 0.30, "NO", 1);
    $trial2->addTrial("she", 0.35, "NO", 1);
    $trial2->addTrial("she", 0.40, "NO", 0);
    $trial2->addTrial("she", 0.45, "NO", 1);
    $trial2->addTrial("she", 0.50, "NO", 0);
    $trial2->addTrial("she", 0.55, "YES", 1);
    $trial2->addTrial("she", 0.60, "YES", 1);
    $trial2->addTrial("she", 0.65, "YES", 0);
    $trial2->addTrial("she", 0.70, "YES", 0);
    $trial2->addTrial("she", 0.75, "YES", 1);
    $trial2->addTrial("she", 0.80, "YES", 0);
    $trial2->addTrial("she", 0.85, "YES", 1);
    $trial2->addTrial("she", 0.90, "YES", 1);
    $trial2->addTrial("she", 0.95, "YES", 1);
    $trial2->addTrial("she", 1.0, "YES", 1);

    my $det1 = new DETCurve($trial, "pooled", undef, "DET1", 1, 0.1, 0.0001);
    my $det2 = new DETCurve($trial2, "pooled", undef, "DET2", 1, 0.1, 0.0001);
    
    DETCurve::writeMultiDetGraph("foomerge", [($det1, $det2)]);
    print DETCurve::writeMultiDetSummary([($det1, $det2)], "text");
}

sub serialize(){
    my ($self, $file) = @_;
    $self->{LAST_SERIALIZED_DET} = $file;
    open (FILE, ">$file") || die "Error: Unable to open file '$file' to serialize STDDETSet to";
    my $orig = $Data::Dumper::Indent; 
    $Data::Dumper::Indent = 0;
    print FILE Dumper($self); 
    $Data::Dumper::Indent = $orig;
    close FILE;
}

sub readFromFile{
    my ($file) = @_;
    my $str = "";
    open (FILE, "$file") || die "Failed to open $file for read";
    while (<FILE>) { $str .= $_ ; }
    close FILE;
    my $VAR1;
    eval $str;
    $VAR1;
}

sub successful{
    my ($self) = @_;
    defined($self->{POINTS});
}

sub getMessages{
    my ($self) = @_;
    $self->{MESSAGES};
}

sub getMaxValueDetectionScore{
    my $self = shift;
    $self->{MAXVALUE}{DETECTIONSCORE}
}

sub getMaxValueValue{
    my $self = shift;
    $self->{MAXVALUE}{VALUE}
}

sub getMaxValuePMiss{
    my $self = shift;
    $self->{MAXVALUE}{PMISS}
}

sub getMaxValuePFA{
    my $self = shift;
    $self->{MAXVALUE}{PFA}
}

sub getStyle{
    my $self = shift;
    $self->{STYLE}
}

sub getDETPng(){
    my ($self) = @_;
    $self->{LAST_GNU_DETFILE_PNG};
}

sub getThreshPng(){
    my ($self) = @_;
    $self->{LAST_GNU_THRESHPLOT_PNG};
}

sub getSerializedDET(){
    my ($self) = @_;
    $self->{LAST_SERIALIZED_DET};
}

sub setSystemDecisionValue{
    my $self = shift;
    my $val = shift;
    $self->{SYSTEMDECISIONVALUE} = $val;
}

sub getSystemDecisionValue{
    my $self = shift;
    $self->{SYSTEMDECISIONVALUE};
}

sub computePoints{
    my $self = shift;

    ## For faster computation;
    $self->{TRIALS}->sortTrials();

    if ($self->{STYLE} eq "blocked"){
	$self->{POINTS} = $self->Compute_blocked_DET_points($self->{TRIALS});
    } elsif ($self->{STYLE} eq "pooled"){
	my @targ = ();
	my @nontarg = ();
	my $omittedTarg = 0;
	foreach my $block(keys %{ $self->{TRIALS}->{'trials'} }){
	    push @targ, @{ $self->{TRIALS}->{'trials'}{$block}{TARG}};	
	    push @nontarg, @{ $self->{TRIALS}->{'trials'}{$block}{NONTARG} };
	    $omittedTarg += $self->{TRIALS}->{'trials'}{$block}{"OMITTED TARG"};
	}
#	$self->{TRIALS}->dump(*STDOUT, "");
	$self->{POINTS} = $self->Compute_DET_points(0, \@targ, \@nontarg, $self->{TRIALS}->getPooledTotalTrials(), $omittedTarg);
    } else {
	die "Error: DET style $self->{STYLE} not implemented"
    }

}

sub Compute_blocked_DET_points{
    my ($self, $trial) = @_;
    my @Outputs = ();

    $self->{TRIALS}->sortTrials();
    my %blocks;
    my $block;
    my $minScore = undef;
    my $maxScore = undef;
    my $numBlocks = 0;
    ### Reduce the block set to only ones with targets and setup the DS!
    foreach $block(keys %{ $trial->{'trials'} }){
	next if (@{ $trial->{'trials'}{$block}{TARG} } + $trial->{'trials'}{$block}{"OMITTED TARG"} <= 0);
	
	$numBlocks++;
	$blocks{$block} = { TARGi => 0, NONTARGi => 0, PFA => undef, PMISS => undef, VALUE => undef };
	$minScore = $trial->{'trials'}{$block}{TARG}[0] if ((@{ $trial->{'trials'}{$block}{TARG} } > 0) && 
							    (!defined($minScore) || $minScore > $trial->{'trials'}{$block}{TARG}[0]));
	$minScore = $trial->{'trials'}{$block}{NONTARG}[0] if ((@{ $trial->{'trials'}{$block}{NONTARG}} > 0) &&
							       (!defined($minScore) || $minScore > $trial->{'trials'}{$block}{NONTARG}[0]));
	$maxScore = $trial->{'trials'}{$block}{TARG}[$#{ $trial->{'trials'}{$block}{TARG} }] 
	    if ((@{ $trial->{'trials'}{$block}{TARG} } > 0) &&   (!defined($maxScore) || $maxScore < $trial->{'trials'}{$block}{TARG}[$#{ $trial->{'trials'}{$block}{TARG} }]));
	$maxScore = $trial->{'trials'}{$block}{NONTARG}[$#{ $trial->{'trials'}{$block}{NONTARG} }]
	    if ((@{ $trial->{'trials'}{$block}{NONTARG}} > 0) && (!defined($maxScore) || $maxScore < $trial->{'trials'}{$block}{NONTARG}[$#{ $trial->{'trials'}{$block}{NONTARG} }]));
    }
    $self->{MINSCORE} = $minScore;
    $self->{MAXSCORE} = $maxScore;
    
    if ($numBlocks <= 1){
	$self->{MESSAGES} .= "WARNING: '".$self->{TRIALS}->{"BlockID"}."' weighted DET curves can not be computed with $numBlocks ".$self->{TRIALS}->{"BlockID"}."s\n";
	return undef;
    }

    if (!defined($self->{MINSCORE}) || !defined($self->{MAXSCORE})){
	$self->{MESSAGES} .= "WARNING: '".$self->{TRIALS}->{"BlockID"}."' weighted DET curves can not be computed, no scores exist\n";
	return undef;
    }

#    print "Blocks: '".join(" ",keys %blocks)."'  minScore: $minScore\n";
    my ($pMiss, $pFa, $TWValue, $ssdPMiss, $ssdPFa, $ssdValue) = $self->computeBlockWeighted(\%blocks, $numBlocks, $trial);
    push(@Outputs, [ ( $minScore, $pMiss, $pFa, $TWValue, $ssdPMiss, $ssdPFa, $ssdValue, $numBlocks) ] );;
#    print "(UNDEF, $pMiss, $pFa, $TWValue, $ssdPMiss, $ssdPFa)\n";
    my $prevMin = $minScore;
    $self->{MAXVALUE}{DETECTIONSCORE} = $minScore;
    $self->{MAXVALUE}{VALUE} = $TWValue;
    $self->{MAXVALUE}{PFA} = $pFa;
    $self->{MAXVALUE}{PMISS} = $pMiss;
    
    while ($self->updateMinScoreForBlockWeighted(\%blocks, \$minScore, $trial)){
	($pMiss, $pFa, $TWValue, $ssdPMiss, $ssdPFa, $ssdValue) = $self->computeBlockWeighted(\%blocks, $numBlocks, $trial);
	push(@Outputs, [ ( $minScore, $pMiss, $pFa, $TWValue, $ssdPMiss, $ssdPFa, $ssdValue, $numBlocks ) ] );;
#	print "($prevMin, $pMiss, $pFa, $TWValue, $ssdPMiss, $ssdPFa, $ssdValue)\n";
#	print Dumper(\%blocks);
	if ($TWValue > $self->{MAXVALUE}{VALUE}){
	    $self->{MAXVALUE}{DETECTIONSCORE} = $minScore;
	    $self->{MAXVALUE}{VALUE} = $TWValue;
	    $self->{MAXVALUE}{PFA} = $pFa;
	    $self->{MAXVALUE}{PMISS} = $pMiss;
	}
	$prevMin = $minScore;
    }
    \@Outputs;
}

sub updateMinScoreForBlockWeighted{
    my ($self, $blocks, $minScore, $trial) = @_;
    my $change = 0;
    #Advance Skipping the min
    foreach $b(keys %$blocks){
	while ($blocks->{$b}{TARGi} < scalar(@{ $trial->{'trials'}{$b}{"TARG"} }) &&
	       $trial->{'trials'}{$b}{"TARG"}[$blocks->{$b}{TARGi}] <= $$minScore){
	    $blocks->{$b}{PFA} = undef;
	    $blocks->{$b}{TARGi} ++;
	    $change++;
	}
	while ($blocks->{$b}{NONTARGi} < scalar(@{ $trial->{'trials'}{$b}{"NONTARG"} }) &&
	       $trial->{'trials'}{$b}{"NONTARG"}[$blocks->{$b}{NONTARGi}] <= $$minScore){
	    $blocks->{$b}{PFA} = undef;
	    $blocks->{$b}{NONTARGi} ++;
	    $change++;
	}
    }    
    my $newMin = undef;
    foreach $b(keys %$blocks){
	$newMin = $trial->{'trials'}{$b}{"TARG"}[$blocks->{$b}{TARGi}]
	    if (($blocks->{$b}{TARGi} < scalar(@{ $trial->{'trials'}{$b}{"TARG"} })) &&
		(!defined($newMin) || $newMin > $trial->{'trials'}{$b}{"TARG"}[$blocks->{$b}{TARGi}]));
	$newMin = $trial->{'trials'}{$b}{"NONTARG"}[$blocks->{$b}{NONTARGi}]
	    if (($blocks->{$b}{NONTARGi} < scalar(@{ $trial->{'trials'}{$b}{"NONTARG"} })) &&
		(!defined($newMin) || $newMin > $trial->{'trials'}{$b}{"NONTARG"}[$blocks->{$b}{NONTARGi}]));
    }
    $$minScore = $newMin if (defined($newMin));  ## Return the prevMin if there was nothing left
    $change;
}

sub computeBlockWeighted{
    my ($self, $blocks, $numBlocks, $trial) = @_;
    my $b;
    my ($sumPfa, $sumSqPfa, $sumPmiss, $sumSqPmiss, $sumValue, $sumSqValue) = (0,0,0,0,0,0);
    foreach $b(keys %$blocks){
	if (!defined($blocks->{$b}{PFA})){
	    my $NTarg = (scalar(@{ $trial->{'trials'}{$b}{"TARG"} }) + $trial->{'trials'}{$b}{"OMITTED TARG"});
	    my $NNonTarg = scalar(@{ $trial->{'trials'}{$b}{"NONTARG"} });
	    my $NNonTargTrials = (defined($trial->getPooledTotalTrials()) ? $trial->getPooledTotalTrials() - $NTarg : $NNonTarg);
	    my $NMiss = $blocks->{$b}{TARGi} + $trial->{'trials'}{$b}{"OMITTED TARG"};
	    my $NFalse = $NNonTarg - $blocks->{$b}{NONTARGi};
	    my $NCorr = $NTarg - $NMiss;
	    $blocks->{$b}{PMISS} = $NMiss / $NTarg;
	    $blocks->{$b}{PFA}   = $NFalse / $NNonTargTrials; 
	    $blocks->{$b}{VALUE} = 1 - ($blocks->{$b}{PMISS} + $self->{BETA}*$blocks->{$b}{PFA});
#	    print "$b targ=$NTarg nonTarg=$NNonTarg nonTargTrials=$NNonTargTrials miss=$NMiss fa=$NFalse cor=$NCorr pmiss=$blocks->{$b}{PMISS} pfa=$blocks->{$b}{PFA} numBlocks=$numBlocks beta=$self->{BETA}\n";
#	} else {
#	    print "$b Computed\n";
	}    
	$sumPfa += $blocks->{$b}{PFA};
	$sumPmiss += $blocks->{$b}{PMISS};
	$sumValue += $blocks->{$b}{VALUE};
	$sumSqPfa += $blocks->{$b}{PFA} * $blocks->{$b}{PFA};
	$sumSqPmiss += $blocks->{$b}{PMISS} * $blocks->{$b}{PMISS};
	$sumSqValue += $blocks->{$b}{VALUE} * $blocks->{$b}{VALUE};
    }
    my $pMiss = $sumPmiss/$numBlocks;
    my $pFa =  $sumPfa/$numBlocks;
    my $TWValue = $sumValue / $numBlocks;
    my $ssdPfa = sqrt((($numBlocks * $sumSqPfa) - ($sumPfa * $sumPfa)) / ($numBlocks * ($numBlocks - 1)));
    my $ssdPmiss = sqrt((($numBlocks * $sumSqPmiss) - ($sumPmiss * $sumPmiss)) / ($numBlocks * ($numBlocks - 1)));
    my $ssdValue = sqrt((($numBlocks * $sumSqValue) - ($sumValue * $sumValue)) / ($numBlocks * ($numBlocks - 1)));
    ($pMiss, $pFa, $TWValue, $ssdPmiss, $ssdPfa, $ssdValue);
}

sub Compute_DET_points{
    my ($self, $presorted, $ra_Targets, $ra_NonTarg, $totalTrials, $omittedTarg) = @_;

#    print "Computing DET #targ=".scalar(@$ra_Targets)." #nontarg=".scalar(@$ra_NonTarg)."\n";

    #
    #   Variables
    my($PMIN)=0.0005;
    my($PMAX)=0.5;
    my($SMAX)=9e99;
    my(@Outputs) = ();
    my(@TARGET);
    my(@NONTARGET);
    my($Pmiss, $Pfa);

    if ($presorted){
	@TARGET = @$ra_Targets;
	@NONTARGET = @$ra_NonTarg;
    } else {
	#
	#   Sort the target and non-target scores
	@TARGET = sort { $a <=> $b } @$ra_Targets;
	@NONTARGET = sort { $a <=> $b } @$ra_NonTarg;
    }
    if (@TARGET > 0 && @NONTARGET > 0){
	$self->{MINSCORE} = ($TARGET[0] < $NONTARGET[0]) ? $TARGET[0] : $NONTARGET[0];
	$self->{MAXSCORE} = ($TARGET[$#TARGET] > $NONTARGET[$#NONTARGET]) ? $TARGET[$#TARGET] : $NONTARGET[$#NONTARGET];
    } else {
	$self->{MINSCORE} = ($#TARGET > 0) ? $TARGET[0] : $NONTARGET[0];
	$self->{MAXSCORE} = ($#TARGET > 0) ? $TARGET[$#TARGET] : $NONTARGET[$#NONTARGET];
    }
#    print "MIN is $self->{MINSCORE} max is  $self->{MAXSCORE}\n";
    #
    #  // Append SMAX to very end 
    push(@TARGET,$SMAX);
    push(@NONTARGET,$SMAX);

    my $nonTargDenom = (!defined($totalTrials) ? $#NONTARGET : $totalTrials - ($omittedTarg + $#TARGET));

    my ($indTarg, $indNTarg, $score, $value, $NMiss, $NFalse, $NCorr) = (0, 0, 0, 0, 0, 0, 0);
    $self->{MAXVALUE}{DETECTIONSCORE} = $self->{MINSCORE};
    $self->{MAXVALUE}{VALUE} = 0.0;
    $self->{MAXVALUE}{PMISS} = 0.0;
    $self->{MAXVALUE}{PFA} = 1.0;
#    push(@Outputs, [ ( $self->{MINSCORE}, 0.0, 1.0, 0.0) ] );;
#    print "TARG = ".join(" ",@TARGET)."\n";
#    print "NONTARG = ".join(" ",@NONTARGET)."\n";
    while  ( ($indTarg < $#TARGET) || ($indNTarg < $#NONTARGET)) {
	if ( $TARGET[$indTarg] <= $NONTARGET[$indNTarg] && $indTarg < $#TARGET) {
	    $score = $TARGET[$indTarg];
	} else {
	    $score = $NONTARGET[$indNTarg];
	}
	$NMiss = $indTarg + $omittedTarg;
	$NFalse = $#NONTARGET - $indNTarg;
	$NCorr = ($#TARGET+$omittedTarg) - $NMiss;
	
	$Pmiss = ($#TARGET > 0) ? ($NMiss) / ($omittedTarg + $#TARGET) : 0;
	$Pfa = ($#NONTARGET > 0) ? ($NFalse) / $nonTargDenom : 0;
	$value = (($self->{VALUE_V} * ($NCorr)) - ($self->{VALUE_C} * ($#NONTARGET - $indNTarg))) / ($self->{VALUE_V} * ($omittedTarg + $#TARGET));
	push(@Outputs, [ ( $score, $Pmiss, $Pfa, $value ) ] );;
	if ($value > $self->{MAXVALUE}{VALUE}){
	    $self->{MAXVALUE}{DETECTIONSCORE} = $score;
	    $self->{MAXVALUE}{VALUE} = $value;
	    $self->{MAXVALUE}{PFA} = $Pfa;
	    $self->{MAXVALUE}{PMISS} = $Pmiss;
	}
#	print "score=$score indNTarg=$indNTarg indTarg=$indTarg omitTarg=$omittedTarg nonTargDen=$nonTargDenom NMiss=$NMiss #false=$NFalse NCorr=$NCorr NonTargDenom=$nonTargDenom PMisss=$Pmiss Pfa=$Pfa\n";

	if ( $TARGET[$indTarg] <= $NONTARGET[$indNTarg] && $indTarg < $#TARGET) {
	    $indTarg++;
	} else {
	    $indNTarg++;
	}
	
    }
    \@Outputs;
}

sub ppndf {

    my($ival) = @_;
# // A lot of predefined variables
#
    my $SPLIT=0.42;

    my $EPS=2.2204e-16;
    my $LL=140;

    my $A0=2.5066282388;
    my $A1=-18.6150006252;
    my $A2=41.3911977353;
    my $A3=-25.4410604963;
    my $B1=-8.4735109309;
    my $B2=23.0833674374;
    my $B3=-21.0622410182;
    my $B4=3.1308290983;
    my $C0=-2.7871893113;
    my $C1=-2.2979647913;
    my $C2=4.8501412713;
    my $C3=2.3212127685;
    my $D1=3.5438892476;
    my $D2=1.6370678189;
    my ($p, $q, $r, $retval);

    if ($ival >= 1.0) {
	$p = 1 - $EPS; 
    }
    elsif ($ival <= 0.0) {
	$p = $EPS;
    }
    else {
	$p = $ival;
    }

    $q = $p - 0.5;

    if (abs($q) <= $SPLIT ) {
	$r = $q * $q;
        $retval = $q * ((($A3 * $r + $A2) * $r + $A1) * $r + $A0) /
	    (((($B4 * $r + $B3) * $r + $B2) * $r + $B1) * $r + 1.0);
    } else {
	if ( $q > 0.0 ) {
	    $r = 1.0 - $p;
	} else { 
	    $r = $p;
	}

	if ($r <= 0.0) {
	    printf ("Found r = %f\n", $r);
	    return;
	}
	
	$r = sqrt( (-1.0 * log($r)));

	$retval = ((($C3 * $r + $C2) * $r + $C1) * $r + $C0) / 
	    (($D2 * $r + $D1) * $r + 1.0);
    
	if ($q < 0) { $retval = $retval * -1.0; }
    }
    return ($retval);
}

sub write_gnuplot_threshold_header{
    my($FP, $title, $min_x, $max_x) = @_;

    my($i, $prev);
    
    print $FP "## GNUPLOT command file\n";
    print $FP "set terminal postscript color\n";
    print $FP "set style data lines\n";
    print $FP "set key at 1,1\n";
    print $FP "set title '$title'\n";
    print $FP "set xlabel 'Decision Score'\n";
    print $FP "set grid\n";

    print $FP "plot [$min_x:$max_x] [0:1] \\\n";

}

sub write_gnuplot_DET_header{
    my($FP, $title, $x_min, $x_max, $y_min, $y_max, $keyLoc) = @_;

    my($p_x_min, $p_x_max) = ( ppndf($x_min/100), ppndf($x_max/100) );
    my($p_y_min, $p_y_max) = ( ppndf($y_min/100), ppndf($y_max/100) );
    
    my $ratio = ($p_y_max - $p_y_min) / ($p_x_max - $p_x_min);
    my($i, $prev);
    
    print $FP "## GNUPLOT command file\n";
    print $FP "set terminal postscript color\n";
    print $FP "set style data lines\n";
    print $FP "set noxzeroaxis\n";
    print $FP "set noyzeroaxis\n";
    if (defined($keyLoc)){
	print $FP "set key $keyLoc spacing .8\n";
    }
    print $FP "set size ratio $ratio\n";
    print $FP "set noxtics\n"; 
    print $FP "set noytics\n";
    print $FP "set title '$title'\n";
    print $FP "set ylabel 'Miss probability (in %)'\n";
    print $FP "set xlabel 'False Alarm probability (in %)'\n";
    print $FP "set grid\n";
    print $FP "set pointsize 3\n";
    
### Write the tic marks
    &write_tics($FP, 'ytics', $y_min, $y_max);
    &write_tics($FP, 'xtics', $x_min, $x_max);

    print $FP "plot [${p_x_min}:${p_x_max}] [${p_y_min}:${p_y_max}] \\\n";
    #print $FP "   -x title 'Random Performance' with lines 1";
    print $FP "   -x title 'Random Performance' with lines lc 1";

}

sub write_tics{ 
    my($FP, $axis, $min, $max) = @_;
    my($lab, $i, $prev);

    my(@tics) = (0.00001, 0.0001, 0.001, 0.004, .01, 0.02, 0.05, 0.1, 0.2, 0.5,
		 1, 2, 5, 10, 20, 40, 60, 80, 90, 95, 98, 99, 99.5, 99.9);

    print $FP "set $axis (";
    for ($i=0, $prev=0; $i<= $#tics; $i++){
	if ($tics[$i] >= $min && $tics[$i] <= $max){
	    print $FP ", " if ($prev > 0);
	    print $FP "\\\n    " if (($prev % 5) == 0);
	    if ($tics[$i] > 99) {
		$lab = sprintf("%.1f", $tics[$i]);
	    } elsif ($tics[$i] >= 1) {
		$lab = sprintf("%d", $tics[$i]);
	    } elsif ($tics[$i] >= 0.1) {
		($lab = sprintf("%.1f", $tics[$i])) =~ s/^0//;
	    } elsif ($tics[$i] >= 0.01) {
		($lab = sprintf("%.2f", $tics[$i])) =~ s/^0//;
	    } elsif ($tics[$i] >= 0.001) {
		($lab = sprintf("%.3f", $tics[$i])) =~ s/^0//;
	    } elsif ($tics[$i] >= 0.0001) {
		($lab = sprintf("%.4f", $tics[$i])) =~ s/^0//;
	    } else {
		($lab = sprintf("%.5f", $tics[$i])) =~ s/^0//;
	    }

	    printf $FP "'$lab' %.4f",ppndf($tics[$i]/100);
	    $prev ++;
	}
    }
    print $FP ")\n";
}

### Options for graphs:
### title  -> the plot title
### noSerialize -> do not write the serialized DET Curves if the element exists
### Xmin -> Set the minimum X coordinate
### Xmax -> Set the maximum X coordinate
### Ymin -> Set the minimum Y coordinate
### Ymax -> Set the maximum Y coordinate
### lTitleNoPointInfo  -> do not write the Max Point Info if the element exisst
### lTitleNoDETType    -> do not write the DET Type if the element exists
### lTitleNoMaxValue   -> do not write the Max Value if the element exists
### KeyLoc -> set the key location.  Values can be left | right | top | bottom | outside | below 

### This is NOT an instance METHOD!!!!!!!!!!!!!!
sub writeMultiDetGraph{
    ### $options is a pointer to a hash table to tweak the graph
    my ($fileRoot, $dets, $options) = @_;
    my %multiInfo = ();
   
    ### If there's one, do one!!!
    if (scalar(@{ $dets }) == 1){
	return($dets->[0]->writeGNUGraph($fileRoot, $options));
    }
    
    ### Use the options
    my $title = "Combined DET Plot";
    my ($xmin, $xmax, $ymin, $ymax, $keyLoc) = (0.0001, 40, 5, 98, "top");
    if (defined $options){
	$title = $options->{title} if (exists($options->{title}));
	$xmin = $options->{Xmin} if (exists($options->{Xmin}));
	$xmax = $options->{Xmax} if (exists($options->{Xmax}));
	$ymin = $options->{Ymin} if (exists($options->{Ymin}));
	$ymax = $options->{Ymax} if (exists($options->{Ymax}));
	$keyLoc = $options->{KeyLoc} if (exists($options->{KeyLoc}));
    }    

    ### open  the jointPlot
#    print "Writing DET to GNUPLOT file $fileRoot.*\n";
    open (MAINPLT,"> $fileRoot.plt") ||
	die("unable to open DET gnuplot file $fileRoot.plt");
    $multiInfo{COMBINED_DET_PNG} = "$fileRoot.png";
    &write_gnuplot_DET_header(*MAINPLT, $title, $xmin, $xmax, $ymin, $ymax, $keyLoc);

    ### Write Individual Dets
    my @colors = (1..40);  splice(@colors, 0, 1);    
    for (my $d=0; $d < @$dets; $d++){
	my $troot = sprintf("%s.sub%02d",$fileRoot,$d);
	if ($dets->[$d]->writeGNUGraph($troot, $options)){
	    my $typeStr = ($dets->[$d]->{STYLE} eq "pooled" ? 
			   "Pooled $dets->[$d]->{TRIALS}->{BlockID} $dets->[$d]->{TRIALS}->{DecisionID}" :
			   "$dets->[$d]->{TRIALS}->{BlockID} Wtd.");
	    my ($scr, $val, $Pmiss, $Pfa) = ($dets->[$d]->getMaxValueDetectionScore(),
					     $dets->[$d]->getMaxValueValue(),
					     $dets->[$d]->getMaxValuePMiss(),
					     $dets->[$d]->getMaxValuePFA());
	    
	    my $ltitle = "";
	    $ltitle .= $typeStr if (! (defined($options) && exists($options->{lTitleNoDETType})));
	    $ltitle .= " ".$dets->[$d]->{LINETITLE};
	    $ltitle .= " ".sprintf("Max Val=%.3f", $val) if (! (defined($options) && exists($options->{lTitleNoMaxValue})));
	    $ltitle .= " ".sprintf("Scr=%.3f", $scr) if (! (defined($options) && exists($options->{lTitleNoPointInfo})));
		# Gnuplot 4
	    #printf MAINPLT ",\\\n  '$troot.dat.1' using 3:2 title '$ltitle' with lines $colors[$d]";
	    #printf MAINPLT ",\\\n  '$troot.dat.2' using 6:5 notitle with points $colors[$d]";
	    printf MAINPLT ",\\\n  '$troot.dat.1' using 3:2 title '$ltitle' with lines lc $colors[$d]";
	    printf MAINPLT ",\\\n  '$troot.dat.2' using 6:5 notitle with points lc $colors[$d]";
	}
    }
    print MAINPLT "\n";
    
    close MAINPLT;
    buildPNG($fileRoot);
    \%multiInfo;
}

sub writeGNUGraph{
    my ($self, $fileRoot, $options) = @_;
    
    if (!defined($self->{POINTS})){
	print STDERR "WARNING: Writing DET plot to $fileRoot.* failed.  Points not computed\n";
	return 0;
    }

    ### Serialize the file for later usage
    $self->serialize("$fileRoot.srl") unless (defined $options && exists($options->{noSerialize}));

    my $typeStr = ($self->{STYLE} eq "pooled" ? "Pooled $self->{TRIALS}->{BlockID} $self->{TRIALS}->{DecisionID}" : 
		   "$self->{TRIALS}->{BlockID} Wtd.");
    my $title = $typeStr . " Detection Error Tradeoff Curve"; 
    my ($xmin, $xmax, $ymin, $ymax, $keyLoc) = (0.0001, 40, 5, 98, "top");
    if (defined $options){
	$title = $options->{title} if (exists($options->{title}));
	$title = $options->{title} if (exists($options->{title}));
	$xmin = $options->{Xmin} if (exists($options->{Xmin}));
	$xmax = $options->{Xmax} if (exists($options->{Xmax}));
	$ymin = $options->{Ymin} if (exists($options->{Ymin}));
	$ymax = $options->{Ymax} if (exists($options->{Ymax}));
	$keyLoc = $options->{KeyLoc} if (exists($options->{KeyLoc}));
    }    
    
#    print "Writing DET to GNUPLOT file $fileRoot.*\n";
    open(PLT,"> $fileRoot.plt") ||
	die("unable to open DET gnuplot file $fileRoot.plt");
    open(THRESHPLT,"> $fileRoot.thresh.plt") ||
	die("unable to open DET gnuplot file $fileRoot.thresh.plt");
    $self->{LAST_GNU_DETFILE_PNG} = "$fileRoot.png";
    $self->{LAST_GNU_THRESHPLOT_PNG} = "$fileRoot.thresh.png";
    &write_gnuplot_DET_header(*PLT, $title, $xmin, $xmax, $ymin, $ymax, $keyLoc);

    ### The line data file
    open(DAT,"> $fileRoot.dat.1") ||
	die("unable to open DET gnuplot file $fileRoot.dat.1"); 
    print DAT "# DET Graph made by DETCurve\n";
    print DAT "# PooledTotalTrials = ".(defined($self->{TRIALS}->getPooledTotalTrials()) ? $self->{TRIALS}->getPooledTotalTrials() : "not defined")."\n";
    print DAT "# DET Type: $typeStr\n";
    if ($self->{STYLE} eq "pooled"){
	print DAT "# score ppndf(Pmiss) ppndf(Pfa) Pmiss Pfa Value\n";
	for (my $i=0; $i<@{ $self->{POINTS} }; $i++){
	    print DAT $self->{POINTS}[$i][0]." ".
		ppndf($self->{POINTS}[$i][1])." ".
		ppndf($self->{POINTS}[$i][2])." ".
		$self->{POINTS}[$i][1]." ".
		$self->{POINTS}[$i][2]." ".
		$self->{POINTS}[$i][3]."\n";
	}
    } else {
	print DAT "# Abbreviations: ssd() is the sample Standard Deviation of a Variable\n";
	print DAT "#                ppndf() is the normal deviant of a probability. ppndf(.5)=0\n";	
	print DAT "#                -2SE(v) is v - 2(StandardError(v)) = v - 2 * (sampleStandardDev / sqrt(n))\n";
	print DAT "# score ppndf(Pmiss) ppndf(Pfa) Pmiss Pfa Value ppndf(-2SE(Pmiss)) ppndf(-2SE(Pfa)) ppndf(+2SE(Pmiss)) ppndf(+2SE(Pfa)) SE(Value)\n";
	for (my $i=0; $i<@{ $self->{POINTS} }; $i++){
	    print DAT $self->{POINTS}[$i][0]." ".
		ppndf($self->{POINTS}[$i][1])." ".
		ppndf($self->{POINTS}[$i][2])." ".
		$self->{POINTS}[$i][1]." ".
		$self->{POINTS}[$i][2]." ".
		$self->{POINTS}[$i][3]." ".
		ppndf($self->{POINTS}[$i][1] - 2*($self->{POINTS}[$i][4] / sqrt($self->{POINTS}[$i][7]-1)))." ".
		ppndf($self->{POINTS}[$i][2] - 2*($self->{POINTS}[$i][5] / sqrt($self->{POINTS}[$i][7]-1)))." ".
		ppndf($self->{POINTS}[$i][1] + 2*($self->{POINTS}[$i][4] / sqrt($self->{POINTS}[$i][7]-1)))." ".
		ppndf($self->{POINTS}[$i][2] + 2*($self->{POINTS}[$i][5] / sqrt($self->{POINTS}[$i][7]-1)))." ".
		($self->{POINTS}[$i][2] - 2*($self->{POINTS}[$i][6] / sqrt($self->{POINTS}[$i][7]-1)))." ".
		"\n";
	}
    }
    close DAT;
    print PLT ",\\\n";
    
    ### The points data file
    open(DAT,"> $fileRoot.dat.2") ||
	die("unable to open DET gnuplot file $fileRoot.dat.2"); 
    print DAT "# Points for DET Graph made by DETCurve\n";
    print DAT "# DET Type: $typeStr\n";
    print DAT "# MaxValueDetectionScore MaxValueValue Pmiss Pfa ppndf(Pmiss) ppndf(Pfa)\n";
    my ($scr, $val, $Pmiss, $Pfa) = ($self->getMaxValueDetectionScore(),
				     $self->getMaxValueValue(),
				     $self->getMaxValuePMiss(),
				     $self->getMaxValuePFA());
    print DAT "$scr $val $Pmiss $Pfa ".ppndf($Pmiss)." ".ppndf($Pfa)."\n";
    close DAT; 
    my $ltitle = "$self->{LINETITLE}";
    $ltitle .= sprintf(" Max Val=%.3f", $val)
	if (! (defined($options) && exists($options->{lTitleNoMaxValue})));
    $ltitle .= sprintf("=(PFa=%.6f, PM=%.4f, Scr=%.3f)", $Pfa, $Pmiss, $scr)
	if (! (defined($options) && exists($options->{lTitleNoPointInfo})));
	# Gnuplot 4
    # printf PLT "    '$fileRoot.dat.1' using 3:2 title '$ltitle' with lines 2, \\\n";
    # printf PLT "    '$fileRoot.dat.2' using 6:5 notitle with points 2";
    printf PLT "    '$fileRoot.dat.1' using 3:2 title '$ltitle' with lines lc 2, \\\n";
    printf PLT "    '$fileRoot.dat.2' using 6:5 notitle with points lc 2";
    
    if ($self->{STYLE} ne "pooled"){
	print PLT ", \\\n";
	# Gnuplot 4
	#printf PLT "    '$fileRoot.dat.1' using 8:7 title '+/- 2 Standard Error' with lines 3, \\\n";
	#printf PLT "    '$fileRoot.dat.1' using 10:9 notitle with lines 3";
	printf PLT "    '$fileRoot.dat.1' using 8:7 title '+/- 2 Standard Error' with lines lc 3, \\\n";
	printf PLT "    '$fileRoot.dat.1' using 10:9 notitle with lines lc 3";
    }
    print PLT "\n";
    close PLT;
    buildPNG($fileRoot);

    my $pad = 0.00;
    if ($self->{MINSCORE} == $self->{MAXSCORE}){
	$pad = 0.000001;
    }
    &write_gnuplot_threshold_header(*THRESHPLT, "$typeStr Threshold Plot for $self->{LINETITLE}", $self->{MINSCORE}-$pad, $self->{MAXSCORE}+$pad);
    print THRESHPLT "  '$fileRoot.dat.1' using 1:4 title 'P(Miss)', \\\n";
    print THRESHPLT "  '$fileRoot.dat.1' using 1:5 title 'P(FA)', \\\n";
    print THRESHPLT "  '$fileRoot.dat.1' using 1:6 title 'Value', \\\n";
    print THRESHPLT "  '$fileRoot.dat.2' using 1:2 title 'MaxValue ".sprintf("%.3f @ %.3f",$val,$scr)."' with points";
    if (defined($self->getSystemDecisionValue())){
	print THRESHPLT ", \\\n  ".$self->getSystemDecisionValue().
	    " with lines title 'Hard Decsion Value'";
    }
    print THRESHPLT "\n";
    close THRESHPLT;
    buildPNG($fileRoot.".thresh");
    1;
}

### This is NOT and instance method
sub buildPNG{
    my ($fileRoot) = @_;

### Use this with gnuplot 3.X
###    system("cat $fileRoot.plt | perl -pe \'\$_ = \"set terminal png medium \n\" if (\$_ =~ /set terminal/)\' | gnuplot > $fileRoot.png");
    system("cat $fileRoot.plt | perl -pe \'\$_ = \"set terminal postscript medium size 768,2048 crop\n\" if (\$_ =~ /set terminal/)\' | gnuplot > $fileRoot.ps");
}


1;
