#!/usr/bin/perl
# NAME: xp2json.pl
# AIM: Like xp2csv.pl, this accepts ONE airport ICAO, read X-Plane (Robin Pell) earth_nav.dat 
# and apt.dat, searching that ICAO, and if found output as ICAO.json 
# 16/11/2013 - Allow a LIST of ICAO
# 11/11/2013 geoff mclane http://geoffair.net/mperl
use strict;
use warnings;
use File::Copy;
use Math::Trig;
use Time::HiRes qw( gettimeofday tv_interval );
my $os = $^O;
my $perl_dir = $0;  # '/home/geoff/bin';
$perl_dir =~ s/xp2json\.pl$//;
$perl_dir = '.' if (length($perl_dir) == 0);
##my $perl_dir = '/home/geoff/bin';
my $PATH_SEP = '/';
my $temp_dir = '/tmp';
if ($os =~ /win/i) {
    #$perl_dir = 'C:\GTools\perl';
    $temp_dir = $perl_dir;
    $PATH_SEP = "\\";
}
unshift(@INC, $perl_dir);
require 'lib_utils.pl' or die "Unable to load 'lib_utils.pl' Check paths in \@INC...\n";
require 'fg_wsg84.pl' or die "Unable to load fg_wsg84.pl ...\n";
#require "Bucket2.pm" or die "Unable to load Bucket2.pm ...\n";
require "Bucket.pm" or die "Unable to load Bucket.pm ...\n";

# =============================================================================
# This NEEDS to be adjusted to YOUR particular default location of these files.
my ($FGROOT);
if ($os =~ /win/i) {
    $FGROOT = "D:/FG/xplane/1000";
} else {
    $FGROOT = '/media/Disk2/xplane/1000';
}
###my $FGROOT = "D:/SAVES/xplane";
my $APT_FILE 	= "$FGROOT/apt.dat";	# the airports data file
###my $APT_FILE   = "$FGROOT/apt4.dat";	# the airports data file
my $NAV_FILE 	= "$FGROOT/earth_nav.dat";	# the NAV, NDB, etc. data file
my $FIX_FILE    = "$FGROOT/earth_fix.dat";	# the FIX data file
my $LIC_FILE    = "$FGROOT/AptNavGNULicence.txt";
# =============================================================================

my $VERS = "0.0.7 20131207";
###my $VERS = "0.0.6 20131116";
###my $VERS = "0.0.5 20131111";

# log file stuff
our ($LF);
my $pgmname = $0;
if ($pgmname =~ /(\\|\/)/) {
    my @tmpsp = split(/(\\|\/)/,$pgmname);
    $pgmname = $tmpsp[-1];
}
my $outfile = $temp_dir.$PATH_SEP."temp.$pgmname.txt";
open_log($outfile);

my $t0 = [gettimeofday];

my $out_path = '';
my $add_navaids_array = 0;
my $add_ils_array = 0;

#my $dout_path = $temp_dir.$PATH_SEP."temp-apts6";
#my $dout_path = $temp_dir.$PATH_SEP."temp-apts5";
#my $dout_path = $temp_dir.$PATH_SEP."temp-apts4";
#my $dout_path = 'C:\FG\17\fgx-globe\apt1000';
#my $dout_path = $temp_dir.$PATH_SEP."temp-apts2";
my $debug_on = 0;
my $dout_path = $temp_dir.$PATH_SEP."temp-apts";
my $def_icao = 'KSFO';

# program variables - set during running
# different searches -icao=LFPO, -latlon=1,2, or -name="airport name"
# KSFO San Francisco Intl (37.6208607739872,-122.381074803838)
my $aptdat = $APT_FILE;
my $navdat = $NAV_FILE;
my $licfil = $LIC_FILE;
my $fixdat = $FIX_FILE;
my $out_base = 'apt1000';
my $navdat2 = $temp_dir.$PATH_SEP."nav.dat";

# features and options
my $load_log = 0;
my $write_output = 1;   # write the CSV file
my $add_newline = 1;    # make json human readable
my $skip_done_files = 1; # do not overwrite previous json file

my $output_full_list = 1; # output ALL airports to ICAO.json
my $do_nav_filter = 1;
my $out_all_json = 1;

my %icaos_to_find = ();
my @find_icaos = ();

# variables for range using distance calculation
my $PI = 3.1415926535897932384626433832795029;
my $D2R = $PI / 180;
my $R2D = 180 / $PI;
my $ERAD = 6378138.12;
my $DIST_FACTOR = $ERAD;
#/** Meters to Nautical Miles.  1 nm = 6076.11549 feet */
my $METER_TO_NM = 0.0005399568034557235;
#/** Nautical Miles to Meters */
my $NM_TO_METER = 1852;

my ($file_version);

my $av_apt_lat = 0;	# later will be $tlat / $ac;
my $av_apt_lon = 0; # later $tlon / $ac;

# apt.dat CODES - see http://x-plane.org/home/robinp/Apt850.htm for DETAILS
#my $aln =     '1';	# airport line
#my $rln =    '10';	# runways/taxiways line 810 OLD CODE
#my $sealn =  '16'; # Seaplane base header data.
#my $heliln = '17'; # Heliport header data.  

#my $rln =    '100';	# land runways
#my $water =  '101'; # Water runway
#my $heli =   '102'; # Helipad

# offsets into land runway array
#my $of_lat1 = 9;
#my $of_lon1 = 10;
#my $of_lat2 = 18;
#my $of_lon2 = 19;

my $twrln =  '14'; # Tower view location. 
my $rampln = '15'; # Ramp startup position(s) 
my $bcnln =  '18'; # Airport light beacons  
my $wsln =   '19'; # windsock
my $minatc = '50';
my $twrfrq = '54';	# like 12210 TWR
my $appfrq = '55';  # like 11970 ROTTERDAM APP
my $maxatc = '56';
my $lastln = '99'; # end of file

# nav.dat.gz CODES
my $navNDB = '2';
my $navVOR = '3';
my $navILS = '4';
my $navLOC = '5';
my $navGS  = '6';
my $navOM  = '7';
my $navMM  = '8';
my $navIM  = '9';
my $navVDME = '12';
my $navNDME = '13';
my @navset = ($navNDB, $navVOR, $navILS, $navLOC, $navGS, $navOM, $navMM, $navIM, $navVDME, $navNDME);
my @navtypes = qw( NDB VOR ILS LOC GS OM NM IM VDME NDME );

my $maxnnlen = 4;
my $actnav = '';
my $line = '';
my $apt = '';
my $alat = 0;
my $alon = 0;
my $glat = 0;
my $glon = 0;
my $rlat = 0;
my $rlon = 0;
my $dlat = 0;
my $dlon = 0;
my $diff = 0;
my $rwycnt = 0;
my $icao = '';
my $name = '';
my @aptlist = ();
my @aptlist2 = ();
my @navlist = ();
my @navlist2 = ();
my $totaptcnt = 0;
my $acnt = 0;
my @lines = ();
my $cnt = 0;
my $loadlog = 0;
my $outcount = 0;
my @tilelist = ();

my @warnings = ();

my @files_written = ();
my $json_count = 0;
my $json_bytes = 0;

# debug tests
# ===================
# debug
my $dbg1 = 0;	# show airport during finding ...
my $dbg2 = 0;	# show navaid during finding ...
my $dbg3 = 0;	# show count after finding
my $verb3 = 0;
my $dbg10 = 0;  # show EVERY airport
my $dbg11 = 0;  # prt( "$name $icao runways $rwycnt\n" ) if ($dbg11);
# ===================

### program variables
my $verbosity = 0;

sub VERB1() { return $verbosity >= 1; }
sub VERB2() { return $verbosity >= 2; }
sub VERB5() { return $verbosity >= 5; }
sub VERB9() { return $verbosity >= 9; }

sub show_warnings($) {
    my ($val) = @_;
    if (@warnings) {
        prt( "\nGot ".scalar @warnings." WARNINGS...\n" );
        foreach my $itm (@warnings) {
           prt("$itm\n");
        }
        prt("\n");
    } else {
        prt( "\nNo warnings issued.\n\n" ) if (VERB9());
    }
}

sub pgm_exit($$) {
    my ($val,$msg) = @_;
    if (length($msg)) {
        $msg .= "\n" if (!($msg =~ /\n$/));
        prt($msg);
    }
    show_warnings($val);
    close_log($outfile,$load_log);
    exit($val);
}


sub prtw($) {
   my ($tx) = shift;
   $tx =~ s/\n$//;
   prt("$tx\n");
   push(@warnings,$tx);
}


########################################################################
### SUBS
#/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  */
#/* Vincenty Inverse Solution of Geodesics on the Ellipsoid (c) Chris Veness 2002-2012             */
#/*                                                                                                */
#/* from: Vincenty inverse formula - T Vincenty, "Direct and Inverse Solutions of Geodesics on the */
#/*       Ellipsoid with application of nested equations", Survey Review, vol XXII no 176, 1975    */
#/*       http://www.ngs.noaa.gov/PUBS_LIB/inverse.pdf                                             */
#/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  */
#
#/**
# * Calculates geodetic distance between two points specified by latitude/longitude using 
# * Vincenty inverse formula for ellipsoids
# *
# * @param   {Number} lat1, lon1: first point in decimal degrees
# * @param   {Number} lat2, lon2: second point in decimal degrees
# * @returns (Number} distance in metres between points
# */
use constant PI    => 4 * atan2(1, 1);

my $FG_PI = PI;
my $FG_D2R = $FG_PI / 180;
my $FG_R2D = 180 / $FG_PI;
my $FG_MIN = 2.22507e-308;
my $NaN = -sin(9**9**9);
sub toRad($) {
    my $deg = shift;
    return ($deg * $FG_D2R);
}
sub toDeg($) {
    my $rad = shift;
    return ($rad * $FG_R2D);
}

sub isNaN { ! defined( $_[0] <=> 9**9**9 ) }
# function distVincenty(lat1, lon1, lat2, lon2) {
sub distVincenty($$$$$$$) {
    my ($lat1, $lon1, $lat2, $lon2, $raz1, $raz2, $rs) = @_;
    my $a = 6378137;
    my $b = 6356752.314245;
    my $f = 1/298.257223563;  #// WGS-84 ellipsoid params
    my $L = toRad($lon2-$lon1); #.toRad();
    my $U1 = atan((1-$f) * tan(toRad($lat1)));
    my $U2 = atan((1-$f) * tan(toRad($lat2)));
    my $sinU1 = sin($U1);
    my $cosU1 = cos($U1);
    my $sinU2 = sin($U2);
    my $cosU2 = cos($U2);
    my $lambda = $L;
    my ($lambdaP);
    my $iterLimit = 100;
    my ($sinLambda,$cosLambda,$sinSigma,$cosSigma,$sigma);
    my ($sinAlpha,$cosSqAlpha,$cos2SigmaM,$C);
    do {

        $sinLambda = sin($lambda);
        $cosLambda = cos($lambda);
        $sinSigma = sqrt(($cosU2*$sinLambda) * ($cosU2*$sinLambda) + 
            ($cosU1*$sinU2-$sinU1*$cosU2*$cosLambda) * ($cosU1*$sinU2-$sinU1*$cosU2*$cosLambda));
        if ($sinSigma==0) { return 0; } # co-incident points
        $cosSigma = $sinU1*$sinU2 + $cosU1*$cosU2*$cosLambda;
        $sigma = atan2($sinSigma, $cosSigma);
        $sinAlpha = $cosU1 * $cosU2 * $sinLambda / $sinSigma;
        $cosSqAlpha = 1 - $sinAlpha*$sinAlpha;
        $cos2SigmaM = $cosSigma - 2*$sinU1*$sinU2/$cosSqAlpha;
        if (isNaN($cos2SigmaM)) { $cos2SigmaM = 0; } #// equatorial line: cosSqAlpha=0 (A76)
        $C = $f/16*$cosSqAlpha*(4+$f*(4-3*$cosSqAlpha));
        $lambdaP = $lambda;
        $lambda = $L + (1-$C) * $f * $sinAlpha *
            ($sigma + $C*$sinSigma*($cos2SigmaM+$C*$cosSigma*(-1+2*$cos2SigmaM*$cos2SigmaM)));

    } while (abs($lambda-$lambdaP) > 1e-12 && --$iterLimit>0);

    if ($iterLimit==0) { 
        prt("formula failed to converge!\n");
        return 1; # $NaN; #// formula failed to converge
    }
    my $uSq = $cosSqAlpha * ($a*$a - $b*$b) / ($b*$b);
    my $A = 1 + $uSq/16384*(4096+$uSq*(-768+$uSq*(320-175*$uSq)));
    my $B = $uSq/1024 * (256+$uSq*(-128+$uSq*(74-47*$uSq)));
    my $deltaSigma = $B*$sinSigma*($cos2SigmaM+$B/4*($cosSigma*(-1+2*$cos2SigmaM*$cos2SigmaM)-
        $B/6*$cos2SigmaM*(-3+4*$sinSigma*$sinSigma)*(-3+4*$cos2SigmaM*$cos2SigmaM)));
    my $s = $b*$A*($sigma-$deltaSigma);
  
    #  // note: to return initial/final bearings in addition to distance, use something like:
    my $fwdAz = atan2($cosU2*$sinLambda,  $cosU1*$sinU2-$sinU1*$cosU2*$cosLambda);
    my $revAz = atan2($cosU1*$sinLambda, -$sinU1*$cosU2+$cosU1*$sinU2*$cosLambda);
    # return { distance: s, initialBearing: fwdAz.toDeg(), finalBearing: revAz.toDeg() };
    ${$raz1} = toDeg($fwdAz);
    ${$raz2} = toDeg($revAz);
    # s = s.toFixed(3); // round to 1mm precision
    ${$rs} = (int($s * 1000) / 1000);
    return 0;
}

