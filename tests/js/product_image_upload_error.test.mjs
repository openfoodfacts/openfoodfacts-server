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
    isSupportedImageFile,
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
            product_js_image_upload_error_format: "This image format is not supported. Please use a supported format.",
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
            assert.equal(globalThis.window.isSupportedImageFile, undefined);
            assert.equal(globalThis.window.getUploadFailureErrorMessage, undefined);
            assert.equal(globalThis.window.getUploadDoneErrorMessage, undefined);
            assert.equal(globalThis.window.showImageUploadError, undefined);
            assert.equal(globalThis.window.hideImageUploadError, undefined);
        });

        test("exposes all required methods on window.imageFieldUI", () => {
            assert.equal(typeof imageFieldUI, "object");
            assert.equal(typeof imageFieldUI.init, "function");
            assert.equal(typeof imageFieldUI.setImages, "function");
            assert.equal(typeof imageFieldUI.addImage, "function");
            assert.equal(typeof imageFieldUI.show, "function");
            assert.equal(typeof imageFieldUI.isSupportedImageFile, "function");
            assert.equal(typeof imageFieldUI.getUploadFailureErrorMessage, "function");
            assert.equal(typeof imageFieldUI.getUploadDoneErrorMessage, "function");
            assert.equal(typeof imageFieldUI.showError, "function");
            assert.equal(typeof imageFieldUI.hideError, "function");
        });
    });

    describe("isSupportedImageFile (Format validation)", () => {
        test("accepts standard supported image formats with matching MIME type", () => {
            assert.equal(isSupportedImageFile({ name: "front.jpg", type: "image/jpeg" }), true);
            assert.equal(isSupportedImageFile({ name: "front.jpeg", type: "image/jpeg" }), true);
            assert.equal(isSupportedImageFile({ name: "ingredients.png", type: "image/png" }), true);
            assert.equal(isSupportedImageFile({ name: "nutrition.gif", type: "image/gif" }), true);
            assert.equal(isSupportedImageFile({ name: "packaging.webp", type: "image/webp" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.heic", type: "image/heic" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.heif", type: "image/heif" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.jpf", type: "image/jp2" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.jp2", type: "image/jp2" }), true);
        });

        test("accepts uppercase and mixed-case supported extensions", () => {
            assert.equal(isSupportedImageFile({ name: "PHOTO.JPG", type: "image/jpeg" }), true);
            assert.equal(isSupportedImageFile({ name: "PHOTO.JPEG", type: "image/jpeg" }), true);
            assert.equal(isSupportedImageFile({ name: "PHOTO.PNG", type: "image/png" }), true);
            assert.equal(isSupportedImageFile({ name: "PHOTO.GIF", type: "image/gif" }), true);
            assert.equal(isSupportedImageFile({ name: "PHOTO.WEBP", type: "image/webp" }), true);
            assert.equal(isSupportedImageFile({ name: "PHOTO.HEIC", type: "image/heic" }), true);
            assert.equal(isSupportedImageFile({ name: "PHOTO.JPF", type: "image/jp2" }), true);
            assert.equal(isSupportedImageFile({ name: "PHOTO.JP2", type: "image/jp2" }), true);
        });

        test("accepts files with valid extensions when MIME type is missing or generic", () => {
            assert.equal(isSupportedImageFile({ name: "photo.jpg", type: "" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.jpeg", type: "" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.png", type: "application/octet-stream" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.heic", type: "" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.webp", type: "" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.jpf", type: "" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.jp2", type: "" }), true);
            assert.equal(isSupportedImageFile({ name: "photo.JPG", type: "" }), true);
        });

        test("accepts blob uploads without filename extension if MIME type is supported", () => {
            assert.equal(isSupportedImageFile({ name: "blob", type: "image/jpeg" }), true);
            assert.equal(isSupportedImageFile({ name: "camera_upload", type: "image/png" }), true);
            assert.equal(isSupportedImageFile({ name: "", type: "image/webp" }), true);
        });

        test("rejects contradictory MIME type and extension", () => {
            // Filename says PDF, MIME says JPEG
            assert.equal(isSupportedImageFile({ name: "invoice.pdf", type: "image/jpeg" }), false);
            // Filename says JPG, MIME says PDF
            assert.equal(isSupportedImageFile({ name: "photo.jpg", type: "application/pdf" }), false);
            // Filename says script.sh, MIME says PNG
            assert.equal(isSupportedImageFile({ name: "script.sh", type: "image/png" }), false);
            // Filename says SVG, MIME says JPEG
            assert.equal(isSupportedImageFile({ name: "drawing.svg", type: "image/jpeg" }), false);
        });

        test("rejects unsupported image formats even when MIME type starts with image/", () => {
            assert.equal(isSupportedImageFile({ name: "drawing.svg", type: "image/svg+xml" }), false);
            assert.equal(isSupportedImageFile({ name: "photo.bmp", type: "image/bmp" }), false);
            assert.equal(isSupportedImageFile({ name: "photo.tiff", type: "image/tiff" }), false);
            assert.equal(isSupportedImageFile({ name: "icon.ico", type: "image/x-icon" }), false);
            assert.equal(isSupportedImageFile({ name: "photo.avif", type: "image/avif" }), false);
        });

        test("rejects non-image files", () => {
            assert.equal(isSupportedImageFile({ name: "document.pdf", type: "application/pdf" }), false);
            assert.equal(isSupportedImageFile({ name: "data.txt", type: "text/plain" }), false);
            assert.equal(isSupportedImageFile({ name: "archive.zip", type: "application/zip" }), false);
            assert.equal(isSupportedImageFile({ name: "video.mp4", type: "video/mp4" }), false);
            assert.equal(isSupportedImageFile({ name: "document.pdf", type: "" }), false);
            assert.equal(isSupportedImageFile({ name: "archive.zip", type: "application/octet-stream" }), false);
        });

        test("rejects null, undefined, and malformed file objects", () => {
            assert.equal(isSupportedImageFile(null), false);
            assert.equal(isSupportedImageFile(undefined), false);
            assert.equal(isSupportedImageFile({}), false);
            assert.equal(isSupportedImageFile("string"), false);
            assert.equal(isSupportedImageFile(123), false);
            assert.equal(isSupportedImageFile({ name: "", type: "" }), false);
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

        test("resolves known safe error from responseJSON when present", () => {
            const data = {
                jqXHR: {
                    status: 400,
                    responseJSON: { imgid: -3 }
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

    describe("getUploadDoneErrorMessage (Backend 200 response handling)", () => {
        test("maps structured negative imgid return codes to user-friendly messages", () => {
            assert.equal(getUploadDoneErrorMessage({ imgid: -3 }), "This picture has already been sent.");
            assert.equal(getUploadDoneErrorMessage({ imgid: -4 }), "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.");
            assert.equal(getUploadDoneErrorMessage({ imgid: -5 }), "The image could not be read.");
            // -2 is internal "field not set", should fall back to generic
            assert.equal(getUploadDoneErrorMessage({ imgid: -2 }), "Error while uploading image");
        });

        test("preserves known legitimate backend translated error messages", () => {
            assert.equal(getUploadDoneErrorMessage({ error: "This picture has already been sent." }), "This picture has already been sent.");
            assert.equal(getUploadDoneErrorMessage({ error: "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself." }), "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.");
            assert.equal(getUploadDoneErrorMessage({ error: "The image could not be read." }), "The image could not be read.");
            assert.equal(getUploadDoneErrorMessage({ error: "No barcode specified or found in the image or filename." }), "No barcode specified or found in the image or filename.");
        });

        test("handles realistic CGI endpoint response fixtures", () => {
            // Fixture 1: Duplicate image response from product_image_upload.pl
            const dupResponse = {
                status: "status not ok",
                error: "This picture has already been sent.",
                imgid: -3,
                debug: "product_id: 123456 - user_id: test - imagefield: front_en - we have already received an image with this file size: 1024 - imgid: 1"
            };
            assert.equal(getUploadDoneErrorMessage(dupResponse), "This picture has already been sent.");

            // Fixture 2: Too small image response
            const tooSmallResponse = {
                status: "status not ok",
                error: "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.",
                imgid: -4
            };
            assert.equal(getUploadDoneErrorMessage(tooSmallResponse), "The picture is too small. Please do not upload pictures found on the Internet and only send photos you have taken yourself.");

            // Fixture 3: Image could not be read (corrupt / unreadable by ImageMagick)
            const unreadableResponse = {
                status: "status not ok",
                error: "The image could not be read.",
                imgid: -5,
                debug: "product_id: 123456 - user_id: test - imagefield: front_en - could not read image: 420 Corrupt JPEG data"
            };
            assert.equal(getUploadDoneErrorMessage(unreadableResponse), "The image could not be read.");

            // Fixture 4: No barcode found response (code not specified)
            const noBarcodeResponse = {
                status: "status not ok",
                error: "No barcode specified or found in the image or filename.",
                files: [{ filename: "sample.jpg" }]
            };
            assert.equal(getUploadDoneErrorMessage(noBarcodeResponse), "No barcode specified or found in the image or filename.");

            // Fixture 5: Invalid product code response (technical)
            const invalidCodeResponse = {
                status: "status not ok",
                error: "error - invalid product code: abc"
            };
            assert.equal(getUploadDoneErrorMessage(invalidCodeResponse), "Error while uploading image");

            // Fixture 6: Missing imagefield error (technical)
            const missingFieldResponse = {
                status: "status not ok",
                error: "error - imagefield not defined"
            };
            assert.equal(getUploadDoneErrorMessage(missingFieldResponse), "Error while uploading image");
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
        });
    });

    describe("Internationalization and fallback behavior", () => {
        test("uses localized translations when lang() provides them", () => {
            langTranslations = {
                product_js_image_upload_error: "Erreur lors de l'envoi de l'image",
                product_js_image_upload_error_file_too_large: "Cette image est trop volumineuse. Veuillez choisir une image plus petite.",
                product_js_image_upload_error_format: "Ce format d'image n'est pas pris en charge.",
                product_js_image_upload_error_network: "Erreur réseau lors de l'envoi de l'image. Veuillez réessayer.",
                product_js_image_upload_error_server: "L'image n'a pas pu être envoyée en raison d'une erreur de serveur.",
                image_upload_error_image_already_exists: "Cette image a déjà été envoyée."
            };

            const netError = getUploadFailureErrorMessage({ jqXHR: { status: 0 }, textStatus: "error" });
            assert.equal(netError, "Erreur réseau lors de l'envoi de l'image. Veuillez réessayer.");

            const largeError = getUploadFailureErrorMessage({ jqXHR: { status: 413 }, textStatus: "error" });
            assert.equal(largeError, "Cette image est trop volumineuse. Veuillez choisir une image plus petite.");

            const serverError = getUploadFailureErrorMessage({ jqXHR: { status: 500 }, textStatus: "error" });
            assert.equal(serverError, "L'image n'a pas pu être envoyée en raison d'une erreur de serveur.");

            const duplicateError = getUploadDoneErrorMessage({ imgid: -3 });
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
