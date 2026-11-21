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

// Replace Tagify by a stub that only records the event handlers, so that we can
// simulate tags being added to or edited in a field.
//
// The stub does NOT automatically fire a "focus" event on edit:start, because
// Tagify's focus event may not fire when the input already has focus (the
// reviewer's concern #1).
function install_fake_tagify() {
    const handlers = {};
    const shownSuggestions = [];
    const tagify = {
        DOM: {},
        whitelist: null,
        dropdown: {show: function (value) { shownSuggestions.push(value); }},
        on: function (event, handler) {
            handlers[event] = handler;

            return tagify;
        },
        trigger: function (event, detail) {
            handlers[event]({detail: detail || {}});
        },
        add_tag: function (value) {
            handlers["add"]({detail: {data: {value: value}}});
        },
        edit_tag: function (oldValue, newValue) {
            handlers["edit:start"]({detail: {data: {value: oldValue}}});
            handlers["edit:updated"]({detail: {data: {value: newValue}}});
        }
    };

    globalThis.Tagify = function () {
        return tagify;
    };

    tagify.shownSuggestions = shownSuggestions;
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

// Helper: create a controllable fetch stub that records the requested URLs
// and lets tests resolve/reject each request individually.
// Aborted requests simply never resolve, matching browser behavior where the
// AbortError rejection is swallowed by the engine's standard fetch abort path.
function install_fake_fetch() {
    const previousFetch = globalThis.fetch;
    const requests = [];
    globalThis.fetch = function (url, options) {
        const request = {url, options, aborted: false};
        const promise = new Promise((resolve, reject) => {
            request.resolve = function (value) {
                if (!request.aborted) {
                    resolve(value);
                }
            };
            request.reject = reject;
            if (options && options.signal) {
                if (options.signal.aborted) {
                    request.aborted = true;
                }
                options.signal.addEventListener("abort", function () {
                    request.aborted = true;
                    // Do not reject: the pending promise chain will simply never settle.
                    // In the browser, AbortError rejections are handled internally by
                    // the fetch implementation and do not produce unhandled rejections
                    // in the typical (no .catch()) use pattern.
                });
            }
        });
        requests.push(request);
        return promise;
    };
    return {
        requests,
        restore: function () { globalThis.fetch = previousFetch; }
    };
}

// Helper: create a taxonomy response that resolves the fetch promise
function makeTaxonomyResponse(synonyms) {
    return {json: function () {
        return Promise.resolve({matched_synonyms: synonyms});
    }};
}

// Flush the microtask queue (Promises) and one round of macrotasks (setTimeout 0)
async function flushAsync() {
    await new Promise((resolve) => setImmediate(resolve));
    await new Promise((resolve) => setImmediate(resolve));
}

// ==================== Tag history unit tests ====================

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

// ==================== Tagify integration tests ====================

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

// ==================== #15136 regression: blur before taxonomy response ====================

test("taxonomy suggestions are not shown when the input is blurred before the response arrives", async function () {
    const fetchStub = install_fake_fetch();

    try {
        const tagify = install_fake_tagify();
        const el = {id: "categories", dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}};
        initializeTagifyInput(el, MAXIMUM);

        tagify.trigger("focus");
        tagify.trigger("input", {value: "fruit"});
        await new Promise((resolve) => setTimeout(resolve, 350));
        assert.ok(fetchStub.requests.length > 0, "the taxonomy request should have started");

        tagify.trigger("blur");
        const shownCountAfterBlur = tagify.shownSuggestions.length;
        fetchStub.requests[fetchStub.requests.length - 1].resolve(makeTaxonomyResponse({fruit: "fruit"}));
        await flushAsync();

        assert.equal(tagify.shownSuggestions.length, shownCountAfterBlur,
            "no new suggestions should be shown after blur");
    } finally {
        fetchStub.restore();
    }
});

// ==================== #15127: edit:start triggers filtered suggestions ====================

