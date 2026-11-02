import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createDeferredSelectionClear,
  setImageMoveMode,
} from '../../html/js/image-editor-move-mode.mjs';

test('move mode lets the canvas handle move the image without moving the selection', () => {
  const canvasHandle = { action: 'select' };
  const selection = { style: { pointerEvents: '' } };

  assert.equal(setImageMoveMode(canvasHandle, selection, true), true);
  assert.equal(canvasHandle.action, 'move');
  assert.equal(selection.style.pointerEvents, 'none');
});

test('selection mode restores selection interaction and canvas selection', () => {
  const canvasHandle = { action: 'move' };
  const selection = { style: { pointerEvents: 'none' } };

  assert.equal(setImageMoveMode(canvasHandle, selection, false), false);
  assert.equal(canvasHandle.action, 'select');
  assert.equal(selection.style.pointerEvents, '');
});

test('move mode can be enabled before a crop selection exists', () => {
  const canvasHandle = { action: 'select' };

  assert.equal(setImageMoveMode(canvasHandle, null, true), true);
  assert.equal(canvasHandle.action, 'move');
  assert.equal(setImageMoveMode(null, null, true), false);
});

test('double-clicking to enter move mode cancels the pending selection clear', async () => {
  let cleared = false;
  const pendingSelectionClear = createDeferredSelectionClear(10);

  pendingSelectionClear.schedule(() => {
    cleared = true;
  });
  pendingSelectionClear.cancel();

  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.equal(cleared, false);
});

test('a single click still clears the selection after the double-click interval', async () => {
  let cleared = false;
  const pendingSelectionClear = createDeferredSelectionClear(10);

  pendingSelectionClear.schedule(() => {
    cleared = true;
  });

  await new Promise((resolve) => setTimeout(resolve, 20));
  assert.equal(cleared, true);
});