sub trimall($) {	# version 20061127
	my ($ln) = shift;
	chomp $ln;			# remove CR (\n)
	$ln =~ s/\r$//;		# remove LF (\r)
	$ln =~ s/\t/ /g;	# TAB(s) to a SPACE
	$ln =~ s/\s\s/ /g while ($ln =~ /\s\s/); # all double space to SINGLE
	$ln = substr($ln,1) while ($ln =~ /^\s/); # remove all LEADING space
	$ln = substr($ln,0, length($ln) - 1) while ($ln =~ /\s$/); # remove all TRAILING space
	return $ln;
}


sub get_tile { # $alon, $alat
	my ($lon, $lat) = @_;
	my $tile = 'e';
	if ($lon < 0) {
		$tile = 'w';
		$lon = -$lon;
	}
	my $ilon = int($lon / 10) * 10;
	if ($ilon < 10) {
		$tile .= "00$ilon";
	} elsif ($ilon < 100) {
		$tile .= "0$ilon";
	} else {
		$tile .= "$ilon"
	}
	if ($lat < 0) {
		$tile .= 's';
		$lat = -$lat;
	} else {
		$tile .= 'n';
	}
	my $ilat = int($lat / 10) * 10;
	if ($ilat < 10) {
		$tile .= "0$ilat";
	} elsif ($ilon < 100) {
		$tile .= "$ilat";
	} else {
		$tile .= "$ilat"
	}
	return $tile;
}

sub add_2_tiles {	# $tile
	my ($tl) = shift;
	if (@tilelist) {
		foreach my $t (@tilelist) {
			if ($t eq $tl) {
				return 0;
			}
		}
	}
	push(@tilelist, $tl);
	return 1;
}

sub is_valid_nav {
	my ($t) = shift;
    if ($t && length($t)) {
        my $txt = "$t";
        my $cnt = 0;
        foreach my $n (@navset) {
            $cnt++;
            if ($n eq $txt) {
                $actnav = $navtypes[$cnt];
                return $cnt;
            }
        }
    }
	return 0;
}

sub set_average_apt_latlon {
	my $ac = scalar @aptlist2;
	my $tlat = 0;
	my $tlon = 0;
	if ($ac) {
		for (my $i = 0; $i < $ac; $i++ ) {
			$alat = $aptlist2[$i][3];
			$alon = $aptlist2[$i][4];
			$tlat += $alat;
			$tlon += $alon;
		}
		$av_apt_lat = $tlat / $ac;
		$av_apt_lon = $tlon / $ac;
	}
}



sub set_apt_version($$) {
    my ($ra,$cnt) = @_;
    if ($cnt < 5) {
        prt("ERROR: Insufficient lines to be an apt.dat file!\n");
        exit(1);
    }
    my $line = trimall(${$ra}[0]);
    if ($line ne 'I') {
        prt("ERROR: File does NOT begin with an 'I'!\n");
        exit(1);
    }
    $line = trimall(${$ra}[1]);
    if ($line =~ /^(\d+)\s+Version\s+/i) {
        $file_version = $1;
        prt("Dealing with file version [$file_version]\n");
    } else {
        prt("ERROR: File does NOT begin with Version info!\n");
        exit(1);

    }
}

# sort by type
sub mycmp_ascend_n0 {
   return -1 if (${$a}[0] < ${$b}[0]);
   return  1 if (${$a}[0] > ${$b}[0]);
   return 0;
}


# sort by ICAO text
sub mycmp_ascend_t1 {
   return -1 if (${$a}[1] lt ${$b}[1]);
   return  1 if (${$a}[1] gt ${$b}[1]);
   return 0;
}

# sort by distance
sub mycmp_ascend_n1 {
   return -1 if (${$a}[1] < ${$b}[1]);
   return  1 if (${$a}[1] > ${$b}[1]);
   return 0;
}


# put least first
sub mycmp_ascend_n4 {
   if (${$a}[4] < ${$b}[4]) {
      return -1;
   }
   if (${$a}[4] > ${$b}[4]) {
      return 1;
   }
   return 0;
}

sub mycmp_ascend_n5 {
   if (${$a}[5] < ${$b}[5]) {
      return -1;
   }
   if (${$a}[5] > ${$b}[5]) {
      return 1;
   }
   return 0;
}

sub mycmp_ascend_n6 {
   if (${$a}[6] < ${$b}[6]) {
      return -1;
   }
   if (${$a}[6] > ${$b}[6]) {
      return 1;
   }
   return 0;
}

# put least first
sub mycmp_ascend {
   if (${$a}[0] < ${$b}[0]) {
      prt( "-[".${$a}[0]."] < [".${$b}[0]."]\n" ) if $verb3;
      return -1;
   }
   if (${$a}[0] > ${$b}[0]) {
      prt( "+[".${$a}[0]."] < [".${$b}[0]."]\n" ) if $verb3;
      return 1;
   }
   prt( "=[".${$a}[0]."] == [".${$b}[0]."]\n" ) if $verb3;
   return 0;
}

sub mycmp_decend {
   if (${$a}[0] < ${$b}[0]) {
      prt( "+[".${$a}[0]."] < [".${$b}[0]."]\n" ) if $verb3;
      return 1;
   }
   if (${$a}[0] > ${$b}[0]) {
      prt( "-[".${$a}[0]."] < [".${$b}[0]."]\n" ) if $verb3;
      return -1;
   }
   prt( "=[".${$a}[0]."] == [".${$b}[0]."]\n" ) if $verb3;
   return 0;
}

# sort by distance
sub mycmp_ascend_n11 {
   return -1 if (${$a}[11] < ${$b}[11]);
   return  1 if (${$a}[11] > ${$b}[11]);
   return 0;
}

sub fix_airport_name($) {
    my $name = shift;
    my @arr = split(/\s/,$name);
    my $nname = '';
    my $len;
    foreach $name (@arr) {
        $nname .= ' ' if (length($nname));
        $nname .= uc(substr($name,0,1));
        $len = length($name);
        if ($len > 1) {
            $nname .= lc(substr($name,1));
        }
    }
    return $nname;
}

sub in_world_range($$) {
    my ($lat,$lon) = @_;
    if (($lat <= 90)&&
        ($lat >= -90)&&
        ($lon <= 180)&&
        ($lon >= -180)) {
        return 1;
    }
    return 0;
}

# 20131108 - This is NOT sufficient, since it presently ONLY returns 4 == ILS
# But take LFPO example - just searching earth_nav.dat
# 4  48.73966100  002.38779200    291 11030  18      18.282 OLN  LFPO 02  ILS-cat-I
# 4  48.73638900  002.36332500    291 10850  18      61.794 ORE  LFPO 06  ILS-cat-III
# 4  48.71934400  002.31514200    291 11090  18     241.794 OLO  LFPO 24  ILS-cat-II
# 4  48.71863300  002.35440300    291 11175  18     254.372 OLW  LFPO 26  ILS-cat-III
# 5  48.72781100  002.40413300    291 10815  18      74.372 OLE  LFPO 08  LOC
# 6  48.71963300  002.38011700    319 11030  10  300018.282 OLN  LFPO 02  GS
# 6  48.72385600  002.32399200    291 10850  10  300061.794 ORE  LFPO 06  GS
# 6  48.73518900  002.35606900    291 11090  10  320241.794 OLO  LFPO 24  GS
# 6  48.72425800  002.39329400    291 11175  10  300254.372 OLW  LFPO 26  GS
# 7  48.65311100  002.34722200    291     0   0      18.282 ---- LFPO 02  OM
# 7  48.69073100  002.23407000    291     0   0      61.794 ---- LFPO 06  OM
# 7  48.76298100  002.43900000    291     0   0     241.794 ---- LFPO 24  OM
# 7  48.74282800  002.49154000    291     0   0     254.372 ---- LFPO 26  OM
# 12  48.72385000  002.32398100    291 10850  18       0.200 ORE  LFPO 06  DME-ILS
# 12  48.73518600  002.35606100    291 11090  18       0.200 OLO  LFPO 24  DME-ILS
# 12  48.72425800  002.39329400    291 11175  18       0.200 OLW  LFPO 26  DME-ILS

# grouping them per the runway they service, and excluding 'markers'
# 4   48.73966100  002.38779200    291 11030  18      18.282 OLN  LFPO 02  ILS-cat-I
# 6   48.71963300  002.38011700    319 11030  10  300018.282 OLN  LFPO 02  GS

# 4   48.73638900  002.36332500    291 10850  18      61.794 ORE  LFPO 06  ILS-cat-III
# 6   48.72385600  002.32399200    291 10850  10  300061.794 ORE  LFPO 06  GS
# 12  48.72385000  002.32398100    291 10850  18       0.200 ORE  LFPO 06  DME-ILS

# 4   48.71934400  002.31514200    291 11090  18     241.794 OLO  LFPO 24  ILS-cat-II
# 6   48.73518900  002.35606900    291 11090  10  320241.794 OLO  LFPO 24  GS
# 12  48.73518600  002.35606100    291 11090  18       0.200 OLO  LFPO 24  DME-ILS

# 4   48.71863300  002.35440300    291 11175  18     254.372 OLW  LFPO 26  ILS-cat-III
# 6   48.72425800  002.39329400    291 11175  10  300254.372 OLW  LFPO 26  GS
# 12  48.72425800  002.39329400    291 11175  18       0.200 OLW  LFPO 26  DME-ILS

# 5  48.72781100  002.40413300    291 10815  18      74.372 OLE  LFPO 08  LOC

sub find_ils_for_apt($) {
    my $find = shift;
    #                0     1     2     3     4     5    6     7   8     9    10
    # push(@navlist,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
    my $max = scalar @navlist;
    my ($i,$ra,$icao,$cnt,$type,$freq);
    $cnt = 0;
    my %freqs = ();
    for ($i = 0; $i < $max; $i++) {
        $ra = $navlist[$i];
        $icao = ${$ra}[8];
        next if ($icao ne $find);   # seeking only this ICAO
        $type = ${$ra}[0];  # get TYPE
        $freq = ${$ra}[4];
        ### next if ($type != 4); # 20130307 was 6, which is GS?
        # 20131108 - change to accept 4, 5 or 6, but filter on frequency
        if (($type == 4) || ($type == 5) || ($type == 6) || ($type == 12)) {
            if (! defined $freqs{$freq}) {
                $freqs{$freq} = 1;
                $cnt++;
            }
        }
    }
    return $cnt;
}

my %navaid_code = (
    2  => 'NDB',    # (Non-Directional Beacon) Includes NDB component of Locator Outer Markers (LOM)
    3  => 'VOR',    # (including VOR-DME and VORTACs) Includes VORs, VOR-DMEs and VORTACs
    4  => 'ILS',    # Localiser component of an ILS (Instrument Landing System)
    5  => 'LOC',    # Localiser component of a localiser-only approach Includes for LDAs and SDFs
    6  => 'GS',     # Glideslope component of an ILS Frequency shown is paired frequency, not the DME channel
    7  => 'OM',     # Outer markers (OM) for an ILS Includes outer maker component of LOMs
    8  => 'MM',     # Middle markers (MM) for an ILS
    9  => 'IM',     # Inner markers (IM) for an ILS
    12 => 'DME',    # including the DME component of an ILS, VORTAC or VOR-DME Frequency display suppressed on X-Plane’s charts
    13 => 'SDME'    # Stand-alone DME, or the DME component of an NDB-DME Frequency will displayed on X-Plane’s charts
);

# NOTE: This now get ALL navaid (earth_nav.dat) entries for this ICAO
sub get_ils_info($) {
    my $find = shift;
    my @arr = ();
    #                0     1     2     3     4     5    6     7   8     9    10
    # push(@navlist,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
    my $max = scalar @navlist;
    my ($i,$ra,$icao,$cnt,$type);
    $cnt = 0;
    for ($i = 0; $i < $max; $i++) {
        $ra = $navlist[$i];
        $type = ${$ra}[0];
        $icao = ${$ra}[8];
        ###next if ($type != 6); # WANT ALL TYPES with this ICAO
        if ($find eq $icao) {
            $cnt++;
            push(@arr,$ra);
            prt(join(",",@{$ra})."\n") if (VERB9());
        }
    }
    return \@arr;
}

my $min_nav_dist = 100;     # 100 nautical miles
my $pole_2_pole = 20014000; # m
my $min_nav_cnt = 10;
#  my $rnavs = get_nav_info($alat,$alon,$icao);
sub get_nav_info($$$) {
    my ($alat,$alon,$find) = @_;
    my @arr = ();
    my @dists = ();
    #                0     1     2     3     4     5    6     7   8     9    10
    # push(@navlist,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
    my $max = scalar @navlist;
    my ($i,$ra,$icao,$cnt,$type,$lat,$lon);
    my ($az1,$az2,$dist,$ret,$rd,$i2);
    my $mdist = $min_nav_dist * $NM_TO_METER;
    $cnt = 0;
    for ($i = 0; $i < $max; $i++) {
        $ra = $navlist[$i];
        $type = ${$ra}[0];
        $icao = ${$ra}[8];
        # WANT ALL TYPES without this ICAO, whihc was returned in get_ils_info
        # next if ($find eq $icao);
        next if (length($icao)); # ignore other airport ILS stuff
        $lat = ${$ra}[1];
        $lon = ${$ra}[2];
        $ret = fg_geo_inverse_wgs_84($alat, $alon, $lat, $lon, \$az1, \$az2, \$dist);
        if ($ret > 0) {
            $dist = $pole_2_pole; # make it BIG
            $az1 = 0;
        }
        push(@dists,[$i,$dist,$az1]);
        next if ($dist > $mdist);
        my @a = @{$ra};
        push(@a,(int($dist * $METER_TO_NM * 10) / 10));
        push(@a,(int($az1 * 10) / 10));
        push(@arr,\@a);
        $cnt++;
        prt("icao:$cnt: $find: ".join(",",@a)."\n") if (VERB9());
    }
    my @as = ();
    if ($cnt < $min_nav_cnt) {
        @dists = sort mycmp_ascend_n1 @dists;
        $cnt = 0;   # restart count
        for ($i = 0; $i < $max; $i++) {
            $rd = $dists[$i];
            $i2   = ${$rd}[0];
            $dist = ${$rd}[1];
            $az1 =  ${$rd}[2];
            $ra = $navlist[$i2];
            my @a = @{$ra};
            push(@a,(int($dist * $METER_TO_NM * 10) / 10));
            push(@a,(int($az1 * 10) / 10));
            push(@as,\@a);
            $cnt++;
            prt("icao:$cnt: $find: ".join(",",@a)."\n") if (VERB9());
            last if ($cnt >= $min_nav_cnt);
        }
    } else {
        @as = sort mycmp_ascend_n11 @arr;
    }
    return \@as;
}


