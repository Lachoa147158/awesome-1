--- Replace the stateless tile

local dynamic = require( "awful.layout.dynamic.base"       )
local stack   = require( "awful.layout.dynamic.base_stack" )

local module = dynamic.register("max", function(t) return stack(false) end)

module.fullscreen = dynamic.register("fullscreen", function(t) return stack(true) end)

return module