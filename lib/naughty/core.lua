----------------------------------------------------------------------------
--- Notification library
--
-- @author koniu &lt;gkusnierz@gmail.com&gt;
-- @copyright 2008 koniu
-- @module naughty
----------------------------------------------------------------------------

--luacheck: no max line length

-- Package environment
local capi = { screen = screen }
local timer = require("gears.timer")
local gdebug = require("gears.debug")
local screen = require("awful.screen")
local util = require("awful.util")
local gtable = require("gears.table")
local nnotif = require("naughty.notification")
local beautiful = require("beautiful")
local dpi = beautiful.xresources.apply_dpi

local naughty = {}

--[[--
Naughty configuration - a table containing common popup settings.

@table naughty.config
@tfield[opt=apply_dpi(4)] int padding Space between popups and edge of the
  workarea.
@tfield[opt=apply_dpi(1)] int spacing Spacing between popups.
@tfield[opt={"/usr/share/pixmaps/"}] table icon_dirs List of directories
  that will be checked by `getIcon()`.
@tfield[opt={ "png", "gif" }] table icon_formats List of formats that will be
  checked by `getIcon()`.
@tfield[opt] function notify_callback Callback used to modify or reject
notifications, e.g.
    naughty.config.notify_callback = function(args)
        args.text = 'prefix: ' .. args.text
        return args
    end
  To reject a notification return `nil` from the callback.
  If the notification is a freedesktop notification received via DBUS, you can
  access the freedesktop hints via `args.freedesktop_hints` if any where
  specified.

@tfield table presets Notification presets.  See `config.presets`.

@tfield table defaults Default values for the params to `notify()`.  These can
  optionally be overridden by specifying a preset.  See `config.defaults`.

--]]
--
naughty.config = {
    padding = dpi(4),
    spacing = dpi(1),
    icon_dirs = { "/usr/share/pixmaps/", },
    icon_formats = { "png", "gif" },
    notify_callback = nil,
}

--- Notification presets for `naughty.notify`.
-- This holds presets for different purposes.  A preset is a table of any
-- parameters for `notify()`, overriding the default values
-- (`naughty.config.defaults`).
--
-- You have to pass a reference of a preset in your `notify()` as the `preset`
-- argument.
--
-- The presets `"low"`, `"normal"` and `"critical"` are used for notifications
-- over DBUS.
--
-- @table config.presets
-- @tfield table low The preset for notifications with low urgency level.
-- @tfield[opt=5] int low.timeout
-- @tfield[opt=empty] table normal The default preset for every notification without a
--   preset that will also be used for normal urgency level.
-- @tfield table critical The preset for notifications with a critical urgency
--   level.
-- @tfield[opt="#ff0000"] string critical.bg
-- @tfield[opt="#ffffff"] string critical.fg
-- @tfield[opt=0] string critical.timeout
naughty.config.presets = {
    low = {
        timeout = 5
    },
    normal = {},
    critical = {
        bg = "#ff0000",
        fg = "#ffffff",
        timeout = 0,
    },
    ok = {
        bg = "#00bb00",
        fg = "#ffffff",
        timeout = 5,
    },
    info = {
        bg = "#0000ff",
        fg = "#ffffff",
        timeout = 5,
    },
    warn = {
        bg = "#ffaa00",
        fg = "#000000",
        timeout = 10,
    },
}

--- Defaults for `naughty.notify`.
--
-- @table config.defaults
-- @tfield[opt=5] int timeout
-- @tfield[opt=""] string text
-- @tfield[opt] int screen Defaults to `awful.screen.focused`.
-- @tfield[opt=true] boolean ontop
-- @tfield[opt=apply_dpi(5)] int margin
-- @tfield[opt=apply_dpi(1)] int border_width
-- @tfield[opt="top_right"] string position
naughty.config.defaults = {
    timeout = 5,
    text = "",
    screen = nil,
    ontop = true,
    margin = dpi(5),
    border_width = dpi(1),
    position = "top_right"
}

