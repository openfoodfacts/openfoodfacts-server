// Tests for the history of the tags typed in the tag inputs of the product forms.
//
// tagify-init.js is a browser script, and not a module: we load it as is with a stub
// for the local storage it uses, so that its functions are available here.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import vm from "node:vm";

const local_storage = {};

globalThis.window = {
    localStorage: {
        getItem: function (key) {
            return Object.hasOwn(local_storage, key) ? local_storage[key] : null;
        },
        setItem: function (key, value) {
            local_storage[key] = String(value);
        }
    }
};

vm.runInThisContext(readFileSync(new URL("../../html/js/tagify-init.js", import.meta.url), "utf8"), {
    filename: "tagify-init.js"
});

const {addTagsToRecentTags, getTagsToCommit, get_recents, initializeTagifyInput, readRecentTags, update_tag_recents} = globalThis;

const MAXIMUM = 10;

// Replace Tagify by a stub that records event handlers and dropdown interactions,
// simulating how Tagify behaves when adding or editing tags
function install_fake_tagify() {
    const handlers = {};
    const dropdownCalls = [];
    const tagify = {
        DOM: {},
        whitelist: null,
        dropdownCalls: dropdownCalls,
        editingValue: null,
        dropdown: {
            show: function (term) {
                const query = typeof term === "undefined" ? "" : String(term);
                const currentWhitelist = tagify.whitelist ? [...tagify.whitelist] : [];
                const filtered = query
                    ? currentWhitelist.filter((item) => {
                        const text = typeof item === "object" && item !== null
                            ? (item.searchBy || item.value)
                            : String(item);

                        return text.toLowerCase().includes(query.toLowerCase());
                    })
                    : currentWhitelist;

                dropdownCalls.push({
                    term: term,
                    query: query,
                    whitelist: currentWhitelist,
                    suggestions: filtered
                });
            }
        },
        on: function (event, handler) {
            handlers[event] = handler;

            return tagify;
        },
        focus_input: function () {
            if (handlers["focus"]) {
                handlers["focus"]({});
            }
            tagify.dropdown.show();
        },
        blur_input: function () {
            tagify.editingValue = null;
            if (handlers["blur"]) {
                handlers["blur"]({});
            }
        },
        cancel_edit: function () {
            tagify.editingValue = null;
            if (handlers["edit:keydown"]) {
                handlers["edit:keydown"]({
                    detail: {
                        event: {key: "Escape"}
                    }
                });
            }
            if (handlers["blur"]) {
                handlers["blur"]({});
            }
        },
        start_edit: function (value) {
            tagify.editingValue = value;
            // Mimic Tagify's editTag method:
            // 1. triggers edit:start
            if (handlers["edit:start"]) {
                handlers["edit:start"]({detail: {data: {value: value}}});
            }
            // 2. focuses the editable tag text node, triggering focus on scope
            if (handlers["focus"]) {
                handlers["focus"]({});
            }
            // 3. Tagify calls dropdown.show() without arguments when enabled is 0
            tagify.dropdown.show();
        },
        type_edit: function (newValue) {
            tagify.editingValue = newValue;
            if (handlers["edit:input"]) {
                handlers["edit:input"]({detail: {data: {newValue: newValue}}});
            }
        },
        save_edit: function (newValue) {
            tagify.editingValue = null;
            if (handlers["edit:updated"]) {
                handlers["edit:updated"]({detail: {data: {value: newValue}}});
            }
        },
        add_tag: function (value) {
            handlers["add"]({detail: {data: {value: value}}});
        },
        edit_tag: function (oldValue, newValue) {
            this.start_edit(oldValue);
            this.save_edit(newValue);
        },
        type_input: function (newValue) {
            if (handlers["input"]) {
                handlers["input"]({detail: {value: newValue}});
            }
        }
    };

    globalThis.Tagify = function (el, options) {
        if (options && options.whitelist) {
            tagify.whitelist = [...options.whitelist];
        }

        return tagify;
    };

    return tagify;
}

function store_history(field, history) {
    local_storage["po_last_tags"] = JSON.stringify({[field]: history});
}

function clear_history() {
    delete local_storage["po_last_tags"];
}

// Mimic the submit handler of product-multilingual.js: only the tags that are
// still submitted are committed to the history
function submit_field(el, maximum, submittedTags) {
    const tagsToCommit = getTagsToCommit(el, submittedTags);
    if (tagsToCommit.length) {
        addTagsToRecentTags([{id: el.id, maximum: maximum, tags: tagsToCommit}]);
    }
    return tagsToCommit;
}

