import assert from "node:assert/strict";
import test from "node:test";

import { selectionAfterImageTransform } from "../../html/js/image-editor-selection.mjs";

const identity = [1, 0, 0, 1, 0, 0];

test("keeps the selection in place for an unchanged image transform", () => {
    assert.deepEqual(
        selectionAfterImageTransform({x: 10, y: 20, width: 30, height: 40}, identity, identity, 100, 100),
        {x: 10, y: 20, width: 30, height: 40}
    );
});

test("rotates the selection with the image around its center", () => {
    assert.deepEqual(
        selectionAfterImageTransform(
            {x: 10, y: 20, width: 30, height: 40},
            identity,
            [0, 1, -1, 0, 0, 0],
            100,
            100
        ),
        {x: 40, y: 10, width: 40, height: 30}
    );
});

test("scales the selection with a zoom around the image center", () => {
    assert.deepEqual(
        selectionAfterImageTransform(
            {x: 30, y: 30, width: 20, height: 20},
            identity,
            [2, 0, 0, 2, 0, 0],
            100,
            100
        ),
        {x: 10, y: 10, width: 40, height: 40}
    );
});

test("returns null for a singular transform", () => {
    assert.equal(
        selectionAfterImageTransform({x: 10, y: 20, width: 30, height: 40}, [0, 0, 0, 0, 0, 0], identity, 100, 100),
        null
    );
});
