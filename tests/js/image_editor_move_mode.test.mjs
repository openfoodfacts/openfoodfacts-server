import assert from 'node:assert/strict';
import test from 'node:test';

import { setImageMoveMode } from '../../html/js/image-editor-move-mode.mjs';

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
