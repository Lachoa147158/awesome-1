---------------------------------------------------------------------------
--- A notification object.
--
-- This class creates individual notification objects that can be manipulated
-- to extend the default behavior.
--
-- Notifications should not be created directly but rather by calling
-- `naughty.notify`.
--
-- This class doesn't define the actual widget, but is rather intended as a data
-- object to hold the properties. All examples assume the default widgets, but
-- the whole implementation can be replaced.
--
--@DOC_naughty_actions_EXAMPLE@
--
-- @author Emmanuel Lepage Vallee
-- @copyright 2008 koniu
-- @copyright 2017 Emmanuel Lepage Vallee
-- @classmod naughty.notification
---------------------------------------------------------------------------
local gobject = require("gears.object")
local gtable  = require("gears.table")
local timer   = require("gears.timer")
local cst     = require("naughty.constants")

local notification = {}

--- Unique identifier of the notification.
-- This is the equivalent to a PID as allows external applications to select
-- notifications.
-- @property text
-- @param string
-- @see title

--- Text of the notification.
-- @property text
-- @param string
-- @see title

--- Title of the notification.
--@DOC_naughty_helloworld_EXAMPLE@
-- @property title
-- @param string

--- Time in seconds after which popup expires.
--   Set 0 for no timeout.
-- @property timeout
-- @param number

--- Delay in seconds after which hovered popup disappears.
-- @property hover_timeout
-- @param number

--- Target screen for the notification.
-- @property screen
-- @param screen

--- Corner of the workarea displaying the popups.
--
-- The possible values are:
--
-- * *top_right*
-- * *top_left*
-- * *bottom_left*
-- * *bottom_right*
-- * *top_middle*
-- * *bottom_middle*
--
--@DOC_awful_notification_corner_EXAMPLE@
--
-- @property position
-- @param string

--- Boolean forcing popups to display on top.
-- @property ontop
-- @param boolean

--- Popup height.
-- @property height
-- @param number

--- Popup width.
-- @property width
-- @param number

--- Notification font.
--@DOC_naughty_colors_EXAMPLE@
-- @property font
-- @param string

--- Path to icon.
-- @property icon
-- @tparam string|surface icon

--- Desired icon size in px.
-- @property icon_size
-- @param number

--- Foreground color.
-- @property fg
-- @tparam string|color|pattern fg
-- @see title

--- Background color.
-- @property bg
-- @tparam string|color|pattern bg
-- @see title

--- Border width.
-- @property border_width
-- @param number
-- @see title

--- Border color.
-- @property border_color
-- @param string
-- @see title

--- Widget shape.
--@DOC_naughty_shape_EXAMPLE@
-- @property shape

--- Widget opacity.
-- @property opacity
-- @param number From 0 to 1

--- Widget margin.
-- @property margin
-- @tparam number|table margin
-- @see shape

--- Function to run on left click.
-- @property run
-- @param function

--- Function to run when notification is destroyed.
-- @property destroy
-- @param function

--- Table with any of the above parameters.
-- args will override ones defined
--   in the preset.
-- @property preset
-- @param table

--- Replace the notification with the given ID.
-- @property replaces_id
-- @param number

--- Function that will be called with all arguments.
--   The notification will only be displayed if the function returns true.
--   Note: this function is only relevant to notifications sent via dbus.
-- @property callback
-- @param function

--- A table containing strings that represents actions to buttons.
--
-- The table key (a number) is used by DBus to set map the action.
--
-- @property actions
-- @param table

--- Ignore this notification, do not display.
--
-- Note that this property has to be set in a `preset` or in a `request::preset`
-- handler.
--
-- @property ignore
-- @param boolean

--- Tell if the notification is currently suspended (read only).
--
-- This is always equal to `naughty.suspended`
--@property suspended
--@param boolean

--- Emitted when the notification is destroyed.
-- @signal destroyed

--- . --FIXME needs a description
-- @property ignore_suspend If set to true this notification
--   will be shown even if notifications are suspended via `naughty.suspend`.

--FIXME remove the screen attribute, let the handlers decide
-- document all handler extra properties

--FIXME add methods such as persist

--- Destroy notification by notification object
--
-- @tparam string reason One of the reasons from `notification_closed_reason`
-- @tparam[opt=false] boolean keep_visible If true, keep the notification visible
-- @return True if the popup was successfully destroyed, nil otherwise
function notification:destroy(reason, keep_visible)
    self:emit_signal("destroyed")

    return true
end

--- Set new notification timeout.
-- @tparam number new_timeout Time in seconds after which notification disappears.
function notification:reset_timeout(new_timeout)
    if self.timer then self.timer:stop() end

    local timeout = new_timeout or self.timeout
    set_timeout(self, timeout)
    self.timeout = timeout

    self.timer:start()
end

function notification:set_id(new_id)
    assert(self._private.id == nil, "Notification identifier can only be set once")
    self._private.id = new_id
    self:emit_signal("property::id", new_id)
end

function notification:set_timeout(timeout)
    local die = function (reason)
        self:destroy(reason)
    end
    if timeout > 0 then
        local timer_die = timer { timeout = timeout }
        timer_die:connect_signal("timeout", function() die(cst.notification_closed_reason.expired) end)
        if not self.suspended then
            timer_die:start()
        end

        -- Prevent a memory leak and the accumulation of active timers
        if self.timer and self.timer.started then
            self.timer:stop()
        end

        self.timer = timer_die
    end
    self.die = die
    self._private.timeout = timeout
end

local properties = {
    "text"    , "title"   , "timeout" , "hover_timeout" ,
    "screen"  , "position", "ontop"   , "border_width"  ,
    "width"   , "font"    , "icon"    , "icon_size"     ,
    "fg"      , "bg"      , "height"  , "border_color"  ,
    "shape"   , "opacity" , "margin"  , "ignore_suspend",
    "destroy" , "preset"  , "callback", "replaces_id"   ,
    "actions" , "run"     , "id"      , "ignore"        ,
}, {}

for _, prop in ipairs(properties) do
    notification["get_"..prop] = notification["get_"..prop] or function(self)
        -- It's possible this could be called from the `request::preset` handler.
        -- `rawget()` is necessary to avoid a stack overflow.
        local preset = rawget(self, "preset")

        return self._private[prop]
            or (preset and preset[prop])
            or cst.config.defaults[prop]
    end

    notification["set_"..prop] = notification["set_"..prop] or function(self, value)
        self._private[prop] = value
        self:emit_signal("property::"..prop, value)
        return
    end

end

-- This is a private API, please use the `naughty.notify` factory to generate
-- those objects.
--TODO v5 deprecate `naughty.notify` and allow direct creation
function notification._create(args)
    local n = gobject {
        enable_properties = true,
    }

    -- Avoid modifying the original table
    local private = {}

    for k, v in pairs(args) do
        private[k] = v
    end

    rawset(n, "_private", private)

    gtable.crush(n, notification, true)

    return n
end

return notification
