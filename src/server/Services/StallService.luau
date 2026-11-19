--!strict
-- SNACK ATTACK: the stalls. Each player owns one market stall (a pad in the world);
-- this service draws the brainrots sitting on it, places a carried brainrot when its
-- owner stands on the stall, runs the base lock, and runs stealing: a thief who stands
-- at an unlocked victim's stall can take one brainrot and must carry it home.
-- Every steal is validated on the server: the victim's lock, the thief's hands and
-- stall room, the distance from the thief's server-side character to the victim stall,
-- and a per-thief cooldown. The victim and the thief both get a toast.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterFactory = require(script.Parent.CharacterFactory)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.RateLimiter)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)
local Validate = require(script.Parent.Validate)

local StallService = {}

-- Display models sitting on stalls, keyed by owner then slot. The state module owns
-- the logical stall; this table only mirrors it with visible models.
local stallModels: { [Player]: { [number]: Model } } = {}
local lastStealAttempt: { [Player]: number } = {}
local placeLimiter = RateLimiter.new(2, 2)
local stealLimiter = RateLimiter.new(2, 2)
local lockLimiter = RateLimiter.new(2, 5)

local function stallCenter(stallName: string): Vector3?
	for _, stall in Config.STALLS do
		if stall.name == stallName then
			return stall.center
		end
	end
	return nil
end

local function slotWorldPosition(stallName: string, slot: number): Vector3?
	local center = stallCenter(stallName)
	local offset = Config.STALL_SLOTS[slot]
	if not center or not offset then
		return nil
	end
	return center + Vector3.new(offset.X, 0.5, offset.Z)
end

