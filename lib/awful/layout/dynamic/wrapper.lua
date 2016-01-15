---------------------------------------------------------------------------
--- A compatibility wrapper around clients to conform to the widget API
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.layout.hierarchy
---------------------------------------------------------------------------

local object      = require( "gears.object"                     )
local base_layout = require( "awful.layout.dynamic.base_layout" )
local client      = require( "awful.client"                     )
local tag         = require( "awful.tag"                        )
local stack_l     = require( "awful.layout.dynamic.tabbed"      )
local resize      = require( "awful.layout.dynamic.resize"      )

local module = {}

-- Callback called when a split point is activated
local function split(wrapper, context, direction)
    if not context.client_widget or not context.source_root then return end
    local t = (direction == "left" or direction == "right")

    local l = t and base_layout.horizontal() or base_layout.vertical()

    local f = context.source_root._remove or context.source_root.remove
    f(context.source_root, context.client_widget, true)

    t = (direction == "left" or direction == "top")
    l:add(t and context.client_widget or wrapper)
    l:add(t and wrapper or context.client_widget)

    context.source_root:replace(wrapper, l, true)

    context.source_root:raise(context.client_widget)

    context.source_root:emit_signal("widget::redraw_needed")
end

-- Callback called when a stack point is activated
local function stack(wrapper, context)

    local f = context.source_root._remove or context.source_root.remove
    f(context.source_root, context.client_widget, true)

    local l = stack_l()

    l:add(context.client_widget)
    l:add(wrapper              )


    context.source_root:replace(wrapper, l, true)

    context.source_root:emit_signal("widget::redraw_needed")

    l:raise(context.client_widget)
end

--- Allow the wrapper to be splited in each of the 4 directions
-- @param self A wrapper
-- @param[opt] A modified geometry preferred by the handler
--
-- This function can be overloaded to add new points
--
-- @return A table of potential split points
function module.splitting_points(self, geometry)
    geometry = geometry or (self._client and self._client:geometry())

    -- Add a group of split point for the UX handler
    return {{
        x      = geometry.x + geometry.width  / 2,
        y      = geometry.y + geometry.height / 2,
        type   = "internal"                      ,
        client = self._client                 ,
        points = {
            {
                direction = "left",
                callback  = function(_, context) split(self, context, "left"  ) end
            },
            {
                direction = "right",
                callback  = function(_, context) split(self, context, "right" ) end
            },
            {
                direction = "top",
                callback  = function(_, context) split(self, context, "top"   ) end
            },
            {
                direction = "bottom",
                callback  = function(_, context) split(self, context, "bottom") end
            },
            {
                direction = "stack",
                callback  = function(_, context) stack(self, context          ) end
            }
        }
    }}
end

-- Equivalent of wibox.widget.draw, simply move and resize the client
local function draw(self, context, cr, width, height)
    local c = self._client

    local matrix = cr:get_matrix()

    local gap = (not self._handler._tag and 0 or tag.getgap(self._handler._tag))

    -- Remove the border and gap from the final size
    width  = width  - 2*c.border_width - gap
    height = height - 2*c.border_width - gap

    -- I don't know what to do if this happen, anybody have a better idea?
    if width <= 0 or height <= 0 then
        c.minimzed = true
        return
    end

    c:geometry {
        x      = matrix.x0 + gap,
        y      = matrix.y0 + gap,
        width  = width          ,
        height = height         ,
    }
end

--- Callback when a new geometry is requested
local function on_geometry(wrapper, c, reasons, geo, hints)
    local handler = wrapper._handler
    if handler.active  and reasons == "mouse.resize" then
        if handler.widget.resize then
            handler.widget:resize(wrapper, geo)
        else
            resize.update_ratio(handler, c, wrapper, geo, hints)
        end
    end
end

--- Callback when the client is raised
local function on_raise(wrapper, c)
    if wrapper._handler.active and wrapper._handler.widget.raise then
        wrapper._handler.widget:raise(wrapper, true)
    end
end

--- Callback when two client indices are swapped
local function on_swap(wrapper, self,other_c,is_source)
    if wrapper._handler.active and is_source then
        if wrapper._handler then
            wrapper._handler:swap(self, other_c, true)
            wrapper._handler.widget:emit_signal("widget::redraw_needed")
        end
    end
end

--- Avoid flickering by disconnecting signals when the wrapper is not in use
local function suspend(wrapper)
    wrapper._client:disconnect_signal("request::geometry"  , wrapper.on_geometry )
    wrapper._client:disconnect_signal("swapped"            , wrapper.on_swap     )
    wrapper._client:disconnect_signal("raised"             , wrapper.on_raise    )
end

--- Re-connect the signals when the wrapper is activated
local function wake_up(wrapper)
    wrapper._client:connect_signal("request::geometry"  , wrapper.on_geometry )
    wrapper._client:connect_signal("swapped"            , wrapper.on_swap     )
    wrapper._client:connect_signal("raised"             , wrapper.on_raise    )
end

-- Create the wrapper
-- @param c_w A client or a wibox
local function wrap_client(c_w)
    local wrapper = object()

    wrapper:add_signal("widget::redraw_needed")
    wrapper:add_signal("widget::layout_changed")

    wrapper._client          = c_w
    wrapper.draw             = draw
    wrapper.visible          = true
    wrapper._widget_caches   = {}
    wrapper.splitting_points = module.splitting_points
    wrapper.suspend          = suspend
    wrapper.wake_up          = wake_up

    wrapper.on_geometry = function( c, reasons, geo       ) on_geometry(wrapper, c, reasons, geo       ) end
    wrapper.on_swap     = function( self, other_c, is_src ) on_swap    (wrapper, self, other_c, is_src ) end
    wrapper.on_raise    = function( c                     ) on_raise   (wrapper, c                     ) end

    wake_up(wrapper)

    return wrapper
end

return setmetatable(module, {__call = function(_,...) return wrap_client(...) end})