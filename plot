#!/usr/bin/env perl6

use JSON::Tiny;

# <trkpt lat="-35.7237188" lon="148.8175634">
# <ele>1283.370</ele>
# <time>2016-10-28T00:46:10.000Z</time>

constant R = 6371000; # radius of Earth in metres

my $buttons = 0;
my $tile_url = 'http://home.whaite.com/fet/imgraw/NSW_25k_Coast_South';
my $points_file = './data/points.json';

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
             tim => Bounds.new,
             dst => Bounds.new,
	     spd => Bounds.new;

my $title;
my $date;
my $pid = 1;
my %pt;

say '<html><head>';

say '<script>';
say 'var points = [];';
say 'var point_ix = 0;';
say 'var animation_rate = 1;';
say 'var keep_point_centered = false;';

for slurp.lines -> $line {
    given $line {
	when /'<trkpt' \s+ 'lat="' (.*) '"' \s+ 'lon="' (.*) '">'/ {
	    @points.push(%pt.clone) if %pt;
	    %pt = lat => $0.Rat, lon => $1.Rat, id => $pid++;
	    %bounds<lat>.add($0.Rat);
	    %bounds<lon>.add($1.Rat);
            if @points.tail {
	        %pt<dst> = calculate_distance(@points.tail, %pt);
	        %bounds<dst>.add(%pt<dst>);
            }
	    say 'points.push({});';
	    say 'points.slice(-1)[0]["lat"] = ' ~ %pt<lat> ~ ';';
	    say 'points.slice(-1)[0]["lon"] = ' ~ %pt<lon> ~ ';';
	    say 'points.slice(-1)[0]["dst"] = ' ~ (%pt<dst> || 0) ~ ';';
	}
	when /'<ele>' (.*) '</ele>'/ {
	    %pt<ele> = $0.Rat;
	    %bounds<ele>.add($0.Rat);
	    say 'points.slice(-1)[0]["ele"] = ' ~ %pt<ele> ~ ';';
	}
	when /'<time>' (.*) '</time>'/ {
	    my $tim = DateTime.new($0.Str);
	    %pt<tim> = $tim;
	    %bounds<tim>.add($tim.Instant.Rat);
	    if @points.tail && %pt<tim>.Instant.Rat > @points.tail<tim>.Instant.Rat {
	        %pt<spd> = %pt<dst> / (%pt<tim>.Instant.Rat - @points.tail<tim>.Instant.Rat);
	        %bounds<spd>.add(%pt<spd>) if %pt<spd> < 5;
            }
	    # 2017-09-01T01:13:28.999000Z
	    say 'points.slice(-1)[0]["date"] = (new Date("' ~ %pt<tim> ~ '"));';
	    say 'points.slice(-1)[0]["tim"] = points.slice(-1)[0]["date"].toLocaleTimeString();';
	    say 'points.slice(-1)[0]["spd"] = ' ~ (%pt<spd> || 0) ~ ';';
	}
	when /'<name>' (.+) '</name>'/ {
	    $title = $0.Str;
	}
	when /'<desc>' (.+) '</desc>'/ {
	    $date = $0.Str;
	}
    }
}

@points.push(%pt.clone);

say '</script>';
say '<title>' ~ $title ~ '</title>';

my $lat_range = %bounds<lat>.max - %bounds<lat>.min;
my $lon_range = %bounds<lon>.max - %bounds<lon>.min;

my $max_dim = 800;
my $border = 20;
my $width;
my $height;
my $scale;

# find the tiles we will need
my @map_data;
my $ban = %bounds<lat>.min;
my $bax = %bounds<lat>.max;
my $bon = %bounds<lon>.min;
my $box = %bounds<lon>.max;

my $pban = $ban - 0.04;
my $pbax = $bax + 0.04;
my $pbon = $bon - 0.04;
my $pbox = $box + 0.04;

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
	(in_box($pban, $pbon, $min_lat, $min_lon, $max_lat, $max_lon)) ||
	(in_box($pban, $pbox, $min_lat, $min_lon, $max_lat, $max_lon)) ||
	(in_box($pbax, $pbon, $min_lat, $min_lon, $max_lat, $max_lon)) ||
	(in_box($pbax, $pbox, $min_lat, $min_lon, $max_lat, $max_lon)) ||

	(in_box($min_lat, $min_lon, $pban, $pbon, $pbax, $pbox)) ||
	(in_box($min_lat, $max_lon, $pban, $pbon, $pbax, $pbox)) ||
	(in_box($max_lat, $min_lon, $pban, $pbon, $pbax, $pbox)) ||
	(in_box($max_lat, $max_lon, $pban, $pbon, $pbax, $pbox))
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


