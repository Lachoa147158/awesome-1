---------------------------------------------------------------------------
-- @author Uli Schlachter
-- @copyright 2010 Uli Schlachter
-- @release @AWESOME_VERSION@
-- @classmod wibox.layout.fixed
---------------------------------------------------------------------------

local base  = require("wibox.widget.base")
local table = table
local pairs = pairs
local util = require("awful.util")

local fixed = {}

--- Layout a fixed layout. Each widget gets just the space it asks for.
-- @param context The context in which we are drawn.
-- @param width The available width.
-- @param height The available height.
function fixed:layout(context, width, height)
    local result = {}
    local pos,spacing = 0, self._spacing

    for k, v in pairs(self.widgets) do
        local x, y, w, h, _
        local in_dir
        if self.dir == "y" then
            x, y = 0, pos
            w, h = width, height - pos
            if k ~= #self.widgets or not self._fill_space then
                _, h = base.fit_widget(self, context, v, w, h);
            end
            pos = pos + h + spacing
            in_dir = h
        else
            x, y = pos, 0
            w, h = width - pos, height
            if k ~= #self.widgets or not self._fill_space then
                w, _ = base.fit_widget(self, context, v, w, h);
            end
            pos = pos + w + spacing
            in_dir = w
        end

        if (self.dir == "y" and pos-spacing > height) or
            (self.dir ~= "y" and pos-spacing > width) then
            break
        end
        table.insert(result, base.place_widget_at(v, x, y, w, h))
    end
    return result
end