#Runway line
##   0   1     2 3 4    5 6 7 8   9            10            11    12   13 14 15 16 17  18           19           20     21   22 23 24 25
#EG: 100 29.87 3 0 0.00 0 0 0 16  -24.20505300 151.89156100  0.00  0.00 1  0  0  0  34  -24.19732300 151.88585300 0.00   0.00 1  0  0  0
#OR: 100 29.87 1 0 0.15 0 2 1 13L 47.53801700  -122.30746100 73.15 0.00 2  0  0  1  31R 47.52919200 -122.30000000 110.95 0.00 2  0  0  1
#Land Runway
#0  - 100 - Row code for a land runway (the most common) 100
#1  - 29.87 - Width of runway in metres Two decimal places recommended. Must be >= 1.00
#2  - 3 - Code defining the surface type (concrete, asphalt, etc) Integer value for a Surface Type Code
#3  - 0 - Code defining a runway shoulder surface type 0=no shoulder, 1=asphalt shoulder, 2=concrete shoulder
#4  - 0.15 - Runway smoothness (not used by X-Plane yet) 0.00 (smooth) to 1.00 (very rough). Default is 0.25
#5  - 0 - Runway centre-line lights 0=no centerline lights, 1=centre line lights
#6  - 0 - Runway edge lighting (also implies threshold lights) 0=no edge lights, 2=medium intensity edge lights
#7  - 1 - Auto-generate distance-remaining signs (turn off if created manually) 0=no auto signs, 1=auto-generate signs
#The following fields are repeated for each end of the runway
#8  - 13L - Runway number (eg. 31R, 02). Leading zeros are required. Two to three characters. Valid suffixes: L, R or C (or blank)
#9  - 47.53801700 - Latitude of runway threshold (on runway centerline) in decimal degrees Eight decimal places supported
#10 - -122.30746100 - Longitude of runway threshold (on runway centerline) in decimal degrees Eight decimal places supported
#11 - 73.15 - Length of displaced threshold in metres (this is included in implied runway length) Two decimal places (metres). Default is 0.00
#12 - 0.00 - Length of overrun/blast-pad in metres (not included in implied runway length) Two decimal places (metres). Default is 0.00
#13 - 2 - Code for runway markings (Visual, non-precision, precision) Integer value for Runway Marking Code
#14 - 0 - Code for approach lighting for this runway end Integer value for Approach Lighting Code
#15 - 0 - Flag for runway touchdown zone (TDZ) lighting 0=no TDZ lighting, 1=TDZ lighting
#16 - 1 - Code for Runway End Identifier Lights (REIL) 0=no REIL, 1=omni-directional REIL, 2=unidirectional REIL
#17 - 31R
#18 - 47.52919200
#19 - -122.30000000
#20 - 110.95 
#21 - 0.00 
#22 - 2
#23 - 0
#24 - 0
#25 - 1

#Surface Type Code Surface type of runways or taxiways
#1 Asphalt
#2 Concrete
#3 Turf or grass
#4 Dirt (brown)
#5 Gravel (grey)
#12 Dry lakebed (eg. At KEDW) Example: KEDW (Edwards AFB)
#13 Water runways Nothing displayed
#14 Snow or ice Poor friction. Runway markings cannot be added.
#15 Transparent Hard surface, but no texture/markings (use in custom scenery)
# offset 2 in runway array
my %runway_surface = (
    1  => 'Asphalt',
    2  => 'Concrete',
    3  => 'Turf/grass',
    4  => 'Dirt',
    5  => 'Gravel',
    6  => 'H-Asphalt', # helepad (big 'H' in the middle).
    7  => 'H_Concrete', # helepad (big 'H' in the middle).
    8  => 'H_Turf', # helepad (big 'H' in the middle).
    9  => 'H_Dirt', # helepad (big 'H' in the middle). 
    10 => 'T_Asphalt', # taxiway - with yellow hold line across long axis (not available from WorldMaker).
    11 => 'T_Concrete', # taxiway - with yellow hold line across long axis (not available from WorldMaker).
    12 => 'Dry_Lakebed', # (eg. at KEDW Edwards AFB).
    13 => 'Water', # runways (marked with bobbing buoys) for seaplane/floatplane bases (available in X-Plane 7.0 and later). 
    14 => 'Snow',
    15 => 'Transparent'
);

my %frequency_code = (
    50 => "ATIS",   # 50 ATC – Recorded AWOS, ASOS or ATIS
    51 => "CTAF",   # 51 ATC – Unicom Unicom (US), CTAF (US), Radio (UK)
    52 => "CLD",    # 52 ATC – CLD Clearance Delivery
    53 => "GND",    # 53 ATC – GND Ground
    54 => "TWR",    # 54 ATC – TWR Tower
    55 => "APP",    # 55 ATC – APP Approach
    56 => "DEP"     # 56 ATC - DEP Departure
    );

