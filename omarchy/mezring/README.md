# mezring

Make two cheap Bluetooth "TikTok rings" do what *you* want on a Linux desktop
(built for Omarchy / Hyprland, works on any Wayland setup with BlueZ).

| Ring | What it really is | Driver target |
|---|---|---|
| **J09** | BLE, Zhuhai Jieli chip running the stock SDK `hid_mouse` demo. 3 buttons + a touch pad. Leaks real pad coordinates. | host driver **and** firmware (RCSP channel exposed, public SDK) |
| **Anko** (Kmart) | Classic Bluetooth, spoofs an Apple Wireless Keyboard. 3 buttons, canned swipe/tap gestures + volume/power keys. | host driver |

Full reverse-engineering notes, descriptors and byte-level gesture maps: [`RECON.md`](RECON.md).

## What you get

* **`tools/mezringd.py`** – userspace driver. Reads raw HID reports, grabs the
  rings' evdev nodes (so the kernel's "fake touchscreen + Sleep key" never reach
  the desktop), turns them into clean events and runs the actions you mapped.
  Modes (profiles), smooth scrolling / pointer / synthetic keys via uinput,
  `hyprctl`, `wtype`, shell commands. Stdlib-only Python.
* **`plugin/`** – Omarchy bar widget `mez.rings`: which ring is connected,
  battery, current mode, a live event log for debugging, and an inline editor
  for every button mapping that writes the config and applies it instantly.
* **`71-mezring.rules`** – udev: user access to the rings + `/dev/uinput`, and
  stops `systemd-logind` suspending the laptop when the J09's third button sends
  the Sleep key (it really does that).
* **`tools/hidcap.py`** – raw report capture/decoder for both rings.
* **`install.sh` / `uninstall.sh`**.

## Install

```sh
cd ~/gitrpo/.dotmez/omarchy/mezring   # part of the .dotmez dotfiles repo
./install.sh          # asks for sudo once (udev rule + uinput module)
```

Pair the rings with BlueZ as usual (they show up as keyboards). The daemon
picks them up when they connect and drops them when they sleep.

* bar: left-click **◎** → panel; right-click → next mode
* config: `~/.config/mezring/mezring.toml` (reference copy with comments in
  `mezring.example.toml` next to it). Edit from the panel, or by hand and
  `systemctl --user kill -s HUP mezringd`.
* logs: `journalctl --user -u mezringd -f`; `tools/mezringd.py -v -n` runs a
  verbose dry run in the foreground (stop the service first).

`./uninstall.sh [--purge]` reverses everything.

## Events

| ring | event | fires when |
|---|---|---|
| j09 | `btn1` `btn2` `btn3` | short press |
| j09 | `hold_fwd` / `hold_back` | button held: every frame (~30 ms) while the firmware drags; `hold_end` on release |
| j09 | `swipe_fwd` `swipe_back` `tap` | gestures on the pad |
| j09 | `pad_down` `pad_move` `pad_up` | raw finger tracking on the pad (`pad_move` carries dx, dy) |
| anko | `btn1` `btn2` `btn3` | short press (firmware gestures swipe-up / tap / swipe-down) |
| anko | `btn1_long` `btn2_long` `btn3_long` | long press (Vol+ / Power / Vol-; 1 and 3 repeat every 0.5 s) |

## Actions

```
key:KEY_PLAYPAUSE    key:KEY_LEFTCTRL+KEY_T     uinput key (names from input-event-codes.h)
scroll:-3  hscroll:2                            wheel notches (+ up / left), fractions ok
click:left|right|middle
pointer      (pad_move)                         pad drives the mouse pointer
scrollpad    (pad_move)                         pad drives scrolling
wtype:-k XF86AudioPlay                          wtype arguments
hypr:workspace +1    hypr:cyclenext             Hyprland dispatcher. Classic names are translated to the
hypr:hl.dsp.focus({ monitor = "+1" })           Lua hl.dsp.* form this Hyprland uses; that form works too
lua:<code>                                      hyprctl eval …
mode:pointer   mode:next                        switch profile
notify:text
anything else                                   shell command
```
Chain actions with a TOML array (`["scroll:-3", "notify:down"]`) or, in the
panel, with ` | `. Missing mappings fall back to `[common.<ring>]`.

## Modes are per ring

Each ring has its own current mode, remembered across restarts in
`general.start_mode`. A ring only takes part in the modes that have a
`[modes.<mode>.<ring>]` table, so the Anko (no pad) is not in `pointer` out of
the box; give it any mapping under that mode in the panel editor to add it.
`mode:next` cycles the ring that pressed the button; `mode:anko:hypr` or
`mode:all:scroll` target another ring or both. In the panel, pick a ring at the
top to see its status, mode, events and mappings; right-click the bar icon to
cycle the selected ring's mode.

## Config layout

```toml
[general]            start_mode, hold_every, pointer_speed, pad_scroll_divisor, …
[common.j09]         fallbacks for every mode
[modes.scroll.j09]   one table per mode per ring
[modes.scroll.anko]
```

## Firmware hacking (J09)

The J09 exposes Jieli's RCSP command/OTA channel (GATT services `ae30`/`ae40`).
Jieli's AC63 SDK is public (Apache-2.0) and the protocol has been reverse
engineered for sibling chips; see the links in `RECON.md`. Not started yet.