--- Add some widgets to the given fixed layout
-- @tparam widget ... Widgets that should be added (must at least be one)
function fixed:add(...)
    -- No table.pack in Lua 5.1 :-(
    local args = { n=select('#', ...), ... }
    assert(args.n > 0, "need at least one widget to add")
    for i=1, args.n do
        base.check_widget(args[i])
        table.insert(self.widgets, args[i])
    end
    self:emit_signal("widget::layout_changed")
end

--- Remove one or more widgets from the layout
--- @tparam widget ... Widgets that should be removed (must at least be one)
--- The last parameter can be a boolean, forcing a recursive seach of the
--- widget(s) to remove.
function fixed:remove(...)
    local args = { ... }

    local recursive = type(args[#args]) == "boolean" and args[#args]

    local ret = true
    for _,rem_widget in ipairs(args) do
        local idx, l = self:index(rem_widget, recursive)

        if idx and l then
            -- In case :remove() is overloaded, make sure its logic is executed
            if l ~= self and l.remove then
                l:remove(l.widgets[idx], false)
            else
                assert(l.widgets[idx] == rem_widget)
                table.remove(l.widgets, idx)
                l:emit_signal("widget::layout_changed")
            end
        else
            ret = false
        end

    end

    return #args >= 0 and ret
end

--- Get all children of this layout
-- @warning If the widget contain itself, this will cause an infinite loop
-- @param[opt] recursive Also add all widgets of childrens
-- @return a list of all widgets
function fixed:get_widgets(recursive)
    if not recursive then return self.widgets end

    local ret = {}

    for k, w in ipairs(self.widgets) do
        table.insert(ret, w)
        local childrens = w.get_widgets and w:get_widgets(true) or {}
        for k2, w2 in ipairs(childrens) do
            table.insert(ret, w2)
        end
    end

    return ret
end

--- Get a widex index
-- @param widget The widget to look for
-- @param[opt] recursive Also check sub-widgets
-- @param[opt] ... Aditional widgets to add at the end of the "path"
-- @return The index, the parent layout, the path between "self" and "widget"
function fixed:index(widget, recursive, ...)
    for idx, w in ipairs(self.widgets) do
        if w == widget then
            return idx, self, {...}
        elseif recursive and type(w.index) == "function" then
            local idx, l, path = w:index(widget, true, self, ...)
            if idx and l then
                return idx, l, path
            end
        end
    end

    return nil, self, {}
end

--- Replace a widget in the layout
-- @param widget1_or_index A widget or a widget index
-- @param widget2 The widget to take the place of the first one
-- @param[opt] recursive Replace the widget even if it is not a direct child of this layout
-- @return The index of the replaced widget, the parent layout and the path
function fixed:replace(widget1_or_index, widget2, recursive)
    if not widget1_or_index or not widget2 then return end

    base.check_widget(widget2)

    local index, layout = type(widget1_or_index) == "number" and widget1_or_index or nil, self

    if not index then
        index, layout, path = self:index(widget1_or_index, recursive)
    end

    if layout and index then
        layout.widgets[index] = widget2

        layout:emit_signal("widget::layout_changed")
        layout:emit_signal("widget::redraw_needed")
        self:emit_signal("widget::redraw_needed")

        return index
    end

    return nil, layout, path
end

--- Swap 2 widgets in a layout
-- @param widget1 The first widget
-- @param widget2 The second widget
-- @param[opt] recursive Digg in all compatible layouts to find the widget.
--  This only work if the first argument is a widget
-- @return If the operation is successful, the widget index
function fixed:swap(widget1, widget2, recursive)
    local idx1, l1 = self:index(widget1, recursive)
    local idx2, l2 = self:index(widget2, recursive)

    if idx1 and l1 and idx2 and l2 then
        l1:replace(idx1, widget2)
        l2:replace(idx2, widget1)

        return true
    end

    return false
end

--- Insert a new widget in the layout at position `index`
-- @param index The position
-- @param widget The widget
function fixed:insert(index, widget)
    base.check_widget(widget)
    table.insert(self.widgets, index, widget)
    self:emit_signal("widget::layout_changed")
end

--- Get the number of children element
-- @return The number of children element
function fixed:get_children_count()
    return #self.widgets
end

--- Fit the fixed layout into the given space
-- @param context The context in which we are fit.
-- @param orig_width The available width.
-- @param orig_height The available height.
function fixed:fit(context, orig_width, orig_height)
    local width, height = orig_width, orig_height
    local used_in_dir, used_max = 0, 0

    for k, v in pairs(self.widgets) do
        local w, h = base.fit_widget(self, context, v, width, height)
        local in_dir, max
        if self.dir == "y" then
            max, in_dir = w, h
            height = height - in_dir
        else
            in_dir, max = w, h
            width = width - in_dir
        end
        if max > used_max then
            used_max = max
        end
        used_in_dir = used_in_dir + in_dir

        if width <= 0 or height <= 0 then
            if self.dir == "y" then
                used_in_dir = orig_height
            else
                used_in_dir = orig_width
            end
            break
        end
    end

    local spacing = self._spacing * (#self.widgets-1)

    if self.dir == "y" then
        return used_max, used_in_dir + spacing
    end
    return used_in_dir + spacing, used_max
end

--- Reset a fixed layout. This removes all widgets from the layout.
function fixed:reset()
    self.widgets = {}
    self:emit_signal("widget::layout_changed")
end

--- Set the layout's fill_space property. If this property is true, the last
-- widget will get all the space that is left. If this is false, the last widget
-- won't be handled specially and there can be space left unused.
function fixed:fill_space(val)
    if self._fill_space ~= val then
        self._fill_space = not not val
        self:emit_signal("widget::layout_changed")
    end
end

local function get_layout(dir, widget1, ...)
    local ret = base.make_widget()

    util.table.crush(ret, fixed)

    ret.dir = dir
    ret.widgets = {}
    ret:set_spacing(0)
    ret:fill_space(false)

    if widget1 then
        ret:add(widget1, ...)
    end

    return ret
end

--- Returns a new horizontal fixed layout. Each widget will get as much space as it
-- asks for and each widget will be drawn next to its neighboring widget.
-- Widgets can be added via :add() or as arguments to this function.
-- @tparam widget ... Widgets that should be added to the layout.
function fixed.horizontal(...)
    return get_layout("x", ...)
end

--- Returns a new vertical fixed layout. Each widget will get as much space as it
-- asks for and each widget will be drawn next to its neighboring widget.
-- Widgets can be added via :add() or as arguments to this function.
-- @tparam widget ... Widgets that should be added to the layout.
function fixed.vertical(...)
    return get_layout("y", ...)
end

--- Add spacing between each layout widgets
-- @param spacing Spacing between widgets.
function fixed:set_spacing(spacing)
    if self._spacing ~= spacing then
        self._spacing = spacing
        self:emit_signal("widget::layout_changed")
    end
end

return fixed

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
