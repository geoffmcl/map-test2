# Bucket.pm
#
# Copyright (c) 2009 Geoff R McLane <ubuntu@geoffair.info>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Bucket - class implementation
package Bucket;

use strict;
use Carp;

#our(@ISA, $VERSION);
#@ISA = qw(Bucket);
our($VERSION);
$VERSION = "0.2";

my $BUCKET_SPAN = 0.125;
my $HALF_BUCKET_SPAN = ( 0.5 * $BUCKET_SPAN );
#/** For divide by zero avoidance, this will be close enough to zero */
my $B_EPSILON = 0.0000001;
my $SGD_PI = 3.14159265358979323846; #/* From M_PI under Linux/X86 */
my $SGD_DEGREES_TO_RADIANS = ($SGD_PI/180.0);
#/** Value of earth radius from LaRCsim (meter) */
my $SG_EQUATORIAL_RADIUS_M = 6378138.12;
#/** 2 * PI */
my $SGD_2PI = 6.28318530717958647692;

#############################################
## the object constructor                  ##
#############################################
sub new {
   my $class = shift;
   if(@_ % 2) {
      croak "Default options must be name=>value pairs (odd number supplied)";
   }
   my %arg = @_;
   my $self  = {};
   #$self->{LON}  = undef;
   #$self->{LAT}  = undef;
   #$self->{X}    = undef;
   #$self->{Y}    = undef;
   $self->{LON}  = -1000;
   $self->{LAT}  = -1000;
   $self->{X}    = -1;
   $self->{Y}    = -1;
   bless ($self, $class);
   #$self->init( -1000, -1000, 0, 0 );
   return $self;
}

##############################################
## methods to access per-object data        ##
## With args, they set the value.  Without  ##
## any, they only retrieve it/them.         ##
##############################################
sub lon {
    my $self = shift;
    if (@_) { $self->{LON} = shift }
    return $self->{LON};
}

sub lat {
    my $self = shift;
    if (@_) { $self->{LAT} = shift }
    return $self->{LAT};
}

sub get_x {
    my $self = shift;
    if (@_) { $self->{X} = shift }
    return $self->{X};
}

sub get_y {
    my $self = shift;
    if (@_) { $self->{Y} = shift }
    return $self->{Y};
}

sub init {
   my ($self, $lon, $lat, $x, $y) = @_;
   $self->lon($lon);
   $self->lat($lat);
   $self->get_x($x);
   $self->get_y($y);
}

sub bucket_info {
   my $self = shift;
   my $lat = $self->lat();
   return "Un-initialised Bucket" if ($lat == -1000);
   return "".$self->lon().":$lat:".$self->get_x().":".$self->get_y(). #":".$self->bucket_span($lat).
      ":".$self->gen_base_path()."/".$self->gen_index();
}

#// return the horizontal tile span factor based on latitude
#static double sg_bucket_span( double l ) {
sub bucket_span {
   my ($self, $l) = @_;
    if ( $l >= 89.0 ) {
	return 360.0;
    } elsif ( $l >= 88.0 ) {
	return 8.0;
    } elsif ( $l >= 86.0 ) {
	return 4.0;
    } elsif ( $l >= 83.0 ) {
	return 2.0;
    } elsif ( $l >= 76.0 ) {
	return 1.0;
    } elsif ( $l >= 62.0 ) {
	return 0.5;
    } elsif ( $l >= 22.0 ) {
	return 0.25;
    } elsif ( $l >= -22.0 ) {
	return 0.125;
    } elsif ( $l >= -62.0 ) {
	return 0.25;
    } elsif ( $l >= -76.0 ) {
	return 0.5;
    } elsif ( $l >= -83.0 ) {
	return 1.0;
    } elsif ( $l >= -86.0 ) {
	return 2.0;
    } elsif ( $l >= -88.0 ) {
	return 4.0;
    } elsif ( $l >= -89.0 ) {
	return 8.0;
    } # else {
	return 360.0;
    #}
}

