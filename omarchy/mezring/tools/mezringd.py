#!/usr/bin/env python3
"""mezringd — userspace driver for the J09 and Anko Bluetooth rings.

* Reads the rings' raw HID reports from /dev/hidraw* (no root needed with
  71-mezring.rules installed).
* Grabs their evdev nodes so the kernel's default interpretation (volume keys,
  Home, Sleep, fake touchscreen) never reaches the compositor.
* Turns the reports into clean events (see EVENTS below) and runs the actions
  you mapped to them in mezring.toml. Actions can be shell commands, hyprctl
  dispatches, wtype key presses, or, when /dev/uinput is accessible, smooth
  scrolling, pointer motion and synthetic key presses through a virtual device.
* Supports modes (profiles) you can switch between from a ring button.
* Serves state + a live event stream on a unix socket ($XDG_RUNTIME_DIR/mezring.sock)
  for the Omarchy bar panel, which can also change mode and edit mappings.

Stdlib only. Python >= 3.11 (tomllib).

EVENTS
  j09 : btn1 btn2 btn3            short press of the three buttons
        hold_fwd hold_back        fired every frame while a button is held (slow drag)
        hold_end                  button released after a hold
        swipe_fwd swipe_back tap  gestures on the touch pad
        pad_down pad_move pad_up  raw finger tracking on the pad (pad_move has dx,dy)
  anko: btn1 btn2 btn3            short press (firmware gesture: swipe up / tap / swipe down)
        btn1_long btn2_long btn3_long  long press (firmware keys: Vol+ / Power / Vol-);
                                  btn1_long and btn3_long repeat every 0.5 s while held

ACTIONS (string, or array of strings run in order)
  "key:KEY_PLAYPAUSE"  "key:KEY_LEFTCTRL+KEY_T"   uinput key press (names from input-event-codes.h)
  "scroll:-3" "hscroll:2"                         uinput wheel notches (+ = up / left)
  "click:left|right|middle"                       uinput mouse click
  "pointer"  (pad_move only)                      move the mouse pointer with the pad
  "scrollpad" (pad_move only)                     scroll with the pad
  "wtype:-k XF86AudioPlay"                        run wtype with these args
  "hypr:workspace +1"  "hypr:cyclenext"           Hyprland dispatcher (classic names are translated to the
  "hypr:hl.dsp.focus({ monitor = \"+1\" })"       Lua hl.dsp.* form this Hyprland uses; that form is also accepted)
  "lua:<code>"                                    hyprctl eval <code>
  "mode:pointer" "mode:next"                      switch THIS ring's mode
  "mode:anko:hypr" "mode:all:scroll"              switch another ring's / every ring's mode
  "notify:text"                                   desktop notification
  anything else                                   run as a shell command

SOCKET PROTOCOL (JSON lines)
  server -> client : {"type":"state", ...}  on connect and whenever something changes
                     {"type":"event","t":..,"ring":..,"event":..,"payload":..,"actions":[..]}
  client -> server : {"cmd":"mode","ring":"j09"|"anko"|"all","mode":"scroll"|"next"} | {"cmd":"reload"} | {"cmd":"state"}
                     {"cmd":"set","mode":"scroll","ring":"j09","event":"tap","action":"key:KEY_SPACE"}
                       (mode "common" edits the [common.*] fallbacks; action "" removes the mapping)
                     {"cmd":"set_general","key":"hold_every","value":2}
                     {"cmd":"run","ring":"anko","action":"hypr:workspace +1"}   (test an action)
"""
import argparse, fcntl, glob, json, os, re, select, shlex, signal, socket, struct, subprocess, sys, time, tomllib

# ----------------------------------------------------------------------------- consts
EVIOCGRAB = 0x40044590
UI_SET_EVBIT, UI_SET_KEYBIT, UI_SET_RELBIT = 0x40045564, 0x40045565, 0x40045566
UI_DEV_SETUP, UI_DEV_CREATE, UI_DEV_DESTROY = 0x405C5503, 0x5501, 0x5502
EV_SYN, EV_KEY, EV_REL = 0, 1, 2
REL_X, REL_Y, REL_HWHEEL, REL_WHEEL, REL_WHEEL_HI_RES, REL_HWHEEL_HI_RES = 0, 1, 6, 8, 0x0B, 0x0C
BUS_VIRTUAL = 0x06
INPUT_EVENT = struct.Struct("qqHHi")

