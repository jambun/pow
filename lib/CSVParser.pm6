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
        $title.=subst(/_/, ' ', :g);
        $!track.title = $title.wordcase;

        $!track.desc = '';

        my $fh = open($!file, :r);
        my @cells;
        my %line;
        my $section;

        until $fh.eof {
            @cells = get_line($fh);

            next unless @cells;

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
	                      time => DateTime.new(%line<Date>.subst(/\s/, 'T')),
                        desc => %line<Notes>.subst('(null)', '');

                $!markers.add(%p);
            } elsif ($section eq 'Track') {
                my %p = lat => %line<Latitude>.Rat,
                        lon => %line<Longitude>.Rat,
                        ele => %line{'Altitude(m)'},
                        dst_err => %line{'Horizontal Accuracy(m)'},
                        ele_err => %line{'Vertical Accuracy(m)'},
	                      time => DateTime.new(%line{'Date(GMT)'}.subst(/\s/, 'T'));

                $!track.add_point(%p);

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
