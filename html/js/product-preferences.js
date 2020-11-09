/*global lang */

var attribute_groups;	// All supported attribute groups and attributes + translated strings
var preferences;	// All supported preferences + translated strings


function get_user_product_preferences () {
	// Retrieve user preferences from local storage

	var user_product_preferences = {};
	var user_product_preferences_string = localStorage.getItem('user_product_preferences');

	if (user_product_preferences_string) {
		user_product_preferences = JSON.parse(user_product_preferences_string);
	}
	else {
		// Default preferences
		user_product_preferences = { "nutriscore" : "very_important", "nova" : "important", "ecoscore" : "important" };
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
				var attribute_html = '<li>' + attribute.setting_name + '</li>';
				selected_preference_groups[product_preferences[attribute.id]].push(attribute_html);
			}
		});
	});	

	var selected_preferences_html = '';

	$.each(selected_preference_groups, function(selected_preference, selected_preference_group) {
		
		var selected_preference_name;
		
		$.each(preferences, function (key, preference) {
					
			if (selected_preference == preference.id) {
				selected_preference_name = preference.name;
			}
		});
		
		if (selected_preference_group.length > 0) {
			selected_preferences_html += "<div>"
			+ "<strong>" + selected_preference_name + "</strong>"
			+ "<ul>" + selected_preference_group.join("") + "</ul>"
			+ "</div>";
		}
	});
	
	$( target_selected ).html(
		'<div class="panel callout">'
		+ '<div class="edit_button">'
		+ '<a id="show_selection_form" class="button small">'
		+ '<img src="/images/icons/dist/food-cog.svg" class="icon" style="filter:invert(1)">'
		+ " " + lang().preferences_edit_your_food_preferences + '</a></div>'
		+ "<h2>" + lang().preferences_your_preferences + "</h2>"
		+ '<a id="preferences_link" data-dropdown="selected_preferences">'
		+ lang().preferences_currently_selected_preferences + ' &raquo;</a>'
		+ '<div id="selected_preferences" data-dropdown-content class="f-dropdown content medium">' 
		+ selected_preferences_html
		+ '</div>'
		+ '</div>'
	);
		
	$( "#show_selection_form").click(function() {
		$( target_selected ).hide();
		$( target_selection_form ).show();
		$(document).foundation('equalizer', 'reflow');
	});
	
	$(document).foundation('reflow');
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
			
			var attribute_group_html = "<li id='attribute_group_" + attribute_group.id + "' class='attribute_group accordion-navigation'>" 
			+ "<a href='#attribute_group_" + attribute_group.id + "_a' style='color:black;'>"
			+ "<span class='attribute_group_name'>" + attribute_group.name + "</span></a>"
			// I can't get the dynamically created accordion to work, making all content active until we find a way to make it work
			+ "<div id='attribute_group_" + attribute_group.id + "_a' class='content active'>";
			
			if (attribute_group.warning) {
				attribute_group_html += "<div class='alert-box warning attribute_group_warning'>" + attribute_group.warning + "</div>";
			}
			
			attribute_group_html += "<ul style='list-style-type: none'>";
			
			// Iterate over attributes
			
			$.each(attribute_group.attributes, function(key, attribute) {
				
				attribute_group_html += "<li id='attribute_" + attribute.id + "' class='attribute'>"
				+ "<div style='width:96px;float:left;margin-right:1em;'><img src='" + attribute.icon_url + "' class='match_icons'></div>"
				+ "<span class='attribute_name'>" + attribute.setting_name + "</span><br>";
							
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
				
				if (attribute.description_short) {
					attribute_group_html += "<p class='attribute_description_short'>" + attribute.description_short + "</p>";
				}
				
				attribute_group_html += "<hr style='clear:left;border:none;margin:0;margin-bottom:0.5rem;padding:0;'>";
				
				attribute_group_html += "</li>";
			});
						
			attribute_group_html += "</ul></div></li>";
			
			attribute_groups_html.push(attribute_group_html);
		});

		$(target_selection_form).html(
			'<div class="panel callout">'
			+ '<div class="edit_button">'
			+ '<a class="show_selected button small">'
			+ '<img src="/images/icons/dist/cancel.svg" class="icon" style="filter:invert(1)">'
			+ " " + lang().close + '</a></div>'
			+ "<h2>" + lang().preferences_edit_your_food_preferences + "</h2>"
			+ "<p>" + lang().preferences_locally_saved + "</p>"
			+ '<ul id="user_product_preferences" class="accordion" data-accordion>'
			+ attribute_groups_html.join( "" )
			+ '</ul>'
			+ '<br><br>'
			+ '<div class="edit_button">'
			+ '<a class="show_selected button small">'
			+ '<img src="/images/icons/dist/cancel.svg" class="icon" style="filter:invert(1)">'
			+ " " + lang().close + '</a></div><br><br>'
			+ '</div>'
		);
		
		$( ".attribute_radio").change( function () {
			if (this.checked) {

				user_product_preferences[this.name] = $("input[name='" + this.name + "']:checked").val();
				localStorage.setItem('user_product_preferences', JSON.stringify(user_product_preferences));
				
				display_selected_preferences(target_selected, target_selection_form, user_product_preferences);
				
				// Call the change callback if we have one (e.g. to update search results)
				if (change) {
					change();
				}
			}
		});
			
		if (target_selected) {	
			display_selected_preferences(target_selected, target_selection_form, user_product_preferences);
		}
			
		$( ".show_selected").click(function() {
			$( target_selection_form ).hide();
			$( target_selected ).show();
		});

		$("#user_product_preferences").foundation();
		$(document).foundation('equalizer', 'reflow');
	}
}
