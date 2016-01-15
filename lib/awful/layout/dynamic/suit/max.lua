---------------------------------------------------------------------------
--- A layout with clients on top of each other filling all the space
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.layout.dynamic.suit.max
---------------------------------------------------------------------------

local dynamic = require( "awful.layout.dynamic.base"       )
local stack   = require( "awful.layout.dynamic.base_stack" )

local module = dynamic.register("max", function(t) return stack(false) end)

module.fullscreen = dynamic.register("fullscreen", function(t) return stack(true) end)

return module