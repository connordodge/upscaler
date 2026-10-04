# Upscaler

A small Mac app that turns an image into exact **3840 × 2160** art for the Samsung Frame TV.

- AI upscaling with [Real-ESRGAN](https://github.com/xinntao/Real-ESRGAN), running on the Mac's GPU
- If the image isn't 16:9, it's scaled to fill 3840 × 2160 and you drag a box to choose what gets cropped
- Keeps the original color profile; JPEGs are saved at maximum quality

## Download

**[Download Upscaler.dmg](https://github.com/connordodge/upscaler/releases/latest/download/Upscaler.dmg)** (macOS 12 or later)

Open the DMG and drag **Upscaler** into **Applications**. The app is signed and notarized by Apple, so it opens normally.

## Use

1. Drop an image onto the window, or click **Choose Image…** (PNG, JPEG or WebP).
2. If the image isn't 16:9, drag the white box to pick which part is kept.
3. Pick a mode:
   - **Photo / Painting**: AI upscale, sharpest result
   - **Illustration**: AI upscale tuned for flat art
   - **Plain Resize**: no AI; looks exactly like the original, slightly softer
4. Click **Make Frame TV Art**. The result is saved next to the original as `<name>_4k.jpg` (or `.png`).

## Development

```sh
flutter run -d macos
flutter test
flutter test integration_test -d macos --dart-define=SAMPLE=/path/to/image.jpg  # runs the real upscaler
./release_macos.sh   # build, sign, notarize and package dist/Upscaler.dmg
```

Real-ESRGAN's binary and models live in `macos/Runner/realesrgan/` and are copied into the app bundle. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for their licenses.
