import assert from "node:assert/strict";
import test from "node:test";

import {getState, getSubmittedValues, installTagifyFixture, setCaret, setSuggestions} from "./tagify_fixture.mjs";

const createPage = installTagifyFixture();

for (const visible of [false, true]) {
    const suggestions = visible ? "visible" : "hidden";

    for (const {key, position, expected} of [
        {key: "ArrowLeft", position: 2, expected: ["A", "[input]", "B"]},
        {key: "ArrowRight", position: 1, expected: ["A", "B", "[input]"]}
    ]) {
        test(`${key} moves the empty input with suggestions ${suggestions}`, async (t) => {
            const page = await createPage(t, {visible, position});
            await page.keyboard.press(key);
            const state = await getState(page);
            assert.deepEqual(state.order, expected);
            assert.deepEqual(state.values, ["A", "B"], "moving the input must not reorder tag values");
            assert.equal(state.suggestionsVisible, visible);
            assert.equal(state.focused, true);
        });
    }

    for (const {key, position, expected} of [
        {key: "ArrowLeft", position: 0, expected: ["[input]", "A", "B"]},
        {key: "ArrowRight", position: 2, expected: ["A", "B", "[input]"]}
    ]) {
        test(`${key} leaves the input in place without an adjacent tag, suggestions ${suggestions}`, async (t) => {
            const page = await createPage(t, {visible, position});
            await page.keyboard.press(key);
            const state = await getState(page);
            assert.deepEqual(state.order, expected);
            assert.deepEqual(state.values, ["A", "B"]);
        });
    }

    for (const {key, offset} of [{key: "ArrowLeft", offset: 0}, {key: "ArrowRight", offset: 2}]) {
        test(`${key} edits text instead of moving the input, suggestions ${suggestions}`, async (t) => {
            const page = await createPage(t, {visible, position: 1});
            await page.locator(".tagify__input").pressSequentially("Ca");
            await setCaret(page, 1);
            await setSuggestions(page, visible);
            await page.keyboard.press(key);
            const state = await getState(page);
            assert.deepEqual(state.order, ["A", "[input]", "B"]);
            assert.equal(state.text, "Ca");
            assert.equal(state.caret, offset);
        });
    }

    for (const {key, offset, expected} of [
        {key: "ArrowLeft", offset: 0, expected: ["[input]", "A", "B"]},
        {key: "ArrowRight", offset: 2, expected: ["A", "B", "[input]"]}
    ]) {
        test(`${key} moves the input only at its text boundary, suggestions ${suggestions}`, async (t) => {
            const page = await createPage(t, {visible, position: 1});
            await page.locator(".tagify__input").pressSequentially("Ca");
            await setCaret(page, offset);
            await setSuggestions(page, visible);
            await page.keyboard.press(key);
            const state = await getState(page);
            assert.deepEqual(state.order, expected);
            assert.equal(state.text, "Ca");
            assert.equal(state.caret, offset);
        });
    }

    test(`inserting between tags preserves displayed and submitted order, suggestions ${suggestions}`, async (t) => {
        const page = await createPage(t, {visible, position: 1});
        await page.locator(".tagify__input").pressSequentially("C");
        await setSuggestions(page, visible);
        await page.keyboard.press("Enter");
        const submitted = await getSubmittedValues(page, 3);
        const state = await getState(page);
        assert.deepEqual(state.order, ["A", "C", "[input]", "B"]);
        assert.deepEqual(state.values, ["A", "C", "B"]);
        assert.deepEqual(submitted, ["A", "C", "B"]);
    });

    test(`Backspace removes the preceding tag in the middle, suggestions ${suggestions}`, async (t) => {
        const page = await createPage(t, {visible, position: 1});
        await page.keyboard.press("Backspace");
        await page.waitForFunction(() => window.tagify.getTagElms().length === 1);
        const state = await getState(page);
        assert.deepEqual(state.order, ["[input]", "B"]);
        assert.deepEqual(state.values, ["B"]);
        assert.deepEqual(await getSubmittedValues(page, 1), ["B"]);
    });

    for (const {key, position, expected} of [
        {key: "ArrowRight", position: 2, expected: ["A", "[input]", "B"]},
        {key: "ArrowLeft", position: 1, expected: ["A", "B", "[input]"]}
    ]) {
        test(`RTL ${key} moves the input in the reversed direction, suggestions ${suggestions}`, async (t) => {
            const page = await createPage(t, {visible, position, direction: "rtl"});
            await page.keyboard.press(key);
            const state = await getState(page);
            assert.deepEqual(state.order, expected);
            assert.deepEqual(state.values, ["A", "B"]);
            assert.equal(state.focused, true);
            assert.equal(state.suggestionsVisible, visible);
        });
    }
}

test("hidden suggestions wait for a pending dropdown render", async (t) => {
    const page = await createPage(t);
    // Hold the render callback so the race is deterministic: Tagify has marked
    // the dropdown visible, but hide() is still a no-op while it is detached.
    await page.evaluate(() => {
        const {tagify} = window;
        const render = tagify.dropdown.render;
        tagify.dropdown.render = () => {
            window.renderPendingDropdown = render;
        };
        tagify.dropdown.show();
    });
    await page.waitForFunction(() => typeof window.renderPendingDropdown === "function");
    assert.equal(await page.evaluate(() => window.tagify.DOM.dropdown.isConnected), false);
    assert.equal((await getState(page)).suggestionsVisible, true);

    const hiding = setSuggestions(page, false);
    await page.evaluate(() => {
        const {tagify} = window;
        tagify.dropdown.render = window.renderPendingDropdown;
        tagify.dropdown.render();
    });
    await hiding;
    assert.equal((await getState(page)).suggestionsVisible, false);
});

test("selecting a suggestion between tags preserves the submitted order", async (t) => {
    const page = await createPage(t, {visible: true, position: 1});
    await page.locator('.tagify__dropdown__item[value="C"]').click();
    assert.deepEqual(await getSubmittedValues(page, 3), ["A", "C", "B"]);
    assert.deepEqual((await getState(page)).values, ["A", "C", "B"]);
});
