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

export function createDeferredSelectionClear(delay = 500) {
  let timeoutId;

  return {
    schedule(clearSelection) {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(() => {
        timeoutId = undefined;
        clearSelection();
      }, delay);
    },
    cancel() {
      clearTimeout(timeoutId);
      timeoutId = undefined;
    },
  };
}
