class Rests {
    has Hash @.list;
    has Int $.rest_threshold = 3 * 60; # 3 minutes
    has Int $!current_rest_time = 0;
    has Int $.total_rest_time = 0;
    has Int $!rest_x;
    has Int $!rest_y;

    method add_point($p) {
        if $p<spd> < 0.1 {
	          unless $!current_rest_time { $!rest_x = $p<x>; $!rest_y = $p<y>; }
            $!current_rest_time += $p<interval>;
        } elsif $!current_rest_time {
            $!current_rest_time += $p<interval>;
            self.process_rest_candidate;
        }
    }


    method finished {
        self.process_rest_candidate;
    }


    method process_rest_candidate {
        if $!current_rest_time > $!rest_threshold {
            @!list.push({x => $!rest_x, y => $!rest_y, time => $!current_rest_time});
            $!total_rest_time += $!current_rest_time;
        }
        $!current_rest_time = 0;
    }
}
