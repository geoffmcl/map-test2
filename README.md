map-test2
=========

Some OpenLayers and crossfeed tests and experiments. This is NOT intended as a 
viewing or user site. It is a bunch of developer EXPERIMENTS only. NOT all 
pages WORK! The failed pages are left as a reminder of what does NOT work!

Since this is hosted in github gh-pages branch, the HTML pages can be viewed in 
a browser, but since gh-pages is NOT a full web host, some features will fail,
but the site pages are also hosted on other servers.

[Hosted on github]( http://geoffmcl.github.io/map-test2/ )

My main site server -
[Hosted on godaddy]( http://geoffair.org/fg/map-test2/ )

And IF my home server is running, and the IP is correct -
[Hosted on Pro2home] ( http://pro2home.dnsdynamic.com/map-test2/ )

To repeat some notes from the index page...

This is **NOT** a 'show case' nor user 'viewing' site!
Not ALL pages 'work'! They are mainly javascript coding tests.

Perhaps the MAIN page, if there is one, is -
[map-test.html]( http://geoffair.org/fg/map-test2/map-test.html )

This gets a feed of the current [FligtGear (FG)]( http://flightgear.org ) and places the 
current active MultiPlayers (MP) on a map, updating their position each few seconds.

And presents a table list of active flights. If an active flight callsign is selected (clicked)
in the table list, then a 'tracker' page will be opened to follow that single flight.

The current 'track' painted in 'blue', and a predicted path in 'red'. This will continue 
until the flight leaves the MP server. IFF that flight is being 'tracked' by [FGTracker] ( http://mpserver15.flightgear.org/modules/fgtracker/ ),
where the left panel shows which MP servers are active and being 'tracked', then the 'history' of that
flight will also be added as a 'green' line. If 'map-test' knows the flight is NOT being
tracked, by checking the [FGTracker API] (http://mpserver15.flightgear.org/modules/content/index.php?id=4)
then it will append an '*' to the callsign.

EOF
