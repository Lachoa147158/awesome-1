---------------------------------------------------------------------------
--- An auto-resized free floating wibox built around a widget.
--
-- This type of widget box (wibox) is auto closed when being clicked on and is
-- automatically resized to the size of its main widget.
--
-- Note that the widget itself should have a finite size. If something like a
-- `wibox.layout.flex` is used, then the size would be unlimited and an error
-- will be printed. The `wibox.layout.fixed`, `wibox.container.constraint`,
-- `forced_width` and `forced_height` are recommended.
--
--@DOC_awful_popup_simple_EXAMPLE@
--
-- Here is an example of how to create an alt-tab like dialog by leveraging
-- the `awful.widget.tasklist`.
--
--@DOC_awful_popup_alttab_EXAMPLE@
--
-- @author Emmanuel Lepage Vallee
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.popup
---------------------------------------------------------------------------
local wibox     = require( "wibox"            )
local util      = require( "awful.util"       )
local glib      = require( "lgi"              ).GLib
local beautiful = require( "beautiful"        )
local color     = require( "gears.color"      )
local placement = require( "awful.placement"  )
local unpack    = unpack or table.unpack

local module = {}

local main_widget = {}

--TODO position = relative to parent
--TODO direction = up or down (the alternate stuff)

-- Get the optimal direction for the wibox
-- This (try to) avoid going offscreen
local function set_position(self)
    local pf = rawget(self, "_placement")
    if pf == false then return end

    if pf then
        pf(self, {bounding_rect = self.screen.geometry})
        return
    end

    if not self.auto_place then return end

    local geo = rawget(self, "widget_geo")

    local preferred_positions = rawget(self, "_preferred_directions") or {
        "right", "left", "top", "bottom"
    }

    local _, pos_name = placement.next_to(self, {
        preferred_positions = preferred_positions,
        geometry            = geo,
        offset              = {
            x = (rawget(self, "xoffset") or 0),
            y = (rawget(self, "yoffset") or 0),
        },
    })

    if pos_name ~= rawget(self, "position") then
        self:emit_signal("property::direction", pos_name)
        rawset(self, "position", pos_name)
    end
end

-- Fit this widget into the given area
function main_widget:fit(context, width, height)
    if not self.widget then
        return 0, 0
    end

    return wibox.widget.base.fit_widget(self, context, self.widget, width, height)
end

-- Layout this widget
function main_widget:layout(context, width, height)
    if self.widget then
        local w, h = wibox.widget.base.fit_widget(self, context, self.widget, 9999, 9999)
        glib.idle_add(glib.PRIORITY_HIGH_IDLE, function()

            local prev_geo = self._wb:geometry()
            self._wb.width  = math.max(1, math.ceil(w or 1))
            self._wb.height = math.max(1, math.ceil(h or 1))

            if self._wb.width ~= prev_geo.width and self._wb.height ~= prev_geo.height then
                set_position(self._wb)
            end
        end)
        return { wibox.widget.base.place_widget_at(self.widget, 0, 0, width, height) }
    end
end

-- Set the widget that is drawn on top of the background
function main_widget:set_widget(widget)
    if widget then
        wibox.widget.base.check_widget(widget)
    end
    self.widget = widget
    self:emit_signal("widget::layout_changed")
end

-- Get the number of children element
-- @treturn table The children
function main_widget:get_children()
    return {self.widget}
end

-- Replace the layout children
-- This layout only accept one children, all others will be ignored
-- @tparam table children A table composed of valid widgets
function main_widget:set_children(children)
    self.widget = children and children[1]
    self:emit_signal("widget::layout_changed")
end

local popup = {}

--- Set the preferred wibox directions relative to its parent. --FIXME do it better
-- Valid directions are:
-- * left
-- * right
-- * top
-- * bottom
-- @tparam string ... One of more directions (in the preferred order)
function popup:set_preferred_positions(pref_pos)
    rawset(self, "_preferred_directions", pref_pos)
end