#// Set the bucket params for the specified lat and lon
#void SGBucket::set_bucket( double dlon, double dlat ) {
sub set_bucket()
{
   my ($self, $dlon, $dlat) = @_;
   my ($lon, $lat, $x, $y);
   # //
   # // latitude first
   # //
   # double span = sg_bucket_span( dlat );
   # double diff = dlon - (double)(int)dlon;
   my $span = $self->bucket_span( $dlat );
   my $diff = $dlon - int($dlon);
   #// cout << "diff = " << diff << "  span = " << span << endl;

   if ( ($dlon >= 0) || (abs($diff) < $B_EPSILON) ) {
      $lon = int($dlon);
   } else {
      $lon = int($dlon - 1);
   }

   #// find subdivision or super lon if needed
   if ( $span < $B_EPSILON ) {
      #// polar cap
      $lon = 0;
      $x = 0;

   } elsif ( $span <= 1.0 ) {
      $x = int(($dlon - $lon) / $span);
   } else {
      if ( ($dlon >= 0) || (abs($diff) < $B_EPSILON) ) {
         $lon = int( int($lon / $span) * $span);
	   } else {
	      #// cout << " lon = " << lon 
	      #//  << "  tmp = " << (int)((lon-1) / span) << endl;
	      $lon = int( int(($lon + 1) / $span) * $span - $span);
	      if ( $lon < -180 ) {
            $lon = -180;
	      }
	   }
   	$x = 0;
   }
   # //
   # // then latitude
   # //
   $diff = $dlat - int($dlat);

   if ( ($dlat >= 0) || (abs($diff) < $B_EPSILON) ) {
      $lat = int($dlat);
   } else {
      $lat = int($dlat - 1);
   }
   $y = int(($dlat - $lat) * 8);

   $self->lon($lon);
   $self->lat($lat);
   $self->get_x($x);
   $self->get_y($y);

}

#sub set_bucket_new {
#   my ($self, $dlon, $dlat) = @_;
#   my ($lon, $lat, $x, $y);
#   my $span = $self->bucket_span( $dlat );
#   my $diff = fmod($dlon - int($dlon);
#}

#// Parse a unique scenery tile index and find the lon, lat, x, and y
#SGBucket::SGBucket(const long int bindex) {
#    long int index = bindex;
sub set_bucket_per_index {
   my ($self, $index) = @_;
   my ($lon, $lat, $x, $y);
   $lon = $index >> 14;
   $index -= $lon << 14;
   $lon -= 180;
   $lat = $index >> 6;
   $index -= $lat << 6;
   $lat -= 90;
   $y = $index >> 3;
   $index -= $y << 3;
   $x = $index;
   $self->lon($lon);
   $self->lat($lat);
   $self->get_x($x);
   $self->get_y($y);
}

sub gen_index {
   my ($self) = shift;
   my ($lon, $lat, $x, $y);
   $lon = $self->lon();
   $lat = $self->lat();
   $x = $self->get_x();
   $y = $self->get_y();
   return (($lon + 180) << 14) + (($lat + 90) << 6) + ($y << 3) + $x;
}

#// Build the path name for this bucket
#string SGBucket::gen_base_path() const {
sub gen_base_path() {
   my ($self) = shift;
   my ($top_lon, $top_lat, $main_lon, $main_lat);
   my ($hem, $pole);
   my ($lon, $lat, $x, $y);
   $lon = $self->lon();
   $lat = $self->lat();
   $x = $self->get_x();
   $y = $self->get_y();
   # char raw_path[256];

   $top_lon = int($lon / 10);
   $main_lon = int($lon);
   if ( ($lon < 0) && ($top_lon * 10 != $lon) ) {
      $top_lon -= 1;
   }
   $top_lon *= 10;
   if ( $top_lon >= 0 ) {
      $hem = 'e';
   } else {
   	$hem = 'w';
      $top_lon *= -1;
   }
   if ( $main_lon < 0 ) {
      $main_lon *= -1;
   }
    
   $top_lat = int($lat / 10);
   $main_lat = int($lat);
   if ( ($lat < 0) && ($top_lat * 10 != $lat) ) {
      $top_lat -= 1;
   }
   $top_lat *= 10;
   if ( $top_lat >= 0 ) {
      $pole = 'n';
   } else {
       $pole = 's';
       $top_lat *= -1;
   }
   if ( $main_lat < 0 ) {
	   $main_lat *= -1;
   }

   return sprintf("$hem%03d$pole%02d/$hem%03d$pole%02d",
	    $top_lon, $top_lat, 
	    $main_lon, $main_lat);

   # SGPath path( raw_path );
   # return path.str();
}

#    /**
#     * @return the center lon of a tile.
#     */
#    inline double get_center_lon() const {
sub get_center_lon {
   my ($self) = shift;
   my ($lon, $lat, $x, $y);
   $lon = $self->lon();
   $lat = $self->lat();
   $x = $self->get_x();
   $y = $self->get_y();
   my $span = $self->bucket_span( $lat + $y / 8.0 + $HALF_BUCKET_SPAN );
	if ( $span >= 1.0 ) {
	    return $lon + $span / 2.0;
	}
   return $lon + $x * $span + $span / 2.0;
}

