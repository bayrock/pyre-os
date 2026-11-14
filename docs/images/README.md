# Images for the README

CC BY-SA 4.0, like all PyreOS artwork (`LICENSE-ARTWORK`).

- `wordmark-dark.png` and `wordmark-light.png`: the landing page's wordmark, "Pyr", the flame mark as the "e", "OS", in its Fraunces heading style (`landing/site/site.css`). They have cream text for GitHub's dark theme and Ember's dark brown for the light one, on a transparent background, rendered at 2x by headless Chromium.
- `preview.jpg`: the boot menu, unlock, boot splash, login screen, welcome panel and guide, as captured by `tools/test-visual` on 2026-11-14 (P5), laid out with the wordmark and the landing page's line, rendered by headless Chromium at 3840×2280 and scaled to 2560 wide.

Re-make them when the look they show changes.
- `avatar.svg`, `avatar-1024.png`, `avatar-512.png`: the PyreOS avatar, the flame mark on Ember's night sky with a warm glow, for profile pictures and project thumbnails. The mark keeps clear of the edges, so a circular crop keeps it whole. `tools/render-avatar` makes all three. For a small transparent icon, use the mark itself, `landing/site/pyre-e.svg`.
