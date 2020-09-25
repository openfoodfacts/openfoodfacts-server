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


// display a summary of the selected preferences
// in the order mandatory, very important, important

function display_selected_preferences (target_selected, target_selection_form, product_preferences) {
	
	var selected_preference_groups = {
		"mandatory" : [],
		"very_important" : [],
		"important" : [],
	};
	
	// Iterate over attribute groups
	$.each( attribute_groups, function(key, attribute_group) {
		
		// Iterate over attributes
		
		$.each(attribute_group.attributes, function(key, attribute) {
			
			if ((product_preferences[attribute.id]) && (product_preferences[attribute.id] != "not_important")) {
				var attribute_html = '<span>' + attribute.setting_name + '</span>';
				selected_preference_groups[product_preferences[attribute.id]].push(attribute_html);
			}
		});
	});	

	var selected_preferences_html = '';

	$.each(selected_preference_groups, function(preference, selected_preference_group) {
		
		if (selected_preference_group.length > 0) {
			selected_preferences_html += "<div>"
			+ "<strong>" + preference + ": </strong>"
			+ selected_preference_group.join(", ")
			+ "</div>";
		}
	});
	
	$( target_selected ).html(selected_preferences_html);
	
	// Show a button to edit the preferences
	if (target_selection_form) {
		$( target_selected ).append('<a id="show_selection_form">' + "Edit preferences" + '</a>');
		$( "#show_selection_form").click(function() {
		  $( target_selected ).hide();
		  $( target_selection_form ).show();
		});
	}
}


// display_user_product_preferences can be called by other scripts
/* exported display_user_product_preferences */

// Make sure we display the preferences only once when we have both preferences and attribute_groups loaded
var displayed_user_product_preferences = false;

function display_user_product_preferences (target_selected, target_selection_form, change) {

	// Retrieve all the supported attribute groups from the server, unless we have them already
	
	if (! attribute_groups) {
		
		$.getJSON( "/api/v0/attribute_groups", function( data ) {
		
			attribute_groups = data;
		
			display_user_product_preferences(target_selected, target_selection_form, change);
		});
	}
	
	if (! preferences) {
		
		$.getJSON( "/api/v0/preferences", function( data ) {
		
			preferences = data;
		
			display_user_product_preferences(target_selected, target_selection_form, change);
		});		
	}
	
	if (attribute_groups && preferences && ! displayed_user_product_preferences) {
		
		displayed_user_product_preferences = true;
		
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

		$(target_selection_form).html( '<ul class="user_product_preferences">'
			+ attribute_groups_html.join( "" )
			+ '</ul>');
		
		$( ".attribute_radio").change( function () {
			if (this.checked) {

				user_product_preferences[this.name] = $("input[name='" + this.name + "']:checked").val();
				localStorage.setItem('user_product_preferences', JSON.stringify(user_product_preferences));
				
				display_selected_preferences (target_selected, target_selection_form, user_product_preferences);
				
				// Call the change callback if we have one (e.g. to update search results)
				if (change) {
					change();
				}
			}
		});
		
		// Show a button to close the preferences selection form and show the selected preferences
		if (target_selected) {
			
			display_selected_preferences (target_selected, target_selection_form, user_product_preferences);
			
			$( target_selection_form ).prepend('<a id="show_selected">' + "Close preferences" + '</a>');
			$( "#show_selected").click(function() {
			  $( target_selection_form ).hide();
			  $( target_selected ).show();
			});
		}		
	}
}
