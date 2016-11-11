#!/usr/bin/env perl6

use JSON::Tiny;

# <trkpt lat="-35.7237188" lon="148.8175634">
# <ele>1283.370</ele>
# <time>2016-10-28T00:46:10.000Z</time>

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

#my %map_data = from-json slurp('data/nsw25k.json');

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


say '<svg width="2000px" height="2000px">';
#say '<svg width="' ~ $width.Int + $border*2 ~ '" height="' ~ $height.Int + $border*2 ~
#    '" style="">';

say '<image xlink:href="' ~ $tile ~ '" width="2000px" height="2000px" x="0" y="0" style="z-index:0;opacity:1;"/>';

my $lastx;
my $lasty;
my $laste;

my $time_mark_secs = 15 * 60;
my $time_mark_radius = 5;
my $last_time_mark = @points[0]<tim>.Instant.Int;

my $dist_mark_m = 1000;
my $last_dist_mark = 0;

for @points -> $p {
    my ($x, $y) = coords($p<lat>, $p<lon>);
    if $lastx {
	if $p<tim>.Instant.Int > $last_time_mark + $time_mark_secs {
	    say '<circle cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="' ~ $time_mark_radius ~ '"' ~
	        ' fill="black" style="opacity:0.25;z-index:1;"/>';
	    $last_time_mark += $time_mark_secs;
	}

	my $climb = $p<ele> - $laste;
	say '<line x1="' ~ $lastx ~ '" y1="' ~ $lasty ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '"' ~
	    ' style="stroke:' ~ ($climb > 0 ?? 'red' !! 'blue')  ~ ';stroke-width:1;z-index:2;"/>';
    }
    $lastx = $x;
    $lasty = $y;
    $laste = $p<ele>
}
say '</svg>';



say '</body></html>';

sub coords($lat, $lon) {
    my $x = ($lon - %bounds<lon>.min) * $scale;
    my $y = $height - ($lat - %bounds<lat>.min) * $scale;
    ($x.Int + $border, $y.Int + $border);
}