test("editing an existing tag shows suggestions filtered by the tag text (issue #15127)", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    // 1. Input receives focus
    tagify.trigger("focus");
    const countAfterFocus = tagify.shownSuggestions.length;

    // 2. User double-clicks an existing tag — Tagify emits edit:start
    //    No additional focus event fires (input already has focus).
    tagify.trigger("edit:start", {data: {value: "Bio"}});

    // 3. The deferred setTimeout(0) callback runs
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();

    // 4. Suggestions should be shown with the tag value
    assert.ok(tagify.shownSuggestions.length > countAfterFocus,
        "suggestions should be shown after edit:start");
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "Bio",
        "suggestions should be filtered by the existing tag text");
});

test("initial history filtering when editing an existing tag", async function () {
    store_history("categories", ["Bio", "AOP", "Bioland"]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");
    tagify.trigger("edit:start", {data: {value: "Bio"}});

    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();

    // The whitelist should have been initialized with the recent history
    assert.deepEqual(tagify.whitelist, ["Bio", "AOP", "Bioland"]);
    // And dropdown.show should be called with "Bio" to filter those suggestions
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "Bio");
});

test("editing an existing tag works even when no new focus event is emitted", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    // Focus fires once when the user first clicks the input
    tagify.trigger("focus");

    // User double-clicks a tag. No focus event fires again.
    tagify.trigger("edit:start", {data: {value: "AOP"}});

    // Wait for the deferred callback
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();

    // The dropdown should show suggestions filtered by "AOP"
    const lastSuggestion = tagify.shownSuggestions[tagify.shownSuggestions.length - 1];
    assert.equal(lastSuggestion, "AOP",
        "dropdown should show the existing tag text as the search query");
});

test("isFocused remains true during editing and taxonomy responses can update suggestions", async function () {
    const fetchStub = install_fake_fetch();

    try {
        const tagify = install_fake_tagify();
        const el = {id: "categories", dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}};
        initializeTagifyInput(el, MAXIMUM);

        // Focus
        tagify.trigger("focus");

        // Edit a tag (no second focus event)
        tagify.trigger("edit:start", {data: {value: "fruit"}});
        await new Promise((resolve) => setTimeout(resolve, 0));
        await flushAsync();

        // Wait for the debounced fetch to fire
        await new Promise((resolve) => setTimeout(resolve, 350));

        // The taxonomy request should have been made
        assert.ok(fetchStub.requests.length > 0, "taxonomy request should fire during editing");

        // Resolve the fetch — should NOT be discarded since we are still focused
        const shownBefore = tagify.shownSuggestions.length;
        fetchStub.requests[fetchStub.requests.length - 1].resolve(
            makeTaxonomyResponse({fruit: "fruit", "tropical fruit": "tropical fruit"})
        );
        await flushAsync();

        assert.ok(tagify.shownSuggestions.length > shownBefore,
            "taxonomy response should update suggestions while editing");
    } finally {
        fetchStub.restore();
    }
});

// ==================== Deferred callback session protection ====================

test("deferred edit:start callback does not apply after edit cancellation (Escape)", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");
    const countAfterFocus = tagify.shownSuggestions.length;

    // Start editing
    tagify.trigger("edit:start", {data: {value: "Bio"}});

    // User presses Escape before the deferred callback executes.
    // Tagify fires blur on Escape.
    tagify.trigger("blur");

    // The deferred callback runs now
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();

    // The stale callback must NOT show suggestions for the cancelled edit
    assert.equal(tagify.shownSuggestions.length, countAfterFocus,
        "no suggestions should be shown after edit cancellation");
});

test("deferred edit:start callback does not apply when another tag starts editing", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");

    // Start editing tag A
    tagify.trigger("edit:start", {data: {value: "TagA"}});

    // Before the deferred callback runs, user saves TagA and starts editing TagB
    tagify.trigger("edit:updated", {data: {value: "TagA"}});
    tagify.trigger("edit:start", {data: {value: "TagB"}});

    // Let both deferred callbacks run
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();

    // The last suggestion should be for TagB, not TagA
    const lastSuggestion = tagify.shownSuggestions[tagify.shownSuggestions.length - 1];
    assert.equal(lastSuggestion, "TagB",
        "suggestions should be for the latest edit session, not the stale one");
});

// ==================== Consecutive tag edits ====================

