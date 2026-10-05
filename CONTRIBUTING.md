# Contributing

Improvements to compatibility, native macOS validation, accessibility, or image attribution are welcome.

For a wallpaper issue, include the macOS version, display type, edition (solar or clock), and selected mode (Dynamic, Light, or Dark). Describe what you expected and what appeared. Do not attach private desktop screenshots unless you have checked their contents.

For changes to the generator, preserve the photograph's geometry and run `./scripts/build.sh`. It renders both editions and validates every HDR/SDR frame. The masks are specific to this image. Keep binaries, `.build/`, and `dist/` out of Git; release images belong in GitHub Releases.

The interactive preview is a standalone `docs/index.html` with no dependencies or analytics. Keep keyboard controls, reduced-motion support, and the SDR-preview explanation intact.
