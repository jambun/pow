use JSON::Tiny;

class Markers {
    has $.points;
    has $.json_file;
    has %.images;
    has %.audio;
    has Str $.images_dir;
    has Str $.audio_dir;

    submethod BUILD(:$json_file) {
        $!json_file = $json_file;

        $!images_dir = 'html/img';
        $!audio_dir = 'html/audio';
        self.find_images;
        self.find_audio;

        self.load;
    }


    method load() {
        $!points = from-json slurp($!json_file);
    }


    method find_images {
        for dir($!images_dir) -> $d {
            next unless $d.extension eq 'jpg';
            %!images{$d.basename.chop(4)} = $!images_dir.split('/')[1] ~ '/' ~ $d.basename;
        }
    }


    method find_audio {
        for dir($!audio_dir) -> $d {
            next unless $d.extension eq 'mp3';
            %!audio{$d.basename.chop(4)} = $!audio_dir.split('/')[1] ~ '/' ~ $d.basename;
        }
    }


    method add(%m is copy) {
        unless $!points.grep({ $_<lat> eq %m<lat> && $_<lon> eq %m<lon> }) {
            %m<time> = %m<time>.Str;
            $!points.push(%m);
        }
    }


    method save() {
        spurt $!json_file, to-json $!points;
    }


    method select(:$track, :$maps, :$all_markers) {
        my @out = $all_markers ?? $!points.grep({$maps.in_box($_<lat>, $_<lon>,
                                                              $maps.lat_bounds.min, $maps.lon_bounds.min,
                                                              $maps.lat_bounds.max, $maps.lon_bounds.max)})
                               !! $!points.grep({$track.bounds<tim>.include(DateTime.new($_<time>).Instant.Int)});

        for @out -> $p {
            ($p<x>, $p<y>) = $maps.coords($p<lat>, $p<lon>);

            $p<audio> = %!audio{$p<name>.trim};
            $p<image> = %!images{$p<name>.trim};
            $p<image_x> = $p<x> - 11;
            $p<image_y> = $p<y> - 55;

            $p<polygon> = sprintf('%s,%s %s,%s %s,%s', $p<x>, $p<y>, $p<x> - 10, $p<y> - 30, $p<x> + 10, $p<y> - 30);
            $p<text_x> = $p<x> - 10 + ($p<image> ?? 22 !! 0);
            $p<text_y> = $p<y> - 35;

            my $track_point = $track.points.grep({$_<time> gt $p<time>}).head;
            if ($track_point) {
                $p<point_ix> = $track_point<ix>;
                $track_point<waypoint> = $p<name>;
            }
        }

        @out;
    }
}
