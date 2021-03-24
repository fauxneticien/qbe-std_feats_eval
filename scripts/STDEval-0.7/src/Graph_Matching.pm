# STDEval
# Graph_Matching.pm
# Author: George Doddington

package Graph_Matching;
use strict;
require Exporter;
our @ISA = qw (Exporter);
our @EXPORT = qw (weighted_bipartite_graph_matching);
{return 1}

#################################

sub weighted_bipartite_graph_matching {
  my ($score) = @_;
    
  unless (defined $score) {
    warn "input to BGM is undefined\n";
    return undef;
  }
  my @keys = keys %$score;
  return {} unless @keys;
  if (@keys == 1) { #skip graph matching an simply pick the minimum cost map
    my $costs = $score->{$keys[0]};
    my (%map, $imin);
    foreach my $i (keys %$costs) {
      $imin = $i if not defined $imin or $costs->{$imin} > $costs->{$i};
    }
    $map{$keys[0]} = $imin;
    return {%map};
  }
    
  my $INF = 1E30;
  my $required_precision = 1E-12;
  my (@row_mate, @col_mate, @row_dec, @col_inc);
  my (@parent_row, @unchosen_row, @slack_row, @slack);
  my ($k, $l, $row, $col, @col_min, $cost, %cost);
  my $t = 0;
    
  my @rows = keys %{$score};
  my $miss = "miss";
  $miss .= "0" while exists $score->{$miss};
  my (@cols, %cols);
  my $min_score = $INF;
  foreach $row (@rows) {
    foreach $col (keys %{$score->{$row}}) {
      $min_score = min($min_score,$score->{$row}{$col});
      $cols{$col} = $col;
    }
  }
  @cols = keys %cols;
  my $fa = "fa";
  $fa .= "0" while exists $cols{$fa};
  my $reverse_search = @rows < @cols; # search is faster when ncols <= nrows
  foreach $row (@rows) {
    foreach $col (keys %{$score->{$row}}) {
      ($reverse_search ? $cost{$col}{$row} : $cost{$row}{$col})
	= $score->{$row}{$col} - $min_score;
    }
  }
  push @rows, $miss;
  push @cols, $fa;
  if ($reverse_search) {
    my @xr = @rows;
    @rows = @cols;
    @cols = @xr;
  }

  my $nrows = @rows;
  my $ncols = @cols;
  my $nmax = max($nrows,$ncols);
  my $no_match_cost = -$min_score*(1+$required_precision);

  # subtract the column minimas
  for ($l=0; $l<$nmax; $l++) {
    $col_min[$l] = $no_match_cost;
    next unless $l < $ncols;
    $col = $cols[$l];
    foreach $row (keys %cost) {
      next unless defined $cost{$row}{$col};
      my $val = $cost{$row}{$col};
      $col_min[$l] = $val if $val < $col_min[$l];
    }
  }
    
  # initial stage
  for ($l=0; $l<$nmax; $l++) {
    $col_inc[$l] = 0;
    $slack[$l] = $INF;
  }
    
 ROW:
  for ($k=0; $k<$nmax; $k++) {
    $row = $k < $nrows ? $rows[$k] : undef;
    my $row_min = $no_match_cost;
    for (my $l=0; $l<$ncols; $l++) {
      my $col = $cols[$l];
      my $val = ((defined $row and defined $cost{$row}{$col}) ? $cost{$row}{$col}: $no_match_cost) - $col_min[$l];
      $row_min = $val if $val < $row_min;
    }
    $row_dec[$k] = $row_min;
    for ($l=0; $l<$nmax; $l++) {
      $col = $l < $ncols ? $cols[$l]: undef;
      $cost = ((defined $row and defined $col and defined $cost{$row}{$col}) ?
	       $cost{$row}{$col} : $no_match_cost) - $col_min[$l];
      if ($cost==$row_min and not defined $row_mate[$l]) {
	$col_mate[$k] = $l;
	$row_mate[$l] = $k;
	# matching row $k with column $l
	next ROW;
      }
    }
    $col_mate[$k] = -1;
    $unchosen_row[$t++] = $k;
  }
    
  goto CHECK_RESULT if $t == 0;
    
  my $s;
  my $unmatched = $t;
  # start stages to get the rest of the matching
  while (1) {
    my $q = 0;
	
    while (1) {
      while ($q < $t) {
	# explore node q of forest; if matching can be increased, update matching
	$k = $unchosen_row[$q];
	$row = $k < $nrows ? $rows[$k] : undef;
	$s = $row_dec[$k];
	for ($l=0; $l<$nmax; $l++) {
	  if ($slack[$l]>0) {
	    $col = $l < $ncols ? $cols[$l]: undef;
	    $cost = ((defined $row and defined $col and defined $cost{$row}{$col}) ?
		     $cost{$row}{$col} : $no_match_cost) - $col_min[$l];
	    my $del = $cost - $s + $col_inc[$l];
	    if ($del < $slack[$l]) {
	      if ($del == 0) {
		goto UPDATE_MATCHING unless defined $row_mate[$l];
		$slack[$l] = 0;
		$parent_row[$l] = $k;
		$unchosen_row[$t++] = $row_mate[$l];
	      } else {
		$slack[$l] = $del;
		$slack_row[$l] = $k;
	      }
	    }
	  }
	}
		
	$q++;
      }
	    
      # introduce a new zero into the matrix by modifying row_dec and col_inc
      # if the matching can be increased update matching
      $s = $INF;
      for ($l=0; $l<$nmax; $l++) {
	if ($slack[$l] and ($slack[$l]<$s)) {
	  $s = $slack[$l];
	}
      }
      for ($q = 0; $q<$t; $q++) {
	$row_dec[$unchosen_row[$q]] += $s;
      }
	    
      for ($l=0; $l<$nmax; $l++) {
	if ($slack[$l]) {
	  $slack[$l] -= $s;
	  if ($slack[$l]==0) {
	    # look at a new zero and update matching with col_inc uptodate if there's a breakthrough
	    $k = $slack_row[$l];
	    unless (defined $row_mate[$l]) {
	      for (my $j=$l+1; $j<$nmax; $j++) {
		if ($slack[$j]==0) {
		  $col_inc[$j] += $s;
		}
	      }
	      goto UPDATE_MATCHING;
	    } else {
	      $parent_row[$l] = $k;
	      $unchosen_row[$t++] = $row_mate[$l];
	    }
	  }
	} else {
	  $col_inc[$l] += $s;
	}
      }
    }
	
   UPDATE_MATCHING:		# update the matching by pairing row k with column l
    while (1) {
      my $j = $col_mate[$k];
      $col_mate[$k] = $l;
      $row_mate[$l] = $k;
      # matching row $k with column $l
      last UPDATE_MATCHING if $j < 0;
      $k = $parent_row[$j];
      $l = $j;
    }
	
    $unmatched--;
    goto CHECK_RESULT if $unmatched == 0;
	
    $t = 0;			# get ready for another stage
    for ($l=0; $l<$nmax; $l++) {
      $parent_row[$l] = -1;
      $slack[$l] = $INF;
    }
    for ($k=0; $k<$nmax; $k++) {
      $unchosen_row[$t++] = $k if $col_mate[$k] < 0;
    }
  }				# next stage

 CHECK_RESULT:			# rigorously check results before handing them back
  for ($k=0; $k<$nmax; $k++) {
    $row = $k < $nrows ? $rows[$k] : undef;
    for ($l=0; $l<$nmax; $l++) {
      $col = $l < $ncols ? $cols[$l]: undef;
      $cost = ((defined $row and defined $col and defined $cost{$row}{$col}) ?
	       $cost{$row}{$col} : $no_match_cost) - $col_min[$l];
      if ($cost < ($row_dec[$k] - $col_inc[$l])) {
	next unless $cost < ($row_dec[$k] - $col_inc[$l]) - $required_precision*max(abs($row_dec[$k]),abs($col_inc[$l]));
	warn "BGM: this cannot happen: cost{$row}{$col} ($cost) cannot be less than row_dec{$row} ($row_dec[$k]) - col_inc{$col} ($col_inc[$l])\n";
	return undef;
      }
    }
  }

  for ($k=0; $k<$nmax; $k++) {
    $row = $k < $nrows ? $rows[$k] : undef;
    $l = $col_mate[$k];
    $col = $l < $ncols ? $cols[$l]: undef;
    $cost = ((defined $row and defined $col and defined $cost{$row}{$col}) ?
	     $cost{$row}{$col} : $no_match_cost) - $col_min[$l];
    if (($l<0) or ($cost != ($row_dec[$k] - $col_inc[$l]))) {
      next unless $l<0 or abs($cost - ($row_dec[$k] - $col_inc[$l])) > $required_precision*max(abs($row_dec[$k]),abs($col_inc[$l]));
      warn "BGM: every row should have a column mate: row $row doesn't, col: $col\n";
      return undef;
    }
  }

  my %map;
  for ($l=0; $l<@row_mate; $l++) {
    $k = $row_mate[$l];
    $row = $k < $nrows ? $rows[$k] : undef;
    $col = $l < $ncols ? $cols[$l]: undef;
    next unless defined $row and defined $col and defined $cost{$row}{$col};
    $reverse_search ? ($map{$col} = $row) : ($map{$row} = $col);
  }
  return {%map};
}

#################################

sub max {

  my $max = shift;
  foreach (@_) {
    $max = $_ if $_ > $max;
  }
  return $max;
}

#################################

sub min {

  my $min = shift;
  foreach (@_) {
    $min = $_ if $_ < $min;
  }
  return $min;
}

#################################

