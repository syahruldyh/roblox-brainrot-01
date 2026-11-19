--!strict
-- SNACK ATTACK: server entry point. One Script, everything else a ModuleScript.
-- It wires the services in dependency order (state first, then the world systems),
-- gives every joining player a stall and a starting balance, and puts their name on
-- their stall's sign so the market reads as a row of owned shops.

local Players = game:GetService("Players")

local CharacterFactory = require(script.Parent.Services.CharacterFactory)
local ConveyorService = require(script.Parent.Services.ConveyorService)
local EconomyService = require(script.Parent.Services.EconomyService)
local InspectorService = require(script.Parent.Services.InspectorService)
local StallService = require(script.Parent.Services.StallService)
local StateService = require(script.Parent.Services.StateService)

local function stallSignPart(stallName: string): BasePart?
	local market = workspace:FindFirstChild("Market")
	local stalls = market and market:FindFirstChild("Stalls")
	local stall = stalls and stalls:FindFirstChild(stallName)
	local sign = stall and stall:FindFirstChild("Sign")
	if sign and sign:IsA("BasePart") then
		return sign
	end
	return nil
end

local function onPlayerAdded(player: Player)
	local state = StateService.setupPlayer(player)
	local sign = stallSignPart(state.stallName)
	if sign then
		CharacterFactory.attachStallSign(sign, player.Name)
	end
	-- Stamp the owner on the stall pad, so other players' HUDs can tell whose stall
	-- they are standing at (and whether it is locked).
	local market = workspace:FindFirstChild("Market")
	local stalls = market and market:FindFirstChild("Stalls")
	local stall = stalls and stalls:FindFirstChild(state.stallName)
	local pad = stall and stall:FindFirstChild("Pad")
	if pad then
		pad:SetAttribute("OwnerUserId", player.UserId)
	end
end

-- The world systems start first, so the belt is already walking when the first
-- player spawns in.
ConveyorService.start()
StallService.start()
EconomyService.start()
InspectorService.start()

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

print("SNACK ATTACK server ready: 14 brainrots, 8 stalls, 1 conveyor, 1 inspector.")
