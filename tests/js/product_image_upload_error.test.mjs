import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test, { beforeEach, describe } from "node:test";
import vm from "node:vm";

// Setup environment and globals for product-multilingual.js
let langTranslations = {};

globalThis.lang = function () {
    return langTranslations;
};

globalThis.window = {
    location: {
        origin: "https://world.openfoodfacts.org",
        href: ""
    }
};

const domStore = {};

function createFakeJQueryElement(selector) {
    let key = selector;
    if (typeof selector === "string" && selector.startsWith("<")) {
        const idMatch = selector.match(/id="([^"]+)"/);
        if (idMatch) {
            key = "#" + idMatch[1];
        }
    }
    if (!domStore[key]) {
        domStore[key] = {
            htmlContent: "",
            textNodes: [],
            visible: true,
            length: 1
        };
    } else if (typeof selector === "string" && selector.startsWith("<")) {
        // When recreating element from HTML, restore length to 1
        domStore[key].length = 1;
        domStore[key].visible = true;
    }
    const state = domStore[key];

    const element = {
        length: state.length,
        selector: selector,
        html: function (val) {
            if (val === undefined) {
                return state.htmlContent;
            }
            state.htmlContent = String(val);
            return element;
        },
        empty: function () {
            state.htmlContent = "";
            state.textNodes = [];
            return element;
        },
        append: function (content) {
            if (content && typeof content === "object" && content.nodeType === 3) {
                state.textNodes.push(content.nodeValue);
                state.htmlContent += content.nodeValue;
            } else {
                state.htmlContent += String(content);
            }
            return element;
        },
        show: function () {
            state.visible = true;
            return element;
        },
        hide: function () {
            state.visible = false;
            return element;
        },
        val: function () {
            return "";
        },
        data: function () {
            return false;
        },
        after: function (newEl) {
            domStore[selector + "_after"] = newEl;
            return element;
        },
        each: function () {
            return element;
        },
        find: function () {
            return {
                each: function () { return this; },
                remove: function () {}
            };
        },
        change: function () { return element; },
        click: function () { return element; },
        on: function () { return element; },
        off: function () { return element; },
        prop: function () { return false; },
        addClass: function () { return element; },
        removeClass: function () { return element; },
        css: function () { return element; },
        siblings: function () { return element; },
        text: function () { return ""; },
        foundation: function () { return element; },
        select2: function () { return element; },
        fileupload: function () { return element; },
        trigger: function () { return element; }
    };

    return element;
}

const fakeJQuery = function (selector) {
    if (typeof selector === "function") {
        // Document ready callback - do not execute on script load
        return;
    }
    return createFakeJQueryElement(selector);
};

fakeJQuery.fn = {};
fakeJQuery.extend = function (target, src) {
    return Object.assign(target || {}, src || {});
};
fakeJQuery.cookie = function () {
    return undefined;
};
fakeJQuery.removeCookie = function () {};
fakeJQuery.each = function (obj, cb) {
    if (Array.isArray(obj)) {
        obj.forEach((val, idx) => cb(idx, val));
    }
};

