import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import {createServer} from "node:http";
import {join, resolve} from "node:path";
import {after, before} from "node:test";
import {fileURLToPath} from "node:url";

import {chromium} from "playwright";
import {compile} from "sass";

const root = fileURLToPath(new URL("../../", import.meta.url));

// Each test file gets an isolated browser and a loopback-only fixture server.
// The source override lets us run the same tests against pre-fix JS and SCSS.
export function installTagifyFixture() {
    let browser;
    let server;
    let origin;

    before(async () => {
        const sourceRoot = resolve(root, process.env.TAGIFY_TEST_SOURCE_DIR || ".");
        const css = compile(join(sourceRoot, "scss/_tagify.scss"), {
            loadPaths: [join(root, "node_modules")],
            silenceDeprecations: ["import", "global-builtin", "color-functions"]
        }).css;
        const assets = new Map([
            ["/", ["text/html", readFileSync(new URL("fixtures/tagify.html", import.meta.url))]],
            ["/tagify.css", ["text/css", css]],
            ["/tagify.js", ["text/javascript", readFileSync(join(root, "node_modules/@yaireo/tagify/dist/tagify.js"))]],
            ["/tagify-init.js", ["text/javascript", readFileSync(join(sourceRoot, "html/js/tagify-init.js"))]]
        ]);
        server = createServer((request, response) => {
            const asset = assets.get(new URL(request.url, "http://localhost").pathname);
            if (!asset) {
                response.writeHead(404);
                response.end();
                return;
            }
            response.writeHead(200, {"Content-Type": asset[0], "Cache-Control": "no-store"});
            response.end(asset[1]);
        });
        await new Promise((resolve, reject) => {
            server.once("error", reject);
            server.listen(0, "127.0.0.1", resolve);
        });
        origin = `http://127.0.0.1:${server.address().port}`;
        browser = await chromium.launch();
    });

    after(async () => {
        await browser?.close();
        if (server) {
            await new Promise((resolve, reject) => {
                server.close((error) => error ? reject(error) : resolve());
            });
        }
    });

    return async function createPage(t, {visible = false, position = 2, direction = "ltr", width = 600, viewportWidth = 1024} = {}) {
        const context = await browser.newContext({viewport: {width: viewportWidth, height: 600}});
        const page = await context.newPage();
        page.setDefaultTimeout(10000);
        const errors = [];
        page.on("pageerror", (error) => errors.push(error.message));
        t.after(async () => {
            await context.close();
            assert.deepEqual(errors, [], "the component must not throw browser errors");
        });
        await page.goto(`${origin}/?direction=${direction}&width=${width}`);
        await page.waitForFunction(() => window.tagify?.value.length === 2);
        // Set up the initial position independently of arrow handling, so order
        // and layout regressions can fail independently of the navigation test.
        await page.evaluate((index) => {
            const {tagify} = window;
            tagify.DOM.scope.insertBefore(tagify.DOM.input, tagify.getTagElms()[index] || null);
        }, position);
        await page.locator(".tagify__input").focus();
        await setCaret(page, 0);
        await setSuggestions(page, visible);
        return page;
    };
}

export async function setSuggestions(page, visible) {
    await page.evaluate((show) => {
        if (show) {
            // Supply deterministic local suggestions after typing clears the
            // whitelist; these tests do not need a remote autocomplete service.
            window.tagify.whitelist = JSON.parse(localStorage.getItem("po_last_tags")).categories;
            window.tagify.dropdown.show();
        } else {
            window.tagify.dropdown.hide();
        }
    }, visible);
    await page.waitForFunction((show) => Boolean(window.tagify.state.dropdown.visible) === show, visible);
    await page.locator(".tagify__dropdown").waitFor({state: visible ? "visible" : "hidden"});
}

export async function setCaret(page, offset) {
    await page.evaluate((position) => {
        const editable = window.tagify.DOM.input;
        const range = document.createRange();
        range.setStart(editable.firstChild || editable, position);
        range.collapse(true);
        const selection = window.getSelection();
        selection.removeAllRanges();
        selection.addRange(range);
    }, offset);
}

export async function getState(page) {
    return page.evaluate(() => {
        const {tagify} = window;
        return {
            order: Array.from(tagify.DOM.scope.children, (element) => element === tagify.DOM.input ? "[input]" : element.getAttribute("value")),
            values: tagify.value.map((tag) => tag.value),
            suggestionsVisible: Boolean(tagify.state.dropdown.visible),
            text: tagify.DOM.input.textContent,
            caret: window.getSelection().anchorOffset,
            focused: document.activeElement === tagify.DOM.input
        };
    });
}

export async function getSubmittedValues(page, count) {
    // Tagify debounces updating the original form field. Wait for the update,
    // not for the expected order, so an incorrectly appended value still fails.
    await page.waitForFunction((length) => {
        const value = new FormData(document.getElementById("product-form")).get("categories");
        // The original CSV value can still be present during initialization.
        try {
            return value && JSON.parse(value).length === length;
        } catch {
            return false;
        }
    }, count);
    return page.evaluate(() => {
        const value = new FormData(document.getElementById("product-form")).get("categories");
        return JSON.parse(value).map((tag) => tag.value);
    });
}
