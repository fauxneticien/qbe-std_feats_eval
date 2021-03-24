#!/usr/bin/env perl

use strict;

use Getopt::Long;
$Getopt::Long::autoabbrev = 1;
$Getopt::Long::ignorecase = 0;

my $progname = "ProcGraph";

my @mpid = ();
my $interval = 1; # inerval between checks (in seconds)
my $timetogo = -1; #time to go (in seconds)
my $Tree = 0; # Do not follow 'son' processes
my $cumul = 0; # Show 'cumul' values
my $cumul_key = "CUMUL";
my $outdir = -1; # output directory
my $outdir_dft = "/tmp"; # Default output directory
my $filebase = -1; # Default base for output file
my $filebase_dft = $progname; # Default base for output file
my $filecomment = "\#"; # Comment character for output file
my $sigquit = 0; # Signal handler trigger
my $gnuplot = 0; # Generate gnuplot command files
my $gp_file = "gnuplot"; # use this to separate files
my $gp_cmd = -1;
my $gp_cmd_dft = "gnuplot";
my $printto = "";
local *PRINTTO = *STDOUT; # By default print to standard out
my $verb = 0; # Only display info if requested (plural level)
# 0 (default): print error/warnings only
# 1: also print cumul info and found pids
# 2: also print iterations information
# 3: also print individual PID information per step
my ($error_usage, $error, $warning) = (-4, -3, -2); # levels for error/warning
my $dsf = undef;

sub usage {
  print PRINTTO <<EOF;

Usage:
  $0 [common_options] --pid pid [--pid pid]
  or
Command line execution mode:
  $0 [common_options] -- command_line_to_execute

common_options:
--verbose         Increase verbosity level (can be used plural times)
                   Levels:
                    0 (default): print error/warnings/exit information only
                    1: also print cumul info and found pids
                    2: also print iteration information
                    3: also print individual PID information per step
                   All program outputs will be preceded by '[$progname]'

--Printto file    When displaying any output message (including default 
                  and error messages), print to the selected file.
                  By default the script print to standard out.

--interval sec    Interval in seconds between checks
                  Default: 1 second

--time sec        Only run check for so many seconds
                  Default: run until all tracked processes end
                  Warning: When running in 'command_line_to_execute' mode,
                   the started program will run at most 'sec' seconds

--Tree            Follow the process and its sons

--cumul           Show cumulative information for all tracked process
                  (only useful when used in conjunction with '--Tree')

--outdir [dir]    When selected, create file in the "output directory"
                  (default: $outdir_dft) of the form: 'filebase'.'PID'
                  where PID is the process id of the running process
                  Note: the 'cumul' file "PID" will '$cumul_key'

--filebase file   Specify the text preceding the PID for the created when
                  using  'outdir' (Default is: $filebase_dft)

--Comment char    Specify the character(s) to use to insert comments
                  in the output file. Default is gnuplot's '$filecomment'

--gnuplot         Generate command to plot files under gnuplot. Only valid
                  when using 'outdir'. Files will be of the form:
                  'outdir'/'filebase'-$gp_file-'plotted'
                  where 'plotted' is one of: pcpu, rss vsize

--Generate [gnuplot]  Run the gnuplot on command lines and generate an HTML
                  file to have an easy way of viewing the generated plots.
                  If provided, use the 'gnuplot' command provided.
                  Generated html file: 'outdir'/'filebase'.html

--signal          Handle Ctrl+C signal. Useful when tracking a PID, will make
                  the script exit properly

Note about 'gnuplot': The generated files are designed for the latest CVS
version of gnuplot (to have support for higher resolution pictures),
please make sure to have it available. It can be obtained from:
http://www.gnuplot.info/

EOF

}

# Just a quick method to see which letters are still available :)
# ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz #
#   C   G        P   T         c  fghi     o p st       #

