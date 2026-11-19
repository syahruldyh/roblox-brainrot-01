--!strict
-- SNACK ATTACK: the Health Inspector. Every cycle the market is calm, then a 30-second
-- warning counts down on every HUD, then the Inspector sweeps west to east across the
-- plaza. Any player carrying a brainrot who is caught outside their own stall when the
-- front passes them drops the haul: it goes back to the stall it came from.
-- The sweep is a big white figure built from parts, moved with PivotTo, so every client
-- sees the same threat at the same place. The phase and the seconds left are broadcast
-- so the HUD never has to guess.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local StateService = require(script.Parent.StateService)

local InspectorService = {}

local function stallCenter(stallName: string): Vector3?
	for _, stall in Config.STALLS do
		if stall.name == stallName then
			return stall.center
		end
	end
	return nil
end

local function isOnOwnStall(player: Player): boolean
	local state = StateService.getState(player)
	local character = player.Character
	if not state or not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local center = stallCenter(state.stallName)
	if not root or not center then
		return false
	end
	local delta = root.Position - center
	return Vector2.new(delta.X, delta.Z).Magnitude <= 8
end

-- The Inspector himself: a tall white figure with a clipboard, built from parts.
local function buildInspector(): Model
	local model = Instance.new("Model")
	model.Name = "HealthInspector"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Block
	body.Size = Vector3.new(3, 5, 2)
	body.CFrame = CFrame.new(0, 2.5, 0)
	body.Color = Color3.fromRGB(250, 250, 250)
	body.Material = Enum.Material.SmoothPlastic
	body.Anchored = true
	body.CanCollide = false
	body.CanTouch = false
	body.CanQuery = false
	body.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(2.2, 2.2, 2.2)
	head.CFrame = CFrame.new(0, 6, 0)
	head.Color = Color3.fromRGB(255, 220, 180)
	head.Material = Enum.Material.SmoothPlastic
	head.Anchored = true
	head.CanCollide = false
	head.CanTouch = false
	head.CanQuery = false
	head.Parent = model

	local hat = Instance.new("Part")
	hat.Name = "Hat"
	hat.Shape = Enum.PartType.Cylinder
	hat.Size = Vector3.new(0.5, 2.8, 2.8)
	hat.CFrame = CFrame.new(0, 7.2, 0)
	hat.Color = Color3.fromRGB(30, 30, 40)
	hat.Material = Enum.Material.SmoothPlastic
	hat.Anchored = true
	hat.CanCollide = false
	hat.CanTouch = false
	hat.CanQuery = false
	hat.Parent = model

	local board = Instance.new("Part")
	board.Name = "Clipboard"
	board.Shape = Enum.PartType.Block
	board.Size = Vector3.new(1.2, 1.6, 0.2)
	board.CFrame = CFrame.new(1.8, 3, 0.5)
	board.Color = Color3.fromRGB(150, 100, 50)
	board.Material = Enum.Material.Wood
	board.Anchored = true
	board.CanCollide = false
	board.CanTouch = false
	board.CanQuery = false
	board.Parent = model

	model.PrimaryPart = body
	return model
end

local function broadcast(phase: string, secondsLeft: number)
	Net.InspectorChanged:FireAllClients(phase, secondsLeft)
end

function InspectorService.start()
	task.spawn(function()
		local inspector = buildInspector()
		local sweeping = false
		local frontX = Config.INSPECTOR.startX

		-- One Heartbeat connection moves the Inspector while a sweep runs, and checks
		-- every carrier against the front line.
		RunService.Heartbeat:Connect(function(deltaTime: number)
			if not sweeping then
				return
			end
			frontX += (Config.INSPECTOR.endX - Config.INSPECTOR.startX) / Config.INSPECTOR.sweepSeconds * deltaTime
			inspector:PivotTo(CFrame.new(frontX, 0, Config.INSPECTOR.pathZ))
			for _, player in Players:GetPlayers() do
				if not StateService.getCarrying(player) then
					continue
				end
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root then
					continue
				end
				if math.abs(root.Position.X - frontX) > Config.INSPECTOR.catchRadius then
					continue
				end
				if isOnOwnStall(player) then
					continue -- safe at home: the sweep passes the stall by
				end
				local StallService = require(script.Parent.StallService)
				StallService.dropCarried(player, "The Health Inspector caught you! You dropped your brainrot!")
			end
		end)

		while true do
			-- Calm: the market trades, the next sweep far off.
			local calmSeconds = Config.INSPECTOR.cycleSeconds - Config.INSPECTOR.warnSeconds - Config.INSPECTOR.sweepSeconds
			broadcast("calm", calmSeconds)
			task.wait(calmSeconds)

			-- Warning: the HUD counts down, thieves decide whether to finish or run.
			for left = Config.INSPECTOR.warnSeconds, 1, -1 do
				broadcast("warning", left)
				task.wait(1)
			end

			-- Sweep: the Inspector crosses the plaza west to east.
			frontX = Config.INSPECTOR.startX
			inspector:PivotTo(CFrame.new(frontX, 0, Config.INSPECTOR.pathZ))
			inspector.Parent = workspace
			sweeping = true
			for left = Config.INSPECTOR.sweepSeconds, 1, -1 do
				broadcast("sweep", left)
				task.wait(1)
			end
			sweeping = false
			inspector.Parent = nil
			broadcast("calm", calmSeconds)
		end
	end)
end

return InspectorService