--- Move the wibox to a position relative to `geo`.
-- This will try to avoid overlapping the source wibox and auto-detect the right
-- direction to avoid going off-screen.
-- @param[opt=mouse.coords()] geo A geometry table. It is given as parameter
--  from buttons callbacks and signals such as `mouse::enter`.
-- @param mode Use the mouse position instead of the widget center as
-- reference point.
function popup:move_by_parent(geo, mode)
    if rawget(self, "is_relative") == false then return end

    rawset(self, "widget_geo", geo)

    set_position(self)
end

function popup:move_by_mouse()
    --TODO
end

function popup:set_auto_palce(value)
    self._private.autoplace = value
    set_position(self)
end

function popup:get_auto_place()
    return self._private.autoplace or false
end

--- The distance between the popup and its parent (if any).
-- @property offset
-- @tparam table|number offset An integer value or a `{x=, y=}` table.
-- @tparam[opt=offset] number offset.x The horizontal distance.
-- @tparam[opt=offset] number offset.y The vertical distance.

function popup:set_xoffset(offset)
    local old =  rawget(self, "xoffset") or 0
    if old == offset then return end

    rawset(self, "xoffset", offset)

    -- Update the position
    set_position(self)
end

function popup:set_yoffset(offset)
    local old =  rawget(self, "yoffset") or 0
    if old == offset then return end

    rawset(self, "yoffset", offset)

    -- Update the position
    set_position(self)
end


--- Set if the wibox take into account the other wiboxes.
-- @property relative
-- @tparam boolean val Take the other wiboxes position into account

function popup:set_relative(val)
    rawset(self, "is_relative", val)
end

--- Set the placement function.
-- @tparam[opt=next_to] function|string|boolean The placement function or name
-- (or false to disable placement)
-- @property placement
-- @param function

function popup:set_placement(f)
    if type(f) == "string" then
        f = placement[f]
    end

    rawset(self, "_placement", f)

    -- Update the position
    set_position(self)
end

-- For the tests
function popup:_apply_size_now()
    if not self.widget then return end

    local w, h = wibox.widget.base.fit_widget(self.widget, {dpi=96}, self.widget, 9999, 9999)

    local prev_geo = self:geometry()
    self.width  = math.max(1, math.ceil(w or 1))
    self.height = math.max(1, math.ceil(h or 1))

    set_position(self)
end

local function init_widget(self, wdg)
    -- Empty popup are forbidden since it would be 0x0
    assert(wdg)

    -- Add some syntax sugar and allow widget inline declarations or
    -- constructors
    wdg = wibox.widget.base.make_widget_from_value(wdg)

    self._private.widget = wdg

    self._private.container:set_widget(wdg)
end

function popup:set_widget(wid)
    self._private.widget = wid
    self._private.container:set_widget(wid)
end

function popup:get_widget()
    return self._private.widget
end

--- A brilliant idea to totally turn the whole hierarchy on its head
-- and create a widget that own a wibox...
--TODO all args
-- @function awful.popup
local function create_auto_resize_widget(_, args)
    assert(args)

    -- Temporarily remove the widget
    local original_widget = args.widget
    args.widget = nil


    local ii = wibox.widget.base.make_widget()

    util.table.crush(ii, main_widget)

    -- Create a wibox to host the widget
    local w = wibox(args or {})

    rawset(w, "_private", {
        container = ii
    })

    util.table.crush(w, popup)

    if original_widget then
        init_widget(w, original_widget)
    end

    -- Restore
    args.widget = original_widget

    -- Cross-link the wibox and widget
    ii._wb = w
    wibox.set_widget(w, ii)

    if args and args.preferred_positions then
        if type(args.preferred_positions) == "table" then
            w:set_preferred_positions(args.preferred_positions)
        else
            w:set_preferred_positions({args.preferred_positions})
        end
    end

    if args.shape then
        w:set_shape(args.shape, unpack(args.shape_args or {}))
    end

    if args.relative ~= nil then
        w:set_relative(args.relative)
    end

    for k,v in ipairs{"placement"} do --FIXME extend
        if args[v] ~= nil then
            w["set_"..v](w, args[v])
        end
    end

    -- Default to visible
    if args.visible ~= false then
        w.visible = true
    end

    return w
end

--@DOC_wibox_COMMON@

return setmetatable(module, {__call = create_auto_resize_widget})
