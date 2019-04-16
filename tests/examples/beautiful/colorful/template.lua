local file_path, image_path = ...
require("_common_template")(...)

-- Test if shape crash when called
-- Also generate some SVG to be used by the documentation
-- it also "prove" that the code examples are all working
local cairo    = require( "lgi"         ).cairo
local shape    = require( "gears.shape" )
local colorful = require( "beautiful.colorful" )
local wibox    = require( "wibox"         )
local surface  = require( "gears.surface" )
local unpack = unpack or table.unpack -- luacheck: globals unpack (compatibility with Lua 5.1)

local api, lines = {}, {}

local function current_group()
    local g = lines[#lines]

    if not g then
        g = {groups={{}},mix={}}
        table.insert(lines, g)
    end

    return g.groups[#g.groups]
end

local function group_for_color(col)
    -- While a hashmap would work too, the extra housekeeping isn't worth it
    -- for a static example. There is never all that many elements in those
    -- arrays.
    for _, l in ipairs(lines) do
        for _, g in ipairs(l.groups) do
            for _, c in ipairs(g) do
                if col == c then
                    return g
                end
            end
        end
    end
end

local constructor, mixer = colorful._create_color_object, colorful.to_mixed

-- Monkeypatch the constructor to keep track of all instances.
--
-- Given this module produces immutable objects, it is important to attempt to
-- keep track of the graph used to generate the final result.
function colorful._create_color_object(...)
    local ret = constructor(...)

    table.insert(current_group(), ret)

    return ret
end

-- Monkeypatch `to_mixed` to intercept the graph nodes.
--
-- It is the only function that merge different groups. It can be a graph since
-- a group can be mixed, forked, then mixed again. So far I try to avoid this
-- in the examples because it is visually confusing, but in theory it can
-- happen, so this template does a minimal effort to try to handle this well
-- enough.
function colorful.to_mixed(col1, col2, value)
    local ret = mixed(col1, col2, value)

    current_group()

    table.insert(lines[#lines].mix, {col1, col2})

    return ret
end

-- Monkey-wrap all methods to keep track of when many values are returned.
for name, method in pairs(colorful) do
    colorful[name] = function(...)
        local ret = {method(...)}

        return unpack(ret)
    end
end

-- Groups are sequences of colorful object.
--
-- The general idea is to merge be able to visualize the merging of different
-- colorful objects in the documentation.
function api.add_group()
    current_group()
    table.insert(lines[#lines].groups, {})
end

-- Lines are independent colorful objects to be displayed in the doc.
function api.add_line()
    table.insert(lines, {groups={{}},mix={}})
end

-- This is the main widget the tests will use as top level
local layout = wibox.layout.fixed.vertical()
layout.spacing = 3

-- Let the test request a size and file format
loadfile(file_path)(api)

local arrow = function(cr, w, h) return shape.arrow(cr, w, h, 7, 2, 6) end

local function gen_group(g)
    if #g == 0 then return nil end

    local cols   = wibox.layout.fixed.horizontal()
    cols.spacing = 14

    cols.spacing_widget = wibox.widget {
        {
            forced_height = 10,
            forced_width  = 10,
            shape         = shape.transform(arrow) : rotate_at(5, 5, math.pi/2),
            widget        = wibox.widget.separator,
        },
        halign = "center",
        valign = "center",
        widget = wibox.container.place,
    }

    for _, c in ipairs(g) do
        cols:add(wibox.widget {
            forced_width  = 32,
            forced_height = 32,
            shape         = shape.circle,
            border_width  = 1,
            border_color  = "#000000",
            color         = c:to_hexa(),
            widget        = wibox.widget.separator
        })
    end

    return cols
end

assert(#lines > 0)

-- Cleanup all groups in a way that's easy to render and visualize.
for _, l in ipairs(lines) do
    -- Easy case, there's no merging, which means there isn't a graph either.
    if #l.groups == 1 then
        l.columns = {{rows = {l.groups[1]} }}
    else
        assert(#l.mix > 0, "Groups only make sense when colors are mixed")
        l.columns = {{ rows = {} }}

        -- Right now it only supports 2 groups, but can easily be extended if
        -- needed.
        for _, m in ipairs(l.mix) do
            local g1, g2 = group_for_color(m[1]), group_for_color(m[2])
            assert(g1 and g1 ~= g2, "Mixed colors need to be in groups")
            table.insert(l.columns[1].rows, #g1 < #g2 and g1 or g2)
            table.insert(l.columns[1].rows, #g1 < #g2 and g2 or g1)
        end
    end

    assert(#l.columns[1].rows > 0)
end

-- Add all line.
for _, l in ipairs(lines) do

    local row = wibox.layout.fixed.vertical()

    for _, g in ipairs(l.columns[1].rows) do --TODO support more than 2 mix
        row:add(wibox.widget {
            gen_group(g),
            halign = "right",
            widget =  wibox.container.place
        })
        assert(#row.children > 0)
    end

    assert(#row.children > 0)

    layout:add(row)
end

-- Get the example fallback size (the tests can return a size if the want)
local f_w, f_h = layout:fit({dpi=96}, 9999, 9999)
assert(f_w >= 32 and f_h >= 32)

-- Save to the output file
local img = surface.widget_to_svg(layout, image_path..".svg", w or f_w, h or f_h)
img:finish()

-- vim: filetype=lua:expandtab:shiftwidth=4:tabstop=8:softtabstop=4:textwidth=80
