# Verification

## Image and metadata checks

Both released files are checked with Apple's Image I/O. The verifier in `src/verify.swift` checks:

- 16 frames for the solar edition; 24 frames for the clock edition.
- Original 4096 × 2304 dimensions in every HDR and SDR frame.
- Exactly one native dynamic metadata block and a complete set of valid frame indices.
- Correct static Light and Dark fallback indices.
- All 24 clock anchors, including midnight; or ordered solar coordinates within valid altitude/azimuth ranges.
- An ISO HDR gain map for every frame.
- Every frame decoded in HDR and SDR modes. HDR headroom is approximately 2.79–4.0× reference white; SDR headroom is 1.

The SHA-256 checksums in the release identify the exact downloadable assets. Rebuilding on a different macOS version may produce different compressed bytes.

## Native desktop check — October 3, 2026

The solar edition was installed through System Settings on the development Mac. macOS recognized it as **Dynamic** and displayed “This wallpaper changes throughout the day.”

- **Light (Still):** original daylight appearance.
- **Dark (Still):** blue night scene with luminous exhaust.
- **Dynamic:** warm afternoon appearance at the time of the check.
- **Show on all Spaces:** enabled and confirmed in the settings UI.

The solar metadata was compared with Apple's own **The Beach** wallpaper: 8 native images and sunrise/sunset anchors. This project uses the same solar structure with 16 stages. The installed Sonoma wallpaper's static Light/Dark metadata was also inspected. No Apple wallpaper files are distributed here.

## Scope and limits

The complete 24-hour cycle was not watched in real time, the system clock was not changed, and physical display luminance was not measured. Native recognition and the frame/metadata checks are separate from those unperformed checks.

HDR playback depends on the display and the app or desktop renderer. Older macOS versions and non-Mac desktops are not verified. The source is an SDR JPEG; the additional brightness is an authored enhancement, not recovered clipped image detail.

## Public package check — October 5, 2026

The documented `./scripts/build.sh` command rebuilt both editions from the included original photo in a fresh build directory. Both rebuilt files passed all frame, metadata, HDR, and SDR checks. The standalone verifier also rejected the ordinary source JPEG as expected. Shell syntax, the preview's JavaScript syntax, release ZIP integrity, and the absence of private workstation paths in published content were checked.
