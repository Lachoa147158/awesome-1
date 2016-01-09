---------------------------------------------------------------------------
-- @author Uli Schlachter
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

local stack = {}

--- Layout a stack layout. Each widget get drwan on top of each other
-- @param context The context in which we are drawn.
-- @param width The available width.
-- @param height The available height.
function stack:layout(context, width, height)
    local result = {}
    local spacing = self._spacing

    for k, v in pairs(self.widgets) do
        table.insert(result, base.place_widget_at(v, spacing, spacing, width - 2*spacing, height - 2*spacing))
    end

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

function stack:raise(widget, recursive)
    
end

local function new(dir, widget1, ...)
    local ret = fixed[dir](...)

    util.table.crush(ret, stack)

    return ret
end

function stack.mt:__call(...)
    return new(...)
end

return setmetatable(stack, constraint.mt)
-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