say '<script>';

say q:to/END/;
  window.onload = function(e) {
    var wrap = document.getElementById("plotmap-wrapper");
    var vb = viewbox_to_a();

    var left_padding = vb[2] / wrap.clientWidth * 40;
    vb[0] -= left_padding;
    vb[2] += left_padding;

    var top_padding = vb[3] / wrap.clientHeight * 120;
    vb[1] -= top_padding;
    vb[3] += top_padding;

    var aspect = wrap.clientWidth / wrap.clientHeight;
    if (aspect > 1) { vb[0] -= (vb[3] * aspect - vb[2])/2; vb[2] = vb[3] * aspect; }
    if (aspect < 1) { vb[1] -= (vb[2] * aspect - vb[3])/2; vb[3] = vb[2] / aspect; }
    document.getElementById("plotmap").setAttribute("viewBox", a_to_viewbox(vb));
    original_viewbox = document.getElementById("plotmap").getAttribute("viewBox");

    show_point(point_ix);
  }

  function show_point(ix) {
    var pl = document.getElementById("line-" + ix);
    if (pl == null) { return; }

    var pt = document.getElementById("point-target");
    pt.setAttribute("cx", pl.getAttribute("x2"));
    pt.setAttribute("cy", pl.getAttribute("y2"));

    document.getElementById("point-tim").innerHTML = points[ix].tim;
    document.getElementById("point-lat").innerHTML = "Lat: " + points[ix].lat;
    document.getElementById("point-lon").innerHTML = "Lon: " + points[ix].lon;
    document.getElementById("point-ele").innerHTML = "Ele: " + parseInt(points[ix].ele) + "m";
//    document.getElementById("point-dst").innerHTML = points[ix].dst;
    document.getElementById("point-spd").innerHTML = parseInt(points[ix].spd / 1000 * 3600 * 100)/100 + ' kph';

    hideGraphMark(point_ix);
    showGraphMark(ix);

    document.getElementById("line-" + point_ix).style.strokeWidth = 12;
    pl.style.strokeWidth = 40;
    
    point_ix = ix;

    if (keep_point_centered) { center_on_point(); }
  }
END

say '</script>';
say '</head>';
say '<body style="margin:0px;overflow:hidden;">';


my $tile_x = 2000;
my $tile_y = 2000;

#$width = ($tilex.max - $tilex.min + 1) * 2000;
#$height = ($tiley.max - $tiley.min + 1) * 2000;
my ($bxn, $byn) = coords($ban, $bon, @map_data[0]);
my ($bxx, $byx) = coords($bax, $box, @map_data[0]);
say '<div id="plotmap-wrapper" style="position:relative;" width="100%" height="100%">';
say '<svg id="plotmap" width="100%" height="100%" viewBox="' ~ $bxn-100 ~ ' ' ~ $byx-100 ~ ' ' ~ $bxx-$bxn+200 ~  ' ' ~ $byn-$byx+200 ~ '">';

for @map_data -> $md {
    say '<image xlink:href="' ~ tile_ref($md<filename>) ~
    '" width="2000px" height="2000px" x="' ~ ($md<tilex> - $tilex.min)*2000 ~
    '" y="' ~ ($md<tiley> - $tiley.min)*2000  ~ '" style="z-index:0;opacity:1;"/>';
}


my $lastx;
my $lasty;
my $laste;
my $lastt;
my $lastp;

my $time_mark_secs = 15 * 60;
my $time_mark_radius = 12;
my $last_time_mark = @points[0]<tim>.Instant.Rat;

my $dist_mark = 1000;
my $dist_mark_radius = 12;
my $last_dist_mark = 0;
my $total_dist = 0;
my $total_climb = 0;
my $start_time = 0;
my $current_rest_time = 0;
my $total_rest_time = 0;
my $dist_mark_count = 0;
my $time_mark_count = 0;

