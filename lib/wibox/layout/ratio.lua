---------------------------------------------------------------------------
-- @author Uli Schlachter
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @classmod wibox.layout.ratio
--
-- Fill all the space with sub-widgets. Use the horizontal or vertical
-- ratio (mwfact, mhfact) property of the widgets (if any) to evaluate
-- the final size. The default ratio is 1.0. The size is obtained from
-- a product of three of the sum all all ratio relative to the widget
-- own width/height factor.
---------------------------------------------------------------------------

local base = require("wibox.widget.base")
local flex = require("wibox.layout.flex")
local table = table
local pairs = pairs
local floor = math.floor
local util = require("awful.util")

local ratio = {}

--- Layout a ratio layout. Each widget gets an equal share of the available space.
-- @param context The context in which we are drawn.
-- @param width The available width.
-- @param height The available height.
function ratio:layout(context, width, height)
    local result = {}
    local pos,spacing = 0, self._spacing
    local num = #self.widgets
    local total_spacing = (spacing*(num-1))

    local sum = 0

    -- Get the sum of all widget ratio
    for k, v in pairs(self.widgets) do
        sum = sum + (v.mwfact or 1)
    end

    -- It is not supposed to happen, negative are meaningless, but just in case
    if sum == 0 then
        sum = 1
    end

    for k, v in pairs(self.widgets) do
        print("HERE", self, #self.widgets)
        local space = nil
        local x, y, w, h
        if self.dir == "y" then
            space = height * ( (v.mwfact or 1) / sum)
            x, y = 0, util.round(pos)
            w, h = width, floor(space)
        else
            space = width * ( (v.mwfact or 1) / sum)
            x, y = util.round(pos), 0
            w, h = floor(space), height
        end

        print(w, width)
        table.insert(result, base.place_widget_at(v, x, y, w, h))

        pos = pos + space + spacing

        if (self.dir == "y" and pos-spacing >= height) or
            (self.dir ~= "y" and pos-spacing >= width) then
            break
        end
    end

    return result
end

local function get_layout(dir, widget1, ...)
    local ret = flex[dir](widget1, ...)

    util.table.crush(ret, ratio)

    ret.fill_space = nil

    return ret
end

--- Returns a new horizontal ratio layout. A ratio layout shares the available space
-- equally among all widgets. Widgets can be added via :add(widget).
-- @tparam widget ... Widgets that should be added to the layout.
function ratio.horizontal(...)
    return get_layout("horizontal", ...)
end

--- Returns a new vertical ratio layout. A ratio layout shares the available space
-- equally among all widgets. Widgets can be added via :add(widget).
-- @tparam widget ... Widgets that should be added to the layout.
function ratio.vertical(...)
    return get_layout("vertical", ...)
end

return ratio

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
