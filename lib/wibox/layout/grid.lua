---------------------------------------------------------------------------
-- A two dimension layout disposing the widgets in a grid pattern.
--
--@DOC_wibox_layout_defaults_grid_EXAMPLE@
-- @author Emmanuel Lepage Vallee
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @classmod wibox.layout.grid
---------------------------------------------------------------------------

local unpack = unpack or table.unpack -- luacheck: globals unpack (compatibility with Lua 5.1)
local base  = require("wibox.widget.base")
local table = table
local pairs = pairs
local util = require("awful.util")
local color = require("gears.color")

local grid = {}

local function get_cell_sizes(self, context, orig_width, orig_height)
    local width, height = orig_width, orig_height

    local max_col, max_row, sum_w, sum_h = {}, {}, 0, 0

    local spacing = (self._private.spacing or 0)
        + (self._private.border_width or 0)

    local max_h = 0
    for row_idx, row in ipairs(self._private.rows) do
        for col_idx, v in ipairs(row) do
            local w, h = base.fit_widget(self, context, v, width, height)
            max_col[col_idx] = math.max(max_col[col_idx] or 0, w)
            max_row[row_idx] = math.max(max_row[row_idx] or 0, h)
            max_h = math.max(max_h, h)
        end
        height = height - max_h - spacing
        sum_h = sum_h + max_row[row_idx]
    end

    for i=1, #max_col do
        sum_w = sum_w + max_col[i]
    end

    return max_col, max_row, sum_w, sum_h
end

