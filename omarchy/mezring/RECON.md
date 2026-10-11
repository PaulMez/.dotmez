# mezring recon — 2026-10-11

Host: adapter 2C:6D:C1:90:5F:7D (Intel, BlueZ 5.87, kernel 7.2.3-arch1-3, Hyprland/Omarchy).

Two rings, both paired to this laptop today (first-ever pairing 20:21 / 20:24).
Both advertise as HID devices. Both carry a near-identical "touchscreen finger"
digitizer collection: that is how they scroll TikTok, they fake a finger
dragging on an absolute 4096x4096 touch surface. Standard media keys ride in a
separate Consumer Control report.

(The earlier paired "BT5.2 Keyboard" 13:05:AA:90:2A:B1 and "BT 5.1 keyboard-1505"
15:05:02:20:0A:96 are NOT the rings. They were asleep/off and unrelated.)

Raw descriptors saved: `j09_rdesc.bin` (163 B), `anko_rdesc.bin` (128 B).
GATT dumps: scratchpad j09_gatt.txt / j09_gatt_vals.txt (copied below).

---------------------------------------------------------------------------
## Ring 1 — "J09"   (Bluetooth LE, HID over GATT)
---------------------------------------------------------------------------
- Address      : C4:3B:40:BA:FB:A7 (public)
- Chip / FW    : **Zhuhai Jieli** (JL) — Device Info says
                 Manufacturer `zhuhai_jieli`, Model `hid_mouse`, Serial `000000`,
                 HW/FW/SW rev `0.0.1`. i.e. it runs the stock Jieli SDK HID demo
                 app, basically unmodified. SDK is public (Apache-2.0):
                 https://github.com/Jieli-Tech/fw-AC63_BT_SDK  (apps/hid)
- PnP ID       : src 0x02 (USB) VID 0x248A PID 0x8251 ver 0x0001
- Appearance   : 0x03C1 Keyboard. Adv flags 0x06.
- Battery      : GATT Battery Service, 39% -> 32% during session (drains fast).
- PPCP         : conn interval 7.5–11.25 ms, slave latency 100, timeout 3 s.
- HID Info     : bcdHID 1.11, country 0, flags 0x03 (remote wake, normally connectable)
- Protocol Mode: 1 (Report). Boot Mouse Input Report char also present.
- Kernel       : hid-generic. Two input nodes:
                   "J09 Consumer Control" (keys)  and  "J09" (touch: ABS_X/Y, BTN_TOUCH, BTN_TOOL_PEN)
- Hyprland     : only `j09-consumer-control` shows up (as a keyboard). The touch
                 node is NOT picked up by libinput, so swipes do nothing on desktop.

### GATT table (handles)
```
0x0001 GAP 1800        : 2a00 Device Name "J09", 2a01 Appearance c1 03, 2a04 PPCP 06 00 09 00 64 00 2c 01
0x0008 GATT 1801       : 2a05 Service Changed
0x000c DIS 180a        : 2a29 zhuhai_jieli | 2a24 hid_mouse | 2a25 000000 | 2a27/2a26/2a28 0.0.1
                         2a23 System ID, 2a2a IEEE cert (unread), 2a50 PnP 02 8a 24 51 82 01 00
0x001f Battery 180f    : 2a19 level (read/notify)
0x0023 HID 1812        : 2a4e Protocol Mode (=1)
                         2a4d Report  char0026  RptRef 01 01  (ID1 input)   r/w/notify  <- not in report map
                         2a4d Report  char002a  RptRef 02 01  (ID2 input)   r/w/notify  <- CONSUMER KEYS
                         2a4d Report  char002e  RptRef 01 02  (ID1 output)  r/w/wwr     <- not in report map
                         2a4d Report  char0031  RptRef 03 01  (ID3 input)   r/w/notify  <- unused
                         2a4d Report  char0035  RptRef 04 01  (ID4 input)   r/w/notify  <- unused
                         2a4d Report  char0039  RptRef 05 01  (ID5 input)   r/w/notify  <- TOUCH
                         2a4d Report  char003d  RptRef 06 01  (ID6 input)   r/w/notify  <- unused
                         2a4b Report Map, 2a33 Boot Mouse Input, 2a4a HID Info 11 01 00 03, 2a4c Control Point
0x004a **ae40** vendor : ae41 write-without-response | ae42 notify
0x0050 **ae30** vendor : ae01 wwr | ae02 notify | ae03 wwr | ae04 notify | ae05 indicate | ae10 read/write (=00 00 00 00)
```
ae30/ae40 (+ae01..ae05, ae10, ae41/ae42) are Jieli's proprietary RCSP / SPP-over-BLE
command channels. Same family as the "cat printer" AE30/AE01/AE02 and the E87 badge
researched here: https://github.com/ElectronicCats/jieli-ble-badge-research
(RCSP 6-step auth handshake on AE01/AE02, custom Jieli block cipher, UFW firmware
container, OTA via their protocol; chipkey is per-PID so their exact tooling will
need adapting — but the protocol knowledge and the pure-Python UFW/RCSP tools carry
over). THIS IS THE FIRMWARE-HACKING PATH for the J09.

