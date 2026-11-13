# Landing page

The PyreOS landing page at <https://bayrock.github.io/pyre-os/>. It is one screen: the wordmark, one line, a link to the source, and a cabin in the woods at night. Later it becomes the entry point for installing and contributing.

## The rules

- **Few words.** No feature lists, cards, or sections. The README and docs do that job.
- **Nothing links to a page that doesn't exist yet.** The status line, "Install images arrive with the first testing release", becomes an "Install" pill beside "Contribute on GitHub" once a testing release is published.
- **No script, and nothing from another host.** The font is self-hosted, and the CSP in each page's `<meta>` allows only the site itself. GitHub Pages can't set response headers, so the CSP can't use `frame-ancestors`.
- **Relative URLs** in `index.html`, because Pages serves the site under `/pyre-os/`. `404.html` is served at any depth, so its URLs are absolute (`/pyre-os/…`). Update them if the site moves to its own domain.

`tools/check` enforces the last two rules.

## Files

| Path | What it is |
|---|---|
| `site/` | The published site. There is no build step |
| `site/site.css` | All of the CSS, with the palette as custom properties |
| `site/pyre-e.svg` | The PyreOS mark, the flame "e". It is the favicon and the "e" in the wordmark |
| `site/fonts/` | Fraunces, with its OFL |
| `site/apple-touch-icon.png`, `site/og.jpg` | Renders (see below) |
| `design/` | The original component mockup and the unused geometric variant of the mark. Not published |

## Design

- **Palette.** The fire ramp is the mark's own gradient: coral `#E96D51`, orange `#D9803C`, and gold `#E9B851`. Brick `#A63220` and cream `#FDFCEB` (text) come from the mockup. Every surface is branded: the sky, the treelines, the cabin, and the footer are the mark's orange at oklch hue 58, with low chroma and low lightness, not neutral greys. Muted text is 6.4:1 or better on every surface, and the pill's dark text is 6.5:1 or better on its gradient.
- **Font.** Fraunces (Undercase Type, SIL OFL 1.1), with the `SOFT` axis at 100. It is a warm, soft old-style serif in the Cooper and Windsor lineage of lodge and cabin signage, and its round terminals match the flame "e". The file is Google Fonts' latin subset of `family=Fraunces:opsz,wght,SOFT@9..144,400..700,100`, fetched on 2026-11-13 (62 KB). The OFL names no Reserved Font Name, so the subset may keep the name.
- **Motion.** The chimney's embers rise once on load and then rest (WCAG 2.2.2). They don't move at all under reduced motion.

## Preview

```sh
mkdir -p /tmp/pyre-site && ln -sfn "$PWD/landing/site" /tmp/pyre-site/pyre-os
python3 -I -m http.server 8080 --bind 127.0.0.1 --directory /tmp/pyre-site
# open http://127.0.0.1:8080/pyre-os/
```

Check 360, 768, and 1280 px wide for horizontal scroll and for console or CSP errors.

**Renders.**
- `apple-touch-icon.png` is the mark at 128 px, centred on 180×180 of the sky colour `#130e0a`:
  ```sh
  rsvg-convert -h 128 pyre-e.svg | magick -size 180x180 xc:#130e0a - -gravity center -composite -strip apple-touch-icon.png
  ```
- `og.jpg` is a 1200×630 headless-Chromium screenshot of the page, converted with `magick -strip -quality 86`.

## Deploying

`.github/workflows/pages.yml` publishes `site/` on every push to `main` that touches it. Repository settings must have **Pages → Source: GitHub Actions**, set once by a repository admin.

The mark and the scene are PyreOS artwork, under CC BY-SA 4.0 ([`LICENSE-ARTWORK`](../LICENSE-ARTWORK)). Fraunces keeps its own license ([`site/fonts/OFL.txt`](site/fonts/OFL.txt)).
