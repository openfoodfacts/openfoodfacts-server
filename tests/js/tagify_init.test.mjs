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
// simulate tags being added to or edited in a field
function install_fake_tagify() {
    const handlers = {};
    const scope = {addEventListener: function (event, handler) { this[event] = handler; }};
    let focusCount = 0;
    const tagify = {
        DOM: {scope, input: {focus: function () { focusCount++; }}},
        get focusCount() { return focusCount; },
        whitelist: null,
        dropdown: {show: function () {}},
        on: function (event, handler) {
            handlers[event] = handler;

            return tagify;
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

    return tagify;
}

test("clicking a tag field label or empty border focuses the editable input", function () {
    const tagify = install_fake_tagify();
    const label = {addEventListener: function (event, handler) { this[event] = handler; }};
    const el = {id: "labels", dataset: {}, labels: [label]};
    initializeTagifyInput(el, MAXIMUM);

    let prevented = false;
    label.click({preventDefault: function () { prevented = true; }});
    assert.equal(prevented, true);
    assert.equal(tagify.focusCount, 1);

    tagify.DOM.scope.click({target: tagify.DOM.scope});
    assert.equal(tagify.focusCount, 2);

    // Clicking a tag or its remove/edit button must keep Tagify's own behavior.
    tagify.DOM.scope.click({target: {}});
    assert.equal(tagify.focusCount, 2);
});

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
