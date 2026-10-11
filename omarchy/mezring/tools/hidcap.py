#!/usr/bin/env python3
"""Capture and decode raw HID reports from the J09 and Anko rings.

Finds the rings' /dev/hidrawN nodes by HID_NAME, reads them concurrently and
prints every report with a timestamp, raw hex and a decoded view based on the
report descriptors recorded in RECON.md.  Stdlib only.

Usage:  tools/hidcap.py            # capture until Ctrl-C
        tools/hidcap.py -o cap.log # also append raw lines to a file
Requires read access to the hidraw nodes (install 70-mezring.rules).
"""
import argparse, glob, os, select, sys, time

RINGS = {
    "J09": {"vid": 0x248A, "pid": 0x8251},
    "Anko": {"vid": 0x05AC, "pid": 0x022C},
}

J09_KEYS = [
    "Menu", "AL_Calculator", "AL_ConsumerCfg", "AC_Home", "AL_Email",
    "AL_WordProc", "AC_Search", "AC_Back", "AC_Forward", "AC_Stop",
    "AC_Refresh", "ScanPrev", "ScanNext", "Stop", "PlayPause", "Vol+",
    "Vol-", "Mute", "Eject", "Power", "Sleep", "VoiceCmd", "RandomPlay",
    "AL_Screensaver",
]
ANKO_KEYS = ["Vol+", "Vol-", "ShowKeyboard", "Power", "Menu", "Back", "AC_Home"]


def bits(data, names):
    v = int.from_bytes(data, "little")
    return [n for i, n in enumerate(names) if v >> i & 1]


def u16(b, i):
    return b[i] | (b[i + 1] << 8)


def decode(ring, r):
    """Reports arrive with variable length over BLE (the firmware truncates
    trailing bytes), so pad to the descriptor's size before decoding."""
    if not r:
        return "?"
    rid = r[0]
    if ring == "J09":
        if rid == 2:
            r = bytes(r) + b"\0" * (4 - len(r))
            return "KEYS " + (",".join(bits(r[1:4], J09_KEYS)) or "(release)")
        if rid == 5:
            r = bytes(r) + b"\0" * (11 - len(r))
            f = r[1]
            x, y = u16(r, 3), u16(r, 5)
            kind = "TOUCH" if f & 1 else "HOVER"   # hover = raw finger on the ring's pad
            if y > 4095 or x > 4095:
                kind += "(garbage)"
            return (f"{kind} tip={f & 1} inrange={f >> 1 & 1} n={r[2]} "
                    f"x={x} y={y} w={u16(r, 7)} h={u16(r, 9)}")
    if ring == "Anko":
        if rid == 3:
            r = bytes(r) + b"\0" * (4 - len(r))
            return "KEYS " + (",".join(bits(r[1:4], ANKO_KEYS)) or "(release)")
        if rid == 2:
            r = bytes(r) + b"\0" * (8 - len(r))
            f = r[1]
            return (f"TOUCH tip={f & 1} inrange={f >> 1 & 1} id={r[2]} "
                    f"x={u16(r, 3)} y={u16(r, 5)} n={r[7]}")
    return f"UNKNOWN report id {rid}"


def find_nodes():
    found = {}
    for uev in glob.glob("/sys/class/hidraw/hidraw*/device/uevent"):
        kv = dict(l.split("=", 1) for l in open(uev).read().split("\n") if "=" in l)
        hid_id = kv.get("HID_ID", "")  # 0005:0000248A:00008251
        try:
            _, vid, pid = hid_id.split(":")
            vid, pid = int(vid, 16), int(pid, 16)
        except ValueError:
            continue
        for name, ids in RINGS.items():
            if (vid, pid) == (ids["vid"], ids["pid"]):
                node = "/dev/" + uev.split("/")[4]
                found[node] = name
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--out", help="append raw capture lines to this file")
    args = ap.parse_args()

    nodes = find_nodes()
    if not nodes:
        sys.exit("no ring hidraw nodes found; are the rings connected?")
    fds = {}
    for node, name in nodes.items():
        try:
            fds[os.open(node, os.O_RDONLY | os.O_NONBLOCK)] = (node, name)
            print(f"[+] {name:5s} {node}")
        except PermissionError:
            print(f"[!] {name:5s} {node}: permission denied (install 70-mezring.rules)")
    if not fds:
        sys.exit(1)
    out = open(args.out, "a") if args.out else None
    print("capturing... Ctrl-C to stop")
    last_scan = time.time()
    try:
        while True:
            # pick up rings that (re)connect mid-capture: they get a new hidraw node
            if time.time() - last_scan > 1.0:
                last_scan = time.time()
                open_nodes = {v[0] for v in fds.values()}
                for node, name in find_nodes().items():
                    if node in open_nodes:
                        continue
                    try:
                        fds[os.open(node, os.O_RDONLY | os.O_NONBLOCK)] = (node, name)
                        print(f"[+] {name:5s} {node} (appeared)", flush=True)
                    except PermissionError:
                        pass
            r, _, _ = select.select(list(fds), [], [], 1.0)
            for fd in r:
                node, name = fds[fd]
                try:
                    data = os.read(fd, 64)
                except OSError as e:
                    print(f"[-] {name} {node} gone ({e})")
                    del fds[fd]
                    continue
                ts = time.strftime("%H:%M:%S") + f".{int(time.time() * 1000) % 1000:03d}"
                hx = " ".join(f"{b:02x}" for b in data)
                line = f"{ts} {name:5s} {hx:34s} | {decode(name, data)}"
                print(line, flush=True)
                if out:
                    out.write(line + "\n"); out.flush()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
