#!/usr/bin/env perl6

use JSON::Tiny;

# <trkpt lat="-35.7237188" lon="148.8175634">
# <ele>1283.370</ele>
# <time>2016-10-28T00:46:10.000Z</time>

my $tile_url = 'http://home.whaite.com/fet/imgraw/NSW_25k_Coast_South';

class Bounds {
    has $.min;
    has $.max;

    method add($val) {
	$!min = $val if !$!min.defined || $val < $!min;
	$!max = $val if !$!max.defined || $val > $!max;
    }
}

my @points;
my %bounds = lat => Bounds.new,
             lon => Bounds.new,
             ele => Bounds.new,
             tim => Bounds.new;
my $title;
my $date;

#my @map_data = (from-json slurp('data/nsw25k_12_12.json'))[0];

for slurp.lines -> $line {
    given $line {
	when /'<trkpt' \s+ 'lat="' (.*) '"' \s+ 'lon="' (.*) '">'/ {
	    # say "point $0 $1";
	    my %pt = lat => $0.Rat, lon => $1.Rat;
	    @points.push(%pt);
	    %bounds<lat>.add($0.Rat);
	    %bounds<lon>.add($1.Rat);
	}
	when /'<ele>' (.*) '</ele>'/ {
	    # say "elevation $0";
	    @points[@points.elems-1]<ele> = $0.Rat;
	    %bounds<ele>.add($0.Rat);
	}
	when /'<time>' (.*) '</time>'/ {
	    # say "time $0";
	    my $tim = DateTime.new($0.Str);
	    @points[@points.elems-1]<tim> = $tim;
	    %bounds<tim>.add($tim.Instant.Int);
	}
	when /'<name>' (.+) '</name>'/ {
	    $title = $0.Str;
	}
	when /'<desc>' (.+) '</desc>'/ {
	    $date = $0.Str;
	}
    }
}

#say %bounds;

my $lat_range = %bounds<lat>.max - %bounds<lat>.min;
my $lon_range = %bounds<lon>.max - %bounds<lon>.min;

my $max_dim = 800;
my $border = 20;
my $width;
my $height;
my $scale;

sub in_range($x, $min, $max) {
    $x >= $min && $x <= $max;
}

# find the tiles we will need
my @map_data;
my $ban = %bounds<lat>.min;
my $bax = %bounds<lat>.max;
my $bon = %bounds<lon>.min;
my $box = %bounds<lon>.max;

#say "LAT: $ban $bax";
#say "LON: $bon $box";

my $json = from-json slurp('data/nsw25k.json');

for @$json -> $md {
    my $max_lat = ($md<topleft><lat>, $md<topright><lat>).max;
    my $min_lat = ($md<bottomleft><lat>, $md<bottomright><lat>).min;

    my $min_lon = ($md<topleft><long>, $md<bottomleft><long>).min;
    my $max_lon = ($md<topright><long>, $md<bottomright><long>).min;

#    say "LAT: $min_lat $max_lat";
#    say "LON: $min_lon $max_lon";

    if (
	(in_range($ban, $min_lat, $max_lat) && in_range($bon, $min_lon, $max_lon)) ||
	(in_range($ban, $min_lat, $max_lat) && in_range($box, $min_lon, $max_lon)) ||
	(in_range($bax, $min_lat, $max_lat) && in_range($bon, $min_lon, $max_lon)) ||
	(in_range($bax, $min_lat, $max_lat) && in_range($box, $min_lon, $max_lon)) ||
	(in_range($min_lat, $ban, $bax) && in_range($min_lon, $bon, $box)) ||
	(in_range($min_lat, $ban, $bax) && in_range($max_lon, $bon, $box)) ||
	(in_range($max_lat, $ban, $bax) && in_range($min_lon, $bon, $box)) ||
	(in_range($max_lat, $ban, $bax) && in_range($max_lon, $bon, $box))
       ) {
	@map_data.push: $md;
    }
}

#say @map_data.join("\n\n");

my $tilex = Bounds.new;
my $tiley = Bounds.new;

for @map_data -> $md {
    $tilex.add($md<tilex>);
    $tiley.add($md<tiley>);
}

my $tile = 'data/NSW_25k_Coast_South_12_12.jpg';

if $lat_range > $lon_range {
    $height = $max_dim;
    $scale = $height / $lat_range;
    $width = $lon_range * $scale;
} else {
    $width = $max_dim;
    $scale = $width / $lon_range;
    $height = $lat_range * $scale;
}

#say $width.Int ~ ' x ' ~ $height.Int;

say '<html><head><title>' ~ $title ~ '</title></head><body>';
say '<h2>' ~ $title ~ ' - ' ~ $date ~ '</h2>';
#say '<div><img src="' ~ $tile ~ '"></div>';

say '<div><svg width="' ~ $width.Int + $border*2 ~ '" height="120">';
my $time_range = %bounds<tim>.max - %bounds<tim>.min;
my $elevation_range = %bounds<ele>.max - %bounds<ele>.min;
for @points -> $p {
    my $x = ($p<tim>.Instant.Int - %bounds<tim>.min) / $time_range * $width + $border;
    my $y = 100 - ($p<ele> - %bounds<ele>.min) / $elevation_range * 100 + 10;
    say '<circle cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="1" fill="black"/>';
}
say '</svg></div>';


