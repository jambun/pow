#!/usr/bin/env perl6

use lib 'lib';
use Bounds;
use Track;
use Markers;
use Maps;

use JSON::Tiny;

# <trkpt lat="-35.7237188" lon="148.8175634">
# <ele>1283.370</ele>
# <time>2016-10-28T00:46:10.000Z</time>

# i'll be needing a main - parses switches
# this example from stackoverflow
# sub MAIN ( Str  :f(:$file)    = "file.dat"
#          , Num  :l(:$length)  = Num(24)
#          , Bool :v(:$verbose) = False
#          )
# {
#     $file.say;
#     $length.say;
#     $verbose.say;
# }

my %buttons;
my $button_group;
my $points_file = './data/points.json';
my $rest_threshold = 5 * 60; # 5 minutes

my $markers = Markers.new(json_file => $points_file);
$markers.load;


my $images_dir = 'html/img'; #
my $images_html_dir = 'img'; # kooky
my %images;

for dir($images_dir) -> $d {
    next unless $d.extension eq 'jpg';
    %images{$d.basename.chop(4)} = $images_html_dir ~ '/' ~ $d.basename;
}

my $audio_dir = 'html/audio'; #
my $audio_html_dir = 'audio'; # kooky
my %audio;

for dir($audio_dir) -> $d {
    next unless $d.extension eq 'mp3';
    %audio{$d.basename.chop(4)} = $audio_html_dir ~ '/' ~ $d.basename;
}

my $track = Track.new;

my %pt;

for slurp.lines -> $line {
    given $line {
        when /'<wpt' \s+ 'lat="' (.*) '"' \s+ 'lon="' (.*) '">'/ {
            %pt = lat => $0.Rat, lon => $1.Rat;
        }
	      when /'<trkpt' \s+ 'lat="' (.*) '"' \s+ 'lon="' (.*) '">'/ {
            if %pt<name> {
	              $track.title = %pt<name>;
	              $track.desc = %pt<desc>;
                %pt<name>:delete;
                %pt<desc>:delete;
            }
	          %pt = lat => $0.Rat, lon => $1.Rat;
	      }
	      when /'<ele>' (.*) '</ele>'/ {
	          %pt<ele> = $0.Rat;
	      }
	      when /'<time>' (.*) '</time>'/ {
	          %pt<time> = DateTime.new($0.Str);
	      }
	      when /'<name>' '<![CDATA['? (.+?) ']]>'? '</name>'/ {
            %pt<name> = $0.Str;
	      }
	      when /'<desc>' '<![CDATA['? (.+?) ']]>'? '</desc>'/ {
            %pt<desc> = $0.Str;
	      }
	      when /'</trkpt>'/ {
            $track.add_point(%pt);
            %pt = < >;
        }
	      when /'</wpt>'/ {
            $markers.add(%pt);
            %pt = < >;
        }
    }
}

$markers.save;


say qq:to/END/;
<html>
  <head>
    <title>{ $track.title }</title>

    <script>
END

say slurp('templates/js/pow.js');

$track.points_to_js;

say '</script>';
say '</head>';
say '<body style="margin:0px;overflow:hidden;">';

my $border = 20;

my $maps = Maps.new(track => $track);

my ($bxn, $byn) = $maps.coords($track.bounds<lat>.min, $track.bounds<lon>.min);
my ($bxx, $byx) = $maps.coords($track.bounds<lat>.max, $track.bounds<lon>.max);
say '<div id="plotmap-wrapper" style="position:relative;" width="100%" height="100%">';
say '<svg id="plotmap" width="100%" height="100%" viewBox="' ~ $bxn-100 ~ ' ' ~ $byx-100 ~ ' ' ~ $bxx-$bxn+200 ~  ' ' ~ $byn-$byx+200 ~ '">';

for $maps.list -> $md {
    say '<image xlink:href="' ~ $md<tile_ref> ~
    '" width="2000px" height="2000px" x="' ~ ($md<tilex> - $maps.x_bounds.min)*2000 ~
    '" y="' ~ ($md<tiley> - $maps.y_bounds.min)*2000  ~ '" style="z-index:0;opacity:1;"/>';
}


my $lastx;
my $lasty;
my $laste;
my $lastt;
my $lastp;

my $time_mark_secs = 15 * 60;
my $time_mark_radius = 12;
my $last_time_mark = $track.points[0]<tim>;

