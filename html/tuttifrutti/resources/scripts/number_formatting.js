/**
 * Created by Olivier Richard (oric.dev@iznogoud.neomailbox.ch) on 19/10/18.
 * Following script is fully copied from:
 *  https://stackoverflow.com/questions/16637051/adding-space-between-numbers
 *  .. and it works super!
 */

/*
 For integers use
 */
function numberWithSpacesIntegers(x) {
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

/*
For floating point numbers you can use
 */
function numberWithSpacesFloats(x) {
    var parts = x.toString().split(".");
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, " ");
    return parts.join(".");
}