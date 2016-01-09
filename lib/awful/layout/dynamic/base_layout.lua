--- This layout extend wibox.layout.radio and add client specific features such
-- as splitting

local origin = require( "wibox.layout.ratio" )

local module = {}

local function split_callback(wrapper, context, pos)
    if not context.client_widget or not context.source_root then return end

    --TODO, currently, it always add new columns, but this should required
    -- only for top level  (children of context.source_root) otherwise, it create
    -- a lot of "noise" splitpoints, but it is cool for testing!
    local new_col = wrapper.dir == "x" and module.vertical() or module.horizontal()

    context.source_root:remove(context.client_widget, true)

    if pos == "first" then
        wrapper:insert(1, new_col)
    else
        local f = (wrapper._add or wrapper.add)
        f(wrapper,new_col)
    end

    new_col:add(context.client_widget)
    wrapper:emit_signal("widget::redraw_needed")
end

local function splitting_points(wrapper, geometry)
    local ret = {}

    if wrapper.dir == "x" then
        table.insert(ret, {
            x         = geometry.x,
            y         = geometry.y + geometry.height/2    ,
            direction = "left",
            type      = "sides",
            callback  = function(s,c) split_callback(wrapper, c, "first") end
        })
        table.insert(ret, {
            x         = geometry.x + geometry.width,
            y         = geometry.y + geometry.height/2    ,
            direction = "right",
            type      = "sides",
            callback  = function(s,c) split_callback(wrapper, c, "last") end
        })
    else
        table.insert(ret, {
            x         = geometry.x + geometry.width/2,
            y         = geometry.y ,
            direction = "top",
            type      = "sides",
            callback  = function(s,c) split_callback(wrapper, c, "first") end
        })
        table.insert(ret, {
            x         = geometry.x + geometry.width/2,
            y         = geometry.y + geometry.height ,
            direction = "bottom",
            type      = "sides",
            callback  = function(s,c) split_callback(wrapper, c, "last") end
        })
    end

    return ret
end

local function get_layout(dir, widget1, ...)
    local ret = origin[dir](widget1, ...)

    ret.splitting_points = splitting_points

    ret.fill_space = nil

    return ret
end

--- Returns a new horizontal ratio layout. A ratio layout shares the available space
-- equally among all widgets. Widgets can be added via :add(widget).
-- @tparam widget ... Widgets that should be added to the layout.
function module.horizontal(...)
    return get_layout("horizontal", ...)
end

--- Returns a new vertical ratio layout. A ratio layout shares the available space
-- equally among all widgets. Widgets can be added via :add(widget).
-- @tparam widget ... Widgets that should be added to the layout.
function module.vertical(...)
    return get_layout("vertical", ...)
end

return module