local function get_ajusted_cell_sizes(self, context, width, height)
    local max_col, max_row, sw, sh = get_cell_sizes(self, context, width, height)

    local spacing = (self._private.spacing or 0)
        + (self._private.border_width or 0)

    if self._private.fill_space then
        if sw + #max_col*spacing < width then
            local to_add = (width - (sw + #max_col*spacing)) / #max_col
            for i=1, #max_col do
                max_col[i] = max_col[i] + to_add
            end
        end

        if sh + #max_row*spacing < height then
            local to_add = (height - (sh + #max_row*spacing)) / #max_row
            for i=1, #max_row do
                max_row[i] = max_row[i] + to_add
            end
        end
        sw, sh = width - spacing*#max_col, height - spacing*#max_row
    end

    return max_col, max_row, sw, sh
end

-- The grid layout.
-- @param context The context in which we are drawn.
-- @param width The available width.
-- @param height The available height.
function grid:layout(context, width, height)
    local max_col, max_row = get_ajusted_cell_sizes(self, context, width, height)

    local result = {}

    local spacing = (self._private.spacing or 0)
        + (self._private.border_width or 0)

    local y = 0

    for row_idx = 1, #max_row do -- Vertical
        local x = 0
        for col_idx = 1, #max_col do -- Horizontal
            local v = self._private.rows[row_idx][col_idx]

            if v then
                table.insert(result, base.place_widget_at(
                    v, x, y, max_col[col_idx], max_row[row_idx]
                ))
                x = x + max_col[col_idx] + spacing
            else
                break
            end
        end

        y = y + max_row[row_idx] + spacing
    end

    return result
end

function grid:after_draw_children(context, cr, width, height)
    -- TODO support transparent colors
    if self._private.border_width and self._private.border_width > 0 then
        local bc = self._private.border_color

        if bc then
            cr:set_source(bc)
        end

        local bw = self._private.border_width
        local max_col, max_row, mw, mh = get_ajusted_cell_sizes(
            self, context, width, height
        )
        local spacing = (self._private.spacing or 0)
            + (self._private.border_width or 0)

        cr:set_line_width(bw)


        local sw, sh = 0, 0

        local max_x = math.min(width-bw , mw+#max_col*spacing)
        local max_y = math.min(height-bw, mh+#max_col*spacing)

        cr:rectangle( bw/2, bw/2, max_x, max_y )

        for i=1, #max_row do
            cr:move_to(bw/2, math.max(0, sh - spacing/2))
            cr:line_to(max_x, math.max(0, sh - spacing/2))

            sh = sh + max_row[i] + spacing
        end

        for i=1, #max_col do
            cr:move_to(math.max(0, sw - spacing/2), bw/2)
            cr:line_to(math.max(0, sw - spacing/2), max_y)

            sw = sw + max_col[i] + spacing
        end

        cr:stroke()
    end
end

local function get_next_empty(self, row, column)
    row, column = row or 1, column or 1
    local cc = self._private.column_count
    for i = row, math.huge do
        local r = self._private.rows[i]

        if not r then
            r = {}
            self._private.rows[i] = r
            self._private.row_count = i

            return i, 1
        end

        for j = column, cc do
            if not r[j] then
                return i, j
            end
        end
    end
end

local function index_to_point(data, index)
    return math.floor(index / data._private.row_count) + 1,
        index % data._private.column_count + 1
end

--- Add some widgets to the given grid layout
-- @param ... Widgets that should be added (must at least be one)
function grid:add(...)

    local args = { n=select('#', ...), ... }
    assert(args.n > 0, "need at least one widget to add")

    local row, column

    for i=1, args.n do
        local w = args[i]

        row, column = get_next_empty(self, row, column)

        base.check_widget(w)

        self._private.rows[row][column] = w
        table.insert(self._private.children, w)
    end

    self:emit_signal("widget::layout_changed")
end

--- Set a widget at a specific position.
-- @tparam number row The row
-- @tparam number column The column
-- @param widget The widget
function grid:set_cell_widget(row, column, widget)
    if row < self._private.row_count then
        grid:set_row_count(row)
    end

    if column < self._private.column_count then
        grid:set_column_count(column)
    end

    self._private.rows[row] = self._private.rows[row] or {}

    self:emit_signal("widget::layout_changed")
end

--- The number of columns.
-- @property column_count
-- @param number

--- The number of rows.
-- Note that this is automatically incremented when more elements
-- are added to the layout.
-- @property row_count
-- @param number

function grid:set_row_count(count)
    self._private.row_count = count
    self:emit_signal("widget::layout_changed")
end

function grid:set_column_count(count)
    self._private.column_count = count
    self:emit_signal("widget::layout_changed")
end

--- Re-pack all the widget according to the current `row_count` and `column_count`.
function grid:reflow()
    local children = self:get_children()
    self:reset()
    if #children > 0 then
        self:add(unpack(children))
    end
end

--- Remove a widget from the layout
-- @tparam number index The widget index to remove
-- @treturn boolean index If the operation is successful
function grid:remove(index)
    local TODO_TOTAL = #self:get_children()
    if not index or index < 1 or index > TODO_TOTAL then return false end

    local r, c = index_to_point(data, index)

    self._private.rows[r][c] = nil

    self:emit_signal("widget::layout_changed")

    return true
end

--- Remove one or more widgets from the layout
-- The last parameter can be a boolean, forcing a recursive seach of the
-- widget(s) to remove.
-- @param widget ... Widgets that should be removed (must at least be one)
-- @treturn boolean If the operation is successful
function grid:remove_widgets(...)
    local args = { ... }

    local recursive = type(args[#args]) == "boolean" and args[#args]

    local ret = true
    for k, rem_widget in ipairs(args) do
        if recursive and k == #args then break end

        local idx, l = self:index(rem_widget, recursive)

        if idx and l and l.remove then
            l:remove(idx, false)
        else
            ret = false
        end
    end

    return #args > (recursive and 1 or 0) and ret
end

function grid:get_children()
    return self._private.children
end

function grid:set_children(children)
    self:reset()
    if #children > 0 then
        self:add(unpack(children))
    end
end

--- Replace the first instance of `widget` in the layout with `widget2`
-- @param widget The widget to replace
-- @param widget2 The widget to replace `widget` with
-- @tparam[opt=false] boolean recursive Digg in all compatible layouts to find the widget.
-- @treturn boolean If the operation is successful
function grid:replace_widget(widget, widget2, recursive)
    local idx, l = self:index(widget, recursive)

    if idx and l then
        l:set(idx, widget2)
        return true
    end

    return false
end

function grid:swap_widgets(widget1, widget2, recursive)
    base.check_widget(widget1)
    base.check_widget(widget2)

    local idx1, l1 = self:index(widget1, recursive)
    local idx2, l2 = self:index(widget2, recursive)

    if idx1 and l1 and idx2 and l2 and (l1.set or l1.set_widget) and (l2.set or l2.set_widget) then
        if l1.set then
            l1:set(idx1, widget2)
        elseif l1.set_widget then
            l1:set_widget(widget2)
        end
        if l2.set then
            l2:set(idx2, widget1)
        elseif l2.set_widget then
            l2:set_widget(widget1)
        end

        return true
    end

    return false
end

function grid:set(index, widget2)
    if (not widget2) or (not self._private.rows[index]) then return false end

    base.check_widget(widget2)

    self._private.rows[index] = widget2

    self:emit_signal("widget::layout_changed")

    return true
end

--- Insert a new widget in the layout at position `index`
-- @tparam number index The position
-- @param widget The widget
-- @treturn boolean If the operation is successful
function grid:insert(index, widget)
    local TODO_TOTAL = math.huge --FIXME
    if not index or index < 1 or index > TODO_TOTAL then return false end

    base.check_widget(widget)
    table.insert(self._private.rows, index, widget) --FIXME
    self:emit_signal("widget::layout_changed")

    return true
end

-- Fit the grid layout into the given space
-- @param context The context in which we are fit.
-- @param orig_width The available width.
-- @param orig_height The available height.
function grid:fit(context, orig_width, orig_height)
    local max_col, max_row = get_cell_sizes(self, context, orig_width, orig_height)

    -- Now that all fit is done, get the maximum
    local used_max_h, used_max_w = 0, 0

    for row_idx = 1, #max_row do
        -- The other widgets will be discarded
        if used_max_h + max_row[row_idx] > orig_height then
            break
        end

        used_max_h = used_max_h + max_row[row_idx]
    end

    for col_idx = 1, #max_col do
        -- The other widgets will be discarded
        if used_max_w + max_col[col_idx] > orig_width then
            break
        end

        used_max_w = used_max_w + max_col[col_idx]
    end

    return used_max_w, used_max_h
end

function grid:reset()
    self._private.rows = {}
    self._private.children = {}
    self:emit_signal("widget::layout_changed")
end

--- Set the layout's fill_space property. If true, the remaining space will
-- be distributed equally across all widgets in the grid.
-- @DOC_wibox_layout_grid_fill_space_EXAMPLE@
-- @property fill_space
-- @param boolean

function grid:set_fill_space(val)
    if self._private.fill_space ~= val then
        self._private.fill_space = not not val
        self:emit_signal("widget::layout_changed")
    end
end

--- The the border (grid) width.
-- @DOC_wibox_layout_grid_border_EXAMPLE@
-- @property border_width
-- @param number

function grid:set_border_width(val)
    if self._private.border_width ~= val then
        self._private.border_width = math.max(0, val)

        -- This count as spacing, so the layout really change
        self:emit_signal("widget::layout_changed")
    end
end

--- The the border (grid) color.
-- @property border_color
-- @param color
-- @see gears.color

function grid:set_border_color(val)
    self._private.border_color = color(val)

    self:emit_signal("widget::redraw_needed")
end

local function get_layout(dir, widget1, ...)
    local ret = base.make_widget(nil, nil, {enable_properties = true})

    util.table.crush(ret, grid, true)

    ret._private.widgets = {}
    ret._private.column_count = 1
    ret:set_spacing(0)
    ret:set_fill_space(false)

    if widget1 then
        ret:add(widget1, ...)
    end

    return ret
end

--- Add spacing between each layout widgets
--@DOC_wibox_layout_grid_spacing_EXAMPLE@
-- @property spacing
-- @tparam number spacing Spacing between widgets.

function grid:set_spacing(spacing)
    if self._private.spacing ~= spacing then
        self._private.spacing = spacing
        self:emit_signal("widget::layout_changed")
    end
end

function grid:get_spacing()
    return self._private.spacing or 0
end

--@DOC_widget_COMMON@

--@DOC_object_COMMON@

return setmetatable(grid, {__call=function(_, ...) return get_layout(...) end})

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
