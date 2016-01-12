---------------------------------------------------------------------------
--- Allow dynamic layouts to be created using wibox.layout composition
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.layout.hierarchy
---------------------------------------------------------------------------

local capi = {client=client}
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

    wrapper:suspend()

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
            if self.client_to_index[c] then
                self.client_to_index[c]:wake_up()
                self.widget:add(self.client_to_index[c])
            else
                local wrapper = l_wrapper.wrap_client(internal, c)
                wrapper._handler = self

                internal.insert_wrapper(self, c, wrapper)
            end
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
                if handler.client_to_index[c] then
                    handler.client_to_index[c]:wake_up()
                    handler.widget:add(handler.client_to_index[c])
                else
                    local wrapper = l_wrapper.wrap_client(internal, c)
                    wrapper._handler = handler

                    internal.insert_wrapper(handler, c, wrapper)
                end
            end
        end
    end)

    handler._tag:connect_signal("untagged", function(t,c)
        if handler.active then
            local wrapper = handler.client_to_wrapper[c]

            if not wrapper then return end

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

        -- The wrapper handle useless gap, remove it from the workarea
        local gap = not handler._tag and 0 or tag.getgap(handler._tag)
        handler.param.workarea = {
            x      = handler.param.workarea.x      -   gap,
            y      = handler.param.workarea.y      -   gap,
            width  = handler.param.workarea.width  + 2*gap,
            height = handler.param.workarea.height + 2*gap,
        }

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

local function get_handler_and_wrapper(c)
    local t = nil
    for k,v in ipairs(c:tags()) do
        if v.selected then
            t = v
            break
        end
    end

    if not t then return end

    local handler = tag.getproperty(t, "layout")

    if not handler or not handler.is_dynamic then return end

    local wrapper = handler.client_to_wrapper[c]

    return handler, wrapper
end

capi.client.connect_signal("property::floating", function(c)
    local handler, wrapper = get_handler_and_wrapper(c)
    if not handler then return end

    local is_floating = client.floating.get(c)

    if not is_floating then
        if not wrapper then
            wrapper = l_wrapper.wrap_client(internal, c)
            wrapper._handler = handler
            internal.insert_wrapper(handler, c, wrapper)
        else
            wrapper:wake_up()
            handler.widget:add(wrapper, true)
        end
    elseif wrapper then
        internal.remove_wrapper(handler, c, wrapper)
        handler.widget:remove(wrapper, true)
    end

end)

capi.client.connect_signal("property::minimized",function(c)
    local handler, wrapper = get_handler_and_wrapper(c)
    if not handler then return end
    if client.floating.get(c) then return end

    --TODO support inserting it back where it was

    if c.minimized then
        if wrapper then
            internal.remove_wrapper(handler, c, wrapper)
        end
    else
        if not wrapper then
            wrapper = l_wrapper.wrap_client(internal, c)
            wrapper._handler = handler
            internal.insert_wrapper(handler, c, wrapper)
        else
            wrapper:wake_up()
            handler.widget:add(wrapper, true)
        end
    end
end)

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
