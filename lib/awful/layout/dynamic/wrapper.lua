--- A widget compatibility wrapper around drawables
-- Also monitor content for changes and add features such as useless gap

local object    = require( "gears.object"               )
local base_layout = require( "awful.layout.dynamic.base_layout" )
local client    = require( "awful.client"               )
local tag       = require( "awful.tag"                  )

local internal = {}

local function split(wrapper, context, direction)
    if not context.client_widget or not context.source_root then return end
    local t = (direction == "left" or direction == "right")

    local l = t and base_layout.horizontal() or base_layout.vertical()

    local f = context.source_root._remove or context.source_root.remove
    f(context.source_root, context.client_widget, true)

    t = (direction == "left" or direction == "top")
    l:add(t and context.client_widget or wrapper)
    l:add(t and wrapper or context.client_widget)

    local idx = context.source_root:index(wrapper, true)

    context.source_root:replace(wrapper, l, true)

    context.source_root:emit_signal("widget::redraw_needed")
end

--- Allow the wrapper to be splited in each of the 4 directions
local function splitting_points(wrapper, geometry)
    --TODO move the wrapper to its own module
    local ret = {}

    -- Add a group of split point for the UX handler
    table.insert(ret, {
        x      = geometry.x + geometry.width  / 2,
        y      = geometry.y + geometry.height / 2,
        type   = "internal"                      ,
        client = wrapper._client                 ,
        points = {
            {
                direction = "left",
                callback  = function(self, context) split(wrapper, context, "left") end
            },
            {
                direction = "right",
                callback  = function(self, context) split(wrapper, context, "right") end
            },
            {
                direction = "top",
                callback  = function(self, context) split(wrapper, context, "top") end
            },
            {
                direction = "bottom",
                callback  = function(self, context) split(wrapper, context, "bottom") end
            }
        }
    })

    return ret
end

--- The layout could be used to move tilebar elements or add overlay wiboxes
local function layout(...)

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

local function before_draw_children(...)
    
end

-- This could eventually be used to move an overlay wibox
-- on top of the top of the client or something or add
-- a resize handle
local function after_draw_children(...)

end

local function on_geometry(private,  wrapper, c, reasons, geo)
    local handler = wrapper._handler
    if handler.active  and reasons == "mouse.resize" then
        if handler.widget.resize then
            handler.widget:resize(wrapper, geo)
        else
            resize.update_ratio(handler.hierarchy, wrapper, geo)
        end
    end
end

local function on_focus(private,  wrapper, c)

end

local function on_raise(private, wrapper, c)
    if wrapper._handler.active and wrapper._handler.widget.raise then
        wrapper._handler.widget:raise(wrapper, true)
    end
end

local function on_swap(private,  wrapper, self,other_c,is_source)
    if wrapper._handler.active and is_source then
        if wrapper._handler then
            wrapper._handler:swap(self, other_c, true)
            wrapper._handler.widget:emit_signal("widget::redraw_needed")
        end
    end
end

local function suspend(wrapper)
    wrapper._client:disconnect_signal("request::geometry"  , wrapper.on_geometry )
    wrapper._client:disconnect_signal("swapped"            , wrapper.on_swap     )
    wrapper._client:disconnect_signal("focus"              , wrapper.on_focus    )
    wrapper._client:disconnect_signal("raised"             , wrapper.on_raise    )
end

local function wake_up(wrapper)
    wrapper._client:connect_signal("request::geometry"  , wrapper.on_geometry )
    wrapper._client:connect_signal("swapped"            , wrapper.on_swap     )
    wrapper._client:connect_signal("focus"              , wrapper.on_focus    )
    wrapper._client:connect_signal("raised"             , wrapper.on_raise    )
end

-- Create the wrapper
-- @param c_w A client or a wibox
function internal.wrap_client(private, c_w)
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
    wrapper.suspend              = suspend
    wrapper.wake_up              = wake_up

    wrapper.on_geometry = function(c, reasons, geo) on_geometry(private, wrapper, c, reasons, geo) end
    wrapper.on_swap     = function(self,other_c,is_source) on_swap(private, wrapper, self,other_c,is_source) end
    wrapper.on_focus    = function(c) on_focus(private, wrapper, c) end
    wrapper.on_raise    = function(c) on_raise(private, wrapper, c) end

    wake_up(wrapper)

    return wrapper
end

return internal