### HID report descriptor (163 B) — decoded
```
05 0c 09 01 a1 01           Consumer Control, Application collection
 85 02                      REPORT ID 2
 15 00 25 01 75 01 95 18    24 x 1-bit buttons, in this bit order:
   bit0  0x040 Menu              bit8  0x225 AC Forward      bit16 0x0EA Vol-
   bit1  0x192 AL Calculator     bit9  0x226 AC Stop         bit17 0x0E2 Mute
   bit2  0x183 AL Consumer Cfg   bit10 0x227 AC Refresh      bit18 0x0B8 Eject
   bit3  0x223 AC Home           bit11 0x0B6 Scan Prev       bit19 0x030 Power
   bit4  0x18A AL Email          bit12 0x0B5 Scan Next       bit20 0x032 Sleep
   bit5  0x182 AL Word Proc.     bit13 0x0B7 Stop            bit21 0x0CF Voice Cmd
   bit6  0x221 AC Search         bit14 0x0CD Play/Pause      bit22 0x0B9 Random Play
   bit7  0x224 AC Back           bit15 0x0E9 Vol+            bit23 0x1B1 AL Screensaver
   (0x204 listed as 25th usage, no bit for it)
 81 02 c0
05 0d 09 01 a1 01           Digitizer, Application collection
 85 05                      REPORT ID 5
 09 22 a1 02                Finger (logical collection)
  09 42 ..  1 bit  Tip Switch
  09 32 ..  1 bit  In Range
  95 06 81 03     6 bits pad
  09 54 75 08     Contact Count   (8 bit)
  05 01 26 ff 0f 75 10 09 30 46 b5 04   X  16-bit  0..4095  (phys 0..1205)
  09 31 46 8a 03                        Y  16-bit  0..4095  (phys 0..906)
 c0
 05 0d 09 48 09 49 95 02 81 02   Width, Height 16-bit each
c0
```
Wire format (as the kernel/hidraw sees it):
- Report 2 (keys)  : `02 b0 b1 b2`                 — 4 bytes, bitfield above
- Report 5 (touch) : `05 ff cc xl xh yl yh wl wh hl hh` — 11 bytes
                     ff bit0=tip bit1=inrange, cc=contact count, X/Y little-endian

### J09 — observed raw reports (capture 2026-10-11 20:40, tools/hidcap.py)
!! BlueZ caveat: subscribing to the HID Report characteristics with
   `bluetoothctl ... notify on` and then quitting DISABLED the notifications
   BlueZ's own HOG driver had armed — the ring went silent until
   `bluetoothctl disconnect` + reconnect. Never poke the HID chars via GATT
   while the input profile is active.

Reports are VARIABLE LENGTH on the wire (firmware truncates). Seen:
```
ID 5, 8 bytes   05 02 00 xl xh yl yh 8e           "HOVER": tip=0 inrange=1 — REAL finger
                                                   tracking on the ring's touch pad, ~30 ms
                                                   cadence, x≈2590..2850, y≈730..2110 observed.
ID 5, 11 bytes  05 03 00 xl xh yl yh 8e 03 8e 03  "TOUCH": tip=1, w=h=910. Canned ramps:
   swipe "A":  x=1046, y 1400→3200 in 7 frames @30 ms, then one garbage frame
               (16 09 07 ac = x 2326 y 44039), then release (05 00 ...) at same garbage coords
   swipe "B":  x=1136, y 3200→756 in 12 frames @30 ms, release at (1136,756)
   tap      :  one TOUCH frame at the current hover position, release at (1024,1064)
ID 2, 3 bytes   02 08 00        bit3  = AC Home   (0x223)
ID 2, 4 bytes   02 00 00 10     bit20 = Sleep     (0x032)
                02 00 00 00     release
```
!! SAFETY: the `02 00 00 10` report is Consumer usage 0x032 "Sleep" -> Linux KEY_SLEEP.
   systemd-logind watches the ring's input node ("Watching system buttons") and
   SUSPENDED THE LAPTOP at 20:40:45 when that button was pressed (both rings then
   dropped). Fix: 71-mezring.rules removes the `power-switch` udev tag so logind
   ignores the rings. Until installed, that J09 button = suspend.