RINGS = {  # name -> (vid, pid)
    "j09": (0x248A, 0x8251),
    "anko": (0x05AC, 0x022C),
}
RING_LABEL = {"j09": "J09", "anko": "Anko"}
EVENTS = {
    "j09": ["btn1", "btn2", "btn3", "swipe_fwd", "swipe_back", "tap",
            "hold_fwd", "hold_back", "hold_end", "pad_move", "pad_down", "pad_up"],
    "anko": ["btn1", "btn2", "btn3", "btn1_long", "btn2_long", "btn3_long"],
}
EVENT_HELP = {
    "j09": {"btn1": "button 1 short", "btn2": "button 2 short", "btn3": "button 3 short",
            "swipe_fwd": "pad swipe forward", "swipe_back": "pad swipe back", "tap": "pad tap",
            "hold_fwd": "button 1 held (per frame)", "hold_back": "button 2/3 held (per frame)",
            "hold_end": "hold released", "pad_move": "finger moving on pad",
            "pad_down": "finger touches pad", "pad_up": "finger leaves pad"},
    "anko": {"btn1": "button 1 short (swipe up)", "btn2": "button 2 short (tap)",
             "btn3": "button 3 short (swipe down)", "btn1_long": "button 1 held (repeats)",
             "btn2_long": "button 2 long", "btn3_long": "button 3 held (repeats)"},
}

J09_RAMP_FWD_X = 1046      # canned "swipe forward" ramp always runs at this x
J09_RAMP_X = 1136          # canned "swipe back" and all slow button drags run at this x
J09_FAST_DY = 120          # per-frame |dy| above this = fast swipe, below = slow hold drag
J09_KEY_TO_BTN = {3: "btn1", 16: "btn2", 20: "btn3"}        # bit -> button (AC Home / Vol- / Sleep)
ANKO_KEY_TO_BTN = {0: "btn1_long", 3: "btn2_long", 1: "btn3_long"}  # Vol+ / Power / Vol-

DEFAULT_CONFIG = os.path.expanduser("~/.config/mezring/mezring.toml")
VERBOSE = False


def log(*a):
    if VERBOSE:
        print(time.strftime("%H:%M:%S"), *a, flush=True)


def u16(b, i):
    return b[i] | (b[i + 1] << 8)


def socket_path():
    base = os.environ.get("XDG_RUNTIME_DIR") or f"/tmp"
    return os.path.join(base, "mezring.sock" if base != "/tmp" else f"mezring-{os.getuid()}.sock")


# ----------------------------------------------------------------------------- key names
def load_keycodes():
    """KEY_*/BTN_* name -> code from the kernel header, with a small fallback."""
    codes = {"BTN_LEFT": 0x110, "BTN_RIGHT": 0x111, "BTN_MIDDLE": 0x112,
             "KEY_VOLUMEUP": 115, "KEY_VOLUMEDOWN": 114, "KEY_MUTE": 113,
             "KEY_PLAYPAUSE": 164, "KEY_NEXTSONG": 163, "KEY_PREVIOUSSONG": 165,
             "KEY_SPACE": 57, "KEY_ENTER": 28, "KEY_ESC": 1, "KEY_LEFT": 105,
             "KEY_RIGHT": 106, "KEY_UP": 103, "KEY_DOWN": 108, "KEY_PAGEUP": 104,
             "KEY_PAGEDOWN": 109, "KEY_LEFTCTRL": 29, "KEY_LEFTALT": 56,
             "KEY_LEFTSHIFT": 42, "KEY_LEFTMETA": 125, "KEY_TAB": 15, "KEY_F": 33}
    path = "/usr/include/linux/input-event-codes.h"
    try:
        pending = {}
        for line in open(path):
            m = re.match(r"#define\s+((?:KEY|BTN)_\w+)\s+(\S+)", line)
            if not m:
                continue
            name, val = m.groups()
            if val.startswith("0x") or val.isdigit():
                codes[name] = int(val, 0)
            else:
                pending[name] = val
        for _ in range(3):
            for name, val in list(pending.items()):
                expr = re.sub(r"\b((?:KEY|BTN)_\w+)\b", lambda m: str(codes.get(m.group(1), m.group(1))), val)
                try:
                    codes[name] = int(eval(expr, {"__builtins__": {}}), 0)
                    del pending[name]
                except Exception:
                    pass
    except OSError:
        pass
    return codes


KEYCODES = load_keycodes()


