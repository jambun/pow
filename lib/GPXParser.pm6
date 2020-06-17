use Track;
use Markers;

use XML;

class GPXParser {
    has Str $.file;
    has Markers $.markers;
    has Track $.track;


    submethod BUILD(:$file, :$markers) {
        $!file = $file;
        $!markers = $markers;
        $!track = Track.new;
        self.parse;
    }


    method parse {
        my $xml = from-xml-file($!file);

        for $xml.getElementsByTagName('trk') -> $trk {
            $!track.title = tag_contents($trk, 'name');
            $!track.desc = tag_contents($trk, 'desc');
        }

        for $xml.getElementsByTagName('wpt') -> $wpt {
            my %p = name => tag_contents($wpt, 'name'),
                    lat => $wpt.attribs<lat>.Rat,
                    lon => $wpt.attribs<lon>.Rat,
	                  time => DateTime.new(tag_contents($wpt, 'time')),
                    desc => tag_contents($wpt, 'desc');

            if (has_tag($wpt, 'ele')) {
                %p<ele> = tag_contents($wpt, 'ele').Rat;
            }

            $!markers.add(%p);
        }

        for $xml.getElementsByTagName('trkpt') -> $trkpt {
            my %p = lat => $trkpt.attribs<lat>.Rat,
                    lon => $trkpt.attribs<lon>.Rat,
	                  time => DateTime.new(tag_contents($trkpt, 'time'));

            if (has_tag($trkpt, 'ele')) {
                %p<ele> = tag_contents($trkpt, 'ele').Rat;
            }

            $!track.add_point(%p);
        }

        $!track.post_process;
    }


    sub has_tag($xml, $tag_name) {
        !!$xml.getElementsByTagName($tag_name).elems;
    }


    sub tag_contents($xml, $tag_name) {
        my $tags = $xml.getElementsByTagName($tag_name);
        if !!$tags.elems {
            $tags[0].contents.join(' ');
        } else {
            '';
        }
    }
}
