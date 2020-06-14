use Bounds;

constant R = 6371000; # radius of Earth in metres

class Track {
    has Str $.title is rw;
    has Str $.desc is rw;
    has @.points;
    has Bounds %.bounds = lat => Bounds.new,
                          lon => Bounds.new,
                          ele => Bounds.new,
                          tim => Bounds.new,
                          dst => Bounds.new,
                          spd => Bounds.new;

    method date() {
        @.points.head<time>.Date.Str;
    }

    method add_point(%pt is copy) {
        return unless %pt;
        return unless %pt<lat>;

        %pt<tim> = %pt<time>.Instant.Rat;
        %pt<dst> = 0;
        %pt<spd> = 0;

        if @!points.tail {
	          %pt<dst> = calculate_distance(@!points.tail, %pt);
	          if %pt<tim> > @!points.tail<tim> {
	              %pt<spd> = %pt<dst> / (%pt<tim> - @!points.tail<tim>);
	          }
        }

        @!points.push(%pt);

        for %!bounds.kv -> $k, $v {
            $v.add(%pt{$k});
        }
    }

    method points_to_js() {
        for @!points.kv -> $ix, $p {
            $p<ele> ||= %!bounds<ele>.min;
            say qq:to/END/;
                  points.push(\{\});
                  points.slice(-1)[0]["lat"] = { $p<lat> };
                  points.slice(-1)[0]["lon"] = { $p<lon> };
                  points.slice(-1)[0]["ele"] = { $p<ele>.round };
                  points.slice(-1)[0]["dst"] = "{ (sprintf '%.2f', $p<dst>.round(.01)).Str }";
                  points.slice(-1)[0]["date"] = (new Date("{ $p<time> }"));
                  points.slice(-1)[0]["tim"] = points.slice(-1)[0]["date"].toLocaleTimeString();
                  points.slice(-1)[0]["tstamp"] = points.slice(-1)[0]["date"].getTime();
                  points.slice(-1)[0]["spd"] = "{ mps_to_kph($p<spd> || 0) }";
                  points.slice(-1)[0]["speed_color"]  = "{ scaled_color(%!bounds<spd>.scale($p<spd>)) }";
                  points.slice(-1)[0]["ele_color"]  = "{ scaled_color(%!bounds<ele>.scale($p<ele>)) }";
            END
        }
    }
}


sub mps_to_kph($mps) {
    (sprintf '%.2f', ($mps/1000*3600).round(.01)).Str ~ ' kph';
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
