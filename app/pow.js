
const url_params = new URLSearchParams(window.location.search);

const opts = {
    enableHighAccuracy: true,
    timeout: 5000,
    maximumAge: 0
};

var tiles = [];
var originTile;
var currentTile;
var direction;
var currentPos = {'x': 0, 'y': 0};
var lastPos = {'x': 0, 'y': 0};

var jitterThreshholdPx = 2;

var pm;
var wrap;
var vb;
var tracking = false;
var trackingSampleRate = 5000; // ms

var lastZoomBarY = 0;

function getDirection() {
    if (typeof(DeviceMotionEvent) !== 'undefined' && typeof(DeviceMotionEvent.requestPermission) === 'function') {
        DeviceMotionEvent.requestPermission()
            .then(response => {
            if (response == 'granted') {
                if (window.DeviceOrientationEvent) {
                    window.addEventListener('deviceorientation', (event) => {
                        if (event.webkitCompassHeading) {
                            direction = event.webkitCompassHeading;  
                        } else {
                            direction = event.alpha;
                        }

                        const dirr = direction * Math.PI / 180.0;
                        const xvec = Math.sin(dirr);
                        const yvec = Math.cos(dirr) * -1;
                        const rad = 33;

                        document.getElementById('point-target-direction').setAttribute('cx', parseInt(xvec * rad) + 50);
                        document.getElementById('point-target-direction').setAttribute('cy', parseInt(yvec * rad) + 50);

                        const bearingLine = document.getElementById('point-target-bearing');
                        bearingLine.setAttribute('x1', parseInt(xvec * rad + currentPos.x));
                        bearingLine.setAttribute('y1', parseInt(yvec * rad + currentPos.y));
                        bearingLine.setAttribute('x2', parseInt(xvec * 1000 + currentPos.x));
                        bearingLine.setAttribute('y2', parseInt(yvec * 1000 + currentPos.y));
                    });
                }

                // window.addEventListener('devicemotion', (event) => {
                    // not using motion ... yet
                // })
            }
            })
            .catch(console.error)
    } else {
        // alert('DeviceMotionEvent is not defined');
    }
}


function findTiles(lat, lon) {
    const lastTile = currentTile;

    // find the tile we're in
    for (const tilemd of metadata) {
        var min_lon = Math.min(tilemd.topleft.long, tilemd.topright.long, tilemd.bottomleft.long, tilemd.bottomright.long);
        var max_lon = Math.max(tilemd.topleft.long, tilemd.topright.long, tilemd.bottomleft.long, tilemd.bottomright.long);
        var min_lat = Math.min(tilemd.topleft.lat, tilemd.topright.lat, tilemd.bottomleft.lat, tilemd.bottomright.lat);
        var max_lat = Math.max(tilemd.topleft.lat, tilemd.topright.lat, tilemd.bottomleft.lat, tilemd.bottomright.lat);

        // a bit of a fudge - might be off by one because of slope, but doesn't matter
        if (lat < max_lat && lat > min_lat && lon < max_lon && lon > min_lon) {
            currentTile = tilemd;
            originTile ||= currentTile;
            break;
        }
    }

    if (lastTile !== currentTile) {
        tiles = [];
        // remember the tile we're in and the eight surrounding it
        for (const tilemd of metadata) {
            if (Math.abs(tilemd.tilex - currentTile.tilex) <= 1 && Math.abs(tilemd.tiley - currentTile.tiley) <= 1) {
                tiles.push(tilemd);
            }
        }
        return true;
    } else {
        return false;
    }
};

function coords(lat, lon) {
    tilemd = originTile;

    var x_t = ((lon - tilemd.topleft.long) / (tilemd.topright.long - tilemd.topleft.long)) * 2000;
    var x_b = ((lon - tilemd.bottomleft.long) / (tilemd.bottomright.long - tilemd.bottomleft.long)) * 2000;
    var y_l = ((lat - tilemd.topleft.lat) / (tilemd.bottomleft.lat - tilemd.topleft.lat)) * 2000;
    var y_r = ((lat - tilemd.topright.lat) / (tilemd.bottomright.lat - tilemd.topright.lat)) * 2000;

    var x_slope = (x_b - x_t) / 2000;
    var y_slope = (y_r - y_l) / 2000;

    var x = Math.round((y_l * x_slope + x_t) / (1 - x_slope * y_slope));
    var y = Math.round((x_t * y_slope + y_l) / (1 - y_slope * x_slope));

    return [x, y];
};

function gotPos(pos) {
    setPos(pos.coords.latitude, pos.coords.longitude);
};

