---------------------------------------------------------------------------
-- @author Emmanuel Lepage Vallee
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

local base  = require("wibox.widget.base" )
local flex  = require("wibox.layout.flex" )
local fixed = require("wibox.layout.fixed")
local table = table
local pairs = pairs
local floor = math.floor
local util  = require("awful.util")

local ratio = {}

-- Compute the sum of all ratio (ideally, it should be 1)
local function gen_sum(self)
    local sum, new_w = 0,0

    -- Get the sum of all widget ratio
    for k, v in pairs(self.widgets) do
        if self._ratios[v] then
            sum = sum + self._ratios[v]
        else
            new_w = new_w + 1
        end
    end

    assert(sum < 1.01)

    return sum, new_w
end

--- Make sure "diff" the sum is 1
local function normalize(self)
    local count = #self.widgets
    if count == 0 then return end

    -- Instead of adding "if" everywhere, just handle this common case
    if count == 1 then
        self._ratios = {[self.widgets[1]] = 1 }
        return
    end

    local sum, new_w = gen_sum(self)
    local old_count  = #self.widgets - new_w

    local to_add = (sum == 0) and 1 or (sum / old_count)

    -- Make sure all widgets have a ratio
    for k, widget in pairs(self.widgets) do
        if not self._ratios[widget] then
            self._ratios[widget] = to_add
        end
    end

    sum = sum + to_add*new_w

    local delta, new_sum =  (1 - sum) / count,0

    -- Increase or decrease each ratio so it the sum become 1
    for k, widget in pairs(self.widgets) do
        self._ratios[widget] = self._ratios[widget] + delta
        new_sum = new_sum + self._ratios[widget]
    end

    assert(new_sum > -0.1 and new_sum < 1.01)
end

--- Layout a ratio layout. Each widget gets an equal share of the available space.
-- @param context The context in which we are drawn.
-- @param width The available width.
-- @param height The available height.
function ratio:layout(context, width, height)
    local result = {}
    local pos,spacing = 0, self._spacing
    local num = #self.widgets
    local total_spacing = (spacing*(num-1))

    normalize(self)

    for k, v in pairs(self.widgets) do
        local space = nil
        local x, y, w, h

        if self.dir == "y" then
            space = height * self._ratios[v]
            x, y = 0, util.round(pos)
            w, h = width, floor(space)
        else
            space = width * self._ratios[v]
            x, y = util.round(pos), 0
            w, h = floor(space), height
        end

        table.insert(result, base.place_widget_at(v, x, y, w, h))

        pos = pos + space + spacing

        if (self.dir == "y" and pos-spacing >= height) or
            (self.dir ~= "y" and pos-spacing >= width) then
            break
        end
    end

    return result
end

--- Increase the ratio of "widget"
-- @param widget The widget to change
-- @param percent An floating point value between -1 and 0.1
function ratio:inc_ratio(widget, percent)
    if #self.widgets ==  1 or (not widget) or percent < -1 or percent > 1 then return end

    self:set_ratio(widget, self._ratios[widget] - percent)
end

--- Set the ratio of "widget"
-- @param widget The widget to change
-- @param percent An floating point value between -1 and 0.1
function ratio:set_ratio(widget, r)
    if not r or #self.widgets ==  1 or (not widget) or r < -1 or r > 1 then return end

    local idx = self:index(widget)
    assert(idx)


    if not self._ratios[widget] then
        normalize(self)
    end

    local old = self._ratios[widget]

    -- Remove what has to be cleared from all widget
    local delta = ( (r-old) / (#self.widgets-1) )

    for k, v in pairs(self.widgets) do
        self._ratios[v] = self._ratios[v] - delta
    end

    -- Set the new ratio
    self._ratios[widget] = r

    self:emit_signal("widget::layout_changed")
end

function ratio:add(...)
    -- Clear the cache
    for k,v in ipairs({...}) do
        self._ratios[v] = nil
    end

    fixed.add(self,...)

    --FIXME This doesn't work if the same widget is there multiple time

    normalize(self)
end

function ratio:remove(...)
    -- Clear the cache
    for k,v in ipairs({...}) do
        self._ratios[v] = nil
    end

    fixed.remove(self,...)

    normalize(self)
end

function ratio:insert(...)
    -- Clear the cache
    for k,v in ipairs({...}) do
        self._ratios[v] = nil
    end

    fixed.insert(self,...)

    normalize(self)
end

local function get_layout(dir, widget1, ...)
    local ret = flex[dir](widget1, ...)

    ret._ratios = setmetatable({}, {__mode = 'k'})

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
