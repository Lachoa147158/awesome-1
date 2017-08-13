----------------------------------------------------------------------------
--- A notification title.
--
-- This widget is a specialized `wibox.widget.textbox` with the following extra
-- features:
--
-- * Honor the `beautiful` notification variables.
-- * React to the `naughty.notification` object title changes.
--
--@DOC_wibox_nwidget_title_simple_EXAMPLE@
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2017 Emmanuel Lepage Vallee
-- @classmod naughty.widget.title
----------------------------------------------------------------------------
local textbox = require("wibox.widget.textbox")
local gtable  = require("gears.table")
local beautiful = require("beautiful")

local title = {}

function title:set_notification(notif)
    if self._private.notification == notif then return end

    if self._private.notification then
        self._private.notification:disconnect_signal("destroyed",
            self._private.title_changed_callback)
    end

    self:set_markup("<b>"..(notif.title or "").."</b>")

    self._private.notification = notif

    notif:connect_signal("poperty::title", self._private.title_changed_callback)
end

local function new()
    local tb = textbox()
    tb:set_font(beautiful.notification_font)

    gtable.crush(tb, title, true)

    function tb._private.title_changed_callback()
        self:set_markup("<b>"..(self._private.notification.title or "").."</b>")
    end

    return tb
end

--@DOC_widget_COMMON@

--@DOC_object_COMMON@

return setmetatable(title, {__call = function(_, ...) return new(...) end})
