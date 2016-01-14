---------------------------------------------------------------------------
-- @author Emmanuel Lepage Vallee
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @classmod wibox.layout.stack
---------------------------------------------------------------------------

local base = require("wibox.widget.base")
local fixed = require("wibox.layout.fixed")
local table = table
local pairs = pairs
local floor = math.floor
local util = require("awful.util")

local stack = {mt={}}

--- Layout a stack layout. Each widget get drwan on top of each other
-- @param context The context in which we are drawn.
-- @param width The available width.
-- @param height The available height.
function stack:layout(context, width, height)
    if #self.widgets == 0 then return {} end

    local result = {}
    local spacing = self._spacing

    for k, v in pairs(self.widgets) do
        table.insert(result, base.place_widget_at(v, spacing, spacing, width - 2*spacing, height - 2*spacing))
--         if self._top_only then break end
    end

--     print("IN LAYOUT",spacing,spacing,width - 2*spacing,height - 2*spacing)
-- 
--     table.insert(result, base.place_widget_at(self.widgets[1], spacing, spacing, width - 2*spacing, height - 2*spacing))
-- 
--     for i = 2, #self.widgets do
--         local v = self.widgets[i]
--         if self._top_only then
--             v.visible = false --TODO break case where is widget is in multiple layouts, add wrapper
--         end
--         table.insert(result, base.place_widget_at(v, spacing, spacing, width - 2*spacing, height - 2*spacing))
--     end

    return result
end

--- Fit the stack layout into the given space.
-- @param context The context in which we are fit.
-- @param orig_width The available width.
-- @param orig_height The available height.
function stack:fit(context, orig_width, orig_height)
    local spacing = self._spacing

    for k, v in pairs(self.widgets) do
        base.fit_widget(self, context, v, orig_width - 2*spacing, orig_height - 2*spacing)
    end

    return orig_width, orig_height
end

--- Get if only the first stack widget is drawn
-- @return If the only the first stack widget is drawn
function stack:get_display_top_only()
    return self._top_only
end

--- Only draw the first widget of the stack, ignore others
-- @param top_only Only draw the top stack widget
function stack:set_display_top_only(top_only)
    self._top_only = top_only
end

function stack:raise(widget, recursive)
    base.check_widget(widget)

    local idx, layout = self:index(widget, recursive)

    if not idx or not layout then return end

    while layout and layout ~= self do
        idx, layout = self:index(layout, recursive)
    end

    if layout == self and idx ~= 1 then
        self.widgets[idx], self.widgets[1] = self.widgets[1], self.widgets[idx]
        self:emit_signal("widget::layout_changed")
        self:emit_signal("widget::redraw_needed")
    end
end

local function new(dir, widget1, ...)
    local ret = fixed.horizontal(...)

    util.table.crush(ret, stack)

    return ret
end

function stack.mt:__call(...)
    return new(...)
end

return setmetatable(stack, stack.mt)
-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