for @points.kv -> $ix, $p {
    my ($x, $y) = coords($p<lat>, $p<lon>, @map_data[0]);
    if $lastp {
	$total_dist += $p<dst>;

	if $p<dst> < 0.1 {
	    $current_rest_time += $p<tim> - $lastt;
	} else {
	    $current_rest_time += $p<tim> - $lastt if $current_rest_time;
	    
	    if $current_rest_time > 180 {
		$total_rest_time += $current_rest_time;
		say '<circle class="rest-mark" cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="' ~ $dist_mark_radius ~ '"' ~
		' fill="blue" style="opacity:0.5;z-index:1;"/>';
	    }
	    $current_rest_time = 0;
	}

	if $total_dist > $last_dist_mark + $dist_mark {
	    $dist_mark_count++;
	    say '<circle class="dist-mark" cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="' ~ $dist_mark_radius ~ '"' ~
	        ' fill="red" style="opacity:0.5;z-index:1;"/>';
	    say '<text class="dist-mark" x="' ~ ($x.Int - 5) ~ '" y="' ~ ($y.Int - 5) ~
	        '" font-size="12">' ~ $dist_mark_count ~ '</text>';
	    $last_dist_mark += $dist_mark;
	}
	
	if $p<tim>.Instant.Int > $last_time_mark + $time_mark_secs {
	    $time_mark_count++;
	    say '<circle class="time-mark" cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="' ~ $time_mark_radius ~ '"' ~
	        ' fill="black" style="opacity:0.25;z-index:1;"/>';
	    say '<text class="time-mark" x="' ~ ($x.Int - 5) ~ '" y="' ~ ($y.Int - 5) ~
	        '" font-size="12">' ~ $time_mark_count ~ '</text>';
	    $last_time_mark += $time_mark_secs;
	}

	my Rat $climb = $p<ele> - $laste;
	$total_climb += $climb if $climb > 0.0;
	my $climb_color = $climb > 0.0 ?? '#ff3333' !! '#3333ff';
        say '<line x1="' ~ $lastx ~ '" y1="' ~ $lasty ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '" style="stroke:black;opacity:0.9;stroke-width:1;z-index:1"/>';
	say '<line id="line-' ~ $ix ~ '" onclick="show_point(' ~ $ix ~ ');" id="path-' ~ $ix ~ '" x1="' ~ $lastx ~ '" y1="' ~ $lasty ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '"' ~ ' style="stroke:' ~ $climb_color  ~ ';opacity:0.5;stroke-width:12;z-index:' ~ 2 + rand.round ~ ';"/>';
    } else {
        say '<line id="line-' ~ $ix ~ '" x1="' ~ $x.Int ~ '" y1="' ~ $y.Int ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '" style="stroke:black;opacity:0.9;stroke-width:1;z-index:1"/>';
    }

    $lastx = $x;
    $lasty = $y;
    $laste = $p<ele>;
    $lastt = $p<tim>;
    $start_time = $lastt unless $lastp;
    $lastp = $p;
}

my $waypoints = from-json slurp($points_file);

for @$waypoints -> $p {
    if in_box($p<lat>, $p<lon>, $ban, $bon, $bax, $box) {
	my ($x, $y) = coords($p<lat>, $p<lon>, @map_data[0]);
	say '<polygon class="waypoint-mark" points="' ~ (($x, $y).join(','), ($x-10, $y-30).join(','), ($x+10, $y-30).join(',')).join(' ') ~ '" style="stroke:black;stroke-width:1px;fill:lime;"/>';
	say '<text class="waypoint-mark" x="' ~ $x.Int-10 ~ '" y="' ~ $y.Int-35 ~ '" font-size="28" font-family="Times" font-weight="normal" stroke="black" fill="black" style="z-index=1;">';
	say $p<name> ~ '</text>';
    }
}

say '<circle id="point-target" cx="50" cy="50" r="30" stroke="black" stroke-width="2" fill="none" style="opacity:1;"/>';

say '</svg>';

say '<div id="point-detail" style="position:absolute;top:12px;left:50px;width:60%;height:16px;opacity:0.75;background-color:#333;border-style:solid;border-width:1px;border-color:#000;border-radius:2px;padding:4px;color:#fff;overflow:hidden;white-space:nowrap;">';