# See http://perldoc.perl.org/Getopt/Long.html
# for more details
GetOptions
  (
   'help'         => sub {usage(); exit;},
   'pid=i'        => \@mpid,
   'interval=i'   => \$interval,
   'time=i'       => \$timetogo,
   'Tree'         => sub {$Tree = 1;},
   'cumul'        => sub {$cumul = 1;},
   'verbose'      => sub {$verb++;},
   'outdir:s'     => \$outdir,
   'filebase=s'   => \$filebase,
   'Comment=s'    => \$filecomment,
   'gnuplot'      => sub {$gnuplot = 1;},
   'Generate:s'   => \$gp_cmd,
   'signal'       => sub {$sigquit = 1;},
   'Printto=s'    => \$printto,
  )
  || usage();

# Are we even doing anything ?
&vprintf($error_usage, "Not displaying to screen or to file, aborting\n")
  if (($verb == 0) && ($outdir == -1));

# Set 'PRINTTO' 
if ($printto ne "") {
  open PRINTTO, ">$printto"
    or &vprint($error_usage, "Could not create output \'Printto\' file ($printto): $!\n");
}

# 'outdir' Sanity check
&vprintf($error_usage, "\'filebase\' can only be used if \'outdir\' was\n")
  if (($filebase != -1) && ($outdir == -1));
&vprintf($error_usage, "\'gnuplot\' can only be used if \'outdir\' was\n")
  if (($gnuplot != 0) && ($outdir == -1));
&vprintf($error_usage, "\'Generate\' can only be used if \'outdir\' was\n")
  if (($gp_cmd != -1) && (&outdir == -1));

# If 'outdir' was selected but no directory was given use default
$outdir = $outdir_dft
  if ($outdir eq "");
# same idea for 'filebase'
$filebase = $filebase_dft
  if ($filebase == -1);
# same idea for 'gp_cmd'
$gp_cmd = $gp_cmd_dft
  if ($gp_cmd eq "");

# Quick sanity checks
&vprint($error_usage, "\'outdir\' ($outdir) does not exist or is not a directory\n")
  if (($outdir != -1) && ((! -e $outdir) || (! -d $outdir)));

&vprint($error_usage, "\'filebase\' ($filebase) can not be empty or contain a directory path\n")
  if (($filebase eq "") || ($filebase =~ m%\/%));

&vprintf($error_usage, "\'Generate\' can only be used if \'gnuplot\' is selected\n")
  if (($gp_cmd != -1) && ($gnuplot == 0));

# Remaining of command line is the command to start
my @command = @ARGV;

## Command line and fork of process
&vprint($error_usage, "Only one of a commandline or PID can be used at a time") if ((scalar @mpid != 0) && (scalar @command != 0));

if (scalar @command != 0) {
  my $kidpid;
  
  if (! defined($kidpid = fork())) {
    # fork returned undef, so failed
    &vprint($error, "Could not fork child process: $!");
  } elsif ($kidpid == 0) {
    # fork returned 0, so this branch is child
    exec(@command);
    # if exec fails, fall through to the next statement
    &vprint($error, "Could not exec commandline: $!");
  } else {
    # fork did not return 0 nor undef,so this branch is the parent
    push @mpid, $kidpid;
  }
}

## 'ps' options
my $pscommand="ps -ww";
my $pscommand_format=" -o ";
my @pscommand_options_once   = qw ( lstart user pid ppid command ); # need to start by 'lstart' and end by 'command' (for 'do_pids_info' processing)
my @pscommand_options_always = qw ( pcpu time nice rss vsize ); # need 'vsize' last
my @pscommand_options = ( @pscommand_options_once, @pscommand_options_always);
my $pscommand_pid=" -p ";
my $pscommand_allprocs=" -A ";
my $pscommand_treeinfo=" $pscommand_allprocs -o pid,ppid ";

# Main hash, will contains all info related to each PID
my %pids_info;
# Either in Running or ended state
my $pids_in_key="IN";
my $pids_in_running="RUNNING";
my $pids_in_ended  ="ENDED";

# Cumul keys
my @cumul_keys = qw ( pcpu rss vsize ); # need 'vsize' last too

# Files/Filehandles keys
my $filename_key = "filename";
my $filehandle_key = "filehandle";
my @files_written = ();
my @fw_command = ();
my $short_command = "short_command"; # command started (not full command line)

# min/Max pre keys
my $pre_min = "min";
my $pre_Max = "Max";

# end signal value
my $signal_end = 99;