my $dist_mark = 1000;
my $dist_mark_radius = 12;
my $last_dist_mark = 0;
my $total_dist = 0;
my $total_climb = 0;
my $start_time = 0;
my $current_rest_time = 0;
my $rest_x;
my $rest_y;
my $total_rest_time = 0;
my $dist_mark_count = 0;
my $time_mark_count = 0;

for $track.points.kv -> $ix, $p {
    my ($x, $y) = $maps.coords($p<lat>, $p<lon>);
    if $lastp {
	$total_dist += $p<dst>;

	if $p<spd> < 0.1 {
	    unless $current_rest_time { $rest_x = $x.Int; $rest_y = $y.Int; }
	    $current_rest_time += $p<time> - $lastt;
	} else {
	    $current_rest_time += $p<time> - $lastt if $current_rest_time;
	    
	    if $current_rest_time > $rest_threshold {
		$total_rest_time += $current_rest_time;
		say '<circle class="rest-mark" cx="' ~ $rest_x ~ '" cy="' ~ $rest_y ~ '" r="' ~ $dist_mark_radius ~ '"' ~
		' fill="blue" style="opacity:0.5;z-index:1;"/>';
	    }
	    $current_rest_time = 0;
	}

	if $total_dist > $last_dist_mark + $dist_mark {
	    $dist_mark_count++;
	    say '<circle class="dist-mark" cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="' ~ $dist_mark_radius ~ '"' ~
	        ' fill="red" style="opacity:0.5;z-index:1;"/>';
	    say '<text class="dist-mark" x="' ~ ($x.Int + 12) ~ '" y="' ~ ($y.Int + 4) ~
	        '" font-size="12">' ~ $dist_mark_count ~ 'km</text>';
            say '<circle class="dist-mark" cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="2" style="fill:red;opacity:0.9;"/>';
	    $last_dist_mark += $dist_mark;
	}
	
	if $p<tim> > $last_time_mark + $time_mark_secs {
	    $time_mark_count++;
	    say '<circle class="time-mark" cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="' ~ $time_mark_radius ~ '"' ~
	        ' fill="black" style="opacity:0.25;z-index:1;"/>';
	    my $elapsed_time = (($time_mark_count * 15) / 60).Int ~ ':' ~ sprintf('%02s', (($time_mark_count * 15) % 60).round);
	    say '<text class="time-mark" x="' ~ ($x.Int + 12) ~ '" y="' ~ ($y.Int + 4) ~
	        '" font-size="12">' ~ $elapsed_time ~ '</text>';
            say '<circle class="time-mark" cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="2" style="fill:gray;opacity:0.9;"/>';
	    $last_time_mark += $time_mark_secs;
	}

	my Rat $climb = $p<ele> - $laste;
	$total_climb += $climb if $climb > 0.0;
	my $climb_color = $climb >= 0.0 ?? '#ff3333' !! '#3333ff';
        say '<line id="fine-line-' ~ $ix ~ '" x1="' ~ $lastx ~ '" y1="' ~ $lasty ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '" style="stroke:black;opacity:0.9;stroke-width:1;z-index:1"/>';
	say '<line class="trail-mark" id="line-' ~ $ix ~ '" onclick="show_point(' ~ $ix ~ ');" id="path-' ~ $ix ~ '" x1="' ~ $lastx ~ '" y1="' ~ $lasty ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '"' ~ ' style="stroke:' ~ $climb_color  ~ ';opacity:0.5;stroke-width:12;z-index:' ~ 2 + rand.round ~ ';"/>';
    } else {
        say '<line class="trail-mark" id="line-' ~ $ix ~ '" x1="' ~ $x.Int ~ '" y1="' ~ $y.Int ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '" style="stroke:black;opacity:0.9;stroke-width:1;z-index:1"/>';
        say '<line id="fine-line-' ~ $ix ~ '" x1="' ~ $x.Int ~ '" y1="' ~ $y.Int ~ '" x2="' ~ $x.Int ~ '" y2="' ~ $y.Int ~ '" style="stroke:black;opacity:0.9;stroke-width:1;z-index:1"/>';
    }

    $lastx = $x;
    $lasty = $y;
    $laste = $p<ele>;
    $lastt = $p<time>;
    $start_time = $lastt unless $lastp;
    $lastp = $p;
}


