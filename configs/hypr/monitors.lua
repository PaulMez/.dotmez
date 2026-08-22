-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- List current monitors and supported resolutions with: hyprctl monitors all

-- GDK_SCALE is global and integer-only (GTK3 fallback; GTK4 ignores it on
-- Wayland). With a 302 DPI laptop and an 81 DPI external there is no correct
-- value, so leave it at 1 and let each monitor's own scale do the work.
hl.env("GDK_SCALE", "1")

-- Qt apps size text off this instead of the GTK text-scaling-factor gsetting.
-- 96 is the default; 105 keeps Qt text in step with
--   gsettings set org.gnome.desktop.interface text-scaling-factor 1.1
hl.env("QT_FONT_DPI", "105")

-- Laptop panel: 3456x2160 @ ~302 DPI.
-- Hyprland only accepts scales that divide into whole logical pixels, so these
-- are the usable steps for this panel (bigger scale = bigger UI):
--
--   scale | logical    | effective DPI
--   ------+------------+--------------
--   1.5   | 2304x1440  | 202   small, lots of room
--   1.8   | 1920x1200  | 168
--   2.0   | 1728x1080  | 151
--   2.25  | 1536x960   | 135
--   2.4   | 1440x900   | 126   <- current
--   2.7   | 1280x800   | 112
--   3.0   | 1152x720   | 101
--
-- 1.25 and 1.7 are NOT valid here; Hyprland rounds them up to the next clean
-- value. Try one live first: omarchy hyprland monitor scaling 2.4
hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2.4 })

-- Acer G277HL: 1920x1080 @ ~81 DPI, already low-density -- scale 1 is correct.
hl.monitor({ output = "DP-3", mode = "preferred", position = "auto-right", scale = 1 })

-- Fallback for any other display plugged in later.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

-- Note: with the per-output rules above, SUPER + / (monitor scaling up/down)
-- still applies live but no longer persists itself back to this file. Edit the
-- scale values here to make a change stick.

-- Portrait/rotated secondary monitor (transform: 1 = 90 deg, 3 = 270 deg).
-- hl.monitor({ output = "DP-2", mode = "preferred", position = "auto", scale = 1, transform = 1 })
