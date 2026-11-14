-- "/remind 10m tea": the text behind the prefix is a reminder (ADR 0020).
local remind = require("./remind.luau")

function onQuery(text)
  remind.query(text, false)
end

function onActivate(id)
  remind.activate(id, false)
end
