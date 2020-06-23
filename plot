#!/usr/bin/env perl6

use lib 'lib';

use Markers;
use GPXParser;
use Commands;

use JSON::Tiny;
use Template::Mustache;


sub MAIN (Str $file where *.IO.f,
          Bool :a(:$all_markers) = False) {

    my $markers = Markers.new(json_file => './data/points.json');
    my $gpx = GPXParser.new(file => $file, markers => $markers);
    my $track = $gpx.track;
    my $maps = $gpx.maps;
    my $commands = Commands.new;

    my $html_templ = Template::Mustache.new: :from<./templates/html>, :extension<.html>;
    my $js_templ = Template::Mustache.new: :from<./templates/js>, :extension<.js>;

    my %ctx = title => $track.title,
              date => $track.date,
              desc => ($track.desc eq 'Your Track' ?? '' !! $track.desc),
              image => $markers.images{$track.title},
              points => $track.points,
              rests => $track.rests.list,
              bounds => $track.bounds,
              summary => $track.summary_display,
              total_rest_time => $track.rests.total_rest_time,
              time_intervals => $track.intervals.times,
              distance_intervals => $track.intervals.distances,
              view_box => $track.view_box,
              mark_radius => 12,
              tile_x => $maps.tile_x,
              tile_y => $maps.tile_y,
              markers => $markers.select(:$maps, :$track, :$all_markers),
              maps => $maps.list,
              button_groups => $commands.list_grouped,
              help => help;

    my %parts = js_head => slurp('templates/js/head.js'),
                js_body => slurp('templates/js/body.js'),
                js_points => slurp('./templates/js/js_points.js'),
                svg => slurp('./templates/html/svg.html');

    say $html_templ.render('page', %ctx, :from(%parts));

    $markers.save;
}


sub help {
    # leaving this for now as a last remnant of the old way
    qq:to/END/;
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
        { help_item('Tab', 'Toggle measure detail') }
        { help_item('`', 'Set measure mark (current/start)') }
        { help_item('c', 'Next trail color map') }
        { help_item('h', 'Show this help') }
        { help_item() }
        { help_item('?', 'Show this help') }
        { help_item('&hellip;', 'Next button group') }
        { help_item() }
        { help_item('Map', 'Drag to move. Double click to centre') }
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
