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

const {get_last_tags, get_recents, initializeTagifyInput, update_tag_recents} = globalThis;

const MAXIMUM = 10;

// Replace Tagify by a stub that only records the event handlers, so that we can
// simulate tags being added to a field
function install_fake_tagify() {
    const handlers = {};
    const tagify = {
        DOM: {},
        whitelist: null,
        dropdown: {show: function () {}},
        on: function (event, handler) {
            handlers[event] = handler;

            return tagify;
        },
        add_tag: function (value) {
            handlers["add"]({detail: {data: {value: value}}});
        }
    };

    globalThis.Tagify = function () {
        return tagify;
    };

    return tagify;
}

// Add tags to a history, the same way the tag inputs do when a tag is added to a field
function add_tags(initial_tags, tags) {
    return tags.reduce(function (history, tag) {
        return update_tag_recents(history, tag, MAXIMUM);
    }, initial_tags);
}

function store_history(field, history) {
    local_storage["po_last_tags"] = JSON.stringify({[field]: history});
}

test("a tag that is not in the history yet is added at the top", function () {
    assert.deepEqual(add_tags([], ["Bio", "AOP", "Label Rouge"]), ["Label Rouge", "AOP", "Bio"]);
});

test("a tag that is already in the history is moved back to the top", function () {
    assert.deepEqual(add_tags(["AOP", "Bio"], ["Bio"]), ["Bio", "AOP"]);
    assert.deepEqual(add_tags(["AOP", "Bio", "Label Rouge"], ["AOP"]), ["AOP", "Bio", "Label Rouge"]);
});

test("a tag that is added twice is only kept once", function () {
    const history = add_tags(["AOP", "Bio"], ["Bio", "Bio"]);

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

test("the history never grows above the maximum number of tags", function () {
    const history = add_tags([], ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"]);

    assert.deepEqual(history, ["L", "K", "J", "I", "H", "G", "F", "E", "D", "C"]);
    assert.equal(history.length, MAXIMUM);
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

    assert.deepEqual(get_last_tags(), {});
    assert.deepEqual(get_recents("categories", MAXIMUM), []);
});

test("a value that is not a list of tags is ignored", function () {
    store_history("categories", "Bio");

    assert.deepEqual(get_recents("categories", MAXIMUM), []);
});

test("the tags added to a field are saved in the history of that field", function () {
    delete local_storage["po_last_tags"];

    const tagify = install_fake_tagify();
    initializeTagifyInput({id: "categories", dataset: {}}, MAXIMUM);

    tagify.add_tag("Bio");
    tagify.add_tag("AOP");
    tagify.add_tag("Label Rouge");

    assert.deepEqual(get_recents("categories", MAXIMUM), ["Label Rouge", "AOP", "Bio"]);
    assert.deepEqual(get_recents("labels", MAXIMUM), []);
});

test("the tags added to a field are saved from the most recently used one", function () {
    delete local_storage["po_last_tags"];

    const tagify = install_fake_tagify();
    initializeTagifyInput({id: "labels", dataset: {}}, MAXIMUM);

    ["Bio", "AOP", "Bio", "Label Rouge", "AOP"].forEach(function (tag) {
        tagify.add_tag(tag);
    });

    assert.deepEqual(get_recents("labels", MAXIMUM), ["AOP", "Label Rouge", "Bio"]);
});

test("nothing is saved for a field that does not keep a history", function () {
    delete local_storage["po_last_tags"];

    const tagify = install_fake_tagify();
    // The product preferences pass 0 as maximumRecentEntriesPerTag, to not store any recent tag
    initializeTagifyInput({id: "attribute_unwanted_ingredients_tags", dataset: {}}, 0);

    tagify.add_tag("en:palm-oil");

    assert.deepEqual(local_storage["po_last_tags"], undefined);
});