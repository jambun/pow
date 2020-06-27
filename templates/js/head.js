var points = [];
var point_ix = 0;
var mark_ix = 0;
var animation_rate = 1;
var keep_point_centered = false;

{{> js_points}}

window.onload = function(e) {
    var wrap = document.getElementById("plotmap-wrapper");
    vb = viewbox_to_a();

    var left_padding = vb[2] / wrap.clientWidth * 40;
    vb[0] -= left_padding;
    vb[2] += left_padding;

    var top_padding = vb[3] / wrap.clientHeight * 120;
    vb[1] -= top_padding;
    vb[3] += top_padding;

    var aspect = wrap.clientWidth / wrap.clientHeight;
    if (aspect > 1) { vb[0] -= (vb[3] * aspect - vb[2])/2; vb[2] = vb[3] * aspect; }
    if (aspect < 1) { vb[1] -= (vb[2] * aspect - vb[3])/2; vb[3] = vb[2] / aspect; }

    set_viewbox();
    original_viewbox = vb.map((x) => x);

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