$width = ($tilex.max - $tilex.min + 1) * 2000;
$height = ($tiley.max - $tiley.min + 1) * 2000;
say '<svg width="' ~ $width ~ 'px" height="' ~ $height ~ 'px">';
#say '<svg width="' ~ $width.Int + $border*2 ~ '" height="' ~ $height.Int + $border*2 ~
#    '" style="">';

sub tile_ref($name) {
    $tile_url ~ '/' ~ $name;
}

for @map_data -> $md {
    say '<image xlink:href="' ~ tile_ref($md<filename>) ~
    '" width="2000px" height="2000px" x="' ~ ($md<tilex> - $tilex.min)*2000 ~
    '" y="' ~ ($md<tiley> - $tiley.min)*2000  ~ '" style="z-index:0;opacity:1;"/>';
}

my $lastx;
my $lasty;
my $laste;
my $lastp;

my $time_mark_secs = 15 * 60;
my $time_mark_radius = 10;
my $last_time_mark = @points[0]<tim>.Instant.Int;

constant R = 6371000; # radius of Earth in metres
my $dist_mark = 1000;
my $dist_mark_radius = 10;
my $last_dist_mark = 0;
my $total_dist = 0;
my $dist_mark_count = 0;
my $time_mark_count = 0;

my $tile_x = 2000;
my $tile_y = 2000;

for @points -> $p {
    my ($x, $y) = coords($p<lat>, $p<lon>, @map_data[0]);
    if $lastp {
	my $dist = calculate_distance($lastp, $p);
#	say $dist;
	$total_dist += $dist;

	if $total_dist > $last_dist_mark + $dist_mark {
	    $dist_mark_count++;
	    say '<circle cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="' ~ $dist_mark_radius ~ '"' ~
	        ' fill="yellow" style="opacity:0.5;z-index:1;"/>';
	    say '<text x="' ~ ($x.Int - 5) ~ '" y="' ~ ($y.Int - 5) ~
	        '" font-size="10">' ~ $dist_mark_count ~ '</text>';
	    $last_dist_mark += $dist_mark;
	}
	
	if $p<tim>.Instant.Int > $last_time_mark + $time_mark_secs {
	    $time_mark_count++;
	    say '<circle cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="' ~ $time_mark_radius ~ '"' ~
	        ' fill="black" style="opacity:0.25;z-index:1;"/>';
	    say '<text x="' ~ ($x.Int - 5) ~ '" y="' ~ ($y.Int - 5) ~
	        '" font-size="10">' ~ $time_mark_count ~ '</text>';
	    $last_time_mark += $time_mark_secs;
	}

	my Rat $climb = $p<ele> - $laste;
	my $climb_color = $climb > 0.0 ?? 'red' !! 'blue';
	say '<line x1="' ~ $lastx ~ '" y1="' ~ $lasty ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '"' ~
	    ' style="stroke:' ~ $climb_color  ~ ';opacity:0.75;stroke-width:3;z-index:2;"/>';
    }
    $lastx = $x;
    $lasty = $y;
    $laste = $p<ele>;
    $lastp = $p;
}
say '</svg>';

say '<p>' ~ $total_dist/1000 ~ '</p>';
say '</body></html>';


sub coords($lat, $lon, %tile) {
    my $x_t = (($lon - %tile<topleft><long>) / (%tile<topright><long> - %tile<topleft><long>)) * $tile_x;
    my $x_b = (($lon - %tile<bottomleft><long>) / (%tile<bottomright><long> - %tile<bottomleft><long>)) * $tile_x;
    my $y_l = (($lat - %tile<topleft><lat>) / (%tile<bottomleft><lat> - %tile<topleft><lat>)) * $tile_y;
    my $y_r = (($lat - %tile<topright><lat>) / (%tile<bottomright><lat> - %tile<topright><lat>)) * $tile_y;

    my $x_slope = ($x_b - $x_t) / $tile_y;
    my $y_slope = ($y_r - $y_l) / $tile_x;

    my $x = ($y_l * $x_slope + $x_t) / (1 - $x_slope * $y_slope);
    my $y = ($x_t * $y_slope + $y_l) / (1 - $y_slope * $x_slope);
    
    ($x.Int, $y.Int);
}


sub calculate_distance($from, $to) {
    my $from_lat = to_r($from<lat>);
    my $to_lat = to_r($to<lat>);
    my $lat_d = to_r($to<lat> - $from<lat>);
    my $lon_d = to_r($to<lon> - $from<lon>);

    my $a = sin($lat_d/2) ** 2 + cos($from_lat) * cos($to_lat) * sin($lon_d/2) ** 2;
    my $c = 2 * atan2(sqrt($a), sqrt(1-$a));

    R * $c;
}


sub to_r($degrees) { $degrees * pi/180 }
