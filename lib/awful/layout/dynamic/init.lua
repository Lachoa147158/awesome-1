---------------------------------------------------------------------------
--- A drop-in replacment for the stateless layout suits
--
-- This system also add the possibility to write handlers enabling the use
-- of tabs, spliters or custom client recorator.
--
-- Any wibox.layout compliant layout can be implemented. Monkey-patching
-- `awful.layout.dynamic.wrapper` also allow modules to define extra features
-- for tiled clients.
--
-- @author Emmanuel Lepage Vallee &lt;elv1313@gmail.com&gt;
-- @copyright 2016 Emmanuel Lepage Vallee
-- @release @AWESOME_VERSION@
-- @module awful.layout.hierarchy
---------------------------------------------------------------------------

local suits = {
    base = require("awful.layout.dynamic.base"),
    suit = require("awful.layout.dynamic.suit")
}

return suits