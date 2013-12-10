
// zoom for tracker page
var def_tzoom = 8;
var use_tracker_html = true;
	
	$(function() {	
		$.aircraft = {};

// getCrossfeed called from threejs-demo.html every x seconds - because that is where Request Animation Frame is.	
		$.getCrossfeed = function() {
			$.getJSON('http://crossfeed.fgx.ch/flights.json', function(data) {
				$.flightsData = data;
				$.lookup = {};
				var flt;
				$('#tbody').empty();
				$.each(data.flights, function(dataItem){
					flt = data.flights[dataItem];
					$.lookup[ flt.callsign ] = flt;
					$('#tbody').append(
						function() {
							return "<tr>" +
								"<td><button onclick='$.setFlightLine(" + dataItem + ")' >" + flt.callsign + "</button></td>" +
								// "<td>" + flt.lat + "</td>" +
								// "<td>" + flt.lon + "</td>" +
								"<td>" + flt.spd_kts + "</td>" +
								"<td>" + flt.alt_ft + "</td>" +
								"<td>" + flt.hdg + "</td>" +
								"<td>" + flt.model.split("/")[1] + "</td>"+
							"<tr>";
						}
					);
					
					if ( ! $.aircraft[ flt.callsign ] ) {
						var craft = $.aircraft[ flt.callsign ] = {
							model: flt.model.split("/")[1],
							data: flt,
							object: null,
							update: true
						};	
						$.ifr.contentWindow.selectAircraft( craft )
						// $.ifr.contentWindow.makePlane( craft );
					} else {
						var craft = $.aircraft[ flt.callsign ];				
						craft.data = flt;
						craft.update = true;
						$.ifr.contentWindow.updatePlane( craft );
					}
				});
				
				$( "#dialog_window_1" ).dialog( "option", "title", $.defaultTitle + " - aircraft now flying: " + data.flights.length );
				document.title = $.defaultTitle + " - " + data.flights.length
				// $('#title').replaceWith( "<scan id='title'>aircraft flying: " + data.flights.length + "</scan>" );
				$('#status').replaceWith( "<p id='status'>Last update: " + $.flightsData.last_updated + "</p>" );

				$.each( $('.flt_window'), function( item, element) {
					var flt =  $.lookup[ element.id ];
					if ( flt !== undefined ) {
						var wid = $.elements.win[flt.callsign].width - 40;
						var hgt = $.elements.win[flt.callsign].height - 175;	
						var zoom = $.elements.win[flt.callsign].zoom;
						var zoomOSM = $.elements.win[flt.callsign].zoomOSM;
						element.innerHTML = $.setMap( flt, parseInt($.elements.thm.mapFlight), wid, hgt, zoom, zoomOSM);	
// console.log('new', zoom, zoomOSM, $('#zoomOSM' + flt.callsign)[0] );							
						$('#zoomOSM' + flt.callsign)[0].selectedIndex = zoomOSM;
					} else {
						element.innerHTML = element.id + " does not seem to be flying right now.";
					}0
				});			
				$.each( $.aircraft, function( item, element) {
					if ( element.update === false ) {
                        console.log( 'delete', element.data.callsign, item, element );
						$.ifr.contentWindow.removeAircraft( item );
						delete $.aircraft[ item ];
					}
					element.update = false;
				});
			})
		};
		
		$.setMap = function( flt, type, wid, hgt, zoom, zoomOSM) {
// console.log('zoom', zoom, zoomOSM);		
			var sel = '<select id="zoom' + flt.callsign + '" onchange="$.elements.win.' + flt.callsign + '.zoom = 8 ;">' +
				'<option>18</option><option>16</option><option>14</option><option>12</option><option>10</option><option>8</option><option>6</option></select>';
			
			var selOSM = '<select id="zoomOSM' + flt.callsign + '" onclick="$.elements.win[\'' + flt.callsign + '\'].zoomOSM = this.selectedIndex; $.setHash();">' +
				'<option>1</option><option>2</option><option>3</option><option>4</option><option>5</option><option>6</option><option>7</option><option>8</option><option>9</option><option>10</option><option>11</option><option>12</option></select>';
			
			if (type === 0) {
				return flt.model.split("/")[1] + '<br>' +
					'Hdg: ' + flt.hdg + ' Alt: ' + flt.alt_ft + ' Spd: ' + flt.spd_kts + '<br>' +
					'Lat: ' + flt.lat.toFixed(2) + '&deg Lon: ' +  flt.lon.toFixed(2) + '&deg<br>' +
					// '<img src"http://www.openstreetmap.org/index.html?lat=' + flt.lat + '&lon=' + flt.lon + '&zoom=12" />' +
					'<a href="http://maps.google.com/maps?z=14&t=k&q=loc:' + flt.lat + ',' + flt.lon + '" target="_blank">' +
					'<img src="http://maps.googleapis.com/maps/api/staticmap?center=' + flt.lat + ',' + flt.lon + '&maptype=satellite&zoom="' + zoom + '"&size=' + wid + 'x' + hgt + '&sensor=false" >' +
					'</a>' + '<br>' +
				'';			
			} else if (type === 1) {
                var model = flt.model.split("/")[1];
                //var link = '<a href="http://www.openstreetmap.org/index.html?lat=' + flt.lat + '&lon=' + flt.lon + '&zoom=' + zoom + '" target="_blank">';
                // init(fid,callsign,model,lon,lat,alt,hdg,spd,zoom);
                var link = '<a href="tracker.html?fid='+flt.fid+'&callsign='+flt.callsign+'&model='+model+
                    '&lat='+flt.lat+'&lon='+flt.lon+'&alt='+flt.alt_ft+'&hdg='+flt.hdg+'&spd='+flt.spd_kts+
                    '&zoom='+def_tzoom+'" target="_blank">';
				zoomOSM = 0.001 * Math.pow( (parseFloat(zoomOSM) + 1), 3 );
				var txt = model + '<br>' +
					'Hdg: ' + flt.hdg + ' Alt: ' + flt.alt_ft + ' Spd: ' + flt.spd_kts + '<br>' +
					'Lat: ' + flt.lat.toFixed(2) + '&deg Lon: ' +  flt.lon.toFixed(2) + '&deg<br>' +
					'<iframe width="' + wid + '" height="' + hgt + '" frameborder="0" scrolling="no" marginheight="0" marginwidth="0" src="http://www.openstreetmap.org/export/embed.html?bbox=' +
					(flt.lon - zoomOSM) + ',' + (flt.lat - zoomOSM) + ',' + (flt.lon + zoomOSM) + ',' + (flt.lat + zoomOSM) + '&amp;layer=mapnik" style="border: 1px solid black"></iframe>' +
					link + '<br>link' +
					'</a> zoom' + selOSM + '<br>' +
					'<img src="textures/fg_generic_craft.png" ' +
						'style="position:absolute; left: 45%; top: 50%; -webkit-transform: rotate(' + flt.hdg + 'deg)"/>' + 
				'';	
// console.log( (flt.lon - zoomOSM),(flt.lat - zoomOSM),(flt.lon + zoomOSM),(flt.lat + zoomOSM));
				return txt;
				
			} else {
				return flt.model.split("/")[1] + '<br>' +
					'Hdg: ' + flt.hdg + ' Alt: ' + flt.alt_ft + ' Spd: ' + flt.spd_kts + '<br>' +
					'Lat: ' + flt.lat.toFixed(2) + '&deg Lon: ' +  flt.lon.toFixed(2) + '&deg<br>' +
					'<a href="http://maps.google.com/maps?z=14&t=m&q=loc:' + flt.lat + ',' + flt.lon + '" target="_blank">' +
					'<img src="http://maps.googleapis.com/maps/api/staticmap?center=' + flt.lat + ',' + flt.lon + '&maptype=roadmap&zoom="' + zoom + '"&size=' + wid + 'x' + hgt + '&sensor=false" >' +
					'</a>' + '<br>' +
				'';	
			}
		};

        if (use_tracker_html) {
          $.setFlightLine = function( item ) {
			var flt = $.flightsData.flights[ item ];
            var model = flt.model.split("/")[1];
            var url = 'tracker.html?fid='+flt.fid+'&callsign='+flt.callsign+'&model='+model+
                    '&lat='+flt.lat+'&lon='+flt.lon+'&alt='+flt.alt_ft+'&hdg='+flt.hdg+'&spd='+flt.spd_kts+
                    '&zoom='+def_tzoom;
            var spec = 'fullscreen=yes';
            // other specs ???? - should be a FULL normal window
            spec += ',location=yes'; // Whether or not to display the address field 
            spec += ',menubar=yes';  // Whether or not to display the menu bar 
            spec += ',resizable=yes'; // Whether or not the window is resizable 
            spec += ',scrollbars=yes'; // Whether or not to display scroll bars 
            spec += ',status=yes';    // Whether or not to add a status bar 
            spec += ',titlebar=yes';  // Whether or not to display the title bar. Ignored unless the calling application is an HTML Application or a trusted dialog box 
            spec += ',toolbar=yes';   // Whether or not to display the browser toolbar 
            window.open(url,model,spec);
          };
        } else {
          $.setFlightLine = function( item ) {
// console.log( item );
			var flt = $.flightsData.flights[ item ];
			$.elements.win[flt.callsign] = {
				className: 'flt_window',
				closer: "true",
				fname: "ajax/new-window.html",
				height: "500",
				id: flt.callsign,
				left: "100",
				title: flt.callsign,
				top: "100",
				width: "370",
				zoom: "14",
				zoomOSM: 2,
			};
			$.newDialog( $.elements.win[flt.callsign]  );
			$.getCrossfeed();
			$.setHash();
		 };
        }
	});	