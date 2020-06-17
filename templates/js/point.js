{{#points}}
    points.push({});
    points.slice(-1)[0]["lat"] = {{lat}};
    points.slice(-1)[0]["lon"] = {{lon}};
    points.slice(-1)[0]["ele"] = {{ele_round}};
    points.slice(-1)[0]["dst"] = "{{dst_round}}";
    points.slice(-1)[0]["date"] = (new Date("{{ time }}"));
    points.slice(-1)[0]["tim"] = points.slice(-1)[0]["date"].toLocaleTimeString();
    points.slice(-1)[0]["tstamp"] = points.slice(-1)[0]["date"].getTime();
    points.slice(-1)[0]["spd_kph"] = "{{spd_kph}}";
    points.slice(-1)[0]["speed_color"]  = "{{speed_color}}";
    points.slice(-1)[0]["ele_color"]  = "{{ele_color}}";
{{/points}}
