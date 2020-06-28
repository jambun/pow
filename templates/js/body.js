var zoom_factor = 0.8;
var move_step = 50;
var keep_animating = false;;
var pm = document.getElementById("plotmap");
var map_drag = false;

document.onkeydown = function(e) {
    if (e.altKey || e.ctrlKey || e.metaKey || e.shiftKey) {
        return;
    }

    if (!(document.getElementById("help-detail").style.display == 'none')) { document.getElementById("help-button").click(); }

    {{#button_groups}}
      {{#buttons}}
        else if (e.key == '{{key}}') { document.getElementById("{{id}}-button").click(); }
      {{/buttons}}
    {{/button_groups}}

    e.preventDefault();
};

pm.onmousedown = function(e) {
    map_drag = true;    
    e.preventDefault();
};

pm.onmousemove = function(e) {
    e.preventDefault();

    if (map_drag) {
        move_map((e.movementX * -2), (e.movementY * -2));
    }

    var panel = document.getElementById("coords-panel");
    if (panel.style.display != 'none') {
        if (panel.dataset.follow == 'true' && panel.dataset.lock == 'false') {
            panel.style.top = e.y + 10;
            panel.style.left = e.x + 10;
        }
        if (panel.dataset.lock == 'false') {
            var lon = e.x / window.innerWidth * vb.width + vb.left;
            var lat = e.y / window.innerHeight * vb.height + vb.top;
            document.getElementById("coords-lat").innerHTML = "Lat: " + Math.round(lat);
            document.getElementById("coords-lon").innerHTML = "Lon: " + Math.round(lon);
        }
    }
};

pm.onmouseup = function(e) {
    map_drag = false;
    e.preventDefault();
};

pm.onmouseleave = function(e) {
    map_drag = false;
    e.preventDefault();
};

function move_map(x, y) {
    vb.left += x;
    vb.top += y;
    vb.set();
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

    vb.left = pl.getAttribute("x2") - vb.width/2;
    vb.top = pl.getAttribute("y2") - vb.height/2;

    vb.set();
}

pm.ondblclick = function(e){
    e.preventDefault();
    map_drag = false;
    var wrap = document.getElementById("plotmap-wrapper");
    var vx = (e.pageX - wrap.offsetLeft) / wrap.offsetWidth * vb.width;
    var vy = (e.pageY - wrap.offsetTop) / wrap.offsetHeight * vb.height;
    vb.left = vx + vb.left - vb.width/2;
    vb.top = vy + vb.top - vb.height/2;
    vb.set();
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

document.getElementById("reset-button").onclick = function(e) {
    vb.set_origin();
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

document.getElementById("measure-mark-button").onclick = function(e) {
    toggleMeasureMark(this);
};

function toggleMeasureMark(button) {
    if (mark_ix == point_ix) {
        mark_ix = 0;
    } else {
        mark_ix = point_ix;
    }
    switchButton(button, mark_ix != 0);

    updateMeasureMarks();

    updateGraph(point_ix);
}

function updateMeasureMarks() {
    var pl = document.getElementById("line-" + mark_ix)
    var pt = document.getElementById("mark-target-inner");
    pt.setAttribute("cx", pl.getAttribute("x2"));
    pt.setAttribute("cy", pl.getAttribute("y2"));

    pt = document.getElementById("mark-target-outer");
    pt.setAttribute("cx", pl.getAttribute("x2"));
    pt.setAttribute("cy", pl.getAttribute("y2"));

    pt = document.getElementById("mark-target-back");
    pt.setAttribute("cx", pl.getAttribute("x2"));
    pt.setAttribute("cy", pl.getAttribute("y2"));

    var trailMarks = document.getElementsByClassName("trail-mark");
    for (i = 0; i < trailMarks.length; i++) {
        var ix = parseInt(trailMarks[i].getAttribute('ix'))
        if (ix >= Math.min(point_ix, mark_ix) && ix <= Math.max(point_ix, mark_ix)) {
            trailMarks[i].style.opacity = '0.5';
        } else {
            trailMarks[i].style.opacity = '0.17';
        }
    }

    var mfrom = points[Math.min(point_ix, mark_ix)];
    var mto = points[Math.max(point_ix, mark_ix)];
    var mtim = mto.tstamp - mfrom.tstamp;
    var mhms = new Date(mtim).toISOString().substr(11, 8);
    var mdst = parseFloat(mto.total_dst) - parseFloat(mfrom.total_dst);
    var mspd = mtim == 0 ? 0 : mdst / (mtim / 1000);

    document.getElementById("measure-tim").innerHTML = "Time: " + mhms;
    document.getElementById("measure-dst").innerHTML = "Dist: " + (Math.round(mdst/10) / 100) + " km";
    document.getElementById("measure-ele").innerHTML = "Ele: " + (mto.ele - mfrom.ele) + "m";
    document.getElementById("measure-spd").innerHTML = (Math.round(mspd * 360) / 100) + " kph";
}

document.getElementById("measure-button").onclick = function(e) {
    toggleMeasure(this);
};

document.getElementById("measure-detail").onclick = function(e) {
    toggleMeasure(document.getElementById("measure-button"));
};

function toggleMeasure(button) {
    var measure = document.getElementById("measure-detail");
    measure.style.display = measure.style.display == 'none' ? 'inherit' : 'none';
    var graphMarks = document.getElementsByClassName("graph-mark");
    for (i = 0; i < graphMarks.length; i++) {
        graphMarks[i].style.display = measure.style.display;
    }

    switchButton(button, measure.style.display != 'none');
}

document.getElementById("coords-button").onclick = function(e) {
    toggleCoords(this);
};

function toggleCoords(button) {
    var panel = document.getElementById("coords-panel");
    if (panel.style.display == 'none') {
        panel.style.display = 'inherit';
        panel.dataset.follow = 'true';
    } else {
        if (panel.dataset.follow == 'true') {
            panel.style.removeProperty('top');
            panel.style.removeProperty('left');
            panel.dataset.follow = 'false';
        } else {
            if (panel.dataset.lock == 'false') {
                panel.dataset.lock = 'true';
                panel.style.borderColor = '#F00';
            } else {
                panel.dataset.lock = 'false';
                panel.style.borderColor = '#000';
                panel.style.display = 'none';
            }
        }
    }
}

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
    setGraphMark(point_ix, 0.0);
    setGraphMark(ix, 1.0);

    if (isNaN(mark_ix)) {
	      document.getElementById("graph-mark-to-point").setAttribute("visibility", 'hidden');
    } else {
	      var mark_to_point = document.getElementById("graph-mark-to-point");
	      mark_to_point.setAttribute("visibility", 'visible');
	      var left_x = document.getElementById("graph-bar-" + Math.min(mark_ix, ix)).getAttribute("x");
	      var right_x = document.getElementById("graph-bar-" + Math.max(mark_ix, ix)).getAttribute("x");
	      mark_to_point.setAttribute("x", left_x);
	      mark_to_point.setAttribute("width", right_x - left_x);

	      var mark = document.getElementById("graph-mark");
	      var x = document.getElementById("graph-bar-" + mark_ix).getAttribute("x");
        mark.setAttribute("x1", x);
        mark.setAttribute("x2", x);
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

function zoom(factor) {
    var vw = vb.width * factor;
    var vh = vb.height * factor;
    vb.left = vb.left + (vb.width-vw)/2;
    vb.top = vb.top + (vb.height-vh)/2;
    vb.width = vw;
    vb.height = vh;

    vb.set();
}
