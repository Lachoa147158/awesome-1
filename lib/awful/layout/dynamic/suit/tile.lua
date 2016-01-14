--- Replace the stateless tile

local dynamic = require( "awful.layout.dynamic.base" )
local wibox   = require( "wibox"                     )
local tag     = require( "awful.tag"                 )
local util    = require( "awful.util"                )
local base_layout = require( "awful.layout.dynamic.base_layout" )

-- Add some columns
local function init_col(self)

    -- This can change during initialization, but before the tag is selected
    self._mwfact  =  1   /   tag.getmwfact (self._tag)
    self._ncol    = math.max(tag.getncol   (self._tag), 1)
    self._nmaster = math.max(tag.getnmaster(self._tag), 1)

    if #self._cols_priority == 0 then

        -- Create the master column
        self:add_column()

        -- Apply the default width factor to the master
        self._cols_priority[1].mwfact = self._mwfact
    end
end

--- When a tag is not visible, it must stop trying to mess with the content
local function wake_up(self)
    if self.is_woken_up then return end

    -- If the number of column changed while inactive, this layout doesn't care.
    -- It has its own state, so it only act on the delta while visible
    self._ncol    =   tag.getncol   (self._tag)
    self._mwfact  = 1/tag.getmwfact (self._tag)
    self._nmaster =   tag.getnmaster(self._tag)

    -- Connect the signals
    self._tag:connect_signal("property::mwfact" , self._conn_mwfact )
    self._tag:connect_signal("property::ncol"   , self._conn_ncol   )
    self._tag:connect_signal("property::nmaster", self._conn_nmaster)

    self.is_woken_up = true

    if self._wake_up then
        self:_wake_up()
    end
end

local function suspend(self)
    if not self.is_woken_up then
        return
    end

    -- Disconnect the signals
    self._tag:disconnect_signal("property::mwfact" , self._conn_mwfact )
    self._tag:disconnect_signal("property::ncol"   , self._conn_ncol   )
    self._tag:disconnect_signal("property::nmaster", self._conn_nmaster)

    self.is_woken_up = false

    if self._suspend then
        self:_suspend()
    end
end

-- Clean empty columns
local function remove_empty_columns(self)
    for k, v in ipairs(self._cols_priority) do
        if v:get_children_count() == 0 then
            self:remove_column()
        end
    end
end

--- When the number of column change, re-balance the elements
local function balance(self, additional_widgets)
    local elems = {}

    -- Get only the top level, this will preserve tabs and manual split points
    for k, v in ipairs(self._cols_priority) do
        util.table.merge(elems, v:get_widgets())
        v:reset()
    end

    util.table.merge(elems, additional_widgets or {})

    for k,v in ipairs(elems) do
        self:add(v)
    end

    remove_empty_columns(self)
end

