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
