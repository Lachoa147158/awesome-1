--DOC_HIDE_ALL
local wibox     = require("wibox")
local gears     = {shape = require("gears.shape")}
local beautiful = require("beautiful")

return {
    text   = "Before",
    align  = "center",
    valign = "center",
    widget = wibox.widget.textbox,
},
{
    {
        {
            text   = "After",
            align  = "center",
            valign = "center",
            widget = wibox.widget.textbox,
        },
        valign = "bottom",
        halign = "right",
        widget = wibox.container.align
    },
    margins = 5,
    layout = wibox.container.margin
}
