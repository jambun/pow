
const url_params = new URLSearchParams(window.location.search);

const opts = {
    enableHighAccuracy: true,
    timeout: 5000,
    maximumAge: 0
};

var tiles = [];

function findTile(lat, lon) {
    var tile;

    for (const tilemd of metadata) {

        var min_lon = Math.min(tilemd.topleft.long, tilemd.topright.long, tilemd.bottomleft.long, tilemd.bottomright.long);
        var max_lon = Math.max(tilemd.topleft.long, tilemd.topright.long, tilemd.bottomleft.long, tilemd.bottomright.long);
        var min_lat = Math.min(tilemd.topleft.lat, tilemd.topright.lat, tilemd.bottomleft.lat, tilemd.bottomright.lat);
        var max_lat = Math.max(tilemd.topleft.lat, tilemd.topright.lat, tilemd.bottomleft.lat, tilemd.bottomright.lat);

        if (lat < max_lat && lat > min_lat && lon < max_lon && lon > min_lon) {
            tile = tilemd;
            tiles.push(tile);
            break;
        }

    }

    console.log(tile);

    return tile.filename;
};

function coords(lat, lon) {
    tilemd = tiles[0];

    var x_t = ((lon - tilemd.topleft.long) / (tilemd.topright.long - tilemd.topleft.long)) * 2000;
    var x_b = ((lon - tilemd.bottomleft.long) / (tilemd.bottomright.long - tilemd.bottomleft.long)) * 2000;
    var y_l = ((lat - tilemd.topleft.lat) / (tilemd.bottomleft.lat - tilemd.topleft.lat)) * 2000;
    var y_r = ((lat - tilemd.topright.lat) / (tilemd.bottomright.lat - tilemd.topright.lat)) * 2000;

    var x_slope = (x_b - x_t) / 2000;
    var y_slope = (y_r - y_l) / 2000;

    var x = Math.round((y_l * x_slope + x_t) / (1 - x_slope * y_slope));
    var y = Math.round((x_t * y_slope + y_l) / (1 - y_slope * x_slope));

    console.log(x, y);
    return [x, y];
};

function gotPos(pos) {
    console.log(pos);
    setPos(pos.coords.latitude, pos.coords.longitude);
};

function setPos(lat, lon) {
    tileFile = findTile(lat, lon);
    var xy = coords(lat, lon);

    document.getElementById('tile').setAttribute('xlink:href', 'https://home.whaite.com/fet/imgraw/NSW_25k_Coast_South/' + tileFile);

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
