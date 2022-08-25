use Track;
use Markers;
use Maps;

class PowParser {
    has Str $.file;
    has Markers $.markers;
    has Track $.track;
    has Maps $.maps;
    has Str @.headers;
    has Str @.expected_headers;

    submethod BUILD(:$file, :$markers) {
        $!file = $file;
        $!markers = $markers;
        $!track = Track.new;

        @!expected_headers = <tim lat lon ele>;

        my $title = $file;
        $title = $title.split('/')[*-1];
        $title.= subst(/.csv$/, '');
        $title ~~ s:g/(<[A .. Z]>)/ $0/;
#        $title ~~ s:g/(<[A .. Z]>)/ $0/;
        $!track.title = $title.trim;

        $!track.desc = '';

        my $fh = open($!file, :r);
        my @cells;
        my %line;
        my $section;
        my $point_secs = 5.0;
        my $last_time;

        @!headers = get_line($fh);

        unless (@!headers == @!expected_headers) {
            $*ERR.say("HEADER MISMATCH", @!headers, @!expected_headers);
        }

        until $fh.eof {
            @cells = get_line($fh);

            next unless @cells;

            %line = Hash.new(@!headers Z @cells);

            my $time = DateTime.new(%line{'tim'}.Rat / 1000);

            if (!$last_time || $time.posix >= $last_time.posix + $point_secs) {

                my %p = lat => %line<lat>.Rat,
                lon => %line<lon>.Rat,
                ele => %line{'ele'},
	              time => $time;

                dst_err => %line{'acc'},
                ele_err => %line{'ela'},

                $!track.add_point(%p);

                $last_time = $time;
            }
        }

        $fh.close;

        $!maps = Maps.new(track => $!track);

        $!track.post_process($!maps);
    }

    sub get_line($fh) {
        my $line = $fh.get;
        return [] unless $line;

        $line.split(',');
    }

}