local function characterRoot(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- True when the player's character stands on their own stall pad.
function StallService.isOnOwnStall(player: Player): boolean
	local state = StateService.getState(player)
	local root = characterRoot(player)
	if not state or not root then
		return false
	end
	local center = stallCenter(state.stallName)
	if not center then
		return false
	end
	local delta = root.Position - center
	return Vector2.new(delta.X, delta.Z).Magnitude <= 8
end

function StallService.showStallBrainrot(player: Player, slot: number, brainrot: Types.StallBrainrot)
	local state = StateService.getState(player)
	if not state then
		return
	end
	local def = Config.getCharacter(brainrot.characterId)
	local position = slotWorldPosition(state.stallName, slot)
	if not def or not position then
		return
	end
	StallService.clearStallSlot(player, slot)
	local model = CharacterFactory.build(def, brainrot.mutation)
	model:SetAttribute("StallName", state.stallName) -- the HUD reads this to steal a slot
	model:SetAttribute("Slot", slot)
	CharacterFactory.attachLabel(model, def, brainrot.mutation, false)
	model:PivotTo(CFrame.new(position))
	model.Parent = workspace
	local perPlayer = stallModels[player]
	if not perPlayer then
		perPlayer = {}
		stallModels[player] = perPlayer
	end
	perPlayer[slot] = model
end

function StallService.clearStallSlot(player: Player, slot: number)
	local perPlayer = stallModels[player]
	if not perPlayer then
		return
	end
	local model = perPlayer[slot]
	if model then
		model:Destroy()
		perPlayer[slot] = nil
	end
end

function StallService.clearStall(player: Player)
	local perPlayer = stallModels[player]
	if not perPlayer then
		return
	end
	for slot, model in perPlayer do
		model:Destroy()
		perPlayer[slot] = nil
	end
end

-- Give a player a carried brainrot model (used after a buy and after a steal).
local function giveCarriedModel(player: Player, characterId: string, mutation: Types.MutationName)
	local def = Config.getCharacter(characterId)
	if not def then
		return
	end
	local carried = CharacterFactory.build(def, mutation)
	carried.Name = "CarriedBrainrot"
	CharacterFactory.attachCarried(carried, player.Character)
end

-- Drop what a player is carrying: the brainrot goes back to the stall it came from
-- (the victim's, when stolen) or to the carrier's own stall (when bought). When that
-- stall is full the brainrot is lost to the market.
function StallService.dropCarried(player: Player, reason: string)
	local carried = StateService.getCarrying(player)
	if not carried then
		return
	end
	local model = CharacterFactory.findCarriedModel(player.Character)
	if model then
		model:Destroy()
	end
	StateService.setCarrying(player, nil)

	local home: Player? = carried.fromPlayer or player
	local def = Config.getCharacter(carried.characterId)
	if home and def then
		local slot = StateService.placeBrainrot(home, carried.characterId, carried.mutation)
		if slot then
			StallService.showStallBrainrot(home, slot, { characterId = carried.characterId, mutation = carried.mutation, slot = slot })
			Net.Toast:FireClient(home, `{def.name} made it back to your stall.`)
		else
			Net.Toast:FireClient(home, `{def.name} was lost — your stall was full!`)
		end
	end
	Net.Toast:FireClient(player, reason)
	StateService.publish(player)
end

local function onPlaceBrainrot(player: Player)
	if not placeLimiter(player) then
		return
	end
	local carried = StateService.getCarrying(player)
	if not carried then
		return
	end
	if not StallService.isOnOwnStall(player) then
		Net.Toast:FireClient(player, "Stand on your own stall to place it!")
		return
	end
	local model = CharacterFactory.findCarriedModel(player.Character)
	if model then
		model:Destroy()
	end
	local slot = StateService.placeBrainrot(player, carried.characterId, carried.mutation)
	if not slot then
		Net.Toast:FireClient(player, "Your stall is full (6/6)!")
		return
	end
	StateService.setCarrying(player, nil)
	local def = Config.getCharacter(carried.characterId)
	StallService.showStallBrainrot(player, slot, { characterId = carried.characterId, mutation = carried.mutation, slot = slot })
	if def then
		local rate = def.rate * Config.MUTATIONS[carried.mutation].multiplier
		Net.Toast:FireClient(player, `{def.name} is on your stall, earning ${rate}/s!`)
	end
	StateService.publish(player)
end

local function onStealBrainrot(player: Player, ownerUserId: unknown, slotArg: unknown)
	if not stealLimiter(player) then
		return
	end
	local userId = Validate.integer(ownerUserId, 1, 9999999999)
	local slot = Validate.integer(slotArg, 1, Config.STALL_SLOT_COUNT)
	if not userId or not slot then
		return
	end
	local now = os.clock()
	if now - (lastStealAttempt[player] or 0) < Config.STEAL.stealCooldownSeconds then
		return
	end
	lastStealAttempt[player] = now

	local victim = Players:GetPlayerByUserId(userId)
	if not victim or victim == player then
		return
	end
	local brainrot = StateService.stallBrainrotAt(victim, slot)
	if not brainrot then
		return
	end
	if StateService.isBaseLocked(victim) then
		Net.Toast:FireClient(player, "That stall is LOCKED. Wait for the lock to run out!")
		return
	end
	if StateService.getCarrying(player) then
		Net.Toast:FireClient(player, "Hands full — place your brainrot first!")
		return
	end
	if not StateService.freeSlot(player) then
		Net.Toast:FireClient(player, "Your stall is full (6/6). No room for stolen goods!")
		return
	end
	local victimState = StateService.getState(victim)
	local root = characterRoot(player)
	if not victimState or not root then
		return
	end
	local center = stallCenter(victimState.stallName)
	if not center then
		return
	end
	local delta = root.Position - center
	if Vector2.new(delta.X, delta.Z).Magnitude > Config.STEAL.reachStuds then
		Net.Toast:FireClient(player, "Get closer to that stall to steal!")
		return
	end

	local taken = StateService.takeBrainrot(victim, slot)
	if not taken then
		return
	end
	StallService.clearStallSlot(victim, slot)
	StateService.setCarrying(player, {
		characterId = taken.characterId,
		mutation = taken.mutation,
		fromPlayer = victim,
	})
	giveCarriedModel(player, taken.characterId, taken.mutation)

	local def = Config.getCharacter(taken.characterId)
	if def then
		Net.Toast:FireClient(player, `You stole {def.name}! RUN home before the Inspector catches you!`)
		Net.Toast:FireClient(victim, `{player.Name} stole your {def.name}!`)
	end
	StateService.publish(player)
	StateService.publish(victim)
end

local function onLockBase(player: Player)
	if not lockLimiter(player) then
		return
	end
	local ok, message = StateService.lockBase(player)
	Net.Toast:FireClient(player, message)
	if ok then
		-- Publish the lock on the stall pad itself, so nearby players' HUDs can see
		-- the stall is locked before they walk over to steal.
		local state = StateService.getState(player)
		if state then
			local market = workspace:FindFirstChild("Market")
			local stalls = market and market:FindFirstChild("Stalls")
			local stall = stalls and stalls:FindFirstChild(state.stallName)
			local pad = stall and stall:FindFirstChild("Pad")
			if pad then
				pad:SetAttribute("LockUntil", player:GetAttribute("SnackLockUntil"))
			end
		end
	end
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid") :: Humanoid
	humanoid.Died:Connect(function()
		-- Dying while carrying drops the haul back to its home stall.
		if StateService.getCarrying(player) then
			StallService.dropCarried(player, "You dropped your brainrot!")
		end
	end)
end

function StallService.start()
	Net.PlaceBrainrot.OnServerEvent:Connect(onPlaceBrainrot)
	Net.StealBrainrot.OnServerEvent:Connect(onStealBrainrot)
	Net.LockBase.OnServerEvent:Connect(onLockBase)

	Players.PlayerAdded:Connect(function(player)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		StallService.clearStall(player)
		stallModels[player] = nil
		lastStealAttempt[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
	end
end

return StallService
