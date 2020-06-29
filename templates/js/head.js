var points = [];
var point_ix = 0;
var mark_ix = 0;
var animation_rate = 1;
var keep_point_centered = false;
var tile_x = {{tile_x}};
var tile_y = {{tile_y}};
var map_metadata = JSON.parse('{{{map_metadata}}}');

{{> js_points}}

window.onload = function(e) {
    var wrap = document.getElementById("plotmap-wrapper");

    vb = {
        left: 0,
        top: 0,
        width: 0,
        height: 0,
        plotmap: pm, 
        load: function() {
            var vb = plotmap.getAttribute("viewBox").split(" ");
            this.left = parseInt(vb[0]);
            this.top = parseInt(vb[1]);
            this.width = parseInt(vb[2]);
            this.height = parseInt(vb[3]);
        },
        to_s: function() {
            return [this.left, this.top, this.width, this.height].join(' ');
        },
        set: function() {
            this.plotmap.setAttribute('viewBox', this.to_s());
        },
        mark_origin: function() {
            this.origin = this.to_s();
        },
        set_origin: function() {
            this.plotmap.setAttribute('viewBox', this.origin);
            this.load();
        }
    }
    vb.load();

    var left_padding = vb.width / wrap.clientWidth * 40;
    vb.left -= left_padding;
    vb.width += left_padding;

    var top_padding = vb.height / wrap.clientHeight * 120;
    vb.top -= top_padding;
    vb.height += top_padding;

    var aspect = wrap.clientWidth / wrap.clientHeight;
    if (aspect > 1) { vb.left -= (vb.height * aspect - vb.width)/2; vb.width = vb.height * aspect; }
    if (aspect < 1) { vb.top -= (vb.width * aspect - vb.height)/2; vb.height = vb.width / aspect; }

    vb.set();
    vb.mark_origin();

    toggleMark('dist-mark', document.getElementById("dist-button"));
    toggleMark('time-mark', document.getElementById("time-button"));
    toggleMark('rest-mark', document.getElementById("rest-button"));
    updateMeasureMarks();
    show_point(point_ix);
}

function show_point(ix, loop_around) {
    var pl = document.getElementById("line-" + ix);
    if (pl == null) {
        if (loop_around) {
	          ix = ix < 1 ? points.length - 1 : 0;
	          pl = document.getElementById("line-" + ix);
        } else {
	          return;
        }
    }
  
    var pt = document.getElementById("point-target");
    pt.setAttribute("cx", pl.getAttribute("x2"));
    pt.setAttribute("cy", pl.getAttribute("y2"));

    var ptc = document.getElementById("point-target-centered");
    ptc.setAttribute("cx", pl.getAttribute("x2"));
    ptc.setAttribute("cy", pl.getAttribute("y2"));

    var pts = document.getElementById("point-target-spot");
    pts.setAttribute("cx", pl.getAttribute("x2"));
    pts.setAttribute("cy", pl.getAttribute("y2"));

    document.getElementById("point-tim").innerHTML = points[ix].tim;
    document.getElementById("point-lat").innerHTML = "Lat: " + points[ix].lat;
    document.getElementById("point-lon").innerHTML = "Lon: " + points[ix].lon;
    document.getElementById("point-ele").innerHTML = "Ele: " + points[ix].ele + "m";
    document.getElementById("point-spd").innerHTML = points[ix].spd_kph;

    updateGraph(ix);

    document.getElementById("line-" + point_ix).style.strokeWidth = 12;
    pl.style.strokeWidth = 40;
    
    point_ix = ix;

    if (keep_point_centered) { center_on_point(); }

    updateMeasureMarks();
}
