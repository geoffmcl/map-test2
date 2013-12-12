#!/usr/bin/perl -w
##########################################################################################
# include module: lib_utils.pl (was fgutils02.pl)
# 01/08/2012 Added set_load_log($arg,$rll) - set 3 if ^lll, 2 if ^ll, else 1
# 18/02/2011 Added several time functions - 
# 17/02/2011 Added funtion prt_log(msg) to directly write to LOG file, if open.
# 13/12/2010 Added function is_ulog_open(), to do own writing if required
# 30/10/2010 Added trim_tailing($) and trim_leading($) called in trim_ends($)
# 08/09/2010 geoff mclane http://geoffair.net/mperl
##########################################################################################
use strict;
use warnings;
use Time::gmtime;
my $os = $^O;
my $PATH_SEP = '/';
if ($os =~ /win/i) {
    $PATH_SEP = "\\";
}

our $LF;
my $def_src_filt = "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat;for;f90";
my $def_hdr_filt = "h;hpp;hxx;hm;inl;fi;fd";
my $def_rcs_filt = "ico;cur;bmp;dlg;rc2;rct;bin;cnt;rtf;gif;jpg;jpeg;jpe";
my $def_spl_filt = "txt;vc5;h-msvc8;asm";
my $def_oth_filt = $def_hdr_filt.';'.$def_rcs_filt.';'.$def_spl_filt;

my $def_src_grp = "Source Files";    # Begin Group "Source Files"
my $def_hdr_grp = "Header Files";	# Begin Group "Header Files"
my $def_rcs_grp = "Resource Files";	# Begin Group "Resource Files"
my $def_spl_grp = "Special Files";
my $def_unknown = "Other Files";

my $vs_install_directory = '';

sub get_def_src_filt { return $def_src_filt; }
sub get_def_hdr_filt { return $def_hdr_filt; }
sub get_def_rcs_filt { return $def_rcs_filt; }
sub get_def_spl_filt { return $def_spl_filt; }

sub get_def_src_grp { return $def_src_grp; }
sub get_def_hdr_grp { return $def_hdr_grp; }
sub get_def_rcs_grp { return $def_rcs_grp; }
sub get_def_spl_grp { return $def_spl_grp; }

######## LOG FILE STUFF #########
my $write_log = 0;

sub is_ulog_open { return $write_log; }

sub open_log {
	my ($f) = shift;
	open $LF, ">$f" or die "ERROR: Unable to open $f ...\n";
	$write_log = 1;
}

sub prt_log {
	if ($write_log) {
		print $LF shift;
	}
}

sub prt {
	my ($msg) = shift;
	if ($write_log) {
		print $LF $msg;
	}
	print $msg;
}

sub mydie {
	my ($msg) = shift;
	if ($write_log) {
		print $LF $msg;
	}
	die $msg;
}

sub close_log {
	my ($of, $p) = @_;
	prt( "Closing LOG and passing $of to system ...\nMay need to CLOSE 'editor' to exit ...\n") if ($p);
	if ($write_log) {
		close( $LF );
	}
    $write_log = 0;
    if ($p) {
	    if ($os =~ /win/i) {
            if ($p == 3) {
                system( "npp $of" );
            } elsif ($p == 2) {
                system( "ep $of" );
            } else {
                system( $of );
            }
	    } else {
            system( "nano $of" );
        }
    }
}

sub set_load_log($$) {
    my ($arg,$rll) = @_;
    my $val = 1;
    if ($arg =~ /^lll/) {
        $val = 3;
    } elsif ($arg =~ /^ll/) {
        $val = 2;
    }
    ${$rll} = $val;
}

sub write2file {
	my ($txt,$fil) = @_;
	open WOF, ">$fil" or mydie("ERROR: Unable to open $fil! $!\n");
	print WOF $txt;
	close WOF;
}

sub append2file {
	my ($txt,$fil) = @_;
	open WOF, ">>$fil" or mydie("ERROR: Unable to open $fil! $!\n");
	print WOF $txt;
	close WOF;
}

sub trim_leading($) {
    my ($ln) = shift;
	$ln = substr($ln,1) while ($ln =~ /^\s/); # remove all LEADING space
    return $ln;
}

sub trim_tailing($) {
    my ($ln) = shift;
	$ln = substr($ln,0, length($ln) - 1) while ($ln =~ /\s$/g); # remove all TRAILING space
    return $ln;
}

sub trim_ends($) {
    my ($ln) = shift;
    $ln = trim_tailing($ln); # remove all TRAINING space
	$ln = trim_leading($ln); # remove all LEADING space
    return $ln;
}

sub trim_all {
	my ($ln) = shift;
	$ln =~ s/\n/ /gm;	# replace CR (\n)
	$ln =~ s/\r/ /gm;	# replace LF (\r)
	$ln =~ s/\t/ /g;	# TAB(s) to a SPACE
    $ln = trim_ends($ln);
	$ln =~ s/\s{2}/ /g while ($ln =~ /\s{2}/);	# all double space to SINGLE
	return $ln;
}


#########################################
###### relative path stuff ##############
sub path_u2d($) {
	my ($ud) = shift;
	$ud =~ s/\//\\/g;
	return $ud;
}

sub path_d2u($) {
	my ($du) = shift;
	$du =~ s/\\/\//g;
	return $du;
}

