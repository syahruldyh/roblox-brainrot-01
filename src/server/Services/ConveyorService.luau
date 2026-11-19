--!strict
-- SNACK ATTACK: the conveyor belt. Brainrots walk from west to east along the belt and
-- despawn at the end; a player who walks up and buys one carries it home. The belt is
-- the game's shop window: the walker models and their labels are built by
-- CharacterFactory from Config, and every buy is validated here on the server
-- (rate limit, real walker, standing close enough, hands empty, stall room, cash).
-- Walkers are anchored models moved with PivotTo on Heartbeat, one loop for all of them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CharacterFactory = require(script.Parent.CharacterFactory)
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local RateLimiter = require(script.Parent.RateLimiter)
local StateService = require(script.Parent.StateService)
local Types = require(ReplicatedStorage.Shared.Types)
local Validate = require(script.Parent.Validate)

local ConveyorService = {}

type Walker = {
	id: string,
	def: any,
	mutation: string,
	model: Model,
	x: number,
}

local walkers: { [string]: Walker } = {}
local walkerCount = 0
local nextWalkerId = 0
local buyLimiter = RateLimiter.new(2, 2) -- at most 2 buys per 2 seconds per player
local random = Random.new()

-- Pity: spawns since the last Epic-or-better brainrot walked the belt. At the
-- threshold the next spawn is guaranteed Epic or better, so an unlucky streak still
-- progresses. Broadcast to every HUD on every spawn.
local pityCount = 0

local function broadcastPity()
	Net.PityChanged:FireAllClients(pityCount, Config.PITY.threshold)
end

-- Weighted pick among Epic and up, for a pity spawn.
local function rollEpicOrBetter(): Types.RarityName
	local roll = random:NextInteger(1, 100)
	if roll <= 60 then
		return "Epic"
	elseif roll <= 85 then
		return "Legendary"
	elseif roll <= 97 then
		return "Mythic"
	else
		return "Brainrot"
	end
end

local function walkerPosition(x: number): CFrame
	return CFrame.new(x, Config.CONVEYOR.topY, Config.CONVEYOR.z)
end

-- forceRarity/forceId pin a spawn: the very first walker is always the cheapest
-- Common, so a new player can buy within 10 seconds of spawning with starting cash.
local function spawnWalker(forceRarity: Types.RarityName?, forceId: string?)
	if walkerCount >= Config.CONVEYOR.maxWalkers then
		return
	end
	local rarity: Types.RarityName
	if forceRarity then
		rarity = forceRarity
	elseif pityCount >= Config.PITY.threshold then
		rarity = rollEpicOrBetter()
	else
		rarity = Config.rollRarity(random)
	end
	local def: Types.CharacterDef
	if forceId then
		def = Config.getCharacter(forceId) :: Types.CharacterDef
	else
		def = Config.randomCharacterOfRarity(rarity, random)
	end
	local mutation = Config.rollMutation(random)

	if rarity == "Epic" or rarity == "Legendary" or rarity == "Mythic" or rarity == "Brainrot" then
		pityCount = 0
	else
		pityCount += 1
	end
	broadcastPity()

	nextWalkerId += 1
	local id = `walker-{nextWalkerId}`
	local model = CharacterFactory.build(def, mutation)
	model:SetAttribute("WalkerId", id) -- the HUD reads this to buy the nearest walker
	CharacterFactory.attachLabel(model, def, mutation, true)
	model:PivotTo(walkerPosition(Config.CONVEYOR.startX))
	model.Parent = workspace

	walkers[id] = { id = id, def = def, mutation = mutation, model = model, x = Config.CONVEYOR.startX }
	walkerCount += 1
end

local function removeWalker(id: string)
	local walker = walkers[id]
	if not walker then
		return
	end
	walker.model:Destroy()
	walkers[id] = nil
	walkerCount -= 1
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

local function onBuyBrainrot(player: Player, walkerId: unknown)
	if not buyLimiter(player) then
		return
	end
	local id = Validate.string(walkerId, 64)
	if not id then
		return
	end
	local walker = walkers[id]
	if not walker then
		return
	end
	local state = StateService.getState(player)
	if not state then
		return
	end
	if StateService.getCarrying(player) then
		Net.Toast:FireClient(player, "Hands full — place your brainrot on your stall first!")
		return
	end
	if not StateService.freeSlot(player) then
		Net.Toast:FireClient(player, "Your stall is full (6/6). Rebirth to clear it!")
		return
	end
	local root = characterRoot(player)
	if not root then
		return
	end
	local walkerPivot = walker.model:GetPivot()
	if (root.Position - walkerPivot.Position).Magnitude > Config.BUY.reachStuds then
		Net.Toast:FireClient(player, "Get closer to the conveyor to buy!")
		return
	end
	if not StateService.spendCash(player, walker.def.price) then
		Net.Toast:FireClient(player, `Not enough cash — {walker.def.name} costs ${walker.def.price}.`)
		return
	end

	removeWalker(id)
	StateService.setCarrying(player, {
		characterId = walker.def.id,
		mutation = walker.mutation,
		fromPlayer = nil,
	})

	local carried = CharacterFactory.build(walker.def, walker.mutation)
	carried.Name = "CarriedBrainrot"
	CharacterFactory.attachCarried(carried, player.Character)
	Net.Toast:FireClient(player, `Bought {walker.def.name}! Carry it to your stall and press PLACE.`)
	StateService.publish(player)
end

function ConveyorService.start()
	Net.BuyBrainrot.OnServerEvent:Connect(onBuyBrainrot)

	-- Walkers drift east on Heartbeat; one connection moves all of them.
	RunService.Heartbeat:Connect(function(deltaTime: number)
		local step = Config.CONVEYOR.walkSpeed * deltaTime
		local finished: { string } = {}
		for id, walker in walkers do
			walker.x += step
			if walker.x >= Config.CONVEYOR.endX then
				table.insert(finished, id)
			else
				walker.model:PivotTo(walkerPosition(walker.x))
			end
		end
		for _, id in finished do
			removeWalker(id)
		end
	end)

	-- A fresh walker rolls onto the belt on a steady timer.
	task.spawn(function()
		while true do
			task.wait(Config.CONVEYOR.spawnIntervalSeconds)
			spawnWalker()
		end
	end)

	-- The first walker is always the cheapest Common, so a new player can buy within
	-- 10 seconds of spawning; the second is a normal roll. The belt never opens empty.
	spawnWalker("Common", "sir-fries-a-lot")
	spawnWalker()
end

return ConveyorService
