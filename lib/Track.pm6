use Bounds;
use Rests;
use Intervals;

constant R = 6371000; # radius of Earth in metres

class Track {
    has Str $.title is rw;
    has Str $.desc is rw;
    has Str $.view_box;
    has Hash @.points;
    has Rests $.rests = Rests.new;
    has Intervals $.intervals = Intervals.new;
    has Num $.total_distance = 0e0;
    has Num $.total_climb = 0e0;
    has Int $.start_time = 0;
    has Int $.total_time = 0;
    has Bounds %.bounds = lat => Bounds.new,
                          lon => Bounds.new,
                          ele => Bounds.new,
                          tim => Bounds.new,
                          dst => Bounds.new,
                          spd => Bounds.new;
    has %.summary;


    method date() {
        @.points.head<time>.Date.Str;
    }


    method add_point(%pt is copy) {
        return unless %pt;
        return unless %pt<lat>;

        %pt<tim> = %pt<time>.Instant.Int;
        %pt<dst> = 0.0;
        %pt<spd> = 0.0;
        %pt<ix> = @!points.elems.Str;

        if @!points.tail {
	          %pt<dst> = calculate_distance(@!points.tail, %pt);
            if %pt<ele> && @!points.tail<ele> {
                my $climb = %pt<ele> - @!points.tail<ele>;
                if $climb > 0 {
                    $!total_climb += $climb;
                    %pt<climb_color> = '#ff3333';
                } else {
                    %pt<climb_color> = '#3333ff';
                }
            } else {
                %pt<climb_color> = '#3333ff';
            }
            $!total_distance += %pt<dst>;
            $!total_time = %pt<tim> - $!start_time;
	          if %pt<tim> > @!points.tail<tim> {
	              %pt<spd> = %pt<dst> / (%pt<tim> - @!points.tail<tim>);
	          }
        } else {
            $!start_time = %pt<tim>;
        }

        %pt<total_distance> = $!total_distance;
        %pt<total_distance_round> = (sprintf '%.2f', %pt<total_distance>.round(.01)).Str;
        %pt<total_time> = $!total_time;

        @!points.push(%pt);

        for %!bounds.kv -> $k, $v {
            $v.add(%pt{$k});
        }
    }


    method post_process($maps) {
        my ($bxn, $byn) = $maps.coords(%!bounds<lat>.min, %!bounds<lon>.min);
        my ($bxx, $byx) = $maps.coords(%!bounds<lat>.max, %!bounds<lon>.max);
        $!view_box = $bxn-100 ~ ' ' ~ $byx-100 ~ ' ' ~ $bxx-$bxn+200 ~  ' ' ~ $byn-$byx+200;

        my $lastp;
        for @!points -> $p {
            $p<ele> ||= %!bounds<ele>.min;
            $p<ele_round> = $p<ele>.round;
            $p<dst_round> = (sprintf '%.2f', $p<dst>.round(.01)).Str;
            $p<spd_kph> = mps_to_kph($p<spd> || 0);
            $p<speed_color> = scaled_color(%!bounds<spd>.scale($p<spd>));
            $p<ele_color> = scaled_color(%!bounds<ele>.scale($p<ele>));

            ($p<x>, $p<y>) = $maps.coords($p<lat>, $p<lon>);

            $p<graph_x> = ($p<tim> - %!bounds<tim>.min) / %!bounds<tim>.range * 1000;
            $p<graph_x_str> = (($p<tim> - %!bounds<tim>.min) / %!bounds<tim>.range * 1000).Str;

            if $lastp {
                $p<lastx> = $lastp<x>;
                $p<lasty> = $lastp<y>;
                $p<interval> = $p<tim> - $lastp<tim>;
                $p<graph_lastx> = $lastp<graph_x>;

                $!rests.add_point($p);
                $!intervals.add_point($p);
            } else {
                $p<lastx> = $p<x>;
                $p<lasty> = $p<y>;
                $p<interval> = 0;
                $p<graph_lastx> = $p<graph_x>;
            }

            $p<graph_width> = (($p<graph_x> - $p<graph_lastx>).Int, 2).max;
            $p<graph_ele_y> = 100 - ($p<ele> - %!bounds<ele>.min) / %!bounds<ele>.range * 100;
            $p<graph_spd_y> = 100 - (($p<spd> || 0) - %!bounds<spd>.min) / %!bounds<spd>.range * 100;

            $p<graph_lastx_str> = $p<graph_lastx>.Str;
            $p<graph_ele_y_str> = $p<graph_ele_y>.Str;
            $p<graph_spd_y_str> = $p<graph_spd_y>.Str;

            $lastp = $p;
        }

        $!rests.finished;

        %!summary = total_distance => ($!total_distance/1000).round(.01) ~ 'km',
                    total_time => sec_to_hm($!total_time),
                    total_rest => sec_to_hm($!rests.total_rest_time),
                    total_climb => $!total_climb.round ~ 'm',
                    min_elevation => %!bounds<ele>.min.round ~ 'm',
                    max_elevation => %!bounds<ele>.max.round ~ 'm',
                    average_speed => mps_to_kph($!total_distance/$!total_time),
                    non_rest_speed => mps_to_kph($!total_distance/($!total_time-$!rests.total_rest_time)),
                    max_speed => mps_to_kph(%!bounds<spd>.max);
    }


    method summary_display {
        {label => 'Total distance', value => %!summary<total_distance>},
        {label => 'Total time', value => %!summary<total_time>},
        {label => 'Rest time', value => %!summary<total_rest>},
        {label => '', value => ''},
        {label => 'Total climb', value => %!summary<total_climb>},
        {label => 'Min elevation', value => %!summary<min_elevation>},
        {label => 'Max elevation', value => %!summary<max_elevation>},
        {label => '', value => ''},
        {label => 'Avg speed', value => %!summary<average_speed>},
        {label => 'Non-rest speed', value => %!summary<non_rest_speed>},
        {label => 'Max speed', value => %!summary<max_speed>};
    }


    method points_to_js($templ) {
        $templ.render('point', { :@!points });
    }


    sub mps_to_kph($mps) {
        (sprintf '%.2f', ($mps/1000*3600).round(.01)).Str ~ ' kph';
    }


    sub sec_to_hm($sec) {
        ($sec / 3600).Int ~ 'hr ' ~ ($sec % 3600 / 60).round ~ 'min';
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


    sub scaled_color($val, $r = Any, $g = Any, $b = Any) {
        my $sv = sprintf('%x', $val * 223 + 16);
        '#' ~ ($sv x 3);
    }
}
