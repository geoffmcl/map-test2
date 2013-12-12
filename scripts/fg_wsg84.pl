#!/usr/bin/perl -w
# NAME: fg_wgs84.pl
# AIM: Emulate various SG services...
# fg_geo_inverse_wgs_84($lat1, $lon1, $lat2, $lon2, $ref_az1, $ref_az2, $ref_s);
# Convert two lat,lon cordinates, to distance, and azimuth, and
# fg_geo_direct_wgs_84($lat1, $lon1, $az1, $s, $ref_lat2, $ref_lon2, $ref_az2 );
# Calculate from one lat,lon coordinate, on azimuth, for distance, to second lat,lon
# lat,lon,asimuth in degrees, distance in meters.
# 08/03/2013 - Only if set_debug_on(1) output the FAILURE message
# 08/03/2013 - Fix an iternation bug in fg_geo_inverse_wgs_84()
# 17/12/2008 geoff mclane http://geoffair.net/mperl
use constant PI    => 4 * atan2(1, 1);

my $FG_PI = PI;
my $FG_D2R = $FG_PI / 180;
my $FG_R2D = 180 / $FG_PI;
my $FG_MIN = 2.22507e-308;

my $FG_F2M = 0.3048;
my $FG_M2F = 3.28083989501312335958;

#// These are hard numbers from the WGS84 standard.  DON'T MODIFY
#// unless you want to change the datum.
my $FG_EQURAD = 6378137.0;
my $FG_FACTOR = 6378138.12;
my $FG_FLATTENING = 298.257223563;

my $FG_SQUASH = 0.9966471893352525192801545;
my $FG_STRETCH = 1.0033640898209764189003079;
my $FG_POLRAD = 6356752.3142451794975639668;

# user options
my $max_iter = 100; # was 250
my $show_fail = 0;

