# ps2-with-recursion

Run [Recursion Tracker](https://recursiontracker.com/) alongside **PlanetSide 2** on Linux,
with Steam and Proton:

- **Starts with the game.** Launch PlanetSide 2 from Steam and Recursion Tracker opens with it,
  inside the game's own Proton prefix. The game doesn't wait for it.
- **No stray console windows.** The black console windows Recursion Tracker opens under Wine
  are hidden.
- **Closes with the game.** When PlanetSide 2 exits, Recursion Tracker is quit through its own
  tray menu (**Exit**), so it saves its settings. Steam then shows the game as stopped.

It is built for **SteamOS** (Desktop Mode) and works on other Linux distributions with Steam
installed from their own package. It runs entirely as your user, with no root, and it doesn't
modify the game or Recursion Tracker.

> Not affiliated with Daybreak Game Company, Rogue Planet Games, Recursion or Valve.
> Recursion Tracker is a third-party tool. This project only starts and stops it.

## Contents

- [Requirements](#requirements)
- [Which desktops work](#which-desktops-work)
- [1. Install Recursion Tracker into PlanetSide 2's prefix](#1-install-recursion-tracker-into-planetside-2s-prefix)
- [2. Install ps2-with-recursion](#2-install-ps2-with-recursion)
- [3. Set the Steam launch option](#3-set-the-steam-launch-option)
- [Using it](#using-it)
- [Troubleshooting](#troubleshooting)
- [Updating and uninstalling](#updating-and-uninstalling)
- [How it works](#how-it-works)
- [Advanced](#advanced)
- [Limitations](#limitations)
- [License](#license)

## Requirements

| What | Notes |
|---|---|
| PlanetSide 2 from Steam, running under Proton | Any Proton works: Valve's Proton, Proton Experimental, GE-Proton, Proton-CachyOS, … |
| Steam from your distribution, not Flatpak | Flatpak Steam runs launch options inside its sandbox, where this tool can't reach your desktop. |
| Recursion Tracker installed **in PlanetSide 2's Proton prefix** | See step 1. |
| `xdotool`, `xwininfo`, `xprop`, and `busctl` or `gdbus` | SteamOS already has all of them. See the table below for other distributions. |
| For the clean quit: a system tray that shows Wine's tray icons | KDE Plasma (including SteamOS Desktop Mode), or a classic system tray such as Xfce's or MATE's. Without one, Recursion Tracker is force-closed 20 s after the game instead. See [Which desktops work](#which-desktops-work). |

Installing the tools on other distributions:

| Distribution | Command |
|---|---|
| SteamOS | Nothing to install. |
| Arch, Manjaro, CachyOS, EndeavourOS | `sudo pacman -S --needed xdotool xorg-xwininfo xorg-xprop` |
| Debian, Ubuntu, Linux Mint, Pop!_OS | `sudo apt install xdotool x11-utils` |
| Fedora | `sudo dnf install xdotool xwininfo xprop` |
| Bazzite and other Fedora Atomic | `rpm-ostree install xdotool xwininfo xprop`, then reboot |
| openSUSE | `sudo zypper install xdotool xwininfo xprop` |

`busctl` comes with systemd and `gdbus` with glib2, so you almost certainly have one of them.
Only KDE Plasma needs them, and only classic trays need `xprop`.

## Which desktops work

Starting Recursion Tracker with the game and hiding its console windows work on any desktop.
The clean quit (clicking **Exit** in its tray menu) needs a system tray that shows Wine's icons:

| Desktop | Clean quit | How the tray icon is found |
|---|---|---|
| KDE Plasma, including SteamOS Desktop Mode | Yes, tested on SteamOS | KDE's `xembedsniproxy` shows Wine's icon in Plasma's tray. The tool finds it over D-Bus. |
| Xfce | Yes, tested with Xfce 4.20's panel | Wine docks its icon in the panel's tray (XEmbed). The tool finds that small window and right-clicks it. |
| MATE, LXDE, LXQt, Budgie, and window managers with an XEmbed tray (stalonetray, trayer, …), on X11 | Expected to work, untested (stalonetray was tested) | Same as Xfce. |
| Cinnamon | Untested | Cinnamon draws tray icons itself. If Wine's icon window isn't really under the pointer where it appears, the tool doesn't click (see below), and Recursion Tracker is force-closed. |
| GNOME | No | GNOME has no system tray, so Recursion Tracker is force-closed. |
| Steam's Game Mode | No | No tray, so Recursion Tracker is force-closed. |

On a classic tray, the tool first moves the pointer onto the icon and checks that the window
under the pointer really is Recursion Tracker's icon or the tray holding it. If something else
is there, it doesn't click.

Run `ps2-with-recursion --test` (game closed) to find out what your desktop does.

## 1. Install Recursion Tracker into PlanetSide 2's prefix

Recursion Tracker has to run in the same Wine prefix as the game, under the same Proton.

1. In Steam, run PlanetSide 2 once so Proton creates its prefix, then quit it. If Steam doesn't
   offer Proton for it, open PlanetSide 2 > Properties > Compatibility and tick *Force the use of a
   specific Steam Play compatibility tool*.
2. Download the Recursion Tracker installer from <https://recursiontracker.com/>.
3. Install [Protontricks](https://github.com/Matoking/protontricks). On SteamOS, get
   **Protontricks** from the Discover store.
4. Run the installer inside PlanetSide 2's prefix (`218230` is PlanetSide 2's Steam app ID), and
   keep the default install folder:

   ```sh
   # Protontricks from Discover / Flathub:
   flatpak run --command=protontricks-launch com.github.Matoking.protontricks \
       --appid 218230 ~/Downloads/RecursionTrackerSetup.exe

   # Protontricks from your distribution's packages:
   protontricks-launch --appid 218230 ~/Downloads/RecursionTrackerSetup.exe
   ```

   Use the installer's real file name. If the Flatpak can't see your Downloads folder, run
   `flatpak override --user --filesystem=xdg-download com.github.Matoking.protontricks` and try
   again.

Recursion Tracker is a .NET program. It ran on the Wine Mono that comes with Proton, with nothing
else installed. If it doesn't start for you, installing .NET into the prefix may help
(`protontricks 218230 dotnet48`). That wasn't needed in testing, so it is untested.

## 2. Install ps2-with-recursion

```sh
git clone https://github.com/ltsjoe/ps2-with-recursion.git
cd ps2-with-recursion
./install.sh
```

No git? Download the ZIP from the green **Code** button on GitHub, extract it, open a terminal
in the folder, and run `./install.sh`.

The installer puts everything in your home folder, so it survives SteamOS updates:

- `~/.local/bin/ps2-with-recursion`, the launcher.
- `~/.local/share/ps2-with-recursion/`, two small Windows-side files that it copies into the
  PlanetSide 2 folder at every launch.
- On KDE Plasma, a KWin window rule that keeps Recursion Tracker's console windows minimized and
  off the taskbar. To skip it, run `./install.sh --no-kwin-rule`.

It also checks for the tools above, finds PlanetSide 2 and Recursion Tracker in your Steam
libraries, and tells you if anything is missing.

**Optional check.** With the game closed, run:

```sh
~/.local/bin/ps2-with-recursion --test
```

This starts Recursion Tracker on its own, waits for its tray icon, and quits it from the tray
menu. It ends with `PASS` if your desktop supports the clean quit. Your mouse pointer jumps to
the tray menu for a moment.

## 3. Set the Steam launch option

In Steam, open PlanetSide 2 > **Properties** > **General** > **Launch Options** and enter:

```
~/.local/bin/ps2-with-recursion %command%
```

If you already use a launch wrapper, keep it, for example
`gamemoderun ~/.local/bin/ps2-with-recursion %command%`. The same goes for `mangohud` or an
environment variable such as `DXVK_HUD=fps`.

## Using it

Launch PlanetSide 2 from Steam as usual.

1. Recursion Tracker starts with the game launcher. If its *hide on game start* option is on, it
   hides itself to the tray once the game starts.
2. Play.
3. Quit PlanetSide 2. About 15 seconds later, your mouse pointer briefly jumps to Recursion
   Tracker's tray menu, clicks **Exit**, and jumps back. Steam then shows the game as stopped.

If Recursion Tracker is already open when you launch the game, it is left as it is, and it is
still closed with the game.

## Troubleshooting

Two logs:

```sh
journalctl -t ps2-with-recursion     # the Linux side: starting, hiding windows, quitting
```

…and `ps2-with-recursion.log` in the PlanetSide 2 folder (Steam > PlanetSide 2 > Manage >
Browse local files), the Windows side, rewritten at every launch.

| Symptom or message | What to do |
|---|---|
| Recursion Tracker doesn't start, and the journal says *not installed in …/pfx* | It isn't in PlanetSide 2's prefix. See step 1. The game still starts normally. |
| The journal has no `ps2-with-recursion` lines at all | Check the launch option, and that `~/.local/bin/ps2-with-recursion` exists and is executable. |
| *Recursion Tracker still running after 20 s, forcing it* (game folder log) | The clean quit didn't work. The journal says why. Run `ps2-with-recursion --test` with the game closed. |
| *no tray icon for Recursion Tracker found* | Your desktop has no system tray that shows Wine's icons (GNOME, Game Mode), or `xprop` is missing on a classic tray. Recursion Tracker is force-closed instead. See [Which desktops work](#which-desktops-work). |
| *the pointer at Recursion Tracker's tray icon … is over another window, so not clicking* | A window covered the tray, or your desktop draws tray icons somewhere other than Wine's own icon window. Recursion Tracker is force-closed instead. |
| `--test` fails on stalonetray right after an earlier run | stalonetray sometimes ignores Wine's icon after an earlier one went away. Restart stalonetray and run the test again. |
| *xdotool, xwininfo or DISPLAY missing* | Install the tools ([Requirements](#requirements)). |
| Black console windows still show up | On desktops other than KDE they can show for up to a second before they are hidden. If they stay, check the journal. |
| Steam still shows PlanetSide 2 as running | Something in the prefix is still open. Check the game folder log. |

Recursion Tracker's in-game overlay is its own business. If it doesn't draw for you, you can
turn the D3D overlay off in Recursion Tracker's options.

## Updating and uninstalling

```sh
cd ps2-with-recursion
git pull
./install.sh                # update
./install.sh --uninstall    # remove everything it installed
```

`--uninstall` removes the launcher, its data folder, its files in the PlanetSide 2 folder and the
KWin rule. Then remove `ps2-with-recursion` from PlanetSide 2's launch options yourself.

## How it works

```
Steam ─► ps2-with-recursion (Linux, your launch option)
           │  copies ps2-with-recursion.bat/.js into the game folder
           │  swaps LaunchPad.exe for ps2-with-recursion.bat in Steam's Proton command
           │  starts a background watcher, then hands over to Steam's command
           ▼
         Proton ─► ps2-with-recursion.bat ─► wscript.exe ps2-with-recursion.js   (Windows side)
                     1. starts RTST.exe (Recursion Tracker) without waiting for it
                     2. runs LaunchPad.exe with Steam's arguments
                     3. waits until LaunchPad and PlanetSide2_x64*.exe have been gone for 15 s
                     4. drops ps2-with-recursion.quit in the game folder
                                         │
watcher (Linux) ◄────────────────────────┘
   every second: hides Recursion Tracker's console windows (xdotool windowunmap)
   on .quit: finds Recursion Tracker's tray icon, either over D-Bus (KDE Plasma's
             StatusNotifierItem) or as Wine's icon window in a classic XEmbed tray,
             right-clicks it, clicks Exit (the menu's last item), puts the pointer back
   the .js force-closes Recursion Tracker if it is still running 20 s later
```

Why it is built this way:

- **One Proton session.** Recursion Tracker has to share the game's prefix and Wine server, so
  both start from the single Proton command Steam runs, not from a second Proton run.
- **The `.bat` hands over to `wscript.exe`.** `wscript` is a Windows GUI program, so no console
  window is left open for the whole game.
- **Quitting through the tray menu.** Recursion Tracker is a tray app. Closing its window, or
  sending it `WM_CLOSE` with `taskkill`, only hides it to the tray, and the process keeps running.
  Only the tray menu's **Exit** really quits it and saves its settings files. Wine can't reach the
  Linux desktop's tray, so the Linux-side watcher does the clicking.
- **Waiting for everything.** Proton's `steam.exe` waits for every program the game started. If
  Recursion Tracker were left running, Steam would keep showing PlanetSide 2 as running.
- **No fixed paths.** The game folder comes from Steam's command line, the prefix from
  `STEAM_COMPAT_DATA_PATH`, and the window class (`steam_app_218230`) from `SteamGameId`.

## Advanced

Environment variables, set in front of the launcher in the launch options:

| Variable | Use |
|---|---|
| `PS2WR_RT_DIR_LINUX` | Recursion Tracker's folder (Linux path), if it isn't in one of the default `Program Files` folders of the prefix. |
| `PS2WR_LAUNCHER_CMD` | For development: a Windows command line the `.js` runs *instead of* `LaunchPad.exe`, for example `ping -n 40 127.0.0.1`, to test the whole chain without starting the game. |

You can also run it straight from a git checkout without installing. Use the checkout's path in
the launch option (`/path/to/ps2-with-recursion/ps2-with-recursion %command%`); it finds the
`windows/` folder next to itself.

Other commands:

```sh
ps2-with-recursion --test      # check the clean quit on this desktop (game closed)
ps2-with-recursion --quit-rt   # quit a running Recursion Tracker from its tray menu
ps2-with-recursion --help
```

## Limitations

- **Your mouse pointer moves for a moment** when the game closes. Clicking the tray menu is the
  only way found to trigger Recursion Tracker's real Exit.
- **The clean quit needs a system tray that shows Wine's icons** (see
  [Which desktops work](#which-desktops-work)). Without one, Recursion Tracker is force-closed
  20 s after the game. It then doesn't save changes you made during that session to its event
  filters or tracked players. In testing, its options were saved as soon as its options window
  closed, so those were kept.
- **Steam's Game Mode** has no tray, so Recursion Tracker is force-closed there. Starting it and
  hiding the console windows are expected to work, but haven't been tested in Game Mode.
- **Exit must stay the last item** of Recursion Tracker's tray menu. If a Recursion Tracker update
  changes the menu, the click could land on a different item. Please open an issue if that
  happens.
- **Wayland-native Wine** (`PROTON_ENABLE_WAYLAND=1`) puts Wine's windows outside X11, where
  `xdotool` can't see them. Recursion Tracker still starts and is force-closed, but its consoles
  aren't hidden.
- **Flatpak Steam** isn't supported (see [Requirements](#requirements)).

Tested on SteamOS 3.9.5 (KDE Plasma 6.7.3, Wayland session) with Proton-CachyOS 11.0,
Recursion Tracker 0.11.0.11 and xdotool 4.20260303.1. The classic-tray quit was tested with
Xfce 4.20.8's panel and stalonetray 1.5.0 on a virtual X server (Xvfb, Arch Linux, no window
manager), with the same Proton and Recursion Tracker. It hasn't been tried on a full Xfce or
MATE desktop yet; reports are welcome.

## License

[GPL-3.0-or-later](LICENSE). © 2026 ltsJoe.
