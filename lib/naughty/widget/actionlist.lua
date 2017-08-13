----------------------------------------------------------------------------
--- Manage a notification action list.
--
-- A notification action is a "button" that will trigger an action on the sender
-- process. `notify-send` doesn't support action, but `libnotify` based
-- applications do.
--
--@DOC_wibox_nwidget_actionlist_simple_EXAMPLE@
--
-- Here's a more customized example:
--
--@DOC_wibox_nwidget_actionlist_fancy_EXAMPLE@
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2017 Emmanuel Lepage Vallee
-- @classmod naughty.widget.actionlist
----------------------------------------------------------------------------

local wibox    = require("wibox")
local awcommon = require("awful.widget.common")
local abutton  = require("awful.button")
local gtable   = require("gears.table")
local beautiful= require("beautiful")

local module = {}

local default_buttons = gtable.join(
    abutton({ }, 1, function(a) a.callback() end)
)

local function wb_label(item)
    return "<u>"..item.label.."</u>", item.selected and "#00ff00" or nil
end

local function reload_cache(self)
    self._private.cache = {}

    if not self._private.notification then return end

    for name, callback in pairs(self._private.notification.actions or {}) do
        table.insert(self._private.cache, {
            label    = name,
            callback = callback,
        })
    end
end

local function update(self)
    awcommon.list_update(
        self._private.layout,
        default_buttons,
        wb_label,
        self._private.data,
        self._private.cache,
        {
            widget_template = self._private.widget_template
        }
    )
end

local actionlist = {}

--- The actionlist parent notification.
-- @property notification
-- @param notification
-- @see naughty.notification

--- The actionlist layout.
-- If no layout is specified, a `wibox.layout.fixed.vertical` will be created
-- automatically.
-- @property layout
-- @param widget
-- @see wibox.layout.fixed.vertical

--- The actionlist parent notification.
-- @property widget_template
-- @param table

function actionlist:set_notification(notif)
    self._private.notification = notif

    if not self._private.layout then
        self._private.layout = wibox.layout.fixed.vertical()
    end

    reload_cache(self)
    update(self)

    self:emit_signal("widget::layout_changed")
    self:emit_signal("widget::redraw_needed")
end

function actionlist:set_base_layout(layout)
    self._private.layout = layout

    update(self)

    self:emit_signal("widget::layout_changed")
    self:emit_signal("widget::redraw_needed")
end

function actionlist:set_widget_template(widget_template)
    self._private.widget_template = widget_template

    -- Remove the existing instances
    self._private.data = {}

    update(self)

    self:emit_signal("widget::layout_changed")
    self:emit_signal("widget::redraw_needed")
end

function actionlist:get_notification()
    return self._private.notification
end

function actionlist:layout(_, width, height)
    if self._private.layout then
        return { wibox.widget.base.place_widget_at(self._private.layout, 0, 0, width, height) }
    end
end

function actionlist:fit(context, width, height)
    if not self._private.layout then
        return 0, 0
    end

    return wibox.widget.base.fit_widget(self, context, self._private.layout, width, height)
end

--- Create an action list.
--
-- @tparam table args
-- @tparam naughty.notification args.notification The notification/
-- @tparam widget args.layout The action layout.
-- @tparam[opt] table widget_template A custom widget to be used for each action.
-- @treturn widget The action widget.
-- @function naughty.widget.actionlist

local function new(_, args)
    args = args or {}

    local wdg = wibox.widget.base.make_widget(nil, nil, {
        enable_properties = true,
    })

    gtable.crush(wdg, actionlist, true)

    wdg._private.data = {}

    gtable.crush(wdg, args)

    return wdg
end

--@DOC_widget_COMMON@

--@DOC_object_COMMON@

return setmetatable(module, {__call = new})
