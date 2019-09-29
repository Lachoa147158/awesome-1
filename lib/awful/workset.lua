---------------------------------------------------------------------------
-- A group of screens and tags belonging together.
--
-- A `workset` is the "owner" of some screens and tag objects. A screen must
-- be part of a `workset`. By default, creating a `screen` will create a
-- workset along with it. Tags can be part of a single `workset` at any time.
-- The tag `index` property is relative to its workset.
--
-- @author Emmanuel Lepage Vallee
-- @copyright 2019 Emmanuel Lepage Vallee
-- @coreclassmod awful.workset
---------------------------------------------------------------------------
local gobject = require("gears.object")
local gtable  = require("gears.table")
local gmath   = require("gears.math")

local capi = { screen = screen, client = client, mouse = mouse }

local module = {}

local by_name = {}

local function get_screen(s)
    return s and capi.screen[s]
end

--TODO move to the tests
local function validate_or_die(self)
    local tags = {}

    for k, t in ipairs(self._private.tags_by_indices) do
        if tags[t] then
            print(debug.traceback())
            os.exit(1)
        end

        if self._private.tag_indices[t] ~= k then
            print("ERROR",self._private.tag_indices[t], k, t)
            print(debug.traceback())
            os.exit(1)
        end

        tags[t] = true
    end
end

local function get_current_workset()
    local ascreen = require("awful.screen") --FIXME

    return module._focused_screen().workset
end

-- Get the tags ordered by their grouped indices.
--
-- Note, do **not** modify the resulting list directly.
-- @staticfct awful.tag._get_by_group
-- @taparam string name The group name.
-- @treturn table All tags ordered by grouped indices.

function _get_by_group(name)
    -- Init the list.
    if not tag_groups[name] then
        local t = nil

        for _, t2 in ipairs(root.tags()) do
            if tag.getproperty(t2, "group") == name then
                t = t2
                break
            end
        end

        if not t then
            tag_groups[name] = {}
            return tag_groups[name]
        end

        -- This will init the index.
        tag.object.get_group_index(t)
    end

    return tag_groups[name]
end

-- Smarter way to get the tags and group.
local function get_tag_and_group(screen, args)
    local group = screen.tag_group or args.group
    local tags  = group and tag._get_by_group(group) or screen.tags

    return tags, group
end

