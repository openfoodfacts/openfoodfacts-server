<p>
    <h1 align="center">
        <a href="//steverichey.github.io/google-play-badge-svg">
            google-play-badge-svg
        </a>
    </h1>
</p>

<p align="center">
    <a href="https://travis-ci.org/steverichey/google-play-badge-svg">
        <img src="https://travis-ci.org/steverichey/google-play-badge-svg.svg?branch=master" alt="Build status">
    </a>
    <a href="./license.md">
        <img src="https://img.shields.io/badge/License-MIT-lightgrey.svg" alt="License: MIT">
    </a>
</p>

<p align="center">
    <a href="#about">About</a>
  • <a href="#usage">Usage</a>
  • <a href="#available-badges">Available badges</a>
  • <a href="#notes">Notes</a>
  • <a href="#license">License</a>
</p>

Hosting for localized versions of Google Play™ badges in SVG format.

## About

It's possible to use [Apple's linkmaker](https://linkmaker.itunes.apple.com/us/) service to generate localized "Download on the App Store" SVG badges for your application. However, no similar service exists for Google's "Get it on Google Play" badges. This repository serves as hosting for Google's badges in SVG format.

## Usage

You should probably use a service like [RawGit](https://rawgit.com/) if you're going to use these images for anything much more than development. Just grab the URL of the file you want and pop it in here. Here's an image from this repo served up via RawGit.

<p align="center">
<img src="https://cdn.rawgit.com/steverichey/google-play-badge-svg/master/img/fr_get.svg" width="50%">
</p>

It's that easy! With a little JavaScript to check for locale (check `navigator.language || navigator.browserLanguage`) you can then load language-specific versions of the badge. I'd like to make this easier by making this available as a Node module, so keep an eye on this space if that sounds cool.

Let me know if you have any questions, suggestions, or comments!

## Available badges

To view the list of available badges, please see [this folder](https://github.com/steverichey/google-play-badge-svg/tree/master/img) or view all of the images in one place [here](http://steverichey.github.io/google-play-badge-svg/all.html). If I've made an error somewhere or you'd like an additional language added, please [open an issue](https://github.com/steverichey/google-play-badge-svg/issues).

## Notes

Badges are labeled according to how Google sorts them, which is mostly using [ISO 639-1](https://en.wikipedia.org/wiki/List_of_ISO_639-1_codes) codes. For some languages with multiple dialects the sorting is a little different.

All SVGs use outlined text instead of embedded fonts.

Inclusion or omission of any language or dialect should not be misconstrued as support for any particular nationality, country, ideology, race, or similar. If there's a language in here, it's just because Google had it available or someone added it themselves. If a language is missing, it's just because Google did not have it available or I had issues with their file.

## License

Unless covered under some other license, all content in this repository is shared under an MIT license. See [license.md](./license.md) for details.

Google Play and the Google Play logo are trademarks of Google Inc. Be sure to read the [Branding Guidelines](https://developer.android.com/distribute/tools/promote/brand.html) and contact Google via the [Android and Google Play Brand Permissions Inquiry form](https://support.google.com/googleplay/contact/brand_developer) if you have any questions. SVGs in this repository were generated from files provided by Google [here](https://play.google.com/intl/en_us/badges/) and they have all the copyrights and trademarks and whatevs.
