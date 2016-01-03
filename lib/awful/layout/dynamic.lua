---------------------------------------------------------------------------
--- Allow dynamic layouts to be created using wibox.layout composition
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.layout.hierarchy
---------------------------------------------------------------------------

local internal = {}

local tag       = require( "awful.tag"       )
local hierarchy = require( "wibox.hierarchy" )
local object    = require( "gears.object"    )
local aw_layout = require( "awful.layout"    )
local cairo     = require( "lgi"             ).cairo

local function insert_wrapper(handler, c, wrapper)
    local pos = #handler.wrappers+1
    handler.wrappers         [ pos ] = wrapper
    handler.client_to_wrapper[ c   ] = wrapper
    handler.client_to_index  [ c   ] = pos
end

local function remove_wrapper(handler, c, wrapper)
    table.remove(handler.wrappers, handler.client_to_index[c])
    handler.client_to_index[c] = nil
end

local function add_wrapper_to_layout(layout, wrapper)
    layout:add(wrapper)
end

local function remove_wrapper_from_layout(layout, wrapper)
    layout:remove(wrapper)
end

-- Equivalent of wibox.widget.draw, simply move and resize the client
local function draw(self, context, cr, width, height)
    local c = self._client

    local matrix = cr:get_matrix()

    c:geometry {
        x      = matrix.x0,
        y      = matrix.y0,
        width  = width,
        height = height
    }
end

local function before_draw_children(...)
    
end

-- This could eventually be used to move an overlay wibox
-- on top of the top of the client or something or add
-- a resize handle
local function after_draw_children(...)

end

-- The layout could be used to move tilebar elements or add overlay wiboxes
local function layout(...)

end

-- Create the wrapper
-- @param c_w A client or a wibox
function internal.wrap_client(c_w)
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


    c_w:connect_signal("property::minimized", function()
        local handler = wrapper._handler
        --TODO the widget.visible attribute is not implemented by layouts
        --TODO support inserting it back where it was
        if c_w.minimized then
            remove_wrapper(handler, c_w, wrapper)
            remove_wrapper_from_layout(handler.widget, wrapper)
        else
            insert_wrapper(handler, c_w, wrapper)
            add_wrapper_to_layout(handler.widget, wrapper)
        end


    end)

    c_w:connect_signal("swapped",function(self,other_c,is_source)
        if is_source then
            if wrapper._handler then
                wrapper._handler:swap(self, other_c)
                wrapper._handler.widget:emit_signal("widget::redraw_needed")
            end
        end
    end)

    return wrapper
end
bob =12

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
    local cr = cairo.Context(img)

    --Move to the work area
    local workarea = handler.param.workarea
    cr:translate(workarea.x, workarea.y)

    handler.hierarchy:draw({dpi=96},cr)
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
    }

    handler.hierarchy = hierarchy.new(
                                {dpi=96}       ,  -- context TODO
                                l              ,  -- widget
                                200            ,  -- width TODO
                                200            ,  -- height TODO
                                redraw         ,  -- redraw_callback
                                main_layout    ,  -- layout_callback
                                handler           -- callback_arg
                            ),

    t:connect_signal("tagged", function(t,c)
        local wrapper = internal.wrap_client(c)
        wrapper._handler = handler

        insert_wrapper(handler, c, wrapper)
        add_wrapper_to_layout(l, wrapper)
    end)

    t:connect_signal("untagged", function(t,c)
        local wrapper = handler.client_to_wrapper[c]

        remove_wrapper(handler, c, wrapper)

        remove_wrapper_from_layout(l, wrapper)

    end)

    for k,c in ipairs(t:clients()) do
        local wrapper = internal.wrap_client(c)
        wrapper._handler = handler
        insert_wrapper(handler, c, wrapper)

        add_wrapper_to_layout(l, wrapper)
    end

    l._client_layout_handler = handler

    function handler.arrange(param)
        handler.param = param
        handler.hierarchy:_redraw()
    end

    handler._tag = t

    return handler
end

-- Swap the client of 2 wrappers
function internal.swap(handler, client1, client2)
    local w1 = handler.client_to_wrapper[client1]
    local w2 = handler.client_to_wrapper[client2]

    handler.widget:swap(w1, w2)
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
-- * obj:before_draw_children(context) TODO
--
-- * obj:after_draw_children(context) TODO
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

        return l_obj
    end})

    return generator
end

return setmetatable(module, { __call = function(_, ...) return module.register(...) end })
