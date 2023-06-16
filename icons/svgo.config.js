// svgo.config.js
// https://github.com/svg/svgo#configuration
module.exports = {
  plugins: [
    {
      name: "removeViewBox",
      active: false
    },
    {
      name: "removeDimensions",
      active: true,
    },
    {
      name: "addClassesToSVGElement",
      active: true,
      params: { className: "icon" }
    },
    {
      name: "addAttributesToSVGElement",
      active: true,
      params: { attributes: [{ "aria-hidden": "true", focusable: "false" }] }
    },
  ],
};