# ----------------------------------------------------------------------------- uinput
class UInput:
    """Two virtual devices: a keyboard (all KEY_*) and a mouse (buttons + rel axes)."""

    def __init__(self):
        self.kbd = self._create("mezring virtual keyboard", keys=range(1, 0x100), rels=())
        self.mouse = self._create("mezring virtual mouse", keys=range(0x110, 0x118),
                                  rels=(REL_X, REL_Y, REL_WHEEL, REL_HWHEEL, REL_WHEEL_HI_RES, REL_HWHEEL_HI_RES))
        time.sleep(0.3)  # let udev/libinput pick the devices up

    def _create(self, name, keys, rels):
        fd = os.open("/dev/uinput", os.O_WRONLY | os.O_NONBLOCK)
        fcntl.ioctl(fd, UI_SET_EVBIT, EV_KEY)
        for k in keys:
            fcntl.ioctl(fd, UI_SET_KEYBIT, k)
        if rels:
            fcntl.ioctl(fd, UI_SET_EVBIT, EV_REL)
            for r in rels:
                fcntl.ioctl(fd, UI_SET_RELBIT, r)
        setup = struct.pack("HHHH80sI", BUS_VIRTUAL, 0x4D5A, 0x0001, 1, name.encode(), 0)
        fcntl.ioctl(fd, UI_DEV_SETUP, setup)
        fcntl.ioctl(fd, UI_DEV_CREATE)
        return fd

    @staticmethod
    def _emit(fd, events):
        now = time.time()
        sec, usec = int(now), int((now % 1) * 1e6)
        buf = b"".join(INPUT_EVENT.pack(sec, usec, t, c, v) for t, c, v in events)
        buf += INPUT_EVENT.pack(sec, usec, EV_SYN, 0, 0)
        os.write(fd, buf)

    def key_combo(self, codes):
        self._emit(self.kbd, [(EV_KEY, c, 1) for c in codes])
        self._emit(self.kbd, [(EV_KEY, c, 0) for c in reversed(codes)])

    def click(self, code):
        self._emit(self.mouse, [(EV_KEY, code, 1)])
        self._emit(self.mouse, [(EV_KEY, code, 0)])

    def scroll(self, notches=0.0, hnotches=0.0):
        ev = []
        if notches:
            ev += [(EV_REL, REL_WHEEL_HI_RES, int(notches * 120))]
            if abs(notches) >= 1:
                ev += [(EV_REL, REL_WHEEL, int(notches))]
        if hnotches:
            ev += [(EV_REL, REL_HWHEEL_HI_RES, int(hnotches * 120))]
            if abs(hnotches) >= 1:
                ev += [(EV_REL, REL_HWHEEL, int(hnotches))]
        if ev:
            self._emit(self.mouse, ev)

    def move(self, dx, dy):
        if dx or dy:
            self._emit(self.mouse, [(EV_REL, REL_X, dx), (EV_REL, REL_Y, dy)])

    def close(self):
        for fd in (self.kbd, self.mouse):
            try:
                fcntl.ioctl(fd, UI_DEV_DESTROY)
                os.close(fd)
            except OSError:
                pass


# ----------------------------------------------------------------------------- parsers
class J09Parser:
    """Report 2 = buttons, report 5 = fake touchscreen (hover frames + canned ramps)."""

    def __init__(self):
        self.tip = []          # (x, y) frames of the current tip-down sequence
        self.phase = None      # None | "fwd" | "back" | "hold_fwd" | "hold_back" | "tap"
        self.last_hover = None
        self.last_hover_t = 0.0
        self.last_tip_t = 0.0

    def feed(self, r, t):
        r = bytes(r) + b"\0" * (11 - len(r))
        rid = r[0]
        if rid == 2:
            v = int.from_bytes(r[1:4], "little")
            for bit, btn in J09_KEY_TO_BTN.items():
                if v >> bit & 1:
                    yield btn, None
            if v and not any(v >> b & 1 for b in J09_KEY_TO_BTN):
                yield f"key_bit{v.bit_length() - 1}", None
            return
        if rid != 5:
            return
        flags, x, y = r[1], u16(r, 3), u16(r, 5)
        if flags & 1 == 0 and flags & 2:                 # hover: real finger position on the pad
            if self.last_hover is None or t - self.last_hover_t > 0.3:
                yield "pad_down", (x, y)
            else:
                dx, dy = x - self.last_hover[0], y - self.last_hover[1]
                if dx or dy:
                    yield "pad_move", (dx, dy)
            self.last_hover, self.last_hover_t = (x, y), t
            return
        if flags & 1:                                    # tip down
            self.last_tip_t = t
            if y > 4095 or x > 4095:                     # garbage frame at the end of ramp A
                return
            self.tip.append((x, y))
            n = len(self.tip)
            if n == 1:
                if x == J09_RAMP_FWD_X:
                    self.phase = "fwd"
                    yield "swipe_fwd", None
                elif x == J09_RAMP_X:
                    self.phase = None                    # decide after a few frames
                else:
                    self.phase = "tap"
            elif self.phase is None and x == J09_RAMP_X and n >= 3:
                dy = (self.tip[-1][1] - self.tip[0][1]) / (n - 1)
                if abs(dy) >= J09_FAST_DY:
                    self.phase = "back"
                    yield "swipe_back", None
                else:
                    self.phase = "hold_fwd" if dy > 0 else "hold_back"
                    for _ in range(n):
                        yield self.phase, None
            elif self.phase in ("hold_fwd", "hold_back"):
                yield self.phase, None
            return
        yield from self._release()                       # tip up

    def _release(self):
        n = len(self.tip)
        if self.phase == "tap" or (self.phase is None and n == 1):
            yield "tap", None
        elif self.phase is None and n >= 2:              # short x=1136 sequence, classify now
            dy = (self.tip[-1][1] - self.tip[0][1]) / (n - 1)
            yield ("swipe_back" if abs(dy) >= J09_FAST_DY else ("hold_fwd" if dy > 0 else "hold_back")), None
        if self.phase in ("hold_fwd", "hold_back"):
            yield "hold_end", None
        self.tip, self.phase = [], None

    def tick(self, t):
        """Timers: synthesize pad_up, and end a hold if the release frame got lost."""
        if self.last_hover is not None and t - self.last_hover_t > 0.3:
            self.last_hover = None
            yield "pad_up", None
        if self.tip and t - self.last_tip_t > 0.25:
            yield from self._release()