globalThis.$ = fakeJQuery;
globalThis.jQuery = fakeJQuery;
globalThis.window.$ = fakeJQuery;
globalThis.window.jQuery = fakeJQuery;
globalThis.admin = 0;
globalThis.initializeTagifyInputs = function () {};
globalThis.initLanguageAdding = function () {};
globalThis.trackMatomoEvent = function () {};
globalThis.document = {
    addEventListener: function () {},
    removeEventListener: function () {},
    getElementById: function () {
        return {
            addEventListener: function () {}
        };
    },
    querySelector: function (sel) {
        if (sel === "html") {
            return {
                lang: "en",
                dataset: { serverdomain: "openfoodfacts.org" }
            };
        }
        return null;
    },
    querySelectorAll: function () {
        return [];
    },
    createElement: function (tagName) {
        return {
            tagName: tagName.toUpperCase(),
            textContent: "",
            get innerHTML() {
                return this.textContent
                    .replace(/&/g, "&amp;")
                    .replace(/</g, "&lt;")
                    .replace(/>/g, "&gt;")
                    .replace(/"/g, "&quot;")
                    .replace(/'/g, "&#039;");
            }
        };
    },
    createTextNode: function (text) {
        return {
            nodeType: 3,
            nodeValue: String(text)
        };
    },
    foundation: function () {}
};

// Execute product-multilingual.js in current context
const scriptSource = readFileSync(new URL("../../html/js/product-multilingual.js", import.meta.url), "utf8");
vm.runInThisContext(scriptSource, {
    filename: "product-multilingual.js"
});

const { imageFieldUI } = globalThis.window;
const {
    getUploadFailureErrorMessage,
    getUploadDoneErrorMessage,
    showError: showImageUploadError,
    hideError: hideImageUploadError
} = imageFieldUI;

describe("Image upload error handling and classification", () => {

    beforeEach(() => {
        // Reset translations before each test
        langTranslations = {
            product_js_image_upload_error: "Error while uploading image",
            product_js_image_upload_error_file_too_large: "This image is too large. Please choose a smaller image.",
            product_js_image_upload_error_network: "Network error while uploading the image. Please try again.",
            product_js_image_upload_error_server: "The image could not be uploaded due to a server error. Please try again later.",
            image_upload_error_image_already_exists: "This picture has already been sent.",
            image_upload_error_image_too_small: "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.",
            image_upload_error_could_not_read_image: "The image could not be read.",
            image_upload_error_no_barcode_specified_or_found: "No barcode specified or found in the image or filename."
        };
        for (const k in domStore) {
            delete domStore[k];
        }
    });

    describe("Global namespace hygiene", () => {
        test("does not pollute window with loose helper functions", () => {
            assert.equal(globalThis.window.getUploadFailureErrorMessage, undefined);
            assert.equal(globalThis.window.getUploadDoneErrorMessage, undefined);
            assert.equal(globalThis.window.showImageUploadError, undefined);
            assert.equal(globalThis.window.hideImageUploadError, undefined);
            assert.equal(globalThis.window.isSupportedImageFile, undefined);
        });

        test("exposes all required methods on window.imageFieldUI", () => {
            assert.equal(typeof imageFieldUI, "object");
            assert.equal(typeof imageFieldUI.init, "function");
            assert.equal(typeof imageFieldUI.setImages, "function");
            assert.equal(typeof imageFieldUI.addImage, "function");
            assert.equal(typeof imageFieldUI.show, "function");
            assert.equal(typeof imageFieldUI.getUploadFailureErrorMessage, "function");
            assert.equal(typeof imageFieldUI.getUploadDoneErrorMessage, "function");
            assert.equal(typeof imageFieldUI.showError, "function");
            assert.equal(typeof imageFieldUI.hideError, "function");
        });

        test("does not expose restrictive client-side format checker", () => {
            assert.equal(imageFieldUI.isSupportedImageFile, undefined);
        });
    });

    describe("getUploadFailureErrorMessage (HTTP and Network failures)", () => {
        test("identifies HTTP 413 as file too large", () => {
            const data = { jqXHR: { status: 413 }, textStatus: "error" };
            const msg = getUploadFailureErrorMessage(data);
            assert.equal(msg, "This image is too large. Please choose a smaller image.");
        });

        test("identifies status 0 as network failure", () => {
            const data = { jqXHR: { status: 0 }, textStatus: "error" };
            const msg = getUploadFailureErrorMessage(data);
            assert.equal(msg, "Network error while uploading the image. Please try again.");
        });

        test("identifies textStatus timeout as network failure", () => {
            const data = { jqXHR: { status: 0 }, textStatus: "timeout" };
            const msg = getUploadFailureErrorMessage(data);
            assert.equal(msg, "Network error while uploading the image. Please try again.");
        });

        test("identifies HTTP 500, 502, 503, 504 as server failure", () => {
            for (const status of [500, 502, 503, 504]) {
                const data = { jqXHR: { status }, textStatus: "error" };
                const msg = getUploadFailureErrorMessage(data);
                assert.equal(msg, "The image could not be uploaded due to a server error. Please try again later.");
            }
        });

        test("does not automatically classify parsererror on 200 as server failure; uses safe fallback", () => {
            // A non-JSON response with HTTP 200 (e.g. HTML login redirect) should safely fallback
            const data = { jqXHR: { status: 200 }, textStatus: "parsererror" };
            const msg = getUploadFailureErrorMessage(data);
            assert.equal(msg, "Error while uploading image");
        });

        test("identifies parsererror on HTTP 500 as server failure", () => {
            const data = { jqXHR: { status: 500 }, textStatus: "parsererror" };
            const msg = getUploadFailureErrorMessage(data);
            assert.equal(msg, "The image could not be uploaded due to a server error. Please try again later.");
        });

        test("returns null for intentional client abort (no alert shown)", () => {
            const data = { jqXHR: { status: 0 }, textStatus: "abort" };
            assert.equal(getUploadFailureErrorMessage(data), null);
        });

        test("resolves known safe error_key from responseJSON when present", () => {
            const data = {
                jqXHR: {
                    status: 400,
                    responseJSON: { error_key: "image_upload_error_image_already_exists" }
                },
                textStatus: "error"
            };
            const msg = getUploadFailureErrorMessage(data);
            assert.equal(msg, "This picture has already been sent.");
        });

        test("does not leak arbitrary technical server error in responseJSON", () => {
            // Internal database error in responseJSON should not leak; 500 status gives user-friendly server error
            const data500 = {
                jqXHR: {
                    status: 500,
                    responseJSON: { error: "DBD::Pg::st execute failed: could not connect to server" }
                },
                textStatus: "error"
            };
            assert.equal(getUploadFailureErrorMessage(data500), "The image could not be uploaded due to a server error. Please try again later.");

            // Technical error on 400 should not leak; gives generic fallback
            const data400 = {
                jqXHR: {
                    status: 400,
                    responseJSON: { error: "field imgupload_front_en not set" }
                },
                textStatus: "error"
            };
            assert.equal(getUploadFailureErrorMessage(data400), "Error while uploading image");
        });

        test("falls back to generic error for unrecognized HTTP errors (e.g. 404, 400)", () => {
            const data404 = { jqXHR: { status: 404 }, textStatus: "error" };
            assert.equal(getUploadFailureErrorMessage(data404), "Error while uploading image");

            const data400 = { jqXHR: { status: 400 }, textStatus: "error" };
            assert.equal(getUploadFailureErrorMessage(data400), "Error while uploading image");
        });

        test("safely handles null, undefined, and empty data objects", () => {
            assert.equal(getUploadFailureErrorMessage(null), "Error while uploading image");
            assert.equal(getUploadFailureErrorMessage(undefined), "Error while uploading image");
            assert.equal(getUploadFailureErrorMessage({}), "Error while uploading image");
        });
    });

    describe("getUploadDoneErrorMessage (Backend error classification via error_key)", () => {
        test("resolves structured backend error_keys directly", () => {
            assert.equal(
                getUploadDoneErrorMessage({ error_key: "image_upload_error_image_already_exists" }),
                "This picture has already been sent."
            );
            assert.equal(
                getUploadDoneErrorMessage({ error_key: "image_upload_error_image_too_small" }),
                "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself."
            );
            assert.equal(
                getUploadDoneErrorMessage({ error_key: "image_upload_error_could_not_read_image" }),
                "The image could not be read."
            );
            assert.equal(
                getUploadDoneErrorMessage({ error_key: "image_upload_error_no_barcode_specified_or_found" }),
                "No barcode specified or found in the image or filename."
            );
        });

        test("preserves backward compatibility for legacy negative imgid codes", () => {
            assert.equal(
                getUploadDoneErrorMessage({ imgid: -4 }),
                "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself."
            );
            assert.equal(
                getUploadDoneErrorMessage({ imgid: -5 }),
                "The image could not be read."
            );
            // -2 is internal "field not set", falls back to generic
            assert.equal(getUploadDoneErrorMessage({ imgid: -2 }), "Error while uploading image");
        });

        test("handles realistic duplicate image response fixture from cgi/product_image_upload.pl", () => {
            // Note: On duplicate upload, process_image_upload_using_filehandle returns -3,
            // but sets $imgid to the existing image ID. Thus the CGI sets imgid = 1 (positive integer).
            const duplicateFixture = {
                code: "1234567890014",
                debug: "product_id: 1234567890014 - user_id:  - imagefield: front_en - we have already received an image with this file size: 18145 - imgid: 1",
                error: "This picture has already been sent.",
                error_key: "image_upload_error_image_already_exists",
                files: [
                    {
                        code: "1234567890014",
                        filename: "",
                        name: "1234567890014",
                        thumbnailUrl: "/images/products/123/456/789/0014/1.100.jpg",
                        url: "/product/1234567890014"
                    }
                ],
                imagefield: "front_en",
                imgid: 1,
                status: "status not ok"
            };

            assert.equal(getUploadDoneErrorMessage(duplicateFixture), "This picture has already been sent.");
            assert.ok(duplicateFixture.imgid > 0, "Duplicate response retains positive existing image id");
        });

        test("handles realistic image too small response fixture", () => {
            const tooSmallFixture = {
                code: "1234567890013",
                debug: "product_id: 1234567890013 - user_id:  - imagefield: front_en - size of image file received: 909 - saved jpg: 288 - image too small - width: 4 - height: 4",
                error: "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.",
                error_key: "image_upload_error_image_too_small",
                files: [
                    {
                        code: "1234567890013",
                        filename: "",
                        name: "1234567890013",
                        url: "/product/1234567890013"
                    }
                ],
                imagefield: "front_en",
                imgid: -4,
                status: "status not ok"
            };

            assert.equal(getUploadDoneErrorMessage(tooSmallFixture), "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.");
        });

        test("handles realistic unreadable / corrupt image response fixture", () => {
            const unreadableFixture = {
                debug: "product_id: 123456 - user_id: test - imagefield: front_en - could not read image: 420 Corrupt JPEG data",
                error: "The image could not be read.",
                error_key: "image_upload_error_could_not_read_image",
                imagefield: "front_en",
                imgid: -5,
                status: "status not ok"
            };

            assert.equal(getUploadDoneErrorMessage(unreadableFixture), "The image could not be read.");
        });

        test("handles realistic missing barcode response fixture", () => {
            const noBarcodeFixture = {
                error: "No barcode specified or found in the image or filename.",
                error_key: "image_upload_error_no_barcode_specified_or_found",
                files: [
                    {
                        error: "No barcode specified or found in the image or filename.",
                        error_key: "image_upload_error_no_barcode_specified_or_found",
                        filename: "sample.jpg"
                    }
                ],
                status: "status not ok"
            };

            assert.equal(getUploadDoneErrorMessage(noBarcodeFixture), "No barcode specified or found in the image or filename.");
        });

        test("does not leak arbitrary technical or unvalidated server errors", () => {
            assert.equal(getUploadDoneErrorMessage({ error: "error" }), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error: " ERROR " }), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error: "field imgupload_front_en not set" }), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error: "error - invalid product code: 12345678" }), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error: "error - invalid product code: <script>alert(1)</script>" }), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error: "Can't call method Read on Image::Magick line 1069" }), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error: "/var/www/openfoodfacts/cache/tmp/file.jpg not found" }), "Error while uploading image");
        });

        test("handles response with error status but no known error field", () => {
            const result = { status: "status not ok - edit against edit rules" };
            assert.equal(getUploadDoneErrorMessage(result), "Error while uploading image");
        });

        test("handles empty or malformed result safely", () => {
            assert.equal(getUploadDoneErrorMessage(null), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage(undefined), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({}), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error: null }), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error: "" }), "Error while uploading image");
            assert.equal(getUploadDoneErrorMessage({ error_key: "unknown_key_xyz" }), "Error while uploading image");
        });
    });

    describe("Internationalization and fallback behavior", () => {
        test("uses localized translations when lang() provides them", () => {
            langTranslations = {
                product_js_image_upload_error: "Erreur lors de l'envoi de l'image",
                product_js_image_upload_error_file_too_large: "Cette image est trop volumineuse. Veuillez choisir une image plus petite.",
                product_js_image_upload_error_network: "Erreur réseau lors de l'envoi de l'image. Veuillez réessayer.",
                product_js_image_upload_error_server: "L'image n'a pas pu être envoyée en raison d'une erreur de serveur.",
                image_upload_error_image_already_exists: "Cette image a déjà été envoyée.",
                image_upload_error_image_too_small: "L'image est trop petite.",
                image_upload_error_could_not_read_image: "L'image n'a pas pu être lue."
            };

            const netError = getUploadFailureErrorMessage({ jqXHR: { status: 0 }, textStatus: "error" });
            assert.equal(netError, "Erreur réseau lors de l'envoi de l'image. Veuillez réessayer.");

            const largeError = getUploadFailureErrorMessage({ jqXHR: { status: 413 }, textStatus: "error" });
            assert.equal(largeError, "Cette image est trop volumineuse. Veuillez choisir une image plus petite.");

            const serverError = getUploadFailureErrorMessage({ jqXHR: { status: 500 }, textStatus: "error" });
            assert.equal(serverError, "L'image n'a pas pu être envoyée en raison d'une erreur de serveur.");

            const duplicateError = getUploadDoneErrorMessage({ error_key: "image_upload_error_image_already_exists", imgid: 1 });
            assert.equal(duplicateError, "Cette image a déjà été envoyée.");

            const genericError = getUploadDoneErrorMessage({ error: "error" });
            assert.equal(genericError, "Erreur lors de l'envoi de l'image");
        });

        test("falls back to English defaults when lang() keys are missing", () => {
            langTranslations = {}; // empty translations

            const netError = getUploadFailureErrorMessage({ jqXHR: { status: 0 }, textStatus: "error" });
            assert.equal(netError, "Network error while uploading the image. Please try again.");

            const largeError = getUploadFailureErrorMessage({ jqXHR: { status: 413 }, textStatus: "error" });
            assert.equal(largeError, "This image is too large. Please choose a smaller image.");

            const serverError = getUploadFailureErrorMessage({ jqXHR: { status: 500 }, textStatus: "error" });
            assert.equal(serverError, "The image could not be uploaded due to a server error. Please try again later.");

            const duplicateError = getUploadDoneErrorMessage({ error_key: "image_upload_error_image_already_exists", imgid: 1 });
            assert.equal(duplicateError, "This picture has already been sent.");

            const genericError = getUploadDoneErrorMessage({});
            assert.equal(genericError, "Error while uploading image");
        });
    });

    describe("DOM error presentation (showImageUploadError / hideImageUploadError)", () => {
        test("showImageUploadError sets text safely and includes close button", () => {
            const field = "front_en";
            showImageUploadError(field, "Test error message");

            const state = domStore["#imgsearcherror_" + field];
            assert.ok(state, "DOM element was accessed");
            assert.equal(state.visible, true);
            assert.ok(state.htmlContent.includes("Test error message"));
            assert.ok(state.htmlContent.includes("&times;"));
        });

        test("showImageUploadError escapes HTML content via text node", () => {
            const field = "nutrition_en";
            showImageUploadError(field, "<script>alert('xss')</script>");

            const state = domStore["#imgsearcherror_" + field];
            // Text nodes contain unexecuted raw string, appended as nodeValue
            assert.ok(state.textNodes.includes("<script>alert('xss')</script>"));
        });

        test("showImageUploadError clears previous text and does not duplicate close buttons", () => {
            const field = "ingredients_en";
            showImageUploadError(field, "First error");
            showImageUploadError(field, "Second error");

            const state = domStore["#imgsearcherror_" + field];
            assert.equal(state.textNodes.length, 1);
            assert.equal(state.textNodes[0], "Second error");

            // Verify only one close button exists in htmlContent
            const closeMatches = state.htmlContent.match(/class="close"/g);
            assert.equal(closeMatches.length, 1);
        });

        test("showImageUploadError recreates element if it was removed by Foundation close", () => {
            const field = "packaging_en";
            // First display
            showImageUploadError(field, "Initial error");
            assert.ok(domStore["#imgsearcherror_" + field]);

            // Simulate user clicking Foundation close button which removes element (length = 0)
            domStore["#imgsearcherror_" + field].length = 0;

            // Second display after dismissal
            showImageUploadError(field, "New error after dismissal");
            const state = domStore["#imgsearcherror_" + field];
            assert.equal(state.visible, true);
            assert.ok(state.htmlContent.includes("New error after dismissal"));
        });

        test("hideImageUploadError hides the error element", () => {
            const field = "front_en";
            showImageUploadError(field, "Test error");
            hideImageUploadError(field);

            const state = domStore["#imgsearcherror_" + field];
            assert.equal(state.visible, false);
        });

        test("showImageUploadError ignores empty or null message", () => {
            const field = "test_field";
            showImageUploadError(field, null);
            showImageUploadError(field, "");
            showImageUploadError(field, undefined);

            assert.equal(domStore["#imgsearcherror_" + field], undefined);
        });
    });
});
