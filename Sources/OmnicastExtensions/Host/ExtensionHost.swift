// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import OmnicastCore
import WebKit

public enum ExtensionHostError: LocalizedError {
    case commandNotFound(String)
    case missingResource(String)
    case invalidResource(String)

    public var errorDescription: String? {
        switch self {
        case .commandNotFound(let name):
            "The extension command was not found: \(name)"
        case .missingResource(let name):
            "The extension host resource is missing: \(name)"
        case .invalidResource(let name):
            "The extension host resource could not be read: \(name)"
        }
    }
}

@MainActor
public final class ExtensionHost: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    public let installedExtension: InstalledExtension
    public let command: ExtensionCommandManifest

    private let directoryURL: URL
    private let persistence: ExtensionPersistence
    private let callbacks: ExtensionHostCallbacks
    private let router: ExtensionBridgeRouter
    private weak var webView: WKWebView?

    public init(
        installedExtension: InstalledExtension,
        commandName: String,
        directoryURL: URL,
        clipboard: any ClipboardService,
        opener: any OpenerService,
        callbacks: ExtensionHostCallbacks
    ) throws {
        guard let command = installedExtension.manifest.commands.first(where: {
            $0.name == commandName
        }) else {
            throw ExtensionHostError.commandNotFound(commandName)
        }
        self.installedExtension = installedExtension
        self.command = command
        self.directoryURL = directoryURL
        self.persistence = ExtensionPersistence(directoryURL: directoryURL)
        self.callbacks = callbacks
        self.router = ExtensionBridgeRouter(
            extensionSlug: installedExtension.slug,
            persistence: persistence,
            clipboard: clipboard,
            opener: opener,
            callbacks: callbacks
        )
        super.init()
    }

    public convenience init(
        installedExtension: InstalledExtension,
        commandName: String,
        directoryURL: URL = OmnicastDataDirectory.defaultURL
    ) throws {
        try self.init(
            installedExtension: installedExtension,
            commandName: commandName,
            directoryURL: directoryURL,
            clipboard: SystemClipboardService(),
            opener: WorkspaceOpenerService(),
            callbacks: ExtensionHostCallbacks()
        )
    }

    public func makeWebView() -> WKWebView {
        let controller = WKUserContentController()
        controller.add(self, name: "omnicast")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        self.webView = webView

        Task { [weak self, weak webView] in
            guard let self, let webView else { return }
            await self.load(into: webView)
        }
        return webView
    }

    public func stop() {
        webView?.stopLoading()
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: "omnicast"
        )
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "omnicast",
              JSONSerialization.isValidJSONObject(message.body),
              let data = try? JSONSerialization.data(withJSONObject: message.body),
              let request = try? JSONDecoder().decode(ExtensionBridgeRequest.self, from: data) else {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let response = await self.router.route(request)
            self.deliver(response)
        }
    }

    public func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: any Error
    ) {
        callbacks.showToast(error.localizedDescription)
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: any Error
    ) {
        callbacks.showToast(error.localizedDescription)
    }

    private func load(into webView: WKWebView) async {
        do {
            let scripts = try await makeScripts()
            let controller = webView.configuration.userContentController
            for source in scripts {
                controller.addUserScript(WKUserScript(
                    source: source,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                ))
            }
            webView.loadHTMLString(Self.html, baseURL: installedExtension.directoryURL)
        } catch {
            callbacks.showToast(error.localizedDescription)
            webView.loadHTMLString(
                Self.errorHTML(error.localizedDescription),
                baseURL: nil
            )
        }
    }

    private func makeScripts() async throws -> [String] {
        let react = try resource(named: "react.production.min", extension: "js")
        let reactDOM = try resource(named: "react-dom.production.min", extension: "js")
        let shim = try resource(named: "RaycastShim", extension: "js")
        let storedPreferences = try await persistence.preferences(
            extensionSlug: installedExtension.slug
        )
        let preferences = resolvedPreferences(stored: storedPreferences)
        let supportURL = directoryURL
            .appendingPathComponent("extension-support", isDirectory: true)
            .appendingPathComponent(installedExtension.slug, isDirectory: true)
        try FileManager.default.createDirectory(
            at: supportURL,
            withIntermediateDirectories: true
        )
        let context: JSONValue = .object([
            "preferences": .object(preferences),
            "environment": .object([
                "extensionName": .string(installedExtension.slug),
                "commandName": .string(command.name),
                "commandMode": .string(command.mode),
                "assetsPath": .string(
                    installedExtension.directoryURL
                        .appendingPathComponent("assets", isDirectory: true).path
                ),
                "supportPath": .string(supportURL.path),
                "ownerOrAuthorName": .string(
                    installedExtension.manifest.owner?.name
                        ?? installedExtension.manifest.author?.name
                        ?? ""
                )
            ])
        ])
        let contextScript = "globalThis.__omnicastContext=\(try javascriptLiteral(context));"
        let bundleURL = installedExtension.directoryURL
            .appendingPathComponent(".sc-build", isDirectory: true)
            .appendingPathComponent("\(command.name).js")
        let bundle = try String(contentsOf: bundleURL, encoding: .utf8)
        let boot = try bootScript(bundle: bundle)
        return [react, reactDOM, contextScript, shim, boot]
    }

    private func resolvedPreferences(
        stored: [String: JSONValue]
    ) -> [String: JSONValue] {
        var values: [String: JSONValue] = [:]
        for preference in installedExtension.manifest.preferences + command.preferences {
            if let value = preference.defaultValue {
                values[preference.name] = value
            }
        }
        values.merge(stored) { _, stored in stored }
        return values
    }

    private func resource(named name: String, extension fileExtension: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension) else {
            throw ExtensionHostError.missingResource("\(name).\(fileExtension)")
        }
        guard let source = try? String(contentsOf: url, encoding: .utf8) else {
            throw ExtensionHostError.invalidResource("\(name).\(fileExtension)")
        }
        return source
    }

    private func bootScript(bundle: String) throws -> String {
        let code = try javascriptLiteral(.string(bundle))
        let props: JSONValue = .object([
            "arguments": .object([:]),
            "launchType": .string("userInitiated")
        ])
        let propsLiteral = try javascriptLiteral(props)
        let mode = try javascriptLiteral(.string(command.mode))
        return """
        (function(){
          function require(name){
            if(name==="react")return globalThis.React;
            if(name==="react-dom"||name==="react-dom/client")return globalThis.ReactDOM;
            if(name==="react/jsx-runtime"||name==="react/jsx-dev-runtime"){
              return {
                Fragment:globalThis.React.Fragment,
                jsx:function(type,props,key){return globalThis.React.createElement(type,Object.assign({},props,key===undefined?{}:{key:key}));},
                jsxs:function(type,props,key){return globalThis.React.createElement(type,Object.assign({},props,key===undefined?{}:{key:key}));},
                jsxDEV:function(type,props,key){return globalThis.React.createElement(type,Object.assign({},props,key===undefined?{}:{key:key}));}
              };
            }
            if(name==="@raycast/api")return globalThis.__raycastAPI;
            throw new Error("Module "+name+" is not yet supported");
          }
          try{
            var module={exports:{}};
            var exports=module.exports;
            var execute=new Function("exports","require","module","__filename","__dirname",\(code));
            execute(exports,require,module,"/extension/index.js","/extension");
            var exported=module.exports&&module.exports.default?module.exports.default:module.exports;
            if(typeof exported!=="function")throw new Error("The command does not export a function");
            var props=\(propsLiteral);
            if(\(mode)==="no-view"){
              Promise.resolve(exported(props)).catch(function(error){throw error;});
            }else{
              globalThis.ReactDOM.createRoot(document.getElementById("root")).render(globalThis.React.createElement(exported,props));
            }
          }catch(error){
            var message=error&&error.stack?error.stack:String(error);
            document.getElementById("root").textContent=message;
            globalThis.webkit.messageHandlers.omnicast.postMessage({id:"boot",operation:"toast",payload:{message:String(error&&error.message?error.message:error)}});
          }
        })();
        """
    }

    private func javascriptLiteral(_ value: JSONValue) throws -> String {
        let data = try JSONSerialization.data(
            withJSONObject: value.foundationValue,
            options: [.fragmentsAllowed]
        )
        return String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "</", with: "<\\/")
    }

    private func deliver(_ response: ExtensionBridgeResponse) {
        guard let data = try? JSONEncoder().encode(response),
              let object = try? JSONSerialization.jsonObject(with: data),
              let responseData = try? JSONSerialization.data(withJSONObject: object),
              let literal = String(data: responseData, encoding: .utf8) else {
            return
        }
        webView?.evaluateJavaScript("globalThis.__omnicastReceive(\(literal));")
    }

    private static let html = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        :root { color-scheme: dark; font: 13px system-ui; background: transparent; color: #f5f5f5; }
        * { box-sizing: border-box; }
        html, body, #root { width: 100%; height: 100%; margin: 0; }
        body { background: #171717; }
        input { width: 100%; padding: 12px; border: 0; border-bottom: 1px solid #333; background: #202020; color: inherit; outline: none; }
        .raycastListBody, .raycastDetail { padding: 8px; }
        .raycastSection h3 { margin: 12px 8px 6px; color: #999; font-size: 11px; text-transform: uppercase; }
        .raycastListItem { display: flex; align-items: center; gap: 10px; min-height: 44px; padding: 8px 10px; border-radius: 8px; }
        .raycastListItem:hover { background: #2b2b2b; }
        .raycastListText { display: flex; flex: 1; flex-direction: column; min-width: 0; }
        .raycastListText small { color: #999; }
        .raycastActions { display: flex; gap: 6px; }
        .raycastAction { border: 0; border-radius: 6px; background: #3b3b3b; color: inherit; padding: 5px 8px; }
        .raycastMarkdown { white-space: pre-wrap; line-height: 1.5; }
      </style>
    </head>
    <body><main id="root"></main></body>
    </html>
    """

    private static func errorHTML(_ message: String) -> String {
        let escaped = message
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return "<html><body><pre>\(escaped)</pre></body></html>"
    }
}
