class Bounds is Associative {
    has $.min;
    has $.max;

    method add($val) {
	      $!min = $val if !$!min.defined || $val < $!min;
	      $!max = $val if !$!max.defined || $val > $!max;
    }

    method include($val) {
	      $val >= $!min && $val <= $!max;
    }

    method range() {
	      $!max - $!min;
    }

    method scale($val) {
	      return unless self.include($val);
	      ($val - $!min) / self.range;
    }

    method AT-KEY(\k) {
        given \k {
            when 'range' {
                self.range;
            }
            when 'min' {
                self.min;
            }
            when 'max' {
                self.max;
            }
        }
    }

    method EXISTS-KEY(\k) {
        \k ~~ /range|min|max/ ?? True  !! False;
    }
}
