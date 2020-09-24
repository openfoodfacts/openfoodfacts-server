var attribute_groups;	// All supported attribute groups and attributes + translated strings
var preferences;	// All supported preferences + translated strings


function get_user_product_preferences () {
	// Retrieve user preferences from local storage

	var user_product_preferences = {};
	var user_product_preferences_string = localStorage.getItem('user_product_preferences');

	if (user_product_preferences_string) {
		user_product_preferences = JSON.parse(user_product_preferences_string);
	}
	
	return user_product_preferences;
}


// display_user_product_preferences can be called by other scripts
/* exported display_user_product_preferences */

function display_user_product_preferences (target, change) {

	// Retrieve all the supported attribute groups from the server, unless we have them already
	
	if (! attribute_groups) {
		
		$.getJSON( "/api/v0/attribute_groups", function( data ) {
		
			attribute_groups = data;
		
			display_user_product_preferences(target, change);
		});
	}
	
	if (! preferences) {
		
		$.getJSON( "/api/v0/preferences", function( data ) {
		
			preferences = data;
		
			display_user_product_preferences(target, change);
		});		
	}
	
	if (attribute_groups && preferences) {
		
		var user_product_preferences = get_user_product_preferences();
		
		var attribute_groups_html = [];
		
		// Iterate over attribute groups
		$.each( attribute_groups, function(key, attribute_group) {
			
			var attribute_group_html = "<li id='attribute_group_" + attribute_group.id + "' class='attribute_group'>" 
			+ "<span class='attribute_group_name'>" + attribute_group.name + "</span>";
			
			if (attribute_group.warning) {
				attribute_group_html += "<p class='attribute_group_warning'>" + attribute_group.warning + "</p>";
			}
			
			attribute_group_html += "<ul>";
			
			// Iterate over attributes
			
			$.each(attribute_group.attributes, function(key, attribute) {
				
				attribute_group_html += "<li id='attribute_" + attribute.id + "' class='attribute'><span class='attribute_name'>" + attribute.setting_name + "</span><br>";
				
				if (attribute.description_short) {
					attribute_group_html += "<p class='attribute_description_short'>" + attribute.description_short + "</p>";
				}				
								
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
		
		$( ".attribute_radio").change( function () {
			if (this.checked) {

				user_product_preferences[this.name] = $("input[name='" + this.name + "']:checked").val();
				localStorage.setItem('user_product_preferences', JSON.stringify(user_product_preferences));
				
				// Call the change callback if we have one (e.g. to update the search results)
				if (change) {
					change();
				}
			}
		});
	}
}