sub set_debug_on($) { $show_fail = shift; }
sub get_fg_PI() { return $FG_PI; }
#// given lat1, lon1, lat2, lon2, calculate starting and ending
#// az1, az2 and distance (s).  Lat, lon, and azimuth are in degrees.
#// distance in meters
#static int _fg_geo_inverse_wgs_84( double lat1, double lon1, double lat2,
#			double lon2, double *az1, double *az2,
#                        double *s )
sub fg_geo_inverse_wgs_84 {
    my ($lat1, $lon1, $lat2, $lon2, $az1, $az2, $s) = @_;
    my $a = $FG_EQURAD;
    my $rf = $FG_FLATTENING;
    my $iter = 0;
    my $testv = 1.0E-10;
    my $f = ( $rf > 0.0 ? 1.0/$rf : 0.0 );
    my $b = $a * (1.0 - $f);
    #// double e2 = f*(2.0-f); // unused in this routine
    my $phi1 = $FG_D2R * $lat1;
    my $lam1 = $FG_D2R * $lon1;
    my $sinphi1 = sin($phi1);
    my $cosphi1 = cos($phi1);
    my $phi2 = $FG_D2R * $lat2;
    my $lam2 = $FG_D2R * $lon2;
    my $sinphi2 = sin($phi2);
    my $cosphi2 = cos($phi2);
	my ($k);

    if( (abs($lat1-$lat2) < $testv && 
	 ( abs($lon1-$lon2) < $testv) || abs($lat1-90.0) < $testv ) ) {
    	#// TWO STATIONS ARE IDENTICAL : SET DISTANCE & AZIMUTHS TO ZERO */
        $$az1 = 0.0;
        $$az2 = 0.0;
        $$s = 0.0;
        return 0;
    } elsif(  abs($cosphi1) < $testv ) {
        #// initial point is polar
        $k = fg_geo_inverse_wgs_84( $lat2, $lon2, $lat1, $lon1, $az1, $az2, $s );
	    my $b = $$az1;
        $$az1 = $$az2;
        $$az2 = $b;
    	return $k;
    } elsif( abs($cosphi2) < $testv ) {
        #// terminal point is polar
        my $r_lon1 = $lon1 + 180.0;
        $k = fg_geo_inverse_wgs_84( $lat1, $lon1, $lat1, $r_lon1, $az1, $az2, $s );
        $$s /= 2.0;
        $$az2 = $$az1 + 180.0;
        $$az2 -= 360.0 if ( $$az2 > 360.0 );
    	return $k;
    } elsif( (abs( abs($lon1-$lon2) - 180 ) < $testv) && (abs($lat1+$lat2) < $testv) ) {
        #// Geodesic passes through the pole (antipodal)
        my ($s1, $s2);
        $k = fg_geo_inverse_wgs_84( $lat1,$lon1, $lat1,$lon2, $az1,$az2, \$s1 );
        $k += fg_geo_inverse_wgs_84( $lat2,$lon2, $lat1,$lon2, $az1,$az2, \$s2 );
    	$$az2 = $$az1;
	    $$s = $s1 + $s2;
    	return $k;
    } else {
	    # // antipodal and polar points don't get here
	    my $dlam = $lam2 - $lam1;
        my $dlams = $dlam;
        my ($sdlams,$cdlams, $sig,$sinsig,$cossig, $sinaz, $cos2saz, $c2sigm);
        my ($tc,$temp, $us,$rnumer,$denom, $ta,$tb);
        my ($cosu1,$sinu1, $sinu2,$cosu2);
        #// Reduced latitudes
        $temp = (1.0-$f)*$sinphi1/$cosphi1;
        $cosu1 = 1.0/sqrt(1.0+$temp*$temp);
    	$sinu1 = $temp*$cosu1;
	    $temp = (1.0-$f)*$sinphi2/$cosphi2;
    	$cosu2 = 1.0/sqrt(1.0+$temp*$temp);
    	$sinu2 = $temp*$cosu2;
        do {
            $sdlams = sin($dlams);
            $cdlams = cos($dlams);
            $sinsig = sqrt($cosu2*$cosu2*$sdlams*$sdlams+
			  ($cosu1*$sinu2-$sinu1*$cosu2*$cdlams)*
			  ($cosu1*$sinu2-$sinu1*$cosu2*$cdlams));
	        $cossig = $sinu1*$sinu2+$cosu1*$cosu2*$cdlams;
            $sig = atan2($sinsig,$cossig);
            $sinaz = $cosu1*$cosu2*$sdlams/$sinsig;
            $cos2saz = 1.0-$sinaz*$sinaz;
            $c2sigm = ($sinu1 == 0.0 || $sinu2 == 0.0 ? $cossig : 
		      $cossig-2.0*$sinu1*$sinu2/$cos2saz);
            $tc = $f*$cos2saz*(4.0+$f*(4.0-3.0*$cos2saz))/16.0;
            $temp = $dlams;
            $dlams = $dlam+(1.0-$tc)*$f*$sinaz*
        		($sig+$tc*$sinsig*($c2sigm+$tc*$cossig*
                (-1.0+2.0*$c2sigm*$c2sigm)));

            $iter++;
            if ((abs($dlams) > $FG_PI) && ($iter >= $max_iter)) {
                prt("FAILED: abs(dlams)=$dlams GT PI=".$FG_PI."! Returning $iter\n") if ($show_fail);
                return $iter;
	        }
            if ($iter >= $max_iter) {
                prt("Formula FAILED to converge! Returning $iter\n") if ($show_fail);
                return $iter;
            }
	    } while ( abs($temp-$dlams) > $testv);

        $us = $cos2saz*($a*$a-$b*$b)/($b*$b);   #// !!
    	#// BACK AZIMUTH FROM NORTH
	    $rnumer = -($cosu1*$sdlams);
        $denom = $sinu1*$cosu2-$cosu1*$sinu2*$cdlams;
        $$az2 = $FG_R2D * (atan2($rnumer,$denom));
        $$az2 = 0.0 if ( abs($$az2) < $testv );
        $$az2 += 360.0 if ($$az2 < 0.0) ;
        # // FORWARD AZIMUTH FROM NORTH
        $rnumer = $cosu2*$sdlams;
        $denom = $cosu1*$sinu2-$sinu1*$cosu2*$cdlams;
        $$az1 = $FG_R2D * (atan2($rnumer,$denom));
        $$az1 = 0.0 if ( abs($$az1) < $testv );
    	$$az1 += 360.0 if ( $$az1 < 0.0) ;
        #// Terms a & b
        $ta = 1.0+$us*(4096.0+$us*(-768.0+$us*(320.0-175.0*$us)))/16384.0;
        $tb = $us*(256.0+$us*(-128.0+$us*(74.0-47.0*$us)))/1024.0;
        #// GEODETIC DISTANCE
        $$s = $b*$ta*($sig-$tb*$sinsig*
            ($c2sigm+$tb*($cossig*(-1.0+2.0*$c2sigm*$c2sigm)-$tb*
            $c2sigm*(-3.0+4.0*$sinsig*$sinsig)*
            (-3.0+4.0*$c2sigm*$c2sigm)/6.0)/4.0));
        return 0;
    }
}

