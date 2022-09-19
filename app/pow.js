
const VERSION = 'v1.2.3';

const registerServiceWorker = async () => {
  if ("serviceWorker" in navigator) {
    try {
      const registration = await navigator.serviceWorker.register("/pow/cache.js", {
        scope: "/pow/",
      });
      if (registration.installing) {
        console.log("Service worker installing");
      } else if (registration.waiting) {
        console.log("Service worker installed");
      } else if (registration.active) {
        console.log("Service worker active");
      }
    } catch (error) {
      console.error(`Registration failed with ${error}`);
    }
  }
};

registerServiceWorker();

window.onload = function(event) {

    function init() {
        document.getElementById('version-bug').textContent = VERSION;

        buildTileMatrix();

        findOriginTile();

        vb.load();
        vb.mark_origin();

        getDirection();
    };


    const url_params = new URLSearchParams(window.location.search);

    const posOpts = {
        enableHighAccuracy: true,
        timeout: 5000,
        maximumAge: 0
    };

    const earthRadiusM = 6371000.0;
    const tileSize = 2000; // x and y pixels for map tiles
    const tileMatrix = Array(); // 2 dim array of tile md for easier lookups

    const homeWidth = 400;
    const maps_url = 'https://hudmol.com/pow/maps'
    var tiles = [];
    var originTile;
    var currentTile;
    var direction;
    var directionInitialized = false;
    var currentPos = {'x': 0, 'y': 0, 'lat': 0, 'lon': 0, 'ele': 0};
    var lastPos = {'x': 0, 'y': 0, 'lat': 0, 'lon': 0, 'ele': 0};
    var trackDistance = 0.0;
    var trackClimb = 0.0;
    var distRadius;
    const distanceRadiusFraction = 1/3;

    var currentObjective;
    var trueBearing;

    var jitterThreshholdPx = 2;

    var pm;
    var wrap;
    var vb;
    var tracking = false;
    var trackingSampleRate = 5000; // ms

    var lastZoomBarY = 0;

    var panning = false;
    var lastPanX = 0;
    var lastPanY = 0;
    var lastPinchDist = 0;

    var map_drag = false;

    var entryCallback;

    var magnetic_declination = 0.0;

    // https://www.magnetic-declination.com/Australia/Sydney/124736.html
    magnetic_declination = 12.75;


    function message(s) {
        document.getElementById('entry-bar').style.opacity = '0.9';
        document.getElementById('entry-bar').innerHTML = s;
    }


    function toRadians(degrees) { return degrees * Math.PI / 180.0 }

    // HELPME: math brainmelt
    function XYtoDegrees(dx, dy) { return (Math.atan2(dy, dx) / Math.PI * 180  - 450) % 360 * -1 }

    function handleOrientation(event) {
        if (event.webkitCompassHeading) {
            direction = event.webkitCompassHeading;
        } else {
            direction = event.alpha;
        }
//        message(direction.toFixed());
        const dirr = toRadians(direction + magnetic_declination);
        const xvec = Math.sin(dirr);
        const yvec = Math.cos(dirr) * -1;
        const rad = 33;
        const scaledRad = rad * vb.width / homeWidth;
        const lineLength = 1000 * vb.width / homeWidth;

        document.getElementById('point-target-direction').setAttribute('cx', Math.round(xvec * rad));
        document.getElementById('point-target-direction').setAttribute('cy', Math.round(yvec * rad));

        const bearingLine = document.getElementById('point-target-bearing');
        bearingLine.setAttribute('x1', Math.round(xvec * scaledRad + currentPos.x));
        bearingLine.setAttribute('y1', Math.round(yvec * scaledRad + currentPos.y));
        bearingLine.setAttribute('x2', Math.round(xvec * lineLength + currentPos.x));
        bearingLine.setAttribute('y2', Math.round(yvec * lineLength + currentPos.y));

        if (trueBearing) {
            const bdiff = Math.abs(direction - trueBearing);
            if (bdiff > 180) { bdiff = 180 - bdiff % 180; }

            if (bdiff < 5) {
                //message(Math.round(bdiff));
            }
        }

    }


    function getDirection() {
        if (typeof(DeviceOrientationEvent) !== 'undefined' && typeof(DeviceOrientationEvent.requestPermission) === 'function') {
            DeviceOrientationEvent.requestPermission()
               .then(response => {
                   if (response == 'granted') {
                       if (window.DeviceOrientationEvent && !directionInitialized) {
                           window.addEventListener('deviceorientation', handleOrientation, true);
                           directionInitialized = true;
                       }
                   } else {
                       alert('orientation permission denied');
                   }
               })
               .catch(console.error)
       } else {
           document.getElementById('point-target-direction').style.display = 'none';
           document.getElementById('point-target-bearing').style.display = 'none';
       }
    }


    function loadTiles(x, y) {
        x ||= vb.left;
        y ||= vb.top;

        const lastTile = currentTile;

        const centerX = x + vb.width / 2;
        const centerY = y + vb.height / 2;

        const tilex = originTile.tilex + Math.round(centerX / tileSize);
        const tiley = originTile.tiley + Math.round(centerY / tileSize);

        for (const tilemd of metadata) {
            if (tilex == tilemd.tilex && tiley == tilemd.tiley) {
                currentTile = tilemd;
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

            var tmdix = 0;

            for (const maptile of document.getElementsByClassName('map-tile')) {
                tmd = tiles[tmdix];

                maptile.setAttribute('x', (originTile.tilex - tmd.tilex) * tileSize * -1);
                maptile.setAttribute('y', (originTile.tiley - tmd.tiley) * tileSize * -1);
                maptile.setAttribute('xlink:href', maps_url + '/' + tmd.filename);

                tmdix++;
            }

            return true;
        } else {
            return false;
        }
    };

    function buildTileMatrix() {
        for (const tilemd of metadata) {
            tileMatrix[tilemd.tilex] ||= Array();
            tileMatrix[tilemd.tilex][tilemd.tiley] = tilemd;
        }
    };

    function findTileXY(x, y) {
        if (!originTile) {
            console.error('call to findTileXY before originTile is set!');
            return;
        }

        const tilex = originTile.tilex + parseInt(x / tileSize);
        const tiley = originTile.tiley + parseInt(y / tileSize);

        return tileMatrix[tilex][tiley];
    }


    function findTile(lat, lon) {
        for (const tilemd of metadata) {
            var min_lon = Math.min(tilemd.topleft.long, tilemd.topright.long, tilemd.bottomleft.long, tilemd.bottomright.long);
            var max_lon = Math.max(tilemd.topleft.long, tilemd.topright.long, tilemd.bottomleft.long, tilemd.bottomright.long);
            var min_lat = Math.min(tilemd.topleft.lat, tilemd.topright.lat, tilemd.bottomleft.lat, tilemd.bottomright.lat);
            var max_lat = Math.max(tilemd.topleft.lat, tilemd.topright.lat, tilemd.bottomleft.lat, tilemd.bottomright.lat);

            // a bit of a fudge - might be off by one because of slope, but doesn't matter
            if (lat < max_lat && lat > min_lat && lon < max_lon && lon > min_lon) {
                return tilemd;
            }
        }
    };


    // lat lon to x y
    function coords(lat, lon) {
        tilemd = originTile;

        var x_t = ((lon - tilemd.topleft.long) / (tilemd.topright.long - tilemd.topleft.long)) * tileSize;
        var x_b = ((lon - tilemd.bottomleft.long) / (tilemd.bottomright.long - tilemd.bottomleft.long)) * tileSize;
        var y_l = ((lat - tilemd.topleft.lat) / (tilemd.bottomleft.lat - tilemd.topleft.lat)) * tileSize;
        var y_r = ((lat - tilemd.topright.lat) / (tilemd.bottomright.lat - tilemd.topright.lat)) * tileSize;

        var x_slope = (x_b - x_t) / tileSize;
        var y_slope = (y_r - y_l) / tileSize;

        var x = Math.round((y_l * x_slope + x_t) / (1 - x_slope * y_slope));
        var y = Math.round((x_t * y_slope + y_l) / (1 - y_slope * x_slope));

        return [x, y];
    };


    function window_to_svg(x, y) {
        return [x / window.innerWidth * vb.width + vb.left, y / window.innerHeight * vb.height + vb.top];
    }

    // x y to lat lon
    function toLatLon(x, y) {
//        const [map_x, map_y] = window_to_svg(x, y);

        const tile = findTileXY(x, y);

        var lon_t = x % tileSize / tileSize * (tile.topright.long - tile.topleft.long) + tile.topleft.long;
        var lon_b = x % tileSize / tileSize * (tile.bottomright.long - tile.bottomleft.long) + tile.bottomleft.long;
        var lat_l = y % tileSize / tileSize * (tile.bottomleft.lat - tile.topleft.lat) + tile.topleft.lat;
        var lat_r = y % tileSize / tileSize * (tile.bottomright.lat - tile.topright.lat) + tile.topright.lat;

        var lon = lon_t + ((lon_b - lon_t) / (tile.bottomleft.lat - tile.topleft.lat) * (lat_l - tile.topleft.lat));
        var lat = lat_l + ((lat_r - lat_l) / (tile.topright.long - tile.topleft.long) * (lon_t - tile.topleft.long));

        return [lat, lon];
    }


    function gotPos(pos) {
        setPos(pos.coords.latitude, pos.coords.longitude, pos);
    };

    function setPos(lat, lon, position = false) {
        var xy = coords(lat, lon);

        const first = lastPos.x == 0;

        if (!first) {
            lastPos.x = currentPos.x;
            lastPos.y = currentPos.y;
            lastPos.lat = currentPos.lat;
            lastPos.lon = currentPos.lon;
        }

        currentPos.x = xy[0];
        currentPos.y = xy[1];
        currentPos.lat = lat;
        currentPos.lon = lon;

        if (position) {
            if (!first) {
                lastPos.ele = currentPos.ele;
            }
            currentPos.ele = position.coords.altitude;
        }

        loadTiles(currentPos.x, currentPos.y);

        document.getElementById('target').setAttribute('x', currentPos.x);
        document.getElementById('target').setAttribute('y', currentPos.y);

        if (currentPos.ele) {
            document.getElementById('point-target-elev').textContent = `${Math.round(currentPos.ele)}m`;

            // bbox is zeroes when display is none, so make it visible first
            document.getElementById('target-ele-group').style.display = 'inherit';

            const ebox = document.getElementById('point-target-elev-box');
            const bbox = document.getElementById('point-target-elev').getBBox();

            ebox.setAttribute('x', bbox.x - 2);
            ebox.setAttribute('y', bbox.y);
            ebox.setAttribute('width', bbox.width + 4);
            ebox.setAttribute('height', bbox.height);
        } else {
            document.getElementById('target-ele-group').style.display = 'none';
        }

        if (!panning) { centreOnPos(); }

        updateCurrentObjective();

        addPoint(position, first);
    };

    function errPos(err) { console.log(err)};

    function centreOnPos(pos = false) {
        pos ||= currentPos;

        vb.left = pos.x - parseInt(vb.width / 2);
        vb.top = pos.y - parseInt(vb.height / 2);
        vb.set();
        loadTiles();
    };


    function centrePanTarget() {
        const pt = document.getElementById('pan-target');
        pt.setAttribute('x', vb.position().x);
        pt.setAttribute('y', vb.position().y);
    }


    function pan(deltaX, deltaY) {
        vb.left = vb.left - (vb.width / homeWidth) * (deltaX / 2);
        vb.top = vb.top - (vb.width / homeWidth) * (deltaY / 2);
        vb.set();
        centrePanTarget();
        loadTiles();
    }


    async function track() {
        while(true) {
            if (!tracking) { break; }
            navigator.geolocation.getCurrentPosition(gotPos, errPos, posOpts);
            await new Promise(resolve => setTimeout(resolve, trackingSampleRate));
        }
    }

    function addObjectiveMark(label) {
        const omTemplate = document.getElementsByClassName('objective-mark')[0];
        const om = omTemplate.cloneNode(true);

        om.setAttribute('x', vb.position().x);
        om.setAttribute('y', vb.position().y);
        om.getElementsByClassName('objective-text')[0].textContent = label;
        om.style.display = 'inherit';

        pm.insertBefore(om, omTemplate.nextSibling);

        const dx = om.getAttribute('x') - currentPos.x;
        const dy = om.getAttribute('y') - currentPos.y;

        const tbl = document.getElementById('true-bearing-line');

        tbl.setAttribute('x2', dx);
        tbl.setAttribute('y2', dy);

        const tb = document.getElementById('true-bearing')
        tb.setAttribute('x', currentPos.x);
        tb.setAttribute('y', currentPos.y);
        tb.style.display = 'inherit';

        const [lat, lon] = toLatLon(om.getAttribute('x'), om.getAttribute('y'));

        om.setAttribute('data-lat', lat);
        om.setAttribute('data-lon', lon);

        currentObjective = om;

        updateCurrentObjective();
    }

    function updateCurrentObjective() {
        if (currentObjective) {
            const dst = dstToHuman(calculateDistance(currentPos.lat, currentPos.lon, currentObjective.dataset.lat, currentObjective.dataset.lon));
            const dx = currentObjective.getAttribute('x') - currentPos.x;
            const dy = currentObjective.getAttribute('y') - currentPos.y;

            const tb = document.getElementById('true-bearing')
            tb.setAttribute('x', currentPos.x);
            tb.setAttribute('y', currentPos.y);

//        const dx = om.getAttribute('x') - currentPos.x;
//        const dy = om.getAttribute('y') - currentPos.y;

        const tbl = document.getElementById('true-bearing-line');

        tbl.setAttribute('x2', dx);
        tbl.setAttribute('y2', dy);



            trueBearing = Math.round(XYtoDegrees(dx, dy * -1));

            message(`${currentObjective.textContent} <br/> ${dst} &mdash;  ${trueBearing}&deg;`);
        }
    }

    function dstToHuman(metres) {
        var dst;
        if (metres >= 1000) {
            dst = (metres / 1000).toFixed(2) + 'km';
        } else {
            dst = Math.round(metres) + 'm';
        }
        return dst;
    }

    function addPoint(position, force) {
        if (!tracking) { return; }

        if (!force && Math.abs(currentPos.x - lastPos.x) < jitterThreshholdPx && Math.abs(currentPos.y - lastPos.y) < jitterThreshholdPx) { return; }

        const line = document.createElementNS("http://www.w3.org/2000/svg", "line");
        line.classList.add('no-stroke-zoom');
        line.setAttribute("data-stroke", "6");
        line.style.opacity = "0.3";
        line.setAttribute("x1", lastPos.x || currentPos.x);
        line.setAttribute("y1", lastPos.y || currentPos.y);
        line.setAttribute("x2", currentPos.x);
        line.setAttribute("y2", currentPos.y);
        line.setAttribute("stroke", "blue");
        line.style.strokeWidth = "6";

        if (position) {
            line.classList.add('position-mark');
            line.setAttribute('data-lat', position.coords.latitude);
            line.setAttribute('data-lon', position.coords.longitude);
            line.setAttribute('data-ele', position.coords.altitude);
            line.setAttribute('data-spd', position.coords.speed);
            line.setAttribute('data-acc', position.coords.accuracy);
            line.setAttribute('data-eac', position.coords.altitudeAccuracy);
            line.setAttribute('data-spd', position.coords.speed);
            line.setAttribute('data-hdg', position.coords.heading);
            line.setAttribute('data-tim', position.timestamp);
        }

        if (lastPos.x) {
            const dst = calculateDistance(lastPos.lat, lastPos.lon, currentPos.lat, currentPos.lon);
            mark.setAttribute('data-dst', dst);
            trackDistance += dst;
            if (currentPos.ele && lastPos.ele && currentPos.ele > lastPos.ele) {
                trackClimb += currentPos.ele - lastPos.ele;
            }
        }

        pm.insertBefore(line, document.getElementById("target"));
    };

    wrap = document.getElementById("plotmap-wrapper");
    pm = document.getElementById("plotmap");

    const zb = document.getElementById("zoom-bar");
    zb.style.height = parseInt(wrap.clientHeight/2 - 20);

    zb.addEventListener('touchstart', function(e) {
        e.preventDefault();
        this.style.opacity = 0.6;
        lastZoomBarY = targetTouches.item(0).pageY;
    });

    zb.addEventListener('touchend', function(e) {
        e.preventDefault();
        this.style.opacity = 0.3;
        lastZoomBarY = 0;
    });

    zb.addEventListener('touchcancel', function(e) {
        e.preventDefault();
        this.style.opacity = 0.3;
        lastZoomBarY = 0;
    });

    zb.addEventListener('touchmove', function(e) {
        e.preventDefault();

        const touch = e.changedTouches.item(0);

        deltaY = touch.pageY - lastZoomBarY;

        if (deltaY > 0) {
            zoom(0.97);
        } else {
            zoom(1/0.97);
        }

        lastZoomBarY = touch.pageY;
    });

    const vbug = document.getElementById('version-bug');

    vbug.addEventListener('touchstart', function(e) {
        document.getElementById('controls-pane').style.display = 'none';
    });

    vbug.addEventListener('touchend', function(e) {
        document.getElementById('controls-pane').style.display = 'inherit';
    });

    vbug.addEventListener('touchcancel', function(e) {
        document.getElementById('controls-pane').style.display = 'inherit';
    });


    const eb = document.getElementById("entry-bar");

    eb.onclick = function(e) {
        // calling getDirection here just as a way of getting permission
        // apparently it has to be in a click or touchend handler
        getDirection();

        openEntryForm('Add a marker', addObjectiveMark);
    };

    // FIXME: not currently used since addObjectiveMark
    function addMarker(label) {
        if (tracking && !panning) {
            const pms = document.getElementsByClassName('position-mark');
            const pm = pms[pms.length - 1];
            pm.setAttribute('data-tag', label);
            alert('Added mark with label ' + label);
        }
    };


    document.getElementById("entry-input").onkeydown = function(e) {
        if (e.key == 'Enter') {
            closeEntry();
            if (entryCallback) { entryCallback(document.getElementById("entry-input").value); }
            entryCallback = null;
        }
    };

    document.getElementById("entry-cancel").onclick = function(e) {
        e.preventDefault();
        e.stopPropagation();
        closeEntry();
    }

    function closeEntry() {
        document.getElementById("entry-pane").style.display = 'none';
        document.getElementById("entry-input").blur();
    };

    function openEntryForm(label, callback) {
        label ||= 'Add a point';
        document.getElementById("entry-label").innerHTML = label;
        document.getElementById("entry-input").value = '';

        document.getElementById("entry-pane").style.display = 'inherit';
        document.getElementById("entry-input").focus();

        entryCallback = callback;
    };

    pm.addEventListener('touchstart', function(e) {
        if (!panning) { return; };
    });

    pm.addEventListener('touchend', function(e) {
        lastPanX = 0;
        lastPanY = 0;
        lastPinchDist = 0;
    });

    pm.addEventListener('touchcancel', function(e) {
        lastPanX = 0;
        lastPanY = 0;
        lastPinchDist = 0;
    });

    pm.addEventListener('touchmove', function(e) {
        if (!panning) { return; };

        e.preventDefault();

        if (e.targetTouches.length > 1) {
            const t1 = e.targetTouches.item(0);
            const t2 = e.targetTouches.item(1);

            dist = Math.abs(t1.clientX - t2.clientX) + Math.abs(t1.clientY - t2.clientY);

            if (lastPinchDist) {
                zoom(lastPinchDist / dist);
            }

            lastPinchDist = dist;
        } else {
            const touch = e.changedTouches.item(0);

            if (lastPanX > 0) {
                deltaX = touch.pageX - lastPanX;
                deltaY = touch.pageY - lastPanY;

                pan(deltaX, deltaY);
            }

            lastPanX = touch.pageX;
            lastPanY = touch.pageY;

            lastPinchDist = 0;
        }
    });

    pm.onmousedown = function(e) {
        map_drag = true;    
        e.preventDefault();
    };

    pm.onmouseup = function(e) {
        map_drag = false;
        e.preventDefault();
    };

    pm.onmouseleave = function(e) {
        map_drag = false;
        e.preventDefault();
    };

    pm.onmousemove = function(e) {
        e.preventDefault();

        if (map_drag && panning) {
            pan(e.movementX, e.movementY);
        }
    };

    pm.onwheel = function(e) {
        if (e.deltaY > 0) {
            zoom(1/0.98);
        } else if (e.deltaY < 0) {
            zoom(0.98);
        }
    };


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
        },
        position: function() {
            return {x: Math.round(this.left + this.width / 2), y: Math.round(this.top + this.height / 2)};
        }
    }

    document.getElementById("track-button").onclick = function(e) {
        if (tracking) {
            tracking = false;
            lastPos.x = 0;
            lastPos.y = 0;
            this.style.color = 'white';
            download();
        } else {
            tracking = true;
            this.style.color = 'lime';
            track();
        }
    };

    document.getElementById("pan-button").onclick = function(e) {
        if (panning) {
            panning = false;
            document.getElementById('pan-target').style.display = 'none';
            this.style.color = 'white';
            lastPanX = 0;
            lastPanY = 0;
            centreOnPos();
        } else {
            panning = true;
            centrePanTarget();
            document.getElementById('pan-target').style.display = 'inherit';
            this.style.color = 'lime';
        }
    };

    function wrapAspect() {
        return wrap.clientWidth / wrap.clientHeight;
    };

    function zoom(factor = false) {
        var vw;
        if (factor) {
            vw = vb.width * factor;
        } else {
            vw = homeWidth;
        }
        var vh = vw / wrapAspect();

        vb.left = vb.left + (vb.width-vw)/2;
        vb.top = vb.top + (vb.height-vh)/2;
        vb.width = vw;
        vb.height = vh;
        vb.set();
        zoomTarget();
    }

    function zoomTarget() {
        const targetZoom = vb.width / homeWidth;

        for (const elt of document.getElementsByClassName('no-zoom')) {
            elt.setAttribute('transform', `scale(${targetZoom})`);
        }

        for (const elt of document.getElementsByClassName('no-stroke-zoom')) {
            elt.style.strokeWidth = `${elt.dataset.stroke * targetZoom}px`;
        }

        if (!distRadius) {
            distRadius = Math.round(vb.width * distanceRadiusFraction);
            document.getElementById('point-target-distance').setAttribute('r', distRadius);

            document.getElementById('point-target-dst-box').setAttribute('x', distRadius);
            document.getElementById('point-target-dst').setAttribute('x', distRadius);
        }

        const [lat, lon] = toLatLon(currentPos.x + Math.round(vb.width * distanceRadiusFraction), currentPos.y);

        document.getElementById('point-target-dst').textContent = dstToHuman(calculateDistance(currentPos.lat, currentPos.lon, lat, lon));

        const dbox = document.getElementById('point-target-dst-box');
        const bbox = document.getElementById('point-target-dst').getBBox();

        dbox.setAttribute('x', bbox.x - 2);
        dbox.setAttribute('y', bbox.y);
        dbox.setAttribute('width', bbox.width + 4);
        dbox.setAttribute('height', bbox.height);
    }

    function download() {
        var data = "tim,lat,lon,ele,acc,eac,dst,tag\n";

        for (const mark of document.getElementsByClassName('position-mark')) {
            data += [mark.dataset.tim,
                     mark.dataset.lat,
                     mark.dataset.lon,
                     mark.dataset.ele,
                     mark.dataset.acc,
                     mark.dataset.eac,
                     mark.dataset.dst,
                     mark.dataset.tag].join(',') + "\n";
        }

        var blob = new Blob([data], {type: 'text/csv;charset=utf-8;'});
        var link = document.createElement("a");

        const d = new Date();
        const filename = 'pow_' + d.toISOString().split('T')[0] + '.pow';

        var url = URL.createObjectURL(blob);
        link.setAttribute("href", url);
        link.setAttribute("download", filename);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }


    function gotPosForOrigin(pos) {
        originTile = findTile(pos.coords.latitude, pos.coords.longitude);
        setPos(pos.coords.latitude, pos.coords.longitude, pos);
        zoom();
    };


    function findOriginTile() {
        if (originTile) { return originTile; }

        if (url_params.has('lat') && url_params.has('lon')) {
            originTile = findTile(Number(url_params.get('lat')), Number(url_params.get('lon')));
            setPos(Number(url_params.get('lat')), Number(url_params.get('lon')));
            zoom();
        } else {
            navigator.geolocation.getCurrentPosition(gotPosForOrigin, errPos, posOpts);
        }
    };

    function calculateDistance(aLat, aLon, bLat, bLon) {
        const from_lat = toRadians(aLat);
        const to_lat = toRadians(bLat);
        const lat_d = toRadians(bLat - aLat);
        const lon_d = toRadians(bLon - aLon);

        const a = Math.sin(lat_d/2) ** 2 + Math.cos(from_lat) * Math.cos(to_lat) * Math.sin(lon_d/2) ** 2;
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));

        return earthRadiusM * c;
    }


    init();
};
