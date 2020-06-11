use Bounds;

class Track {
    has Str $.title is rw;
    has @.points;
    has Bounds %.bounds = lat => Bounds.new,
                          lon => Bounds.new,
                          ele => Bounds.new,
                          tim => Bounds.new,
                          dst => Bounds.new,
	                        spd => Bounds.new;

    method add_point(%pt is copy) {
        return unless %pt;
        return unless %pt<lat>;
        return if @!points && !%pt<spd>;

        @!points.push(%pt);

        for %!bounds.kv -> $k, $v {
            $v.add(%pt{$k});
        }
    }

    method points_to_js() {
        for @!points.kv -> $ix, $p {
            say qq:to/END/;
                points.push(\{\});
                points.slice(-1)[0]["lat"] = { $p<lat> };
                points.slice(-1)[0]["lon"] = { $p<lon> };
                points.slice(-1)[0]["ele"] = { $p<ele>.round };
                points.slice(-1)[0]["dst"] = "{ (sprintf '%.2f', ($p<dst> || 0).round(.01)).Str }";
                points.slice(-1)[0]["date"] = (new Date("{ $p<tim> }"));
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

sub scaled_color($val, $r = Any, $g = Any, $b = Any) {
    my $sv = sprintf('%x', $val * 223 + 16);
    '#' ~ ($sv x 3);
}