sub output_apts_to_json($) {
    my $rapts = shift; # = \@sorted
    my $max = scalar @{$rapts};
    my ($i,$ra,$icao,$name,$alat,$alon,$rwycnt,$rwa,$ils,$line,$rfqa,$o_file,$base);
    my ($rcnt,$j,$rrwy,$i2,$j2);
    my ($wid,$surf,$code,$smth,$ctln,$elit);
    my ($rwy1,$lat1,$lon1,$rwy2,$lat2,$lon2);
    my ($rlen,$az1,$az2,$dist,$racnt,$type,$rha);
    my ($freq,$serv,$feet,$slope,$tmp,$rng,$rwwa);
    if ($max == 0) {
        prt("No airports to output!\n");
        return;
    }
    prt("Outputing JSON for $max airport(s)...\n");
    my $bgntm = [gettimeofday];
    my ($elap,$lnspsec,$remain);
    # $line = "icao,name,lat,lon,runways,ils\n";
    $base = '{"success":true,"source":"'.$pgmname.'","last_updated":"'.
        lu_get_YYYYMMDD_hhmmss_UTC(time()).' UTC"';
    #                 0          1      2      3      4      5  6    7        8    9    10    11
    # push(@aptlist, [$lasttype, $icao, $name, $alat, $alon, 0, \@w, $rwycnt, \@a, \@f, $ils, \@h]);

    for ($i = 0; $i < $max; $i++) {
        $i2 = $i + 1;
        $ra = ${$rapts}[$i];
        # added "type":'.$type;  # 1 land, 16 sea, 17 heli
        $type = ${$ra}[0]; # now all types 1 land, 16 sea, 17 heli
        $icao = ${$ra}[1];
        $name = fix_airport_name(${$ra}[2]);
        $alat = ${$ra}[3];
        $alon = ${$ra}[4];
        #$bucket = ${$ra}[5];
        $rwwa = ${$ra}[6];
        $rwycnt = ${$ra}[7];
        $rwa  = ${$ra}[8];
        $rfqa = ${$ra}[9];
        $ils  = ${$ra}[10];
        $rha  = ${$ra}[11];
        # generate the json FILE
        #$o_file = $out_path.$PATH_SEP."$icao.json";
        #if ($skip_done_files && (-f $o_file)) {
        #    prt("ICAO: $icao json exists. skipping... $i2 of $max\n") if (VERB1());
        #    next;
        #}
        #prt("ICAO: $icao: $alat,$alon - doing json... $i2 of $max\n") if (VERB5());
        # my $b = Bucket2->new();
        my $b = Bucket->new();
        $b->set_bucket($alon,$alat);

        # start JSON text with base
        $line = $base;
        $line .= "\n" if ($add_newline);
        $line .= ',"type":'.$type;  # 1 land, 16 sea, 17 heli
        $line .= ',"icao":"'.$icao.'"';
        $line .= ',"name":"'.$name.'"';
        $line .= ',"lat":'.$alat;
        $line .= ',"lon":'.$alon;
        $line .= ',"rwys":'.$rwycnt;
        $line .= ',"ils":'.$ils;
        # TODO - CHECK bucket code - but looks ok
        $line .= ',"index":'.$b->gen_index();
        $line .= ',"path":"'.$b->gen_base_path().'"';
        $line .= "\n" if ($add_newline);
        $rcnt = scalar @{$rwa};
        # 20131111 - always add, even if an empty array
        $line .= ',"runways":[';
        if ($rcnt) {
            $line .= "\n" if ($add_newline);
            prt("RWYS: $icao adding $rcnt...\n") if (VERB5());
            for ($j = 0; $j < $rcnt; $j++) {
                $j2 = $j + 1;
                # 0     1       2   3 4    5 6 7 8    9           10              11       12   13 14 15 16 17   18          19             20        21   22 23 24 25
                # 100   60.96   1   1 0.25 0 2 1 07   49.01911500 -122.37996700    0.00    0.00 3  5  0  0  25   49.02104800 -122.34005800  131.06    0.00 3  11 0  1
                # 100   60.96   1   1 0.25 0 2 1 01   49.01877000 -122.37871800   75.90    0.00 3  0  0  1  19   49.03176400 -122.36917600    0.00    0.00 3  10 0  0
                # 100   28.96   3   0 0.00 0 0 0 01L  49.02608640 -122.37408779    0.00    0.00 1  0  0  0  19R  49.02976278 -122.37147182    0.00    0.00 1   0 0  0
                $rrwy = ${$rwa}[$j];
                $racnt = scalar @{$rrwy};
                if ($racnt < 20) {
                    prtw("WARNING: icao=$icao: Array count $racnt! SKIPPING\n");
                    prt(join(",",@{$rrwy})."\n");
                    next;
                }
                # hmmmm, seems this is NOT always with BOTH ends!!! - see BIKF, BKPR, ....
                # AHA, seems when there are HELIPORTS also
                $type = ${$rrwy}[1]; #0  - 100 for land runways
                $wid  = ${$rrwy}[1]; #1  - 29.87 - Width of runway in metres Two decimal places recommended. Must be >= 1.00
                $surf = ${$rrwy}[2]; #2  - 3 - Code defining the surface type (concrete, asphalt, etc) Integer value for a Surface Type Code
                $code = ${$rrwy}[3]; #3  - 0 - Code defining a runway shoulder surface type 0=no shoulder, 1=asphalt shoulder, 2=concrete shoulder
                $smth = ${$rrwy}[4]; #4  - 0.15 - Runway smoothness (not used by X-Plane yet) 0.00 (smooth) to 1.00 (very rough). Default is 0.25
                $ctln = ${$rrwy}[5]; #5  - 0 - Runway centre-line lights 0=no centerline lights, 1=centre line lights
                $elit = ${$rrwy}[6]; #6  - 0 - Runway edge lighting (also implies threshold lights) 0=no edge lights, 2=medium intensity edge lights
                # #7  - 1 - Auto-generate distance-remaining signs (turn off if created manually) 0=no auto signs, 1=auto-generate signs
                # #The following fields are repeated for each end of the runway
                $rwy1 = ${$rrwy}[8]; #8  - 13L - Runway number (eg. 31R, 02). Leading zeros are required. Two to three characters. Valid suffixes: L, R or C (or blank)
                $lat1 = sprintf("%.8f",${$rrwy}[9]); #9  - 47.53801700 - Latitude of runway threshold (on runway centerline) in decimal degrees Eight decimal places supported
                $lon1 = sprintf("%.8f",${$rrwy}[10]); #10 - -122.30746100 - Longitude of runway threshold (on runway centerline) in decimal degrees Eight decimal places supported
                # #11 - 73.15 - Length of displaced threshold in metres (this is included in implied runway length) Two decimal places (metres). Default is 0.00
                # #12 - 0.00 - Length of overrun/blast-pad in metres (not included in implied runway length) Two decimal places (metres). Default is 0.00
                # #13 - 2 - Code for runway markings (Visual, non-precision, precision) Integer value for Runway Marking Code
                # #14 - 0 - Code for approach lighting for this runway end Integer value for Approach Lighting Code
                # #15 - 0 - Flag for runway touchdown zone (TDZ) lighting 0=no TDZ lighting, 1=TDZ lighting
                # #16 - 1 - Code for Runway End Identifier Lights (REIL) 0=no REIL, 1=omni-directional REIL, 2=unidirectional REIL
                $rwy2 = ${$rrwy}[17]; #17 - 31R
                $lat2 = sprintf("%.8f",${$rrwy}[18]); #18 - 47.52919200
                $lon2 = sprintf("%.8f",${$rrwy}[19]); #19 - -122.30000000
                # #20 - 110.95 
                # #21 - 0.00 
                # #22 - 2
                # #23 - 0
                # #24 - 0
                # #25 - 1
                $rlen = fg_geo_inverse_wgs_84($lat1, $lon1, $lat2, $lon2, \$az1, \$az2, \$dist);
                $line .= '{';
                $line .= '"len_m":'.int($dist);
                $line .= ',"wid_m":'.$wid;
                $line .= ',"hdg":'.int($az1);
                $line .= ',"surf":"';
                if (defined $runway_surface{$surf}) {
                    $line .= $runway_surface{$surf};
                } else {
                    $line .= $surf;
                }
                $line .= '"';
                $line .= ',"rwy1":"'.$rwy1.'"';
                $line .= ',"lat1":'.$lat1;
                $line .= ',"lon1":'.$lon1;
                $line .= ',"rwy2":"'.$rwy2.'"';
                $line .= ',"lat2":'.$lat2;
                $line .= ',"lon2":'.$lon2;
                $line .= "}";
                if ($j2 < $rcnt) {
                    $rrwy = ${$rwa}[$j2];
                    $racnt = scalar @{$rrwy};
                    $line .= "," if ($racnt >= 20);
                }
                $line .= "\n" if ($add_newline);
            }
        }
        $line .= "]";
        $line .= "\n" if ($add_newline);

        # add helipads, if any
        $rcnt = scalar @{$rha};
        $line .= ',"helipads":[';
        $line .= "\n" if ($add_newline);
        if ($rcnt) {
            prt("HELIPADS: $icao adding $rcnt...\n") if (VERB5());
            # 102 H19  63.98375180 -022.58960171 268.42   35.05   35.05   1 0   0 0.00 0
            # 102 H20  63.97607407 -022.64376126   0.00   49.99   49.99   2 0   0 0.00 0
            for ($j = 0; $j < $rcnt; $j++) {
                $j2 = $j + 1;
                $rrwy = ${$rha}[$j];
                $racnt = scalar @{$rrwy};
                $type = ${$rrwy}[0];  #0 102           Row code for a helipad 101
                $rwy1 = ${$rrwy}[1];  #1 H1            Designator for a helipad. Must be unique at an airport. Usually \93H\94 suffixed by an integer (eg. \93H1\94, \93H3\94)
                $lat1 = sprintf("%.8f",${$rrwy}[2]);  #2 47.53918248   Latitude of helipad centre in decimal degrees Eight decimal places supported
                $lon1 = sprintf("%.8f",${$rrwy}[3]);  #3 -122.30722302 Longitude of helipad centre in decimal degrees Eight decimal places supported
                $az1  = ${$rrwy}[3];  #4 2.00          Orientation (true heading) of helipad in degrees Two decimal places recommended
                $wid  = ${$rrwy}[5];  #5 10.06         Helipad length in metres Two decimal places recommended (metres), must be >=1.00
                $dist = ${$rrwy}[6];  #6 10.06         Helipad width in metres Two decimal places recommended (metres), must be >= 1.00
                $surf = ${$rrwy}[7];  #7 1             Helipad surface code Integer value for a Surface Type Code (see below)
                #0             Helipad markings 0 (other values not yet supported)
                #0             Code defining a helipad shoulder surface type 0=no shoulder, 1=asphalt shoulder, 2=concrete shoulder
                #0.25          Helipad smoothness (not used by X-Plane yet) 0.00 (smooth) to 1.00 (very rough). Default is 0.25
                #0             Helipad edge lighting 0=no edge lights, 1=yellow edge lights
                $line .= '{"rwy1":"'.$rwy1.'"';
                $line .= ',"len_m":'.int($dist);
                $line .= ',"wid_m":'.$wid;
                $line .= ',"hdg":'.int($az1);
                $line .= ',"surf":"';
                if (defined $runway_surface{$surf}) {
                    $line .= $runway_surface{$surf};
                } else {
                    $line .= $surf;
                }
                $line .= '"';
                $line .= ',"lat1":'.$lat1;
                $line .= ',"lon1":'.$lon1;
                $line .= "}";
                $line .= "," if ($j2 < $rcnt);
                $line .= "\n" if ($add_newline);
            }
        }
        $line .= "]";
        $line .= "\n" if ($add_newline);

        # add waterways, if any
        $rcnt = scalar @{$rwwa};
        if ($rcnt) {
            # 0   1      2 3  4           5             6  7           8
            # 101 243.84 0 16 29.27763293 -089.35826258 34 29.26458929 -089.35340410
            # 101 22.86  0 07 29.12988952 -089.39561501 25 29.13389936 -089.38060001
            prt("WATERWAYS: $icao adding $rcnt...\n") if (VERB5());
            $line .= ',"waterways":[';
            $line .= "\n" if ($add_newline);
            for ($j = 0; $j < $rcnt; $j++) {
                $j2 = $j + 1;
                $rrwy = ${$rwwa}[$j];
                $racnt = scalar @{$rrwy};
                $type = ${$rrwy}[0]; #0 101 Row code for a water runway 101
                $wid  = ${$rrwy}[1]; #1 49 Width of runway in metres Two decimal places recommended. Must be >= 1.00
                $surf = ${$rrwy}[2]; #2 1 Flag for perimeter buoys 0=no buoys, 1=render buoys
                # The following fields are repeated for each end of the water runway
                $rwy1 = ${$rrwy}[3]; #3 08 Runway number. Not rendered in X-Plane (on water!) Valid suffixes are L, R or C (or blank)
                $lat1 = sprintf("%.8f",${$rrwy}[4]); #4 35.04420911 Latitude of runway end (on runway centerline) in decimal degrees Eight decimal places supported
                $lon1 = sprintf("%.8f",${$rrwy}[5]); #5 -106.59855711 Longitude of runway end (on runway centerline) in decimal degrees Eight decimal places supported            
                $rwy2 = ${$rrwy}[6]; #6 08 Runway number. Not rendered in X-Plane (on water!) Valid suffixes are L, R or C (or blank)
                $lat2 = sprintf("%.8f",${$rrwy}[7]); #7 35.04420911 Latitude of runway end (on runway centerline) in decimal degrees Eight decimal places supported
                $lon2 = sprintf("%.8f",${$rrwy}[8]); #5 -106.59855711 Longitude of runway end (on runway centerline) in decimal degrees Eight decimal places supported            
                $rlen = fg_geo_inverse_wgs_84($lat1, $lon1, $lat2, $lon2, \$az1, \$az2, \$dist);

                # add json
                $line .= '{';
                $line .= '"len_m":'.int($dist);
                $line .= ',"wid_m":'.int($wid);
                $line .= ',"hdg_t":'.int($az1);
                $line .= ',"buoys":';
                $line .= ($surf ? 'true' : 'false');
                $line .= ',"rwy1":"'.$rwy1.'"';
                $line .= ',"lat1":'.$lat1;
                $line .= ',"lon1":'.$lon1;
                $line .= ',"rwy2":"'.$rwy2.'"';
                $line .= ',"lat2":'.$lat2;
                $line .= ',"lon2":'.$lon2;
                $line .= "}";
                $line .= ',' if ($j2 < $rcnt);
                $line .= "\n" if ($add_newline);
            }
            $line .= "]";
            $line .= "\n" if ($add_newline);
        }

        # add frequencies
        $rcnt = scalar @{$rfqa};
        $line .= ',"radios":[';
        $line .= "\n" if ($add_newline);
        if ($rcnt) {
            prt("RADIOS: $icao adding $rcnt...\n") if (VERB5());
            for ($j = 0; $j < $rcnt; $j++) {
                $j2 = $j + 1;
                $rrwy = ${$rfqa}[$j];
                $racnt = scalar @{$rrwy};
                if ($racnt < 2) {
                    prtw("WARNING: freq array ref cnt < 2! got $racnt. \n".join(",",@{$rrwy})."\n");
                    next;
                }
                #0 51 Row code for an ATC COM frequency 50 thru 56 (see above)
                #1 12775 Frequency in MHz x 100 (eg. use 12322 for 123.225MHz) Five digit integer, rounded DOWN where necessary
                #3 ATIS Descriptive name (displayed on X-Plane charts) Short text string (recommend less than 10 characters)
                $type = ${$rrwy}[0];
                $freq = (${$rrwy}[1] / 100);
                $rwy1 = join(' ', splice(@{$rrwy},2));
                $serv = $type;
                if (defined $frequency_code{$type}) {
                    $serv = $frequency_code{$type};
                }
                $line .= "{";
                $line .= '"type":"'.$serv.'"';
                $line .= ',"freq":'.$freq;
                if (length($rwy1)) {
                    $line .= ',"desc":"'.$rwy1.'"';
                }
                $line .= "}";
                if ($j2 < $rcnt) {
                    $rrwy = ${$rfqa}[$j2];
                    $racnt = scalar @{$rrwy};
                    $line .= "," if ($racnt >= 3);
                }
                $line .= "\n" if ($add_newline);
            }
        }
        $line .= "]";
        $line .= "\n" if ($add_newline);

        ###################################################
        # add ILS
        ###################################################
        if ($add_ils_array) {
            my $rilss = get_ils_info($icao);
            $rcnt = scalar @{$rilss};
            $line .= ',"ils":[';
            $line .= "\n" if ($add_newline);
            if ($rcnt) {
                prt("ILS: $icao adding $rcnt...\n") if (VERB5());
                for ($j = 0; $j < $rcnt; $j++) {
                    $j2 = $j + 1;
                    $rrwy = ${$rilss}[$j];
                    $racnt = scalar @{$rrwy};
                    #                0     1     2     3     4     5    6     7   8     9    10
                    # push(@navlist,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
                    $type = ${$rrwy}[0];
                    $lat1 = sprintf("%.8f",${$rrwy}[1]);
                    $lon1 = sprintf("%.8f",${$rrwy}[2]);
                    $feet = ${$rrwy}[3];
                    $freq  = (${$rrwy}[4] / 100);
                    $rng = ${$rrwy}[5];
                    ###$az1  = int(${$rrwy}[6]);
                    $tmp  = ${$rrwy}[6];
                    if ($type == 6) {
                        $az1 = 0;
                        ###$freq = (substr($tmp,3) / 100);
                        $slope = (substr($tmp,0,3) / 100);
                    } else {
                        $az1 = sprintf("%.2f",$tmp);
                        $slope = 0;
                    }
                    $rwy1 = ${$rrwy}[7];    # actually ID
                    # $icao = ${$rrwy}[8];  # was fetched using this
                    $rwy2 = ${$rrwy}[9];    # associated runway, if ANY
                    $name = ${$rrwy}[10];
                    $serv = $type;
                    if (defined $navaid_code{$type}) {
                        $serv = $navaid_code{$type};
                    }

                    # build json
                    $line .= "{";
                    $line .= '"type":"'.$serv.'"';
                    $line .= ',"freq":'.$freq;
                    $line .= ',"lat":'.$lat1;
                    $line .= ',"lon":'.$lon1;
                    $line .= ',"rng_nm":'.$rng;
                    $line .= ',"alt_fmsl":'.$feet;
                    $line .= ',"hdg":'.$az1 if ($type == 4);
                    $line .= ',"id":"'.$rwy1.'"' if (length($rwy1));
                    $line .= ',"rwy":"'.$rwy2.'"' if (length($rwy2));
                    $line .= ',"desc":"'.$name.'"' if (length($name));
                    $line .= ',"gs":'.$slope if ($type == 6);
                    $line .= "}";
                    $line .= "," if ($j2 < $rcnt);
                    $line .= "\n" if ($add_newline);
                }
            }
            $line .= "]";
            $line .= "\n" if ($add_newline);
        }
        #####################################################

        # add navaids nearyby
        #####################################################
        if ($add_navaids_array) {
            my $rnavs = get_nav_info($alat,$alon,$icao);
            $rcnt = scalar @{$rnavs};
            $line .= ',"navaids":[';
            $line .= "\n" if ($add_newline);
            if ($rcnt) {
                prt("NAV: $icao adding $rcnt...\n") if (VERB5());
                for ($j = 0; $j < $rcnt; $j++) {
                    $j2 = $j + 1;
                    $rrwy = ${$rnavs}[$j];
                    $racnt = scalar @{$rrwy};
                    #                0     1     2     3     4     5    6     7   8     9    10
                    # push(@navlist,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
                    $type = ${$rrwy}[0];
                    $lat1 = sprintf("%.8f",${$rrwy}[1]);
                    $lon1 = sprintf("%.8f",${$rrwy}[2]);
                    $feet = ${$rrwy}[3];
                    if ($type == 2) {
                        $freq  = ${$rrwy}[4];
                    } else {
                        $freq  = (${$rrwy}[4] / 100);
                    }
                    $rng = ${$rrwy}[5];
                    ###$az1  = int(${$rrwy}[6]);
                    $tmp  = ${$rrwy}[6];
                    if ($type == 6) {
                    #    $az1 = 0;
                    #    ###$freq = (substr($tmp,3) / 100);
                        $slope = (substr($tmp,0,3) / 100);
                    } else {
                    #    $az1 = sprintf("%.2f",$tmp);
                        $slope = 0;
                    }
                    $rwy1 = ${$rrwy}[7];    # actually ID
                    # $icao = ${$rrwy}[8];  # was fetched using this
                    $rwy2 = ${$rrwy}[9];    # associated runway, if ANY
                    $name = ${$rrwy}[10];
                    $dist = ${$rrwy}[11];
                    $az1  = ${$rrwy}[12];
                    $serv = $type;
                    if (defined $navaid_code{$type}) {
                        $serv = $navaid_code{$type};
                    }

                    # build json
                    $line .= "{";
                    $line .= '"type":"'.$serv.'"';
                    $line .= ',"hdg_t":'.$az1;
                    $line .= ',"dist_nm":'.$dist;
                    $line .= ',"freq":'.$freq;
                    $line .= ',"lat":'.$lat1;
                    $line .= ',"lon":'.$lon1;
                    $line .= ',"rng_nm":'.$rng;
                    $line .= ',"alt_fmsl":'.$feet;
                    ###$line .= ',"hdg":'.$az1 if ($type == 4);
                    $line .= ',"id":"'.$rwy1.'"' if (length($rwy1));
                    $line .= ',"rwy":"'.$rwy2.'"' if (length($rwy2));
                    $line .= ',"desc":"'.$name.'"' if (length($name));
                    $line .= ',"gs":'.$slope if ($type == 6);
                    $line .= "}";
                    $line .= "," if ($j2 < $rcnt);
                    $line .= "\n" if ($add_newline);
                }
            }
            $line .= "]";
            $line .= "\n" if ($add_newline);
        }
        $line .= "}\n";
        $o_file = $out_path.$PATH_SEP."$icao.json";
        $tmp = 0;
        while ( -f $o_file ) {
            $tmp++;
            $o_file = $out_path.$PATH_SEP."$icao.json".$tmp;
        }
        write2file($line,$o_file);
        $json_count++;
        $json_bytes += length($line);
        prt("ICAO: $icao json written to [$o_file]. $i2 of $max\n");
    }   # for ($i = 0; $i < $max; $i++)

    ##### all done #####
    $elap = tv_interval ( $bgntm, [gettimeofday]);
    $lnspsec = ($i / $elap);
    $remain =  (($max / $lnspsec) - $elap);
    $lnspsec = (int($lnspsec * 10) / 10);
    prt("File $i of $max (est $lnspsec files/sec, elap=".secs_HHMMSS(int($elap)).", rem=".secs_HHMMSS(int($remain)).").\n");
}

