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

// src/index.tsx
var index_exports = {};
__export(index_exports, {
  default: () => ProcessList
});
module.exports = __toCommonJS(index_exports);
var import_api = require("@raycast/api");

// node_modules/pretty-bytes/index.js
var BYTE_UNITS = [
  "B",
  "kB",
  "MB",
  "GB",
  "TB",
  "PB",
  "EB",
  "ZB",
  "YB"
];
var BIBYTE_UNITS = [
  "B",
  "KiB",
  "MiB",
  "GiB",
  "TiB",
  "PiB",
  "EiB",
  "ZiB",
  "YiB"
];
var BIT_UNITS = [
  "b",
  "kbit",
  "Mbit",
  "Gbit",
  "Tbit",
  "Pbit",
  "Ebit",
  "Zbit",
  "Ybit"
];
var BIBIT_UNITS = [
  "b",
  "kibit",
  "Mibit",
  "Gibit",
  "Tibit",
  "Pibit",
  "Eibit",
  "Zibit",
  "Yibit"
];
var toLocaleString = (number, locale, options) => {
  let result = number;
  if (typeof locale === "string" || Array.isArray(locale)) {
    result = number.toLocaleString(locale, options);
  } else if (locale === true || options !== void 0) {
    result = number.toLocaleString(void 0, options);
  }
  return result;
};
var log10 = (numberOrBigInt) => {
  if (typeof numberOrBigInt === "number") {
    return Math.log10(numberOrBigInt);
  }
  const string = numberOrBigInt.toString(10);
  return string.length + Math.log10(`0.${string.slice(0, 15)}`);
};
var log = (numberOrBigInt) => {
  if (typeof numberOrBigInt === "number") {
    return Math.log(numberOrBigInt);
  }
  return log10(numberOrBigInt) * Math.log(10);
};
var divide = (numberOrBigInt, divisor) => {
  if (typeof numberOrBigInt === "number") {
    return numberOrBigInt / divisor;
  }
  const integerPart = numberOrBigInt / BigInt(divisor);
  const remainder = numberOrBigInt % BigInt(divisor);
  return Number(integerPart) + Number(remainder) / divisor;
};
var applyFixedWidth = (result, fixedWidth) => {
  if (fixedWidth === void 0) {
    return result;
  }
  if (typeof fixedWidth !== "number" || !Number.isSafeInteger(fixedWidth) || fixedWidth < 0) {
    throw new TypeError(`Expected fixedWidth to be a non-negative integer, got ${typeof fixedWidth}: ${fixedWidth}`);
  }
  if (fixedWidth === 0) {
    return result;
  }
  return result.length < fixedWidth ? result.padStart(fixedWidth, " ") : result;
};
var buildLocaleOptions = (options) => {
  const { minimumFractionDigits, maximumFractionDigits } = options;
  if (minimumFractionDigits === void 0 && maximumFractionDigits === void 0) {
    return void 0;
  }
  return {
    ...minimumFractionDigits !== void 0 && { minimumFractionDigits },
    ...maximumFractionDigits !== void 0 && { maximumFractionDigits },
    roundingMode: "trunc"
  };
};
function prettyBytes(number, options) {
  if (typeof number !== "bigint" && !Number.isFinite(number)) {
    throw new TypeError(`Expected a finite number, got ${typeof number}: ${number}`);
  }
  options = {
    bits: false,
    binary: false,
    space: true,
    nonBreakingSpace: false,
    ...options
  };
  const UNITS = options.bits ? options.binary ? BIBIT_UNITS : BIT_UNITS : options.binary ? BIBYTE_UNITS : BYTE_UNITS;
  const separator = options.space ? options.nonBreakingSpace ? "\xA0" : " " : "";
  const isZero = typeof number === "number" ? number === 0 : number === 0n;
  if (options.signed && isZero) {
    const result2 = ` 0${separator}${UNITS[0]}`;
    return applyFixedWidth(result2, options.fixedWidth);
  }
  const isNegative = number < 0;
  const prefix = isNegative ? "-" : options.signed ? "+" : "";
  if (isNegative) {
    number = -number;
  }
  const localeOptions = buildLocaleOptions(options);
  let result;
  if (number < 1) {
    const numberString = toLocaleString(number, options.locale, localeOptions);
    result = prefix + numberString + separator + UNITS[0];
  } else {
    const exponent = Math.min(Math.floor(options.binary ? log(number) / Math.log(1024) : log10(number) / 3), UNITS.length - 1);
    number = divide(number, (options.binary ? 1024 : 1e3) ** exponent);
    if (!localeOptions) {
      const minPrecision = Math.max(3, Math.floor(number).toString().length);
      number = number.toPrecision(minPrecision);
    }
    const numberString = toLocaleString(Number(number), options.locale, localeOptions);
    const unit = UNITS[exponent];
    result = prefix + numberString + separator + unit;
  }
  return applyFixedWidth(result, options.fixedWidth);
}

