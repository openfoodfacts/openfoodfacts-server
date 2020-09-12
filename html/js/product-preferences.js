var attribute_groups;	// All supported attribute groups and attributes + translated strings
var preferences;	// All supported preferences + translated strings

// Retrieve user preferences from local storage

var user_product_preferences = {};
var user_product_preferences_string = localStorage.getItem('user_product_preferences');

if (user_product_preferences_string) {
	user_product_preferences = JSON.parse(user_product_preferences_string);
}

// show_user_product_preferences can be called by other scripts

function show_user_product_preferences (target) { // eslint-disable-line no-unused-vars

	// Retrieve all the supported attribute groups from the server, unless we have them already
	
	if (! attribute_groups) {
		
		$.getJSON( "/api/v0/attribute_groups", function( data ) {
		
			attribute_groups = data;
		
			show_user_product_preferences(target);
		});
	}
	
	if (! preferences) {
		
		$.getJSON( "/api/v0/preferences", function( data ) {
		
			preferences = data;
		
			show_user_product_preferences(target);
		});		
	}
	
	if (attribute_groups && preferences) {
		
		var attribute_groups_html = [];
		
		// Iterate over attribute groups
		$.each( attribute_groups, function(key, attribute_group) {
			
			var attribute_group_html = "<li id='attribute_group_" + attribute_group.id + "' class='attribute_group'>" + attribute_group.name 
			+ "<ul>";
			
			// Iterate over attributes
			
			$.each(attribute_group.attributes, function(key, attribute) {
				
				attribute_group_html += "<li id='attribute_" + attribute.id + "' class='attribute'><spanc class='attribute_name'>" + attribute.setting_name + "</span><br>";
								
				$.each(preferences, function (key, preference) {
					
					var checked = '';
					
					if (user_product_preferences[attribute.id] == preference.id) {
						checked = ' checked';
					}
					
					attribute_group_html += "<input class='attribute_radio' id='attribute_" + attribute.id + "_" + preference.id
					+ "' value='" + preference.id + "' type='radio' name='" + attribute.id + "'" + checked + ">"
					+ "<label for='attribute_" + attribute.id + "_" + preference.id + "'>" + preference.name + "</label>"
					+ "</input>";
				});
				
				attribute_group_html += "</li>";
			});
						
			attribute_group_html += "</ul></li>";
			
			attribute_groups_html.push(attribute_group_html);
		});

		$( "<ul/>", {
			"class": "user_product_preferences",
			html: attribute_groups_html.join( "" )
		}).replaceAll(target);
		
		$( ".attribute_radio").change(function () {
			user_product_preferences[this.name] = $("input[name='" + this.name + "']:checked").val();
			localStorage.setItem('user_product_preferences', JSON.stringify(user_product_preferences));
		});
	}
}
