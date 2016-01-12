--- Replace the stateless tile

local dynamic = require( "awful.layout.dynamic.base" )
local wibox   = require( "wibox"                     )
local tag     = require( "awful.tag"                 )
local util    = require( "awful.util"                )

--- As all widgets are on the top of eachother, it is necessary to add the groups
-- elsewhere
local function splitting_points(self, geometry)
    local pts = {}
    --HACK
    local top_level_widgets = self:get_widgets()

    for k,w in ipairs(top_level_widgets) do
        if w._client and w.splitting_points then
            local pt = w:splitting_points({x=1,y=1,width=1,height=1})
            for k2,v2 in ipairs(pt) do
                if v2.type  == "internal" then
                    table.insert(pts, v2)
                end
            end
        end
    end

    local y, dx = geometry.y+geometry.height*0.75, geometry.width / (#pts+1)
    local x = dx

    for k,v in ipairs(pts) do
        v.y = y
        v.x = x
        v.label = v.client and v.client.name or "N/A"

        -- Raise both widgets
        local cb = v.callback
        v.callback = function(w, context)
            cb(w, context)
            if v.widget then
                self:raise(context.client_widget)
                self:raise(v.widget)
            end
        end

        x = x + dx
    end

    return pts
end
local base_layout = require( "awful.layout.dynamic.base_layout" )

--- When a tag is not visible, it must stop trying to mess with the content
local function wake_up(self)
    if self.is_woken_up then return end

    self.is_woken_up = true
end

local function suspend(self)
    if not self.is_woken_up then return end

    self.is_woken_up = false
end

-- Not necessary for "dump" max layout, but if the user add some splitter
-- then the whole sub-layout have to be raised too
local function raise(self, widget)
    local all_widgets = self:get_widgets(true)

    -- If widget is not a top level of self, then get all of its siblings
    local idx, l = self:index(widget, true)
    while l ~= self do
        old_l = l
        idx, l = self:index(l, true)
    end

    local siblings = util.table.join({widget},(old_l and old_l.get_widgets and old_l:get_widgets(true)) or {})

    local by_c = {}

    for k, w in ipairs(all_widgets) do
        if w._client then
            by_c[w._client] = w
        end
    end

    for k, w in ipairs(siblings) do
        if w._client then
            by_c[w._client] = nil
        end
    end

    self:_raise(widget, true)

    for c, w in pairs(by_c) do
        c:lower()
    end
end

local function add(self, widget)
    self:_add (widget)
    self:raise(widget)
end

local function ctr(t, fullscreen)
    -- Decide the right layout
    local main_layout = wibox.layout.stack()
    main_layout:set_display_top_only(true)
    main_layout.suspend = suspend
    main_layout.wake_up = wake_up
    main_layout._raise  = main_layout.raise
    main_layout. raise  = raise
    main_layout._add    = main_layout.add
    main_layout.add     = add
    main_layout.splitting_points = splitting_points

    return main_layout
end

local module = dynamic.register("max", function(t) return ctr(t, false) end)

module.fullscreen = dynamic.register("fullscreen", function(t) return ctr(t, true) end)

return module