-- Smarter way to get the selected tag which takes the group into account.
local function get_selected_tag(tags, workset, screen, args)
    assert(workset)

    print("\nTAGS", #tags, screen.index)

    -- The last "or tags[1]" will happen in grouped mode when all tags are
    -- on another screen.
    local sel, idx = screen.selected_tag, nil

    print("SCREEN SEL", sel, idx)

    -- This will happen if no tags are selected on the screen, but other screens
    -- which are part of the same group have.
    if not sel then
        for k, t in ipairs(tags) do
            if t.selected then
                sel, idx = t, k
                break
            end
        end
    end

    -- Fallback to something sane.
    if not sel then
        sel = sel or screen:get_tags(true)[1] or tags[1]
        idx = 1
    end

    print("RET", sel, idx, gtable.hasitem(tags, sel))

    assert((not idx) or type(idx) == "number")
    assert(type(sel) == "tag")

    return sel, idx or gtable.hasitem(tags, sel)
end

-- When reaching the last tag, select the first and vice versa.
local function select_relative_rotate(tags, i, current_index, _, args)
    return ((not args.mode) or args.mode == "screen" or args.mode == "rotate") and
        tags[gmath.cycle(#tags,current_index + i)] or
        tags[current_index + i]
end

local function select_relative_screen(tags, i, current_index, screen, args)
    assert(false)
    local s = screen
    local old_count = #tags

    if current_index+i > old_count then
        s = screen:get_next_in_direction("right")
        i = (current_index + i) - old_count
    elseif current_index+i <= 0 then
        s = screen:get_next_in_direction("left")
        i = current_index - i
    end

    if s ~= screen then
        local tags, workset = get_tag_and_group(s, args)
        _, current_index = get_selected_tag(tags, workset, screen, args)
    end

    return select_relative_rotate(tags, i, current_index, s, args)
end

--- Switch to a tag in relation to the currently selected tag.
--
-- The `args.modes` are:
--
-- **rotate**: *(default)*
--
-- Go back around the tags. For example, iterating past the end will by one
-- will move to the first tag. Iterating backward from the first tag will
-- select the last tag.
--
-- **stop**:
--
-- When reaching an edge, stay there. If the first tag is selected, calling
-- `awful.workset.select_tag_relative` with a negative number will do nothing. If the
-- last tag is selected and `awful.workset.select_tag_relative` is called with a positive
-- number, it will do nothing.
--
-- **screen**:
--
-- When reaching the edge, start to iterate the tags on the next screen.
--
-- **screen_rotate**:
--
-- When reaching the edge, start to iterate the tags on the next screen. When
-- reaching the last tag of the last screen on the left or right, start from
-- the other side.
--
-- @staticfct awful.workset.select_tag_relative
-- @see screen.tags
-- @tparam number i The **relative** index to see.
-- @tparam[opt] table args
-- @tparam[opt=awful.screen.focused] screen args.screen The screen.
-- @tparam[opt=true] boolean args.mode Which algorithm should be used to iterate.
--  See the modes mentioned above.
-- @tparam[opt=false] boolean args.grouped Use the grouped tag indices instead
--  of the per screen ones.
-- @tparam[opt=false] boolean args.force When `grouped` is set, this will untag
--  the clients tagged on more than 1 tag to allow the tag to be selected.
-- @tparam[opt=true] boolean args.restore_history When set along with `grouped`,
--  this option will restore tags on the origin screen if the tag if it had to
--  be relocated to `args.screen` while being the only selected tag.
function module.select_tag_relative(self, i, args)
    if i == 0 then return end

    args = args or {}

    local screen       = get_screen(args.screen or self.focused_screen)
    local group        = screen.tag_group
    local tags         = module.get_tags(self)
    assert(tags)
    local sel, sel_idx = get_selected_tag(tags, self, screen, args)

    print("SSSS", sel, sel_idx, i, args.mode)

    module._viewnone(screen)

    local nt = nil

    local mode = args.mode or "rotate"

    if mode == "rotate" or mode == "stop" then
        assert(type(sel_idx) == "number")
        nt = select_relative_rotate(tags, i, sel_idx, nil, args)
    elseif mode == "screen" or mode == "screen_rotate" then
        nt = select_relative_screen(tags, i, current_index, screen, args)
    end

    if nt then
        print("\nSELECT", nt.name, screen.index)
        nt:select {screen = screen, force = args.force}
    end

    screen:emit_signal("tag::history::update")
end


--- View next tag, relative to the currently selected one.
--
-- This is the global version of `my_workset_object:select_next_tag()`. This
-- static function is easier to use within the global keybinginds.
--
-- The `args.modes` are:
--
-- **rotate**: *(default)*
--
-- Go back around the tags. For example, calling `awful.workset.select_next_tag` past the
-- end will by one will move to the first tag.
--
-- **stop**:
--
-- When reaching an edge, stay there. If the
-- last tag is selected and `awful.workset.select_next_tag` is called, it will do nothing.
--
-- @staticfct awful.work.select_next_tag
-- @tparam awful.workset|nil workset The workset. If none is provided,
--  `awful.workset.current` will be used.
-- @tparam table args
-- @tparam[opt=awful.screen.focused] screen args.screen The screen.
-- @tparam[opt=true] boolean args.mode Which algorithm should be used to iterate.
--  See the modes mentioned above.
-- @tparam[opt=false] boolean args.grouped Use the grouped tag indices instead of
--  the per screen ones.
-- @tparam[opt=false] boolean args.force When `grouped` is set, this will untag
--  the clients tagged on more than 1 tag to allow the tag to be selected.

--- View next tag, relative to the currently selected one.
--
-- The `args.modes` are:
--
-- **rotate**: *(default)*
--
-- Go back around the tags. For example, calling `awful.workset.select_next_tag` past the
-- end will by one will move to the first tag.
--
-- **stop**:
--
-- When reaching an edge, stay there. If the
-- last tag is selected and `awful.workset.select_next_tag` is called, it will do nothing.
--
-- @method select_next_tag
-- @tparam table args
-- @tparam[opt=awful.screen.focused] screen args.screen The screen.
-- @tparam[opt=true] boolean args.mode Which algorithm should be used to iterate.
--  See the modes mentioned above.
-- @tparam[opt=false] boolean args.grouped Use the grouped tag indices instead of
--  the per screen ones.
-- @tparam[opt=false] boolean args.force When `grouped` is set, this will untag
--  the clients tagged on more than 1 tag to allow the tag to be selected.

function module.select_next_tag(workset, args)
    if (not args) and workset and (not workset._private) then
        args, workset = workset, nil
    end

    workset = workset or get_current_workset()

    return workset:select_tag_relative(1, args)
end


function module.toggle_tag()
    --TODO
    assert(false)
end

--- View previous tag, relative to the currently selected one.
--
-- This is the global version of `my_workset_object:select_previous_tag()`. This
-- static function is easier to use within the global keybinginds.
--
-- The `args.modes` are:
--
-- **rotate**: *(default)*
--
-- Go back around the tags. For example, calling `awful.workset.select_previous_tag` from
-- the first tag will select the last tag.
--
-- **stop**:
--
-- When reaching an edge, stay there. If the first tag is selected, calling
-- `awful.workset.select_previous_tag` will do nothing.
--
-- @staticfct awful.workset.select_previous_tag
-- @tparam awful.workset|nil workset The workset. If none is provided,
--  `awful.workset.current` will be used.
-- @tparam table args
-- @tparam[opt=awful.screen.focused] screen args.screen The screen.
-- @tparam[opt=true] boolean args.mode Which algorithm should be used to iterate.
--  See the modes mentioned above.
-- @tparam[opt=false] boolean args.grouped Use the grouped tag indices instead of
--  the per screen ones.
-- @tparam[opt=false] boolean args.force When `grouped` is set, this will untag
--  the clients tagged on more than 1 tag to allow the tag to be selected.


--- View previous tag, relative to the currently selected one.
--
-- The `args.modes` are:
--
-- **rotate**: *(default)*
--
-- Go back around the tags. For example, calling `awful.workset.select_previous_tag` from
-- the first tag will select the last tag.
--
-- **stop**:
--
-- When reaching an edge, stay there. If the first tag is selected, calling
-- `awful.workset.select_previous_tag` will do nothing.
--
-- @method select_previous_tag
-- @tparam table args
-- @tparam[opt=awful.screen.focused] screen args.screen The screen.
-- @tparam[opt=true] boolean args.mode Which algorithm should be used to iterate.
--  See the modes mentioned above.
-- @tparam[opt=false] boolean args.grouped Use the grouped tag indices instead of
--  the per screen ones.
-- @tparam[opt=false] boolean args.force When `grouped` is set, this will untag
--  the clients tagged on more than 1 tag to allow the tag to be selected.

function module.select_previous_tag(workset, args)
    if (not args) and workset and (not workset._private) then
        args, workset = workset, nil
    end

    print("PREVIOUS", workset, args)

    workset = workset or get_current_workset()

    return workset:select_tag_relative(-1, args)
end

function module._add_tag(self, t)
    if self._private.tag_indices[t] then return end

    print("ADD TAG")

    local idx = #self._private.tags_by_indices
    table.insert(self._private.tags_by_indices, t)
    self._private.tag_indices[t] = idx

    validate_or_die(self)
    assert(self._private.tags_by_indices[self._private.tag_indices[t]] == t)

    self:emit_signal("tag::added", t)
    validate_or_die(self)
end

function module._remove_tag(self, t)
    if not self._private.tag_indices[t] then return end

    local idx = self._private.tag_indices[t]

    assert(self._private.tags_by_indices[idx] == t)

    table.remove(self._private.tags_by_indices, idx)

    for i=idx, #self._private.tags_by_indices do
        local t = self._private.tags_by_indices[i]
        self._private.tag_indices[t] = i

        assert(self._private.tags_by_indices[self._private.tag_indices[t]] == t)
    end

    for i=idx, #self._private.tags_by_indices do
        self._private.tags_by_indices[i]:emit_signal("property::index", i)
    end

    self:emit_signal("tag::removed", t)
    validate_or_die(self)
end

--- Get the tags associated with this screen `workset`.
--
-- @property tags
-- @param table

function module.get_tags(self)
    print("HERE!", #self._private.tags_by_indices)
    validate_or_die(self)
    return self._private.tags_by_indices
end

function module.set_tags(self, new_tags)
    local to_add, to_remove, by_tags = {}, {}, {}

    for _, t in ipairs(new_tags) do
        if not self._private.tag_indices[t] then
            table.insert(to_add, t)
        end

        by_tags[t] = true
    end

    for _, t in ipairs(self._private.tags_by_indices) do
        if not by_tags[t] then
            table.insert(to_remove, t)
        end
    end

    for _, t in ipairs(to_remove) do
        module._remove_tag(self, t, false)
    end

    for _, t in ipairs(to_add) do
        module._add_tag(self, t, false)
    end

    validate_or_die(self)
end

function module._add_screen(self, s)
    if self._private.has_screen[s] then return end

    s.data.ws = self

    local tags = s.tags

    for _, t in ipairs(tags) do
        module._add_tag(self, t)
    end

    table.insert(self._private.screens, s)
    self._private.has_screen[s] = true

    self:emit_signal("screen::added", s)
end

function module._remove_screen(self, s, detach_tags)
    if not self._private.has_screen[s] then return end

    for _, t in ipairs(s.tags) do
        if detach_tags or #self.screens == 1 then
            module._remove_tag(self, t)
        else
            t.screen = self.screens[self.screens[1] == s and 2 or 1]
        end
    end

    for k, s2 in ipairs(self._private.screens) do
        if s2 == s then
            table.remove(self._private.screens, k)
            self._private.has_screen[s] = false
            self:emit_signal("screen::removed", s)
            break
        end
    end
end

--- Get the screens associated with this screen `workset`.
--
-- @property screens
-- @param table

function module.get_screens(self)
    return self._private.screens
end

function module.set_screens(self, new_screens)
    local to_add, to_remove, by_scr = {}, {}, {}

    for _, s in ipairs(new_screens) do
        if not self._private.has_screen[s] then
            table.insert(to_add, s)
        end

        by_scr[s] = true
    end

    for _, s in ipairs(self._private.screens) do
        if not by_scr[s] then
            table.insert(to_remove, s)
        end
    end

    for _, s in ipairs(to_remove) do
        module._remove_screen(self, s, false)
    end

    for _, s in ipairs(to_add) do
        module._add_screen(self, s, false)
    end
end

--- View (select) a tag by index.
--
-- This method support both screen tags and tag groups.
--
-- @method select_tag_by_index
-- @tparam number index The index to select.
-- @tparam table args See `awful.tag.select`.
-- @see tags
-- @see awful.workset.select_tag_relative

function module.select_tag_by_index(self, index, args)
    if type(self) == "number" then
        self, index = get_current_workset(), self
    end

    local t = s.group and s.group_tags[index] or self.tags[index]

    if t then
        t:select(args)
    end
end

--- Toggle a tag by index.
--
-- This method support both screen tags and tag groups.
--
-- @method toggle_tag_by_index
-- @tparam number index The index to select.
-- @tparam table args See `awful.tag.select`.
-- @see tags
-- @see awful.workset.select_tag_relative

function module.toggle_tag_by_index(self, index, args)
    if type(self) == "number" then
        self, index = get_current_workset(), self
    end

    local t = s.group and s.group_tags[index] or self.tags[index]

    if t then
        t:select(args)
    end
end

--- Return true if the screen is part of this workset.
--
-- This is equivalent to `s.workset == w` for most use case, but also allows
-- to query by screen index and name.
--
-- @method has_screen
-- @tparam screen s

--- Return true if the tag is part of this workset.
--
-- This is equivalent to `t.workset == w` for most use case, but also allows
-- to query by screen index and name.
--
-- @method has_tag
-- @tparam screen s

function module.has_screen(self, s)
    s = get_screen(s)
    return s and self._private.has_screen[s] or false
end

function module.has_tag(self, s)
    s = get_screen(s)
    return s and self._private.has_screen[s] or false
end

--- The workset name.
--
-- This is useful when used alongside rules because it allows to set the
-- `tag` or `screen` workset using its name. It can also be obtained using
-- `awful.workset.insert_name_here`.
--
-- @property name
-- @param string

function module.set_name(self, name)
    if name == self._private.name then return end

    self._private.name = name

    if self._private.name then
        by_name[self._private.name] = self
    end

    self:emit_signal("property::name", name)
end

function module.get_name(self)
    if (not self._private.name) and #self._private.screen == 1 then
        return self._private.screen[1].name
    end

    return self._private.name
end

function module.merge(self, other, no_tag_signals)
    --TODO
    assert(false)
end

function module._remove_tag(tag, old_screen)
    --TODO
    assert(false)
end

function module._move_tag(self, tag, new_screen, old_screen)
    validate_or_die(self)
    if new_screen == old_screen then
        local idx = self._private.tag_indices[tag]

        if idx and self._private.tags_by_indices[idx] == tag then return end

          print("NOPE", idx)
    end

          print("SSS", tag, new_screen, old_screen)
    local cur_idx = old_screen and old_screen.workset._private.tag_indices[tag]

    if cur_idx and old_screen and old_screen.workset == self then return end

    if cur_idx and old_screen then
        module._remove_tag(self, tag, true)
    end

    for k2, t2 in ipairs(self._private.tags_by_indices) do
        print("   ", k2, t2)
    end
validate_or_die(self)

    print(self._private.tag_indices[tag])
    local idx = #self._private.tags_by_indices+1
    print(self._private.tags_by_indices[1], idx)

    table.insert(self._private.tags_by_indices, tag)

    self._private.tag_indices[tag] = idx

    print(self._private.tags_by_indices[idx], self._private.tag_indices[tag])

validate_or_die(self)
    assert(self._private.tags_by_indices[self._private.tag_indices[tag]] == tag)

    self:emit_signal("tag::added", tag)
    tag:emit_signal("property::index", idx)

    module._get_tag_index(self, tag)
          print("MOVE", tag, #self._private.tags_by_indices)
    for k2, t2 in ipairs(self._private.tags_by_indices) do
        print("   ", k2, t2)
    end
          print()
    validate_or_die(self)
end

function module._get_tag_index(self, tag)
    assert(self._private.tag_indices[tag])

    return self._private.tags_by_indices[tag]
end

function module._set_tag_index(self, tag, idx)
    validate_or_die(self)
    local old_idx = tag.screen.workset._private.tag_indices[tag]

    if old_idx == idx then return end

    local to_update = math.min(idx, old_idx or math.huge)

    assert((not old_idx) or self._private.tags_by_indices[old_idx] == tag)
    assert((not old_idx) or self._private.tag_indices[tag] == old_idx)

    if old_idx then
        table.remove(self._private.tags_by_indices, old_idx )
    end

    table.insert(self._private.tags_by_indices, idx, tag)
    tag.screen.workset._private.tag_indices[tag] = idx


    -- Update everything.
    for i=to_update, #self._private.tags_by_indices do
        local t = self._private.tags_by_indices[i]
        self._private.tag_indices[t] = i

        assert(self._private.tags_by_indices[self._private.tag_indices[t]] == t)
    end

    -- Notify everybody.
    -- This is done after the fact because some handler can look for other
    -- tag index and they are not updated yet.
    for i=to_update, #self._private.tags_by_indices do
        local t = self._private.tags_by_indices[i]
        t:emit_signal("property::index", idx)
    end
          validate_or_die(self)
end

--- The workset focused screen.
--
-- If the `awful.screen.focused()` screen isn't part of this workset, then this
-- property will be `nil`.
--
-- This property can be used to determine if the workset is focused like this:
--
--    if myworkset.focused_screen then
--        -- do something.
--    end
--
-- @property focused_screen
-- @tparam screen|nil focused_screen

function module._viewnone(screen)
    screen = screen or module._focused_screen()
    local tags = screen.tags
    for _, t in pairs(tags) do
        t.selected = false
    end
end

function module._focused_screen(args)
    args = args or module._default_focused_args or {}
    return get_screen(
        args.client and capi.client.focus and capi.client.focus.screen or capi.mouse.screen
    )
end

function module.get_focused_screen(self)
    local s = module._focused_screen()
    return s.workset == self and s or nil
end


-- local function set_index_common(tags, self, idx, scr, prop)
--     -- sort the tags by index
--     table.sort(tags, function(a, b)
--         local ia, ib = tag.getproperty(a, prop), tag.getproperty(b, prop)
--         return (ia or math.huge) < (ib or math.huge)
--     end)
--
--     if (not idx) or (idx < 1) or (idx > #tags) then
--         return
--     end
--
--     local rm_index = nil
--
--     for i, t in ipairs(tags) do
--
--         -- Useful when this is called for the first time.
--         if not tag.getproperty(t, prop) then
--             tag.setproperty(t, prop, i)
--         end
--
--         if t == self then
--             table.remove(tags, i)
--             rm_index = i
--             break
--         end
--     end
--
--     table.insert(tags, idx, self)
--     for i = idx < rm_index and idx or rm_index, #tags do
--         local tmp_tag = tags[i]
--
--         if scr then
--             tag.object.set_screen(tmp_tag, scr)
--         end
--
--         tag.setproperty(tmp_tag, prop, i)
--     end
-- end

function module._get_by_name(name)
    return by_name[name]
end

--- Create a new workset.
-- @constructorfct awful.workset

local function new_workset(_, args)
    local ret = gobject {
        enable_properties = true,
    }

    -- Rather than recomputing the values all the time, `awful.workset` try to
    -- keep a coherent cache.
    rawset(ret, "_private", {
        screens         = {},
        tags_by_indices = {},
        has_screen      = {},
        tag_indices     = {},
        screen_tags     = {},
        screen_has_tags = {},
    })

    gtable.crush(ret, module, true)
    gtable.crush(ret, args)

    if (not args.tags) or #args.tags == 0 then
        ret:emit_signal("request::tags")
        module.emit_signal("request::tags", ret)
    end

    return ret
end

gobject._setup_class_signals(module)

return setmetatable(module, {__call = new_workset, __index = by_name})
