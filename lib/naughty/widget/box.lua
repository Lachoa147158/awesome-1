----------------------------------------------------------------------------
--- A notification popup widget.
--
--@DOC_naughty_actions_EXAMPLE@
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2017 Emmanuel Lepage Vallee
-- @classmod naughty.widget.box
----------------------------------------------------------------------------

local capi       = { screen = screen, awesome = awesome }
local naughty    = require("naughty.core")
local screen     = require("awful.screen")
local button     = require("awful.button")
local beautiful  = require("beautiful")
local surface    = require("gears.surface")
local gtable     = require("gears.table")
local wibox      = require("wibox")
local gfs        = require("gears.filesystem")
local popup      = require("awful.popup")
local actionlist = require("naughty.widget.actionlist")
local wtitle     = require("naughty.widget.title")
local wmessage   = require("naughty.widget.message")
local wicon      = require("naughty.widget.icon")
local dpi        = require("beautiful").xresources.apply_dpi

local box = {}

local by_position = {
    top_left      = setmetatable({},{__mode = "v"}),
    top_middle    = setmetatable({},{__mode = "v"}),
    top_right     = setmetatable({},{__mode = "v"}),
    bottom_left   = setmetatable({},{__mode = "v"}),
    bottom_middle = setmetatable({},{__mode = "v"}),
    bottom_right  = setmetatable({},{__mode = "v"}),
}

local function placement(w, args)
    local position = w.position
    assert(position)

end

local function update_position(position)
    assert(by_position[position])

    local y_offset = 0

    for _, wdg in ipairs(by_position[position]) do

        wdg.y = wdg.screen.workarea.y + y_offset

        y_offset = y_offset + wdg.height + 2*(wdg.border_width or 0)

        -- Only show it after it has been moved into position to avoid a flicker
        wdg.visible = true
    end

end

local function finish(self)
    self.visible = false
    assert(by_position[self.position])


    for k, v in ipairs(by_position[self.position]) do
        if v == self then
            table.remove(by_position[self.position], k)
            break
        end
    end

    update_position(self.position)
end

--- The maximum notification width.
-- @beautiful beautiful.notification_max_width
-- @tparam[opt=500] number notification_max_width

--- The maximum notification position.
--
-- Valid values are:
--
-- * top_left
-- * top_middle
-- * top_right
-- * bottom_left
-- * bottom_middle
-- * bottom_right
--
-- @beautiful beautiful.notification_position
-- @tparam[opt="top_right"] string notification_position

--- The widget notification object.
-- @property notification
-- @param naughty.notification

--- The widget template to construct the box content.
-- @property widget_template
-- @param widget

local default_template = nil

-- Used as a fallback when no widget_template is provided, emulate the legacy
-- widget.
local function default_widget(args)
    return {
        {
            {
                {
                    {
                        id = "icon_role",
                        widget = wicon,
                    },
                    {
                        {
                            id     = "title_role",
                            font   = args.font,
                            widget = wtitle
                        },
                        {
                            id     = "message_role",
                            font   = args.font,
                            widget = wmessage
                        },
                        layout = wibox.layout.fixed.vertical
                    },
                    fill_space = true,
                    layout     = wibox.layout.fixed.horizontal
                },
                {
                    id     = "action_role",
                    widget = actionlist
                },
                spacing_widget = {
                    forced_height = 10,
                    opacity       = 0.3,
                    span_ratio    = 0.9,
                    widget        = wibox.widget.separator
                },
                spacing = 10,
                layout  = wibox.layout.fixed.vertical
            },
            margins = beautiful.notification_margin or 4,
            widget  = wibox.container.margin
        },
        strategy = "max",
        width    = beautiful.notification_max_width or dpi(500),
        widget   = wibox.container.constraint
    }
end

local function get_roles(widget)
    return {
        title_role      = widget:get_children_by_id( "title_role"      )[1];
        message_role    = widget:get_children_by_id( "message_role"    )[1];
        action_role     = widget:get_children_by_id( "action_role"     )[1];
        icon_role       = widget:get_children_by_id( "icon_role"       )[1];
    }
end

local function init(self, notification)
    local args = self._private.args

    local preset = notification.preset
    assert(preset)

    local position = args.position or beautiful.notification_position or
        preset.position or "top_right"

    self.widget = wibox.widget.base.make_widget_from_value(
        self._private.widget_template or default_widget(self._private.args)
    )

    -- Detect pre-defined roles and set the values. This avoid each user to
    -- have to copy/paste this code.
    local roles = get_roles(self._private.widget)

    if roles.title_role then
        if roles.title_role.set_notification then
            roles.title_role:set_notification(notification)
        else
            roles.title_role:set_markup("<b>".. notification.title .."</b>")
        end
    end

    if roles.icon_role and notification.icon then
        if roles.icon_role.set_notification then
            roles.icon_role:set_notification(notification)
        else
            roles.icon_role:set_image(notification.icon)
        end
    end

    if roles.message_role then
        if roles.message_role.set_notification then
            roles.message_role:set_notification(notification)
        else
            roles.message_role:set_markup(notification.text)
        end
    end

    if roles.action_role then
        roles.action_role:set_notification(notification)
    end

    -- Add the notification to the active list
    assert(by_position[position])

    self:_apply_size_now()

    table.insert(by_position[position], self)

    self:connect_signal("property::geometry", function()
        update_position(position)
    end)

    notification:connect_signal("destroyed", self._private.destroy_callback)

    update_position(position)

end

function box:set_notification(notif)
    if self._private.notification == notif then return end

    if self._private.notification then
        self._private.notification:disconnect_signal("destroyed",
            self._private.destroy_callback)
    end

    init(self, notif)

    self._private.notification = notif
end

function box:get_position()
    if self._private.notification then
        return self._private.notification:get_position()
    end

    return "top_right"
end

local function new(args)

    -- Set the default wibox values
    local new_args = {
        ontop        = true,
        visible      = false,
        bg           = args and args.bg or beautiful.notification_bg,
        fg           = args and args.fg or beautiful.notification_fg,
        shape        = args and args.shape or beautiful.notification_shape,
        border_width = args and args.border_width or beautiful.notification_border_width,
        border_color = args and args.border_color or beautiful.notification_border_color,
    }

    new_args = args and setmetatable(new_args, {__index = args}) or new_args

    local ret = popup(new_args)
    ret._private.args = new_args

    gtable.crush(ret, box, true)

    function ret._private.destroy_callback()
        finish(ret)
    end

    if new_args.notification then
        init(ret, new_args.notification)
    end

    return ret
end

function box.notification_handler(notification, args)
    local r = new(args)
end

--@DOC_wibox_COMMON@

return setmetatable(box, {__call = function(_, args) return new(args) end})
