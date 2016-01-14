--- A stacked layout with an extra wibox to select the topmost client

local capi = {client = client}
local stack   = require( "awful.layout.dynamic.base_stack" )
local margins = require( "wibox.layout.margin"             )
local wibox   = require( "wibox"                           )
local beautiful = require( "beautiful" )

local fct = {}

local tabs = setmetatable({},{__mode="k"})
local connected,old_focus = false

local function focus_changed(c)
    local tab = tabs[c]
    if old_focus and tab ~= old_focus then
        old_focus:set_bg(beautiful.bg_normal)
        old_focus:set_fg(beautiful.fg_normal)
    end

    if tab then
        tab:set_bg(beautiful.bg_focus)
        tab:set_fg(beautiful.fg_focus)

        old_focus = tab
    end
end

local function create_tab(c)
    if tabs[c] then return tabs[c] end

    local ib = wibox.widget.imagebox(c.icon)
    local tb = wibox.widget.textbox(c.name)
    local l  = wibox.layout.fixed.horizontal(ib, tb)
    local bg = wibox.widget.background(l)
    bg._tb, bg._ib = tb, ib
    tabs[c] = bg

    bg:connect_signal("button::press",function(_,__,id,mod)
        capi.client.focus = c
        c:raise()
    end)

    if not connected then
        connected = true
        capi.client.connect_signal("focus", focus_changed)
        capi.client.connect_signal("property::name", function(c)
            local tab = tabs[c]
            if tab then
                tab._tb:set_text(c.name)
            end
        end)
    end

    if capi.client.focus == c then
        focus_changed(c)
    end

    return bg
end

local function before_draw_child(self, context, index, child, cr, width, height)
    if not self._wibox then
        self._wibox = wibox({})

        local flex = wibox.layout.flex.horizontal()

        --TODO overrdide add/remove to keep the "real" list
        --TODO allow modules to override the widget
        --TODO dragging the widget swap the group (how?)

        for k,v in ipairs(self._s:get_widgets()) do
            if v._client then
                flex:add(create_tab(v._client))
            end
        end

        self._wibox:set_widget(flex)
    end

    local matrix = cr:get_matrix()

    self._wibox.x = matrix.x0
    self._wibox.y = matrix.y0
    self._wibox.height = math.ceil(beautiful.get_font_height() * 1.5)
    self._wibox.width = width
    self._wibox.visible=true
end

local function suspend(self)
    self._wibox.visible = false
    self._s:suspend()
end

local function wake_up(self)
    self._wibox.visible = true
    self._s:wake_up()
end

local function ctr2(self, t)
    local s = stack(false)

    local m = margins(s)
    m._s    = s
    m:set_top(math.ceil(beautiful.get_font_height() * 1.5))
    m:set_widget(s)

    m.suspend = suspend
    m.wake_up = wake_up

    m.before_draw_child = before_draw_child

    -- "m" is a dumb proxy of "s", it only free the space for the tabbar
    if #fct == 0 then
        for k, f in pairs(s) do
            if type(f) == "function" and not m[k] then
                fct[k] = f
            end
        end
    end

    for name, func in pairs(fct) do
        m[name] = function(self, ...) return func(s,...) end
    end

    return m
end

return ctr2