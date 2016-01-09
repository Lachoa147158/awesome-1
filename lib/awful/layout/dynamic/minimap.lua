--- Generate a minimap of all the elements in the layer

local module = {}

local function get_rects(handler)
    local ret = {}

    --Move to the work area
    local workarea = handler.param.workarea

    local add_x, add_y = workarea.x, workarea.y

    local function handle_hierarchy(h)
        local widget = h:get_widget()
        if widget._client or widget.draw == draw then
            local matrix = h:get_matrix_to_device()
            local x, y = matrix:transform_point(0, 0)
            local width, height = h:get_size()
            table.insert(ret, {
                x      = x + add_x,
                y      = y + add_y,
                width  = width,
                height = height,
                client = widget._client
            })
        end

        for _, child in ipairs(h:get_children()) do
            handle_hierarchy(child)
        end
    end

    handle_hierarchy(handler.hierarchy)

    return ret, workarea.width, workarea.height
end

local function scale_rects(rects, wa_w, wa_h, res_w, res_h)
    --TODO
end

local function minimap(handler, width, height)
    local rects, wa_w, wa_h = get_rects(handler)

    for k, rect in ipairs(rects) do
        print("HELLO", rect.x, rect.x, rect.width, rect.height)
    end

    print("\n\nGENERATING MINIMAP!!!!")
end

return setmetatable(module, { __call = function(_, ...) return minimap(...) end })