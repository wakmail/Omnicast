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

// src/tools/list-processes.ts
var list_processes_exports = {};
__export(list_processes_exports, {
  default: () => listProcesses
});
module.exports = __toCommonJS(list_processes_exports);

// src/utils/process.ts
var import_child_process = require("child_process");
var import_fs = require("fs");
var import_promises = require("fs/promises");

// src/utils/platform.ts
var platform = process.platform;
var isMac = platform === "darwin";
var isWindows = platform === "win32";
function encodePowerShellCommand(script) {
  return Buffer.from(script, "utf16le").toString("base64");
}
var WINDOWS_PROCESS_LIST_SCRIPT = `
$result = Get-Process | Where-Object { $_.Id -ne 0 } | ForEach-Object {
  [PSCustomObject]@{
    pid = $_.Id
    name = $_.ProcessName
    cpu = 0
    mem = [math]::Round($_.WorkingSet64 / 1KB, 0)
    path = if ($_.Path) { $_.Path } else { '' }
  }
}
$result | ConvertTo-Json -Compress
`;
function getProcessListCommandSpec() {
  if (isWindows) {
    return {
      executable: "powershell",
      args: ["-NoLogo", "-NoProfile", "-EncodedCommand", encodePowerShellCommand(WINDOWS_PROCESS_LIST_SCRIPT)]
    };
  }
  return {
    executable: "ps",
    args: ["-eo", "pid,ppid,pcpu,rss,comm"]
  };
}
function parseProcessLine(line) {
  const trimmed = line.trim();
  if (!trimmed) return null;
  const match = trimmed.match(/(\d+)\s+(\d+)\s+(\d+[.|,]\d+)\s+(\d+)\s+(.*)/);
  if (!match) return null;
  const [, id, pid, cpu, mem, path] = match;
  return {
    id: parseInt(id),
    pid: parseInt(pid),
    cpu: parseFloat(cpu),
    mem: parseInt(mem),
    path,
    processName: path.match(/[^/]*$/)?.[0] ?? ""
  };
}
function parseWindowsProcesses(output) {
  try {
    const data = JSON.parse(output);
    const processes = Array.isArray(data) ? data : [data];
    return processes.map((proc) => ({
      id: proc.pid,
      pid: 0,
      cpu: proc.cpu,
      mem: proc.mem,
      path: proc.path || "",
      processName: proc.name || ""
    }));
  } catch {
    console.error("Failed to parse Windows process output");
    return [];
  }
}
function getProcessType(path) {
  if (isMac) {
    if (path.includes(".prefPane")) return "prefPane";
    if (path.includes(".app/")) return "app";
    return "binary";
  }
  if (isWindows) {
    const lowerPath = path.toLowerCase();
    const isApp = lowerPath.endsWith(".exe") && (lowerPath.includes("program files") || lowerPath.includes("applications"));
    return isApp ? "app" : "binary";
  }
  return "binary";
}
function getAppName(path, processName) {
  if (isMac) {
    return path.match(/(?<=\/)[^/]+(?=\.app\/)/)?.[0];
  }
  if (isWindows) {
    return processName.replace(/\.exe$/i, "");
  }
  return processName;
}

// src/utils/process.ts
var EXEC_OPTIONS = { maxBuffer: 10 * 1024 * 1024 };
function executeCommandWithOutput(command) {
  return new Promise((resolve, reject) => {
    (0, import_child_process.execFile)(command.executable, command.args, EXEC_OPTIONS, (error, stdout) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(stdout);
    });
  });
}
async function fetchRunningProcesses() {
  const stdout = await executeCommandWithOutput(getProcessListCommandSpec());
  const parsed = isWindows ? parseWindowsProcesses(stdout) : stdout.split("\n").map(parseProcessLine).filter(Boolean);
  return parsed.filter((p) => p?.processName).map((p) => {
    const path = p.path || "";
    const processName = p.processName || "";
    const type = getProcessType(path);
    return {
      id: p.id || 0,
      pid: p.pid || 0,
      cpu: p.cpu || 0,
      mem: p.mem || 0,
      type,
      path,
      processName,
      appName: type === "app" ? getAppName(path, processName) : void 0
    };
  }).filter((p) => p.processName !== "");
}

// src/tools/list-processes.ts
var sortProcesses = (processes, field = "mem", order = "desc") => {
  return [...processes].sort((a, b) => {
    const valueA = a[field];
    const valueB = b[field];
    if (valueA === valueB) return 0;
    if (valueA === void 0) return 1;
    if (valueB === void 0) return -1;
    const comparison = valueA < valueB ? -1 : 1;
    return order === "desc" ? -comparison : comparison;
  });
};
var filterProcessesBySearchTerm = (processes, searchTerms) => {
  if (!searchTerms?.length) return processes;
  return processes.filter((p) => {
    const searchIn = `${p.path} ${p.processName} ${p.appName || ""}`.toLowerCase();
    return searchTerms.some((term) => searchIn.includes(term.toLowerCase()));
  });
};
var validateResults = (processes, searchTerms) => {
  if (processes.length === 0 && searchTerms?.length) {
    throw new Error(`No processes found matching "${searchTerms.join(", ")}"`);
  }
};
async function listProcesses(input) {
  const processes = await fetchRunningProcesses();
  const filteredProcesses = filterProcessesBySearchTerm(processes, input?.searchTerm);
  validateResults(filteredProcesses, input?.searchTerm);
  return sortProcesses(filteredProcesses, input?.sortBy, input?.sortOrder);
}