class AnkoParser:
    """Report 2 = canned touch gestures, report 3 = long-press keys."""

    def __init__(self):
        self.frames = []
        self.decided = False
        self.last_t = 0.0

    def feed(self, r, t):
        r = bytes(r) + b"\0" * (9 - len(r))
        rid = r[0]
        if rid == 3:
            v = int.from_bytes(r[1:4], "little")
            for bit, btn in ANKO_KEY_TO_BTN.items():
                if v >> bit & 1:
                    yield btn, None
            return
        if rid != 2:
            return
        flags, cid, y = r[1], r[2], u16(r, 5)
        if flags & 1:
            self.last_t = t
            self.frames.append(y)
            if self.decided:
                return
            if cid == 7:                                  # tap
                self.decided = True
                yield "btn2", None
            elif cid == 6 and len(self.frames) >= 2:
                self.decided = True
                yield ("btn1" if self.frames[1] < self.frames[0] else "btn3"), None
        else:
            self.frames, self.decided = [], False

    def tick(self, t):
        if self.frames and t - self.last_t > 0.3:
            self.frames, self.decided = [], False
        return ()


PARSERS = {"j09": J09Parser, "anko": AnkoParser}


# ----------------------------------------------------------------------------- devices
def find_devices():
    """{hidraw node: (ring, [event nodes], bt address)} for connected rings."""
    out = {}
    for dev in glob.glob("/sys/bus/hid/devices/0005:*"):
        try:
            kv = dict(l.split("=", 1) for l in open(dev + "/uevent").read().split("\n") if "=" in l)
            _, vid, pid = kv["HID_ID"].split(":")
            vid, pid = int(vid, 16), int(pid, 16)
        except (OSError, KeyError, ValueError):
            continue
        for ring, ids in RINGS.items():
            if (vid, pid) != ids:
                continue
            hidraws = [os.path.basename(p) for p in glob.glob(dev + "/hidraw/hidraw*")]
            events = [os.path.basename(p) for p in glob.glob(dev + "/input/input*/event*")]
            if hidraws:
                out["/dev/" + hidraws[0]] = (ring, ["/dev/input/" + e for e in events], kv.get("HID_UNIQ", "").upper())
    return out


class Ring:
    def __init__(self, node, name, events, addr, grab=True):
        self.node, self.name, self.addr = node, name, addr
        self.fd = os.open(node, os.O_RDONLY | os.O_NONBLOCK)
        self.parser = PARSERS[name]()
        self.battery = None
        self.grabbed = []
        if grab:
            for ev in events:
                try:
                    fd = os.open(ev, os.O_RDONLY | os.O_NONBLOCK)
                    fcntl.ioctl(fd, EVIOCGRAB, 1)
                    self.grabbed.append(fd)
                except OSError as e:
                    log(f"[{name}] could not grab {ev}: {e}")

    def poll_battery(self):
        if not self.addr:
            return
        try:
            out = subprocess.run(["bluetoothctl", "info", self.addr], capture_output=True, text=True, timeout=3).stdout
            m = re.search(r"Battery Percentage: 0x[0-9a-f]+ \((\d+)\)", out)
            self.battery = int(m.group(1)) if m else None
        except Exception:
            pass

    def close(self):
        for fd in [self.fd] + self.grabbed:
            try:
                os.close(fd)
            except OSError:
                pass


# ----------------------------------------------------------------------------- config I/O
def toml_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, list):
        return "[" + ", ".join(toml_value(x) for x in v) + "]"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {toml_value(x)}" for k, x in v.items()) + " }"
    return json.dumps(str(v))