for $markers.points -> $p {
    my $tim = DateTime.new($p<time>).Instant.Rat;
    if $track.bounds<tim>.include($tim) && $maps.in_box($p<lat>, $p<lon>,
                                                        $track.bounds<lat>.min,
                                                        $track.bounds<lon>.min,
                                                        $track.bounds<lat>.max,
                                                        $track.bounds<lon>.max) {

	my ($x, $y) = $maps.coords($p<lat>, $p<lon>);
	my $text_x = $x.Int-10;
	if (%images{$p<name>}) {
	    my $audio_attr = %audio{$p<name>} ?? ' x-audio="' ~ %audio{$p<name>} ~ '"' !! '';
	    say '<image class="waypoint-mark waypoint-image" xlink:href="' ~ %images{$p<name>} ~ '"' ~ $audio_attr ~
	        ' width="22" height="22" x="' ~ ($x-11) ~'" y="' ~ ($y-55)  ~ '" style="opacity:1;"/>';
	    $text_x += 22;
	}
	say '<polygon class="waypoint-mark" points="' ~ (($x, $y).join(','), ($x-10, $y-30).join(','), ($x+10, $y-30).join(',')).join(' ') ~ '" style="stroke:black;stroke-width:1px;fill:lime;"/>';
	say '<text class="waypoint-mark" x="' ~ $text_x ~ '" y="' ~ $y.Int-35 ~ '" font-size="28" font-family="Times" font-weight="normal" stroke="black" fill="black" style="z-index=1;">';
	say $p<name> ~ '</text>';
    }
}

say '<circle id="point-target-centered" cx="50" cy="50" r="32" stroke="white" stroke-width="8" fill="none" style="opacity:0.6;"/>';
say '<circle id="point-target" cx="50" cy="50" r="33" stroke="black" stroke-width="3" fill="none" style="opacity:1;"/>';
say '<circle id="point-target-spot" cx="50" cy="50" r="3" stroke="white" stroke-width="0" fill="white" style="opacity:0.8;"/>';

say '</svg>';

say '<div id="point-detail" style="position:absolute;font-size:large;top:12px;left:50px;width:60%;height:20px;opacity:0.75;background-color:#333;border-style:solid;border-width:1px;border-color:#000;border-radius:2px;padding:4px;color:#fff;overflow:hidden;white-space:nowrap;">';

say '<div style="display:inline-block;width:1%;"></div>';
say '<div id="point-tim" style="display:inline-block;width:16%;overflow:hidden;">Time</div>';
say '<div style="display:inline-block;width:1%;"></div>';
say '<div id="point-lat" style="display:inline-block;width:21%;overflow:hidden;">Lat</div>';
say '<div style="display:inline-block;width:1%;"></div>';
say '<div id="point-lon" style="display:inline-block;width:24%;overflow:hidden;">Lon</div>';
say '<div style="display:inline-block;width:1%;"></div>';
say '<div id="point-ele" style="display:inline-block;width:15%;overflow:hidden;">Ele</div>';
say '<div style="display:inline-block;width:1%;"></div>';
#say '<div id="point-dst" style="display:inline-block;">Distance</div>';
say '<div id="point-spd" style="display:inline-block;width:12%;overflow:hidden;text-align:right">Speed</div>';

say '</div>';

say '<div id="graph-wrapper" style="position:absolute;top:50px;left:50px;width:60%;opacity:0.75;background-color:#333;border-style:solid;border-width:1px;border-color:#000;border-radius:2px;padding:4px;color:#fff;">';
say '<svg width="100%" height="40" viewBox="0 0 1000 100" preserveAspectRatio="none">';

my $time_range = $track.bounds<tim>.max - $track.bounds<tim>.min;
my $elevation_range = $track.bounds<ele>.max - $track.bounds<ele>.min;

for $track.points -> $p {
    my $x = ($p<tim> - $track.bounds<tim>.min) / $time_range * 1000;
    my $y = 100 - ($p<ele> - $track.bounds<ele>.min) / $elevation_range * 100;
    say '<circle cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="2" fill="white" style="z-index:1;opacity=0.9;"/>';
}

say '<rect id="graph-mark-to-point" x="0" y="0" width="200" height="100" style="opacity:0.4;" fill="green" />';
say '<line id="graph-mark x1="0" y1="0" x2="0" y2="100" style="stroke:green;opacity:1.0;stroke-width:8;z-index:1;"/>';

