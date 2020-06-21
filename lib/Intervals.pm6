class Intervals {
    has Hash @.times;
    has Hash @.distances;
    has Int $.time_interval = 15 * 60;  # 15 mins
    has Int $.distance_interval = 1000; # 1 km
    has Rat $!last_time_mark = 0.0;
    has Rat $!last_distance_mark = 0.0;
    has Int $!label_x_offset = 12;
    has Int $!label_y_offset = 4;

    method add_point($p) {
        if $p<total_time> > $!last_time_mark + $!time_interval {
	          my $label = (((@!times.elems + 1) * 15) / 60).Int ~ ':' ~ sprintf('%02s', (((@!times.elems + 1) * 15) % 60).round);
            @!times.push({x => $p<x>, y => $p<y>, label => $label, label_x => $p<x> + $!label_x_offset, label_y => $p<y> + $!label_y_offset});
            $!last_time_mark += $!time_interval;
        }

        if $p<total_distance> > $!last_distance_mark + $!distance_interval {
            my $label = (@!distances.elems + 1) ~ 'km';
            @!distances.push({x => $p<x>, y => $p<y>, label => $label, label_x => $p<x> + $!label_x_offset, label_y => $p<y> + $!label_y_offset});
            $!last_distance_mark += $!distance_interval;
        }
    }
}
