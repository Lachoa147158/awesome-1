local gears_obj = require("gears.object")

local function convert_singleton(obj)
    obj._connect_signal = obj.connect_signal
    function obj.connect_signal(name, func)
        return obj._connect_signal(obj, name, func)
    end
    obj.weak_connect_signal = obj.connect_signal

    return obj
end

local awesome = convert_singleton(gears_obj())

awesome:add_signal("refresh")
awesome:add_signal("wallpaper_changed")

return awesome