my $speed_range = $track.bounds<spd>.max - $track.bounds<spd>.min;
my $last_bar_x;
for $track.points.kv -> $ix, $p {
    my $x = ($p<tim> - $track.bounds<tim>.min) / $time_range * 1000;
    my $last_x = $last_bar_x ?? $last_bar_x.Int !! $x;
    say '<rect class="graph-bar" id="graph-bar-' ~ $ix  ~ '" onclick="show_point(' ~ $ix ~ ');" x="' ~ $last_x ~ '" y="0" width="' ~ (($x - $last_x).Int, 2).max ~ '" height="100" style="opacity:0.0;" fill="yellow" />';
    my $y = 100 - (($p<spd> || 0) - $track.bounds<spd>.min) / $speed_range * 100;
    say '<circle cx="' ~ $x.Int ~ '" cy="' ~ $y.Int ~ '" r="2" fill="#8080ff"/>';
    $last_bar_x = $x;
}

say '</svg>';
say '</div>';

$button_group = 'base';
say '<div id="base-button-group">';
add_button('help-button', '?', 'Show help', :on);
add_button('select-button', '&hellip;', 'Select button group');
say '</div>';

$button_group = 'navigation';
say '<div class="button-group" id="navigation-button-group" style="display:none;">';
add_button('reset-button', '0', 'Reset to original zoom position');
add_button('zoom-in-button', '+', 'Zoom in');
add_button('zoom-out-button', '-', 'Zoom out');
add_button('move-north-button', '&#8593;', 'Move north');
add_button('move-west-button', '&#8592;', 'Move west');
add_button('move-east-button', '&#8594;', 'Move east');
add_button('move-south-button', '&#8595;', 'Move south');
say '</div>';

$button_group = 'animation';
say '<div class="button-group" id="animation-button-group" style="display:none;">';
add_button('goto-start-button', '&larrb;', 'Go to start');
add_button('goto-end-button', '&rarrb;', 'Go to end');
add_button('step-fwd-button', '&rarr;', 'Step forward');
add_button('step-bwd-button', '&larr;', 'Step backward');
add_button('animate-fwd-button', '&vrtri;', 'Animate forward');
add_button('animate-bwd-button', '&vltri;', 'Animate backward');
add_button('follow-button', '&target;', 'Toggle follow target');
add_button('faster-button', '&raquo;', 'Faster');
add_button('slower-button', '&laquo;', 'Slower');
add_button('original-speed-button', 'o', 'Original speed', :on);
add_button('stop-button', '!', 'Stop animation');
say '</div>';


$button_group = 'display';
say '<div class="button-group" id="display-button-group" style="display:inherit;">';
add_button('trail-half-button', '&half;', 'Show trail out/back/all');
add_button('trail-color-button', 'C', 'Next trail color map');
add_button('trail-button', 'L', 'Toggle trail marks', :on);
add_button('dist-button', 'D', 'Toggle km marks', :on);
add_button('time-button', 'T', 'Toggle 15 min marks', :on);
add_button('rest-button', 'R', 'Toggle rest marks', :on);
add_button('waypoint-button', 'W', 'Toggle waypoints', :on);
add_button('graph-button', 'G', 'Toggle graph', :on);
add_button('summary-button', 'S', 'Toggle summary detail');
say '</div>';

say '</div>';

sub add_button($id, $label, $title, Bool :$on) {
    %buttons{$button_group} ||= 0;
    my $position = %buttons<base>;
    $position += %buttons{$button_group} unless $button_group eq 'base';
    say '<button type="button" id="' ~ $id ~ '" title="' ~ $title ~ '" style="position:absolute;font-size:large;top:' ~ 10 + $position*36 ~ 'px;left:10px;width:30px;text-align:center;padding:2px 2px;background-color:#333;color:' ~ ($on ?? 'lime' !! 'white') ~ ';opacity:0.8;">' ~ $label ~ '</button>';
    %buttons{$button_group}++;
}

say_summary;

say image_viewer;

say_help;


