-- "remind me to call mum at 5pm", typed like any search (ADR 0020): this
-- provider has no prefix, and answers only a search that starts with "remind".
local remind = require("./remind.luau")

function onQuery(text)
  remind.query(text, true)
end

function onActivate(id)
  remind.activate(id, true)
end