naughty.notificationClosedReason = {
    silent = -1,
    expired = 1,
    dismissedByUser = 2,
    dismissedByCommand = 3,
    undefined = 4
}


--- Notifications font.
-- @beautiful beautiful.notification_font
-- @tparam string|lgi.Pango.FontDescription notification_font

--- Notifications background color.
-- @beautiful beautiful.notification_bg
-- @tparam color notification_bg

--- Notifications foreground color.
-- @beautiful beautiful.notification_fg
-- @tparam color notification_fg

--- Notifications border width.
-- @beautiful beautiful.notification_border_width
-- @tparam int notification_border_width

--- Notifications border color.
-- @beautiful beautiful.notification_border_color
-- @tparam color notification_border_color

--- Notifications shape.
-- @beautiful beautiful.notification_shape
-- @tparam[opt] gears.shape notification_shape
-- @see gears.shape

--- Notifications opacity.
-- @beautiful beautiful.notification_opacity
-- @tparam[opt] int notification_opacity

--- Notifications margin.
-- @beautiful beautiful.notification_margin
-- @tparam int notification_margin

--- Notifications width.
-- @beautiful beautiful.notification_width
-- @tparam int notification_width

--- Notifications height.
-- @beautiful beautiful.notification_height
-- @tparam int notification_height

--- Notifications icon size.
-- @beautiful beautiful.notification_icon_size
-- @tparam int notification_icon_size

-- True if notifying is suspended
local suspended = false

--- Index of notifications per screen and position.
-- See config table for valid 'position' values.
-- Each element is a table consisting of:
--
-- @field box Wibox object containing the popup
-- @field height Popup height
-- @field width Popup width
-- @field die Function to be executed on timeout
-- @field id Unique notification id based on a counter
-- @table notifications
naughty.notifications = { suspended = { } }
screen.connect_for_each_screen(function(s)
    naughty.notifications[s] = {
        top_left = {},
        top_middle = {},
        top_right = {},
        bottom_left = {},
        bottom_middle = {},
        bottom_right = {},
    }
end)

capi.screen.connect_signal("removed", function(scr)
    -- Destroy all notifications on this screen
    naughty.destroy_all_notifications({scr})
    naughty.notifications[scr] = nil
end)

--- Notification state
function naughty.is_suspended()
    return suspended
end

--- Suspend notifications
function naughty.suspend()
    suspended = true
end

local conns = {}

--- Connect a global signal on the notification engine.
--
-- Functions connected to this signal source will be executed when any
-- notification object emit the signal.
--
-- It is also used for some generic notification signals such as
-- `request::display`.
--
-- @tparam string name The name of the signal
-- @tparam function func The function to attach
-- @usage naughty.connect_signal("added", function(notif)
--    -- do something
-- end)
function naughty.connect_signal(name, func)
    assert(name)
    conns[name] = conns[name] or {}
    table.insert(conns[name], func)
end

--- Emit a notification signal.
-- @tparam string name The signal name.
-- @param ... The signal callback arguments
function naughty.emit_signal(name, ...)
    assert(name)
    for _, func in pairs(conns[name] or {}) do
        func(...)
    end
end

--- Disconnect a signal from a source.
-- @tparam string name The name of the signal
-- @tparam function func The attached function
-- @treturn boolean If the disconnection was successful
function naughty.disconnect_signal(name, func)
    for k, v in ipairs(conns[name] or {}) do
        if v == func then
            table.remove(conns[name], k)
            return true
        end
    end
    return false
end

--- Resume notifications
function naughty.resume()
    suspended = false
    for _, v in pairs(naughty.notifications.suspended) do
        v.box.visible = true
        if v.timer then v.timer:start() end
    end
    naughty.notifications.suspended = { }
end

--- Toggle notification state
function naughty.toggle()
    if suspended then
        naughty.resume()
    else
        naughty.suspend()
    end
