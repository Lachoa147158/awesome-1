---------------------------------------------------------------------------
--- Allow dynamic layouts to be created using wibox.layout composition
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.layout.hierarchy
---------------------------------------------------------------------------


local tag       = require( "awful.tag"                  )
local util      = require( "awful.util"                 )
local client    = require( "awful.client"               )
local hierarchy = require( "wibox.hierarchy"            )
local object    = require( "gears.object"               )
local aw_layout = require( "awful.layout"               )
local cairo     = require( "lgi"                        ).cairo
local resize    = require( "awful.layout.dynamic.resize")
local base_layout = require( "awful.layout.dynamic.base_layout" )
local l_wrapper = require( "awful.layout.dynamic.wrapper")


local internal = {}

function internal.insert_wrapper(handler, c, wrapper)

    local pos = #handler.wrappers+1
    handler.wrappers         [ pos ] = wrapper
    handler.client_to_wrapper[ c   ] = wrapper
    handler.client_to_index  [ c   ] = pos

    handler.widget:add(wrapper)
end

function internal.remove_wrapper(handler, c, wrapper)
    table.remove(handler.wrappers, handler.client_to_index[c])
    handler.client_to_index  [c] = nil
    handler.client_to_wrapper[c] = nil

    handler.widget:remove(wrapper, true)
end

--- Get the list of client that were added and removed
local function get_client_differential(self)
    local added, removed = {}, {}

    local clients, reverse = self._tag:clients(), {}

    for k,c in ipairs(clients) do
        if not client.floating.get(c) and not self.client_to_wrapper[c] then
            table.insert(added, c)
        end
        reverse[c] = true
    end

    for c,_ in pairs(self.client_to_wrapper) do
        if not reverse[c] then
            table.insert(removed, c)
        end
    end

    return added, removed
end

--- When a tag is selected or the layout change for this one, activate the handler
local function wake_up(self)
    if self.widget.wake_up then
        self.widget:wake_up()
    end

    local added, removed = get_client_differential(self)

    for k, c in ipairs(added) do
        if not client.floating.get(c) then
            local wrapper = l_wrapper.wrap_client(internal, c)
            wrapper._handler = self

            internal.insert_wrapper(self, c, wrapper)
        end
    end

    for k, c in ipairs(removed) do
        local wrapper = self.client_to_wrapper[c]

        internal.remove_wrapper(self, c, wrapper)
    end

    self.active = true
end

-- When a tag is hidden or the layout isn't the handler, stop all processing
local function suspend(self)
    if self.widget.suspend then
        self.widget.suspend(self.widget)
    end

    self.active = false
end

-- Create the wrapper
-- @param c_w A client or a wibox
function internal.wrap_client(internal, c_w)
    local wrapper = object()
    wrapper:add_signal("widget::redraw_needed")
    wrapper:add_signal("widget::layout_changed")

    wrapper._client              = c_w
    wrapper.draw                 = draw
    wrapper.before_draw_children = before_draw_children
    wrapper.after_draw_children  = after_draw_children
    wrapper.layout               = layout
    wrapper.visible              = true
    wrapper._widget_caches       = {}
    wrapper.splitting_points     = splitting_points


    --TODO disconnect these in suspend
    c_w:connect_signal("property::minimized", function(c)
        local handler = wrapper._handler
        if handler.active then
            --TODO the widget.visible attribute is not implemented by layouts
            --TODO support inserting it back where it was
            if c_w.minimized then
                internal.remove_wrapper(handler, c, wrapper)
            else
                internal.insert_wrapper(handler, c, wrapper)
            end
        end

    end)

    --TODO add terminate_wrapper to disconnect all signals, it leak

    --Listen to resize requests
    c_w:connect_signal("request::geometry", function(c, reasons, geo)
        local handler = wrapper._handler
        if handler.active  and reasons == "mouse.resize" then
            if handler.widget.resize then
                handler.widget:resize(wrapper, geo)
            else
                resize.update_ratio(handler.hierarchy, wrapper, geo)
            end
        end
    end)

    --TODO disconnect these in suspend
    c_w:connect_signal("swapped",function(self,other_c,is_source)
        if wrapper._handler.active and is_source then
            if wrapper._handler then
                wrapper._handler:swap(self, other_c, true)
                wrapper._handler.widget:emit_signal("widget::redraw_needed")
            end
        end
    end)

    c_w:connect_signal("focus",function(c)
        if wrapper._handler.active and wrapper._handler.widget.raise then
            wrapper._handler.widget:raise(wrapper, true)
        end
    end)

    c_w:connect_signal("property::floating",function(c)
        if client.floating.get(c) then
            wrapper._handler.widget:add(wrapper, true)
        else
            wrapper._handler.widget:remove(wrapper, true)
        end
    end)

    return wrapper
end

