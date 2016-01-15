---------------------------------------------------------------------------
--- Dynamic version of the fair layout.
-- This version emulate the stateless one, but try to maximize the space when
-- adding a new slave client.
--
--     1 client        2 clients        3 clients        4 clients
--  |-----------|    |-----|-----|    |-------|---|    |-------|---|
--  |           |    |     |     |    |       |1/3|    |       |   |
--  |           |    |     |     |    |       |   |    |       |   |
--  |           |    | 1/2 | 1/2 |    | 2/3   |---|    |-------|---|
--  |           |    |     |     |    |       |1/3|    |       |   |
--  |___________|    |_____|_____|    |_______|___|    |_______|___|
--
--    5 clients
--  |-------|---|
--  |       |   |
--  |       |---|
--  |       |   |
--  |-------|---|
--  |_______|___|
--

-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.layout.dynamic.suit.corner
---------------------------------------------------------------------------


local dynamic = require("awful.layout.dynamic.base")
local wibox   = require("wibox")
local tag     = require("awful.tag")
local base_layout = require( "awful.layout.dynamic.base_layout" )

--- Support 'n' column and 'm' number of master per column
local function add(self, widget)
    if not widget then return end

    if self._main:get_children_count() == 0 then
        self._main:add(widget)
    else
        -- The main will have to be replaced TODO
        if self._col2:get_children_count() < 3 then
            self._col2:add(widget)
        else
            self._bottom:add(widget)
        end
    end
    self:emit_signal("widget::layout_changed")
    self:emit_signal("widget::redraw_needed")
end

local function ctr(t, direction)
    local main_layout = base_layout.horizontal()

    -- Add new master column
    function main_layout:add_column(idx)
        
    end

    function main_layout:remove_column(idx)
        
    end

    -- Using .widgets could create issue if external code decide to add some
    -- wibox
    main_layout._cols = {}

    main_layout._ncol = tag.getncol(t)

    main_layout._col1   = base_layout.vertical()
    main_layout._col2   = base_layout.vertical()
    main_layout._main   = base_layout.vertical()
    main_layout._bottom = base_layout.horizontal()

    main_layout:add(main_layout._col1)
    main_layout:add(main_layout._col2)

    main_layout._col1:add(main_layout._main)
    main_layout._col1:add(main_layout._bottom)

    main_layout._nmaster = tag.getnmaster(t)

    main_layout.add    = add

    return main_layout
end

-- FIXME IDEA, I could also use the rotation widget

local module = dynamic.register("corner", function(t) return ctr(t, "right") end)

return module