say '<div style="display:inline-block;width:2%;"></div>';
say '<div id="point-tim" style="display:inline-block;width:16%;overflow:hidden;">lat</div>';
say '<div style="display:inline-block;width:1%;"></div>';
say '<div id="point-lat" style="display:inline-block;width:21%;overflow:hidden;">lat</div>';
say '<div style="display:inline-block;width:1%;"></div>';
say '<div id="point-lon" style="display:inline-block;width:22%;overflow:hidden;">lon</div>';
say '<div style="display:inline-block;width:1%;"></div>';
say '<div id="point-ele" style="display:inline-block;width:15%;overflow:hidden;">ele</div>';
say '<div style="display:inline-block;width:1%;"></div>';
#say '<div id="point-dst" style="display:inline-block;">dst</div>';
say '<div id="point-spd" style="display:inline-block;width:12%;overflow:hidden;">spd</div>';

say '</div>';

say '<div id="graph-wrapper" style="position:absolute;top:45px;left:50px;width:60%;opacity:0.75;background-color:#333;border-style:solid;border-width:1px;border-color:#000;border-radius:2px;padding:4px;color:#fff;">';
say '<svg width="100%" height="40" viewBox="0 0 ' ~ $width  ~ ' 100" preserveAspectRatio="none">';

my $time_range = %bounds<tim>.max - %bounds<tim>.min;
my $elevation_range = %bounds<ele>.max - %bounds<ele>.min;

for @points -> $p {
    my $x = ($p<tim>.Instant.Rat - %bounds<tim>.min) / $time_range * $width;
    my $y = 100 - ($p<ele> - %bounds<ele>.min) / $elevation_range * 100;
    say '<circle cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="1" fill="white" style="z-index:1;opacity=0.9;"/>';
}

#say %bounds<spd>.max ~ ' .. ' ~ %bounds<spd>.min;
my $speed_range = %bounds<spd>.max - %bounds<spd>.min;
my $last_bar_x;
for @points.kv -> $ix, $p {
    my $x = ($p<tim>.Instant.Rat - %bounds<tim>.min) / $time_range * $width;
    my $last_x = $last_bar_x ?? $last_bar_x.Int !! $x;
    say '<rect class="graph-bar" id="graph-bar-' ~ $ix  ~ '" onclick="show_point(' ~ $ix ~ ');" x="' ~ $last_x ~ '" y="0" width="' ~ (($x - $last_x).Int, 2).max ~ '" height="100" style="opacity:0.0;" fill="yellow" />';
    if $p<spd> {
	my $y = 100 - ($p<spd> - %bounds<spd>.min) / $speed_range * 100;
	say '<circle cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="1" fill="#9090ff"/>';
	$last_bar_x = $x;
    }
}

say '</svg>';
say '</div>';

add_button('reset-button', '0', 'Reset to original zoom position');
add_button('zoom-in-button', '+', 'Zoom in');
add_button('zoom-out-button', '-', 'Zoom out');
add_button('animate-fwd-button', ']', 'Animate forward. p for slower, \\ for slower, o for original speed. Space to stop.');
add_button('animate-bwd-button', '[', 'Animate backward. p for slower, \\ for slower, o for original speed. Space to stop.');
add_button('dist-button', 'd', 'Toggle km marks');
add_button('time-button', 't', 'Toggle 15 min marks');
add_button('rest-button', 'r', 'Toggle rest marks');
add_button('summary-button', 's', 'Toggle summary detail');
add_button('graph-button', 'g', 'Toggle graph');
add_button('waypoint-button', 'w', 'Toggle waypoints');

say '</div>';

sub add_button($id, $label, $title) {
    say '<button type="button" id="' ~ $id ~ '" title="' ~ $title ~ '" style="position:absolute;top:' ~ 10 + $buttons*25 ~ 'px;left:10px;width:20px;text-align:center;padding:2px 2px;background-color:#333;color:#fff;opacity:0.8;">' ~ $label ~ '</button>';
    $buttons++;
}

say_summary;