end

--- Destroy notification by notification object
--
-- @param notification Notification object to be destroyed
-- @param reason One of the reasons from notificationClosedReason
-- @param[opt=false] keep_visible If true, keep the notification visible
-- @return True if the popup was successfully destroyed, nil otherwise
function naughty.destroy(notification, reason, keep_visible)
    gdebug.deprecate("Use notification:destroy(reason, keep_visible)", {deprecated_in=5})
    return notification:destroy(reason, keep_visible)
end

--- Destroy all notifications on given screens.
--
-- @tparam table screens Table of screens on which notifications should be
-- destroyed. If nil, destroy notifications on all screens.
-- @tparam naughty.notificationClosedReason reason Reason for closing
-- notifications.
-- @treturn true|nil True if all notifications were successfully destroyed, nil
-- otherwise.
function naughty.destroy_all_notifications(screens, reason)
    if not screens then
        screens = {}
        for key, _ in pairs(naughty.notifications) do
            table.insert(screens, key)
        end
    end
    local ret = true
    for _, scr in pairs(screens) do
        for _, list in pairs(naughty.notifications[scr]) do
            while #list > 0 do
                ret = ret and list[1]:destroy(reason)
            end
        end
    end
    return ret
end

--- Get notification by ID
--
-- @param id ID of the notification
-- @return notification object if it was found, nil otherwise
function naughty.getById(id)
    gdebug.deprecate("Use naughty.get_by_id", {deprecated_in=5})
    return naughty.get_by_id(id)
end

--- Get notification by ID
--
-- @param id ID of the notification
-- @return notification object if it was found, nil otherwise
function naughty.get_by_id(id)
    -- iterate the notifications to get the notfications with the correct ID
    for s in pairs(naughty.notifications) do
        for p in pairs(naughty.notifications[s]) do
            for _, notification in pairs(naughty.notifications[s][p]) do
                if notification.id == id then
                    return notification
                 end
            end
        end
    end
end

--- Set new notification timeout.
-- @tparam notification notification Notification object, which timer is to be reset.
-- @tparam number new_timeout Time in seconds after which notification disappears.
function naughty.reset_timeout(notification, new_timeout)
    gdebug.deprecate("Use notification:reset_timeout(new_timeout)", {deprecated_in=5})
    notification:reset_timeout(new_timeout)
end

--- Replace title and text of an existing notification.
-- @tparam notification notification Notification object, which contents are to be replaced.
-- @tparam string new_title New title of notification. If not specified, old title remains unchanged.
-- @tparam string new_text New text of notification. If not specified, old text remains unchanged.
-- @return None.
function naughty.replace_text(notification, new_title, new_text)
    gdebug.deprecate(
        "Use notification.text = new_text; notification.title = new_title",
        {deprecated_in=5}
    )

    notification.title = new_title and (new_title .. "\n") or notification.title
    notification.text  = new_text or notification.text

    update_size(notification)
end

--- Emitted when a notification is created.
-- @signal added
-- @tparam naughty.notification notification The notification object

--- Emitted when a notification is destroyed.
-- @signal destroyed
-- @tparam naughty.notification notification The notification object

--- Emitted when a notification has to be displayed.
--
-- To add an handler, use:
--
--    naughty.connect_signal("request::display", function(notification, args)
--        -- do something
--    end)
--
-- @tparam table notification The `naughty.notification` object.
-- @tparam table args Any arguments passed to the `naughty.notify` function,
--  including, but not limited to all `naughty.notification` properties.
-- @signal request::display

--- Emitted when a notification need pre-display configuration.
--
-- @tparam table notification The `naughty.notification` object.
-- @tparam table args Any arguments passed to the `naughty.notify` function,
--  including, but not limited to all `naughty.notification` properties.
-- @signal request::preset

