local parent    = ... --DOC_HIDE --DOC_NO_USAGE
local naughty = { --DOC_HIDE
    widget       = { actionlist = require("naughty.widget.actionlist")}, --DOC_HIDE
    notification = require("naughty.notification") --DOC_HIDE
} --DOC_HIDE
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
        widget = naughty.widget.actionlist,
    }
,beautiful.bg_normal)) --DOC_HIDE