### J09 physical layout -> reports  (labelled capture 20:46, user: 3 buttons + touch pad)
```
finger resting on pad   : HOVER stream only (05 02 00 ..), ~9 Hz when still, ~30 Hz moving,
                          jitter ±40 counts around the finger position
swipe forward on pad    : 2-3 HOVER frames, then ramp A  x=1046, y 1400->3200, 7 f @30 ms, + garbage frame
swipe backward on pad   : 2-3 HOVER frames, then ramp B  x=1136, y 3200->756, 12 f @30 ms
tap on pad              : ONE TOUCH frame at the finger's hover position, release at (1024,1064)
button 1 short          : KEY  02 08 00      -> AC Home (0x223)
button 1 long (2 s)     : slow drag  x=1136, y 1150->2750, 33 f over 1.3 s (held = keeps dragging)
button 2 short          : KEY  02 00 00 01   -> Volume Decrement (0xEA)
button 2 long (2 s)     : slow drag  x=1136, y 3150->2150, 21 f over 0.8 s (opposite direction)
button 3 short          : KEY  02 00 00 10   -> Sleep (0x032)  [= the laptop-suspend button, see SAFETY]
button 3 long (2 s)     : slow drag  x=1136, y 3150->550, 53 f over 2.1 s (y decreasing, like button 2 long)
```
With 71-mezring.rules installed (20:44) button 3 no longer suspends the host (verified 20:48).
Long-presses on the buttons produce a continuous *slow* synthetic drag (≈ 1 count/ms)
for as long as the button is held — these are "scroll while held" gestures, distinct
from the fast fixed-length swipe ramps the pad triggers.

Hover frames precede every canned gesture: the firmware tracks the finger, then
decides swipe/tap and plays a fixed sequence. For a desktop driver the HOVER
stream is the interesting part (true analog position from the pad); the canned
TOUCH ramps only tell us the direction the firmware decided on.
Anko report 2 is 9 bytes on the wire (8 + pad); both rings need length-tolerant parsing.

---------------------------------------------------------------------------
## Ring 2 — "Anko43559336"   (Bluetooth Classic BR/EDR, HID profile)
---------------------------------------------------------------------------
- Address      : A5:34:88:F9:9A:7D (public). Anko = Kmart AU house brand.
- Transport    : BR/EDR only. SDP: HID 0x1124, PnP 0x1200. No GATT.
- CoD          : 0x002540  Peripheral / Keyboard, service bit "Capturing".
- PnP ID       : VID 0x05AC PID 0x022C  = **spoofs Apple Wireless Keyboard (2007 alu)**
- EIR manuf.   : company 0x7262 ("rb"), data `32 32 78 78 11 22 33 44 55 66 aa bb 00 00`
                 ("22xx" + placeholder bytes = untouched template firmware).
- Chip         : unknown yet (Classic-only cheap SoC; candidates Jieli AC63xx in
                 BR/EDR mode, Beken, Actions). An SDP record dump (needs sudo btmon
                 during reconnect) would show the service name string and may hint.
- Kernel       : binds **hid-apple** (because 05AC:022C). Log:
                 "Fn key not found (Apple Wireless Keyboard clone?), disabling Fn key handling"
                 so hid-apple is effectively pass-through here, but it's the wrong driver.
                 Reports "BLUETOOTH HID v1.1b".
- Input        : ONE combined input node "Anko43559336" with KEY_ESC, KEY_VOLUMEDOWN,
                 KEY_VOLUMEUP, KEY_POWER, KEY_MENU, KEY_HOMEPAGE, KEY_KEYBOARD,
                 BTN_TOOL_PEN, BTN_TOUCH, ABS_X, ABS_Y, ABS_MISC.
- Hyprland     : does NOT list it at all (libinput rejects a keyboard+pen hybrid node).
                 => on this desktop the Anko currently does nothing.
- Sleep        : dropped its link within ~3 min of idle, reconnects on button press.

