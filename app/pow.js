
const url_params = new URLSearchParams(window.location.search);

const opts = {
    enableHighAccuracy: true,
    timeout: 5000,
    maximumAge: 0
};

var tiles = [];
var origin_tile;

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
    var tmdix = 0;

    for (const maptile of document.getElementsByClassName('map-tile')) {
        tmd = tiles[tmdix];

        maptile.setAttribute('x', (origin_tile.tilex - tmd.tilex) * -2000);
        maptile.setAttribute('y', (origin_tile.tiley - tmd.tiley) * -2000);
        maptile.setAttribute('xlink:href', 'https://home.whaite.com/fet/imgraw/NSW_25k_Coast_South/' + tmd.filename);

        tmdix++;
    }

    document.getElementById('target').setAttribute('x', xy[0] - 50);
    document.getElementById('target').setAttribute('y', xy[1] - 50);
};

function errPos(err) { console.log(err)};

var gimme = function() {
    if (url_params.has('lat') && url_params.has('lon')) {
        setPos(Number(url_params.get('lat')), Number(url_params.get('lon')));
    } else {
        navigator.geolocation.getCurrentPosition(gotPos, errPos, opts);
    }
};
