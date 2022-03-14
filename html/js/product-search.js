/*global lang */

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
// - match_attributes: array of arrays of attributes corresponding to the product and 
// each set of preferences: mandatory, very_important, important

function match_product_to_preferences (product, product_preferences) {

	var score = 0;
	var status = "yes";
	var debug = "";

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

// keep the initial order of each result
var initial_order = 0;

function rank_products(products, product_preferences, use_user_product_preferences_for_ranking) {
	
	// Score all products
	
	$.each(products, function (key, product) {
		
		if (! product.initial_order) {
			product.initial_order = initial_order;
			initial_order += 1;
		}
		
		match_product_to_preferences(product, product_preferences);	
	});
	
	// If we don't use the user preferences for ranking, we show products in the initial order
	
	if (use_user_product_preferences_for_ranking) {
	
		// Rank all products, and return them in 3 arrays: "yes", "no", "unknown"
		
		products.sort(function(a, b) {
			return (b.match_score - a.match_score) || (a.initial_order - b.initial_order);
		});	
	}
	else {
		products.sort(function(a, b) {
			return (a.initial_order - b.initial_order);
		});	
	}
	
	var product_groups = {
		"all" : [],
		"yes" : [],
		"unknown" : [],
		"no" : [],
	};
	
	$.each( products, function(key, product) {

		if (use_user_product_preferences_for_ranking) {
			product_groups[product.match_status].push(product);
		}
		product_groups.all.push(product);
	});
	
	return product_groups;
}


function product_edit_url(product) {
	return `/cgi/product.pl?type=edit&code=${product.code}`;
}

function display_products(target, product_groups, user_prefs) {
		
	if (user_prefs.ranking) {
		$( target ).html('<ul id="products_tabs_titles" class="tabs" data-tab></ul>'
		+ '<div id="products_tabs_content" class="tabs-content"></div>');
	}
	else {
		$( target ).html('<div id="products_tabs_content" class="tabs-content"></div>');
	}
	
	$.each(product_groups, function(product_group_id, product_group) {
		const user_product_preferences = user_prefs.prefs;
		var products_html = [];
		
		$.each( product_group, function(key, product) {
		
			var product_html = "";
			
			// Show the green / grey / colors for matching products only if we are using the user preferences
			let css_classes = 'list_product_a';
			if (user_prefs.ranking) {
				css_classes += ' list_product_a_match_' + product.match_status;
			}
			product_html += `<li><a href=${product.url}" class="${css_classes}">`;
			product_html += '<div class="list_product_img_div">';
			
			if (product.image_front_thumb_url) {
				product_html += '<img src="' + product.image_front_thumb_url + '" class="list_product_img">';
			}
			else {
				product_html += '<img src="/images/icons/product-silhouette-transparent.svg" class="list_product_img">';
			}
			
			product_html += "</div>";
			
			if (product.product_display_name) {
				product_html += '<div class="list_product_name">' + product.product_display_name + "</div>";
			}
			else {
				product_html += '<div class="list_product_name">' + product.code + "</div>";
			}
									
			$.each(product.match_attributes.mandatory.concat(product.match_attributes.very_important, product.match_attributes.important), function (key, attribute) {
				
				if (attribute.icon_url) {
					var title = attribute.title;
				
					if (attribute.description_short) {
						title += ' - ' + attribute.description_short;
					}

					if (attribute.missing) {
						title += " - " + attribute.missing;
					}		
					
					product_html += '<img class="list_product_icons" src="' + attribute.icon_url + '" title="' + title + '">';
				}
			});
			// add some specific fields
			if (user_product_preferences.display_barcode === "yes") {
				product_html += `<span class="list_display_barcode">${product.code}</span>`;
			}
			product_html += "</a>";
			if (user_product_preferences.edit_link === "yes") {
				const edit_url = product_edit_url(product);
				product_html += `
				  <a class="list_edit_link" alt="Edit ${product.product_display_name}" href="${edit_url}">
				    <img src="/images/attributes/edit_link.svg">
				  </a>
				`;
			}
			product_html += "</li>";
				
			products_html.push(product_html);		
		});
		
		var active = "";
		var text_or_icon = "";
		if (product_group_id == "all") {
			active = " active";
			if (product_group.length == 1) {
				text_or_icon = lang()["1_product"];
			}
			else {
				text_or_icon = product_group.length + ' ' + lang().products;
			}
		}
		else {
			text_or_icon = '<img src="/images/attributes/match-' + product_group_id + '.svg" class="icon">'
			+ ' <span style="color:grey">' + product_group.length + "</span>";
		}
		
		if (user_prefs.ranking) {
			$("#products_tabs_titles").append(
				'<li class="tabs tab-title tab_products-title' + active + '">'
				+ '<a  id="tab_products_' + product_group_id + '" href="#products_' + product_group_id + '" title="' + lang()["products_match_" + product_group_id] +  '">'
				+ text_or_icon
				+ "</a></li>"
			);
		}
		
		$("#products_tabs_content").append(
			'<div class="tabs content' + active + '" id="products_' + product_group_id + '">'
			+ '<ul class="search_results small-block-grid-1 medium-block-grid-4 large-block-grid-6 xlarge-block-grid-8 xxlarge-block-grid-10" id="products_match_' + product_group_id + '" style="list-style:none">'
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
		var grade ="unknown";
		
		if (attribute.status == "known") {
			grade = attribute.grade;
		}

		attributes_html += '<li>'
		+ '<div class="attribute_card grade_' + grade + '">'
		+ '<img src="' + attribute.icon_url + '" style="height:72px;float:right;margin-left:0.5rem;">'
		+ '<h4 class="grade_' + grade + '_title">' + attribute.title + '</h4>';
		
		if (attribute.description_short) {
			attributes_html += '<span>' + attribute.description_short + '</span>';
		}
		
		if (attribute.missing) {
			attributes_html += "<p class='attribute_missing'>" + attribute.missing + "</p>";
		}		

		attributes_html += '</div></li>';
	});
	
	$( target ).html('<ul id="attributes_grid" class="small-block-grid-1 medium-block-grid-2 large-block-grid-3">' + attributes_html + '</ul>');
		
	$(document).foundation('equalizer', 'reflow');
}


function rank_and_display_products (target, products) {
	
	// Retrieve user preferences from local storage

	var user_product_preferences = get_user_product_preferences();
	
	// Retrieve whether we should use the preferences for ranking, or only for displaying the products
	
	var use_user_product_preferences_for_ranking = JSON.parse(localStorage.getItem('use_user_product_preferences_for_ranking'));
	
	var ranked_products = rank_products(products, user_product_preferences, use_user_product_preferences_for_ranking);
	const user_prefs = {
		ranking: use_user_product_preferences_for_ranking,
		prefs: user_product_preferences,
	};
	display_products(target, ranked_products, user_prefs);
			
	$(document).foundation('equalizer', 'reflow');
}


/* exported search_products */

function search_products (target, products, search_api_url) {

	// Retrieve generic search results from the search API
	
	$.getJSON( search_api_url, function( data ) {
		
		if (data.products) {
			
			Array.prototype.push.apply(products, data.products);
			rank_and_display_products(target, products);
		}		
	});
}