# 20120413 - Another try to get this RIGHT
sub get_relative_path4($$) {
    my ($to,$from) = @_;
    my $dbg_rel = 0;
    my $cos = $^O;
    my $cos_is_win = ($cos =~ /Win/i) ? 1 : 0;
    my $path_sep = "/";
    $path_sep = "\\" if ($cos_is_win);
    prt("OS is ".(($cos_is_win) ? "Windows" : "Unix")."\n") if ($dbg_rel);
	# remove drives, if present
    if ($cos_is_win) {
        $to = path_u2d($to);
        $from = path_u2d($from);
    } else {
        $to = path_d2u($to);
        $from = path_d2u($from);
    }
    my ($cpos);
    if ($cos_is_win) {
        if ( ($cpos = index($to, ":")) != -1 ) {
            $to = substr($to, $cpos+1 );
        }
        if ( ($cpos = index( $from, ":" )) != -1 ) {
            $from = substr($from, $cpos+1 );
        }
        # should check DRIVES are the SAME
    }
    # remove leading '\' or '/'
    $to =~ s/^(\\|\/)//;
    $from =~ s/^(\\|\/)//;
    # remove trailing '\' or '/', if present
    $to =~ s/(\\|\/)$//;
    $from =~ s/(\\|\/)$//;

    # get path arrays
    my (@arr0,@arr1,@arr2);
    if ($cos_is_win) {
        @arr0 = split(/\\/,$to);
        $to = lc($to);
        $from = lc($from);
        @arr1 = split(/\\/,$to);
        @arr2 = split(/\\/,$from);
    } else {
        @arr0 = split(/\//,$to);
        @arr1 = split(/\//,$to);
        @arr2 = split(/\//,$from);
    }
    my $len1 = scalar @arr1;
    my $len2 = scalar @arr2;
    my $max = ($len1 < $len2) ? $len1 : $len2;
    my ($ccnt,$comcnt,$sub1,$sub2);
    $comcnt = 0;
    # eliminate common start, if any
    for ($ccnt = 0; $ccnt < $max; $ccnt++) {
        $sub1 = $arr1[$ccnt];
        $sub2 = $arr2[$ccnt];
        if ($sub1 eq $sub2) {
            $comcnt++;
            # prt("sm [$sub1] == [$sub2] ");
        } else {
            last;
        }
    }
    prt("Common $comcnt") if ($dbg_rel);
    # back up for the difference remaining of the from
    $cpos = $len2 - $comcnt;
    my $relpath = '';
    prt(", backup $cpos out [$from]$len2 ") if ($dbg_rel);
    while ($cpos) {
        $relpath .= "..".$path_sep;
        $cpos--;
    }
    # append to remaining to components
    $cpos = $len1 - $comcnt;
    prt(", append $cpos of [$to]$len1") if ($dbg_rel);
    for (;$comcnt < $len1 ; $comcnt++) {
        $relpath .= $arr0[$comcnt].$path_sep;
    }
    prt(", result [$relpath]\n") if ($dbg_rel);
    return $relpath;
}

# Given TWO FOLDER, attempt to get RELATIVE PATH from the FROM DIRECTORY,
# to the TARGET DIRECTORY. MUSTS BE DIRECTORIES, NOT FILE PATHS
##my $rel = get_relative_path( $htm_folder, $my_folder ); added 20070820
# seems to work fine ... still under test!!!
# 17/11/2007 - Further refinement to REMOVE all warnings
sub get_relative_path_reversed_words {
	my ($target, $fromdir) = @_;
    my $dbg_rel = 0;
	my ($colonpos, $path, $posval, $diffpos, $from, $to);
	my ($tlen, $flen);
    my ($lento, $lenfrom);
	my $retrel = "";
	# only work with slash - convert DOS backslash to slash
	$target = path_d2u($target);
	$fromdir = path_d2u($fromdir);
	# add '/' to target. if missing
	if (substr($target, length($target)-1, 1) ne '/') {
		$target .= '/';
	}
	# add '/' to fromdir. if missing
	if (substr($fromdir, length($fromdir)-1, 1) ne '/') {
		$fromdir .= '/';
	}

	# remove drives, if present
    if ( ( $colonpos = index( $target, ":" ) ) != -1 ) {
		$target = substr( $target, $colonpos+1 );
	}
	if ( ( $colonpos = index( $fromdir, ":" ) ) != -1 ) {
        $fromdir = substr( $fromdir, $colonpos+1 );
    }
	# got the TO and FROM ...
	$to = $target;
	$from = $fromdir;
	print "To [$to], from [$from] ...\n" if ($dbg_rel);
	$path = '';
	$posval = 0;
	$retrel = '';
    $lento = length($to);
    $lenfrom = length($from);
	# // Step through the paths until a difference is found (ignore slash differences)
	# // or until the end of one is found
	while ( ($posval < $lento) && ($posval < $lenfrom) ) {
		if ( substr($from,$posval,1) eq substr($to,$posval,1) ) {
			$posval++; # bump to next
		} else {
			last; # break;
		}
	}

	# // Save the position of the first difference
	$diffpos = $posval;

	# // Check if the directories are the same or
	# // the if target is in a subdirectory of the fromdir
	if ( ( !substr($from,$posval,1) ) &&
		 ( substr($to,$posval,1) eq "/" || !substr($to,$posval,1) ) )
	{
		# // Build relative path
		$diffpos = length($target);
		if (($posval + 1) < $diffpos) {
			$diffpos-- if ($diffpos);
			if ($diffpos > $posval) {
				$diffpos -= $posval;
			} else {
				$diffpos = 0;
			}
			###$retrel = substr( $target, $posval+1, length( $target ) );
			print "Return substr of target, from ".($posval+1).", for $diffpos length ...\n" if ($dbg_rel);
			$retrel = substr( $target, $posval+1, $diffpos );
		} else {
			print "posval+1 (".($posval+1).") greater than length $diffpos ...\n" if ($dbg_rel);
		}
	} else {
		# // find out how many "../"'s are necessary
		# // Step through the fromdir path, checking for slashes
		# // each slash encountered requires a "../"
		#$posval++;
		while ( substr($from,$posval,1) ) {
			print "Check for slash ... $posval in $from\n" if ($dbg_rel);
			if ( substr($from,$posval,1) eq "/" ) { # || ( substr($from,$posval,1) eq "\\" ) ) {
				print "Found a slash, add a '../' \n" if ($dbg_rel);
				$path .= "../";
			}
			$posval++;
		}
		print "Path [$path] ...\n" if ($dbg_rel);

		# // Search backwards to find where the first common directory
		# // as some letters in the first different directory names
		# // may have been the same
		$diffpos--;
		while ( ( substr($to,$diffpos,1) ne "/" ) && substr($to,$diffpos,1) ) {
			$diffpos--;
		}
		# // Build relative path to return
		$retrel = $path . substr( $target, $diffpos+1, length( $target ) );
    }
	print "Returning [$retrel] ...\n" if ($dbg_rel);
	return $retrel;
}

sub get_relative_path {
	my ($fromdir, $targdir) = @_;
    my $dbg_rel = 0;
	my ($colonpos, $path, $posval, $diffpos, $topath, $frpath);
	my ($tlen, $flen);
    my ($frlen, $tolen);
	my $retrel = "";
	# only work with slash - convert DOS backslash to slash
	$fromdir = path_d2u($fromdir);
	$targdir = path_d2u($targdir);
	# add '/' to from, if missing
	$fromdir .= '/' if (substr($fromdir, length($fromdir)-1, 1) ne '/');
	# add '/' to fromdir. if missing
	$targdir .= '/' if (substr($targdir, length($targdir)-1, 1) ne '/');
	# remove drives, if present
    $fromdir = substr( $fromdir, $colonpos+1 ) if ( ( $colonpos = index( $fromdir, ":" ) ) != -1 );
	$targdir = substr( $targdir, $colonpos+1 ) if ( ( $colonpos = index( $targdir, ":" ) ) != -1 );
	# got the TO and FROM ...
	$frpath = $fromdir;
	$topath = $targdir;
	print "From [$frpath], To [$topath] ...\n" if ($dbg_rel);
	$path = '';
	$posval = 0;
	$retrel = '';
    $frlen = length($frpath);
    $tolen = length($topath);
	# // Step through the paths until a difference is found (ignore slash differences)
	# // or until the end of one is found
	while ( ($posval < $frlen) && ($posval < $tolen) ) {
		if ( substr($topath,$posval,1) eq substr($frpath,$posval,1) ) {
			$posval++; # bump to next
		} else {
			last; # break;
		}
	}
	# // Save the position of the first difference
	$diffpos = $posval;

	# // Check if the directories are the same or
	# // the if target is in a subdirectory of the fromdir
	if ( ( !substr($topath,$posval,1) ) &&
		 ( substr($frpath,$posval,1) eq "/" || !substr($frpath,$posval,1) ) ) {
		# // Build relative path
		$diffpos = length($fromdir);
		if (($posval + 1) < $diffpos) {
			$diffpos-- if ($diffpos);
			if ($diffpos > $posval) {
				$diffpos -= $posval;
			} else {
				$diffpos = 0;
			}
			###$retrel = substr( $fromdir, $posval+1, length( $fromdir ) );
			print "Return substr of target, from ".($posval+1).", for $diffpos length ...\n" if ($dbg_rel);
			$retrel = substr( $fromdir, $posval+1, $diffpos );
		} else {
			print "posval+1 (".($posval+1).") greater than length $diffpos ...\n" if ($dbg_rel);
		}
	} else {
		# // find out how many "../"'s are necessary
		# // Step through the fromdir path, checking for slashes
		# // each slash encountered requires a "../"
		#$posval++;
		while ( substr($topath,$posval,1) ) {
			print "Check for slash ... $posval in $topath\n" if ($dbg_rel);
			if ( substr($topath,$posval,1) eq "/" ) { # || ( substr($topath,$posval,1) eq "\\" ) ) {
				print "Found a slash, add a '../' \n" if ($dbg_rel);
				$path .= "../";
			}
			$posval++;
		}
		print "Path [$path] ...\n" if ($dbg_rel);
		# Search backwards to find where the first common directory
		# as some letters in the first different directory names
		# may have been the same
		$diffpos--;
		$diffpos-- while ( ( substr($frpath,$diffpos,1) ne "/" ) && substr($frpath,$diffpos,1) );
		# Build relative path to return
		$retrel = $path . substr( $fromdir, $diffpos+1, length( $fromdir ) );
    }
	print "Returning [$retrel] ...\n" if ($dbg_rel);
	return $retrel;
}


sub get_rel_dos_path {
	my ($from, $targ) = @_;
	my $rp = get_relative_path($from, $targ);
	$rp = path_u2d($rp);
	return $rp;
}


#########################################

# RENAME A FILE TO .OLD, or .BAK
# 0 - do nothing if file does not exist.
# 1 - rename to .OLD if .OLD does NOT exist
# 2 - rename to .BAK, if .OLD already exists,
# 3 - deleting any previous .BAK ...
sub rename_2_old_bak {
	my ($fil) = shift;
	my $ret = 0;	# assume NO SUCH FILE
	if ( -f $fil ) {	# is there?
		my ($nm,$dir,$ext) = fileparse( $fil, qr/\.[^.]*/ );
		my $nmbo = $dir . $nm . '.old';
		$ret = 1;	# assume renaming to OLD
		if ( -f $nmbo) {	# does OLD exist
			$ret = 2;		# yes - rename to BAK
			$nmbo = $dir . $nm . '.bak';
			if ( -f $nmbo ) {
				$ret = 3;
				unlink $nmbo;
			}
		}
		rename $fil, $nmbo;
	}
	return $ret;
}

sub rename_2_old_bak_plus {
	my ($fil) = shift;
	my $ret = 0;	# assume NO SUCH FILE
	if ( -f $fil ) {	# is there?
		my $nmbo = $fil . '.old';
		$ret = 1;	# assume renaming to OLD
		if ( -f $nmbo) {	# does OLD exist
			$ret = 2;		# yes - rename to BAK
			$nmbo = $fil . '.bak';
			if ( -f $nmbo ) {
				$ret = 3;
				unlink $nmbo;
			}
		}
		rename $fil, $nmbo;
	}
	return $ret;
}

# miscellaneous items
sub add_quotes {
    my ($txt) = shift;
    return '"'.$txt.'"';
}

sub is_in_array {
	my ($itm, @arr) = @_;
	my $max = scalar @arr;
	for (my $k = 0; $k < $max; $k++) {
		if ($arr[$k] eq $itm) {
			return $k + 1;  # return offset plus 1
		}
	}
	return 0;
}

# 20120414 - is_in_array_nc - as above, but case insensitive
sub is_in_array_nc {
	my ($itm, $rarr) = @_;
	my $max = scalar @{$rarr};
    my $lcitm = lc($itm);
    my ($k,$tst,$lctst);
	for ($k = 0; $k < $max; $k++) {
        $tst = ${$rarr}[$k];
        $lctst = lc($tst);
		if ($lctst eq $lcitm) {
			return $k + 1;  # return offset plus 1
		}
	}
	return 0;
}

# 29/10/2008 - The DEFAULT filter is -
# # PROP Default_Filter "cpp;c;cxx;rc;def;r;odl;idl;hpj;bat"
# WHICH INCLUDES A LOT MORE - 20090915 - added '.cc', seen in some unix sources
sub is_c_source {
	my $f = shift;
	return 1 if ( ($f =~ /\.c$/i) || ($f =~ /\.cpp$/i) || ($f =~ /\.cxx$/i) || ($f =~ /\.cc$/i) );
    return 1 if ($f =~ /\.fl$/i);   # 31/05/2010 - add *.fl extent for FLTK project
	return 0;
}

# 2010-07-31 - added .inl
# 2012-04-19 - exclude MSVC10 _mainfest.rc
sub is_c_source_extended {
	my $f = shift;
	if (is_c_source($f) ) {
		return 1;
    } elsif ($f =~ /_manifest\.rc$/i) {
        return 0;
	} elsif ( ($f =~ /\.rc$/i) ||
        ($f =~ /\.def$/i) ||
        ($f =~ /\.odl$/i) ||
        ($f =~ /\.idl$/i) ||
        ($f =~ /\.hpj$/i) ||
        ($f =~ /\.bat$/i) ||
        ($f =~ /\.asm$/i) ||
        ($f =~ /\.nas$/i) ||
        ($f =~ /\.inl$/i) ) {
        return 1;
    }
	return 0;
}

sub is_h_source {
	my $f = shift;
	if ( ($f =~ /\.h$/i) || ($f =~ /\.hpp$/i) || ($f =~ /\.hxx$/i) ) {
		return 1;
	}
	return 0;
}

sub is_h_special {
	my $f = shift;
	if (($f =~ /osg/i)||($f =~ /OpenThreads/i)||($f =~ /Producer/i)) {
		return 1;
	} elsif ($f =~ /\.ipp$/i) {
        return 1;
    }
	return 0;
}

sub is_h_source_extended {
    my ($f) = shift;
    if (is_h_source($f)) {
        return 1;
    } elsif ($f =~ /README/i) {
        return 1;
    } elsif (is_h_special($f)) {
        return 1;
    }
    return 0;
}

sub is_resource_file($) {
    my ($f) = shift;
    my @res_extents = qw( ico cur bmp dlg rc rc2 rct bin rgs gif jpg jpeg jpe wav );
    foreach my $ext (@res_extents) {
        if ($f =~ /\.$ext$/i) {
            return 1;
        }
    }
    return 0;
}

sub is_config_file_like($) {
    my ($f) = shift;
    return 1 if ($f =~ /config\.h/);
    return 0;
}

sub is_text_ext_file($) {
    my ($f) = shift;
    return 1 if ($f =~ /\.txt$/i);
    return 0;
}


sub strip_dotrel {
    my ($txt) = shift;
    $txt =~ s/^\.(\\|\/)//;
    return $txt;
}

# split_space - space_split - 
# like split(/\s/,$txt), but honour double inverted commas
# also accept and split '"something"/>', but ONLY if in the tail
# 2010/05/05 - also want to avoid a tag of '"zlib">'
sub space_split {
	my ($txt) = shift;
	my $len = length($txt);
	my ($k, $ch, $tag, $incomm, $k2, $nch);
	my @arr = ();
	$tag = '';
	$incomm = 0;
	for ($k = 0; $k < $len; $k++) {
		$ch = substr($txt,$k,1);
        $k2 = $k + 1;
        $nch = ($k2 < $len) ? substr($txt,$k2,1) : "";
		if ($incomm) {
			$incomm = 0 if ($ch eq '"');
			$tag .= $ch;
            # add 2010/05/05 to avoid say '"zlib">' begin a tag
            if (!$incomm) {
                push(@arr,$tag);
                $tag = '';
            }
		} elsif ($ch =~ /\s/) { # any spacey char
            push(@arr, $tag) if (length($tag));
			$tag = '';
		} elsif (($ch =~ /\//)&&($nch eq '>')) { # 04/10/2008, but only if before '>' 24/09/2008 add this as well
			push(@arr, $tag) if (length($tag));
			$tag = $ch; # restart tag with this character
		} else {
			$tag .= $ch;
			$incomm = 1 if ($ch eq '"');
		}
	}
	push(@arr, $tag) if (length($tag));
	return @arr;
}

sub space_split_ref($) {
    my $txt = shift;
    my @arr = space_split($txt);
    return \@arr;
}

sub space_split_to_rh($) {
    my ($cur) = shift;
    my @arr = space_split($cur);
    my %h = ();
    foreach my $itm (@arr) {
        $h{$itm} = 1;
    }
    return \%h;
}

# for space_split_to_hash(), space_split_2_hash() - see space_split_to_rh()
sub get_only_new_items($$) {
    my ($cval,$val) = @_;
    my $nval = '';
    my $rh1 = space_split_to_rh($cval);
    my $rh2 = space_split_to_rh($val);
    my ($key);
    foreach $key (keys %{$rh2}) {
        if (! defined ${$rh1}{$key} ) {
            $nval .= ' ' if (length($nval));
            $nval .= $key;
        }
    }
    return $nval;
}

sub array_2_hash_on_equals {
	my (@inarr) = @_;
	my %hash = ();
	my ($itm, @arr, $key, $val, $al, $a, $cnt, $titm);
   $cnt = 0;
	foreach $itm (@inarr) {
      $cnt++;
      $titm = trim_all($itm);
      if (length($titm) == 0) {
         prt( "NOTE: fgutils:array_2_hash_on_equals: Item $cnt has NO length in passed array!\n" );
         next;
      } elsif ($titm eq '=') {
         # 20090912 - lets overlook this = no noise
         ### prt( "NOTE: fgutils:array_2_hash_on_equals: Item $cnt is JUST an equal sign! [$itm]!\n" );
         next;
      }
		@arr = split('=',$itm);
		$al = scalar @arr;
		$key = $arr[0];
		$val = '';
		for ($a = 1; $a < $al; $a++) {
			$val .= '=' if length($val);
			$val .= $arr[$a];
		}
      if (defined $key && length($key)) {
         if (defined $hash{$key}) {
            prtw( "WARNING: array_2_hash_on_equals: Duplicate KEY: [$key] ... ADDING val [$val]\n" );
            $hash{$key} .= "\@".$val;
         } else {
            $hash{$key} = $val;
         }
      } else {
         if (defined $key) {
            prt( "NOTE: fgutils:array_2_hash_on_equals: Item $cnt:$itm: key=[$key] has NO length in passed array!\n" );
         } else {
            prt( "NOTE: fgutils:array_2_hash_on_equals: Item $cnt:$itm: key is NOT set in passed array!\n" );
         }
      }
	}
	return %hash;
}

sub strip_square_braces($) {
    my $txt = shift;
    if ($txt =~ /^\[(.*)\]$/) {
        $txt = $1;
    }
    return $txt;
}

sub strip_double_quotes($) {
    my ($ln) = shift;
	$ln = substr($ln,1,length($ln)-2) if ($ln =~ /^".*"$/);
    return $ln;
}

sub strip_single_quotes($) {
    my ($ln) = shift;
	$ln = substr($ln,1,length($ln)-2) if ($ln =~ /^'.*'$/);
    return $ln;
}


sub strip_both_quotes {
	my ($ln) = shift;
    $ln = strip_double_quotes($ln);
    $ln = strip_single_quotes($ln);
	return $ln;
}

sub strip_quotes {
	my ($ln) = shift;
    return strip_double_quotes($ln);
}

# seems MSVC8, and maybe others, when converting the MSVC6 DSP
# to a VCPORJ file can NOT tollerate a command
# ending in a '\' character, without quotes around it
# #########################################################
sub massage_command {
    my ($txt) = shift;
    if ($txt =~ /\\$/) {
        my ($len, $ch, $bgn, $end);
        # need to back up to previous space,
        # and add quotes around the last command
        $len = length($txt);
        while ($len) {
            $len--;
            $ch = substr($txt,$len,1);
            if ($ch eq ' ') {
                last;
            }
        }
        if ($len) {
            $len++;
            $bgn = substr($txt,0,$len);
            $end = substr($txt,$len);
            $txt = $bgn.add_quotes($end);
        }
    }
    return $txt;
}

#  0    1    2     3     4    5     6     7     8
# ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
# so  if I want the DIR form
#01/10/2008  16:01    <DIR>          SimGear
#16/09/2008  11:38               500 slnlist.txt
sub show_file_stat {
    #use File::stat;
    #use File::Basename;
    my ($fil, $pr) = @_;
    my ($nm,$dr) = fileparse($fil);
    my ($sb, $msg);
    $dr = '' if ($dr eq ".\\");
    if ($sb = stat($fil)) {
        my @lt = localtime($sb->mtime);
        if (-d $fil) {
            $msg = sprintf( "%02d/%02d/%04d %02d:%02d %12s %s %s", $lt[3], $lt[4]+1, $lt[5]+1900,
                $lt[2], $lt[1], "<DIR>", $nm, $dr );
        } else {
            $msg = sprintf( "%02d/%02d/%04d %02d:%02d %12d %s %s", $lt[3], $lt[4]+1, $lt[5]+1900,
                $lt[2], $lt[1], $sb->size, $nm, $dr );
        }
    } else {
        $msg = "FAILED: stat of $nm $dr! $!";
    }
    prt( "$msg\n" ) if $pr;
    return $msg;
}

# only change is to add the 'caller' - for DEBUG - who called this?
sub fix_rel_path3($$) {
	my ($path,$caller) = @_;
	$path = path_u2d($path);	# ENSURE DOS PATH SEPARATOR (in relative.pl)
	my @a = split(/\\/, $path);
	my $npath = '';
	my $max = scalar @a;
	my @na = ();
    my ($pt);
	for (my $i = 0; $i < $max; $i++) {
		my $p = $a[$i];
		if ($p eq '.') {
			# ignore this
		} elsif ($p eq '..') {
			if (@na) {
				pop @na;	# discard previous
			} else {
				prtw( "WARNING:$caller: Got relative .. without previous!!! path=$path\n" );
                prt("Any key to continue ");
                $pt = <>;
			}
		} else {
			push(@na,$p);
		}
	}
	foreach $pt (@na) {
		$npath .= "\\" if length($npath);
		$npath .= $pt;
	}
	return $npath;
}

sub fix_rel_path {
	my ($path) = shift;
	$path = path_u2d($path);	# ENSURE DOS PATH SEPARATOR
	my @a = split(/\\+/, $path);
	my $npath = '';
	my $max = scalar @a;
	my @na = ();
	for (my $i = 0; $i < $max; $i++) {
		my $p = $a[$i];
		if ($p eq '.') {
			# ignore this
		} elsif ($p eq '..') {
			if (@na) {
				pop @na;	# discard previous
			} else {
				prtw( "WARNING: Got relative .. without previous!!! path=$path\n" );
			}
		} else {
			push(@na,$p);
		}
	}
	foreach my $pt (@na) {
		$npath .= "\\" if length($npath);
		$npath .= $pt;
	}
	return $npath;
}

# ADDED 2009/10/25 
sub line_2_hash_on_equals($$) {
    my ($line,$lnn) = @_;
    my @inarr = space_split($line);
    my %hash = ();
	my ($itm, @arr, $key, $val, $al, $a, $cnt, $titm);
    my ($cntkey,$lnkey);
    $cnt = 0;
    $lnkey = sprintf("%07d",$lnn);
	foreach $itm (@inarr) {
        $cnt++;
        $titm = trim_all($itm);
        next if (length($titm) == 0);
        next if ($titm eq '=');
		@arr = split('=',$titm);
		$al = scalar @arr;
		$key = $arr[0];
		$val = '';
		for ($a = 1; $a < $al; $a++) {
			$val .= '=' if length($val);
			$val .= $arr[$a];
		}
        $cntkey = sprintf("%07d",$cnt);
        if (defined $key && length($key)) {
            $cntkey = "$lnkey-$cntkey-$key";
            if (defined $hash{$cntkey}) {
                prtw( "WARNING: array_2_hash_on_equals: Duplicate KEY: [$key] ... ADDING val [$val]\n" );
                $hash{$cntkey} .= "\@".$val;
            } else {
                $hash{$cntkey} = $val;
            }
        } else {
            prtw( "ERROR: KEY NOT DEFINED, OR NO LENGTH!\n" );
            exit(1);
        }
	}
	return \%hash;
}

sub get_vs_vars_bat() {
    # 15/04/2012 - Add VC10 in WIn7-PC
    my $bfil = 'C:\Program Files (x86)\Microsoft Visual Studio 10.0\VC\vcvarsall.bat';
    return $bfil if (-f $bfil);
    $bfil = 'C:\Program Files\Microsoft Visual Studio 10.0\VC\vcvarsall.bat';
    return $bfil if (-f $bfil);
    $bfil = 'C:\Program Files\Microsoft Visual Studio 9.0\VC\vcvarsall.bat';
    return $bfil if (-f $bfil);
    $bfil = 'C:\Program Files\Microsoft Visual Studio 8\VC\vcvarsall.bat';
    return $bfil if (-f $bfil);
    # MSVC 7.1
    # $bfil = 'C:\Program Files\Microsoft Visual Studio .NET 2003\Vc7\bin\vsvars32.bat';
    $bfil = 'C:\Program Files\Microsoft Visual Studio .NET 2003\Common7\Tools\vsvars32.bat';
    return $bfil if (-f $bfil);
    $bfil = 'C:\Program Files\Microsoft Visual Studio 9.0\VC\vcvarsall.bat';
    return $bfil if (-f $bfil);
    prtw("WARNING: No known vcvarsall.bat file found! Check location, and FIX\n".
        "this lib_utils.pl script with location. See get_vs_vars_bat sub.\n");
    $bfil = '';
    return $bfil;
}

sub get_vs_install_dir($) {
    my ($rs) = @_;
    if ( length($vs_install_directory) ) {
        ${$rs} = $vs_install_directory;
        return 1;
    }
    my $bfil = get_vs_vars_bat();   ## like 'C:\Program Files\Microsoft Visual Studio 9.0\VC\vcvarsall.bat';
    return 0 if (length($bfil) == 0);
    my $fil = 'tempvc.txt';
    my $bat = 'tempvc.bat';
    my $iret = 0;
    unlink $fil if (-f $fil);
    if (-f $bfil) {
        my $msg = '@call "'.$bfil.'" x86 >nul'."\n";
        $msg .= "\@echo \%VSINSTALLDIR\% >$fil\n";
        # $(WindowsSdkDir)\include
        #$msg .= "\@echo WindowsSdkDir=\%WindowsSdkDir\% >>$fil\n";
        # $(FrameworkSDKDir)include
        #$msg .= "\@echo FrameworkSDKDir=\%FrameworkSDKDir\% >>$fil\n";
        # C:\Program Files\Microsoft DirectX SDK (March 2008)\Include
        # ALL INCLUDE items
        #$msg .= "\@echo INCLUDE=\%INCLUDE\% >>$fil\n";
        write2file($msg,$bat);
        system($bat);   # run the BATCH file, in the MSVC environment
        if (open INF, "<$fil") {
            my @arr = <INF>;
            close INF;
            my $tmp = $arr[0];
            chomp $tmp;
            $tmp = substr($tmp,0,length($tmp)-1) while ($tmp =~ /\s$/);
            ${$rs} = $tmp;
            $vs_install_directory = $tmp;
            # prt("lib_utils::get_vs_install_dir: Set VS INSTALL to [$vs_install_directory]\n");
            $iret = 1;
        } else {
            prtw("ERROR: Failed to open [$fil]!!!\n");
        }
    } else {
        prtw( "ERROR:lib_utils: Failed to find [$bfil]!\n" );
    }
    unlink $fil if (-f $fil);
    unlink $bat if (-f $bat);
    return $iret;
}

# add to a files HASH, all lower case
sub add_to_files_lc($$) {
    my ($fil,$rh) = @_;
    my $lcfil = lc($fil);
    $lcfil = path_u2d($lcfil);
    $lcfil =~ s/\\\\/\\/g while ($lcfil =~ /\\\\/);
    $lcfil = fix_rel_path($lcfil) if ($lcfil =~ /^\w{1}:/);
    $lcfil =~ s/\\\\/\\/g while ($lcfil =~ /\\\\/);
    return 1 if (defined ${$rh}{$lcfil});
    ${$rh}{$lcfil} = $fil;
    return 0;
}

my @msvc_dirs = ();
my $done_vc_dirs = 0;

sub vc_get_include_dirs2($$) {
    my ($rs,$dbg) = @_;
    my ($tmp);
    my @dirs = ();
    if ($done_vc_dirs) {
       $tmp = scalar @msvc_dirs;
       ${$rs} = [ @msvc_dirs ];
       if (($dbg & 0x400) && ($done_vc_dirs == 1)) {
           prt("[x400] vc_get_include_dirs2: return $tmp dirs...\n" );
           foreach $tmp (@msvc_dirs) {
               prt(" [$tmp]\n");
           }
       }
       $done_vc_dirs++;
       return $tmp;
    }
    my $bfil = get_vs_vars_bat();   ## like 'C:\Program Files\Microsoft Visual Studio 9.0\VC\vcvarsall.bat';
    return 0 if (length($bfil) == 0);
    my $fil = 'tempvc.txt';
    my $bat = 'tempvc.bat';
    my $iret = 0;
    my $dbg_f14 = ($dbg & 1) ? 1 : 0;
    my $dbg_f15 = ($dbg & 2) ? 1 : 0;
    my $dbg_f16 = ($dbg & 4) ? 1 : 0;
    my $dbg_f17 = ($dbg & 8) ? 1 : 0;
    my $dbg_f18 = ($dbg & 16) ? 1 : 0;
    my $dbg_f19 = ($dbg & 32) ? 1 : 0;
    my $dbg_f20 = ($dbg & 64) ? 1 : 0;
    my $dbg_f21 = ($dbg & 128) ? 1 : 0;
    my $dbg_f22 = ($dbg & 256) ? 1 : 0;
    my $dbg_f23 = ($dbg & 0x200) ? 1 : 0;
    unlink $fil if (-f $fil);
    unlink $bat if (-f $bat);
    my %d_added = ();
    my $rda = \%d_added;
    if (-f $bfil) {
        my $msg = '@call "'.$bfil.'" x86 >nul'."\n";
        $msg .= "\@echo VSINSTALLDIR=\%VSINSTALLDIR\% >$fil\n";
        # $(WindowsSdkDir)\include
        $msg .= "\@echo WindowsSdkDir=\%WindowsSdkDir\% >>$fil\n";
        # $(FrameworkSDKDir)include
        $msg .= "\@echo FrameworkSDKDir=\%FrameworkSDKDir\% >>$fil\n";
        # C:\Program Files\Microsoft DirectX SDK (March 2008)\Include
        # maybe HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment
        # DXSDK_DIR=C:\Program Files\Microsoft DirectX SDK (March 2008)\ so...
        $msg .= "\@echo DXSDK_DIR=\%DXSDK_DIR\% >>$fil\n";
        # ALL INCLUDE items
        $msg .= "\@echo INCLUDE=\%INCLUDE\% >>$fil\n";
        write2file($msg,$bat);
        system($bat);   # run it
        my ($ln,@arr,$var,$val,@arr2,$d2,$lnn);
        if (open INF, "<$fil") {
            @arr = <INF>;
            close INF;
            @dirs = ();
            $tmp = scalar @arr;
            prt( "[f14] Got $tmp lines, from $fil...\n" ) if ($dbg_f14);
            $lnn = 0;
            foreach $ln (@arr) {
                chomp $ln;
                $ln = substr($ln,0,length($ln)-1) while ($ln =~ /\s$/);
                $lnn++;
                prt( "[f15] $lnn: $ln\n" ) if ($dbg_f15);
                if ($ln =~ /(\w+)=(.+)/) {
                    $var = $1;
                    $val = $2;
                    prt( "[f15] $lnn: $var=$val\n" ) if ($dbg_f15);
                    if ($var eq 'INCLUDE') {
                        @arr2 = split(";",$val);
                        $tmp = scalar @arr2;
                        # prt( "Got $tmp INCLUDE items...\n" );
                        foreach $d2 (@arr2) {
                            if (-d $d2) {
                                if (add_to_files_lc($d2,$rda)) {
                                    prt("[f17] Folder [$d2] already in list.\n") if ($dbg_f17);
                                } else {
                                    push(@dirs,$d2);
                                    prt("[f16] Added folder [$d2] $var\n") if ($dbg_f16);
                                }
                            } else {
                                prt("NOTE: Can NOT locate folder [$d2] $var\n");
                            }
                        }
                    } elsif ($var eq 'VSINSTALLDIR') {
                        $d2 = "$val";
                        $d2 .= "\\" if (!($d2 =~ /(\\|\/)$/));
                        $d2 .= "VC\\include";
                        if (-d $d2) {
                            if (add_to_files_lc($d2,$rda)) {
                                prt("[f17] Folder [$d2] already in list.\n") if ($dbg_f17);
                            } else {
                                push(@dirs,$d2);
                                prt("[f16] Added folder [$d2] $var=$val\n") if ($dbg_f16);
                            }
                        } else {
                            prt("NOTE: Can NOT locate folder [$d2] $var=$val\n");
                        }
                    } elsif ($var eq 'WindowsSdkDir') {
                        $d2 = "$val";
                        $d2 .= "\\" if (!($d2 =~ /(\\|\/)$/));
                        $d2 .= "include";
                        if (-d $d2) {
                            if (add_to_files_lc($d2,$rda)) {
                                prt("[f17] Folder [$d2] already in list.\n") if ($dbg_f17);
                            } else {
                                push(@dirs,$d2);
                                prt("[f16] Added folder [$d2] $var=$val\n") if ($dbg_f16);
                            }
                        } else {
                            prt("[f19] NOTE: Can NOT locate folder [$d2] $var=$val\n") if ($dbg_f19);
                        }
                    } elsif ($var eq 'FrameworkSDKDir') {
                        $d2 = "$val";
                        $d2 .= "\\" if (!($d2 =~ /(\\|\/)$/));
                        $d2 .= "include";
                        if (-d $d2) {
                            if (add_to_files_lc($d2,$rda)) {
                                prt("[f17] Folder [$d2] already in list.\n") if ($dbg_f17);
                            } else {
                                push(@dirs,$d2);
                                prt("[f16] Added folder [$d2] $var=$val\n") if ($dbg_f16);
                            }
                        } else {
                            prt("[f19] NOTE: Can NOT locate folder [$d2] $var=$val\n") if ($dbg_f19);
                        }
                    } elsif ($var eq 'DXSDK_DIR') {
                        $d2 = "$val";
                        $d2 .= "\\" if (!($d2 =~ /(\\|\/)$/));
                        $d2 .= "include";
                        if (-d $d2) {
                            if (add_to_files_lc($d2,$rda)) {
                                prt("[f17] Folder [$d2] already in list.\n") if ($dbg_f17);
                            } else {
                                push(@dirs,$d2);
                                prt("[f16] Added folder [$d2] $var=$val\n") if ($dbg_f16);
                            }
                        } else {
                            prt("[f19] NOTE: Can NOT locate folder [$d2] $var=$val\n") if ($dbg_f19);
                        }
                    }
                } else {
                    prt("[f18] NOTE: Line [$ln] skipped\n") if ($dbg_f18);
                }
            }
            $tmp = scalar @dirs;
            if ($dbg_f23) {
                prt("[x200] vc_get_include_dirs2: return $tmp dirs...\n" );
                foreach $tmp (@dirs) {
                    prt(" $tmp\n");
                }
            }
            ${$rs} = [ @dirs ];
            $iret = 1;
        } else {
            prtw("ERROR: Failed to open [$fil]!!!\n");
        }
    } else {
        prtw( "ERROR: Failed to find [$bfil]!\n" );
    }
    if ($dbg_f22) {
        prt("[f22] NOTE: maybe left [$fil] and [$bat] in local directory!\n") if ($dbg_f22);
    } else {
        unlink $fil if (-f $fil);
        unlink $bat if (-f $bat);
    }
    push(@msvc_dirs,@dirs);
    $done_vc_dirs = 1;
    return $iret;
}

sub get_string_with_sep($$) {
    my ($sep, $txt) = @_;
    my @av = split(/[,;]/, $txt);
    my $ref = '';
    foreach my $tx (@av) {
        $tx = substr($tx,1) if ($tx =~ /^\s/);
        if (length($tx)) {
            $ref .= ' ' if length($ref);
            # remove any existing quotes, but add quotes for sure
            $ref .= $sep.add_quotes(strip_quotes($tx));
        }
    }
    return $ref;
}

sub get_includes_string($) {
    my ($txt) = shift;
    return get_string_with_sep('/I ', $txt);
}

sub get_defines_string($) {
    my ($txt) = shift;
    # watch out for 
    # [PreprocessorDefinitions=
    # "WIN32;_DEBUG;_CONSOLE;NOMINMAX;_CRT_SECURE_NO_WARNINGS;
    # DEFAULT_USGS_MAPFILE=\&quot;usgsmap.txt\&quot;;DEFAULT_PRIORITIES_FILE=\&quot;default_priorities.txt\&quot;"]
    $txt =~ s/\\\&quot;/\\"/g;
    return get_string_with_sep('/D ', $txt);
}

sub get_libpaths_string($) {
    my ($txt) = shift;
    return get_string_with_sep('/libpath:', $txt);
}

sub get_nn($) { # perl nice number nicenum nice_n - add commas
	my ($n) = shift;
	if (length($n) > 3) {
		my $mod = length($n) % 3;
		my $ret = (($mod > 0) ? substr( $n, 0, $mod ) : '');
		my $mx = int( length($n) / 3 );
		for (my $i = 0; $i < $mx; $i++ ) {
			if (($mod == 0) && ($i == 0)) {
				$ret .= substr( $n, ($mod+(3*$i)), 3 );
			} else {
				$ret .= ',' . substr( $n, ($mod+(3*$i)), 3 );
			}
		}
		return $ret;
	}
	return $n;
}

sub secs_HHMMSS($) {
    my ($secs) = @_;
    if ($secs < 60) {
        #$secs = "0$secs" if ($secs < 10);
        return "$secs secs";
    }
    my ($mins,$hour);
    if ($secs < 3600) {
        $mins = int($secs / 60);
        $secs = $secs - ($mins * 60);
        #$mins = "0$mins" if ($mins < 10);
        $secs = "0$secs" if ($secs < 10);
        return "$mins:$secs min:secs";
    }
    $mins = int($secs / 60);
    $secs = $secs - ($mins * 60);
    $hour = int($mins / 60);
    $mins = $mins - ($hour * 60);
    #$hour = "0$hour" if ($hour < 10);
    $mins = "0$mins" if ($mins < 10);
    $secs = "0$secs" if ($secs < 10);
    return "$hour:$mins:$secs hrs:min:secs";
}

sub get_YYYYMMDD($) {
    my ($t) = shift;
    my @f = (localtime($t))[0..5];
    my $m = sprintf( "%04d/%02d/%02d",
        $f[5] + 1900, $f[4] +1, $f[3]);
    return $m;
}

sub lu_get_YYYYMMDD_hhmmss {
    my ($t) = shift;
    my @f = (localtime($t))[0..5];
    my $m = sprintf( "%04d/%02d/%02d %02d:%02d:%02d",
        $f[5] + 1900, $f[4] +1, $f[3], $f[2], $f[1], $f[0]);
    return $m;
}

sub lu_get_YYYYMMDD_hhmmss_UTC {
    my ($t) = shift;
    # sec, min, hour, mday, mon, year, wday, yday, and isdst.
    my $tm = gmtime($t);
    my $m = sprintf( "%04d/%02d/%02d %02d:%02d:%02d",
        $tm->year() + 1900, $tm->mon() + 1, $tm->mday(), $tm->hour(), $tm->min(), $tm->sec());
    return $m;
}

sub lu_get_hhmmss_UTC {
    my ($t) = shift;
    # sec, min, hour, mday, mon, year, wday, yday, and isdst.
    my $tm = gmtime($t);
    my $m = sprintf( "%02d:%02d:%02d",
        $tm->hour(), $tm->min(), $tm->sec());
    return $m;
}

#string dirghtml::b2ks1(double d) // b2ks1(double d)
sub util_bytes2ks($) {
	my ($d) = @_;
	my $oss;
	my $kss;
	my $lg = 0;
	my $ks = ($d / 1024); #// get Ks
	my $div = 1;
   if( $ks < 1024 ) {
      $div = 1;
      $oss = "KB";
   } elsif ( $ks < (1024 * 1024) ) {
	  $div = 1024;
      $oss = "MB";
   } elsif ( $ks < (1024 * 1024 * 1024) ) {
      $div = (1024 * 1024);
      $oss = "GB";
   } else {
      $div = (1024 * 1024 * 1024);
      $oss = "TB";
   }
   $kss = $ks / $div;
   $kss += 0.05;
   $kss *= 10;
   $lg = int($kss);
   return( ($lg / 10) . $oss );
}

sub ut_fix_directory($) {
    my $rd = shift;
    if (length($rd) && (!(${$rd} =~ /(\\|\/)$/))) {
        ${$rd} .= $PATH_SEP;
    }
}

sub ut_fix_rpath_per_os($) {
    my $rff = shift;
    my $ff = ${$rff};
    $ff = ($os =~ /win/i) ? path_u2d($ff) : path_d2u($ff);
    ${$rff} = $ff;
}

sub ut_fix_dir_string($) {
    my ($rdir) = @_;
    if (! ( ${$rdir} =~ /(\\|\/)$/) ) {
        ${$rdir} .= $PATH_SEP;
    }
}


1;
# eof - lib_utils.pl
