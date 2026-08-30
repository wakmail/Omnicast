"use strict";
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/tools/kill-process.ts
var kill_process_exports = {};
__export(kill_process_exports, {
  confirmation: () => confirmation,
  default: () => killProcess
});
module.exports = __toCommonJS(kill_process_exports);
var import_child_process = require("child_process");

// src/utils/platform.ts
var platform = process.platform;
var isMac = platform === "darwin";
var isWindows = platform === "win32";
function getKillCommand(pid, force = false) {
  if (isWindows) {
    return force ? `taskkill /F /PID ${pid}` : `taskkill /PID ${pid}`;
  }
  return force ? `zsh -c 'sudo kill -9 ${pid}'` : `kill -9 ${pid}`;
}
function getPlatformSpecificErrorHelp(action, isForceAction) {
  const actionLabel = action === "restart" ? "Restart" : "Kill";
  const baseFailureMessage = action === "restart" ? "The process could not be restarted. It may have already exited or require elevated privileges." : "The process could not be terminated. It may have already exited or require elevated privileges.";
  if (isMac && isForceAction) {
    return {
      title: `Failed to Force ${actionLabel} Process`,
      message: "Please ensure that touch ID/password prompt is enabled for sudo",
      helpUrl: "https://dev.to/siddhantkcode/enable-touch-id-authentication-for-sudo-on-macos-sonoma-14x-4d28"
    };
  }
  if (isWindows && isForceAction) {
    return {
      title: `Failed to Force ${actionLabel} Process`,
      message: "Administrative privileges may be required. Try running as administrator."
    };
  }
  return {
    title: `Failed to ${actionLabel} Process`,
    message: baseFailureMessage
  };
}

// src/tools/kill-process.ts
async function killProcess(input) {
  return new Promise((resolve, reject) => {
    const command = getKillCommand(input.id, input.force);
    (0, import_child_process.exec)(command, (killErr) => {
      if (killErr) {
        const errorHelp = getPlatformSpecificErrorHelp("kill", input.force || false);
        const error = new Error(`${errorHelp.title}: ${killErr.message}`);
        reject(error);
        return;
      }
      const processInfo = input.processName ? `${input.processName} ` : "";
      resolve({
        success: true,
        message: `Killed process: ${processInfo}(PID: ${input.id})`
      });
    });
  });
}
var confirmation = async (input) => {
  const info = [];
  if (input.processName) {
    info.push({ name: "Process Name", value: input.processName });
  }
  info.push({ name: "PID", value: String(input.id) });
  if (input.path) {
    info.push({ name: "Path", value: input.path });
  }
  return { info };
};
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  confirmation
});
