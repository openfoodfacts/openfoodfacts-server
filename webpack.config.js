var webpack = require('webpack');
const ExtractCssChunks = require('extract-css-chunks-webpack-plugin');

const config = {
  entry: {
    babel: ['@babel/polyfill'],
    search: './html/js/src/search.js',
    display: './html/js/src/display.js',
    display_map: './html/js/src/display_map.js',
    display_tag: './html/js/src/display_tag.js',
    top_translators: './html/js/src/top_translators.js',
    madenearyou: './html/js/src/madenearyou.js',
    images: './html/js/src/images.js',
    product: './html/js/src/product.js',
    users: './html/js/src/users.js',
  },
  output: {
    filename: '[name].js',
    path: __dirname + '/html/dist',
    publicPath: '/dist/'
  },
  devtool: 'source-map',
  module: {
    rules: [
      {
        test: /\.css$/,
        use: [{
          loader: ExtractCssChunks.loader
        },
        'css-loader']
      },
      {
        test: /\.scss$/,
        use: [{
          loader: ExtractCssChunks.loader
        },
        'css-loader', 'sass-loader']
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
      {
        test: /\.m?js$/,
        exclude: /(node_modules|bower_components)/,
        use: {
          loader: 'babel-loader',
          options: {
            presets: ['@babel/preset-env']
          }
        }
      }
    ]
  },
  plugins: [
    new webpack.ProvidePlugin({
      $: 'jquery',
      jQuery: 'jquery'
    }),
    new ExtractCssChunks({
      filename: '[name].css',
      chunkFilename: '[id].css',
      orderWarning: true, // Disable to remove warnings about conflicting order between imports
    }),
  ],
  resolve: {
    extensions: ['.js'],
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
