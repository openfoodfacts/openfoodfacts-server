/**
 * This is related to robotoff insight validation.
 *
 * It enables showing / hiding the div containing the web component with is_hidden css class.
 *
 * @param {Event} eventToListenTo - Event emitted by the web-component,
 * with a state attribute. We react to "has-data" (show) and "annotated" (hide).
 * @param {string} elementId - The web component id.
 * @param {string} parentSelector - A web selector of the containing div.
 * If omitted, we will only id the web-component.
 * @returns {void}
 */
window.listenEventToShowHideAlert = function (
  eventToListenTo,
  elementId,
  parentSelector,
  reloadOnAnnotated = false
) {
  const element = document.getElementById(elementId);
  const parentElement = parentSelector
    ? document.querySelector(parentSelector)
    : element.parentElement;
  parentElement.classList.add("is_hidden");
  element.addEventListener(eventToListenTo, (event) => {
    if (event.detail.state === "has-data") {
      parentElement.classList.remove("is_hidden");
    } else if (event.detail.state === "annotated") {
      // reload the page to show the new insight
      if (reloadOnAnnotated) {
        window.location.reload();
      } else {
        // hide the element after 3 seconds
        setTimeout(function () {
          parentElement.classList.add("is_hidden");
        }, 3000);
      }
    } else {
      parentElement.classList.add("is_hidden");
    }
  });
};
