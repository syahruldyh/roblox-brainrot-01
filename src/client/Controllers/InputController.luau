--!strict
-- SNACK ATTACK: keyboard input. Actions are bound with ContextActionService (not
-- UserInputService.InputBegan with gameProcessedEvent, which never sees keys the
-- default camera scripts already took). Every binding calls the same action the HUD
-- buttons call, so keyboard, touch and gamepad always do the same thing.
-- Bindings are only active while the player is alive in the game, and they never fire
-- while the player is typing in a TextBox.

local ContextActionService = game:GetService("ContextActionService")

local HudController = require(script.Parent.HudController)

local InputController = {}

local function bind(actionName: string, key: Enum.KeyCode, fn: () -> ())
	ContextActionService:BindAction(actionName, function(_name, state, _input)
		if state == Enum.UserInputState.Begin then
			fn()
		end
		return Enum.ContextActionResult.Sink
	end, false, key)
end

function InputController.start()
	bind("SnackBuy", Enum.KeyCode.E, HudController.Actions.buyNearest)
	bind("SnackPlace", Enum.KeyCode.F, HudController.Actions.place)
	bind("SnackSteal", Enum.KeyCode.Q, HudController.Actions.stealNearest)
	bind("SnackLock", Enum.KeyCode.L, HudController.Actions.lock)
	bind("SnackRebirth", Enum.KeyCode.R, HudController.Actions.rebirth)
end

return InputController
