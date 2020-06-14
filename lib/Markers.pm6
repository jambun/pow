use JSON::Tiny;

class Markers {
    has $.points;
    has $.json_file;


    method load() {
        $!points = from-json slurp($!json_file);
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
}