#static inline double M0( double e2 ) {
#    //double e4 = e2*e2;
sub FG_MO {
    my ($e2) = shift;
    return $FG_PI*0.5*(1.0 - $e2*( 1.0/4.0 + $e2*( 3.0/64.0 + 
        $e2*(5.0/256.0) )));
}

#// given, lat1, lon1, az1 and distance (s), calculate lat2, lon2
#// and az2.  Lat, lon, and azimuth are in degrees.  distance in meters
#static int _geo_direct_wgs_84 ( double lat1, double lon1, double az1,
#                        double s, double *lat2, double *lon2,
#                        double *az2 )
sub fg_geo_direct_wgs_84 {
    my ( $lat1, $lon1, $az1, $s, $lat2, $lon2, $az2 ) = @_;
    my $a = $FG_EQURAD;
    my $rf = $FG_FLATTENING;
    my $testv = 1.0E-10;
    my $f = ( $rf > 0.0 ? 1.0/$rf : 0.0 );
    my $b = $a*(1.0-$f);
    my $e2 = $f*(2.0-$f);
    my $phi1 = $FG_D2R * $lat1;
    my $lam1 = $FG_D2R * $lon1;
    my $sinphi1 = sin($phi1);
    my $cosphi1 = cos($phi1);
    my $azm1 = $FG_D2R * $az1;
    my $sinaz1 = sin($azm1);
    my $cosaz1 = cos($azm1);
	
    if ( abs($s) < 0.01 ) {	
        #// distance < centimeter => congruency
        $$lat2 = $lat1;
        $$lon2 = $lon1;
        $$az2 = 180.0 + $az1;
	    $$az2 -= 360.0 if ( $$az2 > 360.0 );
	    $$az2 -= 360.0 if ( $$az2 > 360.0 );
        return 0;
    } elsif ( $FG_MIN < abs($cosphi1) ) {
        #// non-polar origin
        #// u1 is reduced latitude
        my $tanu1 = sqrt(1.0-$e2)*$sinphi1/$cosphi1;
        my $sig1 = atan2($tanu1,$cosaz1);
        my $cosu1 = 1.0/sqrt( 1.0 + $tanu1*$tanu1 );
        my $sinu1 = $tanu1*$cosu1;
        my $sinaz =  $cosu1*$sinaz1;
        my $cos2saz = 1.0-$sinaz*$sinaz;
        my $us = $cos2saz*$e2/(1.0-$e2);
        #// Terms
        my $ta = 1.0+$us*(4096.0+$us*(-768.0+$us*(320.0-175.0*$us)))/16384.0;
        my $tb = $us*(256.0+$us*(-128.0+$us*(74.0-47.0*$us)))/1024.0;
        my $tc = 0;
        #// FIRST ESTIMATE OF SIGMA (SIG)
        my $first = $s/($b*$ta);    #// !!
        my $sig = $first;
        my ($c2sigm, $sinsig,$cossig, $temp,$denom,$rnumer, $dlams, $dlam);
        do {
            $c2sigm = cos(2.0*$sig1+$sig);
            $sinsig = sin($sig);
            $cossig = cos($sig);
            $temp = $sig;
            $sig = $first + 
                $tb*$sinsig*($c2sigm+$tb*($cossig*(-1.0+2.0*$c2sigm*$c2sigm) - 
                $tb*$c2sigm*(-3.0+4.0*$sinsig*$sinsig)*
                (-3.0+4.0*$c2sigm*$c2sigm)/6.0)/4.0);
        } while ( abs($sig-$temp) > $testv);
        #// LATITUDE OF POINT 2
        #// DENOMINATOR IN 2 PARTS (TEMP ALSO USED LATER)
        $temp = $sinu1*$sinsig-$cosu1*$cossig*$cosaz1;
        $denom = (1.0-$f)*sqrt($sinaz*$sinaz+$temp*$temp);
        #// NUMERATOR
        $rnumer = $sinu1*$cossig+$cosu1*$sinsig*$cosaz1;
        $$lat2 = $FG_R2D * (atan2($rnumer,$denom));
        #// DIFFERENCE IN LONGITUDE ON AUXILARY SPHERE (DLAMS )
        $rnumer = $sinsig*$sinaz1;
        $denom = $cosu1*$cossig-$sinu1*$sinsig*$cosaz1;
        $dlams = atan2($rnumer,$denom);
        #// TERM C
        $tc = $f*$cos2saz*(4.0+$f*(4.0-3.0*$cos2saz))/16.0;
        #// DIFFERENCE IN LONGITUDE
        $dlam = $dlams-(1.0-$tc)*$f*$sinaz*($sig+$tc*$sinsig*
            ($c2sigm+
            $tc*$cossig*(-1.0+2.0*
            $c2sigm*$c2sigm)));
        $$lon2 = $FG_R2D * ($lam1+$dlam);
        $$lon2 -= 360.0 if ($$lon2 > 180.0 );
        $$lon2 += 360.0 if ($$lon2 < -180.0 );
        #// AZIMUTH - FROM NORTH
        $$az2 = $FG_R2D * (atan2(-$sinaz,$temp));
        $$az2 = 0.0 if ( abs($$az2) < $testv );
        $$az2 += 360.0 if( $$az2 < 0.0);
        return 0;
    } else {
        #// phi1 == 90 degrees, polar origin
        my $dM = $a*FG_M0($e2) - $s;
        my $paz = ( $phi1 < 0.0 ? 180.0 : 0.0 );
        my $zero = 0.0;
        return fg_geo_direct_wgs_84( $zero, $lon1, $paz, $dM, $lat2, $lon2, $az2 );
    } 
}