# Gnuplot position in file for element
# If changing/adding anything always correct those values
my $other_key = "other_key";
my %gp_pos;
$gp_pos{$cumul_key}{$cumul_keys[0]} = 3;
$gp_pos{$cumul_key}{$cumul_keys[1]} = 4;
$gp_pos{$cumul_key}{$cumul_keys[2]} = 5;
$gp_pos{$other_key}{$cumul_keys[0]} = 2;
$gp_pos{$other_key}{$cumul_keys[1]} = 5;
$gp_pos{$other_key}{$cumul_keys[2]} = 6;
my $gp_time = 1; # the time key is always the first info in the file
# Gnuplot files
my %gp_files;
my $gpf_cmd_key = "cmd";
my $gpf_png_key = "png";
my $gpf_table_key = "table";
my $gpf_df_key = "data";
my $gpf_csv_key = "csv";
my @table_curve = ();

# Start/End 'time'
my $stkey = "stkey";
my $etkey = "etkey";

####################
## Start of core
&vprint($error_usage, "No PID selected\n")
  if (scalar @mpid == 0);

## Signal handling (SIGINT only)
$SIG{INT} = \&sig_catcher
  if ($sigquit);

## MAIN LOOP
$dsf = 0;
my $running = 1;
my @pids = @mpid;
&vprint(1, "Master PID: " . join(" ", @mpid));
while ($running) {
  my @tpids = ();
  
  &vprintf(2, "Iteration: %d%s",
	 ($dsf / $interval) + 1,
	 ($timetogo > 0) ? " / " . ($timetogo/$interval) : "");
  
  ## Find processes sons
  if ($Tree) {
    my $cont = 1;
    # Only do one 'ps' per tree find
    my $cmdline = "$pscommand $pscommand_treeinfo";
    my @it=`$cmdline`;
    chomp @it;
    shift @it;
    
    while ($cont) { # no more sons if start pid list is same at end
      my $sc = scalar @pids;
      
      foreach my $cpid (@pids) {
	push @tpids, $cpid;
	my @res = find_sons($cpid, @it);
	foreach my $npid (@res) {
	  if (! grep (/^$npid$/, @pids)) {
	    push @tpids, $npid;
	    &vprint(1, "New Son PID: $npid");
	  }
	}
      }
      @pids = @tpids;
      @tpids = ();
      
      $cont = 0
	if ($sc == scalar @pids);
    }
    &vprintf(2, "Tree: %d processes", scalar @pids);
  }

  ## Cumul (init)
  if ($cumul) {
    foreach my $keys (@cumul_keys) {
      $pids_info{$cumul_key}{$keys} = 0;
    }
  }
  
  
  ## Do each PID
  foreach my $cpid (@pids) {
    &do_pids_info($cpid)
      if (! exists $pids_info{$cpid}{$pids_in_key});
    
    &do_pid($cpid);
    
    next if ($pids_info{$cpid}{$pids_in_key} eq $pids_in_ended);
    
    &write_pidfile($cpid);

    if ($verb >=3) {
      &vprint(3, "[PID $cpid]");
      foreach my $opt (@pscommand_options) {
	&vprintf(3, "%10.10s  :  %s", $opt, $pids_info{$cpid}{$opt} );
      }
    }
    
    ## Cumul (add)
    if ($cumul) {
      foreach my $key (@cumul_keys) {
	$pids_info{$cumul_key}{$key} += $pids_info{$cpid}{$key};
      }
    }

    push @tpids, $cpid;
  }
  @pids = @tpids;

  ## Cumul (process)
  # Note: if 'vsize' is '0', it means not more process, skip step
  if (($cumul) 
      && ($pids_info{$cumul_key}{$pscommand_options_always[-1]} != 0)) {
    # Write to disk
    &write_pidfile($cumul_key, scalar @pids);
    # Display
    &vprint(1, "[$cumul_key]");
    foreach my $key (@cumul_keys) {
      &vprintf(1, "%10.10s  :  %s", $key, $pids_info{$cumul_key}{$key} );
    }
    # Compute min/Max
    foreach my $opt (@cumul_keys) {
      my $xopt = $pre_min . $opt;
      $pids_info{$cumul_key}{$xopt} = $pids_info{$cumul_key}{$opt}
	if ((! exists $pids_info{$cumul_key}{$xopt})
	    || ($pids_info{$cumul_key}{$opt} < $pids_info{$cumul_key}{$xopt}));
      
      $xopt = $pre_Max . $opt;
      $pids_info{$cumul_key}{$xopt} = $pids_info{$cumul_key}{$opt}
	if ((! exists $pids_info{$cumul_key}{$xopt})
	    || ($pids_info{$cumul_key}{$opt} > $pids_info{$cumul_key}{$xopt}));
    }
  }
  
  ## Go 'interval' more second, or exit properly (signal, done, ...)
  $dsf += $interval;
  if (scalar @pids == 0) {
    &vprint($warning, "No more PIDs to follow, exiting");
    &close_pidfile($cumul_key);
    $running = 0;
  } elsif (($timetogo > 0) && ($dsf >= $timetogo)) {
    $running = 0;
  } elsif ($sigquit == $signal_end) {
    $running = 0;
  } else {
    sleep($interval);
  }
}

