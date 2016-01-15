---------------------------------------------------------------------------
--- Utilities required to resize a client wrapped in ratio layouts
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.layout.hierarchy
---------------------------------------------------------------------------

local util = require("awful.util")

local capi = {
    mouse        = mouse       ,
    client       = client      ,
    mousegrabber = mousegrabber,
}

local module = {}

-- 3x3 matrix of potential resize point
local corners3x3 = {{"top_left"   ,   "top"   , "top_right"   },
                    {"left"       ,    nil    , "right"       },
                    {"bottom_left",  "bottom" , "bottom_right"}}

-- 2x2 matrix of potential resize point, fallback when center is hit in the 3x3
local corners2x2 = {{"top_left"   ,            "top_right"   },
                    {"bottom_left",            "bottom_right"}}

-- Some parameters to correctly compute the final size
local map = {
    -- Corners
    top_left     = {p1= nil  , p2={1,1}, x_only=false, y_only=false},
    top_right    = {p1={0,1} , p2= nil , x_only=false, y_only=false},
    bottom_left  = {p1= nil  , p2={1,0}, x_only=false, y_only=false},
    bottom_right = {p1={0,0} , p2= nil , x_only=false, y_only=false},

    -- Sides
    left         = {p1= nil  , p2={1,1}, x_only=true , y_only=false},
    right        = {p1={0,0} , p2= nil , x_only=true , y_only=false},
    top          = {p1= nil  , p2={1,1}, x_only=false, y_only=true },
    bottom       = {p1={0,0} , p2= nil , x_only=false, y_only=true },
}

-- Convert a rectangle and matrix info into a point
local function rect_to_point(rect, corner_i, corner_j, n)
    return {
        x = rect.x + corner_i * math.floor(rect.width  / (n-1)),
        y = rect.y + corner_j * math.floor(rect.height / (n-1)),
    }
end

-- If the mouse is in the client rectangle (99% of the time), use presise math
local function move_to_corner(client)
    local pos = capi.mouse.coords()

    local c_geo = client:geometry()

    local corner_i, corner_j, n

    -- Use the product of 3 to get the closest point in a NxN matrix
    local function f(_n, mat, offset)
        n        = _n
        corner_i = -math.ceil( ( (c_geo.x - pos.x) * n) / c_geo.width  )
        corner_j = -math.ceil( ( (c_geo.y - pos.y) * n) / c_geo.height )
        return mat[corner_j + 1][corner_i + 1]
    end

    -- If the point is in the center, use the cloest corner
    local corner = f(3, corners3x3) or f(2, corners2x2)

    -- Transpose the corner back to the original size
    capi.mouse.coords(rect_to_point(c_geo, corner_i, corner_j , n))

    return corner
end

-- Convert 2 points into a rectangle
local function rect_from_point(p1x, p1y, p2x, p2y)
    return {
        x      = p1x,
        y      = p1y,
        width  = p2x - p1x,
        height = p2y - p1y,
    }
end

--- Resize, the client, ignore whatever "corner" is provided, it know better
function module.generic_mouse_resize_handler(client, corner, x, y, args)
    local args, corner = args or {}, move_to_corner(client)

    if args.init_callback then
        args.init_callback(client, geo, corner)
    end

    capi.mousegrabber.run(function (_mouse)
        -- Create a vector from top_left and one from bottom_right
        local p0 = {x = _mouse.x, y = _mouse.y}
        local geo     = client:geometry()

        -- Use p0 (mouse), p1 and p2 to create a rectangle
        local pts = map[corner]
        local p1  = pts.p1 and rect_to_point(geo, pts.p1[1], pts.p1[2], 2) or p0
        local p2  = pts.p2 and rect_to_point(geo, pts.p2[1], pts.p2[2], 2) or p0

        -- Create top_left and bottom_right points, convert to rectangle
        geo = rect_from_point(
            pts.y_only and geo.x      or math.min(p1.x, p2.x),
            pts.x_only and geo.y      or math.min(p1.y, p2.y),
            pts.y_only and geo.width  or math.max(p2.x, p1.x),
            pts.x_only and geo.height or math.max(p2.y, p1.y)
        )

        if args.move_callback then
            args.move_callback(client, geo, corner)
        end

        -- Quit when the button is released
        for k,v in pairs(_mouse.buttons) do
            if v then return true end
        end

        -- Notify the handler of the requested geometry
        -- This is done only when the final size is known. Previously, the
        -- resize was done each time the mouse moved, but this caused terminal
        -- applications to lose content. This behavior can be enabled again
        -- using the 3 args.callback. It can also be used to implement
        -- TWM like resize widget or display the width and height in a wibox
        client:emit_signal(
            "request::geometry", "mouse.resize", geo, {corner=corner}
        )

        if args.quit_callback then
            args.quit_callback(client, geo, corner)
        end

        return false
    end, "cross")
end

--- Loop the path between the client widget and the layout to find nodes
-- capable of resizing in both directions
local function ratio_lookup(handler, wrapper)
    local idx, parent, path = handler.widget:index(wrapper, true)
    local res = {}

    local full_path = util.table.join({parent}, path)

    for i=#full_path, 1, -1 do
        local w = full_path[i]
        if w.inc_ratio then
            res[w.dir] = res[w.dir] or {
                layout = w,
                widget = full_path[i-1] or wrapper
            }
        end
    end

    return res
end

--- Compute the new ratio before, for and after geo
local function compute_ratio(workarea, geo)
    local x_before = (geo.x - workarea.x) / workarea.width
    local x_self   = (geo.width         ) / workarea.width
    local x_after  = 1 - x_before - x_self
    local y_before = (geo.y - workarea.y) / workarea.height
    local y_self   = (geo.height        ) / workarea.height
    local y_after  = 1 - y_before - y_self

    return {
        x = { x_before, x_self, x_after },
        y = { y_before, y_self, y_after },
    }
end

--- If there is a ratio based layout somewhere, try to get all geometry updated
function module.update_ratio(handler, c, widget, geo)
    local ratio_wdgs = ratio_lookup(handler, widget)

    local ratio = compute_ratio(handler.param.workarea, geo)

    if ratio_wdgs.x then
        ratio_wdgs.x.layout:ajust_ratio(ratio_wdgs.x.widget, unpack(ratio.x))
    end
    if ratio_wdgs.y then
        ratio_wdgs.y.layout:ajust_ratio(ratio_wdgs.y.widget, unpack(ratio.y))
    end

    handler.widget:emit_signal("widget::redraw_needed")
end

capi.client.add_signal("request::geometry")

return module