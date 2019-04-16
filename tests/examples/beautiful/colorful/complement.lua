--DOC_GEN_IMAGE
local api = ... --DOC_HIDE

local beautiful = {colorful = require("beautiful.colorful")} --DOC_HIDE

for _, color in ipairs {"#FF00FF", "#FFFF00", "#00FFFF" } do
    local col = beautiful.colorful(color):to_complement()
    api.add_line() --DOC_HIDE
end
