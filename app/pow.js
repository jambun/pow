
const url_params = new URLSearchParams(window.location.search);

const opts = {
    enableHighAccuracy: true,
    timeout: 5000,
    maximumAge: 0
};

var tiles = [];
var origin_tile;
var direction;
var currentPos = {'x': 0, 'y': 0};
var vb;

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
                        document.getElementById('message').innerHTML = direction;

                        const dirr = direction * Math.PI / 180.0;
                        const xvec = Math.sin(dirr);
                        const yvec = Math.cos(dirr) * -1;

                        document.getElementById('point-target-direction').setAttribute('cx', parseInt(xvec * 36) + 50);
                        document.getElementById('point-target-direction').setAttribute('cy', parseInt(yvec * 36) + 50);

                        const bearingLine = document.getElementById('point-target-bearing');
                        bearingLine.setAttribute('x1', parseInt(xvec * 36) + currentPos.x);
                        bearingLine.setAttribute('y1', parseInt(yvec * 36) + currentPos.y);
                        bearingLine.setAttribute('x2', parseInt(xvec * 1000) + currentPos.x);
                        bearingLine.setAttribute('y2', parseInt(yvec * 1000) + currentPos.y);
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


//function getDirection() {
//};


function findTile(lat, lon) {
//    var tile;

    // find the tile we're in
    for (const tilemd of metadata) {
        var min_lon = Math.min(tilemd.topleft.long, tilemd.topright.long, tilemd.bottomleft.long, tilemd.bottomright.long);
        var max_lon = Math.max(tilemd.topleft.long, tilemd.topright.long, tilemd.bottomleft.long, tilemd.bottomright.long);
        var min_lat = Math.min(tilemd.topleft.lat, tilemd.topright.lat, tilemd.bottomleft.lat, tilemd.bottomright.lat);
        var max_lat = Math.max(tilemd.topleft.lat, tilemd.topright.lat, tilemd.bottomleft.lat, tilemd.bottomright.lat);

        // a bit of a fudge - might be off by one because of slope, but doesn't matter
        if (lat < max_lat && lat > min_lat && lon < max_lon && lon > min_lon) {
            origin_tile = tilemd;
            break;
        }
    }

    // remember the tile we're in and the eight surrounding it
    for (const tilemd of metadata) {
        if (Math.abs(tilemd.tilex - origin_tile.tilex) <= 1 && Math.abs(tilemd.tiley - origin_tile.tiley) <= 1) {
            tiles.push(tilemd);
        }
    }

    return origin_tile.filename;
};

function coords(lat, lon) {
    tilemd = origin_tile;

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
    tileFile = findTile(lat, lon);
    var xy = coords(lat, lon);

    currentPos.x = xy[0];
    currentPos.y = xy[1];

    var tmdix = 0;

    for (const maptile of document.getElementsByClassName('map-tile')) {
        tmd = tiles[tmdix];

        maptile.setAttribute('x', (origin_tile.tilex - tmd.tilex) * -2000);
        maptile.setAttribute('y', (origin_tile.tiley - tmd.tiley) * -2000);
        maptile.setAttribute('xlink:href', 'https://home.whaite.com/fet/imgraw/NSW_25k_Coast_South/' + tmd.filename);

        tmdix++;
    }

    document.getElementById('target').setAttribute('x', currentPos.x - 50);
    document.getElementById('target').setAttribute('y', currentPos.y - 50);

    vb.left = currentPos.x - 200;
    vb.top = currentPos.y - 200;
    vb.width = 400;
    vb.height = 400;
    vb.set();

};

function errPos(err) { console.log(err)};

var gimme = function() {
    if (url_params.has('lat') && url_params.has('lon')) {
        setPos(Number(url_params.get('lat')), Number(url_params.get('lon')));
    } else {
        navigator.geolocation.getCurrentPosition(gotPos, errPos, opts);
    }

    document.getElementById('message').ontouchend = function(e) { getDirection();};
 
    getDirection();
};

async function track() {
    while(true) {
        await new Promise(resolve => setTimeout(resolve, 5000));
        navigator.geolocation.getCurrentPosition(gotPos, errPos, opts);
    }
}

window.onload = function(event) {
    vb = {
        left: 0,
        top: 0,
        width: 0,
        height: 0,
        plotmap: document.getElementById("plotmap"),
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

    document.getElementById('message').ontouchend = function(e) { getDirection();};
 
    getDirection();

    track();

};
