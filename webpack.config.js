var webpack = require('webpack');

const config = {
    entry: {
        search: './html/js/src/search.js',
        display: './html/js/src/display.js',
        display_map: './html/js/src/display_map.js',
        display_tag: './html/js/src/display_tag.js',
        top_translators: './html/js/src/top_translators.js',
        madenearyou: './html/js/src/madenearyou.js',
        images: './html/js/src/images.js',
        product: './html/js/src/product.js',
    },
    output: {
        filename: '[name].js',
        path: __dirname + '/html/js/dist',
        publicPath: '/js/dist/'
    },
    module: {
        rules: [
            {
                test: /\.css$/,
                use: ['style-loader', 'css-loader']
            },
            {
                test: /\.scss$/,
                use: ['style-loader', 'css-loader', 'sass-loader' ]
            },
            {
                test: /\.(gif|png|jpe?g|svg)$/i,
                use: [
                    'file-loader',
                    {
                        loader: 'image-webpack-loader',
                        options: {
                            bypassOnDebug: true,
                        },
                    },
                ],
            },
            {
                test: /\.(ttf|eot|woff|woff2)$/,
                loader: 'file-loader'
            },
        ]
    },
    plugins: [
        new webpack.ProvidePlugin({
            $: 'jquery',
            jQuery: 'jquery'
          })
    ],
    resolve: {
        extensions: ['.js' ],
        alias: {
           'load-image': 'blueimp-load-image/js/load-image.js',
           'load-image-meta': 'blueimp-load-image/js/load-image-meta.js',
           'load-image-exif': 'blueimp-load-image/js/load-image-exif.js',
           'load-image-scale': 'blueimp-load-image/js/load-image-scale.js',
           'canvas-to-blob': 'blueimp-canvas-to-blob/js/canvas-to-blob.js',
        }
     },
     optimization: {
        splitChunks: {
            chunks: 'all'
        }
     }
};

module.exports = config;