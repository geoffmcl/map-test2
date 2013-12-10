file : README.txt - 20131104

This is just a bunch of map tests using OpenLayer, OpenStreetMap,
jQuery and other javascript libraries and code to generate maps,
in 2D, but hopefully fully expanding to 3D using Three.js, and
WebGL.

The primary example is index.html. This uses a simple OSM
map, gets a json feed from a fgms (FlightGear Multiplayer 
Server) crossfeed client. The json string can be seen from -
 http://crossfeed.fgx.ch/flights.json

This generate a table of active pilots, and places their 
aircraft on the OSM map. The position of the aircraft is 
updates approximately each 3 seconds.

The 'test-map' has lots of quiet features -

* The active list can be 'Hidden' or 'Shown' by clicking 
  on the 'H" at the right end of the table header line. The 
  'H' being replaced with an 'S' when hidden to show it
  again.


* Clicking on the callsign of any particular flight line 
  should open a new window, with a 3D model of the aircraft.

  TODO: Not all models are currently represented, and in this case 
  will simply display the last aircraft (if cookies enabled).

  TODO: Some model are badly 'shaped', and some still have 
  their wheels down, and other artifacts whihc need to be 
  removed.


* Clicking on the column header will sort the list per that 
  item, and a second click will reverse the sort.

  TODO: However new flights arriving after the sort are 
  not presently placed in that order, but only appended 
  to the end of the table.

* A simple 'status' count of active flight is also updated,
  including a guestimate whether the flight is an ATC 
  installation.

  TODO: SInce there are presently no rules concerning 
  the callsign, nor model used by ATC, this is only a 
  rough guess.

Enjoy.

Geoff.

# eof