def write_config(cfg, path):
    """Serialise our (flat-ish) config schema back to TOML. Comments are not kept."""
    lines = ["# mezring configuration — written by mezringd (edits from the bar panel land here).",
             "# Reference with comments: mezring.example.toml in the mezring repo.", ""]
    gen = cfg.get("general", {})
    if gen:
        lines.append("[general]")
        for k, v in gen.items():
            lines.append(f"{k} = {toml_value(v)}")
        lines.append("")
    for ring, table in cfg.get("common", {}).items():
        if table:
            lines.append(f"[common.{ring}]")
            for k, v in table.items():
                lines.append(f"{k} = {toml_value(v)}")
            lines.append("")
    for mode, rings in cfg.get("modes", {}).items():
        for ring in RINGS:
            if ring not in rings:      # a ring without a table does not take part in this mode
                continue
            table = rings[ring]
            lines.append(f"[modes.{mode}.{ring}]")
            for k, v in table.items():
                lines.append(f"{k} = {toml_value(v)}")
            lines.append("")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines))
    os.replace(tmp, path)


def parse_action_text(text):
    """Panel sends a plain string; 'a | b' means an ordered list of actions."""
    text = text.strip()
    if not text:
        return None
    if " | " in text:
        return [p.strip() for p in text.split(" | ") if p.strip()]
    return text


def action_text(a):
    if a is None:
        return ""
    return " | ".join(a) if isinstance(a, list) else str(a)


# ----------------------------------------------------------------------------- hyprland
def hypr_lua(arg):
    """Hyprland >= 0.5x takes dispatchers as Lua (hl.dsp.*). Accept that form
    verbatim, and translate the classic text dispatchers people know."""
    arg = arg.strip()
    if arg.startswith("hl."):
        return arg
    name, _, rest = arg.partition(" ")
    rest = rest.strip()
    q = json.dumps(rest)
    table = {
        "workspace": lambda: f'hl.dsp.focus({{ workspace = {q} }})',
        "focusmonitor": lambda: f'hl.dsp.focus({{ monitor = {q} }})',
        "movefocus": lambda: f'hl.dsp.focus({{ direction = {q} }})',
        "cyclenext": lambda: "hl.dsp.window.cycle_next()",
        "cycleprev": lambda: "hl.dsp.window.cycle_next({ prev = true })",
        "killactive": lambda: "hl.dsp.window.close()",
        "fullscreen": lambda: f'hl.dsp.window.fullscreen({{ mode = {"\"maximized\"" if rest == "1" else "\"fullscreen\""} }})',
        "togglefloating": lambda: 'hl.dsp.window.float({ action = "toggle" })',
        "togglespecialworkspace": lambda: f'hl.dsp.workspace.toggle_special({json.dumps(rest or "special")})',
        "movetoworkspace": lambda: f'hl.dsp.window.move({{ workspace = {q} }})',
        "movetoworkspacesilent": lambda: f'hl.dsp.window.move({{ workspace = {q}, follow = false }})',
        "swapwindow": lambda: f'hl.dsp.window.swap({{ direction = {q} }})',
        "bringactivetotop": lambda: "hl.dsp.window.bring_to_top()",
    }
    if name in table:
        return table[name]()
    log(f"hypr: no translation for {arg!r}; passing through (use the hl.dsp.* form)")
    return arg


def hypr_cycle(prev=False):
    """Focus the next/previous window on the active workspace. Done here because
    Hyprland's Lua cycle_next() ignores its direction argument."""
    def q(*args):
        return json.loads(subprocess.run(["hyprctl", "-j"] + list(args), capture_output=True, text=True, timeout=2).stdout or "null")
    try:
        active = q("activewindow") or {}
        ws = (active.get("workspace") or {}).get("id")
        if ws is None:
            ws = (q("activeworkspace") or {}).get("id")
        wins = [c for c in q("clients") or [] if c.get("mapped") and not c.get("hidden")
                and (c.get("workspace") or {}).get("id") == ws]
        if len(wins) < 2:
            return
        addrs = [c["address"] for c in wins]
        i = addrs.index(active["address"]) if active.get("address") in addrs else -1
        target = addrs[(i + (-1 if prev else 1)) % len(addrs)]
        subprocess.Popen(["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{target}" }})'], stdout=subprocess.DEVNULL)
    except Exception as e:
        print(f"hypr cycle failed: {e}", file=sys.stderr)


