// ps2-with-recursion.js: runs inside PlanetSide 2's Proton prefix under wscript.exe (no console
// window). ps2-with-recursion.bat starts it, and the Linux-side ps2-with-recursion copies both
// into the game folder and points Steam at the .bat.
//
// Copyright (C) 2026 ltsJoe
// SPDX-License-Identifier: GPL-3.0-or-later
// https://github.com/ltsjoe/ps2-with-recursion
//
// 1. Starts Recursion Tracker (unless it is already open) without waiting for it.
// 2. Runs the PlanetSide 2 launcher with Steam's arguments.
// 3. Waits until the launcher and the game have been gone for 15 seconds.
// 4. Drops a .quit file so the Linux side can quit Recursion Tracker from its tray menu, and
//    force-closes it if it is still running 20 seconds later.
// Each run writes what it did to ps2-with-recursion.log next to this file.

var sh  = new ActiveXObject("WScript.Shell");
var fso = new ActiveXObject("Scripting.FileSystemObject");
// Wine's JScript has no GetObject("winmgmts:"), so connect to WMI through the locator.
var wmi = new ActiveXObject("WbemScripting.SWbemLocator").ConnectServer(".", "root\\cimv2");

function env(name) {
  var v = sh.ExpandEnvironmentStrings("%" + name + "%");
  return v === "%" + name + "%" ? "" : v;
}

var SELF      = WScript.ScriptFullName;
var GAME_DIR  = SELF.replace(/\\[^\\]+$/, "");
var LAUNCHER  = "LaunchPad.exe";
var GAME_RE   = /^(launchpad|planetside2_x64(_be)?)\.exe$/i;       // launcher + game client
var RT_EXE    = "RTST.exe";
var RT_ALL    = ["RTST.exe", "rtst_run_dx64.exe", "rtst_run_dx86.exe"]; // tracker + overlay injectors
var QUIT_FLAG = SELF.replace(/\.js$/i, ".quit");                   // watched by the Linux side
var LOG_FILE  = SELF.replace(/\.js$/i, ".log");
// For testing without the game: a Windows command line to run instead of the launcher.
var TEST_LAUNCHER = env("PS2WR_LAUNCHER_CMD");

// Recursion Tracker's folder: as the Linux side found it, else the installer's defaults.
var RT_DIR = "";
var candidates = [env("PS2WR_RT_DIR"),
                  "C:\\Program Files (x86)\\Recursion\\RecursionTracker",
                  "C:\\Program Files\\Recursion\\RecursionTracker"];
for (var c = 0; c < candidates.length; c++) {
  if (candidates[c] && fso.FileExists(candidates[c] + "\\" + RT_EXE)) { RT_DIR = candidates[c]; break; }
}

var log = fso.CreateTextFile(LOG_FILE, true);
function say(msg) { log.WriteLine(new Date().toLocaleString() + "  " + msg); }

function running(test) {            // test: a RegExp, or an exact exe name
  var e = new Enumerator(wmi.ExecQuery("SELECT Name FROM Win32_Process"));
  for (; !e.atEnd(); e.moveNext()) {
    var n = e.item().Name;
    if (typeof test === "string" ? n.toLowerCase() === test.toLowerCase() : test.test(n)) return true;
  }
  return false;
}

function quote(s) { return /[\s"]/.test(s) ? '"' + s.replace(/"/g, '\\"') + '"' : s; }

try { if (fso.FileExists(QUIT_FLAG)) fso.DeleteFile(QUIT_FLAG); } catch (e) {}

// 1. Recursion Tracker
if (!RT_DIR) {
  say("Recursion Tracker not found (looked in: " + candidates.join("; ") + "), starting the game without it");
} else if (running(RT_EXE)) {
  say("Recursion Tracker is already running");
} else {
  sh.CurrentDirectory = RT_DIR;     // it reads PS2.config and user.config from its own folder
  sh.Run('"' + RT_DIR + "\\" + RT_EXE + '"', 1, false);
  say("started Recursion Tracker from " + RT_DIR);
}

// 2. The launcher, with whatever arguments Steam passed
var args = [];
for (var i = 0; i < WScript.Arguments.length; i++) args.push(quote(WScript.Arguments(i)));
sh.CurrentDirectory = GAME_DIR;
var rc;
if (TEST_LAUNCHER) {
  say("TEST: running " + TEST_LAUNCHER + " instead of " + LAUNCHER);
  rc = sh.Run(TEST_LAUNCHER, 0, true);
} else {
  say("running " + LAUNCHER + " " + args.join(" "));
  rc = sh.Run('"' + GAME_DIR + "\\" + LAUNCHER + '" ' + args.join(" "), 1, true);
}
say("launcher exited with " + rc);

// 3. The launcher can hand off to the game or restart itself after patching,
//    so wait until neither has been seen for three checks in a row.
var quiet = 0;
while (quiet < 3) {
  WScript.Sleep(5000);
  quiet = running(GAME_RE) ? 0 : quiet + 1;
}
say("launcher and game have closed");

// 4. Close Recursion Tracker. Closing its window or a plain taskkill only hides it to the tray,
//    and only its tray menu's Exit makes it save its settings. Wine can't reach the Linux
//    desktop's tray, so drop QUIT_FLAG for the Linux side, which clicks Exit. If it is still
//    running 20 s later (Steam's Game Mode has no tray, for example), force it.
if (running(RT_EXE)) {
  fso.CreateTextFile(QUIT_FLAG, true).Close();
  say("asked the Linux side to quit Recursion Tracker from its tray menu");
  for (var t = 0; t < 20 && running(RT_EXE); t++) WScript.Sleep(1000);
  say(running(RT_EXE) ? "Recursion Tracker still running after 20 s, forcing it" : "Recursion Tracker exited");
}
for (var k = 0; k < RT_ALL.length; k++) {
  if (running(RT_ALL[k])) { sh.Run("taskkill /f /im " + RT_ALL[k], 0, true); say("forced " + RT_ALL[k]); }
}
try { if (fso.FileExists(QUIT_FLAG)) fso.DeleteFile(QUIT_FLAG); } catch (e) {}
say("done");
log.Close();