function setPos(lat, lon) {
    const tilesChanged = findTiles(lat, lon);
    var xy = coords(lat, lon);

    const first = lastPos.x == 0;
    lastPos.x = currentPos.x;
    lastPos.y = currentPos.y;
    currentPos.x = xy[0];
    currentPos.y = xy[1];


    if (tilesChanged) {
        var tmdix = 0;

        for (const maptile of document.getElementsByClassName('map-tile')) {
            tmd = tiles[tmdix];

            maptile.setAttribute('x', (originTile.tilex - tmd.tilex) * -2000);
            maptile.setAttribute('y', (originTile.tiley - tmd.tiley) * -2000);
            maptile.setAttribute('xlink:href', 'https://home.whaite.com/fet/imgraw/NSW_25k_Coast_South/' + tmd.filename);

            tmdix++;
        }
    }

    document.getElementById('target').setAttribute('x', currentPos.x - 50);
    document.getElementById('target').setAttribute('y', currentPos.y - 50);

    vb.left = currentPos.x - 200;
    vb.top = currentPos.y - 200;
    vb.width = 400;
    vb.height = 400;
    vb.set();

    addPoint(first);
};

function errPos(err) { console.log(err)};


async function track() {
    while(true) {
        if (!tracking) { break; }
        navigator.geolocation.getCurrentPosition(gotPos, errPos, opts);
        await new Promise(resolve => setTimeout(resolve, trackingSampleRate));
    }
}

function addPoint(force) {
    if (!tracking) { return; }

    if (!force && Math.abs(currentPos.x - lastPos.x) < jitterThreshholdPx && Math.abs(currentPos.y - lastPos.y) < jitterThreshholdPx) { return; }

    var mark = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    mark.style.opacity = "0.7";
    mark.setAttribute("cx", currentPos.x);
    mark.setAttribute("cy", currentPos.y);
    mark.setAttribute("r", 6);
    mark.setAttribute("stroke", "blue");
    mark.setAttribute("stroke-width", "0");
    mark.setAttribute("fill", "blue");

    pm.appendChild(mark);

    if (lastPos.x !== 0) {
        var line = document.createElementNS("http://www.w3.org/2000/svg", "line");
        line.style.opacity = "0.5";
        line.setAttribute("x1", lastPos.x);
        line.setAttribute("x2", currentPos.x);
        line.setAttribute("y1", lastPos.y);
        line.setAttribute("y2", currentPos.y);
        mark.setAttribute("stroke", "blue");
        mark.setAttribute("stroke-width", "3");

        pm.appendChild(line);
    }
};

window.onload = function(event) {
    wrap = document.getElementById("plotmap-wrapper");
    pm = document.getElementById("plotmap");

    const zb = document.getElementById("zoom-bar");
    zb.style.height = parseInt(wrap.clientHeight/2 - 20);

    zb.addEventListener('touchstart', function(e) {
        this.style.opacity = 0.6;
        lastZoomBarY = targetTouches.item(0).pageY;
    });

    zb.addEventListener('touchend', function(e) {
        this.style.opacity = 0.3;
        lastZoomBarY = 0;
    });

    zb.addEventListener('touchcancel', function(e) {
        this.style.opacity = 0.3;
        lastZoomBarY = 0;
    });

    zb.addEventListener('touchmove', function(e) {
        const touch = e.changedTouches.item(0);

        deltaY = touch.pageY - lastZoomBarY;

        if (deltaY > 0) {
            zoom(0.97);
        } else {
            zoom(1/0.97);
        }

        lastZoomBarY = touch.pageY;
    });

    vb = {
        left: 0,
        top: 0,
        width: 0,
        height: 0,
        plotmap: pm,
        from_array: function(a) {
            this.left = parseInt(a[0]);
            this.top = parseInt(a[1]);
            this.width = parseInt(a[2]);
            this.height = parseInt(a[3]);
        },
        load: function() {
            this.from_array(plotmap.getAttribute("viewBox").split(" "));
        },
        to_s: function() {
            return [this.left, this.top, this.width, this.height].join(' ');
        },
        to_q: function() {
            return [this.left.toFixed(), this.top.toFixed(), this.width.toFixed(), this.height.toFixed()].join('-');
        },
        from_q: function(q) {
            this.from_array(q.split('-'));
            this.set();
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

    vb.left = currentPos.x - 400;
    vb.top = currentPos.y - 400;
    vb.width = 800;
    vb.height = 800;
    vb.set();
    vb.mark_origin();

    if (url_params.has('lat') && url_params.has('lon')) {
        setPos(Number(url_params.get('lat')), Number(url_params.get('lon')));
    } else {
        navigator.geolocation.getCurrentPosition(gotPos, errPos, opts);
    }

    getDirection();

    document.getElementById("track-button").onclick = function(e) {
        if (tracking) {
            tracking = false;
            lastPos.x = 0;
            lastPos.y = 0;
            this.style.color = 'white';
        } else {
            tracking = true;
            getDirection();
            this.style.color = 'lime';
            track();
        }
    };

};

function zoom(factor) {
    var vw = vb.width * factor;
    var vh = vb.height * factor;
    vb.left = vb.left + (vb.width-vw)/2;
    vb.top = vb.top + (vb.height-vh)/2;
    vb.width = vw;
    vb.height = vh;

    vb.set();
}