sub say_summary {
  say '<div id="summary" style="position:absolute;top:12px;right:20;width:20%;opacity:0.8;background-color:#333;border-style:solid;border-width:1px;border-color:#000;border-radius:2px;padding:8px;text-align:right;color:#fff;min-height:65px;">';

  say '<div style="font-weight:bold;font-size:medium;">' ~ $title ~ "<br/>" ~ $date ~ '</div>';

  say '<div id="summary-detail" style="display:none;"><br/>Total distance: ' ~ ($total_dist/1000).round(.01) ~ 'km<br/>';
  my $total_time = $lastt - $start_time;
  say 'Total time: ' ~ ($total_time/60).Int ~ 'min<br/>';
  say 'Total climb: ' ~ $total_climb.round ~ 'm<br/>';
  say 'Minimum elevation: ' ~ %bounds<ele>.min.round ~ 'm<br/>';
  say 'Maximum elevation: ' ~ %bounds<ele>.max.round ~ 'm<br/>';
  say 'Total rest time: ' ~ ($total_rest_time/60).Int ~ ' min<br/>';
  say 'Avg speed: ' ~ (($total_dist/1000)/($total_time/3600)).round(.01) ~ 'kph<br/>';
  say 'Avg non-rest speed: ' ~ (($total_dist/1000)/(($total_time-$total_rest_time)/3600)).round(.01) ~ 'kph<br/>';
  say 'Maximum speed: ' ~ (%bounds<spd>.max / 1000 * 3600).round(.01) ~ 'kph';
  say '</div>';
  say '</div>';
}


