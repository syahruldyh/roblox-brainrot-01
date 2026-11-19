--!strict
-- SNACK ATTACK: client entry point. One LocalScript; the controllers do the work.
-- The HUD is built first so the other controllers can find it, then input, then
-- effects. The client never owns game state: it renders what the server publishes
-- and fires intents at the server's remotes.

local EffectsController = require(script.Parent.Controllers.EffectsController)
local HudController = require(script.Parent.Controllers.HudController)
local InputController = require(script.Parent.Controllers.InputController)

HudController.start()
InputController.start()
EffectsController.start()

print("SNACK ATTACK client ready.")
