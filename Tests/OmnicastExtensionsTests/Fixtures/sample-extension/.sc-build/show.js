var React = require("react");
var Raycast = require("@raycast/api");
module.exports.default = function Command() {
  return React.createElement(
    Raycast.List,
    { searchBarPlaceholder: "Search fixtures" },
    React.createElement(Raycast.List.Item, { title: "Fixture Result", subtitle: "Ready" })
  );
};