test("a tag that is not in the history yet is added at the top", function () {
    assert.deepEqual(update_tag_recents([], "Bio", MAXIMUM), ["Bio"]);
    assert.deepEqual(update_tag_recents(["Bio"], "AOP", MAXIMUM), ["AOP", "Bio"]);
});

test("a tag that is already in the history is moved back to the top", function () {
    assert.deepEqual(update_tag_recents(["AOP", "Bio"], "Bio"), ["Bio", "AOP"]);
    assert.deepEqual(update_tag_recents(["AOP", "Bio", "Label Rouge"], "AOP"), ["AOP", "Bio", "Label Rouge"]);
});

test("a tag that is added twice is only kept once", function () {
    const history = update_tag_recents(update_tag_recents(["AOP", "Bio"], "Bio", MAXIMUM), "Bio", MAXIMUM);

    assert.deepEqual(history, ["Bio", "AOP"]);
    assert.equal(history.length, 2);
});

// In the histories below, the first tag is the most recently used one and the last is the least recently used one

test("re-adding a tag does not rotate the history when it is full", function () {
    const history = ["A", "B", "C"];

    assert.deepEqual(update_tag_recents(history, "A", 3), ["A", "B", "C"]);
    assert.deepEqual(update_tag_recents(history, "C", 3), ["C", "A", "B"]);
    assert.deepEqual(update_tag_recents(history, "B", 3), ["B", "A", "C"]);
});

test("adding a new tag to a full history drops the least recently used tag", function () {
    const history = ["A", "B", "C"];

    // Re-adding a tag that is already in the history does not drop any tag
    assert.deepEqual(update_tag_recents(history, "A", 3), ["A", "B", "C"]);

    // "C" is the least recently used tag, so it is the one that is dropped for a new tag
    assert.deepEqual(update_tag_recents(history, "D", 3), ["D", "A", "B"]);
});

test("a history longer than the maximum number of tags is trimmed", function () {
    // The maximum number of entries was lowered after the tags were added
    const history = update_tag_recents(["A", "B", "C", "D", "E"], "F", 3);

    assert.deepEqual(history, ["F", "A", "B"]);
});

test("a history that is not an array is replaced by the tag that is added", function () {
    assert.deepEqual(update_tag_recents(null, "Bio", MAXIMUM), ["Bio"]);
    assert.deepEqual(update_tag_recents("Bio", "AOP", MAXIMUM), ["AOP"]);
});

test("the history saved for a field is returned as stored", function () {
    store_history("categories", ["Bio", "AOP"]);

    assert.deepEqual(get_recents("categories", MAXIMUM), ["Bio", "AOP"]);
});

test("get_recents returns no tag for an unknown field, or when the history is disabled", function () {
    store_history("categories", ["Bio", "AOP"]);

    assert.deepEqual(get_recents("labels", MAXIMUM), []);
    assert.deepEqual(get_recents("categories", 0), []);
});

test("a value that cannot be parsed is ignored instead of breaking the history", function () {
    local_storage["po_last_tags"] = "{not json";

    assert.deepEqual(readRecentTags(), {});
    assert.deepEqual(get_recents("categories", MAXIMUM), []);
});

test("a value that is not a list of tags is ignored", function () {
    store_history("categories", "Bio");

    assert.deepEqual(get_recents("categories", MAXIMUM), []);
});

test("adding a tag does not write to the history before submit", function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.add_tag("Bio");

    // Typos and tags removed before saving must not be remembered (issue #15004)
    assert.deepEqual(local_storage["po_last_tags"], undefined);
    assert.deepEqual(get_recents("categories", MAXIMUM), []);
});

test("the tags added to a field are committed on submit, in field order", function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.add_tag("Bio");
    tagify.add_tag("AOP");
    tagify.add_tag("Label Rouge");
    submit_field(el, MAXIMUM, ["Bio", "AOP", "Label Rouge"]);

    assert.deepEqual(get_recents("categories", MAXIMUM), ["Bio", "AOP", "Label Rouge"]);
    assert.deepEqual(get_recents("labels", MAXIMUM), []);
});

