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

// src/tools/killall-process.ts
var killall_process_exports = {};
__export(killall_process_exports, {
  confirmation: () => confirmation,
  default: () => killAllProcesses
});
module.exports = __toCommonJS(killall_process_exports);
var import_child_process = require("child_process");

// src/utils/platform.ts
var platform = process.platform;
var isMac = platform === "darwin";
var isWindows = platform === "win32";
function encodePowerShellCommand(script) {
  return Buffer.from(script, "utf16le").toString("base64");
}
function getKillAllCommand(processName, force = false) {
  if (isWindows) {
    const psName = processName.replace(/'/g, "''");
    const psScript = `Get-Process -Name '${psName}' -ErrorAction SilentlyContinue | Stop-Process ${force ? "-Force" : ""}`;
    return `powershell -NoLogo -NoProfile -EncodedCommand ${encodePowerShellCommand(psScript)}`;
  }
  const escaped = processName.replace(/'/g, "'\\''");
  return force ? `PROC_NAME='${escaped}' zsh -c 'sudo killall "$PROC_NAME"'` : `killall '${escaped}'`;
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

// src/tools/killall-process.ts
async function killAllProcesses(input) {
  const processName = input.processName.trim();
  if (!processName || processName === "-") {
    throw new Error("A valid process name is required");
  }
  return new Promise((resolve, reject) => {
    const command = getKillAllCommand(processName, input.force);
    (0, import_child_process.exec)(command, (err) => {
      if (err) {
        const errorHelp = getPlatformSpecificErrorHelp("kill", input.force ?? false);
        reject(new Error(`${errorHelp.title}: ${err.message}`));
        return;
      }
      resolve({
        success: true,
        message: `Killed all "${processName}" processes`
      });
    });
  });
}
var confirmation = async (input) => {
  const info = [{ name: "Process Name", value: input.processName }];
  if (input.force) {
    info.push({ name: "Force", value: "Yes (elevated privileges)" });
  }
  return { info };
};
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  confirmation
});