sub say_summary {
  say '<div id="summary" style="position:absolute;top:12px;right:20;width:20%;opacity:0.95;background-color:#333;border-style:solid;border-width:1px;border-color:#000;border-radius:2px;padding:8px;text-align:right;color:#fff;">';

  say '<div style="font-weight:bold;font-size:large;width:100%;">' ~ $track.title ~ "<br/>" ~ $track.date ~ '</div>';

  say '<div id="summary-detail" style="display:none;width:100%;font-size:large;">';
  say '<br/>';
  say '<div style="font-weight:bold;font-size:large;width:100%;text-align:left">' ~ $track.desc ~ '</div>';
  say '<br/>';
  say summary_item('Total distance: ', ($total_dist/1000).round(.01) ~ 'km');
  my $total_time = $lastt - $start_time;
  say summary_item('Total time: ', sec_to_hm($total_time));
  say summary_item('Rest time: ', sec_to_hm($total_rest_time));
  say summary_item();
  say summary_item('Total climb: ', $total_climb.round ~ 'm');
  say summary_item('Min elevation: ', $track.bounds<ele>.min.round ~ 'm');
  say summary_item('Max elevation: ', $track.bounds<ele>.max.round ~ 'm');
  say summary_item();
  say summary_item('Avg speed: ',      mps_to_kph($total_dist/$total_time));
  say summary_item('Non-rest speed: ', mps_to_kph($total_dist/($total_time-$total_rest_time)));
  say summary_item('Max speed: ',      mps_to_kph($track.bounds<spd>.max));
  say '<div id="summary-image" style="padding:6px;">';
  if (%images{$track.title}) {
      say summary_item();
      say '<img src="' ~ %images{$track.title} ~ '" style="max-width:100%;max-height:100%;"/>';
  }
  say '</div>';
  say '</div>';
  say '</div>';
}

sub sec_to_hm($sec) {
    ($sec / 3600).Int ~ 'hr ' ~ ($sec % 3600 / 60).round ~ 'min';
}

sub mps_to_kph($mps) {
    (sprintf '%.2f', ($mps/1000*3600).round(.01)).Str ~ ' kph';
}

sub summary_item($label = '&nbsp;', $value = '&nbsp;') {
    '<div style="width:100%;"><div style="display:inline-block;float:left;">' ~ $label ~ '</div><div style="display:inline-block;right:0;">' ~ $value ~ '</div></div>';
}

sub image_viewer {
    qq:to/END/;
    <div id="image-viewer" align="center" style="display:none;position:absolute;top:20%;left:20%;width:60%;height:60%;font-size:large;">
      <img id="image-media" src="" style="max-width:100%;max-height:100%;"/>
    </div>
    END
}

sub say_help {
    say qq:to/END/;
    <div class="help" id="help-overlay" style="position:absolute;top:0;left:0;width:100%;height:100%;opacity:0.3;background-color:#fff;border-style:none;;padding:0px;"></div>
    <div class="help" id="help-detail" style="position:absolute;top:160;left:120;width:65%;height:60%;overflow:scroll;opacity:0.9;background-color:#333;border-style:solid;border-width:1px;border-color:#000;border-radius:2px;padding:8px;color:#fff;">
      <div align="center" style="font-size:large;">Help: [Any] key or click to exit. [h] to show.</div>
      <table width="100%" height="90%" border="0" style="padding:20;color:#fff;">
      <tr>
      <td width="50%" valign="top">
        <span style="font-size:large;">Navigation</span>
        { help_item('0 (zero)', 'Original nav position') }
        { help_item('=', 'Zoom in') }
        { help_item('-', 'Zoom out') }
        { help_item('Arrows', 'Move map position') }
        { help_item() }
        <span style="font-size:large;">Animation</span>
        { help_item('Space', 'Step forward') }
        { help_item('b', 'Step backward') }
        { help_item('Return', 'Go to start') }
        { help_item("'", 'Go to end') }
        { help_item(']', 'Animate forward') }
        { help_item('[', 'Animate backward') }
        { help_item('q', 'Stop animation') }
        { help_item('\\', 'Faster animation') }
        { help_item('p', 'Slower animation') }
        { help_item('o', 'Original animation speed') }
        { help_item('/', 'Toggle follow target') }
      </td>
      <td width="50%" valign="top">
        <span style="font-size:large;">Display</span>
        { help_item('l', 'Toggle trail') }
        { help_item('k', 'Show trail out/back/all') }
        { help_item('d', 'Toggle km marks') }
        { help_item('t', 'Toggle 15min marks') }
        { help_item('r', 'Toggle rest marks') }
        { help_item('w', 'Toggle waypoints') }
        { help_item('g', 'Toggle graph') }
        { help_item('s', 'Toggle summary detail') }
        { help_item('c', 'Next trail color map') }
        { help_item('h', 'Show this help') }
        { help_item() }
        { help_item('?', 'Show this help') }
        { help_item('&hellip;', 'Next button group') }
        { help_item() }
        { help_item('Map', 'Click to centre') }
        { help_item('Trail', 'Red = climb, Blue = descend. Click to move target') }
        { help_item('Graph', 'White = elevation, Blue = speed. Click to move target') }
        { help_item('Summary', 'Click to see detail') }
      </td>
      </tr>
      </table>
    </div>
    END
}