####################################################
######## SOME VERY ROUGH CALCULATIONS ########
# NOT VERY ACCUTATE DISTANCE WISE,
# BUT TAKES ONLY ABOUT 1/3 THE TIME OF THE ABOVE
# which becomes significant if doing multiple
# comparisons of distances !!! So these are good
# for quick compares only!!!!!!!!!!!
# The $FG_FACTOR used is only a GUESS???
####################################################

sub fg_ll2xyz($$) {
	my $lon = (shift) * $FG_D2R;
	my $lat = (shift) * $FG_D2R;
	my $cosphi = cos $lat;
	my $di = $cosphi * cos $lon;
	my $dj = $cosphi * sin $lon;
	my $dk = sin $lat;
	return ($di, $dj, $dk);
}

sub fg_xyz2ll($$$) {
	my ($di, $dj, $dk) = @_;
	my $aux = $di * $di + $dj * $dj;
	my $lat = atan2($dk, sqrt $aux) * $FG_R2D;
	my $lon = atan2($dj, $di) * $FG_R2D;
	return ($lon, $lat);
}

sub fg_coord_dist_sq($$$$$$) {
	my ($xa, $ya, $za, $xb, $yb, $zb) = @_;
	my $x = $xb - $xa;
	my $y = $yb - $ya;
	my $z = $zb - $za;
	return $x * $x + $y * $y + $z * $z;
}

