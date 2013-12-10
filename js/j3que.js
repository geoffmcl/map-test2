// loads faster out here?!?

	var link = document.head.appendChild( document.createElement("link") );
	link.setAttribute("rel", "stylesheet");
	// link.setAttribute("type", "text/css");
	if ( location.hash === "" ) {
		link.setAttribute("href", "http://code.jquery.com/ui/1.10.2/themes/smoothness/jquery-ui.css");
	} else {
		var hashes = location.hash.split("#");
		link.setAttribute("href", "http://code.jquery.com/ui/1.10.2/themes/" + hashes[1].substr(9) + "/jquery-ui.css");
	}


$(function() {

// Source for a number of the ideas here: http://net.tutsplus.com/tutorials/javascript-ajax/creating-a-windows-like-interface-with-jquery-ui/
// especially this minimize stuff just below
	var _init = $.ui.dialog.prototype._init;

	$.ui.dialog.prototype._init = function() {
		_init.apply(this, arguments);

		var dialog_element = this;
		var dialog_id = this.uiDialogTitlebar.next().attr("id");

		this.uiDialogTitlebar.append('<a href="#" id="' + dialog_id + '-minbutton" class="ui-dialog-titlebar-minimize ui-state-default ui-corner-all">'+
			'<span class="ui-icon ui-icon-newwin ui-icon-minusthick"></span></a>');

		$('#dialog_window_minimized_container').append(
			'<div class="dialog_window_minimized ui-widget ui-state-default ui-corner-all" id="' + dialog_id + '_minimized">' +
			this.uiDialogTitlebar.find('.ui-dialog-title').text() +  '<span class="ui-icon ui-icon-newwin"></div>');

		$("#" + dialog_id + "-minbutton").hover(function() {
			$(this).addClass("ui-state-hover");
		}, function() {
			$(this).removeClass("ui-state-hover");
		}).click(function() {
			dialog_element.close();
			$("#" + dialog_id + "_minimized").show();
		});

		$("#" + dialog_id + "_minimized").click(function() {
			$(this).hide();
			dialog_element.open();
		});
	};

	$.newDialog = function ( win ) {
		$("body").append('<div class="' + win.className + '" id="' + win.id + '" >loading...</div>');
		dialog = $('#' + win.id).dialog({
			autoOpen: true,
			height: win.height,
			position: {
				my: "left top",
				at: "left+" + win.left + " top+" + win.top,
				of: window
			},
			title: win.title,
			width: win.width,
			
			dragStop: function( event, ui ) {
				win.left = ui.position.left;
				win.top = ui.position.top;
				$.setHash();
			},
			close: function( event, ui) {
				win.closed = true;
				$.setHash();
			},
// add close window - delete hash settings
// source: http://acuriousanimal.com/blog/2011/08/16/customizing-jquery-ui-dialog-hiding-close-button-and-changing-opacity/
			open: function( event, ui) {
				if ( win.closer === "false" ) $(this).parent().children().children(".ui-dialog-titlebar-close").hide();
// move this to more obvious location:
				$(this).parent().css({ opacity: 0.80 });
			},
			resize: function( event, ui ) {
				win.height = ui.size.height.toFixed();
				win.width = ui.size.width.toFixed();
				$.setHash();
			}
		});
// load content for each window from external file		
		$( "#" + win.id).load( win.fname );
	};

// permalinks
	var e = $.elements = {};

	$.setHash = function() {
		var settings = "";
		for (var items in e) {
			if ( items === "win" ) {
				for ( var wins in e.win ) {
// console.log( e.win[wins].closed )
					if ( e.win[wins].closed !== true ) {
						for ( var item in e.win[wins] ) {
							settings += "win." + wins + "." + item + "=" +  e.win[wins][item] +  "#";
						}
					}
				}
			} else {
				for ( var item in e[items] ) {
					settings += items + "." + item + "=" + e[items][item] +  "#";
					if ( item === "name" ) {
						link.setAttribute("href", "http://code.jquery.com/ui/1.10.2/themes/" + e[items][item] + "/jquery-ui.css");
					}
				}
			}
		}
		location.hash = settings;
		$.permalink = location.hash;
	};

	$.resetHash = function () {
		window.history.pushState( "", "", window.location.pathname);
		$.permalink = "";
	};


	$.getHash = function () {
// defaults
		$.defaultTitle = "FGx Globe r3.3";
		if ( location.hash === "" ) {
			e.thm = {
				name: "smoothness",
				select: 16,
				mapFlight: 1,
				mapGlobe: 1
			};
			e.win =  {
				w1: {
					className: "basic",
					closer: "false",
					fname: "ajax/0fgx-globe.html",
					height: window.innerHeight - 50,
					id: "dialog_window_1",
					left: window.innerWidth - 530, // "3000",
					title: $.defaultTitle,
					top: "20",
					width: "510"
				}
			};
			$.permalink = "";

// or load from hash fragment
		} else {
			var items, item, hashes = location.hash.split("#");
			for (var i = 1, len = hashes.length - 1; i < len; i++) {
				items =  hashes[i].split("=");
				item = items[0].split(".");
				if ( e[item[0]] === undefined ) { e[item[0]] = {}; }
				if ( item.length > 2 ) {
					if ( e[item[0]][item[1]] === undefined ) { e[item[0]][item[1]] = {}; }
					e[item[0]][item[1]][item[2]] = items[1];
				} else {
					e[item[0]][item[1]] = items[1];
				}
			}
		}
		$.permalink = location.hash;

		$.each($.elements.win, function( item, element) {
			$.newDialog( element );
		});
	};

	var winMin = document.body.appendChild( document.createElement( "div" ) );
	winMin.id = "dialog_window_minimized_container";
});