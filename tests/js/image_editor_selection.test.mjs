import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const source = await readFile(new URL("../../html/js/image-editor-selection.js", import.meta.url), "utf8");
const {
    selectionAfterImageTransform,
    shouldAdjustSelectionForImageTransform,
} = await import(`data:text/javascript;base64,${Buffer.from(source).toString("base64")}`);

const identity = [1, 0, 0, 1, 0, 0];

test("does not adjust the crop while a replacement image is loading", () => {
    assert.equal(
        shouldAdjustSelectionForImageTransform({imageSourceLoading: true, moveMode: false}),
        false
    );
});

test("does not adjust the crop while the image is being moved beneath it", () => {
    assert.equal(
        shouldAdjustSelectionForImageTransform({imageSourceLoading: false, moveMode: true}),
        false
    );
});

test("adjusts the crop for user image transforms in selection mode", () => {
    assert.equal(
        shouldAdjustSelectionForImageTransform({imageSourceLoading: false, moveMode: false}),
        true
    );
});

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
