export function setImageMoveMode(canvasHandle, selection, enabled) {
  if (!canvasHandle) {
    return false;
  }

  canvasHandle.action = enabled ? 'move' : 'select';
  if (selection) {
    selection.style.pointerEvents = enabled ? 'none' : '';
  }

  return enabled;
}
