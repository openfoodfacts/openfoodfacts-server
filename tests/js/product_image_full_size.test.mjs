import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const source = readFileSync(new URL("../../html/js/product-multilingual.js", import.meta.url), "utf8");

function encodeEntityText(value) {
    return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function initHarnessWithFieldUrl(imageUrls, labels) {
    const htmlBySelector = {};
    const documentListeners = {};

    function makeJqueryWrapper(selector) {
        return {
            0: {
                getBoundingClientRect() {
                    return { width: selector === "#nutrition_data_table" ? 400 : 900 };
                },
            },
            data() { return false; },
            each(callback) {
                if (Array.isArray(selector)) {
                    for (const item of selector) {
                        callback.call(item);
                    }
                }
                return this;
            },
            is() { return false; },
            isVisible() { return true; },
            click() { return this; },
            change() { return this; },
            on() { return this; },
            fileupload() { return this; },
            foundation() { return this; },
            prop() { return this; },
            css() { return this; },
            show() { return this; },
            hide() { return this; },
            find() { return this; },
            closest() { return this; },
            select2() { return this; },
            text(nextText) { return nextText === undefined ? "" : this; },
            attr(name) {
                if (name === "id" && selector && selector.id) {
                    return selector.id;
                }
                return "";
            },
            val() {
                if (typeof selector === "string") {
                    const match = selector.match(/^#(.+)_display_url$/);
                    if (match) {
                        return imageUrls[match[1]] || "";
                    }
                }
                return "1234567890123";
            },
            html(nextHtml) {
                if (nextHtml === undefined) {
                    return htmlBySelector[selector] || "";
                }
                htmlBySelector[selector] = nextHtml;
                return this;
            },
        };
    }

    function $(value) {
        if (typeof value === "function") {
            return makeJqueryWrapper("ready");
        }
        return makeJqueryWrapper(value);
    }
    $.fn = {};
    $.expr = { filters: { visible: () => true } };
    $.extend = (target, ...sources) => Object.assign(target, ...sources);
    $.cookie = () => undefined;
    $.removeCookie = () => undefined;

    const document = {
        addEventListener(type, listener) {
            documentListeners[type] = listener;
        },
        getElementById(id) {
            return {
                id,
                value: "",
                classList: { add() {}, remove() {} },
                addEventListener() {},
            };
        },
        querySelector() { return { lang: "en" }; },
        querySelectorAll() { return []; },
        createElement() {
            return {
                _text: "",
                set textContent(value) { this._text = encodeEntityText(value ?? ""); },
                get innerHTML() { return this._text; },
            };
        },
    };

    const context = {
        $,
        jQuery: $,
        document,
        window: { addEventListener() {}, location: { hostname: "world.openfoodfacts.org" } },
        FormData: function () {},
        URL,
        encodeURI,
        admin: false,
        other_nutrients: [],
        initializeTagifyInput() {},
        getTagsToCommit() { return []; },
        addTagsToRecentTags() {},
        trackMatomoEvent() {},
        lang() {
            return {
                product_js_current_image: "Current image:",
                image_full_size: "Full size",
                product_js_image_open_full_size_image: "Open the picture in original size in a new windows",
                product_js_unselect_image: "Unselect image",
                product_js_extract_ingredients: "Extract the ingredients from the picture",
                product_js_extract_packaging: "Extract the packaging information from the picture",
                ...labels,
            };
        },
        setTimeout,
        clearTimeout,
    };

    vm.runInNewContext(source, context, { filename: "product-multilingual.js" });
    context.window.imageFieldUI.init(
        $(Object.keys(imageUrls).map((id) => ({ id }))),
        { img_path: "//images.openfoodfacts.org/images/products/123/" },
    );

    return { context, htmlBySelector, documentListeners };
}

test("getFullSizeImageUrl converts sized image filenames to .full.", () => {
    const { context } = initHarnessWithFieldUrl({});
    assert.equal(context.getFullSizeImageUrl("front_en.12.400.jpg"), "front_en.12.full.jpg");
    assert.equal(context.getFullSizeImageUrl("ingredients_fr.4.200.jpg"), "ingredients_fr.4.full.jpg");
    assert.equal(context.getFullSizeImageUrl(""), "");
    assert.equal(context.getFullSizeImageUrl(null), "");
});

test("update_display adds a full-size link in a new tab for resized images", () => {
    const { context, htmlBySelector } = initHarnessWithFieldUrl({
        front_en: "front_en.12.400.jpg",
        nutrition_en: "nutrition_en.8.400.jpg",
    });

    context.update_display("front_en", true, false);
    const frontHtml = htmlBySelector['div[id="display_front_en"]'];
    assert.match(frontHtml, /<img src="\/\/images\.openfoodfacts\.org\/images\/products\/123\/front_en\.12\.400\.jpg" \/>/);
    assert.match(
        frontHtml,
        /<a id="fullsizebutton_front_en" class="small button" href="\/\/images\.openfoodfacts\.org\/images\/products\/123\/front_en\.12\.full\.jpg" target="_blank" rel="noopener noreferrer">Full size<\/a>/,
    );
    assert.match(frontHtml, /id="unselectbutton_front_en"/);

    context.update_display("nutrition_en", true, true);
    const nutritionHtml = htmlBySelector['div[id="display_nutrition_en"]'];
    assert.match(
        nutritionHtml,
        /<a id="fullsizebutton_nutrition_en" class="small button" href="\/\/images\.openfoodfacts\.org\/images\/products\/123\/nutrition_en\.8\.full\.jpg" target="_blank" rel="noopener noreferrer">Full size<\/a>/,
    );
    assert.doesNotMatch(nutritionHtml, /id="unselectbutton_nutrition_en"/);
});

test("update_display updates both the full-size link and inline ingredients preview after crop-saved", () => {
    const { htmlBySelector, documentListeners } = initHarnessWithFieldUrl({
        ingredients_fr: "ingredients_fr.2.400.jpg",
    });

    documentListeners["crop-saved"]({
        detail: {
            imagefield: "ingredients_fr",
            display_url: "ingredients_fr.9.400.jpg",
        },
    });

    const displayHtml = htmlBySelector['div[id="display_ingredients_fr"]'];
    const inlineFullHtml = htmlBySelector["#ingredients_fr_image_full"];
    assert.match(
        displayHtml,
        /href="\/\/images\.openfoodfacts\.org\/images\/products\/123\/ingredients_fr\.9\.full\.jpg"/,
    );
    assert.match(
        inlineFullHtml,
        /<img src="\/\/images\.openfoodfacts\.org\/images\/products\/123\/ingredients_fr\.9\.full\.jpg" class="ingredients_image_full"\/>/,
    );
});

test("update_display uses translated label and escapes HTML in full-size button", () => {
    const { context, htmlBySelector } = initHarnessWithFieldUrl(
        { packaging_fr: "packaging_fr.3.400.jpg" },
        { image_full_size: "Taille <réelle>" },
    );

    context.update_display("packaging_fr", true, false);
    const packagingHtml = htmlBySelector['div[id="display_packaging_fr"]'];
    assert.match(
        packagingHtml,
        /<a id="fullsizebutton_packaging_fr" class="small button" href="\/\/images\.openfoodfacts\.org\/images\/products\/123\/packaging_fr\.3\.full\.jpg" target="_blank" rel="noopener noreferrer">Taille &lt;réelle&gt;<\/a>/,
    );
    assert.match(packagingHtml, /id="ocrbuttongooglecloudvision_packaging_fr"/);
});

test("update_display does nothing when display_url is missing", () => {
    const { context, htmlBySelector } = initHarnessWithFieldUrl({});
    assert.doesNotThrow(() => context.update_display("front_en", true, false));
    assert.equal(htmlBySelector['div[id="display_front_en"]'], undefined);
});
