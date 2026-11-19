--!strict
-- SNACK ATTACK: the economy. Every second each player's stall pays out its coins per
-- second; the mutate machine re-rolls one stall brainrot's mutation for a fee; rebirth
-- trades a full collection and a cash target for a permanent income multiplier.
-- All three run on the server against StateService, so a client can only ask.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.RateLimiter)
local StateService = require(script.Parent.StateService)
local Validate = require(script.Parent.Validate)

local EconomyService = {}

local mutateLimiter = RateLimiter.new(2, 2)
local rebirthLimiter = RateLimiter.new(1, 5)
local random = Random.new()

local function onMutateBrainrot(player: Player, slotArg: unknown)
	if not mutateLimiter(player) then
		return
	end
	local slot = Validate.integer(slotArg, 1, Config.STALL_SLOT_COUNT)
	if not slot then
		return
	end
	local brainrot = StateService.stallBrainrotAt(player, slot)
	if not brainrot then
		Net.Toast:FireClient(player, "No brainrot on that slot to mutate.")
		return
	end
	if not StateService.spendCash(player, Config.MUTATE_FEE) then
		Net.Toast:FireClient(player, `Mutating costs ${Config.MUTATE_FEE} cash.`)
		return
	end
	local mutation = Config.rollMutateReroll(random)
	StateService.mutateSlot(player, slot, mutation)
	-- The stall display is rebuilt so its colours and label show the new mutation.
	local StallService = require(script.Parent.StallService)
	StallService.showStallBrainrot(player, slot, { characterId = brainrot.characterId, mutation = mutation, slot = slot })
	local def = Config.getCharacter(brainrot.characterId)
	if def then
		Net.Toast:FireClient(player, `{def.name} mutated into {mutation}!`)
	end
	StateService.publish(player)
end

local function onRequestRebirth(player: Player)
	if not rebirthLimiter(player) then
		return
	end
	local StallService = require(script.Parent.StallService)
	local ok, message = StateService.tryRebirth(player)
	if ok then
		-- The stall resets: every display model on it is cleared with the state.
		StallService.clearStall(player)
	end
	Net.Toast:FireClient(player, message)
end

function EconomyService.start()
	Net.MutateBrainrot.OnServerEvent:Connect(onMutateBrainrot)
	Net.RequestRebirth.OnServerEvent:Connect(onRequestRebirth)

	-- One loop pays every stall, once a second. Income is computed from state, so a
	-- client can never pay itself; the attribute update is the only per-second traffic.
	task.spawn(function()
		while true do
			task.wait(Config.INCOME_TICK_SECONDS)
			for _, player in Players:GetPlayers() do
				local income = StateService.incomePerSecond(player)
				if income > 0 then
					StateService.addCash(player, income)
				end
			end
		end
	end)
end

return EconomyService
