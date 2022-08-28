window.onload = function(event) {

    const url_params = new URLSearchParams(window.location.search);

    const opts = {
        enableHighAccuracy: true,
        timeout: 5000,
        maximumAge: 0
    };

    const homeWidth = 400;
    const maps_url = 'https://james.whaite.com/pow/maps'
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

    var panning = false;
    var lastPanX = 0;
    var lastPanY = 0;
    var lastPinchDist = 0;

    var map_drag = false;


    // https://www.magnetic-declination.com/Australia/Sydney/124736.html
    //var magnetic_declination = 12.75;
    // hmm - usually not needed - why does it change?
    var magnetic_declination = 0.0;

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

                                const dirr = (direction + magnetic_declination) % 360 * Math.PI / 180.0;
                                const xvec = Math.sin(dirr);
                                const yvec = Math.cos(dirr) * -1;
                                const rad = 33;
                                const scaledRad = rad * vb.width / homeWidth;
                                const lineLength = 1000 * vb.width / homeWidth;

                                document.getElementById('point-target-direction').setAttribute('cx', parseInt(xvec * rad));
                                document.getElementById('point-target-direction').setAttribute('cy', parseInt(yvec * rad));

                                const bearingLine = document.getElementById('point-target-bearing');
                                bearingLine.setAttribute('x1', parseInt(xvec * scaledRad + currentPos.x));
                                bearingLine.setAttribute('y1', parseInt(yvec * scaledRad + currentPos.y));
                                bearingLine.setAttribute('x2', parseInt(xvec * lineLength + currentPos.x));
                                bearingLine.setAttribute('y2', parseInt(yvec * lineLength + currentPos.y));
                            });
                        }

                        // window.addEventListener('devicemotion', (event) => {
                        // not using motion ... yet
                        // })
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

        const tilex = originTile.tilex + Math.round(centerX / 2000);
        const tiley = originTile.tiley + Math.round(centerY / 2000);

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

                maptile.setAttribute('x', (originTile.tilex - tmd.tilex) * -2000);
                maptile.setAttribute('y', (originTile.tiley - tmd.tiley) * -2000);
                maptile.setAttribute('xlink:href', maps_url + '/' + tmd.filename);

                tmdix++;
            }

            return true;
        } else {
            return false;
        }
    };

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
        setPos(pos.coords.latitude, pos.coords.longitude, pos);
    };

    function setPos(lat, lon, position = false) {
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

        document.getElementById('target').setAttribute('x', currentPos.x);
        document.getElementById('target').setAttribute('y', currentPos.y);

        centreOnPos();

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

    function pan(deltaX, deltaY) {
        vb.left = vb.left - (vb.width / homeWidth) * (deltaX / 2);
        vb.top = vb.top - (vb.width / homeWidth) * (deltaY / 2);
        vb.set();
        loadTiles();
    }


    async function track() {
        while(true) {
            if (!tracking) { break; }
            navigator.geolocation.getCurrentPosition(gotPos, errPos, opts);
            await new Promise(resolve => setTimeout(resolve, trackingSampleRate));
        }
    }

    function addPoint(position, force) {
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

        if (position) {
            mark.classList.add('position-mark');
            mark.setAttribute('data-lat', position.coords.latitude);
            mark.setAttribute('data-lon', position.coords.longitude);
            mark.setAttribute('data-ele', position.coords.altitude);
            mark.setAttribute('data-spd', position.coords.speed);
            mark.setAttribute('data-acc', position.coords.accuracy);
            mark.setAttribute('data-ela', position.coords.altitudeAccuracy);
            mark.setAttribute('data-spd', position.coords.speed);
            mark.setAttribute('data-hdg', position.coords.heading);
            mark.setAttribute('data-tim', position.timestamp);
        }

        pm.appendChild(mark);

        if (lastPos.x) {
            var line = document.createElementNS("http://www.w3.org/2000/svg", "line");
            line.style.opacity = "0.5";
            line.setAttribute("x1", lastPos.x);
            line.setAttribute("x2", currentPos.x);
            line.setAttribute("y1", lastPos.y);
            line.setAttribute("y2", currentPos.y);
            line.setAttribute("stroke", "blue");
            line.setAttribute("stroke-width", "3");

            pm.appendChild(line);
        }
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
        }
    }
    vb.load();

    zoom();

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
            download();
        } else {
            tracking = true;
            getDirection();
            this.style.color = 'lime';
            track();
        }
    };

    document.getElementById("pan-button").onclick = function(e) {
        if (panning) {
            panning = false;
            this.style.color = 'white';
            lastPanX = 0;
            lastPanY = 0;
            centreOnPos();
        } else {
            panning = true;
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
            vw = homeWidth;;
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

        document.getElementById("target-group").setAttribute('transform', `scale(${targetZoom})`);
        const bearing = document.getElementById("point-target-bearing");

        bearing.setAttribute('stroke-width', Math.max(0.1, (2.0 * targetZoom)));
    }

    function download() {
        var data = "tim,lat,lon,ele\n";

        for (const mark of document.getElementsByClassName('position-mark')) {
            data += [mark.dataset.tim, mark.dataset.lat, mark.dataset.lon, mark.dataset.ele].join(',') + "\n";
        }

        var blob = new Blob([data], {type: 'text/csv;charset=utf-8;'});
        var link = document.createElement("a");

        const d = new Date();
        const filename = 'pow_' + d.toISOString().split('T')[0] + '.csv';

        var url = URL.createObjectURL(blob);
        link.setAttribute("href", url);
        link.setAttribute("download", filename);
        link.style.visibility = 'hidden';
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
    }
};
