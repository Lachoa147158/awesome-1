---------------------------------------------------------------------------
--- Implements EWMH requests handling.
--
-- @author Julien Danjou &lt;julien@danjou.info&gt;
-- @copyright 2009 Julien Danjou
-- @module awful.ewmh
---------------------------------------------------------------------------

local client = client
local screen = screen
local ipairs = ipairs
local timer = require("gears.timer")
local gtable = require("gears.table")
local aclient = require("awful.client")
local aplace = require("awful.placement")
local asuit = require("awful.layout.suit")
local beautiful = require("beautiful")
local alayout = require("awful.layout")
local atag = require("awful.tag")

local ewmh = setmetatable({}, {
    __index = function(_, k)
        -- deprecated members
        if k == "generic_activate_filters" then
            return aclient._get_request_filters("request::activate", "generic")
        elseif k == "contextual_activate_filters" then
            return aclient._get_request_filters("request::activate", "contextual")
        end
    end
})

--- Honor the screen padding when maximizing.
-- @beautiful beautiful.maximized_honor_padding
-- @tparam[opt=true] boolean maximized_honor_padding

--- Hide the border on fullscreen clients.
-- @beautiful beautiful.fullscreen_hide_border
-- @tparam[opt=true] boolean fullscreen_hide_border

--- Hide the border on maximized clients.
-- @beautiful beautiful.maximized_hide_border
-- @tparam[opt=false] boolean maximized_hide_border

--- Update a client's settings when its geometry changes, skipping signals
-- resulting from calls within.
local repair_geometry_lock = false

local function repair_geometry(window)
    if repair_geometry_lock then return end
    repair_geometry_lock = true

    -- Re-apply the geometry locking properties to what they should be.
    for _, prop in ipairs {
        "fullscreen", "maximized", "maximized_vertical", "maximized_horizontal"
    } do
        if window[prop] then
            window:emit_signal("request::geometry", prop, {
                store_geometry = false
            })
            break
        end
    end

    repair_geometry_lock = false
end

-- Take into account the tag state to select where to send "orphan" clients.
--
-- Here's a textual description of the expected behavior.
--
-- Instead of always choosing the current tag, this function tries to pick the
-- "best" one(s). Some tags might be "reserved" for a single maximized apps.
-- Some other might have a carefully crafted layout that doesn't behave well
-- when additional clients are added. It is also possible to want that a tag
-- set of clients is never modified while the tag is selected to avoid things
-- "jumping around" and the master client getting replaced.
--
-- The "locked" tags should never be selected.
--
-- The "exclusive" tags should
-- not have new clients unless explicitly told by the rules (so it never gets
-- to this function) *or* when the client is "intrusive". The "intrusive"
-- clients, as implemented in other OS like macOS and Samsung modified Android,
-- are usually for "little floating tools" like calculators or color pickers.
--
-- If there's still nothing, look for a tag with the "class" state and the same
-- class as the client.
--
-- The "fallback" tags should be used when no selected tag is inclusive
-- (the default state).
--
-- If no tags are available and the client isn't sticky, then a new one
-- is created. This avoids having untagged clients. In practice it will only
-- happen if the user uses the tag state system, so it wont be unexpected for
-- such workflow.
--
local function choose_tag(c, hints)
    local new_tags = {}

    -- Check if a selected tag welcomes this client.
    for _, t in ipairs(c.screen.selected_tags) do
        if t.state == "inclusive" then
            table.insert(new_tags, t)
        elseif t.state == "exclusive" and c.intrusive then
            table.insert(new_tags, t)
        end
    end

    -- Look for fallback tags for the client screen.
    if #new_tags == 0 then
        for _, t in ipairs(c.screen.tags) do
            if t.state == "fallback" then
                --TODO add a way, per screen and globally, to disable
                -- auto-multitag.
                table.insert(new_tags, t)
            end
        end
    end

    -- Look for a tag for this specific class.
    if #new_tags == 0 then
        new_tags = atag.find_for_class(c)
    end

    -- Attempt to deduce the category.
