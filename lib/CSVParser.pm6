use Track;
use Markers;
use Maps;

#use CSV::Parser;

class CSVParser {
    has Str $.file;
    has Markers $.markers;
    has Track $.track;
    has Maps $.maps;
    has Str @.headers;

    submethod BUILD(:$file, :$markers) {
        $!file = $file;
        $!markers = $markers;
        $!track = Track.new;

        my $title = $file;
        $title = $title.split('/')[*-1];
        $title.=subst(/.csv$/, '');
        $title ~~ s:g/(<[A .. Z]>)/ $0/;
        $!track.title = $title.trim;

        $!track.desc = '';

        my $fh = open($!file, :r);
        my @cells;
        my %line;
        my $section;
        my $point_secs = 5.0;
        my $last_time;

        until $fh.eof {
            @cells = get_line($fh);

            next unless @cells;

            if ((@cells[*-1] ~~ m:g/ <["]> /).elems == 1) {
                @cells[*-1] ~= ' ' ~ get_line($fh).head;
                @cells[*-1] ~~ s:g/ <["]> //;
            }

            %line = Hash.new(@!headers Z @cells);

            my $first = @cells.first;

            if ($first eq 'Waypoints' || $first eq 'Track') {
                $section = $first;
                @!headers = get_line($fh);
                next;
            }

            if ($section eq 'Waypoints') {
                my %p = name => %line<Name>,
                        lat => %line<Latitude>.Rat,
                        lon => %line<Longitude>.Rat,
                        ele => %line{'Altitude (m)'},
	                      time => DateTime.new(%line<Date>.subst(/\s/, 'T'));

                %p<desc> = %line<Notes>.subst('"(null)"', '') if %line<Notes>.subst('"(null)"', '');

                $!markers.add(%p);
            } elsif ($section eq 'Track') {
                my $time = DateTime.new(%line{'Date(GMT)'}.subst(/\s/, 'T'));

                if (!$last_time || $time.posix >= $last_time.posix + $point_secs) {

                    my %p = lat => %line<Latitude>.Rat,
                    lon => %line<Longitude>.Rat,
                    ele => %line{'Altitude(m)'},
                    dst_err => %line{'Horizontal Accuracy(m)'},
                    ele_err => %line{'Vertical Accuracy(m)'},
	                  time => DateTime.new(%line{'Date(GMT)'}.subst(/\s/, 'T'));

                    $!track.add_point(%p);

                    $last_time = $time;
                }
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
