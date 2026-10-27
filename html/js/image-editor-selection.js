// Keep an axis-aligned crop selection over the same part of the image when the
// image's transform changes (for example, zooming or rotating it).
export function shouldAdjustSelectionForImageTransform({ imageSourceLoading, moveMode }) {
  return !imageSourceLoading && !moveMode;
}

export function selectionAfterImageTransform(selection, oldMatrix, newMatrix, imageWidth, imageHeight) {
  const [a, b, c, d, e, f] = oldMatrix;
  const determinant = (a * d) - (b * c);
  if (!determinant || !imageWidth || !imageHeight) {
    return null;
  }

  const oldInverse = [d / determinant, -b / determinant, -c / determinant, a / determinant];
  const oldInverseTranslation = [
    ((c * f) - (d * e)) / determinant,
    ((b * e) - (a * f)) / determinant,
  ];
  const centerX = imageWidth / 2;
  const centerY = imageHeight / 2;
  const [nextA, nextB, nextC, nextD, nextE, nextF] = newMatrix;

  function mapPoint(x, y) {
    const centeredX = x - centerX;
    const centeredY = y - centerY;
    const localX = (oldInverse[0] * centeredX) + (oldInverse[2] * centeredY)
      + oldInverseTranslation[0] + centerX;
    const localY = (oldInverse[1] * centeredX) + (oldInverse[3] * centeredY)
      + oldInverseTranslation[1] + centerY;
    const localCenteredX = localX - centerX;
    const localCenteredY = localY - centerY;

    return [
      (nextA * localCenteredX) + (nextC * localCenteredY) + nextE + centerX,
      (nextB * localCenteredX) + (nextD * localCenteredY) + nextF + centerY,
    ];
  }

  const corners = [
    mapPoint(selection.x, selection.y),
    mapPoint(selection.x + selection.width, selection.y),
    mapPoint(selection.x, selection.y + selection.height),
    mapPoint(selection.x + selection.width, selection.y + selection.height),
  ];
  const xs = corners.map(([x]) => x);
  const ys = corners.map(([, y]) => y);
  const left = Math.min(...xs);
  const top = Math.min(...ys);
  const right = Math.max(...xs);
  const bottom = Math.max(...ys);

  if (![left, top, right, bottom].every(Number.isFinite)) {
    return null;
  }

  return { x: left, y: top, width: right - left, height: bottom - top };
}
