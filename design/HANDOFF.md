# Darkroom UI handoff

Redesign the app UI to the "Darkroom" direction: a dark, photo-editor style window with a toolbar, an
edge-to-edge image stage, and a status bar. Behavior and the upscale pipeline stay the same, plus a new
**Crop / Preview** view switch and a post-upscale result preview.

## References

- Sketch file: `design/Upscaler.sketch` (page "Darkroom", frames C1–C5). Local only (gitignored): it
  embeds a personal sample image. Absolute path on the build machine:
  `/Users/connordodge/code/apps/upscaler/design/Upscaler.sketch`.
- PNG exports of each frame: `/Users/connordodge/code/apps/upscaler/design/screens/C1-crop.png` … `C5-done.png`
  (local only, same reason).
- Exact CSS for each screen: `design/html/Darkroom*.dc.html` (committed). Treat inline styles as the
  source of truth for spacing, radii, colors and font sizes. `/_blob/...` URLs are the sample painting
  and the app icon.

## Tokens

| Token | Hex | Use |
|---|---|---|
| Surface/Background | `#0B0B0D` | window, crop stage |
| Surface/Stage | `#121214` | preview / done stage |
| Surface/Bar | `#18181B` | toolbar, status bar, cards |
| Surface/Control | `#222226` | segmented control track, secondary buttons |
| Surface/Selected | `#3A3A42` | selected segment |
| Surface/Bezel | `#26262B` | TV bezel |
| Line/Divider | `#2A2A2F` | toolbar bottom / status bar top border, card border, disabled button fill |
| Line/Control | `#34343A` | control borders |
| Text/Primary | `#ECECEF` | |
| Text/Secondary | `#B4B4BC` | unselected segments |
| Text/Muted | `#9A9AA3` | status bar, captions, body copy |
| Text/Disabled | `#6B6B74` | disabled button label/icon, empty-state glyph |
| Accent/Primary | `#6E3FF3` | primary buttons, progress line (white text on it) |
| Status/Success | `#4ADE80` | done check icon |

Typography (bundled, files in `assets/fonts/`, OFL licenses alongside):
- **Hanken Grotesk** 400 / 500 / 600: all UI text.
- **JetBrains Mono** 400 / 500: status bar, captions, numbers (dimensions, percent).

Icons: 1.8px stroke line icons at 15–16px (folder, crop, TV, sparkle). Material Symbols equivalents are
fine (`folder_open`, `crop`, `tv`, `auto_awesome`) if drawn at matching size and weight.

## Layout (default window 960 × 820, min 640 × 720)

- **Toolbar**: 60px tall, `Surface/Bar`, 1px `Line/Divider` bottom border, padding 8×16, three groups
  spaced between, wraps on narrow widths.
  - Left: app icon 28px, then **Open…** secondary button (44px tall, radius 8, folder icon + label).
  - Center: **method switch**: segmented control (track `Surface/Control`, 1px `Line/Control`, radius 10,
    3px padding, 2px gap; segments 38px tall, radius 7, 0×14 padding, 13px). Segments: `AI · Photo`,
    `AI · Illustration`, `Plain` → `UpscaleMode.painting / illustration / plain`.
  - Right: **view switch** (same control, segments with 15px icon + label: `Crop`, `Preview`), then the
    **Make 4K Art** primary button (accent, white 14px/600, sparkle icon, 44px, radius 8).
- **Stage**: fills the space between bars, 32px padding, content centered.
- **Status bar**: 36px, `Surface/Bar`, 1px `Line/Divider` top border, padding 0×16, JetBrains Mono 12px
  `Text/Muted`, left text and right hint spaced between.

## Screens / states

**C3 · Empty** (no image)
- Stage: dashed drop zone (1.5px `#3A3A42`, dash ~6/5, radius 16), 16:9, max 720 wide. Centered column,
  gap 14: image glyph 48px `Text/Disabled`; "Drop an image to start" 22px/600; "PNG, JPEG or WebP. It
  becomes exact 3840 × 2160 art for your Samsung Frame TV." 14px `Text/Muted`, max ~380 wide, centered;
  **Choose Image…** primary button.