--- Create a notification.
--
-- @tab args The argument table containing any of the arguments below.
-- @string[opt=""] args.text Text of the notification.
-- @string[opt] args.title Title of the notification.
-- @int[opt=5] args.timeout Time in seconds after which popup expires.
--   Set 0 for no timeout.
-- @int[opt] args.hover_timeout Delay in seconds after which hovered popup disappears.
-- @tparam[opt=focused] integer|screen args.screen Target screen for the notification.
-- @string[opt="top_right"] args.position Corner of the workarea displaying the popups.
--   Values: `"top_right"`, `"top_left"`, `"bottom_left"`,
--   `"bottom_right"`, `"top_middle"`, `"bottom_middle"`.
-- @bool[opt=true] args.ontop Boolean forcing popups to display on top.
-- @int[opt=`beautiful.notification_height` or auto] args.height Popup height.
-- @int[opt=`beautiful.notification_width` or auto] args.width Popup width.
-- @string[opt=`beautiful.notification_font` or `beautiful.font` or `awesome.font`] args.font Notification font.
-- @string[opt] args.icon Path to icon.
-- @int[opt] args.icon_size Desired icon size in px.
-- @string[opt=`beautiful.notification_fg` or `beautiful.fg_focus` or `'#ffffff'`] args.fg Foreground color.
-- @string[opt=`beautiful.notification_fg` or `beautiful.bg_focus` or `'#535d6c'`] args.bg Background color.
-- @int[opt=`beautiful.notification_border_width` or 1] args.border_width Border width.
-- @string[opt=`beautiful.notification_border_color` or `beautiful.border_focus` or `'#535d6c'`] args.border_color Border color.
-- @tparam[opt=`beautiful.notification_shape`] gears.shape args.shape Widget shape.
-- @tparam[opt=`beautiful.notification_opacity`] gears.opacity args.opacity Widget opacity.
-- @tparam[opt=`beautiful.notification_margin`] gears.margin args.margin Widget margin.
-- @tparam[opt] func args.run Function to run on left click.  The notification
--   object will be passed to it as an argument.
--   You need to call e.g.
--   `notification.die(naughty.notificationClosedReason.dismissedByUser)` from
--   there to dismiss the notification yourself.
-- @tparam[opt] func args.destroy Function to run when notification is destroyed.
-- @tparam[opt] table args.preset Table with any of the above parameters.
--   Note: Any parameters specified directly in args will override ones defined
--   in the preset.
-- @tparam[opt] int args.replaces_id Replace the notification with the given ID.
-- @tparam[opt] func args.callback Function that will be called with all arguments.
--   The notification will only be displayed if the function returns true.
--   Note: this function is only relevant to notifications sent via dbus.
-- @tparam[opt] table args.actions Mapping that maps a string to a callback when this
--   action is selected.
-- @bool[opt=false] args.ignore_suspend If set to true this notification
--   will be shown even if notifications are suspended via `naughty.suspend`.
-- @usage naughty.notify({ title = "Achtung!", text = "You're idling", timeout = 0 })
-- @treturn ?table The notification object, or nil in case a notification was
--   not displayed.
function naughty.notify(args)
    if naughty.config.notify_callback then
        args = naughty.config.notify_callback(args)
        if not args then return end
    end

    -- Create the notification object
    local notification = nnotif._create{}

    -- Make sure all signals bubble up
    notification:_connect_everything(naughty.emit_signal)

    -- Allow extensions to create override the preset with custom data
    naughty.emit_signal("request::preset", notification, args)

    -- gather variables together
    notification.preset = gtable.join(
        naughty.config.defaults or {},
        args.preset or naughty.config.presets.normal or {},
        notification.preset or {}
    )

    -- Let all listeners handle the actual visual aspects
    if (not notification.ignore) and (not notification.preset.ignore) then
        naughty.emit_signal("request::display", notification, args)
    end

    naughty.emit_signal("added", notification, args)

    -- return the notification
    return notification
end

return naughty

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
