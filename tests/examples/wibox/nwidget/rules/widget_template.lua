--DOC_GEN_IMAGE --DOC_NO_USAGE
local parent    = ... --DOC_HIDE
local naughty = require("naughty") --DOC_HIDE
local ruled = {notification = require("ruled.notification")}--DOC_HIDE
local wibox = require("wibox") --DOC_HIDE
local beautiful = require("beautiful") --DOC_HIDE
local def = require("naughty.widget._default") --DOC_HIDE
local acommon = require("awful.widget.common") --DOC_HIDE
local aplace = require("awful.placement") --DOC_HIDE
local gears = require("gears") --DOC_HIDE
local cairo = require("lgi").cairo --DOC_HIDE
local gshape = require("gears.shape") --DOC_HIDE

beautiful.notification_bg = beautiful.bg_normal --DOC_HIDE

   ruled.notification.connect_signal("request::rules", function()
       -- Add a red background for urgent notifications.
       ruled.notification.append_rule {
           rule       = { app_name = "mdp" },
           properties = {
               widget_template = {
                   {
                       {
                           {
                               {
                                   naughty.widget.icon,
                                   {
                                       naughty.widget.title,
                                       naughty.widget.message,
                                       spacing = 4,
                                       layout  = wibox.layout.fixed.vertical,
                                   },
                                   fill_space = true,
                                   spacing    = 4,
                                   layout     = wibox.layout.fixed.horizontal,
                               },
                               naughty.list.actions,
                               spacing = 10,
                               layout  = wibox.layout.fixed.vertical,
                           },
                           margins = beautiful.notification_margin,
                           widget  = wibox.container.margin,
                       },
                       id     = "background_role",
                       widget = naughty.container.background,
                   },
                   strategy = "max",
                   width    = 160,
                   widget   = wibox.container.constraint,
               }
           }
       }
   end)

awesome.emit_signal("startup") --DOC_HIDE

--DOC_HIDE let's have some fun.
local helmet = cairo.ImageSurface(cairo.Format.ARGB32, 128, 128) --DOC_HIDE
local cr = cairo.Context(img) --DOC_HIDE

cr:set_source_rgb(1, 0, 0) --DOC_HIDE
cr:move_to(20, 90) --DOC_HIDE
gshape.rounded_rect(cr, 80, 20) --DOC_HIDE
cr:fill() --DOC_HIDE

helmet:finish() --DOC_HIDE

local notif2 =  --DOC_HIDE
   naughty.notification {  --DOC_HIDE
       title     = "Daft Punk",  --DOC_HIDE
       message   = "Harder, Better, Faster, Stronger",  --DOC_HIDE
       icon      = helmet,  --DOC_HIDE
       icon_size = 128,  --DOC_HIDE
       app_name  = "mdp",  --DOC_HIDE
   }  --DOC_HIDE

assert(notif2.app_name == "mdp") --DOC_HIDE

local function show_notification(n) --DOC_HIDE
    local default = wibox.widget(def) --DOC_HIDE
    acommon._set_common_property(default, "notification", n) --DOC_HIDE
    parent:add(default) --DOC_HIDE
end --DOC_HIDE

parent.spacing = 10 --DOC_HIDE
show_notification(notif2) --DOC_HIDE
