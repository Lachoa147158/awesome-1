local parent    = ... --DOC_HIDE
local naughty = { --DOC_HIDE
    widget = { icon = require("naughty.widget.icon")}, --DOC_HIDE
    notification = require("naughty.notification")} --DOC_HIDE
local wibox = require("wibox") --DOC_HIDE
local beautiful = require("beautiful") --DOC_HIDE

    local notif = naughty.notification {
        title = "A notification",
        text  = "This notification has actions!",
        icon  = beautiful.awesome_icon,
    }

parent:add( --DOC_HIDE
    wibox.widget {
        resize_strategy = strategy,
        notification    = notif,
        widget          = naughty.widget.icon,
    }
) --DOC_HIDE