- View switch and Make 4K Art disabled (view at 45% opacity; Make uses `Line/Divider` fill and
  `Text/Disabled` label).
- Status bar: `No image` · `Output 3840×2160`.
- Dropping a file anywhere on the window loads it (existing desktop_drop behavior).

**C1 · Crop** (image loaded, view = Crop; default after loading)
- Stage `Surface/Background`. Image shown at its own aspect ratio, as large as fits.
- Crop overlay: area outside the 16:9 window shaded `rgba(11,11,13,0.8)`; window outline 1px white 85%;
  3×3 guide lines 1px white 22% inside the window; 22px white corner ticks, 3px thick, at the window
  corners. Dragging along the overflowing axis moves the window (existing `CropPicker` logic and
  `cropOffset` math stay as they are).
- Status bar left: `{file}  {w}×{h}  →  3840×2160  ·  crop {axis} {px}` where axis/px come from
  `cropOffset(coverSize(size), position)` (`x` for wide images, `y` for tall). Omit the `· crop …` part
  when the image is already exactly 16:9. Right: `Drag frame to reposition` (or `No crop needed` when
  exactly 16:9).

**C2 · Preview** (image loaded, view = Preview)
- Stage `Surface/Stage`. The cropped 16:9 result inside a TV bezel: 10px `Surface/Bezel` padding,
  radius 3, shadow `0 30 60 rgba(0,0,0,0.55)`, max 820 wide. Caption below (gap 18), JetBrains Mono 12px
  `Text/Muted`: `How it will look on the Frame · 3840 × 2160`.
- Before an upscale, render the preview from the source image with the current crop applied (no
  re-encoding needed: position the image like the HTML does).
- Status bar right: `Switch to Crop to adjust`.

**C4 · Working** (upscale running)
- Open, method switch and drag/drop disabled (45% opacity). View switch stays usable.
- Make button becomes a busy state: `Line/Divider` fill, label `Upscaling…  62%` (percent in
  JetBrains Mono 500) or `Upscaling…` when progress is indeterminate; min width 150.
- 3px accent progress line along the toolbar's bottom edge, width = progress (indeterminate: animated or
  full-width pulsing; keep it simple).
- In Crop view: dim the image (`rgba(11,11,13,0.55)`), hide guides/corner ticks, show a centered pill
  (`rgba(24,24,27,0.92)`, 1px `Line/Control`, fully rounded, 12×18 padding, sparkle + `AI upscaling on
  your Mac's GPU` 14px/500; for Plain mode: `Resizing and cropping`).
- Status bar right: `Step 1 of 2 · AI upscale, then resize and crop` during the AI phase,
  `Step 2 of 2 · Resize and crop` once progress becomes indeterminate after it. Plain mode:
  `Resizing and cropping`.

**C5 · Done** (upscale finished)
- Switch to Preview automatically and show the **actual output file** in the bezel (max 780 wide).
- Success card under it (gap 20, same width): `Surface/Bar`, 1px `Line/Divider`, radius 12, padding
  12/12/12/16. Left: 22px success check, title `Saved {output file name}` 15px/600, detail
  `3840 × 2160 · next to the original` JetBrains Mono 12px muted. Right: **Show in Finder** and **Open**
  secondary buttons (40px, radius 8, 13px/500) — same actions as today (`open -R`, `open`).
- Status bar right: `Done`. Changing the crop, the mode, or loading another image clears the done state.

**Errors**: show a card in the same position as the success card, with a red (`#F87171`) alert icon,
title `Upscale failed` and the error message (selectable) in muted text. Status bar right: `Failed`.

## Other changes in this PR

- Default window 960 × 820 (`MainMenu.xib` contentRect), min stays 640 × 720.
- Dark theme only (`ThemeData` with the tokens above; no light theme).
- Bundle the fonts via `pubspec.yaml`.
- Put license notices inside the app: add the Hanken Grotesk and JetBrains Mono OFL texts to
  `THIRD_PARTY_NOTICES.md`, and copy that file into the app bundle (e.g. alongside
  `macos/Runner/realesrgan/` so it ships in `Contents/Resources/realesrgan/`).
- Bump version to `0.2.0+2`.