# ----------------------------------------------------------------------------- actions
class Engine:
    def __init__(self, cfg, cfg_path, dry_run=False):
        self.cfg_path = cfg_path
        self.dry = dry_run
        self.ui = None
        self.active = {}            # ring -> current mode
        self.load(cfg)
        if not dry_run:
            try:
                self.ui = UInput()
                log("uinput: virtual keyboard + mouse created")
            except OSError as e:
                print(f"uinput unavailable ({e}); key:/scroll:/click:/pointer actions disabled. "
                      f"Run install.sh (udev rule + uinput module) to enable.", file=sys.stderr)
        self.hold_count = 0
        self.pad_scroll_acc = 0.0
        self.pointer_acc = [0.0, 0.0]
        self.on_change = lambda: None   # set by the hub to broadcast state

    def load(self, cfg):
        self.cfg = cfg
        self.general = cfg.setdefault("general", {})
        self.modes = cfg.setdefault("modes", {})
        cfg.setdefault("common", {})
        if not self.modes:
            self.modes["default"] = {}
        self.mode_names = list(self.modes)
        # a ring only takes part in the modes that define a table for it
        self.ring_modes = {r: [m for m in self.mode_names if r in self.modes[m]] or self.mode_names[:1] for r in RINGS}
        start = self.general.get("start_mode", self.mode_names[0])
        for ring in RINGS:
            if self.active.get(ring) not in self.ring_modes[ring]:
                want = start.get(ring) if isinstance(start, dict) else start
                self.active[ring] = want if want in self.ring_modes[ring] else self.ring_modes[ring][0]
        self.hold_every = max(1, int(self.general.get("hold_every", 2)))

    def reload(self):
        try:
            self.load(tomllib.load(open(self.cfg_path, "rb")))
            log("config reloaded")
        except Exception as e:
            print(f"config reload failed: {e}", file=sys.stderr)
        self.on_change()

    def save(self):
        write_config(self.cfg, self.cfg_path)
        self.on_change()

    def set_mapping(self, mode, ring, event, action):
        if ring not in RINGS:
            raise ValueError(f"unknown ring {ring}")
        table = self.cfg["common"].setdefault(ring, {}) if mode == "common" else self.modes[mode].setdefault(ring, {})
        a = parse_action_text(action)
        if a is None:
            table.pop(event, None)
        else:
            table[event] = a
        self.save()

    def set_general(self, key, value):
        self.general[key] = value
        self.load(self.cfg)
        self.save()

    # -- lookup
    def actions_for(self, ring, event):
        a = self.modes.get(self.active.get(ring), {}).get(ring, {}).get(event)
        if a is None:
            a = self.cfg.get("common", {}).get(ring, {}).get(event)
        if a is None:
            return []
        return a if isinstance(a, list) else [a]

    # -- dispatch
    def handle(self, ring, event, payload):
        """Returns the actions that were run (for the event stream), or None if throttled."""
        if event in ("hold_fwd", "hold_back"):
            self.hold_count += 1
            if self.hold_count % self.hold_every:
                return None
        elif event == "hold_end":
            self.hold_count = 0
        acts = self.actions_for(ring, event)
        if event != "pad_move":
            log(f"[{ring}] {event}" + (f" {payload}" if payload else "") + (f" -> {acts}" if acts else ""))
        for a in acts:
            try:
                self.run(a, payload, ring)
            except Exception as e:  # never let one bad action kill the daemon
                print(f"action {a!r} failed: {e}", file=sys.stderr)
        return acts

    def run(self, a, payload, ring=None):
        kind, _, arg = a.partition(":")
        if self.dry and kind != "mode":
            print(f"  DRY {a}", flush=True)
            return
        if kind == "key" and self.ui:
            self.ui.key_combo([KEYCODES[k.strip()] for k in arg.split("+")])
        elif kind == "scroll" and self.ui:
            self.ui.scroll(notches=float(arg))
        elif kind == "hscroll" and self.ui:
            self.ui.scroll(hnotches=float(arg))
        elif kind == "click" and self.ui:
            self.ui.click({"left": 0x110, "right": 0x111, "middle": 0x112}[arg or "left"])
        elif kind == "pointer" and self.ui and payload:
            s = float(self.general.get("pointer_speed", 0.25))
            sx, sy = int(self.general.get("pointer_x_sign", 1)), int(self.general.get("pointer_y_sign", 1))
            self.pointer_acc[0] += payload[0] * s * sx
            self.pointer_acc[1] += payload[1] * s * sy
            dx, dy = int(self.pointer_acc[0]), int(self.pointer_acc[1])
            self.pointer_acc[0] -= dx
            self.pointer_acc[1] -= dy
            self.ui.move(dx, dy)
        elif kind == "scrollpad" and self.ui and payload:
            div = float(self.general.get("pad_scroll_divisor", 60))
            sign = int(self.general.get("pad_scroll_sign", -1))
            self.pad_scroll_acc += payload[1] * sign / div
            if abs(self.pad_scroll_acc) >= 0.1:
                self.ui.scroll(notches=self.pad_scroll_acc)
                self.pad_scroll_acc = 0.0
        elif kind == "wtype":
            subprocess.Popen(["wtype"] + shlex.split(arg))
        elif kind == "hypr":
            if arg.strip() in ("cyclenext", "cycleprev"):
                hypr_cycle(prev=arg.strip() == "cycleprev")
            else:
                subprocess.Popen(["hyprctl", "dispatch", hypr_lua(arg)], stdout=subprocess.DEVNULL)
        elif kind == "lua":
            subprocess.Popen(["hyprctl", "eval", arg], stdout=subprocess.DEVNULL)
        elif kind == "mode":
            target, _, name = arg.rpartition(":")      # "next" | "anko:hypr" | "all:scroll"
            self.set_mode(name, target or ring or "all")
        elif kind == "notify":
            subprocess.Popen(["notify-send", "-t", "2000", "-a", "mezring", arg])
        elif kind in ("key", "scroll", "hscroll", "click", "pointer", "scrollpad"):
            pass  # uinput not available; already warned at startup
        else:
            subprocess.Popen(a, shell=True)

    def set_mode(self, name, ring="all"):
        rings = list(RINGS) if ring in ("all", "", None) else [ring]
        for r in rings:
            if r not in RINGS:
                raise ValueError(f"unknown ring {r}")
        if name != "next" and name not in self.modes:
            raise ValueError(f"unknown mode {name}")
        for r in rings:
            new = name
            names = self.ring_modes[r]
            if name == "next":
                i = names.index(self.active[r]) if self.active[r] in names else -1
                new = names[(i + 1) % len(names)]
            elif name not in names:
                raise ValueError(f"{RING_LABEL[r]} has no '{name}' mode (add a [modes.{name}.{r}] table)")
            self.active[r] = new
            log(f"[{r}] mode -> {new}")
            if self.general.get("mode_notify", True) and not self.dry:
                subprocess.Popen(["notify-send", "-t", "1500", "-a", "mezring", f"{RING_LABEL[r]} mode: {new}"])
        # remember per-ring modes across restarts
        self.general["start_mode"] = dict(self.active)
        try:
            write_config(self.cfg, self.cfg_path)
        except OSError as e:
            print(f"could not persist mode: {e}", file=sys.stderr)
        self.on_change()


