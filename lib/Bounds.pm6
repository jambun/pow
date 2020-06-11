class Bounds {
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
}