################################################################
# 1000 Version - data cycle 2012.08, build 20121293
sub load_apt_data {
    prt("Loading $aptdat file ... seeking ".join(" ",@find_icaos)." ...\n");
    mydie("ERROR: Can NOT locate $aptdat ...$!...\n") if ( !( -f $aptdat) );
    ###open IF, "<$aptdat" or mydie("OOPS, failed to open [$aptdat] ... check name and location ...\n");
    open IF, "<$aptdat" or mydie( "ERROR: CAN NOT OPEN $aptdat...$!...\n" );
    ##prt( "Processing $cnt lines ... airports, runways, and taxiways ...\n" );
    ##set_apt_version( \@lines, $cnt );
    my ($rlat1,$rlat2,$rlon1,$rlon2,$type,$len,$lasttype,@arr,@arr2,$ils);
    my ($apline,$ra,$helicnt,$wwcnt,$trcnt,$tmp);
    my (@sorted, $o_file,$rwwa,$msg);
    my ($i,$rwa);
    my ($tlat,$tlon);   # tower/viewport location
    my @runways = ();
    my @heliways = ();
    my @closedapts = ();
    my @helipads = ();
    my @seaapts = ();
    my @majapts = ();
    my @freqs = ();
    my @waterways = ();
    $lasttype = 0;
    my $estmax = 2133071;
    my $bgntm = [gettimeofday];
    my ($elap,$lnspsec,$remain);
    $helicnt = 0;
    $rwycnt = 0;
    $wwcnt = 0;
    $ra = \@aptlist;
    $tlat = 999;
    $tlon = 999;
    while ($line = <IF>) {
        chomp $line;
        $line = trimall($line);
        $len = length($line);
        if (($. % 25000) == 0) {
            $elap = tv_interval ( $bgntm, [gettimeofday]);
            $lnspsec = $. / $elap;
            $remain = ($estmax / $lnspsec) - $elap;
            prt("Line $. of $estmax (est ".int($lnspsec)." lns/sec, elap=".secs_HHMMSS(int($elap)).", rem=".secs_HHMMSS(int($remain)).").\n");
        }
        next if ($len == 0);
        if ($. < 3) {
            if ($. == 2) {
                #$o_file = $out_path.$PATH_SEP."VERSION.apt.txt";
                #write2file($line,$o_file);
                #push(@files_written,["VERSION.apt.txt",1,51]);
                prt(substr($line,0,50)."...\n");
            }
            next;
        }
        ###prt("$.: $line\n");
        @arr = split(/\s+/,$line);
        $type = $arr[0];
        if ($type == 99) {
            prt( "$.: Reached END OF FILE ... \n" ); # if ($dbg1);
            last;
        }
        ###pgm_exit(1,"END") if ($. > 15);
        ### if (($line =~ /^$aln\s+/)||($line =~ /^$sealn\s+/)||($line =~ /^$heliln\s+/)) {
        #if ($line =~ /^$aln\s+/) {	# start with '1'
        if (($type == 1)||($type == 16)||($type == 17)) {
            # start of a NEW airport line
            if (length($apt)) {
                # ==========================================================
                # deal with previous
                $trcnt = $rwycnt;
                $trcnt += $helicnt;
                $trcnt += $wwcnt;
                $msg = '';
                # 20131118 - if tower/viewport location valid, use that
                if (in_world_range($tlat,$tlon)) {
                    $alat = $tlat;
                    $alon = $tlon;
                    $msg = 'twr ';
                } else {
                    if ($trcnt > 0) {
                        $alat = $glat / $trcnt;
                        $alon = $glon / $trcnt;
                        if (!in_world_range($alat,$alon)) {
                            prtw("WARNING: $apline: OOW [$apt] $alat,$alon $rwycnt\n");
                            next;
                        }
                    } else {
                        $alat = 0;
                        $alon = 0;
                        prtw("WARNING: $.: No RUNWAYS [$apt]\n");
                        next;
                    }
                    $msg = 'rwy ';
                }
                @arr2 = split(/\s/,$apt);
                $icao = $arr2[4];
                $name = join(' ', splice(@arr2,5));
                prt( "[$name] $icao $alat $alon rwys=$rwycnt\n" ) if ($dbg11);
                if (defined $icaos_to_find{$icao}) {
                    ##prt("[$apt] (with $rwycnt runways at [$alat, $alon]) ...\n");
                    ##prt("[$icao] [$name] ...\n");
                    my @a = @runways;
                    my @f = @freqs;
                    my @h = @heliways;
                    my @w = @waterways;
                    $ils = 0;
                    if ($name =~ /\[X\]/) {
                        $ra = \@closedapts;
                        $msg .= 'closed';
                    } elsif (($name =~ /\[H\]/)||($lasttype == 17)) {
                        $ra = \@helipads;
                        $msg .= 'heliport';
                    } else {
                        if ($lasttype == 1) {
                            $ra = \@aptlist;
                            $msg .= 'land airport';
                            $totaptcnt++;	# count another AIRPORT
                        } elsif ($lasttype == 16) {
                            $ra = \@seaapts;
                            $msg .= 'sea airport';
                        } else {
                            prtw("$.: ERROR: Unknown last type $lasttype. [$apt]\n");
                            pgm_exit(1,"");
                        }
                        $ils = find_ils_for_apt($icao);
                        #if ($ils > 0) {
                        #    push(@majapts, [$lasttype, $icao, $name, $alat, $alon, 0, \@w, $rwycnt, \@a, \@f, $ils, \@h]);
                        #}
                    }
                    push(@{$ra}, [$lasttype, $icao, $name, $alat, $alon, 0, \@w, $rwycnt, \@a, \@f, $ils, \@h]);
                    $elap = tv_interval ( $bgntm, [gettimeofday]);
                    $lnspsec = $. / $elap;
                    $remain = ($estmax / $lnspsec) - $elap;
                    delete $icaos_to_find{$icao}; # delete from hash
                    $tmp = scalar keys(%icaos_to_find);
                    prt("Line $. of $estmax (est ".int($lnspsec)." lns/sec, elap=".secs_HHMMSS(int($elap)).", rem=".secs_HHMMSS(int($remain)).").\n");
                    prt("Found icao $icao, cat $msg... remainder $tmp to find...\n");
                    $apt = '';
                    last if ($tmp == 0);
                }
                # ==========================================================
            } elsif (length($apt)) {
                prtw("WARNING: $.: Skipping line [$line]\n");
                pgm_exit(1,"");
            }
            $apline = $.;
            $apt = $line;   # set the NEW AIRPORT line
            $rwycnt  = 0;   # restart RUNWAY counter
            $helicnt = 0;   # restart helipad counter
            $wwcnt   = 0;   # restart waterway counter
            $glat    = 0;   # clear lat accumulator
            $glon    = 0;   # clear lon accumulator
            $tlat    = 999; # clear Tower/Viewport location
            $tlon    = 999;
            @runways = ();
            @freqs = ();
            @heliways = ();
            @waterways = ();
            $lasttype = $type;  # keep LAST type
            prt("$apt\n") if ($dbg10);
        #} elsif ($line =~ /^$rln\s+/) {
        } elsif ($type == 100) {	# land runways
            # 0     1       2   3 4    5 6 7 8    9           10              11       12   13 14 15 16 17   18          19             20        21   22 23 24 25
            # 100   60.96   1   1 0.25 0 2 1 07   49.01911500 -122.37996700    0.00    0.00 3  5  0  0  25   49.02104800 -122.34005800  131.06    0.00 3  11 0  1
            # 100   60.96   1   1 0.25 0 2 1 01   49.01877000 -122.37871800   75.90    0.00 3  0  0  1  19   49.03176400 -122.36917600    0.00    0.00 3  10 0  0
            # 100   28.96   3   0 0.00 0 0 0 01L  49.02608640 -122.37408779    0.00    0.00 1  0  0  0  19R  49.02976278 -122.37147182    0.00    0.00 1   0 0  0
            $rlat1 = $arr[9];  # [$of_lat1];
            $rlon1 = $arr[10]; # [$of_lon1];
            $rlat2 = $arr[18]; # [$of_lat2];
            $rlon2 = $arr[19]; # [$of_lon2];
            $rlat = sprintf("%.8f",(($rlat1 + $rlat2) / 2));
            $rlon = sprintf("%.8f",(($rlon1 + $rlon2) / 2));
            if (!in_world_range($rlat,$rlon)) {
                prt( "$.: $line [$rlat, $rlon]\n" );
                next;
            }
            $glat += $rlat;
            $glon += $rlon;
            $rwycnt++;  # count another runway
            my @a2 = @arr;
            push(@runways, \@a2);
        } elsif ($type == 101) {	# Water runways
            # 0   1      2 3  4           5             6  7           8
            # 101 243.84 0 16 29.27763293 -089.35826258 34 29.26458929 -089.35340410
            # 101 22.86  0 07 29.12988952 -089.39561501 25 29.13389936 -089.38060001
            # prt("$.: $line\n");
            $rlat1 = $arr[4];
            $rlon1 = $arr[5];
            $rlat2 = $arr[7];
            $rlon2 = $arr[8];
            $rlat = sprintf("%.8f",(($rlat1 + $rlat2) / 2));
            $rlon = sprintf("%.8f",(($rlon1 + $rlon2) / 2));
            if (!in_world_range($rlat,$rlon)) {
                prtw( "WARNING: $.: $line [$rlat, $rlon] NOT IN WORLD\n" );
                next;
            }
            $glat += $rlat;
            $glon += $rlon;
            my @a2 = @arr;
            push(@waterways, \@a2);
            $wwcnt++;
        } elsif ($type == 102) {	# Heliport
            # my $heli =   '102'; # Helipad
            # 0   1  2           3            4      5     6     7 8 9 10   11
            # 102 H2 52.48160046 013.39580674 355.00 18.90 18.90 2 0 0 0.00 0
            # 102 H3 52.48071507 013.39937648 2.64   13.11 13.11 1 0 0 0.00 0
            # prt("$.: $line\n");
            $rlat = sprintf("%.8f",$arr[2]);
            $rlon = sprintf("%.8f",$arr[3]);
            if (!in_world_range($rlat,$rlon)) {
                prtw( "WARNING: $.: $line [$rlat, $rlon] NOT IN WORLD\n" );
                next;
            }
            $glat += $rlat;
            $glon += $rlon;
            my @a2 = @arr;
            push(@heliways, \@a2);
            $helicnt++;
        } elsif ($type == 10) { # old 810 runway/taxiway code!!!
            # 0  1           2             3   4      5   6   7   8  9      10 11 12 13   14
            # 10 68.72074130 -052.79344940 xxx 168.00 160 0.0 0.0 60 161161 1  0  0  0.25 0
            $rlat = $arr[1];
            $rlon = $arr[2];
            $name = $arr[3];
            if ($name ne 'xxx') {
                prtw("WARNING: $.: [$line] NOT A TAXIWAY!\n");
            }
        } elsif ($type == 110) { # 110  Pavement (taxiway or ramp) header Must form a closed loop
        } elsif ($type == 120) { # 120  Linear feature (painted line or light string) header Can form closed loop or simple string
        } elsif ($type == 130) { # 130  Airport boundary header Must form a closed loop
        } elsif ($type == 111) { # 111  Node All nodes can also include a style (line or lights)
        } elsif ($type == 112) { # 112  Node with Bezier control point Bezier control points define smooth curves
        } elsif ($type == 113) { # 113  Node with implicit close of loop Implied join to first node in chain
        } elsif ($type == 114) { # 114  Node with Bezier control point, with implicit close of loop Implied join to first node in chain
        } elsif ($type == 115) { # 115  Node terminating a string (no close loop) No styles used
        } elsif ($type == 116) { # 116  Node with Bezier control point, terminating a string (no close loop) No styles used
        } elsif ($type == 14) { # 14   Airport viewpoint One or none for each airport
            # 14 47.52917900 -122.30434900 100 0 ATC Tower
            $tlat = sprintf("%.8f",$arr[1]);
            $tlon = sprintf("%.8f",$arr[2]);
        } elsif ($type == 15) { # 15   Aeroplane startup location *** Convert these to new row code 1300 ***
        } elsif ($type == 18) { # 18   Airport light beacon One or none for each airport
        } elsif ($type == 19) { # 19   Windsock Zero, one or many for each airport
        } elsif ($type == 20) { # 20   Taxiway sign (inc. runway distance-remaining signs) Zero, one or many for each airport
        } elsif ($type == 21) { # 21   Lighting object (VASI, PAPI, Wig-Wag, etc.) Zero, one or many for each airport
        } elsif ($type == 1000) { # 1000 Airport traffic flow Zero, one or many for an airport. Used if following rules met (rules of same type are ORed together, rules of a different type are ANDed together to). First flow to pass all rules is used.
        } elsif ($type == 1001) { # 1001 Traffic flow wind rule One or many for a flow. Multiple rules of same type ORed
        } elsif ($type == 1002) { # 1002 Traffic flow minimum ceiling rule Zero or one rule for each flow
        } elsif ($type == 1003) { # 1003 Traffic flow minimum visibility rule Zero or one rule for each flow
        } elsif ($type == 1004) { # 1004 Traffic flow time rule One or many for a flow. Multiple rules of same type ORed
        } elsif ($type == 1100) { # 1100 Runway-in-use arrival/departure constraints First constraint met is used. Sequence matters
        } elsif ($type == 1101) { # 1101 VFR traffic pattern Zero or one pattern for each traffic flow
        } elsif ($type == 1200) { # 1200 Header indicating that taxi route network data follows
        } elsif ($type == 1201) { # 1201 Taxi route network node Sequencing is arbitrary. Must be part of one or more edges
        } elsif ($type == 1202) { # 1202 Taxi route network edge Must connect two nodes
        } elsif ($type == 1204) { # 1204 Taxi route edge active zone Can refer to up to 4 runway ends
        } elsif ($type == 1300) { # 1300 Airport location Not explicitly connected to taxi route network
        } elsif (($type >= 50)&&($type <= 56)) { # 50-56 Communication frequencies Zero, one or many for each airport
            my @tfa = @arr;
            push(@freqs, \@tfa); # save the freq array
        } else {
            pgm_exit(1,"$.: [$line] UNPARSED! FIX ME!!\n");
        }
    }

    $elap = tv_interval ( $bgntm, [gettimeofday]);
    $lnspsec = $. / $elap;
    $remain = ($estmax / $lnspsec) - $elap;
    # prt("Line $. of $estmax (est ".int($lnspsec)." lns/sec, elap=".secs_HHMMSS(int($elap)).", rem=".secs_HHMMSS(int($remain)).") - all done.\n");
    # prt("Line $. - all done\n");
    close(IF);
    # do any LAST entry
    if (length($apt)) {
        $trcnt = $rwycnt;
        $trcnt += $helicnt;
        $trcnt += $wwcnt;
        if ($trcnt > 0) {
            $alat = $glat / $trcnt;
            $alon = $glon / $trcnt;
            if (!in_world_range($alat,$alon)) {
                prtw("WARNING: $apline: OOW [$apt] $alat,$alon $rwycnt\n");
            }
        } else {
            $alat = 0;
            $alon = 0;
            prtw("WARNING: $.: No RUNWAYS [$apt]\n");
        }
        @arr2 = split(/ /,$apt);
        $icao = $arr2[4];
        $name = join(' ', splice(@arr2,5));
        ###prt("$diff [$apt] (with $rwycnt runways at [$alat, $alon]) ...\n");
        ###prt("$diff [$icao] [$name] ...\n");
        my @a = @runways;
        my @f = @freqs;
        my @h = @heliways;
        my @w = @waterways;
        if (defined $icaos_to_find{$icao}) {
            $ils = find_ils_for_apt($icao);
            if ($name =~ /\[X\]/) {
                $ra = \@closedapts;
                $msg = 'closed';
            } else {
                if ($lasttype == 1) {
                    $ra = \@aptlist;
                    $msg = 'land airport';
                    $totaptcnt++;	# count another AIRPORT
                } elsif ($lasttype == 16) {
                    $ra = \@seaapts;
                    $msg = 'sea airport';
                } elsif ($lasttype == 17) {
                    $ra = \@helipads;
                    $msg = 'heliport';
                } else {
                    prtw("$.: ERROR: Unknown last type $lasttype. [$apt]\n");
                    pgm_exit(1,"");
                }
                $ils = find_ils_for_apt($icao);
                delete $icaos_to_find{$icao}; # delete from hash
                #if ($ils > 0) {
                #    push(@majapts, [$lasttype, $icao, $name, $alat, $alon, 0, \@w, $rwycnt, \@a, \@f, $ils, \@h]);
                #}
            }
            push(@{$ra}, [$lasttype, $icao, $name, $alat, $alon, 0, \@w, $rwycnt, \@a, \@f, $ils, \@h]);
            prt("Found icao $icao, cat $msg...\n");

        }
    }
    #### done file ###
    @arr = keys %icaos_to_find;
    $tmp = scalar @arr;
    prtw("WARNING: Not $tmp NOT FOUND! ".join(" ",@arr)."\n") if ($tmp);

    $tmp = scalar @closedapts;
    $apline = scalar @aptlist;
    $wwcnt = scalar @seaapts;
    $helicnt = scalar @helipads;
    $diff = $tmp + $apline + $wwcnt + $helicnt;
    prt("Loaded $diff airports... land $apline, sea $wwcnt, heli $helicnt, closed $tmp\n");
    ##############################################
    output_apts_to_json(\@aptlist) if ($apline);
    output_apts_to_json(\@helipads) if ($helicnt);
    output_apts_to_json(\@seaapts) if ($wwcnt);
    output_apts_to_json(\@closedapts) if ($tmp);
    ##############################################
}