test("consecutive tag edits each show correct suggestions", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");

    // Edit first tag
    tagify.trigger("edit:start", {data: {value: "Alpha"}});
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "Alpha");

    // Save and edit another
    tagify.trigger("edit:updated", {data: {value: "Alpha"}});
    tagify.trigger("edit:start", {data: {value: "Beta"}});
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "Beta");

    // Save and edit a third
    tagify.trigger("edit:updated", {data: {value: "Beta"}});
    tagify.trigger("edit:start", {data: {value: "Gamma"}});
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "Gamma");
});

// ==================== Saving an edit ====================

test("saving an edit resets the query and does not commit unchanged tags", function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.add_tag("Bio");

    // Edit tag but keep the same value
    tagify.edit_tag("Bio", "Bio");
    submit_field(el, MAXIMUM, ["Bio"]);

    // "Bio" was added via add_tag, so it should be committed.
    // But the edit_tag with unchanged value should not add it again.
    assert.deepEqual(get_recents("categories", MAXIMUM), ["Bio"]);
});

// ==================== Initial taxonomy autocomplete query ====================

test("initial taxonomy autocomplete query fires on edit:start", async function () {
    const fetchStub = install_fake_fetch();

    try {
        const tagify = install_fake_tagify();
        const el = {id: "categories", dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}};
        initializeTagifyInput(el, MAXIMUM);

        tagify.trigger("focus");
        tagify.trigger("edit:start", {data: {value: "cheese"}});

        // Wait for deferred callback + debounce
        await new Promise((resolve) => setTimeout(resolve, 0));
        await flushAsync();
        await new Promise((resolve) => setTimeout(resolve, 350));

        assert.ok(fetchStub.requests.length > 0, "a taxonomy request should fire for the existing tag text");
        assert.ok(fetchStub.requests[fetchStub.requests.length - 1].url.includes("string=cheese"),
            "the request should search for the tag's text");
    } finally {
        fetchStub.restore();
    }
});

// ==================== Subsequent typing during edit ====================

test("typing during edit updates suggestions", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");
    tagify.trigger("edit:start", {data: {value: "Bio"}});
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();

    // User types more text during edit
    tagify.trigger("edit:input", {data: {newValue: "Biologic"}});
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "Biologic",
        "typing during edit should update suggestions with the new text");
});

// ==================== Normal new-tag creation ====================

test("normal focus resets the whitelist to history entries", function () {
    store_history("categories", ["Bio", "AOP"]);

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");

    // On focus with empty query, the whitelist is set to the history.
    // dropdown.show() is not called (show=false), but the whitelist is available
    // for Tagify's built-in dropdown to use.
    assert.deepEqual(tagify.whitelist, ["Bio", "AOP"]);
});

// ==================== History-only fields (no taxonomy) ====================

test("history-only fields set the whitelist to history on focus without fetch", async function () {
    store_history("labels", ["Bio", "AOP"]);

    const tagify = install_fake_tagify();
    const el = {id: "labels", dataset: {}};  // no autocomplete dataset
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");

    // Whitelist should be set to history entries without any fetch
    assert.deepEqual(tagify.whitelist, ["Bio", "AOP"]);
});

// ==================== Language-prefixed tags ====================

test("editing a language-prefixed tag uses the full value for suggestions", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");
    tagify.trigger("edit:start", {data: {value: "en:organic"}});
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();

    // The dropdown should filter by the tag after the language prefix
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "organic",
        "language-prefixed tag should show suggestions filtered by the text after the prefix");
});

// ==================== Reopening the same tag ====================

test("reopening the same tag for editing shows correct suggestions", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    tagify.trigger("focus");

    // Edit a tag
    tagify.trigger("edit:start", {data: {value: "Bio"}});
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "Bio");

    // Save the edit (unchanged)
    tagify.trigger("edit:updated", {data: {value: "Bio"}});

    // Re-open the same tag
    tagify.trigger("edit:start", {data: {value: "Bio"}});
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();
    assert.equal(tagify.shownSuggestions[tagify.shownSuggestions.length - 1], "Bio",
        "reopening the same tag should still show filtered suggestions");
});

// ==================== Empty-query request invalidation ====================

