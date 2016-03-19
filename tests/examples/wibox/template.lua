local file_path, image_path = ...

local gears_obj = require("gears.object")

-- Set the global shims
awesome = require( "awesome" )
client  = require( "client"  )
tag     = require( "tag"     )

local wibox = require("wibox")
local GLib  = require("lgi").require("GLib")

-- Unless there is some kind of shim for that, the Awesome mainloop need to be
-- emulated.
local main_loop = GLib.MainLoop()

-- This is the main widget the tests will use as top level
local container = wibox.layout.fixed.vertical()

-- Let the test request a size and file format
local w, h, image_type = loadfile(file_path)(container)
image_type = image_type or "svg"

-- Emulate 10 cycles of mainloop
local counter = 1

local main_loop_callback

-- Loop as fast as possible
GLib.timeout_add_seconds(0, 0,function()
    -- Emulate capi.awesome mainloop signal. Otherwise gears.timer wont work
    awesome:emit_signal("refresh")

    counter = counter + 1
    if counter < 10 then
        return true
    else
        -- Get the example fallback size (the tests can return a size if the want)
        local f_w, f_h = container:fit({dpi=96}, 9999, 9999)

        -- There is an overhead that cause testbox "...", add 10 until someone
        -- figures out the real equation
        f_w, f_h = f_w+10, f_h+10

        -- Save to the output file
        container["to_"..image_type](container, image_path.."."..image_type, w or f_w, h or f_h)

        -- Quit normally, else the .svg are going to be empty
        main_loop:quit()
        return false
    end
end)

-- Start the main loop
main_loop:run()
