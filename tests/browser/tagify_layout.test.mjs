import assert from "node:assert/strict";
import test from "node:test";

import {getState, installTagifyFixture} from "./tagify_fixture.mjs";

const createPage = installTagifyFixture();

async function getWidth(page) {
    return page.locator(".tagify__input").evaluate((element) => element.getBoundingClientRect().width);
}

for (const visible of [false, true]) {
    const suggestions = visible ? "visible" : "hidden";

    for (const {width, viewportWidth} of [
        {width: 600, viewportWidth: 1024},
        {width: 240, viewportWidth: 320},
        {width: 160, viewportWidth: 320}
    ]) {
        test(`the middle input remains at least 110px wide in a ${width}px container, suggestions ${suggestions}`, async (t) => {
            const page = await createPage(t, {visible, position: 1, width, viewportWidth});
            assert.deepEqual((await getState(page)).order, ["A", "[input]", "B"]);
            const measuredWidth = await getWidth(page);
            t.diagnostic(`rendered input width: ${measuredWidth}px`);
            assert.ok(measuredWidth >= 110, `rendered input width was ${measuredWidth}px`);
        });
    }

    test(`the middle input grows into available space, suggestions ${suggestions}`, async (t) => {
        const page = await createPage(t, {visible, position: 1, width: 300});
        const before = await getWidth(page);
        await page.locator("#field-container").evaluate((element) => {
            element.style.width = "600px";
        });
        const after = await getWidth(page);
        t.diagnostic(`rendered input grew from ${before}px to ${after}px`);
        assert.ok(after > before + 200, `input only grew from ${before}px to ${after}px`);
        assert.deepEqual((await getState(page)).order, ["A", "[input]", "B"]);
    });

    test(`moving the input between tags does not shrink it below 110px, suggestions ${suggestions}`, async (t) => {
        const page = await createPage(t, {visible});
        await page.keyboard.press("ArrowLeft");
        assert.deepEqual((await getState(page)).order, ["A", "[input]", "B"]);
        const measuredWidth = await getWidth(page);
        t.diagnostic(`rendered input width after moving: ${measuredWidth}px`);
        assert.ok(measuredWidth >= 110, `rendered input width was ${measuredWidth}px after moving`);
    });
}
