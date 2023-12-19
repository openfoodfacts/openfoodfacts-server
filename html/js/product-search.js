/*global lang */

// match_product_to_preference checks if a product matches
// a given set of preferences and scores the product according to
// the preferences
//
// The product object must contain the attribute_groups field
//
// Output values are returned in the product object
//
// - match_score: number from 0 to 100
//		- the score is 0 if 
//		- otherwise the score is a weighted average of how well the product matches
//		each attribute selected by the user
//
// - match_status:
// 		- very_good_match	score >= 75
//		- good_match		score >= 50
//		- poor_match		score < 50
//		- unknown_match		at least one mandatory attribute is unknown, or unknown attributes weight more than 50% of the score
//		- may_not_match		at least one mandatory attribute score is <= 50 (e.g. may contain traces of an allergen)
//		- does_not_match	at least one mandatory attribute score is <= 10 (e.g. contains an allergen, is not vegan)
//
// - match_attributes: array of arrays of attributes corresponding to the product and 
// each set of preferences: mandatory, very_important, important

function match_product_to_preferences(product, product_preferences) {

	let score = 0;
	let debug = "";

	product.match_attributes = {
		"mandatory": [],
		"very_important": [],
		"important": []
	};

	// Note: it is important that mandatory attributes also contribute to the score
	// as some attributes like "low sugar" have scores from 0 to 100 that can still
	// be very useful to rank products by how much sugar they contain.
	// It is also needed in order not to have scores of 0 when only mandatory attributes
	// are selected.
	const preferences_factors = {
		"mandatory": 2,
		"very_important": 2,
		"important": 1,
		"not_important": 0
	};

	let sum_of_factors = 0;
	let sum_of_factors_for_unknown_attributes = 0;

	if (product.attribute_groups) {

		product.attributes_for_status = {};

		// Iterate over attribute groups
		$.each(product.attribute_groups, function (key, attribute_group) {

			// Iterate over attributes

			$.each(attribute_group.attributes, function (key, attribute) {

				const attribute_preference = product_preferences[attribute.id];
				let match_status_for_attribute = "match";

				if ((!attribute_preference) || (attribute_preference === "not_important")) {
					// Ignore attribute
					debug += attribute.id + " not_important" + "\n";
				}
				else {

					const attribute_factor = preferences_factors[attribute_preference];
					sum_of_factors += attribute_factor;

					if (attribute.status === "unknown") {

						sum_of_factors_for_unknown_attributes += attribute_factor;

						// If the attribute is mandatory and the attribute status is unknown
						// then mark the product status unknown

						if (attribute_preference === "mandatory") {
							match_status_for_attribute = "unknown_match";
						}
					}
					else {
						debug += attribute.id + " " + attribute_preference + " - match: " + attribute.match + "\n";
						score += attribute.match * attribute_factor;

						if (attribute_preference === "mandatory") {
							if (attribute.match <= 10) {
								// Mandatory attribute with a very bad score (e.g. contains an allergen) -> status: does not match
								match_status_for_attribute = "does_not_match";
							}
							// Mandatory attribute with a bad score (e.g. may contain traces of an allergen) -> status: may not match
							else if (attribute.match <= 50) {
								match_status_for_attribute = "may_not_match";
							}
						}
					}

					if (!(match_status_for_attribute in product.attributes_for_status)) {
						product.attributes_for_status[match_status_for_attribute] = [];
					}
					product.attributes_for_status[match_status_for_attribute].push(attribute);

					product.match_attributes[attribute_preference].push(attribute);
				}
			});
		});

		// Normalize the score from 0 to 100
		if (sum_of_factors === 0) {
			score = 0;
		} else {
			score /= sum_of_factors;
		}

		// If one of the attributes does not match, the product does not match
		if ("does_not_match" in product.attributes_for_status) {
			// Set score to 0 for products that do not match
			score = "0";
			product.match_status = "does_not_match";
		}
		else if ("may_not_match" in product.attributes_for_status) {
			product.match_status = "may_not_match";
		}
		// If one of the mandatory attribute is unknown, set an unknown match
		else if ("unknown_match" in product.attributes_for_status) {
			product.match_status = "unknown_match";
		}
		// If too many attributes are unknown, set an unknown match
		else if (sum_of_factors_for_unknown_attributes >= sum_of_factors / 2) {
			product.match_status = "unknown_match";
		}
		// If the product matches, check how well it matches user preferences
		else if (score >= 75) {
			product.match_status = "very_good_match";
		}
		else if (score >= 50) {
			product.match_status = "good_match";
		}
		else {
			product.match_status = "poor_match";
		}
	}
	else {
		// the product does not have the attribute_groups field
		product.match_status = "unknown_match";
		debug = "no attribute_groups";
	}

	product.match_score = score;
	product.match_debug = debug;
}


// rank_products (products, product_preferences)

