local lgi = require("lgi")
local Pango = lgi.Pango

-- Default theme for the documentation examples
local module = {
    fg_normal    = "#000000"  ,
    bg_normal    = "#6181FF7D",
    border_color = "#6181FF"  ,
    border_width = 1.5        ,
}

local f = Pango.FontDescription.from_string("sans 8")

function module.get_font()
    return f
end

return module