# Close all still open PID file
if (scalar @pids > 0) {
  foreach my $rpid (@pids) {
    &close_pidfile($rpid);
  }

  &close_pidfile($cumul_key);
}

# List written files
for (my $i = 0; $i < scalar @files_written; $i++) {
  my $file = $files_written[$i];
  my $command = $fw_command[$i];
  &vprint(0, "Log file: $file $command");
}

## Gnuplot files generation
&do_gnuplot_cmdfiles();
&create_html();

# Exit successfuly
&vprint(0, "Ended successfuly\n");
exit(0);
## End of Script


########################################
## SUBS

sub cleanstr {
  my $str = shift @_;
  
  $str =~ s/^\s+//;
  $str =~ s/\s+$//;
  
  return $str;
}

####################

sub do_pids_info {
  my $rpid = shift @_;
  
  my $cladd = join ",", @pscommand_options_once;
  my $cmdline = "$pscommand $pscommand_pid $rpid $pscommand_format $cladd";
  my @it=`$cmdline`;
  
  if (scalar @it == 1) {
    $pids_info{$rpid}{$pids_in_key} = $pids_in_ended;
    &close_pidfile($rpid);
    return;
  }
  
  chomp @it;
  shift @it;
  my $work = shift @it;
  
  my @todo = @pscommand_options_once;
  
  # 'lstart' is special
  my $now = shift @todo;
  $pids_info{$rpid}{$now} = &cleanstr($1)
    if ($work =~ s/^(.+?2\d{3})\s+//);
  # using the fact that all data  end in 2xxx
  
  # 'command' is special too (part 1)
  # get it out of the end of the 'todo' list and keep it for last
  @todo = reverse @todo;
  $now = shift @todo;
  @todo = reverse @todo;
  
  # all the other are easy
  my @rest = split ( /\s+|\t+/, $work);

  foreach my $opt (@todo) {
    $pids_info{$rpid}{$opt} = &cleanstr(shift @rest);
    $work = &cleanstr($work);
    $work =~ s/^$pids_info{$rpid}{$opt}//;
  }
  $work = &cleanstr($work);

  # 'command' (part 2)
  # what is left in 'work' after removing all found entries
  $pids_info{$rpid}{$now} = $work;

  # 'short_command' is the first element in '@rest'
  $pids_info{$rpid}{$short_command} = &cleanstr(shift @rest);

  $pids_info{$rpid}{$pids_in_key} = $pids_in_running;
}
  
##########

sub do_pid {
  my $rpid = shift @_;

  my $cladd = join(",", @pscommand_options_always);
  my $cmdline = "$pscommand $pscommand_pid $rpid $pscommand_format $cladd";
  my @it=`$cmdline`;

  if (scalar @it == 1) {
    &vprintf($warning, "PID $rpid%s ended, not tracking anymore",
	   (exists $pids_info{$rpid}{$short_command})
	    ? " ($pids_info{$rpid}{$short_command})"
	    : "");
    $pids_info{$rpid}{$pids_in_key} = $pids_in_ended;
    &close_pidfile($rpid);
    return;
  }

  chomp @it;
  shift @it;
  my $work = shift @it;
  my @rest = split ( /\s+|\t+/, &cleanstr($work));

  foreach my $opt (@pscommand_options_always) {
    $pids_info{$rpid}{$opt} = &cleanstr(shift @rest);
  }

  # If the process 'vsize' is '0' it means the process is 'defunct'
  if ($pids_info{$rpid}{$pscommand_options_always[-1]} == 0) {
    &vprintf($warning, "PID $rpid%s \'defunct\', not tracking anymore",
	   (exists $pids_info{$rpid}{$short_command})
	    ? " ($pids_info{$rpid}{$short_command})"
	    : "");
    $pids_info{$rpid}{$pids_in_key} = $pids_in_ended;
    &close_pidfile($rpid);
    return;
  }
  
  # start time
  $pids_info{$rpid}{$stkey} = $dsf
    if (! exists $pids_info{$rpid}{$stkey});

  # Compute min/Max (only need to know about the same things as for 'cumul')
  foreach my $opt (@cumul_keys) {
    my $xopt = $pre_min . $opt;
    $pids_info{$rpid}{$xopt} = $pids_info{$rpid}{$opt}
      if ((! exists $pids_info{$rpid}{$xopt})
	  || ($pids_info{$rpid}{$opt} < $pids_info{$rpid}{$xopt}));
    
    $xopt = $pre_Max . $opt;
    $pids_info{$rpid}{$xopt} = $pids_info{$rpid}{$opt}
      if ((! exists $pids_info{$rpid}{$xopt})
	  || ($pids_info{$rpid}{$opt} > $pids_info{$rpid}{$xopt}));
  }

}

####################

sub find_sons {
  my $rpid = shift @_;
  my @it = @_;

  my @res = ();
  foreach my $line (@it) {
    $line = &cleanstr($line);

    my ($pid, $ppid) = split(/\s+/, $line);

    push @res, $pid
      if ($ppid == $rpid);
  }

  return @res;
}

####################

sub exit_or_not {
  # only exit on error message
  my $pl = shift @_;

  return if ($pl > $error);

  &usage() if ($pl == $error_usage);

  exit(1);
}

sub headerprint {
  my $pl = shift @_;

  printf PRINTTO ("\n[$progname]%s %s", 
		  (defined $dsf) ? "[$dsf]" : "",
		  ($pl == $warning) ? "WARNING: " : 
		  (($pl <= $error) ? "ERROR: " : ""));

}

sub vprintf {
  my $pl = shift @_;

  return if ($verb < $pl);

  headerprint($pl);
  printf PRINTTO (@_);

  &exit_or_not($pl);
}

sub vprint {
  my $pl = shift @_;

  return if ($verb < $pl);
  
  headerprint($pl);
  print PRINTTO (@_);

  &exit_or_not($pl);
}

####################
## output files

sub create_fh {
  local *FH;
  return *FH;
}

##

sub create_pidfile {
  my $rpid = shift @_;

  $pids_info{$rpid}{$filename_key} = "$outdir/$filebase.$rpid";
  $pids_info{$rpid}{$filehandle_key} = create_fh();
  
  open $pids_info{$rpid}{$filehandle_key}, ">$pids_info{$rpid}{$filename_key}"
    or &vprint($error, "Could not create output log file ($pids_info{$rpid}{$filename_key}) for PID ($rpid): $!\n");
}

##

sub close_pidfile {
  my $rpid = shift @_;
  
  return if (! exists $pids_info{$rpid}{$filehandle_key});

  local *FH = $pids_info{$rpid}{$filehandle_key};

  # min/Max add (only want to know about the same values as 'cumul')
  print FH "$filecomment\n$filecomment min/Max summary:\n";
  foreach my $opt (@cumul_keys) {
    my $mopt = $pre_min . $opt;
    my $Mopt = $pre_Max . $opt;
    
    print FH "$filecomment $opt\t$pre_min: "
      . $pids_info{$rpid}{$mopt}
	. "\t$pre_Max: "
	  . $pids_info{$rpid}{$Mopt}
	    . "\n";
  }

  # For 'cumul' also add information about all related PID files
  if ($rpid eq $cumul_key) {
    print FH "$filecomment\n$filecomment All processes log files:\n";
    for (my $i = 0; $i < scalar @files_written; $i++) {
      my $file = $files_written[$i];
      my $command = $fw_command[$i];
      print FH "$filecomment $file $command\n";
    }
    # Also remember to tell it that 'cumul' started at '0'
    $pids_info{$rpid}{$stkey} = 0;
  }

  # Add 'run for' information
  print FH "$filecomment\n$filecomment Run for " . 
    (1 + $pids_info{$rpid}{$etkey} - $pids_info{$rpid}{$stkey}) . " s\n";

  close $pids_info{$rpid}{$filehandle_key};
  push @files_written, $pids_info{$rpid}{$filename_key};
  if ($rpid eq $cumul_key) {
    push @fw_command,  "";
  } else {
    push @fw_command, "(" . $pids_info{$rpid}{$short_command} . ")";
  }
}

##

sub write_pidfile {
  return if ($outdir == -1);

  my $rpid = shift @_;
  my $srpids = shift @_; # "Still running pids" (Only useful for 'cumul')

  local *FH;

  ##########
  # If output file does not exist, create it and add header informations
  if (! exists $pids_info{$rpid}{$filehandle_key}) {
    &create_pidfile($rpid);
    *FH = $pids_info{$rpid}{$filehandle_key};

    if ($rpid ne $cumul_key) {
      foreach my $opt (@pscommand_options_once) {
	printf FH "$filecomment %10.10s  :  %s\n", $opt, $pids_info{$rpid}{$opt};
      }
      print FH "$filecomment\n";
    }
  
    print FH "$filecomment timeval\t";

    if ($rpid ne $cumul_key) {
      print FH join("\t", @pscommand_options_always) . "\n";
    } else {
      print FH "running_procs\t";
      print FH join("\t", @cumul_keys) . "\n";
    }
  } # end file creation

  ##########
  # Write _current_ data to file
  *FH = $pids_info{$rpid}{$filehandle_key};
  print FH "$dsf\t";
  if ($rpid ne $cumul_key) {
    foreach my $opt (@pscommand_options_always) {
      print FH $pids_info{$rpid}{$opt} . "\t";
    }
  } else {
    print FH "$srpids\t";
    foreach my $opt (@cumul_keys) {
      print FH $pids_info{$rpid}{$opt} . "\t";
    }
  }
  print FH "\n";

  # end time
  $pids_info{$rpid}{$etkey} = $dsf;
}

####################

sub sig_catcher {
  &vprint($warning, "Received SIGINT signal, exiting properly");

  $sigquit = $signal_end;
}

####################

sub do_gnuplot_cmdfiles {
  return if (! $gnuplot);

  foreach my $opt (@cumul_keys) {
    local *FH;
    my $fname = "$outdir/${filebase}-${gp_file}-$opt";
    my $pfname = "$fname.png";
    
    $gp_files{$opt}{$gpf_table_key} = "$fname.${gpf_table_key}";
    $gp_files{$opt}{$gpf_csv_key} = "$fname.${gpf_csv_key}";
    
    # 'table_txt' is used to add commands to the gnuplot command file
    # in order to have an easy way of generating a "table" "replot"
    my $table_txt = "\n# The following lines are only useful to help generate the CSV file\n";
    $table_txt .= "\n# Replot into a text readable table\n";
    $table_txt .= "set table \"" . $gp_files{$opt}{$gpf_table_key} . "\"\n";

    open FH, ">$fname"
      or &vprint($error, "Could not create output gnuplot command file ($fname): $!\n");
    # We are sure to use gnuplot here, so use the real comment char (#)
    print FH "\# Force output to be a PNG file\n" 
      . "set terminal png size 1600,1200\n";
    print FH "\# Write output to a proper filename\n"
      . "set output \"$pfname\"";
    print FH "\# Set x & y labels\n"
      . "set xlabel \"time\"\n"
	. "set ylabel \"$opt\"\n";

    # Start the 'plot' line
    print FH "\# Plot all \'$opt\'\n"
      . "plot ";
    my @fw_f = reverse @files_written; # to start by 'cumul'
    my @fw_c = reverse @fw_command;
    for (my $i = 0; $i < scalar @fw_f; $i++) {
      my $file = $fw_f[$i];
      my $tpid = $1 if ($file =~ /\.(\w+?)$/);
      my $cmd = ($tpid eq $cumul_key) ? "$cumul_key" : $fw_c[$i];
      my $c2 = $gp_pos{($tpid eq $cumul_key) ? $cumul_key : $other_key}{$opt};
      my $txt = ($tpid eq $cumul_key) ? $cumul_key : "PID $tpid $cmd";
      print FH "\"$file\" using ${gp_time}:${c2} with lines title \"$txt\"";
      print FH ", " if ($i < scalar @fw_f - 1);

      push @table_curve, $txt;
    }
    print FH "\n";

    $table_txt .= "replot\n";
    print FH $table_txt
      if ($gp_cmd != -1);

    close FH;

    $gp_files{$opt}{$gpf_cmd_key} = $fname;
    $gp_files{$opt}{$gpf_png_key} = $pfname;
    &vprint(0, "Gnuplot Command File: $fname");
  }
}

#####

sub run_gp {
  foreach my $opt (@cumul_keys) {
    my $fname = $gp_files{$opt}{$gpf_cmd_key};
    my $pfname = $gp_files{$opt}{$gpf_png_key};
    &vprint($error, "Could not find gnuplot command file ($fname)\n")
      if (! -e $fname);
    my $gprun = `$gp_cmd < $fname 2>&1`; # Run command, and capture both its stdout and stderr in the run variable
    &vprint($warning, "\'GnuPlot\' run for command file ($fname) did output the follwing text:\n$gprun")
      if ($gprun ne "");
    if (! -e $pfname) {
      &vrint($warning, "Could not generate output PNG file ($pfname)\n");
      return 0;
    }
  }

  return 1;
}

#####

sub create_html {
  return if ($gp_cmd == -1);

  # first, run gnuplot
  my $ok_gp = &run_gp();
  if ($ok_gp == 0) {
    &vprint($warning, "There was a problem in the gnuplot run, skipping HTML generation");
    return;
  }

  # Then create the output file
  my $ofname = "$outdir/$filebase.html";
  local *FH;

  open FH, ">$ofname"
    or &vprint($error, "Could not create output html file ($ofname): $!\n");

  print FH "<html>\n<head>\n<title>$progname output</title>\n</head>\n";
  print FH "<body><h1>$progname output</h1>\n";
  
  foreach my $opt (@cumul_keys) {
    my $fname = $gp_files{$opt}{$gpf_cmd_key};
    my $pfname = $gp_files{$opt}{$gpf_png_key};

    # Generate the csv file
    my $got_df = &table2csv($opt);

    my $cfname = ($got_df == 0) ? "" : $gp_files{$opt}{$gpf_csv_key};

    $fname = $1 if ($fname =~ m%\/([^\/]+)$%);
    $pfname = $1 if ($pfname =~ m%\/([^\/]+)$%);
    $cfname = $1 if ($cfname =~ m%\/([^\/]+)$%);
    
    print FH "<hr>\n<h2>$opt Plot</h2>\n"
      . "Generated from Gnuplot command file: <a href=\"$fname\">$fname</a><br>\n"
	. "Generated PNG file: <a href=\"$pfname\">$pfname</a><br>\n";

    print FH "CSV file containing entries used to generate this plot: <a href=\"$cfname\">$cfname</a><br>\n"
      if ($cfname ne "");
    print FH "<a href=\"$pfname\"><img src=\"$pfname\"></a><br>\n";
    print FH "<h3>$opt min/Max information</h3>\n";
    print FH "<table border=1>\n"
      . "<tr>\n<td><b>PID</b></td>\n<td><b>$opt min</b></td>\n"
	. "<td><b>$opt Max</b></td>\n<td><b>started</b></td>\n"
	  . "<td><b>ended</b></td>\n<td><b>Run for (s)<b></td>\n"
	    . "<td><b>full command line</b></td>\n</tr>\n";
	    
    for (my $i = 0; $i < scalar @files_written; $i++) {
      my $file = $files_written[$i];
      my $tpid = $1 if ($file =~ /\.(\w+?)$/);
      my $mopt = $pre_min . $opt;
      my $Mopt = $pre_Max . $opt;
      print FH "<tr>\n"
	. "<td>$tpid</td>\n"
	  . "<td>$pids_info{$tpid}{$mopt}</td>\n"
	    . "<td>$pids_info{$tpid}{$Mopt}</td>\n"
	      . "<td>$pids_info{$tpid}{$stkey}</td>\n"
		. "<td>$pids_info{$tpid}{$etkey}</td>\n"
		  . "<td>" . (1 + $pids_info{$tpid}{$etkey} 
			      - $pids_info{$tpid}{$stkey}) . "</td>\n"
		    . "<td>$pids_info{$tpid}{$pscommand_options_once[-1]}</td>\n"
		      . "</tr>\n";
    }
    print FH "</table>\n";

  }

  print FH "<hr><i>Generated on:" . localtime(time()) . "</i>\n";
  print FH "</body>\n</html>\n";

  close FH;
  &vprint(0, "HTML results: $ofname");
}

####################

sub extract_curve {
  my $curven = shift @_;
  local *FH = shift @_;
  my @res = ();

  while (my $line = <FH>) {

    # Heavily reliant on gnuplot's table output of the form:
    # '#Curve 1 of 5, 75 points'
    if ($line =~ /^\#\s*curve\s+${curven}\s+of\s+\d+\,\s+(\d+)\s+points/i) {
      my $points = $1; # Get the total number of entry
      # discard next line
      $line = <FH>;

      # Read 'points' lines
      for (my $i = 0; $i < $points; $i++) {
	$line = <FH>;
	push @res, $line;
      }

      # done, return
      return @res;
    }

    # Well keep reading until finding the proper curve number
  }
}

sub table2csv {
  my $opt = shift @_;
  my $tfile = $gp_files{$opt}{$gpf_table_key};
  my $ofile = $gp_files{$opt}{$gpf_csv_key};

  if (! -e $tfile) {
    &vprint($warning, "\'table\' file does not exists ($tfile), skipping \'datafile\' generation");
    return 0;
  }

  my $csv_header = "Time";
  my @csv = ();

  open TFILE, "<$tfile"
    or &vprint($error, "Could not read table file ($tfile): $!\n");
  open OFILE, ">$ofile"
    or &vprint($error, "Could not create csv file ($ofile): $!\n");

  # There are only so many 'Curve's to process
  my @fw_f = reverse @files_written;
  # We _need_ to start by 'cumul' so that all time slots are filled
  for (my $i = 0; $i < scalar @fw_f; $i++) {
    $csv_header .= ", \"$opt for $table_curve[$i]\"";

    # Get this curve information
    my @c = &extract_curve($i, *TFILE);
    chomp @c;
    
    my $domin = 1;
    my $rtime; # 'real "time"' = 'read time' / 'interval' (fill @csv in inc)
    foreach my $line (@c) {
      $line = cleanstr($line);
      $line =~ m%^(\d+)\s+([\d|\.]+)\s%;
      my ($time, $value) = ($1, $2);
      $rtime = $time / $interval;
      # fill up all entries before this one
      if ($domin) {
	if ($rtime != 0) {
	  for (my $j = 0; $j < $rtime; $j++) {
	    $csv[$j] .= ", ";
	  }
	}
	$domin = 0;
      }
      # Add 'value' to the proper 'csv' lines
      $csv[$rtime] .= ", $value";
    }
    # Now check we do not need to fill the end of the 'csv'
    if ($rtime < scalar @csv) {
      for (my $j = $rtime + 1; $j < scalar @csv; $j++) {
	$csv[$j] .= ", ";
      }
    }

  } # Go to next 'curve entry'
  # We do not need the table file anymore, we read all we needed
  close TFILE;

  # Now that all entries are read, fill the output file
  print OFILE "$csv_header\n";
  my ($check, $pcheck) = (-1, -1);
  for (my $i = 0; $i < scalar @csv; $i++) {
    $pcheck = $check;
    $check = scalar split(/,/, @csv);
    &vprint($warning, "Found a different number of entries from one line of the csv file to the next ... this should _not_ have happened")
      if (($pcheck != -1) && ($check != $pcheck));
    printf OFILE ("%d%s\n", $i * $interval, $csv[$i]);
  }
  close OFILE;
  
  return 1;
}