# ----------------------------------------------------------------------------- socket hub
class Hub:
    """Unix socket server: pushes state + events to panels, accepts commands."""

    def __init__(self, engine, rings_ref):
        self.engine = engine
        self.rings = rings_ref     # fd -> Ring (shared with main loop)
        self.path = socket_path()
        self.clients = {}          # sock -> recv buffer
        try:
            os.unlink(self.path)
        except FileNotFoundError:
            pass
        self.srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.srv.bind(self.path)
        os.chmod(self.path, 0o600)
        self.srv.listen(8)
        self.srv.setblocking(False)
        engine.on_change = self.broadcast_state

    def fds(self):
        return [self.srv] + list(self.clients)

    def state(self):
        e = self.engine
        rings = {}
        for name in RINGS:
            r = next((r for r in self.rings.values() if r.name == name), None)
            rings[name] = {"label": RING_LABEL[name], "connected": r is not None,
                           "node": r.node if r else None, "addr": r.addr if r else None,
                           "battery": r.battery if r else None}
        mappings = {m: {ring: {ev: action_text(a) for ev, a in t.get(ring, {}).items()} for ring in RINGS}
                    for m, t in e.modes.items()}
        mappings["common"] = {ring: {ev: action_text(a) for ev, a in e.cfg.get("common", {}).get(ring, {}).items()}
                              for ring in RINGS}
        for name in RINGS:
            rings[name]["mode"] = e.active.get(name)
        return {"type": "state", "active": dict(e.active), "modes": e.mode_names, "ring_modes": e.ring_modes, "rings": rings,
                "events": EVENTS, "event_help": EVENT_HELP, "mappings": mappings,
                "general": e.general, "uinput": e.ui is not None, "config": e.cfg_path}

    def send(self, s, obj):
        try:
            s.sendall((json.dumps(obj) + "\n").encode())
        except OSError:
            self.drop(s)

    def broadcast(self, obj):
        for s in list(self.clients):
            self.send(s, obj)

    def broadcast_state(self):
        self.broadcast(self.state())

    def drop(self, s):
        self.clients.pop(s, None)
        try:
            s.close()
        except OSError:
            pass

    def event(self, ring, ev, payload, actions):
        if ev == "pad_move" or not self.clients:
            return
        self.broadcast({"type": "event", "t": time.time(), "ring": ring, "event": ev,
                        "payload": list(payload) if payload else None, "actions": actions})

    def service(self, ready):
        if self.srv in ready:
            try:
                c, _ = self.srv.accept()
                c.setblocking(False)
                self.clients[c] = b""
                self.send(c, self.state())
            except OSError:
                pass
        for s in list(self.clients):
            if s not in ready:
                continue
            try:
                data = s.recv(65536)
            except OSError:
                data = b""
            if not data:
                self.drop(s)
                continue
            self.clients[s] += data
            while b"\n" in self.clients[s]:
                line, _, self.clients[s] = self.clients[s].partition(b"\n")
                self.command(s, line)

    def command(self, s, line):
        try:
            msg = json.loads(line or b"{}")
            cmd = msg.get("cmd")
            if cmd == "state":
                self.send(s, self.state())
            elif cmd == "mode":
                self.engine.set_mode(msg["mode"], msg.get("ring", "all"))
            elif cmd == "reload":
                self.engine.reload()
            elif cmd == "set":
                self.engine.set_mapping(msg["mode"], msg["ring"], msg["event"], msg.get("action", ""))
            elif cmd == "set_general":
                self.engine.set_general(msg["key"], msg["value"])
            elif cmd == "run":                      # test an action string as if a ring sent it
                self.engine.run(msg["action"], None, msg.get("ring"))
            else:
                self.send(s, {"type": "error", "error": f"unknown cmd {cmd}"})
        except Exception as e:
            self.send(s, {"type": "error", "error": str(e)})

    def close(self):
        for s in list(self.clients):
            self.drop(s)
        self.srv.close()
        try:
            os.unlink(self.path)
        except OSError:
            pass


