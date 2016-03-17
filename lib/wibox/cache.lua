---------------------------------------------------------------------------
-- Management of widget caches.
--
-- This is meant for internal use only. If you are look for a generic caching
-- mechanism, use `gears.cache`.
--
-- @author Uli Schlachter
-- @copyright 2015 Uli Schlachter
-- @release @AWESOME_VERSION@
-- @module wibox.hierarchy
---------------------------------------------------------------------------
local cache = require("gears.cache")
local protected_call = require("gears.protected_call")

-- Indexes are widgets, allow them to be garbage-collected
local widget_dependencies = setmetatable({}, { __mode = "kv" })

-- Special value to skip the dependency recording that is normally done by
-- base.fit_widget() and hierarchy.layout_widget(). The caller must ensure that no
-- caches depend on the result of the call and/or must handle the childs
-- widget::layout_changed signal correctly when using this.
local module = {
    no_parent_I_know_what_I_am_doing = {}
}

-- Record a dependency from parent to child: The layout of parent depends on the
-- layout of child.
local function record_dependency(parent, child)
    if parent == base.no_parent_I_know_what_I_am_doing then
        return
    end

    local deps = widget_dependencies[child] or {}
    deps[parent] = true
    widget_dependencies[child] = deps
end

-- Clear the caches for `widget` and all widgets that depend on it.
local clear_caches
function module.clear_caches(widget)
    local deps = widget_dependencies[widget] or {}
    widget_dependencies[widget] = {}
    widget._widget_caches = {}
    for w in pairs(deps) do
        module.clear_caches(w)
    end
end



-- Record a dependency from parent to child: The layout of parent depends on the
-- layout of child.
function module.record_dependency(parent, child)
    if parent == module.no_parent_I_know_what_I_am_doing then
        return
    end

    local deps = widget_dependencies[child] or {}
    deps[parent] = true
    widget_dependencies[child] = deps
end

-- Get the cache of the given kind for this widget. This returns a gears.cache
-- that calls the callback of kind `kind` on the widget.
function module.get_cache(widget, kind)
    if not widget._widget_caches[kind] then
        widget._widget_caches[kind] = cache.new(function(...)
            return protected_call(widget[kind], widget, ...)
        end)
    end
    return widget._widget_caches[kind]
end

--- Lay out a widget for the given available width and height. This calls the
-- widget's `:layout` callback and caches the result for later use. Never call
-- `:layout` directly, but always through this function! However, normally there
-- shouldn't be any reason why you need to use this function.
-- @param parent The parent widget which requests this information.
-- @param context The context in which we are laid out.
-- @param widget The widget to layout (this uses widget:layout(context, width, height)).
-- @param width The available width for the widget
-- @param height The available height for the widget
-- @return The result from the widget's `:layout` callback.
function module.layout_widget(parent, context, widget, width, height)
    --TODO find a better home for this method, ideally back into base.lua
    module.record_dependency(parent, widget)

    if not widget.visible then
        return
    end

    -- Sanitize the input. This also filters out e.g. NaN.
    width = math.max(0, width)
    height = math.max(0, height)

    if widget.layout then
        return module.get_cache(widget, "layout"):get(context, width, height)
    end
end

return module
