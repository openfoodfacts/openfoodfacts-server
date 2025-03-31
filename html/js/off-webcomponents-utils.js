/**

 * This is related to robotoff insight validation.
 *
 * It enables showing / hiding the div containing the web component with is_hidden css class.
 *
 * @param {Event} eventToListenTo - Event emitted by the web-component,
 * with a state attribute. We react to "has-data" (show) and "annotated" (hide).
 * @param {string} elementId - The web component id.
 * @param {object} options - Options.
 * @param {string} options.parentSelector - A web selector of the containing div.
 * If omitted, we will only id the web-component.
 * @param {boolean} options.reloadOnAnnotated - If true, we reload the page when the insight is annotated.
 * @returns {void}
 */
window.listenEventToShowHideAlert = function (
  eventToListenTo,
  elementId,
  options = {}
) {
  const element = document.getElementById(elementId);
  const parentElement = options.parentSelector
    ? document.querySelector(options.parentSelector)
    : element.parentElement;
  parentElement.classList.add("is_hidden");
  element.addEventListener(eventToListenTo, (event) => {
    if (event.detail.state === "has-data") {
      parentElement.classList.remove("is_hidden");
    } else if (event.detail.state === "annotated") {
      // reload the page to show the new insight
      if (options.reloadOnAnnotated) {
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
