-- "Remind me" in the launcher (ADR 0020), shared by the plugin's two
-- providers. It reads no time and keeps no reminder itself: "pyre remind"
-- does both, so the launcher and the terminal agree. A row for the text
-- being typed is always there, and Enter sets what the text says even when
-- it comes before the row has caught up.

local M = {}

local TOP = 100000 -- above every application the search finds
local EXAMPLES = "10m tea  ·  5pm call mum  ·  tomorrow 9am standup  ·  call mum in 2 hours"

local ask = ""       -- the reminder text of the latest search
local seen = nil     -- what pyre remind --parse made of it: { ask, when, message }
local shown = false  -- this provider has rows in the launcher

local function trim(s)
  return ((s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- fields LINE: the tab-separated fields of a line.
local function fields(line)
  local out = {}
  for field in (line .. "\t"):gmatch("([^\t]*)\t") do
    table.insert(out, field)
  end
  return out
end

-- reminder TEXT, PLAIN: the reminder in a search, or nil when the search is
-- not for this provider. The provider without a prefix only takes
-- "remind …"; behind the prefix the word is optional.
local function reminder(text, plain)
  local words = trim(text)
  local lower = words:lower()
  if lower == "remind" or lower == "/remind" then
    return ""
  end
  local lead = lower:match("^/?remind%s+")
  if lead then
    return trim(words:sub(#lead + 1))
  end
  if plain then
    return nil
  end
  return words
end

-- pending TEXT: the examples, then the reminders waiting, soonest first.
-- Enter on one cancels it.
local function pending(text)
  shown = true
  local rows = {
    { id = "examples", title = "Remind me…", subtitle = EXAMPLES, glyph = "alarm", score = TOP },
  }
  launcher.setResults(text, rows)
  noctalia.runAsync({ "pyre", "remind", "list" }, function(r)
    local count = 0
    for line in (r.stdout or ""):gmatch("[^\n]+") do
      local f = fields(line)
      if #f >= 3 and f[1]:match("^%d+$") then
        count = count + 1
        table.insert(rows, {
          id = "cancel " .. f[1] .. " " .. f[3],
          title = f[3],
          subtitle = f[2] .. "  ·  Enter cancels it",
          glyph = "bell",
          score = TOP - count,
        })
      end
    end
    if count > 0 then
      launcher.setResults(text, rows)
    end
  end)
end

function M.query(text, plain)
  local wanted = reminder(text, plain)
  if wanted == nil then
    -- Someone else's search: clear the rows of an earlier one, once.
    if shown then
      shown = false
      launcher.setResults(text, {})
    end
    return
  end
  ask = wanted
  shown = true
  if ask == "" or ask:lower() == "me" then
    ask = ""
    pending(text)
    return
  end
  local current = ask
  launcher.setResults(text, {
    { id = "set", title = "Remind me…", subtitle = current, glyph = "alarm", score = TOP },
  })
  noctalia.runAsync({ "pyre", "remind", "--parse", current }, function(r)
    if current ~= ask then
      return
    end
    local f = fields(trim(r.stdout))
    if r.exitCode == 0 and #f >= 3 then
      seen = { ask = current, when = f[2], message = f[3] }
      launcher.setResults(text, { {
        id = "set",
        title = "Remind me " .. f[2],
        subtitle = f[3] ~= "" and f[3] or "No message",
        glyph = "alarm",
        score = TOP,
      } })
    else
      launcher.setResults(text, {
        { id = "examples", title = "When? Start or end with a time", subtitle = EXAMPLES, glyph = "alarm", score = TOP },
      })
    end
  end)
end

function M.activate(id, plain)
  local number, message = id:match("^cancel (%d+) ?(.*)$")
  if number then
    noctalia.runAsync({ "pyre", "remind", "cancel", number }, function(r)
      if r.exitCode == 0 then
        noctalia.notify("Reminder cancelled", message)
      else
        noctalia.notifyError("Remind me", trim(r.stderr))
      end
    end)
  elseif id == "set" and ask ~= "" then
    local current = ask
    noctalia.runAsync({ "pyre", "remind", current }, function(r)
      if r.exitCode ~= 0 then
        noctalia.notifyError("Remind me", (trim(r.stderr):gsub("^pyre: remind: ", "")))
      elseif seen and seen.ask == current then
        noctalia.notify("Reminder set", seen.when .. (seen.message ~= "" and (": " .. seen.message) or ""))
      else
        noctalia.notify("Reminder set", current)
      end
    end)
  else
    -- The examples are not a reminder: stay open, with the text as it is.
    launcher.setQuery((plain and "remind " or "") .. ask)
  end
end

return M
