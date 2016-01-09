--- Replace the stateless fair.
--
-- This is not a perfect clone, as the stateful property of this layout
-- allow to minimize the number of clients being moved. If a splot of left
-- empty, then it will be used next time a client is added rather than
-- "pop" a client from the next column/row and move everything. This is
-- intended, if you really wish to see the old behavior, a new layout will
-- be created.
--
-- This version also support resizing, the older one did not

local dynamic = require("awful.layout.dynamic.base")
local wibox = require("wibox")
local base_layout = require( "awful.layout.dynamic.base_layout" )
local tag = require("awful.tag")


local function add(self, widget)
    if not widget then return end

    local lowest_idx    = -1
    local highest_count = 0
    local lowest_count  = 9999

    for i = 1, #self._cols do
        local col = self._cols[i]
        local count = col:get_children_count()

        if count < lowest_count then
            lowest_idx   = i
            lowest_count = count
        end

        lowest_count  = count < lowest_count  and count or lowest_count
        highest_count = count > highest_count and count or highest_count

        if col:get_children_count() > highest_count then
        end
    end

    if highest_count == 0 or (lowest_count == highest_count and highest_count <= #self._cols) then
        -- Add to the first existing row
        self._cols[1]:add(widget)
    elseif lowest_count == highest_count then
        -- Add a row
        local l = self._col_layout()
        table.insert(self._cols, l)
        self:_add(l)
    elseif lowest_idx ~= -1 then
        self._cols[lowest_idx]:add(widget)
    else
        print("\n\n\n\nOOPS")
    end
end

local function ctr(t, direction)
    local main_layout = base_layout[
        (direction == "left" or direction == "right")
            and "horizontal" or "vertical"
    ]()

    main_layout._col_layout = base_layout[
        (direction == "left" or direction == "right")
            and "vertical" or "horizontal"
    ]

    -- Add new master column
    function main_layout:add_column(idx)
        
    end

    function main_layout:remove_column(idx)
        
    end

    -- Using .widgets could create issue if external code decide to add some
    -- wibox
    main_layout._cols = {}

    local l = main_layout._col_layout()
    table.insert(main_layout._cols, l)
    main_layout:add(l)

    main_layout._add = main_layout.add

    main_layout.add    = add

    return main_layout
end

local module = dynamic.register("fair", function(t) return ctr(t, "right") end)

module.horizontal   = dynamic.register("fairh",   function(t) return ctr(t, "fairh"  ) end)

return module