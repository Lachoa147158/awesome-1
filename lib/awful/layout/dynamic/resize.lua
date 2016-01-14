local util = require("awful.util")

local capi =
{
    mouse        = mouse       ,
    client       = client      ,
    screen       = screen      ,
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

-- Delta modifier matrix
local mods = {
    -- Corners
    top_left     = {x = 1 , y =  1, width = -1, height = -1 },
    top_right    = {x = 1 , y = -1, width =  1, height = -1 },
    bottom_left  = {x = 1 , y =  0, width = -1, height =  1 },
    bottom_right = {x = 0 , y =  0, width =  1, height =  1 },

    -- Sides
    left         = {x = -1, y =   0, width =  1, height =  0 },
    right        = {x =  0, y =   0, width =  1, height =  0 },
    top          = {x =  0, y =  -1, width =  0, height =  1 },
    bottom       = {x =  0, y =   0, width =  0, height =  1 },
}

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

    print("\n\n\nCORNER", corner, corner_i, corner_j)

    -- Transpose the corner back to the original size
    capi.mouse.coords {
        x = c_geo.x + corner_i * math.floor(c_geo.width  / (n-1)),
        y = c_geo.y + corner_j * math.floor(c_geo.height / (n-1)),
    }

    return corner
end

--- Resize, the client, ignore whatever "corner" is provided, it know better
function module.generic_mouse_resize_handler(client, corner)
    local corner = move_to_corner(client)

    local button = nil
    local pos    = capi.mouse.coords()
    local modif  = mods[corner]

    capi.mousegrabber.run(function (_mouse)
        local dx, dy = _mouse.x - pos.x, _mouse.y - pos.y
        local geo = client:geometry()

        pos = {x = _mouse.x, y = _mouse.y}

        if dx ~= 0 or dy ~= 0 then
            client:emit_signal("request::geometry", "mouse.resize", {
                x      = geo.x      + (modif.x      * dx), --TODO complete the above table
                y      = geo.y      + (modif.y      * dy),
                width  = geo.width  + (modif.width  * dx),
                height = geo.height + (modif.height * dy),
            })
        end

        -- Quit when the button is released
        if not button then
            for k,v in pairs(_mouse.buttons) do
                if v then
                    button = k
                    break
                end
            end
        elseif button and not _mouse.buttons[button] then
            return false
        end

        return true
    end, "cross")
end

local function ratio_lookup(handler, wrapper)
    local idx, parent, path = handler.widget:index(wrapper, true)
    local res = {}

    local full_path = util.table.join({parent}, path)

    for i=#full_path, 1, -1 do
        local w = full_path[i]
        if w.inc_ratio then
            res[w.dir] = res[w.dir] or {layout = w, widget = full_path[i-1] or wrapper}
        end
    end

    return res
end

local function get_delta()
    --TODO
end

local function compute_ration()
    --TODO
end

--- If there is a ratio based layout somewhere, try to get all geometry updated
function module.update_ratio(handler, widget, geo)
    local ratio_wdgs = ratio_lookup(handler, widget)

    if ratio_wdgs.x then
        ratio_wdgs.x.layout:inc_ratio(ratio_wdgs.x.widget, -0.01)
    end
    if ratio_wdgs.y then
        ratio_wdgs.y.layout:inc_ratio(ratio_wdgs.y.widget, -0.01)
    end
    handler.widget:emit_signal("widget::redraw_needed")
    --I will do that later, it should not be an issue
end

capi.client.add_signal("request::geometry")

return module