sub load_nav_file {
	prt("\nLoading $navdat file ...\n");
	mydie("ERROR: Can NOT locate [$navdat]!\n") if ( !( -f $navdat) );
	open NIF, "<$navdat" or mydie( "ERROR: CAN NOT OPEN $navdat...$!...\n" );
	my @nav_lines = <NIF>;
	close NIF;
    my $cnt = scalar @nav_lines;
    prt("Loaded $cnt line...\n");
    return \@nav_lines;
}


##############
### functions

# 12/12/2008 - Additional distance calculations
# from 'signs' perl script
# Melchior FRANZ <mfranz # aon : at>
# $Id: signs,v 1.37 2005/06/01 15:53:00 m Exp $

# sub ll2xyz($$) {
sub ll2xyz {
	my $lon = (shift) * $D2R;
	my $lat = (shift) * $D2R;
	my $cosphi = cos $lat;
	my $di = $cosphi * cos $lon;
	my $dj = $cosphi * sin $lon;
	my $dk = sin $lat;
	return ($di, $dj, $dk);
}


# sub xyz2ll($$$) {
sub xyz2ll {
	my ($di, $dj, $dk) = @_;
	my $aux = $di * $di + $dj * $dj;
	my $lat = atan2($dk, sqrt $aux) * $R2D;
	my $lon = atan2($dj, $di) * $R2D;
	return ($lon, $lat);
}

# sub coord_dist_sq($$$$$$) {
sub coord_dist_sq {
	my ($xa, $ya, $za, $xb, $yb, $zb) = @_;
	my $x = $xb - $xa;
	my $y = $yb - $ya;
	my $z = $zb - $za;
	return $x * $x + $y * $y + $z * $z;
}

sub get_bucket_info {
   my ($lon,$lat) = @_;
   #my $b = Bucket2->new();
   my $b = Bucket->new();
   $b->set_bucket($lon,$lat);
   return $b->bucket_info();
}

sub look_like_icao($) {
    my $icao = shift;
    my $up = uc($icao);
    my $len = length($icao);
    if (($len == 4) && ($up eq $icao)) {
        return 1;
    }
    return 0;
}

# How can I tell if a string is a number?
# The simplest method is:
#         if ($string == "$string") { 
#          # It is a number
#        } 
# Note the use of the == operator to compare the string to its numeric value. 
# However, this approach is dangerous because the $string might contain arbitrary 
# code such as @{[system "rm -rf /"]} which would be executed as a result of the 
# interpolation process. For safety, use this regular expression:
#   if ($var =~ /(?=.)M{0,3}(C[MD]|D?C{0,3})(X[CL]|L?X{0,3})(I[XV]|V?I{0,3})/) {
#    print "$var contains a number.\b";
#  }


# contains digits,commas and 1 period AND
# does not contain alpha's, more than 1 period
# commas or periods at the beggining and ends of
# each line AND
# is not null
sub IsANumber($) {
    my $var = shift;
    if ( ( $var =~ /(^[0-9]{1,}?$)|(\,*?)|(\.{1})/ ) &&
         !( $var =~ /([a-zA-Z])|(^[\.\,]|[\.\,]$)/ ) &&
         ($var ne '') ) {
         return 1;
    } 
    return 0;
}


sub looks_like_rwy($) {
    my $rwy = shift;
    if (length($rwy) > 0) {
        my $ch = substr($rwy,0,1);
        if (IsANumber($ch)) {  # or perhaps if ($ch == "$ch")
            return 1;
        }
    }
    return 0;
}

my %name_exceptions = (
    'BORYSPIL NDB' => 1,
    'DONETSK NDB' => 1,
    'LOPEZ ISLAND NDB' => 1,
    'PINCK NDB' => 1,
    'OKANAGAN NDB' => 1,
    'UTICA NDB' => 1,
    'DURBAN NDB' => 1,
    'NIZHNEYANSK NDB' => 1  # really should sort out LOCATION - Dist = 6585
    );

sub exception_names($) {
    my $name = shift;
    return 1 if (defined $name_exceptions{$name});
    return 0;
}

sub is_ndb_lom($$) {
    my ($ucnm1,$ucnm2) = @_;
    return 1 if (($ucnm1 =~ /NDB/)&&($ucnm2 =~ /LOM/));
    return 1 if (($ucnm1 =~ /LOM/)&&($ucnm2 =~ /NDB/));
    return 0;
}

# THESE SHOULD BE RE-CHECKED - EXCEPTIONS
sub is_big_exception($$) {
    my ($ucnm1,$ucnm2) = @_;
    return 1 if (($ucnm1 =~ /CHIHUAHUA/)&&($ucnm2 =~ /CHIHUAHUA/)); # dist 1223??? 12:3! VOR-DME
    return 1 if (($ucnm1 =~ /CATEY/)&&($ucnm2 =~ /CATEY/)); # dist 376 but one name starts 'EL ' VOR-DME/VORTAC
    return 1 if (($ucnm1 =~ /DONETSK/)&&($ucnm2 =~ /DONETSK/)); # dist 3971??? 13:3! DME/VOR-DME
    return 1 if (($ucnm1 =~ /GUANTANAMO/)&&($ucnm2 =~ /GUANTANAMO/)); # dist 2150??? 13:3! TACAN/VOR
    return 1 if (($ucnm1 =~ /BOURGET/)&&($ucnm2 =~ /BOURGET/)); # dist 92??? 13:12! DME VOR-DME
    return 1 if (($ucnm1 =~ /MEXICALI/)&&($ucnm2 =~ /MEXICALI/)); # Quite CLOSE 1433??? 12:3!
    return 0;
}