--- Support 'n' column and 'm' number of master per column
local function add(self, widget)
    if not widget then return end

    -- By default, there is no column, so nowhere to add the widget, fix this
    init_col(self)

    -- Make sure there is enough masters
    if self._cols_priority[1]:get_children_count() < self._nmaster then
        self._cols_priority[1]:add(widget)
        return
    elseif #self._cols_priority == 1 then
        self:add_column()
    end

    -- For legacy reason, the new clients are added as primary master
    -- Technically, I should foreach all masters and push them, but
    -- until someone complain, lets do something a little bit simpler
    local to_pop = self._cols_priority[1]:get_widgets()[1]
    if to_pop then
        self:replace(to_pop, widget, true)
        widget = to_pop
    end

    local candidate_i, candidate_c = 0, 999

    -- Get the column with the least members, this is a break from the old
    -- behavior, but I think it make sense, as it optimize space
    for i = 2, math.max(#self._cols_priority, self._ncol) do
        local col = self._cols_priority[i]

        -- Create new columns on demand, nothing can have less members than a new col
        if not col then
            self:add_column()
            candidate_i = #self._cols_priority
            break
        end

        local count = col:get_children_count()
        if count <= candidate_c then
            candidate_c = count
            candidate_i = i
        end
    end

    self._cols_priority[candidate_i]:add(widget)
end

--- Remove a widget
local function remove(self, widget)
    local idx, parent, path = self:index(widget, true)

    -- Avoid and infinite loop
    local f = parent == self and parent._remove or parent.remove
    local ret = f(parent, widget)

    -- A master is required
    if self._cols_priority[1]:get_children_count() == 0 then
        self:balance()
    elseif #path < 3 then
        -- Indicate a column might be empty
        remove_empty_columns(self)
    end

    return ret
end

--- Add a new column
local function add_column(main_layout, idx)
    idx = idx or #main_layout._cols + 1
    local l = main_layout._col_layout()
    table.insert(main_layout._cols, idx, l)
    main_layout:_add(l)

    if main_layout._primary_col > 0 then
        table.insert(main_layout._cols_priority,l)
    else
        table.insert(main_layout._cols_priority, 1, l)
    end

    return l
end

-- Remove a column
local function remove_column(main_layout, idx)
    idx = idx or #main_layout._cols
    local wdg = main_layout._cols[idx]

    if main_layout._primary_col > 0 then
        table.remove(main_layout._cols_priority, idx)
    else
        table.remove(main_layout._cols_priority, 1) --TODO wrong
    end

    main_layout._cols[idx] = nil

    main_layout:remove(wdg, true)

    return wdg:get_widgets()
end

-- React when the number of column changes
local function col_count_changed(self, t)
    local diff = tag.getncol(t) - self._ncol

    if diff > 0 then
        for i=1, diff do
            self:add_column()
        end

        self:balance()
    elseif diff < 0 then
        local orphans = {}

        for i=1, -diff do
            util.table.merge(orphans, self:remove_column())
        end

        self:balance(orphans)
    end

    self._ncol = tag.getncol(t)
end

-- Widget factor changed
local function wfact_changed(self, t)
    local diff = (tag.getmwfact(t) - self._mwfact) * 2
    local master = self._cols_priority[1]

    self._mwfact = (1/tag.getmwfact(t))

    master.mwfact = self._mwfact

    self:emit_signal("widget::layout_changed")
end

-- The number of master clients changed
local function nmaster_changed(self, t)
    local diff = tag.getnmaster(t) - self._nmaster

    self._nmaster = tag.getnmaster(t)

    self:balance()
end

local function ctr(t, direction)
    -- Decide the right layout
    local main_layout = base_layout[
        (direction == "left" or direction == "right")
            and "horizontal" or "vertical"
    ]()

    main_layout._col_layout = base_layout[
        (direction == "left" or direction == "right")
            and "vertical" or "horizontal"
    ]

    -- Declare the signal handlers
    main_layout._conn_mwfact  = function(t) wfact_changed    (main_layout, t) end
    main_layout._conn_ncol    = function(t) col_count_changed(main_layout, t) end
    main_layout._conn_nmaster = function(t) nmaster_changed  (main_layout, t) end

    -- Cache
    main_layout._cols          = {}
    main_layout._cols_priority = {}
    main_layout._primary_col   = (direction == "right" or direction == "bottom") and 1 or -1
    main_layout._add           = main_layout.add
    main_layout._remove        = main_layout.remove
    main_layout._tag           = t
    main_layout._wake_up       = main_layout.wake_up
    main_layout._suspend       = main_layout.suspend

    -- Methods
    main_layout.add            = add
    main_layout.remove         = remove
    main_layout.balance        = balance
    main_layout.wake_up        = wake_up
    main_layout.suspend        = suspend
    main_layout.remove_column  = remove_column
    main_layout.add_column     = add_column

    return main_layout
end

-- FIXME IDEA, I could also use the rotation widget

local module = dynamic.register("tile", function(t) return ctr(t, "right") end)

module.left   = dynamic.register("tileleft",   function(t) return ctr(t, "left"  ) end)
module.top    = dynamic.register("tiletop",    function(t) return ctr(t, "top"   ) end)
module.bottom = dynamic.register("tilebottom", function(t) return ctr(t, "bottom") end)

return module