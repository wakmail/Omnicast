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

public struct ExtensionConsoleMessage: Equatable, Sendable {
    public let level: String
    public let message: String

    public init(level: String, message: String) {
        self.level = level
        self.message = message
    }
}

@MainActor
public final class ExtensionHost: NSObject, WKScriptMessageHandler, WKNavigationDelegate, WKUIDelegate {
    public let installedExtension: InstalledExtension
    public let command: ExtensionCommandManifest

    private let directoryURL: URL
    private let persistence: ExtensionPersistence
    private let callbacks: ExtensionHostCallbacks
    private let router: ExtensionBridgeRouter
    private let nodeBridge = ExtensionNodeBridge()
    private weak var webView: WKWebView?
    private var commandBootScript: String?

    public private(set) var consoleMessages: [ExtensionConsoleMessage] = []
    public private(set) var renderedItemCount = 0

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
        controller.add(self, name: "log")
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        configuration.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
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
        webView?.configuration.userContentController.removeScriptMessageHandler(
            forName: "log"
        )
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        if message.name == "log" {
            captureLog(message.body)
            return
        }
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
        runJavaScriptTextInputPanelWithPrompt prompt: String,
        defaultText: String?,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (String?) -> Void
    ) {
        guard prompt == "omnicast.sync" else {
            completionHandler(nil)
            return
        }
        completionHandler(nodeBridge.synchronousResponse(for: defaultText))
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

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let commandBootScript else { return }
        webView.evaluateJavaScript(commandBootScript) { [weak self] _, error in
            guard let self, let error else { return }
            let nsError = error as NSError
            let message = nsError.userInfo["WKJavaScriptExceptionMessage"] as? String
                ?? nsError.localizedDescription
            self.captureLog([
                "type": "console",
                "level": "error",
                "message": message
            ])
        }
    }

    private func load(into webView: WKWebView) async {
        do {
            let scripts = try await makeScripts()
            let controller = webView.configuration.userContentController
            for source in scripts.userScripts {
                controller.addUserScript(WKUserScript(
                    source: source,
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                ))
            }
            commandBootScript = scripts.boot
            webView.loadHTMLString(Self.html, baseURL: installedExtension.directoryURL)
        } catch {
            callbacks.showToast(error.localizedDescription)
            webView.loadHTMLString(
                Self.errorHTML(error.localizedDescription),
                baseURL: nil
            )
        }
    }

    private func makeScripts() async throws -> (userScripts: [String], boot: String) {
        let react = try resource(named: "react.production.min", extension: "js")
        let reactDOM = try resource(named: "react-dom.production.min", extension: "js")
        let nodeShim = try resource(named: "NodeShim", extension: "js")
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
        #if arch(arm64)
        let architecture = "arm64"
        #elseif arch(x86_64)
        let architecture = "x64"
        #else
        let architecture = "unknown"
        #endif
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
                "extensionPath": .string(installedExtension.directoryURL.path),
                "homePath": .string(NSHomeDirectory()),
                "temporaryPath": .string(FileManager.default.temporaryDirectory.path),
                "hostName": .string(ProcessInfo.processInfo.hostName),
                "architecture": .string(architecture),
                "processEnv": .object(
                    ProcessInfo.processInfo.environment.mapValues(JSONValue.string)
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
        return ([react, reactDOM, contextScript, nodeShim, shim], boot)
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
            if(globalThis.__omnicastModules&&name in globalThis.__omnicastModules)return globalThis.__omnicastModules[name];
            throw new Error('Cannot require unknown module ' + JSON.stringify(name));
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
            console.error(message);
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

    private func captureLog(_ body: Any) {
        guard let value = body as? [String: Any],
              let type = value["type"] as? String else {
            return
        }
        if type == "rendered", let count = value["count"] as? NSNumber {
            renderedItemCount = count.intValue
            return
        }
        if type == "console",
           let level = value["level"] as? String,
           let message = value["message"] as? String {
            consoleMessages.append(ExtensionConsoleMessage(level: level, message: message))
        }
    }

    private static let html = """
    <!doctype html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style>
        :root { color-scheme: dark; font: 13px system-ui; background: transparent; color: rgba(255,255,255,.92); }
        * { box-sizing: border-box; }
        html, body, #root { width: 100%; height: 100%; margin: 0; }
        body { overflow: hidden; background: rgba(7,9,13,.92); }
        .raycastList { height: 100%; }
        .raycastSearch { display: flex; align-items: center; gap: 10px; height: 56px; padding: 0 16px; border-bottom: 1px solid rgba(255,255,255,.08); }
        .raycastSearch input { flex: 1; min-width: 0; border: 0; background: transparent; color: inherit; outline: none; font: 20px system-ui; }
        .raycastSearch input::placeholder { color: rgba(255,255,255,.5); }
        .raycastDropdown { border: 1px solid rgba(255,255,255,.08); border-radius: 6px; background: rgba(255,255,255,.08); color: inherit; padding: 5px 8px; }
        .raycastLoading { color: rgba(255,255,255,.74); }
        .raycastListBody { height: calc(100% - 56px); overflow: auto; padding: 6px; }
        .raycastDetail { height: 100%; overflow: auto; padding: 16px; }
        .raycastSection h3 { display: flex; justify-content: space-between; margin: 8px 10px 4px; color: rgba(255,255,255,.74); font-size: 11px; font-weight: 600; }
        .raycastSection h3 small { font-weight: 400; }
        .raycastListItem { display: flex; align-items: center; gap: 12px; min-height: 40px; padding: 8px 10px; border-radius: 8px; }
        .raycastListItem:hover, .raycastListItem.selected { background: rgba(255,255,255,.10); }
        .raycastIcon { display: grid; width: 24px; height: 24px; place-items: center; color: rgb(78,162,255); }
        .raycastListText { display: flex; flex: 1; flex-direction: column; min-width: 0; }
        .raycastListText strong { overflow: hidden; font-size: 14px; font-weight: 500; text-overflow: ellipsis; white-space: nowrap; }
        .raycastListText small, .raycastAccessories { color: rgba(255,255,255,.74); }
        .raycastAccessories { display: flex; gap: 18px; }
        .raycastActions { display: none; position: fixed; z-index: 10; right: 14px; bottom: 14px; flex-direction: column; gap: 4px; width: 210px; padding: 12px; border: 1px solid rgba(255,255,255,.08); border-radius: 10px; background: rgba(24,24,28,.96); box-shadow: 0 14px 40px rgba(0,0,0,.45); }
        .actionPanelOpen .raycastListItem.selected > .raycastActions { display: flex; }
        .raycastAction { display: flex; justify-content: space-between; border: 0; border-radius: 6px; background: transparent; color: inherit; padding: 7px 8px; text-align: left; }
        .raycastAction:hover, .raycastAction:focus { background: rgba(255,255,255,.10); outline: none; }
        .raycastAction kbd { color: rgba(255,255,255,.74); }
        .raycastEmpty { display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 48px; color: rgba(255,255,255,.74); }
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
