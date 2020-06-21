var zoom_factor = 0.8;
var move_step = 50;
var keep_animating = false;;
var pm = document.getElementById("plotmap");

document.onkeydown = function(e) {
    if (!(document.getElementById("help-detail").style.display == 'none')) { document.getElementById("help-button").click(); }

    {{#button_groups}}
      {{#buttons}}
        else if (e.key == '{{key}}') { document.getElementById("{{id}}-button").click(); }
      {{/buttons}}
    {{/button_groups}}

    e.preventDefault();
};

function move_map(x, y) {
    var vb = viewbox_to_a();
    vb[0] += x;
    vb[1] += y;
    pm.setAttribute("viewBox", a_to_viewbox(vb));
}

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function animate(rate) {
    var step = rate < 0 ? -1 : 1;
    if (!points[point_ix + step]) { show_point(step == 1 ? 0 : points.length - 1); }
    var button = document.getElementById(step == 1 ? 'animate-fwd-button' : 'animate-bwd-button');
    switchButton(button, true);
    while (true) {
        if (!keep_animating) { break; }
        if (!points[point_ix + step]) { keep_animating = false; break; }

        var wait = 100;
        if (points[point_ix - step]) {
	          wait = Math.abs((points[point_ix]["tstamp"] - points[point_ix - step]["tstamp"])
			                      * rate * animation_rate / 100);
        }

        await sleep(wait);
        show_point(parseInt(point_ix) + step);
    }
    switchButton(button, false);
}

function center_on_point() {
    var pl = document.getElementById("line-" + point_ix);
    if (pl == null) { return; }

    var vb = viewbox_to_a();
    vb[0] = pl.getAttribute("x2") - vb[2]/2;
    vb[1] = pl.getAttribute("y2") - vb[3]/2;

    document.getElementById("plotmap").setAttribute("viewBox", a_to_viewbox(vb));
}

pm.onclick = function(e){
    var wrap = document.getElementById("plotmap-wrapper");
    var vb = viewbox_to_a();
    var vx = (e.pageX - wrap.offsetLeft) / wrap.offsetWidth * vb[2];
    var vy = (e.pageY - wrap.offsetTop) / wrap.offsetHeight * vb[3];
    vb[0] = vx + vb[0] - vb[2]/2;
    vb[1] = vy + vb[1] - vb[3]/2;
    this.setAttribute("viewBox", a_to_viewbox(vb));
};

var button_groups = ['display', 'navigation', 'animation'];
var button_group_ix = 0;
document.getElementById("select-button").onclick = function(e) {
    var groups = document.getElementsByClassName("button-group");
    for (i = 0; i < groups.length; i++) {
        groups[i].style.display = 'none';
    }
    button_group_ix++;
    if (button_group_ix >= button_groups.length) { button_group_ix = 0; }
    document.getElementById(button_groups[button_group_ix] + '-button-group').style.display = 'inherit';
};

var original_viewbox = pm.getAttribute("viewBox");

document.getElementById("reset-button").onclick = function(e) {
    pm.setAttribute("viewBox", original_viewbox);
};

document.getElementById("zoom-in-button").onclick = function(e) {
    zoom(zoom_factor);
};

document.getElementById("zoom-out-button").onclick = function(e) {
    zoom(1/zoom_factor);
};

document.getElementById("move-north-button").onclick = function(e) {
    move_map(0, move_step*-1);
};

document.getElementById("move-west-button").onclick = function(e) {
    move_map(move_step*-1, 0);
};

document.getElementById("move-east-button").onclick = function(e) {
    move_map(move_step, 0);
};

document.getElementById("move-south-button").onclick = function(e) {
    move_map(0, move_step);
};

document.getElementById("goto-start-button").onclick = function(e) {
    keep_animating = false;
    show_point(0);
};

document.getElementById("goto-end-button").onclick = function(e) {
    keep_animating = false;
    show_point(points.length-1);
};

document.getElementById("step-fwd-button").onclick = function(e) {
    keep_animating = false;
    show_point(parseInt(point_ix) + 1, true);
};

document.getElementById("step-bwd-button").onclick = function(e) {
    keep_animating = false;
    show_point(parseInt(point_ix) - 1, true);
};

document.getElementById("animate-fwd-button").onclick = function(e) {
    if (!keep_animating) { keep_animating = true; animate(1); }
};

document.getElementById("animate-bwd-button").onclick = function(e) {
    if (!keep_animating) { keep_animating = true; animate(-1); }
};

document.getElementById("faster-button").onclick = function(e) {
    setAnimationRate(animation_rate/2);
};

document.getElementById("slower-button").onclick = function(e) {
    setAnimationRate(animation_rate*2);
};

document.getElementById("original-speed-button").onclick = function(e) {
    setAnimationRate(1);
};

function setAnimationRate(rate) {
    animation_rate = rate;
    switchButton(document.getElementById("faster-button"), rate < 1);
    switchButton(document.getElementById("slower-button"), rate > 1);
    switchButton(document.getElementById("original-speed-button"), rate == 1);
}

document.getElementById("stop-button").onclick = function(e) {
    keep_animating = false;
};

document.getElementById("follow-button").onclick = function(e) {
    keep_point_centered = !keep_point_centered;
    switchButton(this, keep_point_centered);
    if (keep_point_centered) { center_on_point(); }
};

document.getElementById("rest-button").onclick = function(e) {
    toggleMark("rest-mark", this);
};

document.getElementById("dist-button").onclick = function(e) {
    toggleMark("dist-mark", this);
};

document.getElementById("time-button").onclick = function(e) {
    toggleMark("time-mark", this);
};

document.getElementById("summary-button").onclick = function(e) {
    toggleSummary(this);
};

document.getElementById("summary").onclick = function(e) {
    toggleSummary(document.getElementById("summary-button"));
};

function toggleSummary(button) {
    var sum = document.getElementById("summary-detail");
    sum.style.display = sum.style.display == 'none' ? 'inherit' : 'none';
    switchButton(button, sum.style.display != 'none');
}

document.getElementById("graph-button").onclick = function(e) {
    var graph = document.getElementById("graph-wrapper");
    graph.style.display = graph.style.display == 'none' ? 'inherit' : 'none';
    switchButton(this, graph.style.display != 'none');
};

document.getElementById("waypoint-button").onclick = function(e) {
    toggleMark("waypoint-mark", this);
};

document.getElementById("trail-half-button").onclick = function(e) {
    // all > first > second > all ...
    if (document.getElementById("line-0").getAttribute("visibility") == 'hidden')  {
        toggleMark("trail-mark", this, 0, parseInt(points.length/2));
        switchButton(this, false);
    } else if (document.getElementById("line-" + (parseInt(points.length/2)+1)).getAttribute("visibility") == 'hidden') {
        toggleMark("trail-mark", this, 0, parseInt(points.length/2));
        toggleMark("trail-mark", this, parseInt(points.length/2) + 1, points.length-1);
        switchButton(this, true);
    } else {
        toggleMark("trail-mark", this, parseInt(points.length/2) + 1, points.length-1);
        switchButton(this, true);
    }
};

document.getElementById("trail-color-button").onclick = function(e) {
    colorTrail();
};

document.getElementById("trail-button").onclick = function(e) {
    toggleMark("trail-mark", this);
};

document.getElementById("image-media").onclick = function(e) {
    closeImage();
};

document.getElementById("help-button").onclick = function(e) {
    toggleHelp();
};

document.getElementById("help-detail").onclick = function(e) {
    toggleHelp();
};

document.getElementById("help-overlay").onclick = function(e) {
    toggleHelp();
};

function switchButton(button, on) {
    button.style.color = on ? 'lime' : 'white';
}

function toggleHelp() {
    var help = document.getElementById("help-detail");
    var set_value = help.style.display == 'none' ? 'inherit' : 'none';
    switchButton(document.getElementById("help-button"), set_value != 'none');
    var help = document.getElementsByClassName("help");
    for (i = 0; i < help.length; i++) {
        help[i].style.display = set_value;
    }
}

function toggleMark(cls, button, start_ix, length) {
    start_ix = start_ix || 0;
    var marks = document.getElementsByClassName(cls);
    length = length || marks.length;
    var set_value = marks[start_ix].getAttribute("visibility") == 'hidden' ? 'visible' : 'hidden';
    switchButton(button, set_value != 'hidden');
    for (i = start_ix; i < length; i++) {
        marks[i].setAttribute("visibility", set_value);
    }
}

function setGraphMark(id, opacity) {
    document.getElementById("graph-bar-" + id).style["opacity"] = opacity || 0.0;
}

function updateGraph(ix) {
    setGraphMark(ix, 1.0);
    setGraphMark(point_ix, 0.0);

    if (isNaN(mark_ix)) {
	      document.getElementById("graph-mark-to-point").setAttribute("visibility", 'hidden');
    } else {
	      var mark = document.getElementById("graph-mark-to-point");
	      mark.setAttribute("visibility", 'visible');
	      var left_x = document.getElementById("graph-bar-" + Math.min(mark_ix, ix)).getAttribute("x");
	      var right_x = document.getElementById("graph-bar-" + Math.max(mark_ix, ix)).getAttribute("x");
	      mark.setAttribute("x", left_x);
	      mark.setAttribute("width", right_x - left_x);
    }
}

var wims = document.getElementsByClassName("waypoint-image");
for (i = 0; i < wims.length; i++) {
    wims[i].onclick = function(e) {
	      e.stopPropagation();
	      viewImage(e.target.getAttribute("xlink:href"), e.target.getAttribute("x-audio"));
    }
}

function closeImage() {
    var iv = document.getElementById("image-viewer");
    var aw = document.getElementById("audio-wrapper");
    iv.style.display = 'none';
    if (aw) { iv.removeChild(aw); }
}

function viewImage(url, audio) {
    var iv = document.getElementById("image-viewer");
    iv.children[0].src = url;
    if (audio) {
        var de = document.createElement("div");
        var ae = document.createElement("audio");
        var se = document.createElement("source");
        de.style.padding = 4;
        de.setAttribute("id", "audio-wrapper");
        ae.setAttribute("controls", true);
        se.setAttribute("src", audio);
        se.setAttribute("type", "audio/mpeg");
        ae.appendChild(se);
        de.appendChild(ae);
        iv.appendChild(de);
    }
    iv.style.display = 'inherit';
}

var trail_colors = ["speed_color", "ele_color"];
var trail_color_ix = 0;
function colorTrail() {
    if (++trail_color_ix >= trail_colors.length) { trail_color_ix = 0; }
    for (i = 0; i < points.length; i++) {
	      document.getElementById("line-" + i).style.stroke = points[i][trail_colors[trail_color_ix]];
    }
}

function viewbox_to_a() {
    var vb = document.getElementById("plotmap").getAttribute("viewBox").split(" ");
    for (i = 0; i < vb.length; i++) {
        vb[i] = parseInt(vb[i]);
    }
    return vb;
}

function a_to_viewbox(vb) {
    for (i = 0; i < vb.length; i++) {
        vb[i] = Math.round(vb[i]);
    }
    return vb.join(" ");
}

function zoom(factor) {
    var vb = viewbox_to_a();
    var vw = vb[2] * factor;
    var vh = vb[3] * factor;
    vb[0] = vb[0] + (vb[2]-vw)/2;
    vb[1] = vb[1] + (vb[3]-vh)/2;
    vb[2] = vw;
    vb[3] = vh;
    document.getElementById("plotmap").setAttribute("viewBox", a_to_viewbox(vb));
}