sub help_item($key = '&nbsp;', $text = '&nbsp;') {
    qq:to/END/;
    <div style="width:100%;">
    <div style="display:inline-block;width:75;font-size:large;"> $key </div>
    <div style="display:inline-block;"> $text </div>
    </div>
    END
}

say q:to/END/;
<script>
  var zoom_factor = 0.8;
  var move_step = 50;
  var keep_animating = false;;
  var pm = document.getElementById("plotmap");

  document.onkeydown = function(e) {
    if (!(document.getElementById("help-detail").style.display == 'none')) { document.getElementById("help-button").click(); }
    else if (e.key == ';') { document.getElementById("select-button").click(); }
    else if (e.key == '0') { document.getElementById("reset-button").click(); }
    else if (e.key == '=') { document.getElementById("zoom-in-button").click(); }
    else if (e.key == '-') { document.getElementById("zoom-out-button").click(); }
    else if (e.key == 'd') { document.getElementById("dist-button").click(); }
    else if (e.key == 't') { document.getElementById("time-button").click(); }
    else if (e.key == 'r') { document.getElementById("rest-button").click(); }
    else if (e.key == 's') { document.getElementById("summary-button").click(); }
    else if (e.key == 'g') { document.getElementById("graph-button").click(); }
    else if (e.key == 'w') { document.getElementById("waypoint-button").click(); }
    else if (e.key == 'l') { document.getElementById("trail-button").click(); }
    else if (e.key == 'k') { document.getElementById("trail-half-button").click(); }
    else if (e.key == 'c') { document.getElementById("trail-color-button").click(); }
    else if (e.key == 'ArrowLeft') { document.getElementById("move-west-button").click(); }
    else if (e.key == 'ArrowRight') { document.getElementById("move-east-button").click(); }
    else if (e.key == 'ArrowUp') { document.getElementById("move-north-button").click(); }
    else if (e.key == 'ArrowDown') { document.getElementById("move-south-button").click(); }
    else if (e.key == ' ') { document.getElementById("step-fwd-button").click(); }
    else if (e.key == 'b') { document.getElementById("step-bwd-button").click(); }
    else if (e.key == 'Enter') { document.getElementById("goto-start-button").click(); }
    else if (e.key == '\'') { document.getElementById("goto-end-button").click(); }
    else if (e.key == ']') { document.getElementById("animate-fwd-button").click(); }
    else if (e.key == '[') { document.getElementById("animate-bwd-button").click(); }
    else if (e.key == 'q') { document.getElementById("stop-button").click(); }
    else if (e.key == 'p') { document.getElementById("slower-button").click(); }
    else if (e.key == '\\\\') { document.getElementById("faster-button").click(); }
    else if (e.key == 'o') { document.getElementById("original-speed-button").click(); }
    else if (e.key == '/') { document.getElementById("follow-button").click(); }
    else if (e.key == 'h') { document.getElementById("help-button").click(); }
    e.preventDefault();
  };

  function move_map(x, y) {
    var vb = viewbox_to_a();
    vb[0] += x;
    vb[1] += y;
    pm.setAttribute("viewBox", a_to_viewbox(vb));
  }

  function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async function animate(rate) {
    var step = rate < 0 ? -1 : 1;
    if (!points[point_ix + step]) { show_point(step == 1 ? 0 : points.length - 1); }
    var button = document.getElementById(step == 1 ? 'animate-fwd-button' : 'animate-bwd-button');
    switchButton(button, true);
    while (true) {
      if (!keep_animating) { break; }
      if (!points[point_ix + step]) { keep_animating = false; break; }

      var wait = 100;
      if (points[point_ix - step]) {
	wait = Math.abs((points[point_ix]["tstamp"] - points[point_ix - step]["tstamp"])
			 * rate * animation_rate / 100);
      }

      await sleep(wait);
      show_point(parseInt(point_ix) + step);
    }
    switchButton(button, false);
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
    var vx = (e.pageX - wrap.offsetLeft) / wrap.offsetWidth * vb[2];
    var vy = (e.pageY - wrap.offsetTop) / wrap.offsetHeight * vb[3];
    vb[0] = vx + vb[0] - vb[2]/2;
    vb[1] = vy + vb[1] - vb[3]/2;
    this.setAttribute("viewBox", a_to_viewbox(vb));
  };

  var button_groups = ['display', 'navigation', 'animation'];
  var button_group_ix = 0;
  document.getElementById("select-button").onclick = function(e) {
    var groups = document.getElementsByClassName("button-group");
    for (i = 0; i < groups.length; i++) {
      groups[i].style.display = 'none';
    }
    button_group_ix++;
    if (button_group_ix >= button_groups.length) { button_group_ix = 0; }
    document.getElementById(button_groups[button_group_ix] + '-button-group').style.display = 'inherit';
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

  document.getElementById("move-north-button").onclick = function(e) {
    move_map(0, move_step*-1);
  };

  document.getElementById("move-west-button").onclick = function(e) {
    move_map(move_step*-1, 0);
  };

  document.getElementById("move-east-button").onclick = function(e) {
    move_map(move_step, 0);
  };

  document.getElementById("move-south-button").onclick = function(e) {
    move_map(0, move_step);
  };

  document.getElementById("goto-start-button").onclick = function(e) {
    keep_animating = false;
    show_point(0);
  };

  document.getElementById("goto-end-button").onclick = function(e) {
    keep_animating = false;
    show_point(points.length-1);
  };

  document.getElementById("step-fwd-button").onclick = function(e) {
    keep_animating = false;
    show_point(parseInt(point_ix) + 1, true);
  };

  document.getElementById("step-bwd-button").onclick = function(e) {
    keep_animating = false;
    show_point(parseInt(point_ix) - 1, true);
  };

  document.getElementById("animate-fwd-button").onclick = function(e) {
    if (!keep_animating) { keep_animating = true; animate(1); }
  };

  document.getElementById("animate-bwd-button").onclick = function(e) {
    if (!keep_animating) { keep_animating = true; animate(-1); }
  };

  document.getElementById("faster-button").onclick = function(e) {
    setAnimationRate(animation_rate/2);
  };

  document.getElementById("slower-button").onclick = function(e) {
    setAnimationRate(animation_rate*2);
  };

  document.getElementById("original-speed-button").onclick = function(e) {
    setAnimationRate(1);
  };

  function setAnimationRate(rate) {
      animation_rate = rate;
      switchButton(document.getElementById("faster-button"), rate < 1);
      switchButton(document.getElementById("slower-button"), rate > 1);
      switchButton(document.getElementById("original-speed-button"), rate == 1);
  }

  document.getElementById("stop-button").onclick = function(e) {
    keep_animating = false;
  };

  document.getElementById("follow-button").onclick = function(e) {
    keep_point_centered = !keep_point_centered;
    switchButton(this, keep_point_centered);
    if (keep_point_centered) { center_on_point(); }
  };

  document.getElementById("rest-button").onclick = function(e) {
    toggleMark("rest-mark", this);
  };

  document.getElementById("dist-button").onclick = function(e) {
    toggleMark("dist-mark", this);
  };

  document.getElementById("time-button").onclick = function(e) {
    toggleMark("time-mark", this);
  };

  document.getElementById("summary-button").onclick = function(e) {
    toggleSummary(this);
  };

  document.getElementById("summary").onclick = function(e) {
    toggleSummary(document.getElementById("summary-button"));
  };

  function toggleSummary(button) {
    var sum = document.getElementById("summary-detail");
    sum.style.display = sum.style.display == 'none' ? 'inherit' : 'none';
    switchButton(button, sum.style.display != 'none');
  }
  
  document.getElementById("graph-button").onclick = function(e) {
    var graph = document.getElementById("graph-wrapper");
    graph.style.display = graph.style.display == 'none' ? 'inherit' : 'none';
    switchButton(this, graph.style.display != 'none');
  };

  document.getElementById("waypoint-button").onclick = function(e) {
    toggleMark("waypoint-mark", this);
  };

  document.getElementById("trail-half-button").onclick = function(e) {
    // all > first > second > all ...
    if (document.getElementById("line-0").getAttribute("visibility") == 'hidden')  {
      toggleMark("trail-mark", this, 0, parseInt(points.length/2));
      switchButton(this, false);
    } else if (document.getElementById("line-" + (parseInt(points.length/2)+1)).getAttribute("visibility") == 'hidden') {
      toggleMark("trail-mark", this, 0, parseInt(points.length/2));
      toggleMark("trail-mark", this, parseInt(points.length/2) + 1, points.length-1);
      switchButton(this, true);
    } else {
      toggleMark("trail-mark", this, parseInt(points.length/2) + 1, points.length-1);
      switchButton(this, true);
    }
  };

  document.getElementById("trail-color-button").onclick = function(e) {
    colorTrail();
  };

  document.getElementById("trail-button").onclick = function(e) {
    toggleMark("trail-mark", this);
  };

  document.getElementById("image-media").onclick = function(e) {
    closeImage();
  };

  document.getElementById("help-button").onclick = function(e) {
    toggleHelp();
  };

  document.getElementById("help-detail").onclick = function(e) {
    toggleHelp();
  };

  document.getElementById("help-overlay").onclick = function(e) {
    toggleHelp();
  };

  function switchButton(button, on) {
    button.style.color = on ? 'lime' : 'white';
  }

  function toggleHelp() {
    var help = document.getElementById("help-detail");
    var set_value = help.style.display == 'none' ? 'inherit' : 'none';
    switchButton(document.getElementById("help-button"), set_value != 'none');
    var help = document.getElementsByClassName("help");
    for (i = 0; i < help.length; i++) {
      help[i].style.display = set_value;
    }
  }

  function toggleMark(cls, button, start_ix, length) {
    start_ix = start_ix || 0;
    var marks = document.getElementsByClassName(cls);
    length = length || marks.length;
    var set_value = marks[start_ix].getAttribute("visibility") == 'hidden' ? 'visible' : 'hidden';
    switchButton(button, set_value != 'hidden');
    for (i = start_ix; i < length; i++) {
      marks[i].setAttribute("visibility", set_value);
    }
  }

  function setGraphMark(id, opacity) {
      document.getElementById("graph-bar-" + id).style["opacity"] = opacity || 0.0;
  }

  function updateGraph(ix) {
      setGraphMark(ix, 1.0);
      setGraphMark(point_ix, 0.0);

      if (isNaN(mark_ix)) {
	  document.getElementById("graph-mark-to-point").setAttribute("visibility", 'hidden');
      } else {
	  var mark = document.getElementById("graph-mark-to-point");
	  mark.setAttribute("visibility", 'visible');
	  var left_x = document.getElementById("graph-bar-" + Math.min(mark_ix, ix)).getAttribute("x");
	  var right_x = document.getElementById("graph-bar-" + Math.max(mark_ix, ix)).getAttribute("x");
	  mark.setAttribute("x", left_x);
	  mark.setAttribute("width", right_x - left_x);
      }
  }

  var wims = document.getElementsByClassName("waypoint-image");
  for (i = 0; i < wims.length; i++) {
      wims[i].onclick = function(e) {
	e.stopPropagation();
	viewImage(e.target.getAttribute("xlink:href"), e.target.getAttribute("x-audio"));
      }
  }

  function closeImage() {
    var iv = document.getElementById("image-viewer");
    var aw = document.getElementById("audio-wrapper");
    iv.style.display = 'none';
    if (aw) { iv.removeChild(aw); }
  }

  function viewImage(url, audio) {
    var iv = document.getElementById("image-viewer");
    iv.children[0].src = url;
    if (audio) {
      var de = document.createElement("div");
      var ae = document.createElement("audio");
      var se = document.createElement("source");
      de.style.padding = 4;
      de.setAttribute("id", "audio-wrapper");
      ae.setAttribute("controls", true);
      se.setAttribute("src", audio);
      se.setAttribute("type", "audio/mpeg");
      ae.appendChild(se);
      de.appendChild(ae);
      iv.appendChild(de);
    }
    iv.style.display = 'inherit';
  }

  var trail_colors = ["speed_color", "ele_color"];
  var trail_color_ix = 0;
  function colorTrail() {
    if (++trail_color_ix >= trail_colors.length) { trail_color_ix = 0; }
    for (i = 0; i < points.length; i++) {
	document.getElementById("line-" + i).style.stroke = points[i][trail_colors[trail_color_ix]];
    }
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
