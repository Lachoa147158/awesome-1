----------------------------------------------------------------------------
--- A notification content message.
--
-- This widget is a specialized `wibox.widget.textbox` with the following extra
-- features:
--
-- * Honor the `beautiful` notification variables.
-- * React to the `naughty.notification` object message changes.
--
--@DOC_wibox_nwidget_message_simple_EXAMPLE@
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2017 Emmanuel Lepage Vallee
-- @classmod naughty.widget.message
----------------------------------------------------------------------------
local textbox = require("wibox.widget.textbox")
local gtable  = require("gears.table")
local beautiful = require("beautiful")

local message = {}

function message:set_notification(notif)
    if self._private.notification == notif then return end

    if self._private.notification then
        self._private.notification:disconnect_signal("destroyed",
            self._private.message_changed_callback)
    end

    self:set_markup(notif.message)

    self._private.notification = notif

    notif:connect_signal("poperty::message", self._private.message_changed_callback)
end

local function new()
    local tb = textbox()
    tb:set_wrap("word")
    tb:set_font(beautiful.notification_font)

    gtable.crush(tb, message, true)

    function tb._private.message_changed_callback()
        self:set_markup(self._private.notification)
    end

    return tb
end

--@DOC_widget_COMMON@

--@DOC_object_COMMON@

return setmetatable(message, {__call = function(_, ...) return new(...) end})
