const path = require('path');

module.exports = {
    entry: './src/index.js',
    output: {
        path: path.resolve(__dirname, 'dist'),
        filename: 'bundle.js',
    },
    optimization: {
        minimize: true,
    },
    resolve: {
        fallback: {
            fs: false
        }
    },
    mode: "production",
};
