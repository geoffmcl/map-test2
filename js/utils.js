/* Just a bunch of utility services - 20140908 */

var pi = Math.PI;
var pi2 = pi + pi;
var d2r = pi / 180;
var r2d = 180 / pi;  // degrees / radians

function getBearing( Lat1, Lon1, Lat2, Lon2 ) {
    // convert to radians
    var startLat = Lat1 * d2r;
    var startLon = Lon1 * d2r;
    var endLat   = Lat2 * d2r;
    var endLon   = Lon2 * d2r;
    var dLon = endLon - startLon;
    var pi4 = pi / 4;
    var dPhi = Math.log( Math.tan( (endLat / 2.0) + pi4 ) / 
            Math.tan( (startLat / 2.0) + pi4 ) );
    if ( Math.abs( dLon ) > pi ) {
        if ( dLon > 0.0) {
            dLon = -( pi2 - dLon );
        } else {
            dLon =  ( pi2 + dLon );
        }
    }
    var d = Math.atan2( dLon, dPhi ) * r2d;
    return parseInt((d + 360.0) % 360.0);
}

// The good old GUP function by Geoff McLane
function gup( name ) {
    name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
    var regexS = "[\\?&]"+name+"=([^&#]*)";
    var regex = new RegExp( regexS );
    var results = regex.exec( window.location.href );
    if( results == null )
        return "";
    else
        return results[1];
}

// HttpRequest handler
function getHttpRequest() {
    var httpReq = null;
    if (window.XMLHttpRequest) {
        httpReq = new XMLHttpRequest();
    } 
    else if (typeof ActiveXObject != "undefined") { 
        httpReq = new ActiveXObject("Microsoft.XMLHTTP")
    }
    return httpReq;
}

function getUrlwithCB(url,callback) {
    var req = getHttpRequest();
    if (req !== null) {
        req.onreadystatechange = callback;
        req.open("GET", url);
        req.send(null);
    } else {
        alert("Your browser does not support an XMLHttpRequest object. No updates will happen!");
    }
}

///////////////////////////////////////////////////////////////////////////
function getElapsed(bgn) {
    var d = Date.now();
    var ms = d.valueOf() - bgn.valueOf();
    var elap = ms2hhmmss(ms);
    return elap;
}
    
function ms2hhmmss( ms ) {
    if (ms < 1000) {
        return ''+ms+' ms';
    }
    var secs = Math.floor( ms / 1000 );
    ms -= (secs * 1000);
    if (secs < 60) {
        var stg = ''+((ms / 1000).toFixed(2));
        stg = stg.substr(1);    // drop the zero
        return ''+secs+stg+' secs';
    }
    var mins = Math.floor(secs / 60);
    secs -= (mins * 60);
    if (ms > 500)
        secs++;
    if (secs >= 60) {
        secs -= 60;
        mins++;
    }
    if (mins < 60) {
        if (secs < 10)
            secs = '0'+secs;
        return ''+mins+':'+secs+' mm:ss';
    }
    var hours = Math.floor(mins / 60);
    mins -= (hours * 60);
    if (mins < 10)
        mins = '0'+mins;
    if (secs < 10)
        secs = '0'+secs;
    return ''+hours+':'+mins+':'+secs+' hh:mm:ss';
}


function set_orientation( obj, degs ) {
    var val = "rotate(" + degs + "deg)"
    obj.webkitTransform = val;
    obj.msTransform = val;
    obj.MozTransform = val;
    obj.OTransform = val;
}

/* eof */
