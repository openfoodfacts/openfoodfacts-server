/**
 * This is related to robotoff insight validation.
 * 
 * It enables showing / hiding the div containing the web component.
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
  // Hide the alert until we have questions
  parentElement.style.display = "none";
  lang;
  element.addEventListener(eventToListenTo, (event) => {
    if (event.detail.state === "has-data") {
      parentElement.style.display = "block";
    } else if (event.detail.state === "annotated") {
      setTimeout(function () {
        parentElement.style.display = "none";
      }, 3000);
    } else {
      parentElement.style.display = "none";
    }
  });
};