say q:to/END/;
<script>
  var zoom_factor = 0.8;
  var move_step = 50;
  var keep_animating = false;;
  var pm = document.getElementById("plotmap");

  document.onkeydown = function(e) {
    if      (e.key == '0') { document.getElementById("reset-button").click(); }
    else if (e.key == '=') { document.getElementById("zoom-in-button").click(); }
    else if (e.key == '-') { document.getElementById("zoom-out-button").click(); }
    else if (e.key == 'd') { document.getElementById("dist-button").click(); }
    else if (e.key == 't') { document.getElementById("time-button").click(); }
    else if (e.key == 'r') { document.getElementById("rest-button").click(); }
    else if (e.key == 's') { document.getElementById("summary-button").click(); }
    else if (e.key == 'g') { document.getElementById("graph-button").click(); }
    else if (e.key == 'w') { document.getElementById("waypoint-button").click(); }
    else if (e.key == 'ArrowLeft') { move_map(move_step*-1, 0); }
    else if (e.key == 'ArrowRight') { move_map(move_step, 0); }
    else if (e.key == 'ArrowUp') { move_map(0, move_step*-1); }
    else if (e.key == 'ArrowDown') { move_map(0, move_step); }
    else if (e.key == ' ') { keep_animating = false; show_point(parseInt(point_ix) + 1); }
    else if (e.key == 'b') { keep_animating = false; show_point(point_ix - 1); }
    else if (e.key == 'Enter') { keep_animating = false; show_point(0); }
    else if (e.key == '\'') { keep_animating = false; show_point(points.length-1); }
    else if (e.key == ']') { document.getElementById("animate-fwd-button").click(); }
    else if (e.key == '[') { document.getElementById("animate-bwd-button").click(); }
    else if (e.key == 'q') { keep_animating = false; }
    else if (e.key == 'p') { animation_rate *= 2; }
    else if (e.key == '\\\\') { animation_rate /= 2; }
    else if (e.key == 'o') { animation_rate = 1; }
    else if (e.key == '/') { keep_point_centered = !keep_point_centered; if (keep_point_centered) { center_on_point(); } }
    e.preventDefault();
  };

  function move_map(x, y) {
    var vb = viewbox_to_a();
    vb[0] += x;
    vb[1] += y;
    pm.setAttribute("viewBox", a_to_viewbox(vb));
  }

  function animate(rate) {
    var step = rate < 0 ? -1 : 1;
    if (!points[point_ix + step]) { keep_animating = false; return; }

    var wait = 100;
    if (points[point_ix + (step*-1)]) {
      wait = Math.abs((points[point_ix]["date"].getTime() - points[point_ix + (step*-1)]["date"].getTime()) * rate * animation_rate / 100);
    }

    setTimeout(function(){ show_point(parseInt(point_ix) + step); if (keep_animating) { animate(rate); } }, wait);
  }

  function center_on_point() {
      var pl = document.getElementById("line-" + point_ix);
      if (pl == null) { return; }

      var vb = viewbox_to_a();
      vb[0] = pl.getAttribute("x2") - vb[2]/2;
      vb[1] = pl.getAttribute("y2") - vb[3]/2;

      document.getElementById("plotmap").setAttribute("viewBox", a_to_viewbox(vb));
  }

  pm.onclick = function(e){
    var wrap = document.getElementById("plotmap-wrapper");
    var vb = viewbox_to_a();
    var vx = (e.pageX - wrap.offsetLeft) / pm.width.baseVal.value * vb[2];
    var vy = (e.pageY - wrap.offsetTop) / pm.height.baseVal.value * vb[3];
    vb[0] = vx + vb[0] - vb[2]/2;
    vb[1] = vy + vb[1] - vb[3]/2;
    this.setAttribute("viewBox", a_to_viewbox(vb));
  };

  var original_viewbox = pm.getAttribute("viewBox");
  document.getElementById("reset-button").onclick = function(e) {
    pm.setAttribute("viewBox", original_viewbox);
  };

  document.getElementById("zoom-in-button").onclick = function(e) {
    zoom(zoom_factor);
  };

  document.getElementById("zoom-out-button").onclick = function(e) {
    zoom(1/zoom_factor);
  };

  document.getElementById("animate-fwd-button").onclick = function(e) {
    if (!keep_animating) { keep_animating = true; animate(1); }
  };

  document.getElementById("animate-bwd-button").onclick = function(e) {
    if (!keep_animating) { keep_animating = true; animate(-1); }
  };

  document.getElementById("rest-button").onclick = function(e) {
    toggleMark("rest-mark");
  };

  document.getElementById("dist-button").onclick = function(e) {
    toggleMark("dist-mark");
  };

  document.getElementById("time-button").onclick = function(e) {
    toggleMark("time-mark");
  };

  document.getElementById("summary-button").onclick = function(e) {
    var sum = document.getElementById("summary-detail");
    sum.style.display = sum.style.display == 'none' ? 'inherit' : 'none';
  };

  document.getElementById("graph-button").onclick = function(e) {
    var graph = document.getElementById("graph-wrapper");
    graph.style.display = graph.style.display == 'none' ? 'inherit' : 'none';
  };

  document.getElementById("waypoint-button").onclick = function(e) {
    toggleMark("waypoint-mark");
  };

  function toggleMark(cls) {
    var marks = document.getElementsByClassName(cls);
    var set_value = marks[0].getAttribute("visibility") == 'hidden' ? 'visible' : 'hidden';
    for (i = 0; i < marks.length; i++) {
      marks[i].setAttribute("visibility", set_value);
    }
  }

  function showGraphMark(id) {
      document.getElementById("graph-bar-" + id).style["opacity"] = 1.0;
  }

  function hideGraphMark(id) {
      document.getElementById("graph-bar-" + id).style["opacity"] = 0.0;
  }
  
  function viewbox_to_a() {
    var vb = document.getElementById("plotmap").getAttribute("viewBox").split(" ");
    for (i = 0; i < vb.length; i++) {
      vb[i] = parseInt(vb[i]);
    }
    return vb;
  }

  function a_to_viewbox(vb) {
    for (i = 0; i < vb.length; i++) {
      vb[i] = Math.round(vb[i]);
    }
    return vb.join(" ");
  }
  
  function zoom(factor) {
    var vb = viewbox_to_a();
    var vw = vb[2] * factor;
    var vh = vb[3] * factor;
    vb[0] = vb[0] + (vb[2]-vw)/2;
    vb[1] = vb[1] + (vb[3]-vh)/2;
    vb[2] = vw;
    vb[3] = vh;
    document.getElementById("plotmap").setAttribute("viewBox", a_to_viewbox(vb));
  }
</script>
END

say '</body></html>';


sub svg_line($x1, $y1, $x2, $y2, :%style is copy) {
    my $style = (%style.map: -> $p { $p.key ~ ':' ~ $p.value }).join(';');
    my $out = '<line x1="' ~ $x1 ~ '" y1="' ~ $y1 ~ '" x2="' ~ $x2 ~ '" y2="' ~ $y2 ~ '" ';
    $out ~= 'style="' ~ $style ~ '"';
    $out ~= '/>';

    $out;
}


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

sub in_range($x, $min, $max) {
    $x >= $min && $x <= $max;
}

sub in_box($x, $y, $xmin, $ymin, $xmax, $ymax) {
    in_range($x, $xmin, $xmax) && in_range($y, $ymin, $ymax);
}

sub tile_ref($name) {
    $tile_url ~ '/' ~ $name;
}

