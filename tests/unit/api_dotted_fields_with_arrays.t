    #!/usr/bin/perl -w
    
    use strict;
    use warnings;
    use utf8;
    
    use Test::More;
    
    use ProductOpener::API qw(customize_response_for_product);
    
    my $product_ref = {
    schema_version => 1002,
    packagings => [
        {
            material => 'en:glass',
            recycling => {
                instructions => 'rinse and sort',
            },
        },
        {
            material => 'en:paper',
        },
    ],
    images => {
        selected => {
            front => {
                display => {
                    en => 'https://static.example.org/front.jpg',
                },
            },
        },
    },
    };
    
    my $customized_product_ref;
    my $error;
    
    eval {
    $customized_product_ref = customize_response_for_product(
        { api_version => '3.3' },
        $product_ref,
        'packagings.0.recycling.instructions,images.selected.front.display.en'
    );
    1;
    } or $error = $@;
    
    ok(!$error, 'resolving dotted field paths with arrays does not crash');
    
    is(
    $customized_product_ref->{packagings}[0]{recycling}{instructions},
    'rinse and sort',
    'returns the expected value for a dotted field path crossing an array index',
    );
    
    is(
    $customized_product_ref->{images}{selected}{front}{display}{en},
    'https://static.example.org/front.jpg',
    'returns the expected value for a dotted field path without arrays',
    );
    
    done_testing();
