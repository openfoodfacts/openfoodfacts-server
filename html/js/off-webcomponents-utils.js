/**
 * This is related to robotoff insight validation.
 *
 * It enables showing / hiding the div containing the web component with is_hidden css class.
 *
 * @param eventToListenTo - event emited by the web-component,
 * with a state attribute. we react to "has-data" (show) and "annotated" (hide)
 *
 * @param elementId - the web component id
 *
 * @param parentSelector - a web selector of the containing div.
 * If omitted, we will only id the web-component.
 */
window.listenEventToShowHideAlert = function (
  eventToListenTo,
  elementId,
  parentSelector
) {
  const element = document.getElementById(elementId);
  let parentElement = parentSelector
    ? document.querySelector(parentSelector)
    : element.parentElement;
  parentElement.classList.add("is_hidden");
  element.addEventListener(eventToListenTo, (event) => {
    if (event.detail.state === "has-data") {
      parentElement.classList.remove("is_hidden");
    } else if (event.detail.state === "annotated") {
      setTimeout(function () {
        parentElement.classList.add("is_hidden");
      }, 3000);
    } else {
      parentElement.classList.add("is_hidden");
    }
  });
};