--     if #new_tags == 0 then
--         new_tags = atag.find_for_category(c)
--     end

    -- Try to avoid creating tags
    if #new_tags == 0 then
        c:emit_signal("request::fallback_tags", hints.reason or "other", hints)
    end

    -- Last resort, add another tag
    if #new_tags == 0 and #c:tags() == 0 then
        atag.new(c.name, {
            icon     = c.icon,
            volatile = true,
            state    = "class",
        })
    end
end

--- Activate a window.
--
-- This sets the focus only if the client is visible.
--
-- It is the default signal handler for `request::activate` on a `client`.
--
-- @signalhandler awful.ewmh.activate
-- @client c A client to use
-- @tparam string context The context where this signal was used.
-- @tparam[opt] table hints A table with additional hints:
-- @tparam[opt=false] boolean hints.raise should the client be raised?
-- @tparam[opt=false] boolean hints.switch_to_tag should the client's first tag
--  be selected if none of the client's tags are selected?
-- @tparam[opt=false] boolean hints.switch_to_tags Select all tags associated
--  with the client.
function ewmh.activate(c, context, hints)
    hints = hints or  {}

    if c.focusable == false and not hints.force then
        if hints.raise then
            c:raise()
        end

        return
    end

    local ret = c:check_allowed_requests("request::activate", context, hints)

    -- Minimized clients can be requested to have focus by, for example, 3rd
    -- party toolbars and they might not try to unminimize it first.
    if ret ~= false and hints.raise then
        c.minimized = false
    end

    if ret ~= false and c:isvisible() then
        client.focus = c
    elseif ret == false and not hints.force then
        return
    end

    if hints.raise then
        c:raise()
        if not awesome.startup and not c:isvisible() then
            c.urgent = true
        end
    end

    -- The rules use `switchtotag`. For consistency and code re-use, support it,
    -- but keep undocumented. --TODO v5 remove switchtotag
    if hints.switchtotag or hints.switch_to_tag or hints.switch_to_tags then
        atag.viewmore(c:tags(), c.screen, (not hints.switch_to_tags) and 0 or nil)
    end
end

--- Add an activate (focus stealing) filter function.
--
-- The callback takes the following parameters:
--
-- * **c** (*client*) The client requesting the activation
-- * **context** (*string*) The activation context.
-- * **hints** (*table*) Some additional hints (depending on the context)
--
-- If the callback returns `true`, the client will be activated. If the callback
-- returns `false`, the activation request is cancelled unless the `force` hint is
-- set. If the callback returns `nil`, the previous callback will be executed.
-- This will continue until either a callback handles the request or when it runs
-- out of callbacks. In that case, the request will be granted if the client is
-- visible.
--
-- For example, to block Firefox from stealing the focus, use:
--
--    awful.ewmh.add_activate_filter(function(c)
--        if c.class == "Firefox" then return false end
--    end, "ewmh")
--
-- @tparam function f The callback
-- @tparam[opt] string context The `request::activate` context
-- @see generic_activate_filters
-- @see contextual_activate_filters
-- @see remove_activate_filter
-- @see awful.client.add_request_filter
-- @deprecated awful.ewmh.add_activate_filter
function ewmh.add_activate_filter(f, context)
    aclient.add_request_filter("request::activate", f, context)
end

--- Remove an activate (focus stealing) filter function.
-- This is an helper to avoid dealing with `ewmh.add_activate_filter` directly.
-- @tparam function f The callback
-- @tparam[opt] string context The `request::activate` context
-- @deprecated awful.ewmh.remove_activate_filter
-- @treturn boolean If the callback existed
-- @see generic_activate_filters
-- @see contextual_activate_filters
-- @see add_activate_filter
-- @see awful.client.remove_request_filter
function ewmh.remove_activate_filter(f, context)
    aclient.remove_request_filter("request::activate", f, context)
end

-- Get tags that are on the same screen as the client. This should _almost_
-- always return the same content as c:tags().
local function get_valid_tags(c, s)
    local tags, new_tags = c:tags(), {}

    for _, t in ipairs(tags) do
        if s == t.screen then
            table.insert(new_tags, t)
        end
    end

    return new_tags
end

