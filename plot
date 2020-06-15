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

say slurp('templates/js/head.js');

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
    '" width="' ~ $maps.tile_x ~ 'px" height="' ~ $maps.tile_y ~ 'px" x="' ~ ($md<tilex> - $maps.x_bounds.min) * $maps.tile_x ~
    '" y="' ~ ($md<tiley> - $maps.y_bounds.min) * $maps.tile_y ~ '" style="z-index:0;opacity:1;"/>';
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

say '<script>';

say slurp('templates/js/body.js');

say '</script>';
say '</body></html>';


sub svg_line($x1, $y1, $x2, $y2, :%style is copy) {
    my $style = (%style.map: -> $p { $p.key ~ ':' ~ $p.value }).join(';');
    my $out = '<line x1="' ~ $x1 ~ '" y1="' ~ $y1 ~ '" x2="' ~ $x2 ~ '" y2="' ~ $y2 ~ '" ';
    $out ~= 'style="' ~ $style ~ '"';
    $out ~= '/>';

    $out;
}