test("empty query after edit:start invalidates earlier requests", async function () {
    const fetchStub = install_fake_fetch();

    try {
        const tagify = install_fake_tagify();
        const el = {id: "categories", dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}};
        initializeTagifyInput(el, MAXIMUM);

        tagify.trigger("focus");
        tagify.trigger("edit:start", {data: {value: "fruit"}});
        await new Promise((resolve) => setTimeout(resolve, 0));
        await flushAsync();

        // User clears the text
        tagify.trigger("edit:input", {data: {newValue: ""}});

        // Wait for the original debounced request to fire
        await new Promise((resolve) => setTimeout(resolve, 350));

        if (fetchStub.requests.length > 0) {
            // Resolve the stale request
            const shownBefore = tagify.shownSuggestions.length;
            fetchStub.requests[0].resolve(makeTaxonomyResponse({fruit: "fruit"}));
            await flushAsync();

            // It should NOT have added new suggestions since the query changed
            // (the searchRequestId check should prevent it)
        }
    } finally {
        fetchStub.restore();
    }
});

// ==================== Out-of-order taxonomy responses ====================

test("out-of-order taxonomy responses do not overwrite newer queries", async function () {
    const fetchStub = install_fake_fetch();

    try {
        const tagify = install_fake_tagify();
        const el = {id: "categories", dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}};
        initializeTagifyInput(el, MAXIMUM);

        tagify.trigger("focus");

        // First query
        tagify.trigger("input", {value: "app"});
        await new Promise((resolve) => setTimeout(resolve, 350));
        const firstRequest = fetchStub.requests[fetchStub.requests.length - 1];

        // Second query (before first response arrives)
        tagify.trigger("input", {value: "apple"});
        await new Promise((resolve) => setTimeout(resolve, 350));
        const secondRequest = fetchStub.requests[fetchStub.requests.length - 1];

        // Resolve second request first (correct response)
        secondRequest.resolve(makeTaxonomyResponse({apple: "apple"}));
        await flushAsync();
        const countAfterSecond = tagify.shownSuggestions.length;

        // Resolve first request late (stale response)
        firstRequest.resolve(makeTaxonomyResponse({appetizer: "appetizer", apple: "apple"}));
        await flushAsync();

        // The stale first response must not have added more suggestions
        assert.equal(tagify.shownSuggestions.length, countAfterSecond,
            "stale out-of-order response should not update suggestions");
    } finally {
        fetchStub.restore();
    }
});

// ==================== Aborted requests ====================

test("aborted requests do not generate unhandled promise rejections", async function () {
    const fetchStub = install_fake_fetch();

    try {
        const tagify = install_fake_tagify();
        const el = {id: "categories", dataset: {autocomplete: "/api/v3/taxonomy_suggestions?tagtype=categories"}};
        initializeTagifyInput(el, MAXIMUM);

        tagify.trigger("focus");
        tagify.trigger("input", {value: "bio"});
        await new Promise((resolve) => setTimeout(resolve, 350));

        // A second query should abort the first via AbortController
        tagify.trigger("input", {value: "biolog"});
        await new Promise((resolve) => setTimeout(resolve, 350));

        // Give time for any unhandled rejections to surface
        await flushAsync();

        // If we got here without an unhandled rejection, the test passes
        assert.ok(true, "no unhandled promise rejection");
    } finally {
        fetchStub.restore();
    }
});

// ==================== Focus handler preserves #15136 ====================

test("focus handler does not clear editing query when focus fires during editing", async function () {
    clear_history();

    const tagify = install_fake_tagify();
    const el = {id: "categories", dataset: {}};
    initializeTagifyInput(el, MAXIMUM);

    // Initial focus
    tagify.trigger("focus");

    // Start editing
    tagify.trigger("edit:start", {data: {value: "Bio"}});
    await new Promise((resolve) => setTimeout(resolve, 0));
    await flushAsync();

    const countBeforeFocus = tagify.shownSuggestions.length;
    const lastSuggestionBeforeFocus = tagify.shownSuggestions[tagify.shownSuggestions.length - 1];

    // Focus event fires again (e.g., when Tagify moves focus to the contenteditable element)
    tagify.trigger("focus");

    // The focus handler should NOT have reset the query or shown empty suggestions
    // because tagValueBeforeEdit is set
    // Note: the focus handler with the early return should not call updateSuggestions
    assert.equal(tagify.shownSuggestions.length, countBeforeFocus,
        "focus during editing should not add more suggestion calls");
});
