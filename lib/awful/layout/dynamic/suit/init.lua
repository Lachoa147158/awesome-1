--- Stateful layouts. Some layouts provided by this module are direct
-- equivalent of stateless ones while some other are new.
--
-- These layouts are not intended to replace sateless ones. Many
-- `awful.layout.suit`, such as spiral, would not benefit from being stateful
--
-- Stateful layouts require more memory and carry a larger overhead.

return {
    tile     = require("awful.layout.dynamic.suit.tile"),
    fair     = require("awful.layout.dynamic.suit.fair"),
    treesome = require("awful.layout.dynamic.suit.treesome")
}