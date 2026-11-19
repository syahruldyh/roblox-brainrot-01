--!strict
-- SNACK ATTACK: the ONE state module. Every piece of authoritative per-player state lives
-- here and only here: cash, the brainrots on the stall, the collection index, what the
-- player is carrying, the base lock, and the rebirth count. Other services never write
-- these tables directly; they call StateService functions, so there is exactly one place
-- where an exploit could ever matter, and it is all server-side.
-- Cash and income are also published as attributes on the Player ("SnackCash",
-- "SnackIncome", "SnackLockUntil") so the HUD can listen without a remote round-trip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)

export type Carried = {
	characterId: string,
	mutation: Types.MutationName,
	fromPlayer: Player?, -- who it was stolen from, nil when bought fresh off the belt
}

export type PlayerState = {
	cash: number,
	stall: { [number]: Types.StallBrainrot }, -- slot number -> brainrot on that slot
	stallName: string,
	collection: { [string]: boolean }, -- character ids ever owned
	carrying: Carried?,
	lockUntil: number, -- server-time timestamp, 0 when unlocked
	lockCooldownUntil: number,
	rebirths: number,
}

local StateService = {}

local states: { [Player]: PlayerState } = {}
local stallOwners: { [string]: Player } = {}

local function rebirthMultiplier(rebirths: number): number
	return Config.REBIRTH.multiplierPerRebirth ^ rebirths
end

function StateService.getState(player: Player): PlayerState?
	return states[player]
end

function StateService.getStallName(player: Player): string?
	local state = states[player]
	return state and state.stallName or nil
end

function StateService.getPlayerByStall(stallName: string): Player?
	return stallOwners[stallName]
end

function StateService.setupPlayer(player: Player): PlayerState
	-- First free stall, in config order, becomes this player's market stall.
	local stallName = ""
	for _, stall in Config.STALLS do
		if stallOwners[stall.name] == nil then
			stallName = stall.name
			break
		end
	end
	if stallName == "" then
		stallName = Config.STALLS[1].name -- full server: share stall 1's pad
	end
	stallOwners[stallName] = player

	local state: PlayerState = {
		cash = Config.STARTING_CASH,
		stall = {},
		stallName = stallName,
		collection = {},
		carrying = nil,
		lockUntil = 0,
		lockCooldownUntil = 0,
		rebirths = 0,
	}
	states[player] = state
	StateService.publish(player)
	return state
end

function StateService.teardownPlayer(player: Player)
	local state = states[player]
	if state then
		stallOwners[state.stallName] = nil
	end
	states[player] = nil
end

function StateService.getCash(player: Player): number
	local state = states[player]
	return state and state.cash or 0
end

-- Positive amounts only; clamps at the economy ceiling. Returns the new balance.
function StateService.addCash(player: Player, amount: number): number?
	local state = states[player]
	if not state or not math.isfinite(amount) or amount <= 0 then
		return nil
	end
	state.cash = math.min(state.cash + math.floor(amount), Config.MAX_CASH)
	StateService.publishCash(player)
	return state.cash
end

-- Atomic check-and-spend. False when the player cannot afford it; the balance is
-- untouched in that case, so a failed buy can never half-charge.
function StateService.spendCash(player: Player, amount: number): boolean
	local state = states[player]
	if not state or not math.isfinite(amount) or amount <= 0 then
		return false
	end
	amount = math.floor(amount)
	if state.cash < amount then
		return false
	end
	state.cash -= amount
	StateService.publishCash(player)
	return true
end

function StateService.incomePerSecond(player: Player): number
	local state = states[player]
	if not state then
		return 0
	end
	local total = 0
	for _, brainrot in state.stall do
		local def = Config.getCharacter(brainrot.characterId)
		if def then
			total += def.rate * Config.MUTATIONS[brainrot.mutation].multiplier
		end
	end
	return math.floor(total * rebirthMultiplier(state.rebirths))
end

function StateService.freeSlot(player: Player): number?
	local state = states[player]
	if not state then
		return nil
	end
	for slot = 1, Config.STALL_SLOT_COUNT do
		if state.stall[slot] == nil then
			return slot
		end
	end
	return nil
end

-- Put a brainrot on the first free stall slot. Returns the slot, or nil when full.
function StateService.placeBrainrot(player: Player, characterId: string, mutation: Types.MutationName): number?
	local state = states[player]
	if not state then
		return nil
	end
	local slot = StateService.freeSlot(player)
	if not slot then
		return nil
	end
	state.stall[slot] = { characterId = characterId, mutation = mutation, slot = slot }
	StateService.addToCollection(player, characterId)
	StateService.publish(player)
	return slot
end

-- Take a brainrot off a stall slot (steal, or clearing for a rebirth). Returns it, or nil.
function StateService.takeBrainrot(player: Player, slot: number): Types.StallBrainrot?
	local state = states[player]
	if not state then
		return nil
	end
	local brainrot = state.stall[slot]
	if not brainrot then
		return nil
	end
	state.stall[slot] = nil
	StateService.publish(player)
	return brainrot
end

