# Environmental cost (Ecobalyse) label rendered by nginx

This directory contains an [njs](https://nginx.org/en/docs/njs/) module that renders the French
"coût environnemental" label as SVG, directly in nginx, without calling Product Opener (Apache + mod_perl).

It runs on the [QuickJS engine](https://nginx.org/en/docs/njs/engine.html) of njs (`js_engine qjs`):
the original built-in njs engine is deprecated since njs 1.0.0. The code also runs unchanged on the
njs engine, with identical output.

```
/images/environmental-cost/v1/<cost for the product>-<cost for 100 g or 100 ml>-<g|ml>.svg
```

e.g. `https://static.openfoodfacts.org/images/environmental-cost/v1/360-154-g.svg`

- Both values are integers from 0 to 99999. Other URLs return a 404.
- The URL contains all the values, so the response never changes. It is sent with
  `Cache-Control: public, max-age=31536000, immutable`. The `v1` segment lets us change the design later.
- In Perl, the path is built by `ProductOpener::EnvironmentalImpact::get_environmental_cost_label_path()`.
  It is used as the icon of the `environmental_cost` knowledge panel.

## The label

The design is set by the official charter:
https://affichage-environnemental.ecobalyse.beta.gouv.fr/charte.pdf

- The label has a fixed size and layout. Only the 2 numbers change, and they are right-aligned.
- On screens, it is 80px high and must not be resized.
- The product cost uses Marianne ExtraBold and the cost for 100 g uses Marianne Medium.
  The text must be vectorized (outlined).
- The colours are `#000000`, with `#595959` for the box of the cost for 100 g.
- The charter only shows "pts/100g". We also generate "pts/100ml" for products sold by volume.
  That variant is not in the charter.

## Sources: the official generator (ecopass)

The site https://affichage-environnemental.ecobalyse.beta.gouv.fr/ (the official site where brands
declare products) is open source: https://github.com/incubateur-ademe/ecopass (MIT licence).

- Generator: [`src/utils/label/simple.ts`](https://github.com/incubateur-ademe/ecopass/blob/main/src/utils/label/simple.ts).
  It is a string template with the frame as 5 `<path>` elements, in a 154×77 viewBox.
  The 2 numbers are `<text>` elements, and an embedded Marianne Regular woff2 font is used for both.
- Grey box width: [`src/utils/label/size.ts`](https://github.com/incubateur-ademe/ecopass/blob/main/src/utils/label/size.ts),
  a lookup table based on the number of digits.
- API: `https://affichage-environnemental.ecobalyse.beta.gouv.fr/api/image?type=score&score=360&masse=0.234`

We reuse the frame and the positions of the official generator, with these differences:

| | ecopass | Open Food Facts |
|---|---|---|
| Numbers | `<text>` with an embedded Marianne Regular font (bold is synthesized by the browser) | outlined glyphs of Marianne ExtraBold and Medium, as required by the charter, with kerning |
| Thousands separator | U+202F, missing from the embedded font (rendered with a fallback font) | space of the Marianne font |
| Box of the cost for 100 g | width from a table based on the number of digits | width computed from the actual text width, with 4px padding (same result for "g") |
| Size | ~54 KB (~39 KB gzipped) | ~16 KB (~7 KB gzipped) |

## Files

- `environmental_cost_label.js`: the njs module.
  At load time, it pre-builds the glyph definitions and the frame as a Buffer.
  For each request, it lays out the digits right to left (advance widths and kerning).
  It then outputs `<defs>` with only the glyphs used, `<use>` elements, and the grey box.
- `environmental_cost_label_data.js`: **generated**, do not edit. It holds the frame, and the outlines,
  advance widths and kerning pairs of the digits and of the " pts/100g" and " pts/100ml" strings.
- `../conf.d/environmental_cost_label.conf`: `js_engine qjs`, `js_path` and `js_import` (http context).
- `../snippets/environmental-cost-label.include`: the `location` that calls the module. It is kept out of
  `productopener-server.include` so that servers without njs can still include that one. It must be
  included before `productopener-server.include`, whose generic `/images/` location would match first.
- `scripts/environmental_cost_label/generate_label_data.py`: generates `environmental_cost_label_data.js`.

To regenerate the data (e.g. to update the frame from a newer ecopass commit, after changing
`ECOPASS_COMMIT` in the script):

```bash
pip install fonttools brotli
python3 scripts/environmental_cost_label/generate_label_data.py
```

The script downloads the inputs from pinned URLs:
- the ecopass `simple.ts` for the frame
- Marianne Medium from the [DSFR](https://www.systeme-de-design.gouv.fr/) package `@gouvfr/dsfr`
- Marianne ExtraBold, which is not in the DSFR, from the ADEME project
  [nosgestesclimat-site](https://github.com/incubateur-ademe/nosgestesclimat-site)

Local files can be passed instead with `--extrabold`, `--medium` and `--ecopass-simple-ts`.
The font files are not stored in this repository, only the outlines of the characters needed for the label.

**Font licence**: Marianne is reserved for the French government ("dessiné pour l'usage exclusif du
gouvernement français"). The official ecopass generator embeds it in every label, and we only use the
outlines of the digits and of "pts/100g" / "pts/100ml" to draw the official label. This should
still be confirmed with the Ecobalyse team.

## Deployment

nginx needs the njs module, version 0.8.6 or later, built with QuickJS:
- Docker (`Dockerfile.frontend`, based on `nginx:stable`, which ships the `nginx-module-njs` package,
  njs 1.0.2 with nginx 1.30.6 in October 2026). `load_module modules/ngx_http_js_module.so;` is added
  to `/etc/nginx/nginx.conf` when building the image. `docker-compose.yml` mounts
  `conf.d/environmental_cost_label.conf`, `snippets/environmental-cost-label.include`
  and this directory in `/etc/nginx/njs`. `conf/nginx-docker/nginx.conf` includes the snippet.
  **The frontend image must be rebuilt**: an older image without the module fails to start with
  `unknown directive "js_engine"`.
- Without Docker (e.g. the openfoodfacts.org production server, `conf/nginx/sites-available/off`):
  the label is not enabled yet. The server runs nginx 1.18.0, which has no njs module with QuickJS.
  To enable it:
  1. Upgrade nginx to a current version from the [nginx.org packages](https://nginx.org/en/linux_packages.html),
     with the `nginx-module-njs` package.
  2. Load the module (`load_module modules/ngx_http_js_module.so;` in the main context of `nginx.conf`).
  3. Link `conf.d/environmental_cost_label.conf` in `/etc/nginx/conf.d/` and this directory to `/etc/nginx/njs`.
  4. Add `include snippets/environmental-cost-label.include;` before
     `include snippets/productopener-server.include;` in the server block.
  5. Check with `nginx -t` before reloading.

## Performance benchmark

Measured in October 2026 with `ab` (keep-alive, 50 concurrent connections, 60,000 requests per variant).
nginx ran in Docker, limited to **1 CPU core and 1 worker process**. The comparison is nginx serving
the same kind of SVG as a static file.

Prototypes (straight ports of the ecopass generator, with the embedded font):

| Variant | Size (gzipped) | Requests / s | Median / p99 latency under load |
|---|---|---|---|
| Static file (upper bound) | 54 KB (39 KB) | 13,400 | 3 / 10 ms |
| Port of ecopass, one big string per request | 54 KB | 2,000 | 22 / 48 ms |
| Port of ecopass, static parts pre-built as Buffers | 54 KB (39 KB) | 4,300 - 4,800 | 10 / 22 ms |

Building one large string per request is what costs the most: the static parts (frame) are therefore
pre-encoded once as a Buffer, and only the small dynamic part is built for each request.

Current implementation (outlined digits, pre-built Buffers):

| Variant | Size (gzipped) | Requests / s | Median / p99 latency under load |
|---|---|---|---|
| Static file (upper bound) | 54 KB | 14,500 - 15,800 | 3 / 10 ms |
| `360-154-g.svg` | 17 KB (7 KB) | 6,100 - 6,600 | 7 / 16-23 ms |
| `99999-12345-g.svg` | 17.5 KB (7 KB) | 5,400 - 5,900 | 8 / 17-22 ms |
| `360-154-g.svg` with gzip | 7 KB | 5,600 | |

njs engine vs QuickJS engine (same code, same conditions, nginx 1.30.6 with njs 1.0.2, 2 rounds):

| Engine | `360-154-g.svg` | `99999-12345-g.svg` | Single request |
|---|---|---|---|
| njs (deprecated) | 6,600 - 7,000 req/s | 6,200 - 6,900 req/s | 0.54 ms |
| QuickJS | 6,200 - 8,800 req/s | 6,000 - 6,900 req/s | 0.52 ms |

The two engines perform the same, within the run-to-run variation, and both use under 6 MB of memory.

- **About 0.15 - 0.2 ms of CPU per label.** A single request (one client, no keep-alive) takes 0.44 ms end to end.
- Throughput scales with the number of nginx workers (one per core).
- Memory: the whole nginx container used under 6 MB.
- Since the URLs are immutable, browsers and CDNs cache each label: it is generated at most once per client.

These numbers are well above the traffic of the knowledge panels, and Apache + mod_perl is not involved.
