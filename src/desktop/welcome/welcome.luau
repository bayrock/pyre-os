-- The PyreOS welcome panel (ADR 0016): the doormat of the cabin. It greets
-- the user, offers the themes (pyre theme set), the keys that matter most,
-- updates and settings, and reads the user guide in place. Every color is a
-- palette role, so the panel recolors live with the theme it switches.

local THEMES_DIR = "/usr/share/pyre/themes"
local GUIDE_DIR = "/usr/share/doc/pyre/guide"

local KEYS = {
  { "Super + Space", "Open the launcher" },
  { "Super + Enter", "Open a terminal" },
  { "Super + S", "Control center" },
  { "Super + O", "See every window" },
  { "Super + Shift + /", "Show all the keys" },
}

local state = {
  view = "home",     -- "home" or "guide"
  themes = {},       -- { id, name, description, banner }
  current = nil,     -- the theme Noctalia shows, from pyre theme current
  busy = nil,        -- the theme being switched to
  atLogin = false,   -- greet at every login, not just the first
  pages = {},        -- the guide: { title, file }
  page = 1,
  pageText = nil,
}

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

-- tomlField TEXT KEY: a string value from a theme.toml.
local function tomlField(text, key)
  for line in (text or ""):gmatch("[^\n]+") do
    local k, v = line:match('^(%w+)%s*=%s*"(.*)"%s*$')
    if k == key then
      return v
    end
  end
  return nil
end

local function stateFile(name)
  local base = noctalia.getenv("XDG_STATE_HOME")
  if base == nil or base == "" then
    base = noctalia.expandPath("~/.local/state")
  end
  return base .. "/pyre/welcome/" .. name
end

local function loadThemes()
  state.themes = {}
  local ids = noctalia.listDir(THEMES_DIR) or {}
  table.sort(ids)
  for _, id in ipairs(ids) do
    local meta = noctalia.readFile(THEMES_DIR .. "/" .. id .. "/theme.toml")
    if meta then
      local banner = tomlField(meta, "banner")
      table.insert(state.themes, {
        id = id,
        name = tomlField(meta, "name") or id,
        description = tomlField(meta, "description") or "",
        banner = banner and (THEMES_DIR .. "/" .. id .. "/" .. banner) or nil,
      })
    end
  end
  -- Ember, the default, leads.
  table.sort(state.themes, function(a, b)
    if a.id == "ember" or b.id == "ember" then
      return a.id == "ember"
    end
    return a.name < b.name
  end)
end

local function loadGuide()
  state.pages = {}
  local files = noctalia.listDir(GUIDE_DIR) or {}
  table.sort(files)
  for _, file in ipairs(files) do
    if file:match("%.md$") then
      local text = noctalia.readFile(GUIDE_DIR .. "/" .. file) or ""
      local title = text:match("^#%s+([^\n]+)") or file:gsub("%.md$", "")
      table.insert(state.pages, { title = title, file = GUIDE_DIR .. "/" .. file })
    end
  end
end

local function refreshCurrent()
  noctalia.runAsync({ "pyre", "theme", "current" }, function(r)
    state.current = r.exitCode == 0 and trim(r.stdout) or nil
    render()
  end)
end

local function setTheme(theme)
  if state.busy then
    return
  end
  state.busy = theme.id
  render()
  noctalia.runAsync({ "pyre", "theme", "set", theme.id }, function(r)
    state.busy = nil
    if r.exitCode == 0 then
      state.current = theme.id
    else
      noctalia.notifyError("PyreOS", "Could not switch to " .. theme.name .. ": " .. trim(r.stderr))
    end
    render()
  end)
end

local function setAtLogin(on)
  state.atLogin = on
  render()
  noctalia.runAsync({ "pyre", "welcome", "--at-login", on and "on" or "off" })
end

local function openPage(index)
  state.page = index
  local page = state.pages[index]
  state.pageText = page and (noctalia.readFile(page.file) or "") or "The guide is not installed."
  render()
end

local function banner()
  local path
  for _, theme in ipairs(state.themes) do
    if theme.id == (state.current or "ember") then
      path = theme.banner
    end
  end
  path = path or (THEMES_DIR .. "/ember/wallpapers/ember-banner.jpg")
  return ui.image({ key = "banner", path = path, width = 760, height = 180, radius = 14, fit = "cover" })
end

local function card(key, glyph, title, children)
  local body = {
    ui.row({ gap = 8, align = "center" }, {
      ui.glyph({ name = glyph, size = 18, color = "primary" }),
      ui.label({ text = title, fontSize = 15, fontWeight = "bold" }),
    }),
  }
  for _, child in ipairs(children) do
    table.insert(body, child)
  end
  return ui.column({ key = key, flexGrow = 1, width = 245, gap = 7, padding = 12, radius = 12,
                     fill = "surface_container", border = "outline_variant", borderWidth = 1 }, body)
end

