local parent  = ... --DOC_HIDE --DOC_NO_USAGE
local naughty = { --DOC_HIDE
    widget       = { actionlist = require("naughty.widget.actionlist")}, --DOC_HIDE
    notification = require("naughty.notification") --DOC_HIDE
} --DOC_HIDE
local gears = {shape = require("gears.shape")} --DOC_HIDE
local wibox = require("wibox") --DOC_HIDE
local beautiful = require("beautiful") --DOC_HIDE

    local notif = naughty.notification {
        title = "A notification",
        text = "This notification has actions!",
        actions = {
            ["Accept"] = function() end,
            ["Refuse"] = function() end,
            ["Ignore"] = function() end,
        }
    }


parent:add( wibox.container.background(--DOC_HIDE
    wibox.widget {
        notification = notif,
        base_layout = wibox.widget {
            spacing        = 3,
            spacing_widget = wibox.widget{
                orientation = "horizontal",
                widget      = wibox.widget.separator,
            },
            layout         = wibox.layout.fixed.vertical
        },
        widget_template = {
            {
                {
                    {
                        id     = "text_role",
                        widget = wibox.widget.textbox
                    },
                    widget = wibox.container.place
                },
                shape              = gears.shape.rounded_rect,
                shape_border_width = 2,
                shape_border_color = beautiful.bg_normal,
                forced_height      = 30,
                widget             = wibox.container.background,
            },
            margins = 4,
            widget  = wibox.container.margin,
        },
        forced_width = 100, --DOC_HIDE
        widget = naughty.widget.actionlist,
    }
,beautiful.bg_normal)) --DOC_HIDE