local function main_layout(self, handler)

    local region = cairo.Region.create()

    if not handler.param then
        handler.param = aw_layout.parameters(handler._tag)
    end

    local workarea = handler.param.workarea

    region:union_rectangle( cairo.RectangleInt(workarea))

    handler.hierarchy:update({dpi=96}, handler.widget, workarea.width, workarea.height, region)

end

--TODO patch hierarchy to accept contextless drawing or dummy surface
local img = cairo.ImageSurface.create(cairo.Format.A1, 10000, 10000)

local function redraw(a, handler)
    if handler.active then
        local cr = cairo.Context(img)

        --Move to the work area
        local workarea = handler.param.workarea
        cr:translate(workarea.x, workarea.y)

        handler.hierarchy:draw({dpi=96},cr)
    end
end

-- Convert client into emulated widget
function internal.create_layout(t, l)

    local handler = {
        wrappers          = {},
        client_to_wrapper = {},
        client_to_index   = {},
        layout            = main_layout,
        widget            = l,
        swap              = internal.swap,
        active            = true,
        _tag              = t,
    }

    handler.hierarchy = hierarchy.new(
                                {dpi=96}       ,  -- context TODO
                                l              ,  -- widget
                                200            ,  -- width TODO
                                200            ,  -- height TODO
                                redraw         ,  -- redraw_callback
                                main_layout    ,  -- layout_callback
                                handler           -- callback_arg
                            )


    l._client_layout_handler = handler

    wake_up(handler)

    handler._tag:connect_signal("tagged", function(t,c)
        if handler.active then
            if not client.floating.get(c) then
                local wrapper = l_wrapper.wrap_client(internal, c)
                wrapper._handler = handler

                internal.insert_wrapper(handler, c, wrapper)
            end
        end
    end)

    handler._tag:connect_signal("untagged", function(t,c)
        if handler.active then
            local wrapper = handler.client_to_wrapper[c]

            internal.remove_wrapper(handler, c, wrapper)
        end
    end)

    t:connect_signal("property::selected", function(t)
        if t.selected then
            wake_up(handler)
        else
            suspend(handler)
        end
    end)

    t:connect_signal("property::layout", function(t)
        if tag.getproperty(t, "layout") ~= handler then
            suspend(handler)
        else
            wake_up(handler)
        end
    end)

    function handler.arrange(param)
        handler.param = param
        handler.hierarchy:_redraw()
    end

    return handler
end

-- Swap the client of 2 wrappers
function internal.swap(handler, client1, client2)
    local w1 = handler.client_to_wrapper[client1]
    local w2 = handler.client_to_wrapper[client2]

    handler.widget:swap(w1, w2, true)
end

local module = {}

-- Proxy some client/wibox properties
-- local function index(table, key)
--     if key == "mwfact" then
--         return tag.getmwfact(self._client)
--     elseif key == "opacity" then
--         return self._client.opacity
--     end
-- end

--- Register a new type of dynamic layout
-- @param name An unique name, duplicates are forbidden
-- @param base_layout The layout constructor function. When called, the first
--   paramater is the tag
--
-- The object returned from the base_layout need to comply with this interface:
--
-- **Required:**
--
-- * obj:add(widget) Add a new widget to the layout, widget._drawable will be
--   either the client or wibox being added
--
-- * obj:balance() Re-layout elements
--
-- * obj:remove(widget) Remove a widget
--
-- * obj:swap(widget1, widget2) Swap 2 widgets
--
-- * obj:layout(context, width, height) For each layout children, an entry in
--    a table. The entry must be a wibox.widget.base.place_widget_at(...) value
--
-- **Optional:**
--
-- * obj:split(...) TODO to be determined, a mode and an axis and a layout?
--
-- * obj:add_column(idx) and obj:remove_column(idx) Change the default number
--   of layout column (or, if applicable, rows). The default is 
--   `awful.tag.getncol(t)`
--
-- * obj:before_draw_children(context) TODO
--
-- * obj:after_draw_children(context) TODO
--
-- * obj.mouse_resize_handler(client, corner) Allow mouse resize
--
-- * obj:resize(widget) Resize a widget
--
-- If other arguments are provided, they will be passed to the base_layout
-- callback.
--
-- This system is compatible with most existing `wibox.layout`, therefor you
-- can do this:
--
-- @usage -- Align all clients on top of each other using wibox.layout.flex.vertical
--  awful.layout.suit.tile_clone = awful.layout.dynamic.register("vertical",
--      function (t, ...) return wibox.layout.flex.vertical() end)
function module.register(name, base_layout, ...)
    local generator = {name = name}
    local args = {...}

    setmetatable(generator, {__call = function(self, t )
        local l =  base_layout(t , unpack(args))

        local l_obj      = internal.create_layout(t, l)
        l_obj._type      = generator
        l_obj.name       = name
        l_obj.is_dynamic = true

        l_obj.mouse_resize_handler = l.mouse_resize_handler or resize.generic_mouse_resize_handler

        return l_obj
    end})

    return generator
end

return setmetatable(module, { __call = function(_, ...) return module.register(...) end })
