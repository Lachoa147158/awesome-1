---------------------------------------------------------------------------
--- Allows to use the wibox widget system to draw the wallpaper.
--
-- Rather than simply having a function to set an image
-- (stretched, centered or tiled) like most wallpaper tools, this module
-- leverage the full widget system to draw the wallpaper. Note that the result
-- is **not** interactive. If you want an interactive wallpaper, better use
-- a `wibox` object with the `below` property set to `true` and maximized
-- using `awful.placement.maximized`.
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2019 Emmanuel Lepage Vallee
-- @classmod awful.wallpaper
---------------------------------------------------------------------------
local gtable     = require( "gears.table"         )
local gobject    = require( "gears.object"        )
local gtimer     = require( "gears.timer"         )
local whierarchy = require( "wibox.hierarchy"     )
local manual     = require( "wibox.layout.manual" )

local module = {}

local function run_in_hierarchy(self, cr, width, height)
    local root_width, root_height = root.size()
    local context = {dpi=96}
    local h = hierarchy.new(context, self, width, height, no_op, no_op, {})
    h:draw(context, cr)
    return h
end

local function paint()
    s = get_screen(s)

    local root_width, root_height = root.size()
    local geom = s and s.geometry or root_geometry()
    local source, target, cr

    if not pending_wallpaper then
        -- Prepare a pending wallpaper
        source = surface(root.wallpaper())
        target = source:create_similar(cairo.Content.COLOR, root_width, root_height)

        -- Set the wallpaper (delayed)
        timer.delayed_call(function()
            local paper = pending_wallpaper
            pending_wallpaper = nil
            wallpaper.set(paper.surface)
            paper.surface:finish()
        end)
    elseif root_width > pending_wallpaper.width or root_height > pending_wallpaper.height then
        -- The root window was resized while a wallpaper is pending
        source = pending_wallpaper.surface
        target = source:create_similar(cairo.Content.COLOR, root_width, root_height)
    else
        -- Draw to the already-pending wallpaper
        source = nil
        target = pending_wallpaper.surface
    end

    cr = cairo.Context(target)

    if source then
        -- Copy the old wallpaper to the new one
        cr:save()
        cr.operator = cairo.Operator.SOURCE
        cr:set_source_surface(source, 0, 0)
        cr:paint()
        cr:restore()
    end

    pending_wallpaper = {
        surface = target,
        width = root_width,
        height = root_height
    }

    -- Only draw to the selected area
    cr:translate(geom.x, geom.y)
    cr:rectangle(0, 0, geom.width, geom.height)
    cr:clip()

    return geom, cr
end

local mutex = false

-- Uploading the surface to X11 is *very* resource intensive. Given the updates
-- will often happen in batch (like startup), make sure to only do one "real"
-- update.
local function update()
    if mutex then return end

    mutex = true

    gtimer.deleayed_call(function()
        paint()
        mutex = false
    end)
end

--- The wallpaper widget.
--
-- When set, instead of using the `image_path` or `surface` properties, the
-- wallpaper will be defined as a normal `wibox` widget tree.
--
-- @property widget
-- @param wibox.widget
-- @see image

--- The wallpaper DPI (dots per inch).
--
-- Each screen has a DPI. This value will be used by default, but sometime it
-- is useful to override the screen DPI and use a custom one. This makes
-- possible, for example, to draw the widgets bigger than they would otherwise
-- be.
--
-- @property dpi
-- @param[opt=screen.dpi] number
-- @see screen

--- The wallpaper screen.
--
-- Note that there can only be one wallpaper per screen. If there is more, one
-- will be chosen and all other ignored.
--
-- @property screen
-- @param screen

--- The background color.
--
-- It will be used as the "fill" color if the `image` doesn't take all the
-- screen space. It will also be the default background for the `widget.
--
-- As usual with colors in `AwesomeWM`, it can also be a gradient or a pattern.
--
-- @property bg
-- @param gears.color
-- @see gears.color

--- The foreground color.
--
-- This will be used by the `widget` (if any).
--
-- As usual with colors in `AwesomeWM`, it can also be a gradient or a pattern.
--
-- @property fg
-- @param gears.color
-- @see gears.color

--- The `image` placement.
--
-- @property placement
-- @param An `awful.placement` compatible function.
-- @see awful.placement

--- Honor the `image` aspect ratio.
--
-- When set to `false`, the `image` or `widget` will be scaled horizontally
-- or vertically to fill the whole space.
--
-- @property honor_ratio
-- @param[opt=true] boolean

--- Honor the workarea.
--
-- When set to `true`, the wallpaper will only fill the workarea space instead
-- of the entire screen. This means it wont be drawn below the `awful.wibar` or
-- docked clients. This is useful when using opaque bars. Note that it can cause
-- aspect ratio issues for the wallpaper `image` and add bars colored with the
-- `bg` color on the sides.
--
-- @property honor_workarea
-- @param[opt=false] boolean

function module:set_widget(w)
    --
end

function module:set_dpi(dpi)
    --
end

function module:set_screen(s)
    self._private.screen = s
end

function module:get_screen()
    return self._private.screen
end

local function new(args)
    local ret = gobject {
        enable_auto_signals = true,
        enable_properties   = true,
    }

    rawset(ret, "_private", {})

    gtable.crush(ret, module, true)

    return ret
end

return module