// keep the initial order of each result
let initial_order = 0;

// option to enable tabs in results to filter on product match status
const show_tabs_to_filter_by_match_status = 0;

function rank_products(products, product_preferences, use_user_product_preferences_for_ranking) {

	// Score all products

	$.each(products, function (key, product) {

		if (!product.initial_order) {
			product.initial_order = initial_order;
			initial_order += 1;
		}

		match_product_to_preferences(product, product_preferences);
	});

	// If we don't use the user preferences for ranking, we show products in the initial order

	if (use_user_product_preferences_for_ranking) {

		// Rank all products

		products.sort(function (a, b) {
			return (b.match_score - a.match_score)  // Highest score first
				|| ((b.match_status === "does_not_match" ? 0 : 1) - (a.match_status === "does_not_match" ? 0 : 1)) // Matching products second
				|| (a.initial_order - b.initial_order); // Initial order third
		});
	}
	else {
		products.sort(function (a, b) {
			return (a.initial_order - b.initial_order);
		});
	}

	const product_groups = {
		"all": [],
	};

	$.each(products, function (key, product) {

		if (show_tabs_to_filter_by_match_status && use_user_product_preferences_for_ranking) {
			if (!(product.match_status in product_groups)) {
				product_groups[product.match_status] = [];
			}
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

	if (user_prefs.use_ranking) {
		$(target).html('<ul id="products_tabs_titles" class="tabs" data-tab></ul>' +
			'<div id="products_tabs_content" class="tabs-content"></div>');
	} else {
		$(target).html('<div id="products_tabs_content" class="tabs-content"></div>');
	}

	$.each(product_groups, function (product_group_id, product_group) {

		const products_html = [];

		$.each(product_group, function (key, product) {

			let product_html = `<li><a href="${product.url}" class="list_product_a">`;

			// Add a colored banner to show how the product matches the user's preferences
			if (user_prefs.use_ranking) {
				product_html += `<div class="list_product_banner list_product_banner_${product.match_status}">`
					+ lang()["products_match_" + product.match_status] + ' ' + Math.round(product.match_score) + '%</div>';
			}

			product_html += '<div class="list_product_content">';
			product_html += '<div class="list_product_img_div">';

			if (product.image_front_small_url) {
				product_html += `<img src="${product.image_front_small_url}" class="list_product_img">`;
			}
			else {
				product_html += `<img src="/images/icons/dist/packaging.svg" style="filter:invert(.9)" class="list_product_img">`;
			}

			product_html += "</div>";

			if (product.product_display_name) {
				product_html += '<div class="list_product_name v-space-tiny">' + product.product_display_name + "</div>";
			} else {
				product_html += '<div class="list_product_name v-space-tiny">' + product.code + "</div>";
			}

			product_html += '<div class="list_product_sc">';
			$.each(product.match_attributes.mandatory.concat(product.match_attributes.very_important, product.match_attributes.important), function (key, attribute) {

				if (attribute.icon_url) {
					let title = attribute.title;

					if (attribute.description_short) {
						title += ' - ' + attribute.description_short;
					}

					if (attribute.missing) {
						title += " - " + attribute.missing;
					}

					product_html += '<img class="list_product_icons" src="' + attribute.icon_url + '" title="' + title + '">';
				}
			});
			product_html += '</div>';
			// add some specific fields
			if (user_prefs.display.display_barcode) {
				product_html += `<span class="list_display_barcode">${product.code}</span>`;
			}

			product_html += "</div>";

			if (user_prefs.display.edit_link) {
				const edit_url = product_edit_url(product);
				const edit_title = lang().edit_product_page;
				product_html += `
				<a class="list_edit_link" 
				    alt="Edit ${product.product_display_name}" 
				    href="${edit_url}"
				    title="${edit_title}">
					<img src="/images/icons/dist/edit.svg">
				</a>
				`;
			}

			product_html += "</a></li>";

			products_html.push(product_html);
		});

		let active = "";
		let text_or_icon = "";
		if (product_group_id === "all") {
			active = " active";
		}

		if (show_tabs_to_filter_by_match_status) {
			if (product_group_id === "all") {
				if (product_group.length === 1) {
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

			if (user_prefs.use_ranking) {
				$("#products_tabs_titles").append(
					'<li class="tabs tab-title tab_products-title' + active + '">'
					+ '<a  id="tab_products_' + product_group_id + '" href="#products_' + product_group_id + '" title="' + lang()["products_match_" + product_group_id] + '">'
					+ text_or_icon
					+ "</a></li>"
				);
			}
		}

		$("#products_tabs_content").append(
			'<div class="tabs content' + active + '" id="products_' + product_group_id + '">'
			+ '<ul class="search_results small-block-grid-1 medium-block-grid-4 large-block-grid-6 xlarge-block-grid-8 xxlarge-block-grid-10" id="products_match_' + product_group_id + '" style="list-style:none">'
			+ products_html.join("")
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

	const user_prefs = get_user_preferences();

	match_product_to_preferences(product, user_prefs.product);

	// Show the green / grey / colors for matching products only if we are using the user preferences

	$("#prodHead").removeClass("product_banner_unranked product_banner_does_not_match product_banner_may_not_match product_banner_unknown_match product_banner_poor_match product_banner_good_match product_banner_very_good_match");
	$("#prodNav").removeClass("product_banner_unranked product_banner_does_not_match product_banner_may_not_match product_banner_unknown_match product_banner_poor_match product_banner_good_match product_banner_very_good_match");

	if (user_prefs.use_ranking) {

		const match_status_html = `<div class="match_status match_status_${product.match_status}">`
			+ `<div class="match_score match_score_${product.match_status}">` + Math.round(product.match_score) + '%</div>'
			+ '<span style="padding-left:0.5rem;padding-right:1rem;">' + lang()["products_match_" + product.match_status] + '</span></div>';

		$("#match_score_and_status").html(match_status_html);

		$("#prodHead").addClass("product_banner_" + product.match_status);
		$("#prodNav").addClass("product_banner_" + product.match_status);

		$("#prodBanner").html(lang()["products_match_" + product.match_status] + ' ' + Math.round(product.match_score) + '%');
		$("#prodBanner").removeClass();
		$("#prodBanner").addClass(`list_product_banner_${product.match_status}`);
		$("#prodBanner").show();
	}
	else {
		$("#prodHead").addClass("product_banner_unranked");
		$("#prodNav").addClass("product_banner_unranked");
		$("#prodBanner").hide();
		$("#match_score_and_status").html('');
	}

	let attributes_html = '';

	$.each(product.match_attributes.mandatory.concat(product.match_attributes.very_important, product.match_attributes.important), function (key, attribute) {

		// vary the color from green to red
		let grade = "unknown";

		if (attribute.status == "known") {
			grade = attribute.grade;
		}

		// card_html will be either a <div> or a <a> element, depending on whether it is linked to a knowledge panel
		let card_html = 'class="attribute_card grade_' + grade + '">' +
			'<div><div class="attr_card_header">' +
			'<div class="img_attr"><img src="' + attribute.icon_url + '" style="height:72px;float:right;margin-left:0.5rem;"></div>' +
			'<div class="attr_text"><h4 class="grade_' + grade + '_title attr_title">' + attribute.title + '</h4>';

		if (attribute.description_short) {
			card_html += '<span>' + attribute.description_short + '</span>';
		}

		if (attribute.missing) {
			card_html += "<p class='attribute_missing'>" + attribute.missing + "</p>";
		}
		card_html += "</div></div></div>";
		// check if the product attribute has an associated knowledge panel that exists
		if (attribute.panel_id) {
			// note: on the website, the id for the panel contains : instead of - (e.g. for the ingredients_analysis_en:vegan panel)
			const panel_element_id = 'panel_' + attribute.panel_id.replace(':', '-');
			if (document.getElementById(panel_element_id)) {
				// onclick : open the panel content + reflow to make sur all column content is shown			
				card_html = '<a href="#' + panel_element_id
					+ '" onclick="document.getElementById(\'' + panel_element_id + '_content\').classList.add(\'active\'); $(document).foundation(\'equalizer\', \'reflow\');"' + card_html + '</a>';
			}
			else {
				card_html = '<div ' + card_html + '</div>';
			}
		}
		else {
			card_html = '<div ' + card_html + '</div>';
		}

		attributes_html += '<li>' + card_html + '</li>';
	});

	$(target).html('<ul id="attributes_grid" class="small-block-grid-1 medium-block-grid-2 large-block-grid-3">' + attributes_html + '</ul>');

	$(document).foundation('equalizer', 'reflow');
}


// Retrieve user preferences from local storage

function get_user_preferences(contributor_prefs) {

	return {
		// Retrieve whether we should use the preferences for scoring and ranking, or only for displaying the attributes of the products
		use_ranking: JSON.parse(localStorage.getItem('use_user_product_preferences_for_ranking')),
		// Product preferences
		product: get_user_product_preferences(),
		display: contributor_prefs,
	};
}

function rank_and_display_products(target, products, contributor_prefs) {

	const user_prefs = get_user_preferences(contributor_prefs);


	const ranked_products = rank_products(products, user_prefs.product, user_prefs.use_ranking);
	display_products(target, ranked_products, user_prefs);

	$(document).foundation('equalizer', 'reflow');
}

/* exported search_products */

function search_products(target, products, search_api_url) {

	// Retrieve generic search results from the search API

	$.getJSON(search_api_url, function (data) {

		if (data.products) {

			Array.prototype.push.apply(products, data.products);
			rank_and_display_products(target, products);
		}
	});
}