// src/index.tsx
var import_react2 = require("react");

// src/hooks/use-interval.tsx
var import_react = require("react");
var noop = () => {
};
function useInterval(callback, delay) {
  const savedCallback = (0, import_react.useRef)(noop);
  (0, import_react.useEffect)(() => {
    savedCallback.current = callback;
  }, [callback]);
  (0, import_react.useEffect)(() => {
    if (delay === null) {
      return;
    }
    savedCallback.current();
    const refreshEnabled = delay > 0;
    if (!refreshEnabled) {
      return;
    }
    const interval = Math.max(delay, 1e3);
    const id = setInterval(() => savedCallback.current(), interval);
    return () => clearInterval(id);
  }, [delay]);
}
var use_interval_default = useInterval;

// src/utils/platform.ts
var platform = process.platform;
var isMac = platform === "darwin";
var isWindows = platform === "win32";
function encodePowerShellCommand(script) {
  return Buffer.from(script, "utf16le").toString("base64");
}
function quotePosixShellArgument(value) {
  return `'${value.replace(/'/g, "'\\''")}'`;
}
function escapePowerShellSingleQuotedString(value) {
  return value.replace(/'/g, "''");
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
var WINDOWS_CPU_PERFORMANCE_SCRIPT = `
$cpuCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$processes = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process | Where-Object { $_.IDProcess -ne 0 -and $_.Name -ne '_Total' -and $_.Name -ne 'Idle' }
$result = $processes | ForEach-Object {
  [PSCustomObject]@{
    pid = $_.IDProcess
    cpu = [math]::Round($_.PercentProcessorTime / $cpuCores, 1)
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
function getProcessPerformanceCommandSpec() {
  if (isWindows) {
    return {
      executable: "powershell",
      args: ["-NoLogo", "-NoProfile", "-EncodedCommand", encodePowerShellCommand(WINDOWS_CPU_PERFORMANCE_SCRIPT)]
    };
  }
  return getProcessListCommandSpec();
}
function getKillCommand(pid, force = false) {
  if (isWindows) {
    return force ? `taskkill /F /PID ${pid}` : `taskkill /PID ${pid}`;
  }
  return force ? `zsh -c 'sudo kill -9 ${pid}'` : `kill -9 ${pid}`;
}
function getKillTreeCommand(pid, force = false) {
  if (isWindows) {
    return force ? `taskkill /F /T /PID ${pid}` : `taskkill /T /PID ${pid}`;
  }
  const signal = force ? "-9" : "-TERM";
  const killCommand = force ? "sudo kill" : "kill";
  const script = `
kill_tree() {
  local target_pid="$1"
  local child_pid
  for child_pid in $(pgrep -P "$target_pid"); do
    kill_tree "$child_pid"
  done
  ${killCommand} ${signal} "$target_pid" 2>/dev/null || true
}
kill_tree ${pid}
`;
  return `zsh -c ${quotePosixShellArgument(script)}`;
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
function getMacBundlePath(path, extension) {
  const bundlePath = path.match(new RegExp(`(.+\\${extension})(?:\\/.*)?$`))?.[1];
  return bundlePath ?? null;
}
function getRestartLaunchPath(process2) {
  const path = process2.path.trim();
  if (!path || path === "-") {
    return null;
  }
  if (isMac) {
    if (process2.type === "app" || process2.type === "aggregatedApp") {
      return getMacBundlePath(path, ".app") ?? path;
    }
    if (process2.type === "prefPane") {
      return getMacBundlePath(path, ".prefPane") ?? path;
    }
    return path.startsWith("/") ? path : null;
  }
  if (isWindows) {
    return path;
  }
  return null;
}
function hasRestartLaunchPath(process2) {
  return getRestartLaunchPath(process2) !== null;
}
function getRestartCommand(process2) {
  const launchPath = getRestartLaunchPath(process2);
  if (!launchPath) {
    return null;
  }
  if (isMac) {
    if (process2.type === "app" || process2.type === "aggregatedApp" || process2.type === "prefPane") {
      return `open ${quotePosixShellArgument(launchPath)}`;
    }
    return `nohup ${quotePosixShellArgument(launchPath)} >/dev/null 2>&1 &`;
  }
  if (isWindows) {
    const escapedPath = escapePowerShellSingleQuotedString(launchPath);
    const script = `
$path = '${escapedPath}'
if (-not (Test-Path -LiteralPath $path)) {
  throw "Launch path not found: $path"
}
$workingDirectory = Split-Path -LiteralPath $path -Parent
if ([string]::IsNullOrWhiteSpace($workingDirectory)) {
  Start-Process -FilePath $path
} else {
  Start-Process -FilePath $path -WorkingDirectory $workingDirectory
}
`;
    return `powershell -NoLogo -NoProfile -EncodedCommand ${encodePowerShellCommand(script)}`;
  }
  return null;
}
function getProcessRunningCheckCommand(pid) {
  if (isWindows) {
    const script = `
$process = Get-Process -Id ${pid} -ErrorAction SilentlyContinue
if ($null -eq $process) { exit 1 }
exit 0
`;
    return `powershell -NoLogo -NoProfile -EncodedCommand ${encodePowerShellCommand(script)}`;
  }
  if (isMac) {
    return `ps -p ${pid} >/dev/null 2>&1`;
  }
  return `kill -0 ${pid}`;
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
function parseWindowsPerformanceData(output) {
  const cpuMap = /* @__PURE__ */ new Map();
  try {
    const data = JSON.parse(output);
    const processes = Array.isArray(data) ? data : [data];
    for (const proc of processes) {
      if (proc?.pid) {
        cpuMap.set(proc.pid, proc.cpu ?? 0);
      }
    }
  } catch {
    console.error("Failed to parse Windows performance output");
  }
  return cpuMap;
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
function getFileIcon(process2) {
  if (isMac) {
    if (process2.type === "prefPane") {
      return { fileIcon: process2.path?.replace(/(.+\.prefPane)(.+)/, "$1") ?? "" };
    }
    if (process2.type === "app" || process2.type === "aggregatedApp") {
      return { fileIcon: process2.path?.replace(/(.+\.app)(.+)/, "$1") ?? "" };
    }
    return "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/ExecutableBinaryIcon.icns";
  }
  if (isWindows) {
    if (process2.type === "app") {
      return { fileIcon: process2.path };
    }
    return "\u{1F5A5}\uFE0F";
  }
  return "\u2699\uFE0F";
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

// src/utils/process-grouping.ts
function getOuterAppBundlePath(path) {
  return path.match(/^(.+?\.app)(?:\/|$)/)?.[1];
}
function getAppNameFromBundlePath(bundlePath) {
  return bundlePath.match(/([^/]+)\.app$/)?.[1] ?? bundlePath;
}
function findMainProcess(processes, appName) {
  const processIds = new Set(processes.map((process2) => process2.id));
  return processes.find((process2) => process2.processName === appName) ?? processes.find((process2) => !processIds.has(process2.pid)) ?? processes[0];
}
function aggregateAppProcesses(bundlePath, processes) {
  const appName = getAppNameFromBundlePath(bundlePath);
  const mainProcess = findMainProcess(processes, appName);
  const childProcesses = processes.filter((process2) => process2.id !== mainProcess.id);
  return {
    ...mainProcess,
    cpu: processes.reduce((total, process2) => total + process2.cpu, 0),
    mem: processes.reduce((total, process2) => total + process2.mem, 0),
    type: "aggregatedApp",
    path: mainProcess.path || bundlePath,
    processName: mainProcess.processName || appName,
    appName,
    childProcessCount: childProcesses.length,
    childProcessIds: childProcesses.map((process2) => process2.id)
  };
}
function groupRelatedProcesses(processes) {
  const appGroups = /* @__PURE__ */ new Map();
  const ungroupedProcesses = [];
  for (const process2 of processes) {
    const bundlePath = getOuterAppBundlePath(process2.path);
    if (!bundlePath) {
      ungroupedProcesses.push(process2);
      continue;
    }
    const group = appGroups.get(bundlePath);
    if (group) {
      group.push(process2);
    } else {
      appGroups.set(bundlePath, [process2]);
    }
  }
  appGroups.forEach((group, bundlePath) => {
    ungroupedProcesses.push(group.length > 1 ? aggregateAppProcesses(bundlePath, group) : group[0]);
  });
  return ungroupedProcesses;
}

// src/utils/refresh.ts
function shouldRefreshProcesses(launchType) {
  return launchType !== "background";
}

// src/utils/process.ts
var import_child_process = require("child_process");
var import_fs = require("fs");
var import_promises = require("fs/promises");
var EXEC_OPTIONS = { maxBuffer: 10 * 1024 * 1024 };
var PROCESS_EXIT_POLL_INTERVAL_MS = 250;
var PROCESS_EXIT_TIMEOUT_MS = 5e3;
function executeCommand(command) {
  return new Promise((resolve, reject) => {
    (0, import_child_process.exec)(command, EXEC_OPTIONS, (error) => {
      if (error) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}
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
function sleepForProcessExitPollInterval() {
  return new Promise((resolve) => {
    setTimeout(resolve, PROCESS_EXIT_POLL_INTERVAL_MS);
  });
}
async function isProcessRunning(processId) {
  try {
    await executeCommand(getProcessRunningCheckCommand(processId));
    return true;
  } catch {
    return false;
  }
}
async function waitForProcessExit(processId) {
  const timeoutAt = Date.now() + PROCESS_EXIT_TIMEOUT_MS;
  while (Date.now() < timeoutAt) {
    if (!await isProcessRunning(processId)) {
      return;
    }
    await sleepForProcessExitPollInterval();
  }
  throw new Error("The process did not fully exit before restart.");
}
async function assertRestartLaunchPathExists(process2) {
  const launchPath = getRestartLaunchPath(process2);
  if (!launchPath) {
    throw new Error("The selected process cannot be restarted because its launch path is unavailable.");
  }
  try {
    await (0, import_promises.access)(launchPath, import_fs.constants.F_OK);
  } catch {
    throw new Error("The selected process cannot be restarted because its launch path no longer exists.");
  }
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
async function fetchProcessPerformance() {
  if (!isWindows) {
    return /* @__PURE__ */ new Map();
  }
  try {
    return parseWindowsPerformanceData(await executeCommandWithOutput(getProcessPerformanceCommandSpec()));
  } catch (error) {
    console.error("Failed to fetch CPU performance data:", error);
    return /* @__PURE__ */ new Map();
  }
}
async function terminateProcess(processId, force = false) {
  await executeCommand(getKillCommand(processId, force));
}
async function terminateProcessesByName(processName, force = false) {
  await executeCommand(getKillAllCommand(processName, force));
}
async function terminateProcessTree(processId, force = false) {
  await executeCommand(getKillTreeCommand(processId, force));
}
async function relaunchProcess(process2) {
  if (!hasRestartLaunchPath(process2)) {
    throw new Error("The selected process cannot be restarted because its launch path is unavailable.");
  }
  await assertRestartLaunchPathExists(process2);
  const restartCommand = getRestartCommand(process2);
  if (!restartCommand) {
    throw new Error("The selected process does not have a supported restart command on this platform.");
  }
  await executeCommand(restartCommand);
}
async function restartProcess(process2, force = false) {
  if (!hasRestartLaunchPath(process2)) {
    throw new Error("The selected process cannot be restarted because its launch path is unavailable.");
  }
  try {
    await terminateProcessTree(process2.id, force);
  } catch (error) {
    const help = getPlatformSpecificErrorHelp("restart", force);
    const details = error instanceof Error ? error.message : "Unknown error";
    const message = help.message ? `${help.message}: ${details}` : details;
    throw new Error(message);
  }
  await waitForProcessExit(process2.id);
  await relaunchProcess(process2);
}

// src/index.tsx
var import_jsx_runtime = require("react/jsx-runtime");
var APP_GROUPING_STORAGE_KEY = "kill-process.app-grouping-enabled";
var SORT_BY_DROPDOWN_ID = "kill-process.sort-by";
var DEFAULT_SORT_BY = "cpu";
var DEFAULT_APP_GROUPING_ENABLED = true;
var parseBooleanLike = (value) => {
  if (value == null) {
    return null;
  }
  if (value === true || value === "true" || value === 1 || value === "1") {
    return true;
  }
  if (value === false || value === "false" || value === 0 || value === "0") {
    return false;
  }
  return null;
};
var isSortBy = (value) => {
  return value === "cpu" || value === "memory";
};
function ProcessList() {
  const canRefreshProcesses = shouldRefreshProcesses(import_api.environment.launchType);
  const [fetchResult, setFetchResult] = (0, import_react2.useState)([]);
  const [visibleProcesses, setVisibleProcesses] = (0, import_react2.useState)([]);
  const [fetchError, setFetchError] = (0, import_react2.useState)();
  const [isLoadingProcesses, setIsLoadingProcesses] = (0, import_react2.useState)(canRefreshProcesses);
  const [query, setQuery] = (0, import_react2.useState)("");
  const preferences = (0, import_api.getPreferenceValues)();
  const shouldSearchInPaths = preferences.shouldSearchInPaths;
  const shouldSearchInPid = preferences.shouldSearchInPid;
  const shouldPrioritizeAppsWhenFiltering = preferences.shouldPrioritizeAppsWhenFiltering;
  const shouldShowPID = preferences.shouldShowPID;
  const shouldShowPath = preferences.shouldShowPath;
  const refreshDuration = +preferences.refreshDuration;
  const closeWindowAfterKill = preferences.closeWindowAfterKill;
  const clearSearchBarAfterKill = preferences.clearSearchBarAfterKill;
  const goToRootAfterKill = preferences.goToRootAfterKill;
  const skipConfirmation = preferences.skipConfirmation;
  const [sortBy, setSortBy] = (0, import_react2.useState)(DEFAULT_SORT_BY);
  const [isAppGroupingEnabled, setIsAppGroupingEnabled] = (0, import_react2.useState)(DEFAULT_APP_GROUPING_ENABLED);
  const isFetchingProcesses = (0, import_react2.useRef)(false);
  const [cpuCache, setCpuCache] = (0, import_react2.useState)(/* @__PURE__ */ new Map());
  (0, import_react2.useEffect)(() => {
    const loadAppGrouping = async () => {
      const stored = await import_api.LocalStorage.getItem(APP_GROUPING_STORAGE_KEY);
      if (typeof stored === "boolean") {
        setIsAppGroupingEnabled(stored);
        return;
      }
      const parsed = parseBooleanLike(stored);
      if (parsed == null) {
        return;
      }
      setIsAppGroupingEnabled(parsed);
      await import_api.LocalStorage.setItem(APP_GROUPING_STORAGE_KEY, parsed);
    };
    void loadAppGrouping();
  }, []);
  const fetchProcesses = (showErrorToast = false) => {
    if (isFetchingProcesses.current) {
      if (showErrorToast) {
        (0, import_api.showToast)({ title: "Refresh already in progress", style: import_api.Toast.Style.Animated });
      }
      return;
    }
    isFetchingProcesses.current = true;
    setIsLoadingProcesses(true);
    setFetchError(void 0);
    fetchRunningProcesses().then((processes) => {
      if (isWindows && cpuCache.size > 0) {
        processes = processes.map((proc) => {
          const cachedCpu = cpuCache.get(proc.id);
          return cachedCpu !== void 0 ? { ...proc, cpu: cachedCpu } : proc;
        });
      }
      setFetchResult(processes);
      if (isWindows) {
        fetchProcessPerformance().then((cpuData) => {
          if (cpuData.size > 0) {
            setCpuCache(cpuData);
            setFetchResult(
              (currentProcesses) => currentProcesses.map((proc) => {
                const cpu = cpuData.get(proc.id);
                return cpu !== void 0 ? { ...proc, cpu } : proc;
              })
            );
          }
        });
      }
    }).catch((err) => {
      console.error("Failed to fetch processes:", err);
      const message = err instanceof Error ? err.message : "Unknown error";
      setFetchError(message);
      if (showErrorToast) {
        (0, import_api.showToast)({
          title: "Failed to fetch processes",
          style: import_api.Toast.Style.Failure,
          message
        });
      }
    }).finally(() => {
      isFetchingProcesses.current = false;
      setIsLoadingProcesses(false);
    });
  };
  use_interval_default(fetchProcesses, canRefreshProcesses ? refreshDuration : null);
  (0, import_react2.useEffect)(() => {
    let processes = [...fetchResult];
    if (isAppGroupingEnabled) {
      processes = groupRelatedProcesses(processes);
    }
    processes.sort((a, b) => {
      if (sortBy === "memory") {
        return a.mem > b.mem ? -1 : 1;
      } else {
        return a.cpu > b.cpu ? -1 : 1;
      }
    });
    setVisibleProcesses(
      processes.map((process2) => ({
        ...process2,
        canRestartProcess: hasRestartLaunchPath(process2)
      }))
    );
  }, [fetchResult, sortBy, isAppGroupingEnabled]);
  const fileIcon = (process2) => {
    return getFileIcon(process2);
  };
  const handleKillError = (force) => {
    const errorHelp = getPlatformSpecificErrorHelp("kill", force);
    if (force && errorHelp.helpUrl) {
      (0, import_api.confirmAlert)({
        title: errorHelp.title,
        message: errorHelp.message,
        primaryAction: {
          title: "Open Help",
          onAction: () => (0, import_api.open)(errorHelp.helpUrl)
        }
      });
    } else {
      (0, import_api.showToast)({
        title: errorHelp.title,
        message: errorHelp.message,
        style: import_api.Toast.Style.Failure
      });
    }
  };
  const handleRestartError = (processName, error) => {
    (0, import_api.showToast)({
      title: `Failed to Restart ${processName}`,
      message: error instanceof Error ? error.message : "Unknown error",
      style: import_api.Toast.Style.Failure
    });
  };
  const performPostKillActions = () => {
    if (closeWindowAfterKill) (0, import_api.closeMainWindow)();
    if (goToRootAfterKill) (0, import_api.popToRoot)({ clearSearchBar: clearSearchBarAfterKill });
    if (clearSearchBarAfterKill) (0, import_api.clearSearchBar)({ forceScrollToTop: true });
  };
  const killProcess = async (process2, force = false) => {
    const processName = process2.processName === "-" ? `process ${process2.id}?` : process2.processName;
    if (!skipConfirmation) {
      if (!await (0, import_api.confirmAlert)({
        title: `${force ? "Force " : ""}Kill ${processName}?`,
        rememberUserChoice: true
      })) {
        (0, import_api.showToast)({
          title: `Cancelled Killing ${processName}`,
          style: import_api.Toast.Style.Failure
        });
        return;
      }
    }
    try {
      if (process2.type === "aggregatedApp") {
        await terminateProcessTree(process2.id, force);
      } else {
        await terminateProcess(process2.id, force);
      }
      (0, import_api.showToast)({
        title: `Killed ${processName}`,
        style: import_api.Toast.Style.Success
      });
      const terminatedProcessIds = /* @__PURE__ */ new Set([process2.id, ...process2.childProcessIds ?? []]);
      setFetchResult((prev) => prev.filter((p) => !terminatedProcessIds.has(p.id)));
      performPostKillActions();
    } catch {
      handleKillError(force);
    }
  };
  const killAllProcesses = async (process2, force = false) => {
    const processName = process2.processName;
    if (processName === "-") {
      (0, import_api.showToast)({
        title: "Cannot Kill All for unnamed processes",
        style: import_api.Toast.Style.Failure
      });
      return;
    }
    if (!skipConfirmation) {
      if (!await (0, import_api.confirmAlert)({
        title: `${force ? "Force " : ""}Kill all "${processName}" processes?`,
        rememberUserChoice: true
      })) {
        (0, import_api.showToast)({
          title: `Cancelled Kill All ${processName}`,
          style: import_api.Toast.Style.Failure
        });
        return;
      }
    }
    try {
      await terminateProcessesByName(processName, force);
      (0, import_api.showToast)({
        title: `Killed all "${processName}" processes`,
        style: import_api.Toast.Style.Success
      });
      setFetchResult((prev) => prev.filter((p) => p.processName !== processName));
      performPostKillActions();
    } catch {
      handleKillError(force);
    }
  };
  const restartProcess2 = async (process2, force = false) => {
    const processName = process2.processName === "-" ? `process ${process2.id}` : process2.processName;
    if (!hasRestartLaunchPath(process2)) {
      handleRestartError(processName, new Error("A launchable executable or app bundle path is required."));
      return;
    }
    if (!skipConfirmation) {
      if (!await (0, import_api.confirmAlert)({
        title: `${force ? "Force " : ""}Restart ${processName}?`,
        rememberUserChoice: true
      })) {
        (0, import_api.showToast)({
          title: `Cancelled Restarting ${processName}`,
          style: import_api.Toast.Style.Failure
        });
        return;
      }
    }
    try {
      await restartProcess(process2, force);
      (0, import_api.showToast)({
        title: `Restarted ${processName}`,
        style: import_api.Toast.Style.Success
      });
      fetchProcesses(true);
    } catch (error) {
      handleRestartError(processName, error);
    }
  };
  const subtitleString = (process2) => {
    const subtitles = [];
    const title = process2.processName?.trim() ?? "";
    const titleLower = title.toLowerCase();
    const pushSubtitle = (value) => {
      const trimmed = value?.trim();
      if (!trimmed) {
        return;
      }
      if (trimmed.toLowerCase() === titleLower) {
        return;
      }
      if (subtitles.some((s) => s.toLowerCase() === trimmed.toLowerCase())) {
        return;
      }
      subtitles.push(trimmed);
    };
    if (process2.type === "aggregatedApp") {
      pushSubtitle(process2.appName);
      if (process2.childProcessCount != null && process2.childProcessCount > 0) {
        pushSubtitle(`${process2.childProcessCount + 1} processes`);
      }
    }
    if (shouldShowPID) {
      pushSubtitle(process2.id.toString());
    }
    if (shouldShowPath) {
      pushSubtitle(process2.path);
    }
    return subtitles.length > 0 ? subtitles.join(" - ") : void 0;
  };
  const toggleAppGrouping = async () => {
    const nextValue = !isAppGroupingEnabled;
    await import_api.LocalStorage.setItem(APP_GROUPING_STORAGE_KEY, nextValue);
    setIsAppGroupingEnabled(nextValue);
    await (0, import_api.showToast)({ title: `${nextValue ? "Enabled" : "Disabled"} App Grouping` });
  };
  const processCount = visibleProcesses.length;
  const isShowingInitialLoadingState = isLoadingProcesses && visibleProcesses.length === 0;
  return /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(
    import_api.List,
    {
      isLoading: isShowingInitialLoadingState,
      searchBarPlaceholder: "Filter by name",
      onSearchTextChange: (query2) => setQuery(query2),
      searchBarAccessory: /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
        import_api.List.Dropdown,
        {
          id: SORT_BY_DROPDOWN_ID,
          tooltip: "Sort",
          storeValue: true,
          defaultValue: DEFAULT_SORT_BY,
          onChange: (newValue) => {
            if (!isSortBy(newValue)) {
              return;
            }
            setSortBy(newValue);
          },
          children: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_api.List.Dropdown.Section, { title: "Sort By", children: [
            /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Dropdown.Item, { title: "CPU Usage", value: "cpu" }),
            /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Dropdown.Item, { title: "Memory Usage", value: "memory" })
          ] })
        }
      ),
      children: [
        fetchError ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.EmptyView, { title: "Failed to Fetch Processes", description: fetchError }) : null,
        !fetchError && !isLoadingProcesses && visibleProcesses.length === 0 ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.EmptyView, { title: "No Processes Found" }) : null,
        /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.List.Section, { title: "Processes", subtitle: `${processCount} running`, children: visibleProcesses.filter((process2) => {
          if (query === "") {
            return true;
          }
          const nameMatches = process2.processName.toLowerCase().includes(query.toLowerCase());
          const pathMatches = shouldSearchInPaths && process2.path.toLowerCase().match(new RegExp(`.+${query}.*\\.[app|framework|prefpane]`, "ig")) != null;
          const pidMatches = shouldSearchInPid && process2.id.toString().includes(query);
          const appNameMatches = process2.type === "aggregatedApp" && process2.appName?.toLowerCase().includes(query.toLowerCase());
          return nameMatches || pathMatches || pidMatches || appNameMatches;
        }).sort((a, b) => {
          if (shouldPrioritizeAppsWhenFiltering) {
            const appTypes = ["app", "aggregatedApp"];
            if (appTypes.includes(a.type) && !appTypes.includes(b.type)) {
              return -1;
            } else if (!appTypes.includes(a.type) && appTypes.includes(b.type)) {
              return 1;
            }
          }
          return 0;
        }).map((process2, index) => {
          const icon = fileIcon(process2);
          return /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
            import_api.List.Item,
            {
              title: process2.processName,
              subtitle: subtitleString(process2),
              icon,
              accessories: [
                {
                  text: `${process2.cpu.toFixed(2)}%`,
                  icon: { source: "cpu.svg", tintColor: import_api.Color.PrimaryText },
                  tooltip: "% CPU"
                },
                {
                  text: prettyBytes(process2.mem * 1024),
                  icon: {
                    source: "memorychip.svg",
                    tintColor: import_api.Color.PrimaryText
                  },
                  tooltip: "Memory"
                }
              ],
              actions: /* @__PURE__ */ (0, import_jsx_runtime.jsxs)(import_api.ActionPanel, { children: [
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.Action, { title: "Kill", icon: import_api.Icon.XMarkCircle, onAction: () => killProcess(process2) }),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(import_api.Action, { title: "Force Kill", icon: import_api.Icon.XMarkCircle, onAction: () => killProcess(process2, true) }),
                process2.canRestartProcess ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.Action,
                  {
                    title: "Restart",
                    icon: import_api.Icon.RotateAntiClockwise,
                    shortcut: { modifiers: ["cmd", "opt"], key: "r" },
                    onAction: () => restartProcess2(process2)
                  }
                ) : null,
                process2.canRestartProcess ? /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.Action,
                  {
                    title: "Force Restart",
                    icon: import_api.Icon.RotateAntiClockwise,
                    shortcut: { modifiers: ["cmd", "opt", "shift"], key: "r" },
                    onAction: () => restartProcess2(process2, true)
                  }
                ) : null,
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.Action,
                  {
                    title: "Kill All",
                    icon: import_api.Icon.XMarkCircleFilled,
                    shortcut: { modifiers: ["opt"], key: "return" },
                    onAction: () => killAllProcesses(process2)
                  }
                ),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.Action,
                  {
                    title: "Force Kill All",
                    icon: import_api.Icon.XMarkCircleFilled,
                    shortcut: { modifiers: ["opt", "shift"], key: "return" },
                    onAction: () => killAllProcesses(process2, true)
                  }
                ),
                process2.path == null ? null : /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.Action.CopyToClipboard,
                  {
                    title: "Copy Path",
                    content: process2.path,
                    shortcut: import_api.Keyboard.Shortcut.Common.CopyPath
                  }
                ),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.Action,
                  {
                    title: "Reload",
                    icon: import_api.Icon.ArrowClockwise,
                    shortcut: import_api.Keyboard.Shortcut.Common.Refresh,
                    onAction: () => fetchProcesses(true)
                  }
                ),
                /* @__PURE__ */ (0, import_jsx_runtime.jsx)(
                  import_api.Action,
                  {
                    title: `${isAppGroupingEnabled ? "Disable" : "Enable"} App Grouping`,
                    icon: import_api.Icon.AppWindow,
                    shortcut: { modifiers: ["shift"], key: "tab" },
                    onAction: toggleAppGrouping
                  }
                )
              ] })
            },
            index
          );
        }) })
      ]
    }
  );
}
