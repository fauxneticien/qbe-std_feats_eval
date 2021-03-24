# STDEval
# Mapping.pm
# Author: George Doddington

package Mapping;
use strict;
use Graph_Matching;
require Exporter;
our @ISA = qw (Exporter);
our @EXPORT = qw (map_ref_to_sys);
{return 1}

#################################

sub map_ref_to_sys {

  my ($joint_values, $fa_values, $miss_values) = @_;

#create ref_info, sys_info and reversed_values
  my (%ref_info, %sys_info, %reversed_values);
  foreach my $ref_id (keys %$joint_values) {
    defined $miss_values->{$ref_id} or die
      "\n\nFATAL ERROR in map_ref_to_sys: no miss_value defined for ref ID '$ref_id'\n";
    $ref_info{$ref_id} = {ID => $ref_id, MISS_VALUE => $miss_values->{$ref_id}};
    while (my($sys_id, $value) = each %{$joint_values->{$ref_id}}) {
      $reversed_values{$sys_id}{$ref_id} = $value;
    }
  }
  foreach my $sys_id (keys %reversed_values) {
    defined $fa_values->{$sys_id} or die
      "\n\nFATAL ERROR in map_ref_to_sys: no fa_value defined for sys ID '$sys_id'\n";
    $sys_info{$sys_id} = {ID => $sys_id, FA_VALUE => $fa_values->{$sys_id}};
  } 

#group ref and sys ids into cohort sets and map each set independently
  my %map;
  foreach my $ref (values %ref_info) {
    next if exists $ref->{cohort};

#collect cohorts
    my (@ref_cohorts, @sys_cohorts, %sys_map, %ref_map, @queue);
    @queue = ($ref->{ID}, 1);
    $ref->{cohort} = 1;
    $ref->{mapped} = 1;
    push @ref_cohorts, $ref;
    $ref_map{$ref->{ID}} = 1;
    while (@queue > 0) {
      (my $id, my $ref_type) = splice @queue, 0, 2;
      if ($ref_type) { #find sys cohorts for this ref
	foreach my $sys_id (keys %{$joint_values->{$id}}) {
	  next if defined $sys_map{$sys_id} or not defined $joint_values->{$id}{$sys_id};
	  $sys_map{$sys_id} = 1;
	  my $sys = $sys_info{$sys_id};
	  $sys->{cohort} = 1;
	  $sys->{mapped} = 1;
	  push @sys_cohorts, $sys;
	  splice @queue, scalar @queue, 0, $sys_id, 0;
	}
      } else { #find ref cohorts for this sys
	foreach my $ref_id (keys %{$reversed_values{$id}}) {
	  next if defined $ref_map{$ref_id} or not defined $reversed_values{$id}{$ref_id};
	  $ref_map{$ref_id} = 1;
	  my $ref = $ref_info{$ref_id};
	  $ref->{cohort} = 1;
	  $ref->{mapped} = 1;
	  push @ref_cohorts, $ref;
	  splice @queue, scalar @queue, 0, $ref_id, 1;
	}
      }
    }

#map cohorts
    my %costs;
    foreach my $ref_cohort (@ref_cohorts) {
      my ($ref_id, $miss_value) = ($ref_cohort->{ID}, $ref_cohort->{MISS_VALUE});
      foreach my $sys_cohort (@sys_cohorts) {
	my ($sys_id, $fa_value) = ($sys_cohort->{ID}, $sys_cohort->{FA_VALUE});
	$costs{$ref_id}{$sys_id} = $miss_value + $fa_value - $joint_values->{$ref_id}{$sys_id} if
	  defined $joint_values->{$ref_id}{$sys_id};
      }
    }
    my $cohort_map = weighted_bipartite_graph_matching(\%costs) or die
      "\n\nFATAL ERROR:  Cohort mapping through BGM FAILED\n";
    while (my($ref_id, $sys_id) = each %$cohort_map) {
      $map{$ref_id} = $sys_id;
    }
  }

  return {%map};
}

#################################
