"use strict";

var React = require("react");
var api = require("@raycast/api");
var List = api.List;
var Detail = api.Detail;
var ActionPanel = api.ActionPanel;
var Action = api.Action;
var showToast = api.showToast;

function storeURL(value) {
  return "https://www.raycast.com/" + encodeURIComponent(value.author) + "/" +
    encodeURIComponent(value.name);
}

function detailMarkdown(value) {
  var commands = (value.commands || []).map(function(command) {
    return "* **" + command.title + "**  " + command.description;
  }).join("\n");
  var categories = (value.categories || []).join(", ") || "Uncategorized";
  return "# " + value.title + "\n\n" + value.description + "\n\n" +
    "## Details\n\n" +
    "**Author:** " + value.author + "\n\n" +
    "**Categories:** " + categories + "\n\n" +
    "**Installs:** " + Number(value.installCount || 0).toLocaleString() + "\n\n" +
    "## Commands\n\n" + (commands || "No commands listed");
}

function Store() {
  var catalogState = React.useState([]);
  var catalog = catalogState[0];
  var setCatalog = catalogState[1];
  var installedState = React.useState([]);
  var installed = installedState[0];
  var setInstalled = installedState[1];
  var loadingState = React.useState(true);
  var loading = loadingState[0];
  var setLoading = loadingState[1];
  var detailState = React.useState(null);
  var detail = detailState[0];
  var setDetail = detailState[1];

  React.useEffect(function() {
    var active = true;
    Promise.all([
      globalThis.omnicast.store.catalog(),
      globalThis.omnicast.store.installed()
    ]).then(function(values) {
      if (!active) return;
      setCatalog(values[0] || []);
      setInstalled(values[1] || []);
      setLoading(false);
    }).catch(function(error) {
      setLoading(false);
      showToast({style: api.Toast.Style.Failure, title: "Could not load the Store", message: String(error)});
    });
    return function() { active = false; };
  }, []);

  function isInstalled(value) {
    return installed.indexOf(value.name) >= 0;
  }

  async function install(value) {
    if (isInstalled(value)) return;
    await showToast({style: api.Toast.Style.Animated, title: "Installing " + value.title});
    try {
      await globalThis.omnicast.store.install(value.name);
      setInstalled(function(values) { return values.concat([value.name]); });
      await showToast({style: api.Toast.Style.Success, title: "Installed " + value.title});
    } catch (error) {
      await showToast({style: api.Toast.Style.Failure, title: "Install failed", message: String(error)});
    }
  }

  function actions(value) {
    return React.createElement(ActionPanel, null,
      React.createElement(Action, {
        title: "Open",
        onAction: function() { setDetail(value); }
      }),
      React.createElement(Action, {
        title: isInstalled(value) ? "Installed" : "Install",
        onAction: function() { return install(value); }
      }),
      React.createElement(Action.OpenInBrowser, {
        title: "Open in Raycast Store",
        url: storeURL(value)
      })
    );
  }

  if (detail) {
    return React.createElement(Detail, {
      markdown: detailMarkdown(detail),
      actions: React.createElement(ActionPanel, null,
        React.createElement(Action, {
          title: "Back to Extensions",
          onAction: function() { setDetail(null); }
        }),
        React.createElement(Action, {
          title: isInstalled(detail) ? "Installed" : "Install",
          onAction: function() { return install(detail); }
        }),
        React.createElement(Action.OpenInBrowser, {
          title: "Open in Raycast Store",
          url: storeURL(detail)
        })
      )
    });
  }

  var installedValues = catalog.filter(isInstalled);
  var availableValues = catalog.filter(function(value) { return !isInstalled(value); });

  function section(title, values) {
    if (!values.length) return null;
    return React.createElement(List.Section, {title: title, subtitle: String(values.length)},
      values.map(function(value) {
        return React.createElement(List.Item, {
          key: value.name,
          title: value.title,
          subtitle: value.description,
          icon: value.iconURL || "🧩",
          accessories: [
            {text: value.author},
            {text: Number(value.installCount || 0).toLocaleString() + " installs"}
          ],
          actions: actions(value)
        });
      })
    );
  }

  return React.createElement(List, {
      isLoading: loading,
      searchBarPlaceholder: "Search extensions"
    },
    section("Installed", installedValues),
    section("Discover", availableValues),
    !loading && !catalog.length
      ? React.createElement(List.EmptyView, {
          title: "No extensions found",
          description: "The catalog did not return any extensions"
        })
      : null
  );
}

module.exports = Store;
