// Renders the French "coût environnemental" (Ecobalyse) label as SVG, directly in nginx.
//
// URL: /images/environmental-cost/v1/<cost for the product>-<cost for 100 g or 100 ml>-<g|ml>.svg
// e.g. /images/environmental-cost/v1/360-154-g.svg
//
// Runs on the QuickJS engine of njs (js_engine qjs), see conf/nginx/conf.d/environmental_cost_label.conf
// See README.md in this directory for the design, the sources and the benchmark.

import D from 'environmental_cost_label_data.js';

const WIDTH = 154;
const HEIGHT = 77;
// Positions from the official generator (ecopass src/utils/label/simple.ts)
const BIG_RIGHT = 146;
const BIG_BASELINE = 41.375;
const SMALL_RIGHT = 140;
const SMALL_BASELINE = 64.9375;
const BOX_Y = 55;
const BOX_HEIGHT = 14;
const BOX_PADDING = 4;

// Glyph definitions (in font units, scaled and flipped), built once when nginx loads the module
function glyph_defs(prefix, font) {
	const scale = (font.size / font.upm).toFixed(6);
	const defs = {};
	for (const char in font.d) {
		defs[char] = `<path id="${prefix}${char}" transform="scale(${scale} -${scale})" d="${font.d[char]}"/>`;
	}
	return defs;
}

const BIG_DEFS = glyph_defs('b', D.big);
const SMALL_DEFS = glyph_defs('s', D.small);
const SMALL_SCALE = D.small.size / D.small.upm;
const UNITS = {};
for (const unit in D.small.units) {
	const u = D.small.units[unit];
	UNITS[unit] = {
		width: u.adv * SMALL_SCALE,
		def: `<path id="u${unit}" transform="scale(${SMALL_SCALE.toFixed(6)} -${SMALL_SCALE.toFixed(6)})" d="${u.d}"/>`,
	};
}

// The fixed part of the label: pre-encoded once, sent as is for each request
const FRAME = Buffer.from(D.frame);

// 12345 -> "12 345"
function format(value) {
	return String(value).replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
}

// Lay out a right-aligned string of digits and spaces.
// Returns the <use> elements, the glyphs used and the width of the string.
function run(font, prefix, string, right, baseline) {
	const scale = font.size / font.upm;
	let width = 0;
	for (let i = 0; i < string.length; i++) {
		width += font.adv[string[i]] + (i > 0 ? font.kern[string[i - 1] + string[i]] || 0 : 0);
	}
	let x = right - width * scale;
	let uses = '';
	const used = {};
	for (let i = 0; i < string.length; i++) {
		const char = string[i];
		if (i > 0) {
			x += (font.kern[string[i - 1] + char] || 0) * scale;
		}
		if (char !== ' ') {
			uses += `<use href="#${prefix}${char}" x="${x.toFixed(2)}" y="${baseline}"/>`;
			used[char] = true;
		}
		x += font.adv[char] * scale;
	}
	return {uses, used, width: width * scale};
}

function label(r) {
	const m = r.uri.match(/\/(0|[1-9]\d{0,4})-(0|[1-9]\d{0,4})-(g|ml)\.svg$/);
	if (!m) {
		r.return(404);
		return;
	}
	const product = m[1];
	const per_100 = m[2];
	const unit = UNITS[m[3]];

	const big = run(D.big, 'b', format(product), BIG_RIGHT, BIG_BASELINE);
	// the unit (" pts/100g") is drawn right-aligned, the number on its left
	const small = run(D.small, 's', format(per_100), SMALL_RIGHT - unit.width, SMALL_BASELINE);
	const box_x = SMALL_RIGHT - unit.width - small.width - BOX_PADDING;

	let defs = unit.def;
	for (const char in big.used) {
		defs += BIG_DEFS[char];
	}
	for (const char in small.used) {
		defs += SMALL_DEFS[char];
	}

	const title = `Coût environnemental : ${product} points d'impact, ${per_100} pour 100${m[3]}`;
	const head = `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}" fill="none" role="img" aria-label="${title}"><title>${title}</title><defs>${defs}</defs><g>`;
	const tail = `<rect x="${box_x.toFixed(2)}" y="${BOX_Y}" width="${(SMALL_RIGHT + BOX_PADDING - box_x).toFixed(2)}" height="${BOX_HEIGHT}" rx="3" fill="#595959"/>`
		+ `<g fill="#fff">${small.uses}<use href="#u${m[3]}" x="${(SMALL_RIGHT - unit.width).toFixed(2)}" y="${SMALL_BASELINE}"/></g>`
		+ `<g fill="#000">${big.uses}</g></g></svg>`;

	r.status = 200;
	r.headersOut['Content-Type'] = 'image/svg+xml';
	r.headersOut['Cache-Control'] = 'public, max-age=31536000, immutable';
	r.headersOut['Content-Length'] = Buffer.byteLength(head) + FRAME.length + Buffer.byteLength(tail);
	r.sendHeader();
	r.send(head);
	r.send(FRAME);
	r.send(tail);
	r.finish();
}

export default {label};