function StateService.stallBrainrotAt(player: Player, slot: number): Types.StallBrainrot?
	local state = states[player]
	return state and state.stall[slot] or nil
end

function StateService.stallCount(player: Player): number
	local state = states[player]
	if not state then
		return 0
	end
	local count = 0
	for _ in state.stall do
		count += 1
	end
	return count
end

function StateService.addToCollection(player: Player, characterId: string)
	local state = states[player]
	if state then
		state.collection[characterId] = true
	end
end

function StateService.hasRarityInCollection(player: Player, rarity: Types.RarityName): boolean
	local state = states[player]
	if not state then
		return false
	end
	for id in state.collection do
		local def = Config.getCharacter(id)
		if def and def.rarity == rarity then
			return true
		end
	end
	return false
end

function StateService.raritiesInCollection(player: Player): number
	local count = 0
	for _, rarity in Config.RARITY_ORDER do
		if StateService.hasRarityInCollection(player, rarity) then
			count += 1
		end
	end
	return count
end

function StateService.setCarrying(player: Player, carried: Carried?)
	local state = states[player]
	if state then
		state.carrying = carried
		StateService.publish(player)
	end
end

function StateService.getCarrying(player: Player): Carried?
	local state = states[player]
	return state and state.carrying or nil
end

-- Lock this player's stall so nobody can steal from it. Returns success + a reason
-- string for the toast when it fails.
function StateService.lockBase(player: Player): (boolean, string)
	local state = states[player]
	if not state then
		return false, "No stall yet."
	end
	local now = workspace:GetServerTimeNow()
	if now < state.lockCooldownUntil then
		return false, `Lock recharges in {math.ceil(state.lockCooldownUntil - now)}s.`
	end
	if now < state.lockUntil then
		return false, "Your stall is already locked."
	end
	if state.cash < Config.LOCK.fee then
		return false, `Lock costs ${Config.LOCK.fee} cash.`
	end
	if not StateService.spendCash(player, Config.LOCK.fee) then
		return false, `Lock costs ${Config.LOCK.fee} cash.`
	end
	state.lockUntil = now + Config.LOCK.durationSeconds
	state.lockCooldownUntil = state.lockUntil + Config.LOCK.cooldownSeconds
	StateService.publish(player)
	return true, `Stall locked for {Config.LOCK.durationSeconds}s! (-${Config.LOCK.fee})`
end

function StateService.isBaseLocked(player: Player): boolean
	local state = states[player]
	if not state then
		return false
	end
	return workspace:GetServerTimeNow() < state.lockUntil
end

-- Rebirth: requires every rarity in the collection and the cash target. Resets the
-- cash and the stall, keeps the collection, and raises the income multiplier forever.
function StateService.tryRebirth(player: Player): (boolean, string)
	local state = states[player]
	if not state then
		return false, "No stall yet."
	end
	if StateService.raritiesInCollection(player) < Config.REBIRTH.raritiesRequired then
		return false, `Rebirth needs all {Config.REBIRTH.raritiesRequired} rarities in your collection.`
	end
	if state.cash < Config.REBIRTH.cashRequired then
		return false, `Rebirth needs ${Config.REBIRTH.cashRequired} cash.`
	end
	state.rebirths += 1
	state.cash = Config.STARTING_CASH
	state.stall = {}
	state.carrying = nil
	StateService.publish(player)
	return true, `REBIRTH {state.rebirths}! Income x{string.format("%.2f", rebirthMultiplier(state.rebirths))} forever.`
end

function StateService.mutateSlot(player: Player, slot: number, mutation: Types.MutationName): boolean
	local state = states[player]
	if not state then
		return false
	end
	local brainrot = state.stall[slot]
	if not brainrot then
		return false
	end
	brainrot.mutation = mutation
	StateService.publish(player)
	return true
end

function StateService.snapshot(player: Player): Types.PlayerSnapshot?
	local state = states[player]
	if not state then
		return nil
	end
	local collection = {}
	for id in state.collection do
		table.insert(collection, id)
	end
	return {
		cash = state.cash,
		income = StateService.incomePerSecond(player),
		rebirths = state.rebirths,
		rebirthMultiplier = rebirthMultiplier(state.rebirths),
		collection = collection,
		stallCount = StateService.stallCount(player),
		lockUntil = state.lockUntil,
		lockCooldownUntil = state.lockCooldownUntil,
		carryingId = state.carrying and state.carrying.characterId or nil,
	}
end

-- Cheap replicated values the HUD listens to; the full snapshot goes by remote.
function StateService.publishCash(player: Player)
	local state = states[player]
	if not state then
		return
	end
	player:SetAttribute("SnackCash", state.cash)
	player:SetAttribute("SnackIncome", StateService.incomePerSecond(player))
	player:SetAttribute("SnackLockUntil", state.lockUntil)
end

function StateService.publish(player: Player)
	StateService.publishCash(player)
	local snapshot = StateService.snapshot(player)
	if snapshot then
		Net.StateChanged:FireClient(player, snapshot)
	end
end

Players.PlayerRemoving:Connect(function(player)
	StateService.teardownPlayer(player)
end)

return StateService