sub fg_coord_distance_m($$$$$$) {
	my ($xa, $ya, $za, $xb, $yb, $zb) = @_;
    return (sqrt( fg_coord_dist_sq( $xa, $ya, $za, $xb, $yb, $zb ) ) * $FG_FACTOR);
}

sub fg_lat_lon_distance_m($$$$) {
    my ($lat1, $lon1, $lat2, $lon2) = @_;
    my ($xa, $ya, $za) = fg_ll2xyz($lon1, $lat1);
    my ($xb, $yb, $zb) = fg_ll2xyz($lon2, $lat2);
    return fg_coord_distance_m( $xa, $ya, $za, $xb, $yb, $zb );
}

sub myGeod_DEG_FT_ToCart($$) {
    my ($rgeod,$rcart) = @_;
    my $a = $FG_EQURAD;
    my $e2 = abs(1 - $FG_SQUASH*$FG_SQUASH);
    my $lat = ${$rgeod}[0];
    my $lon = ${$rgeod}[1];
    my $alt = ${$rgeod}[2];
    #print "SGGeod_DEG_FT_ToCart: $lat $lon $alt\n";

#void
#SGGeodesy::SGGeodToCart(const SGGeod& geod, SGVec3<double>& cart)
#{
#  // according to
#  // H. Vermeille,
#  // Direct transformation from geocentric to geodetic ccordinates,
#  // Journal of Geodesy (2002) 76:451-454
#  double lambda = geod.getLongitudeRad();
    my $lambda = $lon * $FG_D2R; # getLongitudeRad($rgeod);
#  double phi = geod.getLatitudeRad();
    my $phi    = $lat * $FG_D2R; # getLatitudeRad($rgeod);
#  double h = geod.getElevationM();
    my $h      = $alt * $FG_F2M; # getElevationM($rgeod);
#  double sphi = sin(phi);
    my $sphi = sin($phi);
#  double n = a/sqrt(1-e2*sphi*sphi);
    my $n = $a / sqrt( 1 - $e2 * $sphi * $sphi );
#  double cphi = cos(phi);
    my $cphi = cos($phi);
#  double slambda = sin(lambda);
    my $slambda = sin($lambda);
#  double clambda = cos(lambda);
    my $clambda = cos($lambda);
#  cart(0) = (h+n)*cphi*clambda;
#  cart(1) = (h+n)*cphi*slambda;
#  cart(2) = (h+n-e2*n)*sphi;
    my $x = ($h + $n) * $cphi * $clambda;
    my $y = ($h + $n) * $cphi * $slambda;
    my $z = ($h + $n - $e2 * $n) * $sphi;
    ${$rcart}[0] = $x;
    ${$rcart}[1] = $y;
    ${$rcart}[2] = $z;
    #print "SGGeod_DEG_FT_ToCart: $x $y $z\n";
}

