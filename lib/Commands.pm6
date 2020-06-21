class Commands {
    has @.buttons;
    has @.groups;

    submethod BUILD {
        @!groups = <base navigation animation display>;

        @!buttons =
          {id => 'help', key => 'h', group => 'base', label => '?', title => 'Show help', on => True},
          {id => 'select', key => ';', group => 'base', label => '&hellip;', title => 'Select button group', on => False},

          {id => 'reset', key => '0', group => 'navigation', label => '0', title => 'Reset to original zoom position', on => False},
          {id => 'zoom-in', key => '=', group => 'navigation', label => '+', title => 'Zoom in', on => False},
          {id => 'zoom-out', key => '-', group => 'navigation', label => '-', title => 'Zoom out', on => False},
          {id => 'move-north', key => 'ArrowUp', group => 'navigation', label => '&#8593;', title => 'Move north', on => False},
          {id => 'move-west', key => 'ArrowLeft', group => 'navigation', label => '&#8592;', title => 'Move west', on => False},
          {id => 'move-east', key => 'ArrowRight', group => 'navigation', label => '&#8594;', title => 'Move east', on => False},
          {id => 'move-south', key => 'ArrowDown', group => 'navigation', label => '&#8595;', title => 'Move south', on => False},

          {id => 'goto-start', key => 'Enter', group => 'animation', label => '&larrb;', title => 'Go to start', on => False},
          {id => 'goto-end', key => '\\\'', group => 'animation', label => '&rarrb;', title => 'Go to end', on => False},
          {id => 'step-fwd', key => ' ', group => 'animation', label => '&rarr;', title => 'Step forward', on => False},
          {id => 'step-bwd', key => 'b', group => 'animation', label => '&larr;', title => 'Step backward', on => False},
          {id => 'animate-fwd', key => ']', group => 'animation', label => '&vrtri;', title => 'Animate forward', on => False},
          {id => 'animate-bwd', key => '[', group => 'animation', label => '&vltri;', title => 'Animate backward', on => False},
          {id => 'follow', key => '/', group => 'animation', label => '&target;', title => 'Toggle follow target', on => False},
          {id => 'faster', key => '\\\\', group => 'animation', label => '&raquo;', title => 'Faster', on => False},
          {id => 'slower', key => 'p', group => 'animation', label => '&laquo;', title => 'Slower', on => False},
          {id => 'original-speed', key => 'o', group => 'animation', label => 'o', title => 'Original speed', on => True},
          {id => 'stop', key => 'q', group => 'animation', label => '!', title => 'Stop animation', on => False},

          {id => 'trail-half', key => 'k', group => 'display', label => '&half;', title => 'Show trail out/back/all', on => False},
          {id => 'trail-color', key => 'c', group => 'display', label => 'C', title => 'Next trail color map', on => False},
          {id => 'trail', key => 'l', group => 'display', label => 'L', title => 'Toggle trail marks', on => True},
          {id => 'dist', key => 'd', group => 'display', label => 'D', title => 'Toggle km marks', on => True},
          {id => 'time', key => 't', group => 'display', label => 'T', title => 'Toggle 15 min marks', on => True},
          {id => 'rest', key => 'r', group => 'display', label => 'R', title => 'Toggle rest marks', on => True},
          {id => 'waypoint', key => 'w', group => 'display', label => 'W', title => 'Toggle waypoints', on => True},
          {id => 'graph', key => 'g', group => 'display', label => 'G', title => 'Toggle graph', on => True},
          {id => 'summary', key => 's', group => 'display', label => 'S', title => 'Toggle summary detail', on => False};

        my %btn_cnt;
        for @!buttons -> $b {
            %btn_cnt{$b<group>} ||= ($b<group> eq 'base' ?? 0 !! @!buttons.grep({$_<group> eq 'base'}).elems);
            $b<top> = 10 + (%btn_cnt{$b<group>}) * 36;
            %btn_cnt{$b<group>} += 1;
        }
    }


    method list_grouped {
        eager @!groups.map: {
            my $g = $_; # bah!
            {
                name => $g,
                base => $g eq 'base',
                display => $g ~~ /display|base/,
                buttons => @!buttons.grep({$_<group> eq $g}).eager
            }
        }
    }
}
