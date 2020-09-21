
// Retrieve user preferences from local storage

var user_product_preferences = {};
var user_product_preferences_string = localStorage.getItem('user_product_preferences');

if (user_product_preferences_string) {
	user_product_preferences = JSON.parse(user_product_preferences_string);
}

var products;


function rank_and_filter_products() {
	
	// TODO
	
}


function show_products(target) {
	
	var products_html = [];
	
	$.each( products, function(key, product) {
	
		var product_html = "<li>";
		
		product_html += '<a href="' + product.url + '"><div>';
		
		if (product.image_front_thumb_url) {
			product_html += '<img src="' + product.image_front_thumb_url + '">';
		}
		
		product_html += "</div>";
		
		product_html += "<span>" + product.product_name + "</span>";
		
		product_html += '</a>';
		
		product_html += "</li>";
			
		products_html.push(product_html);		
	});
	
	$( "<ul/>", {
		"class": "products search_results",
		html: products_html.join( "" )
	}).replaceAll(target);	
}


function search_products (target, search_api_url) {

	// Retrieve generic search results from the search API
	
	$.getJSON( search_api_url, function( data ) {
		
		if (data.products) {
			
			products = data.products;
			
			rank_and_filter_products();
			
			show_products(target);
			
			$(document).foundation('equalizer', 'reflow');
		}		
	});
}
