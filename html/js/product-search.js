
// Will hold product data retrieved from the search API
var products = [];


// match_product_to_preference checks if a product matches
// a given set of preferences and scores the product according to
// the preferences
//
// The product object must contain the attribute_groups field
//
// Output values are returned in the product object
//
// - match_status: yes, no, unknown
// - match_score: number (maximum depends on the preferences)
// - match_icons: array of arrays of urls of icons corresponding to the product and 
// each set of preferences: mandatory, very_important, important

function match_product_to_preferences (product, product_preferences) {

	var score = 0;
	var status = "yes";
	var debug = "";
	
	product.match_icons = {
		"mandatory" : [],
		"very_important" : [],
		"important" : []
	};

	product.match_attributes = {
		"mandatory" : [],
		"very_important" : [],
		"important" : []
	};

	if (product.attribute_groups) {
		
		// Iterate over attribute groups
		$.each( product.attribute_groups, function(key, attribute_group) {
			
			// Iterate over attributes
			
			$.each(attribute_group.attributes, function(key, attribute) {
				
				if ((! product_preferences[attribute.id]) || (product_preferences[attribute.id] == "not_important")) {
					// Ignore attribute
					debug += attribute.id + " not_important" + "\n";
				}
				else {
					
					if (attribute.status == "unknown") {
						
						// If the attribute is important or more, then mark the product unknown
						// if the attribute is unknown (unless the product is already not matching)				
						
						if (status == "yes") {
							status = "unknown";
						}
					}
					else {
						
						debug += attribute.id + " " + product_preferences[attribute.id] + " - match: " + attribute.match + "\n";
					
						if (product_preferences[attribute.id] == "important") {
					
							score += attribute.match;
						}
						else if (product_preferences[attribute.id] == "very_important") {
							
							score += attribute.match * 2;
						}
						else if (product_preferences[attribute.id] == "mandatory") {

							score += attribute.match * 4;
					
							if (attribute.match <= 20) {
								status = "no";
							}
						}
					}
					
					if (attribute.icon_url) {
						product.match_icons[product_preferences[attribute.id]].push(attribute.icon_url);
					}
					
					product.match_attributes[product_preferences[attribute.id]].push(attribute);
				}
			});
		});		
	}
	else {
		// the product does not have the attribute_group field 
		status = "unknown";
	}

	product.match_status = status;
	product.match_score = score;	
	product.match_debug = debug;	
}

// rank_products (products, product_preferences)

function rank_products(products, product_preferences) {
	
	// Score all products
	
	$.each(products, function (key, product) {
		
		match_product_to_preferences(product, product_preferences);
		
	});
	
	// Rank all products, and return them in 3 arrays: "yes", "no", "unknown"
	
	products.sort(function(a, b) {
		return b.match_score - a.match_score;
	});
	
	var product_groups = {
		"yes" : [],
		"unknown" : [],
		"no" : [],
	};
	
	$.each( products, function(key, product) {

		product_groups[product.match_status].push(product);
	});
	
	return product_groups;
}


function display_products(target, product_groups ) {
	
	$( target ).html('<ul id="products_tabs_titles" class="tabs" data-tab></ul>'
		+ '<div id="products_tabs_content" class="tabs-content"></div>');
	
	$.each(product_groups, function(product_group_id, product_group) {
	
		var products_html = [];
		
		$.each( product_group, function(key, product) {
		
			var product_html = "<li>";
			
			product_html += '<a href="' + product.url + '"><div>';
			
			if (product.image_front_thumb_url) {
				product_html += '<img src="' + product.image_front_thumb_url + '">';
			}
			
			product_html += "</div>";
			
			product_html += "<span>" + product.product_name + "</span>";
			
			product_html += '</a>';
			
			$.each(product.match_icons.mandatory.concat(product.match_icons.very_important, product.match_icons.important), function (key, icon_url) {
				
				product_html += '<img src="' + icon_url + '" class="match_icons">';
			});
			
			product_html += '<span title="' + product.match_debug + '">' + Math.round(product.match_score) + '</span>';
			
			product_html += "</li>";
				
			products_html.push(product_html);		
		});
		
		var active = "";
		if (product_group_id == "yes") {
			active = " active";
		}
		
		$("#products_tabs_titles").append(
			'<li class="tabs tab-title' + active + '"><a href="#products_' + product_group_id + '">'
			+ product_group_id + " : " + product_group.length + " products" + "</a></li>"
		);
		
		$("#products_tabs_content").append(
			'<div class="tabs content' + active + '" id="products_' + product_group_id + '">'
			+ '<ul class="products search_results" id="products_match_' + product_group_id + '">'
			+ products_html.join( "" )
			+ '</ul>'
		);
		
		$(document).foundation('tab', 'reflow');
		$(document).foundation('equalizer', 'reflow');
		
		$('#products_tabs_titles').on('toggled', function () {
			$(document).foundation('equalizer', 'reflow');
		});

	});
}

/* global get_user_product_preferences */
/* exported display_product_summary */

function display_product_summary(target, product) {
	
	var user_product_preferences = get_user_product_preferences();
	
	match_product_to_preferences(product, user_product_preferences);
	
	var attributes_html = '';
	
	$.each(product.match_attributes.mandatory.concat(product.match_attributes.very_important, product.match_attributes.important), function (key, attribute) {
		
		// vary the color from green to red
		var color = "#eee";
		
		if (attribute.status == "known") {
			if (attribute.match <= 20) {
				color = "hsl(0, 100%, 90%)";
			}
			else if (attribute.match <= 40) {
				color = "hsl(30, 100%, 90%)";
			}
			else if (attribute.match <= 60) {
				color = "hsl(60, 100%, 90%)";
			}
			else if (attribute.match <= 80) {
				color = "hsl(90, 100%, 90%)";
			}
			else {
				color = "hsl(120, 100%, 90%)";
			}
		}
		
		attributes_html += '<div class="small-12 medium-6 large-4 columns">'
		+ '<div style="border-radius:12px;background-color:' + color + ';padding:1rem;margin-bottom:1rem;min-height:96px;">'
		+ '<img src="' + attribute.icon_url + '" style="height:72px;float:right;">'
		+ '<h4>' + attribute.title + '</h4>';
		
		if (attribute.description_short) {
			attributes_html += '<span>' + attribute.description_short + '</span>';
		}
		
		attributes_html += '</div>'
		+ '</div>';
	});
	
	$( target ).html('<div class="row" id="attributes_row">' + attributes_html + '</div>');
		
	$(document).foundation('equalizer', 'reflow');
}


function rank_and_display_products (target) {
	
	// Retrieve user preferences from local storage

	var user_product_preferences = get_user_product_preferences();
	
	var ranked_products = rank_products(products, user_product_preferences);
			
	display_products(target, ranked_products);
			
	$(document).foundation('equalizer', 'reflow');
}


/* exported search_products */

function search_products (target, search_api_url) {

	// Retrieve generic search results from the search API
	
	$.getJSON( search_api_url, function( data ) {
		
		if (data.products) {
			
			products = data.products;
			
			rank_and_display_products(target);
		}		
	});
}