sub myCart_To_Geod($$) {
    my ($rcart,$rgeod) = @_;
#void
#SGGeodesy::SGCartToGeod(const SGVec3<double>& cart, SGGeod& geod)
#{
#  // according to
#  // H. Vermeille,
#  // Direct transformation from geocentric to geodetic ccordinates,
#  // Journal of Geodesy (2002) 76:451-454
#  double X = cart(0);
    my $X = ${$rcart}[0];
#  double Y = cart(1);
    my $Y = ${$rcart}[1];
#  double Z = cart(2);
    my $Z = ${$rcart}[2];
#  double XXpYY = X*X+Y*Y;
    my $XXpYY = $X*$X + $Y*$Y;
#  if( XXpYY + Z*Z < 25 ) {
    if (($XXpYY + $Z*$Z) < 25) {
#    // This function fails near the geocenter region, so catch that special case here.
#    // Define the innermost sphere of small radius as earth center and return the 
#    // coordinates 0/0/-EQURAD. It may be any other place on geoide's surface,
#    // the Northpole, Hawaii or Wentorf. This one was easy to code ;-)
#    geod.setLongitudeRad( 0.0 );
        ${$rgeod}[0] = 0.0;     # longitude
#    geod.setLongitudeRad( 0.0 );
        ${$rgeod}[1] = 0.0;     # latitude
#    geod.setElevationM( -EQURAD );
        ${$rgeod}[2] = -$FG_EQURAD; # meters
        return;
    }
    my $ra2 = 1/($FG_EQURAD*$FG_EQURAD);
    my $e2 = abs(1 - $FG_SQUASH*$FG_SQUASH);
    my $e4 = $e2 * $e2;
#    
#  double sqrtXXpYY = sqrt(XXpYY);
    my $sqrtXXpYY = sqrt($XXpYY);
#  double p = XXpYY*ra2;
    my $p = $XXpYY * $ra2;
#  double q = Z*Z*(1-e2)*ra2;
    my $q = $Z*$Z*(1-$e2)*$ra2;
#  double r = 1/6.0*(p+q-e4);
    my $r = 1/6.0*($p+$q-$e4);
#  double s = e4*p*q/(4*r*r*r);
    my $s = $e4 * $p *$q / (4 * $r * $r * $r);
#/* 
#  s*(2+s) is negative for s = [-2..0]
#  slightly negative values for s due to floating point rounding errors
#  cause nan for sqrt(s*(2+s))
#  We can probably clamp the resulting parable to positive numbers
#*/
#  if( s >= -2.0 && s <= 0.0 )
#    s = 0.0;
    if (($s >= -2.0)&&($s <= 0.0)) {
        $s = 0.0;
    }
#  double t = pow(1+s+sqrt(s*(2+s)), 1/3.0);
    #my $t = pow(1 + $s + sqrt($s * (2 + $s)), 1/3.0);
    my $t = (1 + $s + sqrt($s * (2 + $s))) ** (1/3.0);
#  double u = r*(1+t+1/t);
    my $u = $r * (1 + $t + 1/$t);
#  double v = sqrt(u*u+e4*q);
    my $v = sqrt($u * $u + $e4 * $q);
#  double w = e2*(u+v-q)/(2*v);
    my $w = $e2 * ($u + $v - $q) / (2 * $v);
#  double k = sqrt(u+v+w*w)-w;
    my $k = sqrt($u + $v + $w * $w) - $w;
#  double D = k*sqrtXXpYY/(k+e2);
    my $D = $k * $sqrtXXpYY / ($k + $e2);
#  geod.setLongitudeRad(2*atan2(Y, X+sqrtXXpYY));
    my $lonRad = (2 * atan2($Y, $X + $sqrtXXpYY));
#  double sqrtDDpZZ = sqrt(D*D+Z*Z);
    my $sqrtDDpZZ = sqrt($D * $D + $Z * $Z);
#  geod.setLatitudeRad(2*atan2(Z, D+sqrtDDpZZ));
    my $latRad = (2 * atan2($Z, $D + $sqrtDDpZZ));
#  geod.setElevationM((k+e2-1)*sqrtDDpZZ/k);
    my $elevM = (($k+$e2-1)*$sqrtDDpZZ/$k);

    my $lat = $latRad * $FG_R2D;
    my $lon = $lonRad * $FG_R2D;
    my $alt = $elevM  * $FG_M2F;

    ${$rgeod}[0] = $lat;
    ${$rgeod}[1] = $lon;
    ${$rgeod}[2] = $alt;

}

sub func_floor($) {
    my $v = shift;
    $v = $v < 0.0 ? -int(-$v) - 1 : int($v);
    return $v;
}

1;

# eof - fg_wgs84.pl

