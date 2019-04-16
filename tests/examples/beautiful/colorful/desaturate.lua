--DOC_GEN_IMAGE
local api = ... --DOC_HIDE

local beautiful = {colorful = require("beautiful.colorful")} --DOC_HIDE

local col = beautiful.colorful("#FF00FF")
--DOC_NEWLINE
for i=1, 5 do
    col = col:to_desaturated(0.2)
end