test("committed tags move back to the top in most recently used order", function () {
    store_history("labels", ["Bio", "AOP", "Label Rouge"]);

    const tagify = install_fake_tagify();
    const el = {id: "labels", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    // Re-add "AOP", already in the history: it moves back to the top (issue #15005)
    tagify.add_tag("AOP");
    submit_field(el, MAXIMUM, ["Bio", "AOP", "Label Rouge"]);

    assert.deepEqual(get_recents("labels", MAXIMUM), ["AOP", "Bio", "Label Rouge"]);

    // New history, re-add the least recently used tag
    store_history("labels", ["A", "B", "C"]);
    const tagify2 = install_fake_tagify();
    const el2 = {id: "labels", dataset: {}};
    initializeTagifyInput(el2, MAXIMUM);
    tagify2.add_tag("C");
    submit_field(el2, MAXIMUM, ["A", "B", "C"]);

    assert.deepEqual(get_recents("labels", MAXIMUM), ["C", "A", "B"]);
});

test("committing a re-added tag moves it to the top", function () {
    store_history("labels", ["A", "B", "C"]);

    // Direct commit, as done on submit: "C" was already used, it moves to the top
    addTagsToRecentTags([{id: "labels", maximum: 3, tags: ["C"]}]);

    assert.deepEqual(get_recents("labels", 3), ["C", "A", "B"]);
});

test("committing a new tag to a full history drops the least recently used tag", function () {
    store_history("labels", ["A", "B", "C"]);

    addTagsToRecentTags([{id: "labels", maximum: 3, tags: ["D"]}]);

    // "C" is the least recently used tag, so it is the one that is dropped
    assert.deepEqual(get_recents("labels", 3), ["D", "A", "B"]);
});

test("the history never grows above the maximum number of tags", function () {
    clear_history();

    addTagsToRecentTags([{id: "labels", maximum: MAXIMUM, tags: ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"]}]);

    const history = get_recents("labels", MAXIMUM);
    assert.deepEqual(history, ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J"]);
    assert.equal(history.length, MAXIMUM);
});

test("tags removed before submit are not committed", function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.add_tag("Bio");
    tagify.add_tag("Typo");
    // Only "Bio" is still submitted, "Typo" was removed before saving
    submit_field(el, MAXIMUM, ["Bio"]);

    assert.deepEqual(get_recents("categories", MAXIMUM), ["Bio"]);
});

test("edited tags are committed on submit", function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.add_tag("Bio");
    tagify.edit_tag("Bio", "AOP");
    submit_field(el, MAXIMUM, ["AOP"]);

    assert.deepEqual(get_recents("categories", MAXIMUM), ["AOP"]);
});

test("nothing is saved for a field that does not keep a history", function () {
    clear_history();

    const tagify = install_fake_tagify();
    // The product preferences pass 0 as maximumRecentEntriesPerTag, to not store any recent tag
    const el = {id: "attribute_unwanted_ingredients_tags", dataset: {}};
    initializeTagifyInput(el, 0);

    tagify.add_tag("en:palm-oil");
    submit_field(el, 0, ["en:palm-oil"]);

    assert.deepEqual(local_storage["po_last_tags"], undefined);
});

// Issue #15127 regression tests

test("Test 1 — existing tag initializes correctly when entering edit mode", function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.start_edit("chocolate");

    assert.equal(tagify.editingValue, "chocolate");
});

test("Test 2 — initial history suggestions are filtered using the existing tag text", function () {
    store_history("categories", [
        "chocolate",
        "chocolate biscuits",
        "chocolate milk",
        "tomato sauce",
        "olive oil"
    ]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.start_edit("chocolate");

    const lastCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(lastCall.term, "chocolate");
    assert.deepEqual(lastCall.suggestions, [
        "chocolate",
        "chocolate biscuits",
        "chocolate milk"
    ]);
});

test("Test 3 — initial taxonomy request uses the existing tag text as search query", async function () {
    clear_history();

    let requestedUrl = null;
    globalThis.fetch = function (url) {
        requestedUrl = url;

        return Promise.resolve({
            json: function () {
                return Promise.resolve({
                    matched_synonyms: {
                        "en:chocolate": "Chocolate",
                        "en:dark-chocolate": "Dark chocolate"
                    }
                });
            }
        });
    };

    const tagify = install_fake_tagify();
    const el = {
        id: "categories",
        dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}
    };
    initializeTagifyInput(el, MAXIMUM);

    tagify.start_edit("chocolate");

    await new Promise((resolve) => setTimeout(resolve, 350));

    assert.ok(requestedUrl, "taxonomy request was made");
    const parsedUrl = new URL(requestedUrl, "https://world.openfoodfacts.org");
    assert.equal(parsedUrl.searchParams.get("string"), "chocolate");
    assert.equal(parsedUrl.searchParams.get("get_synonyms"), "1");
});

test("Test 4 — new tag creation displays all history entries on focus without filtering", function () {
    store_history("categories", [
        "chocolate",
        "tomato sauce",
        "olive oil"
    ]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.focus_input();

    const lastCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(lastCall.term, undefined);
    assert.deepEqual(lastCall.suggestions, [
        "chocolate",
        "tomato sauce",
        "olive oil"
    ]);
});

test("Test 5 — subsequent typing in edit mode updates suggestions with the current query", function () {
    store_history("categories", [
        "chocolate",
        "chocolate biscuits",
        "chocolate milk",
        "tomato sauce"
    ]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.start_edit("chocolate");
    tagify.type_edit("chocolate milk");

    const lastCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(lastCall.term, "chocolate milk");
    assert.deepEqual(lastCall.suggestions, ["chocolate milk"]);
});

test("Test 6 — consecutive tag edits use each tag's own text without retaining stale state", function () {
    store_history("categories", [
        "chocolate",
        "chocolate biscuits",
        "tomato sauce",
        "olive oil"
    ]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.start_edit("chocolate");
    tagify.save_edit("chocolate");

    tagify.start_edit("tomato");

    const lastCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(lastCall.term, "tomato");
    assert.deepEqual(lastCall.suggestions, ["tomato sauce"]);
});

test("Test 7 — selecting a suggestion and completing normal edit saves updated tag", function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.add_tag("chocolate");
    tagify.edit_tag("chocolate", "dark chocolate");
    submit_field(el, MAXIMUM, ["dark chocolate"]);

    assert.deepEqual(get_recents("categories", MAXIMUM), ["dark chocolate"]);
});

test("Test 8 — cancelling an edit with Escape cleans up edit state and restores normal focus behavior", function () {
    store_history("categories", [
        "chocolate",
        "chocolate biscuits",
        "tomato sauce"
    ]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.start_edit("chocolate");
    assert.equal(tagify.dropdownCalls[tagify.dropdownCalls.length - 1].term, "chocolate");

    // Cancel edit via Escape
    tagify.cancel_edit();

    // Focusing the input as a new tag should display all history without filtering
    tagify.focus_input();
    const focusCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(focusCall.term, undefined);
    assert.deepEqual(focusCall.suggestions, [
        "chocolate",
        "chocolate biscuits",
        "tomato sauce"
    ]);

    // Editing a different tag afterwards does not retain stale state from the cancelled edit
    tagify.start_edit("tomato");
    const nextEditCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(nextEditCall.term, "tomato");
    assert.deepEqual(nextEditCall.suggestions, ["tomato sauce"]);
});

test("Test 9 — asynchronous response ordering prevents stale taxonomy responses from overwriting newer query", async function () {
    clear_history();

    let resolveFirstRequest;
    let resolveSecondRequest;

    let callCount = 0;
    globalThis.fetch = function () {
        callCount++;
        const currentCount = callCount;

        if (currentCount === 1) {
            return new Promise((resolve) => {
                resolveFirstRequest = function () {
                    resolve({
                        json: function () {
                            return Promise.resolve({
                                matched_synonyms: {
                                    "en:chocolate": "Old Chocolate Match"
                                }
                            });
                        }
                    });
                };
            });
        }

        return new Promise((resolve) => {
            resolveSecondRequest = function () {
                resolve({
                    json: function () {
                        return Promise.resolve({
                            matched_synonyms: {
                                "en:dark-chocolate": "New Dark Chocolate Match"
                            }
                        });
                    }
                });
            };
        });
    };

    const tagify = install_fake_tagify();
    const el = {
        id: "categories",
        dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}
    };
    initializeTagifyInput(el, MAXIMUM);

    // Edit 1: "chocolate"
    tagify.start_edit("chocolate");
    await new Promise((resolve) => setTimeout(resolve, 350));

    // While request 1 is still in flight, user types "dark chocolate"
    tagify.type_edit("dark chocolate");
    await new Promise((resolve) => setTimeout(resolve, 350));

    // Resolve second request first
    resolveSecondRequest();
    await new Promise((resolve) => setTimeout(resolve, 50));

    const afterSecondCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.deepEqual(afterSecondCall.whitelist, ["New Dark Chocolate Match"]);

    // Resolve first (stale) request later
    resolveFirstRequest();
    await new Promise((resolve) => setTimeout(resolve, 50));

    // Stale result must not overwrite the whitelist
    const finalCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.deepEqual(finalCall.whitelist, ["New Dark Chocolate Match"]);
});

test("Test 10 — history-only fields without taxonomy endpoints provide history suggestions during editing and typing", function () {
    store_history("stores", [
        "Carrefour",
        "Carrefour Market",
        "Casino",
        "Monoprix"
    ]);

    const tagify = install_fake_tagify();
    // Input without autocomplete endpoint
    const el = {id: "stores", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    // Enter edit mode for "Carrefour"
    tagify.start_edit("Carrefour");

    const initialCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(initialCall.term, "Carrefour");
    assert.deepEqual(initialCall.suggestions, [
        "Carrefour",
        "Carrefour Market"
    ]);

    // Subsequent typing updates suggestions
    tagify.type_edit("Carrefour M");
    const typingCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(typingCall.term, "Carrefour M");
    assert.deepEqual(typingCall.suggestions, ["Carrefour Market"]);
});

test("Test 11 — edit-session termination prevents late taxonomy responses from polluting later state", async function () {
    clear_history();
    store_history("categories", [
        "tomato sauce",
        "olive oil"
    ]);

    let resolveTerminatedRequest;
    globalThis.fetch = function () {
        return new Promise((resolve) => {
            resolveTerminatedRequest = function () {
                resolve({
                    json: function () {
                        return Promise.resolve({
                            matched_synonyms: {
                                "en:chocolate": "Late Chocolate Match"
                            }
                        });
                    }
                });
            };
        });
    };

    const tagify = install_fake_tagify();
    const el = {
        id: "categories",
        dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}
    };
    initializeTagifyInput(el, MAXIMUM);

    // Start editing "chocolate"
    tagify.start_edit("chocolate");
    await new Promise((resolve) => setTimeout(resolve, 350));

    // Cancel edit via Escape
    tagify.cancel_edit();

    // Focus input for new tag
    tagify.focus_input();
    const focusCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.deepEqual(focusCall.whitelist, ["tomato sauce", "olive oil"]);

    // Resolve the taxonomy request from the cancelled session
    resolveTerminatedRequest();
    await new Promise((resolve) => setTimeout(resolve, 50));

    // Whitelist must still be the history, not polluted by Late Chocolate Match
    const finalCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.deepEqual(finalCall.whitelist, ["tomato sauce", "olive oil"]);
});

test("Test 12 — language-prefixed tags strip prefix for search and preserve prefix in taxonomy suggestions", async function () {
    clear_history();
    store_history("categories", [
        "fr:chocolat",
        "fr:chocolat noir",
        "fr:sauce tomate"
    ]);

    let requestedUrl = null;
    globalThis.fetch = function (url) {
        requestedUrl = url;

        return Promise.resolve({
            json: function () {
                return Promise.resolve({
                    matched_synonyms: {
                        "fr:chocolat-au-lait": "Chocolat au lait"
                    }
                });
            }
        });
    };

    const tagify = install_fake_tagify();
    const el = {
        id: "categories",
        dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}
    };
    initializeTagifyInput(el, MAXIMUM);

    // Start editing "fr:chocolat"
    tagify.start_edit("fr:chocolat");

    // Dropdown show receives stripped search term "chocolat"
    const initialCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(initialCall.term, "chocolat");
    assert.deepEqual(initialCall.suggestions, [
        "fr:chocolat",
        "fr:chocolat noir"
    ]);

    // Wait for taxonomy response
    await new Promise((resolve) => setTimeout(resolve, 350));

    assert.ok(requestedUrl, "taxonomy request was made");
    const parsedUrl = new URL(requestedUrl, "https://world.openfoodfacts.org");
    assert.equal(parsedUrl.searchParams.get("string"), "fr:chocolat");

    // The taxonomy suggestions preserve the language prefix
    const taxonomyCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.deepEqual(taxonomyCall.whitelist, [
        {value: "fr:Chocolat au lait", searchBy: "Chocolat au lait"}
    ]);
});

test("Test 13 — stale taxonomy response after query becomes empty cannot overwrite current whitelist or re-render suggestions", async function () {
    clear_history();
    store_history("categories", [
        "tomato sauce",
        "olive oil"
    ]);

    let resolveStaleRequest;
    globalThis.fetch = function () {
        return new Promise((resolve) => {
            resolveStaleRequest = function () {
                resolve({
                    json: function () {
                        return Promise.resolve({
                            matched_synonyms: {
                                "en:chocolate": "Stale Chocolate"
                            }
                        });
                    }
                });
            };
        });
    };

    const tagify = install_fake_tagify();
    const el = {
        id: "categories",
        dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}
    };
    initializeTagifyInput(el, MAXIMUM);

    // Type "chocolate" — starts a taxonomy request after debounce
    tagify.type_input("chocolate");
    await new Promise((resolve) => setTimeout(resolve, 350));

    // User clears the input — empty query transition
    tagify.type_input("");

    // Whitelist is reset to recent history
    const afterClear = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.deepEqual(afterClear.whitelist, ["tomato sauce", "olive oil"]);
    const callCountAfterClear = tagify.dropdownCalls.length;

    // The stale "chocolate" request resolves
    resolveStaleRequest();
    await new Promise((resolve) => setTimeout(resolve, 50));

    // Obsolete response must not trigger a new dropdown call or mutate synonymMap
    assert.equal(tagify.dropdownCalls.length, callCountAfterClear);
    assert.equal(tagify.synonymMap, undefined);

    // Whitelist must remain the history
    const finalCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.deepEqual(finalCall.whitelist, ["tomato sauce", "olive oil"]);
});

test("Test 14 — aborting a taxonomy request does not produce unhandled errors", async function () {
    clear_history();

    let fetchSignal;
    globalThis.fetch = function (url, options) {
        fetchSignal = options && options.signal;

        // Return a promise that rejects with AbortError when aborted
        return new Promise(function (resolve, reject) {
            if (fetchSignal) {
                fetchSignal.addEventListener("abort", function () {
                    const abortError = new DOMException("The operation was aborted.", "AbortError");
                    reject(abortError);
                });
            }
        });
    };

    const tagify = install_fake_tagify();
    const el = {
        id: "categories",
        dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}
    };
    initializeTagifyInput(el, MAXIMUM);

    // Start editing, which fires a taxonomy request after debounce
    tagify.start_edit("chocolate");
    await new Promise((resolve) => setTimeout(resolve, 350));

    // Save edit, which aborts the in-flight request
    tagify.save_edit("chocolate");

    // Allow microtasks to process the abort rejection
    await new Promise((resolve) => setTimeout(resolve, 50));

    // If we reach here without an unhandled rejection, the test passes.
    // The whitelist should be the history (empty query after save)
    assert.deepEqual(tagify.whitelist, []);
});

test("Test 15 — reopening the same tag for editing starts a fresh correct session", function () {
    store_history("categories", [
        "chocolate",
        "chocolate biscuits",
        "tomato sauce"
    ]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    // First edit
    tagify.start_edit("chocolate");
    const firstEdit = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(firstEdit.term, "chocolate");
    assert.deepEqual(firstEdit.suggestions, ["chocolate", "chocolate biscuits"]);

    // Save without changing
    tagify.save_edit("chocolate");

    // Re-edit the same tag
    tagify.start_edit("chocolate");
    const secondEdit = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(secondEdit.term, "chocolate");
    assert.deepEqual(secondEdit.suggestions, ["chocolate", "chocolate biscuits"]);
});

test("Test 16 — dropdown wrapper passes through explicit search terms unchanged", function () {
    store_history("categories", [
        "chocolate",
        "tomato sauce"
    ]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    // Normal focus (new tag) — dropdown.show() called without arguments
    tagify.focus_input();
    const focusCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(focusCall.term, undefined);
    assert.deepEqual(focusCall.suggestions, ["chocolate", "tomato sauce"]);

    // Edit mode — dropdown.show() called without arguments but value is set
    tagify.start_edit("chocolate");
    const editCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(editCall.term, "chocolate");
    assert.deepEqual(editCall.suggestions, ["chocolate"]);

    // Explicit term via typing — dropdown.show(term) called with explicit argument
    tagify.type_edit("tomato");
    const typeCall = tagify.dropdownCalls[tagify.dropdownCalls.length - 1];
    assert.equal(typeCall.term, "tomato");
    assert.deepEqual(typeCall.suggestions, ["tomato sauce"]);
});
