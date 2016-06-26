Once the code is working, the URL to be called should be:
http://fr.openfoodfacts.org/cgi/graph.pl?code=59032823

I) Addition of the following files
==================================

* cgi/graph.pl
* cgi/Graph.pm
* cgi/PointRepartition.pm
* cgi/Product.pm      # package Blogs::Product. I don't use the Blog::Products available in Product_opener. Check if not overlapping or maybe it is a kind of suplicate with Products
* cgi/Querier.pm
* cgi/DataEnv.pm      # DataEnvironment used for initializing Querier. Could possibly be removed when using the product-opener package for connecting , querying, filtering data
* README_FROM_ORIC_product_opener_graph_comparator.txt  # can be deleted

II) How to update the code
==========================

Some parts of the code need to be integrated in the product-opener. These parts are mentioned with:
* todo tag
* the following banner:

    # ################################
    # CHECK START
    # ################################

    <code to check and integrate into product-opener>

    # ################################
    # CHECK END
    # ################################


III) The todos
==============

* in Graph.pm: check the todos : product_url and product_image are partially hard-coded
    ** product_url: I am taking fr.off, maybe we should choose world??
    ** product_image: I saw there exists a image_front_url property in production, but unavailable in mongo-Database in the API (available in CSV format but not in Mongo Format)
    ** prepare_graph(): I used the $html variable from search.pl to build the page. However the syntax hasn't been checked, I mean that I am using "$Lang{...}" as an "eval" function, but not sure I use it correctly. Please check
    ** prepare_graph(): for outputting the html code, i used "${$request_ref->{content_ref}} .= $html;" from search.pl. Please update accordingly (not sure). $Lang and $request_ref are unknown in my code (packages missing??)
    
* in Querier.pm:
    ** you may want to use for connect() and disconnect() the API in product_opener instead (my code is hard-coded)
    
    ** fetch(): should use the field projection using the DataEnv object to reduce the number of fields retrieved for the selection of the products. However, I couldn't make the field projection work in Perl, so it retrieves all fields (not efficient)
    
    ** fetch(): uses also a limit of  products for a category (var $_tmp_nb_max) because the outputting of the Javascript Data structure is too big (limitation of print in Perl??) and the code crashes. Of course, remove it in test or set up a bigger limit: 400 ??)
    
* in Product.pm:
    ** calc_score_nutrition(): see the todo note in there: currently the score nutrition which is computed doesn't make the difference with waters, or country rating etc.
    
    