local function themeCard()
  local rows = {
    ui.label({ text = "One cabin, four hours and seasons.", fontSize = 12, color = "on_surface_variant" }),
  }
  for _, theme in ipairs(state.themes) do
    local current = theme.id == state.current
    table.insert(rows, ui.button({
      key = "theme-" .. theme.id,
      text = state.busy == theme.id and (theme.name .. "…") or theme.name,
      glyph = current and "check" or "palette",
      variant = current and "primary" or "outline",
      contentAlign = "start",
      controlSize = "sm",
      selected = current,
      tooltip = theme.description,
      onClick = function() setTheme(theme) end,
    }))
  end
  return card("themes", "flame", "Choose your light", rows)
end

local function keysCard()
  local rows = {
    ui.label({ text = "Super is the key with the logo on it.", fontSize = 12, color = "on_surface_variant" }),
  }
  for i, k in ipairs(KEYS) do
    table.insert(rows, ui.row({ key = "key-" .. i, gap = 8, align = "center" }, {
      ui.label({ text = k[1], fontSize = 12, fontWeight = "bold", color = "secondary", width = 112 }),
      ui.label({ text = k[2], fontSize = 12, flexGrow = 1 }),
    }))
  end
  return card("keys", "keyboard", "Find your way around", rows)
end

local function tidyCard()
  local function action(key, glyph, text, fn)
    return ui.button({ key = key, glyph = glyph, text = text, variant = "ghost", contentAlign = "start",
                       controlSize = "sm", onClick = fn })
  end
  return card("tidy", "home", "Keep the place in order", {
    ui.label({ text = "Everything else is a click away.", fontSize = 12, color = "on_surface_variant" }),
    action("guide", "book", "Read the guide", function()
      state.view = "guide"
      openPage(state.page)
    end),
    action("update", "refresh", "Check for updates", function()
      noctalia.runInTerminal("pyre update; echo; read -rp 'Press Enter to close. '")
    end),
    action("settings", "adjustments", "Shell settings", function()
      panel.close()
      noctalia.openSettings()
    end),
    action("doctor", "stethoscope", "Check the system", function()
      noctalia.runInTerminal("pyre doctor; echo; read -rp 'Press Enter to close. '")
    end),
  })
end

local function home()
  return ui.column({ gap = 12, padding = 16 }, {
    banner(),
    ui.column({ gap = 2, paddingH = 4 }, {
      ui.label({ text = "Welcome home.", fontSize = 30, fontWeight = "bold", color = "secondary" }),
      ui.label({ text = "Kick the snow off your boots and come on in. The fire's lit, the kettle's on, "
                        .. "and the place is yours to arrange.",
                 fontSize = 14, color = "on_surface_variant", maxWidth = 756, maxLines = 2 }),
    }),
    ui.row({ gap = 12, align = "stretch" }, { themeCard(), keysCard(), tidyCard() }),
    ui.row({ gap = 10, align = "center" }, {
      ui.toggle({ checked = state.atLogin, onChange = function(v) setAtLogin(v == "true") end }),
      ui.label({ text = "Say hello at every login", fontSize = 13, color = "on_surface_variant" }),
      ui.spacer({ flexGrow = 1 }),
      ui.button({ text = "Settle in", glyph = "flame", variant = "primary", onClick = function() panel.close() end }),
    }),
  })
end

local function guide()
  local topics = {}
  for i, page in ipairs(state.pages) do
    table.insert(topics, ui.button({
      key = "page-" .. i, text = page.title, contentAlign = "start", controlSize = "sm",
      variant = i == state.page and "secondary" or "ghost", selected = i == state.page,
      onClick = function() openPage(i) end,
    }))
  end
  return ui.column({ gap = 12, padding = 16 }, {
    ui.row({ gap = 10, align = "center" }, {
      ui.button({ glyph = "arrow-left", text = "Welcome", variant = "ghost", controlSize = "sm",
                  onClick = function() state.view = "home"; render() end }),
      ui.label({ text = "The PyreOS guide", fontSize = 18, fontWeight = "bold", color = "secondary", flexGrow = 1 }),
      ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = function() panel.close() end }),
    }),
    -- Explicit heights: a scroll sizes to what it is given, not to its parent.
    ui.row({ gap = 12, height = 528, align = "stretch" }, {
      ui.column({ width = 200, height = 528, gap = 4 }, topics),
      ui.scroll({ key = "page", flexGrow = 1, width = 548, height = 528, padding = 14, radius = 12,
                  fill = "surface_container" }, {
        ui.markdown({ key = "page-" .. state.page, text = state.pageText or "", width = 516 }),
      }),
    }),
  })
end

function render()
  panel.render(state.view == "guide" and guide() or home())
end

function onOpen(context)
  loadThemes()
  loadGuide()
  state.atLogin = noctalia.fileExists(stateFile("at-login"))
  state.view = context == "guide" and "guide" or "home"
  if state.view == "guide" then
    openPage(state.page)
  else
    render()
  end
  refreshCurrent()
end