# ----------------------------------------------------------------------------- main loop
def main():
    global VERBOSE
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("-c", "--config", default=DEFAULT_CONFIG)
    ap.add_argument("-v", "--verbose", action="store_true", help="log every event and action")
    ap.add_argument("-n", "--dry-run", action="store_true", help="print actions instead of running them")
    ap.add_argument("--no-grab", action="store_true", help="leave the rings' evdev nodes alone")
    ap.add_argument("--no-socket", action="store_true", help="do not serve the panel socket")
    args = ap.parse_args()
    VERBOSE = args.verbose or args.dry_run

    cfg_path = args.config
    if not os.path.exists(cfg_path):
        example = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "mezring.toml")
        cfg = tomllib.load(open(example, "rb"))
        write_config(cfg, cfg_path)
        print(f"created {cfg_path} from defaults")
    cfg = tomllib.load(open(cfg_path, "rb"))

    engine = Engine(cfg, cfg_path, dry_run=args.dry_run)
    rings = {}   # fd -> Ring
    hub = None if args.no_socket else Hub(engine, rings)
    stop = False

    def on_sig(*_):
        nonlocal stop
        stop = True
    signal.signal(signal.SIGINT, on_sig)
    signal.signal(signal.SIGTERM, on_sig)
    signal.signal(signal.SIGHUP, lambda *_: engine.reload())

    def emit(ring, ev, payload):
        acts = engine.handle(ring.name, ev, payload)
        if hub and acts is not None:
            hub.event(ring.name, ev, payload, acts)

    last_scan = last_batt = 0.0
    print(f"mezringd up, modes={engine.active}, config={cfg_path}" + (f", socket={hub.path}" if hub else ""), flush=True)
    while not stop:
        now = time.time()
        if now - last_scan >= 1.0:
            last_scan = now
            open_nodes = {r.node for r in rings.values()}
            for node, (name, events, addr) in find_devices().items():
                if node in open_nodes:
                    continue
                try:
                    r = Ring(node, name, events, addr, grab=not args.no_grab)
                    rings[r.fd] = r
                    print(f"[+] {name} on {node} ({len(r.grabbed)} evdev nodes grabbed)", flush=True)
                    r.poll_battery()
                    if hub:
                        hub.broadcast_state()
                except OSError as e:
                    print(f"[!] {name} {node}: {e}", file=sys.stderr)
        if now - last_batt >= 60.0 and rings:
            last_batt = now
            for r in rings.values():
                r.poll_battery()
            if hub:
                hub.broadcast_state()
        try:
            ready, _, _ = select.select(list(rings) + (hub.fds() if hub else []), [], [], 0.05)
        except InterruptedError:
            continue
        now = time.time()
        for fd in ready:
            if fd not in rings:
                continue
            r = rings[fd]
            try:
                data = os.read(fd, 64)
            except OSError:
                print(f"[-] {r.name} on {r.node} disconnected", flush=True)
                r.close()
                del rings[fd]
                if hub:
                    hub.broadcast_state()
                continue
            for ev, payload in r.parser.feed(data, now):
                emit(r, ev, payload)
        for r in list(rings.values()):
            for ev, payload in r.parser.tick(now):
                emit(r, ev, payload)
        if hub:
            hub.service(ready)

    for r in rings.values():
        r.close()
    if hub:
        hub.close()
    if engine.ui:
        engine.ui.close()


if __name__ == "__main__":
    main()