--- Tag a window with its requested tag.
--
-- It is the default signal handler for `request::tag` on a `client`.
--
-- @signalhandler awful.ewmh.tag
-- @client c A client to tag
-- @tparam[opt] tag|boolean t A tag to use. If true, then the client is made sticky.
-- @tparam[opt={}] table hints Extra information
function ewmh.tag(c, t, hints)
    local is_accepted = c:check_allowed_requests(
        "request::tag", hints and hints.reason or "", hints
    ) ~= false

    if not is_accepted then return end

    -- There is nothing to do
    if not t and #get_valid_tags(c, c.screen) > 0 then return end

    if not t then
        if c.transient_for and not (hints and hints.reason == "screen") then
            -- When a dialog or a popup opens with a known parent client, bypass
            -- everything and favor the parent client screen and tags.
            c.screen = c.transient_for.screen
            if not c.sticky then
                local tags = c.transient_for:tags()
                c:tags(#tags > 0 and tags or c.transient_for.screen.selected_tags)
            end
        else
            -- Some dynamic tag rules can create a tag and/or assign clients to
            -- tags.
            atag.rules.apply(c, hints)

            -- By default, no rules will set the tags, so fallback to the
            -- selected one(s).
            if #c:tags() == 0 then
                c:to_selected_tags()
            end
        end
    elseif type(t) == "boolean" and t then
        c.sticky = true
    else
        -- When there is dynamic tag rules, take precedence over the desktop
        -- index. This is "better" because if tags are dynamic, the index has
        -- no "stable" meaning and should not be taken into account on restart.
        if awesome.startup and hints.reason == "ewmh" then
            atag.rules.apply(c, hints)
            if #c:tags() > 0 then return end
        end

        c.screen = t.screen
        c:tags({ t })
    end
end

--- Handle client urgent request
-- @signalhandler awful.ewmh.urgent
-- @client c A client
-- @tparam boolean urgent If the client should be urgent
function ewmh.urgent(c, urgent)
    local is_accepted = c:check_allowed_requests(
        "request::urgent", ""--[[TODO]], hints
    ) ~= false

    if not is_accepted then return end

    if c ~= client.focus and not aclient.property.get(c,"ignore_urgent") then
        c.urgent = urgent
    end
end

-- Map the state to the action name
local context_mapper = {
    maximized_vertical   = "maximize_vertically",
    maximized_horizontal = "maximize_horizontally",
    maximized            = "maximize",
    fullscreen           = "maximize"
}

--- Move and resize the client.
--
-- This is the default geometry request handler.
--
-- @signalhandler awful.ewmh.geometry
-- @tparam client c The client
-- @tparam string context The context
-- @tparam[opt={}] table hints The hints to pass to the handler
function ewmh.geometry(c, context, hints)
    local is_accepted = c:check_allowed_requests("request::geometry", context, hints) ~= false

    if not is_accepted then return end

    local layout = c.screen.selected_tag and c.screen.selected_tag.layout or nil

    local is_tiled = not (
        c.floating               or
        c.immobilized_horizontal or
        c.immobilized_vertical   or
        layout == asuit.floating
    )

    -- Setting the geometry will cause the client to flicker if it is tiled.
    if is_tiled then return end

    context = context or ""

    local original_context = context

    -- Now, map it to something useful
    context = context_mapper[context] or context

    local props = gtable.clone(hints or {}, false)
    props.store_geometry = props.store_geometry==nil and true or props.store_geometry

    -- If it is a known placement function, then apply it, otherwise let
    -- other potential handler resize the client (like in-layout resize or
    -- floating client resize)
    if aplace[context] then

        -- Check if it corresponds to a boolean property.
        local state = c[original_context]

        -- If the property is boolean and it corresponds to the undo operation,
        -- restore the stored geometry.
        if state == false then
            local original = repair_geometry_lock
            repair_geometry_lock = true
            aplace.restore(c, {context=context})
            repair_geometry_lock = original
            return
        end

        local honor_default = original_context ~= "fullscreen"

        if props.honor_workarea == nil then
            props.honor_workarea = honor_default
        end

        if props.honor_padding == nil and props.honor_workarea and context:match("maximize") then
            props.honor_padding = beautiful.maximized_honor_padding ~= false
        end

        if (original_context == "fullscreen" and beautiful.fullscreen_hide_border ~= false) or
           (original_context == "maximized" and beautiful.maximized_hide_border == true) then
            props.ignore_border_width = true
            props.zap_border_width = true
        end

        local original = repair_geometry_lock
        repair_geometry_lock = true
        aplace[context](c, props)
        repair_geometry_lock = original
    end
end

--- Merge the 2 requests sent by clients wanting to be maximized.
--
-- The X clients set 2 flags (atoms) when they want to be maximized. This caused
-- 2 request::geometry to be sent. This code gives some time for them to arrive
-- and send a new `request::geometry` (through the property change) with the
-- combined state.
--
-- @signalhandler awful.ewmh.merge_maximization
-- @tparam client c The client
-- @tparam string context The context
-- @tparam[opt={}] table hints The hints to pass to the handler
function ewmh.merge_maximization(c, context, hints)
    local is_accepted = (
        context == "client_maximize_horizontal" or
        context == "client_maximize_vertical"
    ) and c:check_allowed_requests("request::geometry", context, hints) ~= false

    if not is_accepted then return end

    if not c._delay_maximization then
        c._delay_maximization = function()
            -- This ignores unlikely corner cases like mismatching toggles.
            -- That's likely to be an accident anyway.
            if c._delayed_max_h and c._delayed_max_v then
                c.maximized = c._delayed_max_h or c._delayed_max_v
            elseif c._delayed_max_h then
                c.maximized_horizontal = c._delayed_max_h
            elseif c._delayed_max_v then
                c.maximized_vertical = c._delayed_max_v
            end
        end

        timer {
            timeout     = 1/60,
            autostart   = true,
            single_shot = true,
            callback    = function()
                if not c.valid then return end

                c._delay_maximization(c)
                c._delay_maximization = nil
                c._delayed_max_h = nil
                c._delayed_max_v = nil
            end
        }
    end

    local function get_value(suffix, long_suffix)
        if hints.toggle and c["_delayed_max_"..suffix] ~= nil then
            return not c["_delayed_max_"..suffix]
        elseif hints.toggle then
            return not c["maximized_"..long_suffix]
        else
            return hints.status
        end
    end

    if context == "client_maximize_horizontal" then
        c._delayed_max_h = get_value("h", "horizontal")
    elseif context == "client_maximize_vertical" then
        c._delayed_max_v = get_value("v", "vertical")
    end
end

--- Allow the client to move itself.
--
-- This is the default geometry request handler when the context is `ewmh`.
--
-- @signalhandler awful.ewmh.client_geometry_requests
-- @tparam client c The client
-- @tparam string context The context
-- @tparam[opt={}] table hints The hints to pass to the handler
function ewmh.client_geometry_requests(c, context, hints)
    local is_accepted = context == "ewmh" and hints
        and c:check_allowed_requests("request::geometry", context, hints) ~= false

    if not is_accepted then return end

    if c.immobilized_horizontal then
        hints = gtable.clone(hints)
        hints.x = nil
        hints.width = nil
    end
    if c.immobilized_vertical then
        hints = gtable.clone(hints)
        hints.y = nil
        hints.height = nil
    end
    c:geometry(hints)
end

-- The magnifier layout doesn't work with focus follow mouse.
aclient.add_request_filter("request::activate", function(c)
    if alayout.get(c.screen) ~= alayout.suit.magnifier
      and aclient.focus.filter(c) then
        return nil
    else
        return false
    end
end, "mouse_enter")

client.connect_signal("request::activate", ewmh.activate)
client.connect_signal("request::tag", ewmh.tag)
client.connect_signal("request::urgent", ewmh.urgent)
client.connect_signal("request::geometry", ewmh.geometry)
client.connect_signal("request::geometry", ewmh.merge_maximization)
client.connect_signal("request::geometry", ewmh.client_geometry_requests)
client.connect_signal("property::border_width", repair_geometry)
client.connect_signal("property::screen", repair_geometry)
screen.connect_signal("property::workarea", function(s)
    for _, c in pairs(client.get(s)) do
        repair_geometry(c)
    end
end)

return ewmh

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
