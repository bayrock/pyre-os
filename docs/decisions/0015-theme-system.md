# ADR 0015: Themes are Noctalia palettes

- Status: Accepted
- Date: 2026-11-13

## Context

P5 builds the theme system. `ARCHITECTURE.md` planned for PyreOS to own it: a `palette.toml` per theme, matugen templates for each app, and a `pyre theme set` that renders them and signals every app.

Noctalia 5.5, the shell since ADR 0005, already does that job:

- **Palettes.** It reads palettes from four sources: `builtin`, `wallpaper` (Material You), `community`, and `custom`. A custom palette is a JSON file in `~/.config/noctalia/palettes/` with 16 Material roles and a terminal block. Noctalia derives the remaining roles, such as the containers.
- **Templates.** It renders the palette into other apps through matugen-style templates (`{{colors.primary.default.hex}}`). The built-in set covers niri, foot, GTK 3 and 4, Qt, btop and more. Each template runs a hook that adds an include to the app's config only when one is missing.
- **Live updates.** Every palette change re-renders the enabled templates. `noctalia msg color-scheme-set <source> <name>` switches the palette at runtime, and its settings window does the same.
- **Greeter.** It syncs its appearance to `noctalia-greeter`.

ADR 0005 already requires that "the theme system must drive Noctalia's palette, not fight it". A second renderer would duplicate the engine, and it would disagree with Noctalia's own settings window.

## Decision

- **A PyreOS theme is a Noctalia palette.**
  - Each theme is a directory in `themes/`, installed by `pyre-themes` to `/usr/share/pyre/themes/<id>/`. It holds `theme.toml` (`name`, `description`, `mode`) and `palette.json` (Noctalia palette format 2).
  - Directories hold data only, never code.
  - `tools/check-themes` gates every theme in `tools/check`: the schema, plus WCAG contrast for the text pairs and the ANSI colors.
- **Palettes are linked, not copied.** Noctalia reads custom palettes only from the user's config.
  - The user reconcile unit `002-theme-palettes` links each palette to `~/.config/noctalia/palettes/<name>.json`, so package updates reach users through the link.
  - A file of the user's own with that name is never replaced.
- **Noctalia renders the apps.** PyreOS's Noctalia defaults select `source = "custom"` and `custom_palette = "Ember"`, and enable the built-in templates for the default apps: niri, foot, GTK 3, GTK 4 and btop. Qt waits until a default app uses Qt.
- **The user stubs already include the generated files,** so Noctalia's hooks never edit a user's config. "PyreOS never rewrites your files" still holds.
  - niri uses `include optional=true "noctalia.kdl"` (niri 26.04), which reloads by itself once the file appears.
  - foot cannot include a missing file, so skel ships a first copy of its theme, rendered from Noctalia's own template.
- **`pyre theme`** lists the installed themes, shows the current one, and sets one through `color-scheme-set custom <name>`. A theme's wallpaper comes with it through `wallpaper-set`, and `--keep-wallpaper` opts out. The rest is Noctalia's job. Noctalia's settings window stays free to choose any other palette.
- **Open windows recolor live.** Neither foot nor GTK rereads its theme file, so PyreOS adds one Noctalia user template, `pyre-live`. It runs after the built-in templates (`index = 100`) on every palette change, whichever way the change came, and renders the terminal colors into `~/.local/state/pyre/theme/live-colors`. Its hook, `pyre theme refresh`, then:
  - writes them as OSC color sequences to each open foot terminal
  - flips GTK's color-scheme preference and restores it, which makes GTK reload its styles and the CSS Noctalia just wrote
- **Ember is the default.** It comes from the landing page (`landing/site/site.css`):
  - the surfaces are the mark's orange at low chroma and lightness (OKLCH hue 58)
  - `primary`, `secondary` and `tertiary` are the fire ramp: orange, gold and coral
  - text is the page's cream
  - it is dark only, like the page
  - `tools/ember-palette` derives `palette.json` from those OKLCH values, and `tools/check` keeps the two in sync
  - its wallpaper is the landing page's cabin at night, generated from the site's own woods SVG and color tokens by `tools/render-wallpaper`. It is CC BY-SA 4.0 like all PyreOS artwork, and `tools/check` keeps its SVG in sync with the site
- **matugen is not used.** Noctalia's engine replaces it.
- **Boot surfaces wear Ember, whatever the user's theme.** The boot menu, the splash and the ISO belong to the machine, which can have several users with different themes, so they carry the distribution's identity, not one user's choice.
  - **Limine:** `pyre-base` keeps a marked block at the top of `limine.conf` (Limine reads global options anywhere in the file, and `limine-entry-tool` keeps foreign lines). The block sets the PyreOS branding, Ember's colors, and a 1920×1080 copy of the wallpaper on the ESP, `/pyre/wallpaper.jpg`.
  - The block is applied by a pacman hook on every `pyre-base` change, and by `pyre-install` right after `limine-update`.
  - A line `# pyre-boot-branding: off` opts out. An enrolled config (Secure Boot) is re-enrolled only when the admin turned enrollment on.
  - Plymouth and the ISO's menus follow the same rule.

## Consequences

- **Less to own.** The theme system is a palette file, a link, and a config default. Live switching, template coverage, and the settings window all come from upstream.
- **Contributions go upstream.** Coverage grows when Noctalia adds templates. PyreOS sends new templates upstream instead of keeping its own.
- **Narrow format coupling.** A theme depends on Noctalia's palette format. The file carries `version = 2`, Noctalia rejects formats newer than it supports, and `tools/check-themes` pins the format.
- **Users who change palettes in Noctalia** leave the PyreOS theme. `pyre theme current` then says so, and `pyre theme set` brings a PyreOS theme back.
- **Existing users** get the palette link from reconcile. Their older stubs lack the includes, so Noctalia's hooks add them on first render, as upstream intends.