# sub filter_nav_list() if ($do_nav_filter);
# a massive SLOW process, mainly to weed out what look like DUPLICATES
# and other 'exceptions'.
sub filter_nav_list() {
    my @sorted = sort mycmp_ascend_n0 @navlist;
    my $max = scalar @sorted;
    my ($i,$ra,$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name);
    my ($j,$ra2,$type2,$nlat2,$nlon2,$feet2,$freq2,$rng2,$bear2,$id2,$icao2,$rwy2,$name2);
    my ($max2,$fnd,$dist,$az1,$az2,$ret,$msg1,$msg2,$i2,$j2);
    my ($ucnm1,$ucnm2,@arr1,@arr2);
    prt("Filtering $max navaids...\n");
    #$line = "type,lat,lon,feet,freq,rng,bear,id,icao,rwy,\"name\"\n";
    #                0     1     2     3     4     5    6     7   8     9    10
    # push(@navlist,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
    my @navs = ();
    my $bgntm = [gettimeofday];
    for ($i = 0; $i < $max; $i++) {
        $i2 = $i + 1;
        $ra = $sorted[$i];
        $type = ${$ra}[0];
        $nlat = ${$ra}[1];
        $nlon = ${$ra}[2];
        $feet = ${$ra}[3];
        $freq = ${$ra}[4];
        $rng  = ${$ra}[5];
        $bear = ${$ra}[6];
        $id   = ${$ra}[7];
        $icao = ${$ra}[8];
        $rwy  = ${$ra}[9];
        $name = ${$ra}[10];
        $max2 = scalar @navs;
        $fnd = 0;
        if (length($icao) == 0) {
            for ($j = 0; $j < $max2; $j++) {
                $j2 = $j + 1;
                $ra2 = $navs[$j];
                $type2 = ${$ra2}[0];
                $nlat2 = ${$ra2}[1];
                $nlon2 = ${$ra2}[2];
                $feet2 = ${$ra2}[3];
                $freq2 = ${$ra2}[4];
                $rng2  = ${$ra2}[5];
                $bear2 = ${$ra2}[6];
                $id2   = ${$ra2}[7];
                $icao2 = ${$ra2}[8];
                $rwy2  = ${$ra2}[9];
                $name2 = ${$ra2}[10];
                next if (length($icao2) > 0);
                if ( ($id eq $id2) && ($freq == $freq2) ) {
                    $msg1 = join(",", @{$ra})."\n";
                    $msg2 = join(",", @{$ra2})."\n";
                    $ret = fg_geo_inverse_wgs_84($nlat, $nlon, $nlat2, $nlon2, \$az1, \$az2, \$dist);
                    if ($ret > 0) {
                        $dist = $pole_2_pole; # make it BIG
                        $az1 = 0;
                        prtw("$i2:$j2: WARNING: fg_geo_inverse_wgs_84($nlat, $nlon, $nlat2, $nlon2, ...) FAILED!\n");
                    } else {
                        $dist = int($dist);
                        $ucnm1 = uc($name);
                        $ucnm2 = uc($name2);
                        @arr1 = split(/\s+/,$ucnm1);
                        @arr2 = split(/\s+/,$ucnm2);
                        if ($type == $type2) {
                            if ($dist < 10000) {
                                if ($type == 2) {
                                    if (($ucnm1 eq $ucnm2) && (exception_names($ucnm1))) {
                                        $fnd = 1;   # exception - drop duplication
                                        prt("$i2:$j2: NDB exception - Dist $dist! Dropping first\n".$msg1.$msg2) if (VERB9());
                                    } elsif (is_ndb_lom($ucnm1,$ucnm2)) {
                                        $fnd = 1;   # exception for NDB and LOM
                                        prt("$i2:$j2: NDB and LOM - Dist $dist! Dropping first\n".$msg1.$msg2) if (VERB9());
                                    } elsif (($arr1[0] eq $arr2[0]) && ($dist < 1000)) {
                                        $fnd = 1;   # ok name starts same like
                                        # 2,-42.72933333,170.95622222,0,310,100,0.0,HK,,,HOKITIKA NDB-DME
                                        # 2,-42.72933333,170.95622222,0,310,50,0.0,HK,,,HOKITIKA NDB
                                        prt("$i2:$j2: NDB DUPLICATION - Dist $dist! Dropping first\n".$msg1.$msg2) if (VERB9());
                                    } else {
                                        prt("$i2:$j2: Potential NDB DUPLICATION - Dist $dist! CHECK ME!\n".$msg1.$msg2);
                                    }
                                } elsif ($dist < 1000) {
                                    if ($arr1[0] eq $arr2[0]) {
                                        prt("$i2:$j2: NDB DUPE - SAME FIRST NAME - Dist $dist! Dropping first\n".$msg1.$msg2) if (VERB9());
                                        $fnd = 1;
                                    }

                                } else {
                                    prt("$i2:$j2: Potential DUPLICATION - Dist $dist! CHECK ME!\n".$msg1.$msg2);
                                }
                            }
                        } else {
                            if ($dist < 20) {
                                # *** CO-LOCATION ***
                                # ok, decide these can be dropped without notice if
                                if (( ($type == 3) && ($type2 == 13) ) || ( ($type == 13) && ($type2 == 3) )) {
                                    # like AOSTA DME <=> AOSTA VOR-DME Dist 0 or close, SAME frequency
                                    $fnd = 1;
                                    prt("$i2:$j2: Combine VOR & VOR-DME - Dist $dist dropping first!\n".$msg1.$msg2) if (VERB9());
                                } elsif (( ($type == 3) && ($type2 == 12) ) || ( ($type == 12) && ($type2 == 3) )) {
                                    # like AOSTA DME <=> AOSTA VOR-DME Dist 0 or close, SAME frequency
                                    $fnd = 1;
                                    prt("$i2:$j2: Combine VOR & VOR-DME - Dist $dist dropping first!\n".$msg1.$msg2) if (VERB9());
                                } elsif ($ucnm1 eq $ucnm2) {
                                    $fnd = 1;
                                    prt("$i2:$j2: Combine SAME NAME - Dist $dist dropping first!\n".$msg1.$msg2) if (VERB9());
                                } elsif ($arr1[0] eq $arr2[0]) {
                                    $fnd = 1;
                                    prt("$i2:$j2: Combine FIRST NAME - Dist $dist dropping first!\n".$msg1.$msg2) if (VERB9());
                                } else {
                                    prt("$i2:$j2: Combine these - CO-LOCATED - Dist $dist dropping first!\n".$msg1.$msg2);
                                    $fnd = 1;
                                }
                            } elsif ($dist < 10000 ) {
                                if ( ($ucnm1 eq $ucnm2) && ($dist < 1000) ) {
                                    prt("$i2:$j2: Close $dist, and SAME NAME, freq, id $type:$type2! Dropping first\n".$msg1.$msg2) if (VERB9());
                                    $fnd = 1;
                                } elsif ( ($arr1[0] eq $arr2[0]) && ($dist < 1000) ) {
                                    prt("$i2:$j2: Close $dist, and SAME FIRST NAME, freq, id $type:$type2! Dropping first\n".$msg1.$msg2) if (VERB9());
                                    $fnd = 1;
                                } elsif (is_big_exception($ucnm1,$ucnm2)) {
                                    prt("$i2:$j2: Close $dist, special exceptions. CHECK ME! $type:$type2! Dropping first\n".$msg1.$msg2) if (VERB9());
                                    $fnd = 1;
                                } else {
                                    prt("$i2:$j2: WARNING: Quite CLOSE $dist??? $type:$type2!\n".$msg1.$msg2);
                                }
                            }
                        }
                    }
                }
                last if ($fnd); # found dupe - dropping one
            }   # for ($j = 0; $j < $max2; $j++)
        }
        if ($fnd == 0) {
            push(@navs,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
        }
    }
    @navlist = @navs;
    $i = scalar @navlist;
    my $elap = tv_interval ( $bgntm, [gettimeofday]);
    prt("Returning $i of $max. That mess took ".secs_HHMMSS(int($elap))."\n");
}

sub  write_nav_list() {
    if ( -f $navdat2) {
        prt("File $navdat2 already exist...\n");
        return;
    }
    my $max = scalar @navlist;
    prt("Writing $max nav records to $navdat2...\n");
    my ($i,$rnav,$line);
    if (! open(FIL,">$navdat2")) {
        pgm_exit(1,"Unable to create $navdat2!\n");
    }
    for ($i = 0; $i < $max; $i++) {
        $rnav = $navlist[$i];
        $line = join(" ",@{$rnav});
        print FIL "$line\n";
    }
    close FIL;
    prt("Written $max nav records to $navdat2...\n");
}

# ============================================================
# 20131123 - new tests added mainly for 6 GS and 12 VOR-DME
sub looks_like_number($) {
    my $txt = shift;
    $txt = substr($txt,1) if ($txt =~ /^-/); # remove any beginning minus sign
    return 1 if ($txt =~ /^\d+$/);
    return 0;
}
sub looks_like_freq($) {
    my $txt = shift;
    my $len = length($txt);
    return 0 if ($len < 5); # expect at least 5 digits
    return looks_like_number($txt);
}
sub looks_like_id($) {
    my $txt = shift;
    my $len = length($txt);
    return 0 if ($len < 2); # expect at least 2 chars
    my $utx = uc($txt);
    return 0 if ($utx ne $txt);
    return 1;
}
sub looks_like_bearing($) {
    my $txt = shift;
    return 1 if (IsANumber($txt));
    return 0;
}
# 300327.389
sub looks_like_gs($) {
    my $txt = shift;
    my $len = length($txt);
    return 0 if ($len != 10);
    return IsANumber($txt);
}
# ============================================================

##################################################################################
### Load x-plane earth_nav.dat - all added to @navlist
##############################
sub parse_nav_lines($) {
    my $rnava = shift;
    my $max = scalar @{$rnava};
    # add to my @navlist = ();
    my ($i,$line,$lnn,@arr,$acnt,$type,$len,$vnav);
    my ($nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$name,$rwy);
    my (@sorted,$ra,$diff,$o_file,$tmp,$tmp2);
    $lnn = 0;
    prt("Processing $max line of NAV data...\n");
    for ($i = 0; $i < $max; $i++) {
        $line = ${$rnava}[$i];
        chomp $line;
        $line = trimall($line);
        $len = length($line);
        $lnn++;
        next if ($len == 0);
        if ($lnn < 3) {
            if ($lnn == 2) {
                #$o_file = $out_path.$PATH_SEP.'VERSION.nav.txt';
                #write2file("$line\n",$o_file);
                #push(@files_written,['VERSION.nav.txt',1,51]);
                #prt(substr($line,0,50)."..., written to [$o_file]\n");
                prt(substr($line,0,50)."...\n");
            }
            next;
        }
        @arr = split(/\s+/,$line);
        $acnt = scalar @arr;
        $type = $arr[0];
        if ($type == 99) {
            prt("$lnn: Reached EOF (99)\n");
            last;
        }
        #0  1           2             3    4     5   6          7    8                 9    10
        #CD LAT         LON           ELEV FREQ  RNG BEARING    ID   NAME              RWY  NAME
        #                             FT         NM. GS Ang          ICAO
        #2  47.63252778 -122.38952778 0      362 50  0.0        BF   NOLLA NDB
        #3  47.43538889 -122.30961111 354  11680 130 19.0       SEA  SEATTLE VORTAC
        #4  47.42939200 -122.30805600 338  11030 18  180.343    ISNQ KSEA               16L ILS-cat-I
        #6  47.46081700 -122.30939400 425  11030 10  300180.343 ISNQ KSEA               16L GS
        if ($acnt < 9) {
            prt("Split only yielded $acnt!\n");
            prt("$lnn: [$line]\n");
            pgm_exit(1,"");
        }

        $nlat = $arr[1];
        $nlon = $arr[2];
        $feet = $arr[3];
        $freq = $arr[4];
        $rng  = $arr[5];
        $bear = $arr[6];
        $id   = $arr[7];
        $icao = $arr[8];
        $name = $icao;
        $rwy  = '';
        if ($type == 2) {
            # 2  NDB - (Non-Directional Beacon) Includes NDB component of Locator Outer Markers (LOM)
            # 2  47.63252778 -122.38952778 0      362 50  0.0        BF   NOLLA NDB
            $icao = '';
            $name = join(' ', splice(@arr,8));
        } elsif ($type == 3) {
            # 3  VOR - (including VOR-DME and VORTACs) Includes VORs, VOR-DMEs and VORTACs
            # 3  47.43538889 -122.30961111 354  11680 130 19.0       SEA  SEATTLE VORTAC
            $icao = '';
            $name = join(' ', splice(@arr,8));
        } elsif ($type == 4) {
            # 4  ILS - LOC Localiser component of an ILS (Instrument Landing System)
            # 0  1           2             3    4     5   6          7    8                  9   10
            # 4  47.42939200 -122.30805600 338  11030 18  180.343    ISNQ KSEA               16L ILS-cat-I
            if ($acnt < 11) {
                prtw("WARNING: Split only yielded $acnt!\n".
                    "$lnn: [$line] SKIPPING\n");
                next;
            }
            $rwy = $arr[9];
            $name = $arr[10];
        } elsif ($type == 5) {
            # 5  LOC - Localiser component of a localiser-only approach Includes for LDAs and SDFs
            # 0  1           2              3    4     5   6         7    8                  9   10
            # 5  40.03460600 -079.02328100  2272 10870 18  236.086   ISOZ 2G9                25  LOC
            # 5  67.01850600 -050.68207200   165 10955 18   61.600   ISF  BGSF               10  LOC
            if ($acnt < 11) {
                prtw("WARNING: Split only yielded $acnt!\n".
                    "$lnn: [$line] SKIPPING\n");
                next;
            }
            $rwy = $arr[9];
            $name = $arr[10];
        } elsif ($type == 6) {
            # 6  GS  - Glideslope component of an ILS Frequency shown is paired frequency, not the DME channel
            # 0  1           2             3    4     5   6          7    8     9   10
            # 6  47.46081700 -122.30939400 425  11030 10  300180.343 ISNQ KSEA  16L GS
            # 0 1           2              3         4    5        6    7   8
            # 6 40.75644400 016.94085000   1184 *NF* 10 300321.163 LIBV 32L GS
            # Got 4 WARNINGS...
            #                 0 1           2            3    4  5          6    7   8
            # WARNING:16455: [6 40.75644400 016.94085000 1184 10 300321.163 LIBV 32L GS] SKIPPING split 9
            # WARNING:16827: [6 24.01447200 121.61319400 52   10 320026.187 RCYU 03 GS] SKIPPING split 9
            #                 0 1           2            3    4  5          6    7    8  9
            # WARNING:16758: [6 28.27461100 068.45741900 185  10 300327.389 MCCT OPJA 33 GS] SKIPPING split 10
            # WARNING:16812: [6 22.74861100 121.09566700 143  10 300038.513 MFNN RCFN 04 GS] SKIPPING split 10
            # $feet = $arr[3];
            # $freq = $arr[4];
            # $rng  = $arr[5];
            # $bear = $arr[6];
            # $id   = $arr[7];
            # $icao = $arr[8];
            if ($acnt < 11) {
                if (($acnt == 9) && looks_like_number($feet) && looks_like_number($freq) &&
                    looks_like_gs($rng) && look_like_icao($bear) && looks_like_rwy($id) && ($icao eq 'GS')) {
                    $rwy = $id;     # [7] is runway
                    $tmp = $freq;
                    $freq = '19999';    # set dummy freq
                    $tmp2 = $bear;
                    $bear = $rng;
                    $rng = $tmp;    # [4] is range
                    $tmp = $icao;
                    $icao = $tmp2;
                    $id = $icao;
                    $name = 'GS';
                    #prt("CHECK: $type,$nlat,$nlon,a=$feet,f=$freq,r=$rng,b=$bear,id=$id,icao=$icao,rw=$rwy,nm=$name\n");
                } elsif (($acnt == 10) && looks_like_number($feet) && looks_like_number($freq) &&
                    looks_like_gs($rng) && looks_like_id($bear) && look_like_icao($id) && looks_like_rwy($icao) && ($arr[9] eq 'GS')) {
                    $tmp = $freq;
                    $freq = '19999'; # dummy freq
                    $tmp2 = $rng;
                    $rng = $tmp;
                    $tmp = $bear;
                    $bear = $tmp2;
                    $tmp2 = $id;
                    $id = $tmp;
                    $tmp = $icao;
                    $icao = $tmp2;
                    $rwy = $tmp;
                    $name = 'GS';
                    #prt("CHECK: $type,$nlat,$nlon,a=$feet,f=$freq,r=$rng,b=$bear,id=$id,icao=$icao,rw=$rwy,nm=$name\n");
                } else {
                    prtw("WARNING:$lnn: [$line] SKIPPING split $acnt\n");
                    next;
                }
            } else {
                $rwy = $arr[9];
                $name = $arr[10];
            }
        } elsif ($type == 7) {
            # 7  OM  - Outer markers (OM) for an ILS Includes outer maker component of LOMs
            if ($acnt < 11) {
                prtw("WARNING:$lnn: [$line] SKIPPING split $acnt\n");
                next;
            }
            $rwy = $arr[9];
            $name = $arr[10];
        } elsif ($type == 8) {
            # 8  MM  - Middle markers (MM) for an ILS
            # 8  47.47223300 -122.31102500 433  0     0   180.343    ---- KSEA               16L MM
            if ($acnt < 11) {
                prtw("WARNING:$lnn: [$line] SKIPPING split $acnt\n");
                next;
            }
            $rwy = $arr[9];
            $name = $arr[10];
        } elsif ($type == 9) {
            # 9  IM  - Inner markers (IM) for an ILS
            if ($acnt < 11) {
                prtw("WARNING:$lnn: [$line] SKIPPING split $acnt\n");
                next;
            }
            $rwy = $arr[9];
            $name = $arr[10];
        } elsif ($type == 12) {
            # 12 DME - including the DME component of an ILS, VORTAC or VOR-DME Frequency display suppressed on X-Plane charts
            # 0  1           2             3    4     5   6          7    8                  9   10
            # 12 47.43433300 -122.30630000 369  11030 18  0.000      ISNQ KSEA               16L DME-ILS
            # 12 47.43538889 -122.30961111 354  11680 130 0.0        SEA  SEATTLE VORTAC DME
            # exceptions
            # 0  1           2            3    4     5  6   7   8
            # 12 49.22907200 007.41789200 1177 11480 60 0.0 ZWN ZWEIBRUCKEN VOR-DME
            # $feet = $arr[3];
            # $freq = $arr[4];
            # $rng  = $arr[5];
            # $bear = $arr[6];
            # $id   = $arr[7];
            # $icao = $arr[8];
            if (($acnt > 10) && look_like_icao($icao) && looks_like_rwy($arr[9])) {
                $rwy = $arr[9];
                $name = $arr[10];
            } elsif (looks_like_number($feet) && looks_like_freq($freq) && looks_like_number($rng) && looks_like_bearing($bear) && looks_like_id($id)) {
                $icao = ''; # this is NOT an ICAO
                $name = join(' ', splice(@arr,8));
            } else {
                prtw("WARNING:$lnn: [$line] SKIPPING split $acnt\n");
                next;
            }
        } elsif ($type == 13) {
            # 13 Stand-alone DME, or the DME component of an NDB-DME Frequency will displayed on X-Plane charts
            # 0  1           2             3    4     5      6       7    8
            # 13 57.10393300  009.99280800  57  11670 199    0.0     AAL  AALBORG TACAN
            # 13 68.71941900 -052.79275300 172  10875  25    0.0     AS   AASIAAT DME
            $icao = '';
            $name = join(' ', splice(@arr,8));
        } else {
            prtw("WARNING:$lnn: INVALID [$line]\n");
            next;
        }

        ##############################################################################
        #               0     1     2     3     4     5    6     7   8     9   10
        push(@navlist,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
        ##############################################################################
    }
    $type = scalar @navlist;
    prt("Collected $type navaids, before filtering...\n");
    filter_nav_list() if ($do_nav_filter);
    write_nav_list();
    #write_nav_csv();
}

sub check_files() {
    if (! -f $aptdat) {
        pgm_exit(1,"ERROR: Input file $aptdat does NOT EXIST!\n");
    }
    if (! -f $navdat) {
        pgm_exit(1,"ERROR: Input file $navdat does NOT EXIST!\n");
    }
    if (! -f $licfil) {
        pgm_exit(1,"ERROR: Input file $licfil does NOT EXIST!\n");
    }
    if (! -d $out_path) {
        pgm_exit(1,"ERROR: Ouput path [$out_path] does NOT EXIST!\nCreate the path, and run again...\n");
    }

    #copy($licfil,$out_path);
    #prt("Copied the licence text to [$out_path]\n");
    #### pgm_exit(0,"TEMP EXIT");
}

sub output_readme() {
    my $o_file = $out_path.$PATH_SEP."README.txt";
    my $txt = "FLIGHTGEAR AIRPORT GENERATION UTILITY - version $VERS\n";

    $txt .= "\nGenerated by $pgmname, on ".lu_get_YYYYMMDD_hhmmss_UTC(time())." UTC\n";
    $txt .= "generated from $aptdat and $navdat data files.\n";
    $txt .= "Files written:\n"; # join(" ",@files_written)."\n";
    my $max = scalar @files_written;
    my ($i,$file,$lines,$bytes,$min,$len,$minl,$minb,$nnl,$nnb);
    my $tot_lines = 0;
    my $tot_bytes = 0;
    $min = 0;
    $minl = 0;
    $minb = 0;
    for ($i = 0; $i < $max; $i++) {
        $file = $files_written[$i][0];
        $len = length($file);
        $min = $len if ($len > $min);
        $lines = $files_written[$i][1];
        $nnl = get_nn($lines);
        $len = length($nnl);
        $minl = $len if ($len > $minl);
        $bytes = $files_written[$i][2];
        $nnb = get_nn($bytes);
        $len = length($nnb);
        $minb = $len if ($len > $minb);
        $tot_lines += $lines;
        $tot_bytes += $bytes;
    }
    $nnl = get_nn($tot_lines);
    $len = length($nnl);
    $minl = $len if ($len > $minl);
    $nnb = get_nn($tot_bytes);
    $len = length($nnb);
    $minb = $len if ($len > $minb);
    for ($i = 0; $i < $max; $i++) {
        $file = $files_written[$i][0];
        $lines = $files_written[$i][1];
        $bytes = $files_written[$i][2];
        $file .= ' ' while(length($file) < $min);
        $nnl = get_nn($line);
        $nnl = ' '.$nnl while (length($nnl) < $minl);
        $nnb = get_nn($bytes);
        $nnb = ' '.$nnb while (length($nnb) < $minb);
        $txt .= "$file $nnl lines, $nnb bytes\n"
    }
    $nnl = get_nn($tot_lines);
    $nnb = get_nn($tot_bytes);
    my $bks = util_bytes2ks($tot_bytes);
    $txt .= "Approx. total of $nnl lines, $nnb bytes ($bks)\n";

    $nnl = get_nn($json_count);
    $nnb = get_nn($json_bytes);
    $txt .= "\nPlus $nnl ICAO.json files, $nnb bytes, for each airport.\n";
    $txt .= "\nAnd of course this README.txt\n";
    my $elap = tv_interval ( $t0, [gettimeofday]);
    $nnb = get_nn(int($elap));
    $txt .= "\nProcessing took $nnb seconds, or ".secs_HHMMSS(int($elap))."\n";
    $txt .= "\n# eof\n";
    write2file($txt,$o_file);
    prt("Summary of output written to $o_file\n");
}

# if more than just ONE space, them push an empty item
sub spl_space_split($) {
    my $line = shift;
    my $len = length($line);
    my ($i,$ch,$pc,$tag);
    $ch = '';
    my @arr = ();
    $tag = '';
    for ($i = 0; $i < $len; $i++) {
        $pc = $ch;
        $ch = substr($line,$i,1);
        if ($ch =~ /\s/) {
            push(@arr,$tag) if (length($tag));
            $tag = '';
            if ($pc =~ /\s/) {
                push(@arr,"");
            }
        } else {
            $tag .= $ch;
        }
    }
    push(@arr,$tag) if (length($tag));
    return \@arr;
}

sub do_nav_load() {
    if (-f $navdat2) {
        if (open FIL,"<$navdat2") {
            my @lines = <FIL>;
            close FIL;
            my $max = scalar @lines;
            prt("Loaded $max lines from $navdat2\n");
            my ($i,$line,$ra,$len);
            my ($type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name);
            for ($i = 0; $i < $max; $i++) {
                $line = $lines[$i];
                chomp $line;
                $ra = spl_space_split($line);
                $len = scalar @{$ra};
                if ($len < 11) {
                    pgm_exit(1,"Bad line [$line] len $len!\n");
                }
                $type = ${$ra}[0];
                $nlat = ${$ra}[1];
                $nlon = ${$ra}[2];
                $feet = ${$ra}[3];
                $freq = ${$ra}[4];
                $rng  = ${$ra}[5];
                $bear = ${$ra}[6];
                $id   = ${$ra}[7];
                $icao = ${$ra}[8];
                $rwy  = ${$ra}[9];
                $name = join(' ', splice(@{$ra},10));
                ##############################################################################
                #               0     1     2     3     4     5    6     7   8     9   10
                #               4    39.9  5.877 660   108   18   281.6 IMQS 40N   29  ILS-cat-I
                push(@navlist,[$type,$nlat,$nlon,$feet,$freq,$rng,$bear,$id,$icao,$rwy,$name]);
                ##############################################################################
            }
            $type = scalar @navlist;
            prtw("WARNING: Collected $type navaids, from $navdat2\nDelete file to use x-plane earth-nav.dat!");
            #write_nav_csv();
            #$line = get_nav_vers();
            #my $o_file = $out_path.$PATH_SEP.'VERSION.nav.txt';
            #write2file("$line\n",$o_file);
            #push(@files_written,['VERSION.nav.txt',1,51]);
            #prt(substr($line,0,50)."..., written to [$o_file]\n");
            return;
        }

    }
    my $nav_ref = load_nav_file();
    parse_nav_lines($nav_ref);
    
}


############################################
### MAIN ###
parse_args(@ARGV);	# collect command line arguments ...
# prt("Not exists $notexist\n");
check_files();

do_nav_load();

### pgm_exit(0,"");

load_apt_data();  # load apt.dat, and output found to json

#output_readme();
my $elapsed = tv_interval ( $t0, [gettimeofday]);
prt( "Ran for $elapsed seconds ... ".secs_HHMMSS(int($elapsed))."\n" );
pgm_exit(0,"");
############################################################

sub need_arg {
    my ($arg,@av) = @_;
    pgm_exit(1,"ERROR: [$arg] must have a following argument!\n") if (!@av);
}

sub load_input_file($) {
    my $file = shift;
    if (!open FIL, "<$file") {
        pgm_exit(1,"ERROR: Unable to open input file [$file]\n");
    }
    my @lines = <FIL>;
    close FIL;
    my ($line,$len,$cnt);
    $cnt = 0;
    foreach $line (@lines) {
        chomp $line;
        $line = trim_all($line);
        $len = length($line);
        next if ($len == 0);
        next if ($line =~ /^\#/);
        $icaos_to_find{$line} = 1;
        push(@find_icaos,$line);
        prt("Added to find ICAO [$line]\n") if (VERB5());
        $cnt++;
    }
    prt("Added to $cnt ICAO from [$file]\n") if (VERB1());
}


sub parse_args {
    my (@av) = @_;
    my ($arg,$sarg);
    while (@av) {
        $arg = $av[0];
        if ($arg =~ /^-/) {
            $sarg = substr($arg,1);
            $sarg = substr($sarg,1) while ($sarg =~ /^-/);
            if (($sarg =~ /^h/i)||($sarg eq '?')) {
                give_help();
                pgm_exit(0,"Help exit(0)");
            } elsif ($sarg =~ /^v/) {
                if ($sarg =~ /^v.*(\d+)$/) {
                    $verbosity = $1;
                } else {
                    while ($sarg =~ /^v/) {
                        $verbosity++;
                        $sarg = substr($sarg,1);
                    }
                }
                prt("Verbosity = $verbosity\n") if (VERB1());
            } elsif ($sarg =~ /^l/) {
                if ($sarg =~ /^ll/) {
                    $load_log = 2;
                } else {
                    $load_log = 1;
                }
                prt("Set to load log at end. ($load_log)\n") if (VERB1());
            } elsif ($sarg =~ /^o/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                $out_path = $sarg;
                prt("Set out path to [$out_path].\n") if (VERB1());
            } elsif ($sarg =~ /^i/) {
                $add_ils_array = 1;
                prt("Set to add ils array to ICAO airport json.\n") if (VERB1());
            } elsif ($sarg =~ /^n/) {
                $add_navaids_array = 1;
                prt("Set to add navaids array to ICAO airport json.\n") if (VERB1());
            } elsif ($sarg =~ /^f/) {
                need_arg(@av);
                shift @av;
                $sarg = $av[0];
                load_input_file($sarg);
            } else {
                pgm_exit(1,"ERROR: Invalid argument [$arg]! Try -?\n");
            }
        } else {
            $icaos_to_find{$arg} = 1;
            push(@find_icaos,$arg);
            prt("Added to find ICAO [$arg]\n") if (VERB1());
        }
        shift @av;
    }

#    if ($debug_on) {
#        prtw("WARNING: DEBUG is ON!\n");
#        if (length($out_path) ==  0) {
#            $out_path = $dout_path;
#            prt("Set DEFAULT output path to [$out_path]\n");
#        }
#    }
    if (length($out_path) ==  0) {
        pgm_exit(1,"ERROR: No output path found in command! Add -o path\n");
    }
    if (! -d $out_path) {
        pgm_exit(1,"ERROR: Ouput path [$out_path] does NOT exist! Check name, location...\n");
    }
    
    $arg = scalar @find_icaos;
    if ($debug_on) {
        prtw("WARNING: DEBUG is ON!\n");
        if ($arg == 0) {
            $icaos_to_find{$def_icao} = 1;
            push(@find_icaos,$def_icao);
            prt("Added to find DEFAULT ICAO [$def_icao]\n") if (VERB1());
            $arg++;
        }
    }
    if ($arg == 0) {
        pgm_exit(1,"ERROR: No ICAO to find found in command!\n");
    }
}

sub give_help {
    prt("$pgmname: version $VERS\n");
    prt("Usage: $pgmname [options] out_directory\n");
    prt("Options:\n");
    prt(" --help  (-h or -?) = This help, and exit 0.\n");
    prt(" --verb[n]     (-v) = Bump [or set] verbosity. (def=$verbosity)\n");
    prt(" --load        (-l) = Load LOG at end. (def=$outfile)\n");
    prt(" --out <dir>   (-o) = Write output to directory. Must exist. (def=$out_path).\n");
    prt(" --nav         (-n) = Add navaids array to ICAO airport json. (def=$add_navaids_array)\n");
    prt(" --ils         (-i) = Add ils array to ICAO airport json. (def=$add_ils_array)\n");
    prt(" --file <file> (-f) = Input the ICAO list from the <file>.\n");
}

# eof - xp2json.pl
