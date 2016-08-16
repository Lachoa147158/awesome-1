---------------------------------------------------------------------------
-- A container used to align smaller widgets into larger space.
--
--@DOC_wibox_container_defaults_align_EXAMPLE@
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @classmod wibox.container.align
---------------------------------------------------------------------------

local setmetatable = setmetatable
local base = require("wibox.widget.base")
local util = require("awful.util")

local align = { mt = {} }

-- Take the widget width/height and compute the position from the full
-- width/height
local align_fct = {
    left   = function(_  , _   ) return 0                         end,
    center = function(wdg, orig) return math.max(0, (orig-wdg)/2) end,
    right  = function(wdg, orig) return math.max(0, orig-wdg    ) end,
}
align_fct.top, align_fct.bottom = align_fct.left, align_fct.right

-- Layout this layout
function align:layout(context, width, height)
    if not self._private.widget or not self._private.widget._private.visible then
        return
    end

    local w, h = base.fit_widget(self, context, self._private.widget, width, height)

    local valign = self._private.valign or "center"
    local halign = self._private.halign or "center"

    local x, y = align_fct[halign](w, width), align_fct[valign](h, height)

    return { base.place_widget_at(self._private.widget, x, y, w, h) }
end

-- Fit this layout into the given area
function align:fit(context, width, height)
    if not self._private.widget then
        return 0, 0
    end
    return base.fit_widget(self, context, self._private.widget, width, height)
end

--- The widget to be aligned.
-- @property widget
-- @tparam widget widget The widget

function align:set_widget(widget)
    if widget then
        base.check_widget(widget)
    end
    self._private.widget = widget
    self:emit_signal("widget::layout_changed")
end

function align:get_widget()
    return self._private.widget
end

--- Get the number of children element
-- @treturn table The children
function align:get_children()
    return {self._private.widget}
end

--- Replace the layout children
-- This layout only accept one children, all others will be ignored
-- @tparam table children A table composed of valid widgets
function align:set_children(children)
    self:set_widget(children[1])
end

--- Reset this layout. The widget will be removed and the rotation reset.
function align:reset()
    self._private.direction = nil
    self:set_widget(nil)
end

--- Get the direction of this rotating layout
function align:get_direction()
    return self._private.direction or "north"
end

--- The vertical alignement.
--
-- Possible values are:
--
-- * *top*
-- * *center* (default)
-- * *bottom*
--
-- @property valign
-- @param string

--- The horizontal alignement.
--
-- Possible values are:
--
-- * *left*
-- * *center* (default)
-- * *right*
--
-- @property halign
-- @param string

function align:set_valign(value)
    if value ~= "center" and value ~= "top" and value ~= "bottom" then
        return
    end

    self._private.valign = value
    self:emit_signal("widget::layout_changed")
end

function align:set_halign(value)
    if value ~= "center" and value ~= "left" and value ~= "right" then
        return
    end

    self._private.halign = value
    self:emit_signal("widget::layout_changed")
end

--- Returns a new align container.
-- @param[opt] widget The widget to display.
-- @tparam[opt="center"] string halign The horizontal alignment
-- @tparam[opt="center"] string valign The vertical alignment
-- @treturn table A new align container.
-- @function wibox.container.align
local function new(widget, halign, valign)
    local ret = base.make_widget(nil, nil, {enable_properties = true})

    util.table.crush(ret, align, true)

    ret:set_widget(widget)
    ret:set_halign(halign)
    ret:set_valign(valign)

    return ret
end

function align.mt:__call(...)
    return new(...)
end

--@DOC_widget_COMMON@

--@DOC_object_COMMON@

return setmetatable(align, align.mt)

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
