# STDEval
# MinMax.pm
# Author: George Doddington

package MinMax;
use strict;
require Exporter;
our @ISA = qw (Exporter);
our @EXPORT = qw (min max);
{return 1}

#################################

sub max {

  my $max = shift;
  foreach $_ (@_) {
    $max = $_ if $_ > $max;
  }
  return $max;
}

#################################

sub min {

  my $min = shift;
  foreach $_ (@_) {
    $min = $_ if $_ < $min;
  }
  return $min;
}

#################################