#    /**
#     * @return the center lat of a tile.
#     */
#    inline double get_center_lat() const {
sub get_center_lat {
   my ($self) = shift;
   my ($lat, $y);
   $lat = $self->lat();
   $y = $self->get_y();
	return $lat + $y / 8.0 + $HALF_BUCKET_SPAN;
}

#// return width of the tile in degrees
#double SGBucket::get_width() const {
sub get_width {
   my ($self) = shift;
   return $self->bucket_span( $self->get_center_lat() );
}

#// return height of the tile in degrees
#double SGBucket::get_height() const {
sub get_height {
   my ($self) = shift;
   return $BUCKET_SPAN;
}

#// return width of the tile in meters
#double SGBucket::get_width_m() const {
sub get_width_m {
   my ($self) = shift;

   my $centlat = $self->get_center_lat();
   my $clat = int($centlat);
   if ( $clat > 0.0 ) {
      $clat = int($clat + 0.5);
   } else {
      $clat = int($clat - 0.5);
   }
   my $clat_rad = $clat * $SGD_DEGREES_TO_RADIANS;
   my $cos_lat = cos( $clat_rad );
   my $local_radius = $cos_lat * $SG_EQUATORIAL_RADIUS_M;
   my $local_perimeter = $local_radius * $SGD_2PI;
   my $degree_width = $local_perimeter / 360.0;
   return ($self->bucket_span( $centlat ) * $degree_width);
}


#// return height of the tile in meters
# double SGBucket::get_height_m() const {
sub get_height_m {
   my ($self) = shift;
   my $perimeter = $SG_EQUATORIAL_RADIUS_M * $SGD_2PI;
   my $degree_height = $perimeter / 360.0;
   return ($BUCKET_SPAN * $degree_height);
}

#    /**
#     * @return the corner of the bucket
#     */
#    SGGeod get_corner(unsigned num) const
sub get_corner {
   my ($self, $num) = @_;
   my $lonFac = (($num + 1) & 2) ? 0.5 : -0.5;
   my $latFac = (($num    ) & 2) ? 0.5 : -0.5;
   return ( $self->get_center_lon() + ( $lonFac * $self->get_width() ),
      $self->get_center_lat() + ( $latFac * $self->get_height() ) );
}

# Next bucket   or in letters
# 6 |  5  | 4   TL | TC | TR
#   ----------  ------------
# 7 | RB  | 3   CL | RB | CR
#   ----------  ------------
# 0 |  1  | 2   BL | BC | BR
# so order is
# 0=BL 1=BC 2=BR 3=CR 4=TR 5=TC 6=TL 7=CL
# Given a reference bucket, get the touching bucket, starting 
sub get_next_bucket {
   my ($self, $num) = @_;
   my ($clon, $clat, $cx, $cy, $nlon, $nlat);
   $clon = $self->get_center_lon();
   $clat = $self->get_center_lat();
   $cx = $self->get_width();
   $cy = $self->get_height();
   if ($num == 0) {
      $nlon = $clon - $cx;
      $nlat = $clat + $cy;
   } elsif ($num == 1) {
      $nlon = $clon;
      $nlat = $clat + $cy;
   } elsif ($num == 2) {
      $nlon = $clon + $cx;
      $nlat = $clat - $cy;
   } elsif ($num == 3) {
      $nlon = $clon + $cx;
      $nlat = $clat;
   } elsif ($num == 4) {
      $nlon = $clon + $cx;
      $nlat = $clat + $cy;
   } elsif ($num == 5) {
      $nlon = $clon;
      $nlat = $clat - $cy;
   } elsif ($num == 6) {
      $nlon = $clon - $cx;
      $nlat = $clat - $cy;
   } else {  # ($num == 7) or other values
      $nlon = $clon - $cx;
      $nlat = $clat;
   }
   my $nb = Bucket->new();
   $nb->set_bucket( $nlon, $nlat );
   return $nb;
}

sub buckets_equal {
   my ($self, $b1, $b2) = @_;
   my ($lon1, $lat1, $x1, $y1);
   my ($lon2, $lat2, $x2, $y2);

   $lon1 = $b1->lon();
   $lat1 = $b1->lat();
   $x1   = $b1->get_x();
   $y1   = $b1->get_y();

   $lon2 = $b2->lon();
   $lat2 = $b2->lat();
   $x2   = $b2->get_x();
   $y2   = $b2->get_y();
   if (($lon1 == $lon2)&&
       ($lat1 == $lat2)&&
       ($x1 == $x2)&&
       ($y1 == $y2)) {
      return 1;
   }
   return 0;
}



1;  # so the require or use succeeds