### HID report descriptor (128 B) — decoded
```
05 0c 09 01 a1 01           Consumer Control
 85 03                      REPORT ID 3
 15 00 25 01 75 01 95 0b    11 x 1-bit:
   bit0 0x0E9 Vol+   bit1 0x0EA Vol-   bit2 0x1AE AL Keyboard Layout (show soft keyboard)
   bit3 0x030 Power  bit4 0x040 Menu   bit5 0x046 Menu Escape (=Back)  bit6 0x223 AC Home
   bits7-10 repeat last usage (padding in practice)
 81 02  95 01 75 0d 81 03   + 13 bits const pad  -> 3 data bytes
c0
05 0d 09 02 a1 01           Digitizer, **Pen** application   (J09 uses 0x01 Digitizer)
 85 02                      REPORT ID 2
 09 22 a1 02                Finger
  09 42 1b Tip | 09 32 1b InRange | 6b pad
  09 51 8b  Contact Identifier
  05 01 26 ff 0f 75 10 55 0e 65 33   X 16-bit 0..4095, unit inch*10^-2, phys 0..1205
  09 31 46 8a 03                     Y 16-bit 0..4095, phys 0..906
 c0
 05 0d 09 54 8b   Contact Count
 85 08 09 55 25 05 b1 02   REPORT ID 8 (feature): Contact Count Maximum = 5
c0
```
Wire format:
- Report 3 (keys)  : `03 b0 b1 b2`  (only low 7 bits of b0 meaningful)
- Report 2 (touch) : `02 ff id xl xh yl yh cc`  — 8 bytes
- Report 8 feature : contact-count-max, host can GET it.

Same Physical-Max constants (1205 / 906) in both rings => both descriptors
descend from the same reference "fake touchscreen" template.

### Anko — observed raw reports (capture 2026-10-11 20:36, tools/hidcap.py)
Only report ID 2 (touch) was ever seen; NO key reports (ID 3) in the default mode.
Every button is implemented as a synthetic touch gesture. Reports are 9 bytes on
the wire (descriptor says 8; trailing 00 pad). Flags byte is 0x07 when down
(tip|inrange|bit2), 0x00 on release. X is always 1904 (= 0x770, screen centre).
```
"next"/swipe-up   : id=6, 10 frames @ 30 ms: y 3200,2600,2300,2000,...,500 then release at y=200   (~0.3 s)
"prev"/swipe-down : id=6, 10 frames @ 30 ms: y 1012,1100,1400,...,3200 then release at y=3500
"tap"             : id=7, one frame tip=1 at (1904,1904), release 30 ms later
```
=> for a desktop driver: direction = sign(y_last - y_first), tap = single frame,
   contact id 6 = swipe, 7 = tap. No velocity information worth using (fixed ramp).
User reports the Anko has 3 physical buttons, no touch pad.
Labelled capture 20:49 (six events, 3-4 s apart) produced, in order:
```
 1. swipe up    (02 07 06 .. y 3200->500)
 2. KEY 03 01 00  Vol+   -- sent TWICE, 0.5 s apart (held key auto-repeats)
 3. tap         (02 07 07 .. at 1904,1904)
 4. KEY 03 08 00 00  Power (0x30)
 5. swipe down  (02 07 06 .. y 1012->3200)
 6. KEY 03 02 00  Vol-   -- sent TWICE, 0.5 s apart
```
User confirmed press order was b1 short, b1 long, b2 short, b2 long, b3 short, b3 long, so:
   button 1: short = swipe up,   long = Vol+ (repeating every 0.5 s while held)
   button 2: short = tap,        long = Power (0x30)
   button 3: short = swipe down, long = Vol- (repeating every 0.5 s while held)
Key reports are 3 or 4 bytes on the wire (variable length).

---------------------------------------------------------------------------
## Why a custom driver is needed (desktop Linux)
---------------------------------------------------------------------------
- libinput/Hyprland ignore the touch nodes (J09) or the whole device (Anko).
- Only J09's media keys currently reach the compositor.
- Plan: userspace daemon reads /dev/hidraw* (or evdev), decodes reports above,
  recognises swipe direction/velocity/tap from the fake-touch stream, and emits
  whatever we want via uinput (scroll, keys, mouse, custom actions per app).
  Needs the udev rule `70-mezring.rules` (in this dir) so it runs as the user.

## Access still blocked (need one sudo)
- `sudo cp 70-mezring.rules /etc/udev/rules.d/ && sudo udevadm control --reload && sudo udevadm trigger`
  -> gives the seat user ACLs on both rings' hidraw + event nodes, persistently.
- `sudo btmon -w ring.btsnoop` for HCI-level capture (SDP of the Anko, L2CAP HID
  traffic, pairing details).
- Optional: `sudo pacman -S python-evdev python-bleak` for tooling.

## Firmware-hacking leads
- J09: Jieli chip, stock `hid_mouse` demo, RCSP channels exposed (ae30/ae40).
  Public SDK + community RE tooling. Realistic to: (a) talk RCSP to it,
  (b) attempt OTA of a custom build, (c) at worst open it and flash over UART/USB
  with jl-uboot-tool. Need to find which Jieli PID -> chipkey.
- Anko: no vendor channel visible over the air. Hacking = open the case, identify
  SoC, find UART/SWD. Lower priority; drive it from the host side instead.
