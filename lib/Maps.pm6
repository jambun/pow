use Track;
use Bounds;

use JSON::Tiny;
use HTTP::UserAgent;

class Maps {
    has Track $.track;
    has Str $.metadata_file = 'data/nsw25k.json';
    has Str $.tile_source_url = 'https://home.whaite.com/fet/imgraw/NSW_25k_Coast_South';
    has Str $.maps_dir = 'html/maps';
    has Str $.maps_url_dir = 'maps';
    has $.tile_x = 2000;
    has $.tile_y = 2000;
    has Bounds $.x_bounds = Bounds.new;
    has Bounds $.y_bounds = Bounds.new;
    has Rat $.lat_padding = 0.06;
    has Rat $.lon_padding = 0.06;
    has Hash @.metadata;

    method list {
        unless @!metadata {
            my $pban = $!track.bounds<lat>.min - $!lat_padding;
            my $pbax = $!track.bounds<lat>.max + $!lat_padding;
            my $pbon = $!track.bounds<lon>.min - $!lon_padding;
            my $pbox = $!track.bounds<lon>.max + $!lon_padding;

            my $json = from-json slurp($!metadata_file);

            for @$json -> $md {
                my $max_lat = ($md<topleft><lat>, $md<topright><lat>).max;
                my $min_lat = ($md<bottomleft><lat>, $md<bottomright><lat>).min;

                my $min_lon = ($md<topleft><long>, $md<bottomleft><long>).min;
                my $max_lon = ($md<topright><long>, $md<bottomright><long>).min;

                if ((self.in_box($pban, $pbon, $min_lat, $min_lon, $max_lat, $max_lon)) ||
                    (self.in_box($pban, $pbox, $min_lat, $min_lon, $max_lat, $max_lon)) ||
                    (self.in_box($pbax, $pbon, $min_lat, $min_lon, $max_lat, $max_lon)) ||
                    (self.in_box($pbax, $pbox, $min_lat, $min_lon, $max_lat, $max_lon)) ||

                    (self.in_box($min_lat, $min_lon, $pban, $pbon, $pbax, $pbox)) ||
                    (self.in_box($min_lat, $max_lon, $pban, $pbon, $pbax, $pbox)) ||
                    (self.in_box($max_lat, $min_lon, $pban, $pbon, $pbax, $pbox)) ||
                    (self.in_box($max_lat, $max_lon, $pban, $pbon, $pbax, $pbox))) {

                    $md<tile_ref> = self.tile_ref($md<filename>);

                    @!metadata.push: $md;

                    $!x_bounds.add($md<tilex>);
                    $!y_bounds.add($md<tiley>);
                }
            }

            for @!metadata -> $md {
                $md<x> = (($md<tilex> - $!x_bounds.min) * $!tile_x).Str;
                $md<y> = (($md<tiley> - $!y_bounds.min) * $!tile_y).Str;
            }

            self.cache_tiles;
        }

        @!metadata;
    }


    method cache_tiles {
        my $http = HTTP::UserAgent.new;
        for @!metadata -> $md {
            my $file_path = $!maps_dir ~ '/' ~ $md<filename>;
            if $file_path.IO.e {
#                note $md<filename> ~ ' already in cache';
            } else {
                note 'Caching ' ~ $md<filename>;
                my $resp = $http.request(HTTP::Request.new(:GET($!tile_source_url ~ '/' ~ $md<filename>)));
                spurt $file_path,  $resp.decoded-content;
            }
        }
    }


    method tile_ref($filename) {
        $!maps_url_dir ~ '/' ~ $filename;        
    }


    method coords($lat, $lon) {
        my %tile = self.list.head;
        my $x_t = (($lon - %tile<topleft><long>) / (%tile<topright><long> - %tile<topleft><long>)) * $!tile_x;
        my $x_b = (($lon - %tile<bottomleft><long>) / (%tile<bottomright><long> - %tile<bottomleft><long>)) * $!tile_x;
        my $y_l = (($lat - %tile<topleft><lat>) / (%tile<bottomleft><lat> - %tile<topleft><lat>)) * $!tile_y;
        my $y_r = (($lat - %tile<topright><lat>) / (%tile<bottomright><lat> - %tile<topright><lat>)) * $!tile_y;

        my $x_slope = ($x_b - $x_t) / $!tile_y;
        my $y_slope = ($y_r - $y_l) / $!tile_x;

        my $x = ($y_l * $x_slope + $x_t) / (1 - $x_slope * $y_slope);
        my $y = ($x_t * $y_slope + $y_l) / (1 - $y_slope * $x_slope);
    
        ($x.Int, $y.Int);
}

    sub in_range($x, $min, $max) {
        $x >= $min && $x <= $max;
    }

    method in_box($x, $y, $xmin, $ymin, $xmax, $ymax) {
        in_range($x, $xmin, $xmax) && in_range($y, $ymin, $ymax);
    }
}
