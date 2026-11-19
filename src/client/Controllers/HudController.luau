--!strict
-- SNACK ATTACK: the HUD. One ScreenGui built in code, laid out in Scale so it fits
-- phones and desktops, with the top-left corner left clear for Roblox's own menu.
-- The HUD only renders state and sends intents: cash and income come from player
-- attributes, the collection and rebirth target from the state snapshot, the Inspector
-- countdown from the server broadcast. Buttons use Activated, so mouse, touch and
-- gamepad all work; the same actions are bound to keys by the InputController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local LocalPlayer = Players.LocalPlayer

local HudController = {}

-- The actions the buttons and the keybinds share.
local Actions = {}

local snapshot = nil :: any
local ownedIds: { [string]: boolean } = {}

local gui: ScreenGui
local cashLabel: TextLabel
local incomeLabel: TextLabel
local inspectorLabel: TextLabel
local inspectorFrame: Frame
local collectionTitle: TextLabel
local collectionRows: { [string]: TextLabel } = {}
local stallLabel: TextLabel
local lockLabel: TextLabel
local rebirthLabel: TextLabel
local carryingFrame: Frame
local carryingLabel: TextLabel
local toastLabel: TextLabel
local toastFrame: Frame
local keyHint: TextLabel
local nextLabel: TextLabel
local pityLabel: TextLabel
local buyButton: TextButton
local placeButton: TextButton

local function formatMoney(amount: number): string
	local text = tostring(math.floor(amount))
	local result = ""
	while #text > 3 do
		result = "," .. string.sub(text, -3) .. result
		text = string.sub(text, 1, -4)
	end
	return "$" .. text .. result
end

local function makeButton(parent: Instance, name: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
	button.Size = UDim2.new(0, 104, 0, 48)
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

local function characterRoot(): BasePart?
	local character = LocalPlayer.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function ownStallName(): string?
	local market = workspace:FindFirstChild("Market")
	local stalls = market and market:FindFirstChild("Stalls")
	if not stalls then
		return nil
	end
	for _, stall in stalls:GetChildren() do
		local pad = stall:FindFirstChild("Pad")
		if pad and pad:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			return stall.Name
		end
	end
	return nil
end

-- The walker id nearest the player and inside buy reach, or nil. The BUY button
-- and the E key share this, and the glow loop below uses it too.
local function findNearestWalkerId(): string?
	local root = characterRoot()
	if not root then
		return nil
	end
	local bestId: string? = nil
	local bestDistance = Config.BUY.reachStuds
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") then
			local walkerId = child:GetAttribute("WalkerId")
			if typeof(walkerId) == "string" then
				local pivot = child:GetPivot()
				local distance = (root.Position - pivot.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestId = walkerId
				end
			end
		end
	end
	return bestId
end

function Actions.buyNearest()
	local bestId = findNearestWalkerId()
	if bestId then
		Net.BuyBrainrot:FireServer(bestId)
	else
		HudController.showToast("No brainrot in reach — walk to the conveyor!")
	end
end

function Actions.stealNearest()
	local root = characterRoot()
	if not root then
		return
	end
	local bestModel: Model? = nil
	local bestDistance = Config.STEAL.reachStuds
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") then
			local stallName = child:GetAttribute("StallName")
			local slot = child:GetAttribute("Slot")
			if typeof(stallName) == "string" and typeof(slot) == "number" then
				local pivot = child:GetPivot()
				local distance = (root.Position - pivot.Position).Magnitude
				if distance < bestDistance then
					bestDistance = distance
					bestModel = child
				end
			end
		end
	end
	if not bestModel then
		HudController.showToast("No stall brainrot in reach — sneak up to a stall!")
		return
	end
	local stallName = bestModel:GetAttribute("StallName") :: string
	local slot = bestModel:GetAttribute("Slot") :: number
	local market = workspace:FindFirstChild("Market")
	local stalls = market and market:FindFirstChild("Stalls")
	local stall = stalls and stalls:FindFirstChild(stallName)
	local pad = stall and stall:FindFirstChild("Pad")
	local ownerUserId = pad and pad:GetAttribute("OwnerUserId")
	if typeof(ownerUserId) ~= "number" or ownerUserId == LocalPlayer.UserId then
		HudController.showToast("That is your own stall!")
		return
	end
	Net.StealBrainrot:FireServer(ownerUserId, slot)
end

function Actions.place()
	Net.PlaceBrainrot:FireServer()
end

function Actions.lock()
	Net.LockBase:FireServer()
end

function Actions.rebirth()
	Net.RequestRebirth:FireServer()
end

function Actions.mutateFirst()
	-- Mutate the highest-numbered brainrot on your own stall.
	local myStall = ownStallName()
	if not myStall then
		return
	end
	local bestSlot = 0
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("StallName") == myStall then
			local slot = child:GetAttribute("Slot")
			if typeof(slot) == "number" and slot > bestSlot then
				bestSlot = slot
			end
		end
	end
	if bestSlot > 0 then
		Net.MutateBrainrot:FireServer(bestSlot)
	else
		HudController.showToast("No brainrot on your stall to mutate.")
	end
end

HudController.Actions = Actions

function HudController.showToast(text: string)
	toastLabel.Text = text
	toastFrame.Visible = true
	toastFrame.BackgroundTransparency = 0.3
	task.delay(3, function()
		local tween = TweenService:Create(toastFrame, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			toastFrame.Visible = false
		end)
	end)
end

local function refreshCollection()
	local owned = 0
	for _, def in Config.CHARACTERS do
		local row = collectionRows[def.id]
		if row then
			local isOwned = ownedIds[def.id] == true
			if isOwned then
				owned += 1
			end
			local mark = if isOwned then "✓" else "·"
			local rarityColor = Config.RARITIES[def.rarity].color
			row.Text = `{mark} {def.name} — ${def.rate}/s`
			row.TextColor3 = if isOwned then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(150, 150, 160)
			row.BackgroundColor3 = rarityColor
		end
	end
	collectionTitle.Text = `COLLECTION  {owned}/14`
end

local function refreshStallPanel()
	if not snapshot then
		return
	end
	stallLabel.Text = `Your stall: {snapshot.stallCount}/{Config.STALL_SLOT_COUNT}  •  Rebirths: {snapshot.rebirths} (x{string.format("%.2f", snapshot.rebirthMultiplier)})`
	local now = workspace:GetServerTimeNow()
	if now < snapshot.lockUntil then
		lockLabel.Text = `LOCKED — {math.ceil(snapshot.lockUntil - now)}s left`
		lockLabel.TextColor3 = Color3.fromRGB(120, 220, 120)
	elseif now < snapshot.lockCooldownUntil then
		lockLabel.Text = `Lock recharging — {math.ceil(snapshot.lockCooldownUntil - now)}s`
		lockLabel.TextColor3 = Color3.fromRGB(200, 200, 120)
	else
		lockLabel.Text = `Lock: READY — ${Config.LOCK.fee} (L)`
		lockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	-- The next tier, always one good haul away: the cheapest brainrot not yet owned.
	local nextDef: any = nil
	for _, def in Config.CHARACTERS do
		if not ownedIds[def.id] and (not nextDef or def.price < nextDef.price) then
			nextDef = def
		end
	end
	if nextDef then
		nextLabel.Text = `Next: {nextDef.name} ({nextDef.rarity}) — {formatMoney(nextDef.price)} • ${nextDef.rate}/s`
	else
		nextLabel.Text = "Collection complete — every brainrot owned!"
	end
	local raritiesOwned = 0
	for _, rarity in Config.RARITY_ORDER do
		for id in ownedIds do
			local def = Config.getCharacter(id)
			if def and def.rarity == rarity then
				raritiesOwned += 1
				break
			end
		end
	end
	rebirthLabel.Text = `Rebirth target: all 6 rarities ({raritiesOwned}/6) + ${Config.REBIRTH.cashRequired} — press R`
	carryingFrame.Visible = snapshot.carryingId ~= nil
	if snapshot.carryingId then
		local def = Config.getCharacter(snapshot.carryingId)
		carryingLabel.Text = def and `Carrying: {def.name} — take it home and press PLACE (F)!` or "Carrying a brainrot!"
	end
end

local function onSnapshot(newSnapshot: any)
	snapshot = newSnapshot
	ownedIds = {}
	for _, id in newSnapshot.collection do
		ownedIds[id] = true
	end
	cashLabel.Text = formatMoney(newSnapshot.cash)
	incomeLabel.Text = `+{formatMoney(newSnapshot.income)}/s`
	refreshCollection()
	refreshStallPanel()
end

-- The pity counter: how many belt spawns since the last Epic-or-better brainrot.
-- At the threshold the next spawn is guaranteed Epic or better.
local function onPityChanged(pity: number, threshold: number)
	if pity >= threshold then
		pityLabel.Text = `PITY {pity}/{threshold} — NEXT SPAWN IS EPIC+!`
		pityLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	else
		pityLabel.Text = `PITY {pity}/{threshold} — Epic+ guaranteed at {threshold}`
		pityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	end
end

local function onInspectorChanged(phase: string, secondsLeft: number)
	if phase == "warning" then
		inspectorFrame.BackgroundColor3 = Color3.fromRGB(200, 140, 30)
		inspectorLabel.Text = `HEALTH INSPECTOR IN {secondsLeft}s — finish your steal or RUN HOME!`
	elseif phase == "sweep" then
		inspectorFrame.BackgroundColor3 = Color3.fromRGB(200, 40, 40)
		inspectorLabel.Text = `INSPECTOR SWEEP — {secondsLeft}s — GET TO YOUR STALL!`
	else
		inspectorFrame.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
		inspectorLabel.Text = "Inspector calm — the market is safe"
	end
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "SnackHud"
	gui.ResetOnSpawn = false
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Cash, top-right (top-left stays clear for Roblox's menu).
	local cashFrame = Instance.new("Frame")
	cashFrame.Name = "CashFrame"
	cashFrame.AnchorPoint = Vector2.new(1, 0)
	cashFrame.Position = UDim2.new(1, -16, 0, 16)
	cashFrame.Size = UDim2.new(0.22, 0, 0.1, 0)
	cashFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	cashFrame.BackgroundTransparency = 0.25
	cashFrame.Parent = gui
	Instance.new("UICorner").Parent = cashFrame

	cashLabel = Instance.new("TextLabel")
	cashLabel.Name = "CashLabel"
	cashLabel.Size = UDim2.new(1, -12, 0.6, 0)
	cashLabel.Position = UDim2.new(0, 6, 0, 2)
	cashLabel.BackgroundTransparency = 1
	cashLabel.Text = "$100"
	cashLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
	cashLabel.Font = Enum.Font.GothamBlack
	cashLabel.TextSize = 26
	cashLabel.TextXAlignment = Enum.TextXAlignment.Right
	cashLabel.Parent = cashFrame

	incomeLabel = Instance.new("TextLabel")
	incomeLabel.Name = "IncomeLabel"
	incomeLabel.Size = UDim2.new(1, -12, 0.35, 0)
	incomeLabel.Position = UDim2.new(0, 6, 0.6, 0)
	incomeLabel.BackgroundTransparency = 1
	incomeLabel.Text = "+$0/s"
	incomeLabel.TextColor3 = Color3.fromRGB(120, 220, 120)
	incomeLabel.Font = Enum.Font.GothamBold
	incomeLabel.TextSize = 16
	incomeLabel.TextXAlignment = Enum.TextXAlignment.Right
	incomeLabel.Parent = cashFrame

	-- Inspector countdown, top-centre.
	inspectorFrame = Instance.new("Frame")
	inspectorFrame.Name = "InspectorFrame"
	inspectorFrame.AnchorPoint = Vector2.new(0.5, 0)
	inspectorFrame.Position = UDim2.new(0.5, 0, 0, 16)
	inspectorFrame.Size = UDim2.new(0.4, 0, 0.07, 0)
	inspectorFrame.BackgroundColor3 = Color3.fromRGB(40, 120, 60)
	inspectorFrame.BackgroundTransparency = 0.25
	inspectorFrame.Parent = gui
	Instance.new("UICorner").Parent = inspectorFrame

	inspectorLabel = Instance.new("TextLabel")
	inspectorLabel.Name = "InspectorLabel"
	inspectorLabel.Size = UDim2.fromScale(1, 1)
	inspectorLabel.BackgroundTransparency = 1
	inspectorLabel.Text = "Inspector calm — the market is safe"
	inspectorLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	inspectorLabel.Font = Enum.Font.GothamBold
	inspectorLabel.TextSize = 16
	inspectorLabel.TextWrapped = true
	inspectorLabel.Parent = inspectorFrame

	-- Toast, centre under the inspector bar.
	toastFrame = Instance.new("Frame")
	toastFrame.Name = "ToastFrame"
	toastFrame.AnchorPoint = Vector2.new(0.5, 0)
	toastFrame.Position = UDim2.new(0.5, 0, 0, 84)
	toastFrame.Size = UDim2.new(0.5, 0, 0.06, 0)
	toastFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	toastFrame.BackgroundTransparency = 1
	toastFrame.Visible = false
	toastFrame.Parent = gui
	Instance.new("UICorner").Parent = toastFrame

	toastLabel = Instance.new("TextLabel")
	toastLabel.Name = "ToastLabel"
	toastLabel.Size = UDim2.fromScale(1, 1)
	toastLabel.BackgroundTransparency = 1
	toastLabel.Text = ""
	toastLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	toastLabel.Font = Enum.Font.GothamBold
	toastLabel.TextSize = 16
	toastLabel.TextWrapped = true
	toastLabel.Parent = toastFrame

	-- Collection index, left-middle: 14 rows grouped by rarity.
	local collectionFrame = Instance.new("Frame")
	collectionFrame.Name = "CollectionFrame"
	collectionFrame.AnchorPoint = Vector2.new(0, 0.5)
	collectionFrame.Position = UDim2.new(0, 16, 0.5, 0)
	collectionFrame.Size = UDim2.new(0.22, 0, 0.56, 0)
	collectionFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	collectionFrame.BackgroundTransparency = 0.25
	collectionFrame.Parent = gui
	Instance.new("UICorner").Parent = collectionFrame

	collectionTitle = Instance.new("TextLabel")
	collectionTitle.Name = "CollectionTitle"
	collectionTitle.Size = UDim2.new(1, 0, 0, 28)
	collectionTitle.BackgroundTransparency = 1
	collectionTitle.Text = "COLLECTION  0/14"
	collectionTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
	collectionTitle.Font = Enum.Font.GothamBlack
	collectionTitle.TextSize = 16
	collectionTitle.Parent = collectionFrame

	pityLabel = Instance.new("TextLabel")
	pityLabel.Name = "PityLabel"
	pityLabel.Size = UDim2.new(1, -8, 0, 20)
	pityLabel.Position = UDim2.new(0, 4, 0, 28)
	pityLabel.BackgroundTransparency = 1
	pityLabel.Text = "PITY 0/8 — Epic+ guaranteed at 8"
	pityLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	pityLabel.Font = Enum.Font.GothamBold
	pityLabel.TextSize = 12
	pityLabel.TextXAlignment = Enum.TextXAlignment.Left
	pityLabel.Parent = collectionFrame

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "CollectionList"
	scroller.Size = UDim2.new(1, -8, 1, -58)
	scroller.Position = UDim2.new(0, 4, 0, 52)
	scroller.BackgroundTransparency = 1
	scroller.ScrollBarThickness = 4
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.Parent = collectionFrame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 3)
	list.Parent = scroller

	for _, rarity in Config.RARITY_ORDER do
		-- A header per rarity, so the ladder reads as a ladder, not a flat list.
		local header = Instance.new("TextLabel")
		header.Name = `Header_{rarity}`
		header.Size = UDim2.new(1, -6, 0, 18)
		header.BackgroundTransparency = 1
		header.Text = rarity:upper()
		header.TextColor3 = Config.RARITIES[rarity].color
		header.Font = Enum.Font.GothamBlack
		header.TextSize = 12
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = scroller
		for _, def in Config.CHARACTERS do
			if def.rarity == rarity then
				local row = Instance.new("TextLabel")
				row.Name = `Row_{def.id}`
				row.Size = UDim2.new(1, -6, 0, 20)
				row.BackgroundTransparency = 0.75
				row.BackgroundColor3 = Config.RARITIES[rarity].color
				row.Text = `· {def.name} — ${def.rate}/s`
				row.TextColor3 = Color3.fromRGB(150, 150, 160)
				row.Font = Enum.Font.GothamBold
				row.TextSize = 13
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Parent = scroller
				Instance.new("UICorner").Parent = row
				collectionRows[def.id] = row
			end
		end
	end

	-- Stall panel, bottom-left: stall count, lock timer, rebirth target, next tier.
	local stallFrame = Instance.new("Frame")
	stallFrame.Name = "StallFrame"
	stallFrame.AnchorPoint = Vector2.new(0, 1)
	stallFrame.Position = UDim2.new(0, 16, 1, -16)
	stallFrame.Size = UDim2.new(0.26, 0, 0.2, 0)
	stallFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	stallFrame.BackgroundTransparency = 0.25
	stallFrame.Parent = gui
	Instance.new("UICorner").Parent = stallFrame

	stallLabel = Instance.new("TextLabel")
	stallLabel.Name = "StallLabel"
	stallLabel.Size = UDim2.new(1, -12, 0, 24)
	stallLabel.Position = UDim2.new(0, 6, 0, 4)
	stallLabel.BackgroundTransparency = 1
	stallLabel.Text = "Your stall: 0/6"
	stallLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	stallLabel.Font = Enum.Font.GothamBold
	stallLabel.TextSize = 15
	stallLabel.TextXAlignment = Enum.TextXAlignment.Left
	stallLabel.Parent = stallFrame

	lockLabel = Instance.new("TextLabel")
	lockLabel.Name = "LockLabel"
	lockLabel.Size = UDim2.new(1, -12, 0, 24)
	lockLabel.Position = UDim2.new(0, 6, 0, 30)
	lockLabel.BackgroundTransparency = 1
	lockLabel.Text = "Lock: READY (L)"
	lockLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	lockLabel.Font = Enum.Font.GothamBold
	lockLabel.TextSize = 15
	lockLabel.TextXAlignment = Enum.TextXAlignment.Left
	lockLabel.Parent = stallFrame

	rebirthLabel = Instance.new("TextLabel")
	rebirthLabel.Name = "RebirthLabel"
	rebirthLabel.Size = UDim2.new(1, -12, 0, 24)
	rebirthLabel.Position = UDim2.new(0, 6, 0, 56)
	rebirthLabel.BackgroundTransparency = 1
	rebirthLabel.Text = "Rebirth target: all 6 rarities + $10000"
	rebirthLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
	rebirthLabel.Font = Enum.Font.GothamBold
	rebirthLabel.TextSize = 14
	rebirthLabel.TextXAlignment = Enum.TextXAlignment.Left
	rebirthLabel.Parent = stallFrame

	nextLabel = Instance.new("TextLabel")
	nextLabel.Name = "NextLabel"
	nextLabel.Size = UDim2.new(1, -12, 0, 24)
	nextLabel.Position = UDim2.new(0, 6, 0, 82)
	nextLabel.BackgroundTransparency = 1
	nextLabel.Text = "Next: Sir Fries-A-Lot — $25"
	nextLabel.TextColor3 = Color3.fromRGB(140, 220, 255)
	nextLabel.Font = Enum.Font.GothamBold
	nextLabel.TextSize = 14
	nextLabel.TextXAlignment = Enum.TextXAlignment.Left
	nextLabel.Parent = stallFrame

	-- Carrying banner, bottom-centre above the action bar.
	carryingFrame = Instance.new("Frame")
	carryingFrame.Name = "CarryingFrame"
	carryingFrame.AnchorPoint = Vector2.new(0.5, 1)
	carryingFrame.Position = UDim2.new(0.5, 0, 1, -76)
	carryingFrame.Size = UDim2.new(0.44, 0, 0.06, 0)
	carryingFrame.BackgroundColor3 = Color3.fromRGB(120, 60, 180)
	carryingFrame.BackgroundTransparency = 0.25
	carryingFrame.Visible = false
	carryingFrame.Parent = gui
	Instance.new("UICorner").Parent = carryingFrame

	carryingLabel = Instance.new("TextLabel")
	carryingLabel.Name = "CarryingLabel"
	carryingLabel.Size = UDim2.fromScale(1, 1)
	carryingLabel.BackgroundTransparency = 1
	carryingLabel.Text = ""
	carryingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	carryingLabel.Font = Enum.Font.GothamBold
	carryingLabel.TextSize = 16
	carryingLabel.Parent = carryingFrame

	-- Action bar, bottom-centre: the four touch buttons (BUY / PLACE / STEAL / MUTATE).
	local actionBar = Instance.new("Frame")
	actionBar.Name = "ActionBar"
	actionBar.AnchorPoint = Vector2.new(0.5, 1)
	actionBar.Position = UDim2.new(0.5, 0, 1, -16)
	actionBar.Size = UDim2.new(0, 448, 0, 52)
	actionBar.BackgroundTransparency = 1
	actionBar.Parent = gui

	local barList = Instance.new("UIListLayout")
	barList.FillDirection = Enum.FillDirection.Horizontal
	barList.Padding = UDim.new(0, 8)
	barList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	barList.Parent = actionBar

	buyButton = makeButton(actionBar, "BuyButton", "BUY (E)")
	buyButton.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
	buyButton.Activated:Connect(Actions.buyNearest)

	placeButton = makeButton(actionBar, "PlaceButton", "PLACE (F)")
	placeButton.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
	placeButton.Activated:Connect(Actions.place)

	local stealButton = makeButton(actionBar, "StealButton", "STEAL (Q)")
	stealButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
	stealButton.Activated:Connect(Actions.stealNearest)

	local mutateButton = makeButton(actionBar, "MutateButton", "MUTATE")
	mutateButton.BackgroundColor3 = Color3.fromRGB(140, 60, 200)
	mutateButton.Activated:Connect(Actions.mutateFirst)

	-- Key hints, bottom-right; hidden on touch, where the buttons are the input.
	keyHint = Instance.new("TextLabel")
	keyHint.Name = "KeyHint"
	keyHint.AnchorPoint = Vector2.new(1, 1)
	keyHint.Position = UDim2.new(1, -16, 1, -16)
	keyHint.Size = UDim2.new(0, 260, 0, 22)
	keyHint.BackgroundTransparency = 1
	keyHint.Text = "E buy · F place · Q steal · L lock · R rebirth"
	keyHint.TextColor3 = Color3.fromRGB(200, 200, 200)
	keyHint.Font = Enum.Font.Gotham
	keyHint.TextSize = 13
	keyHint.TextXAlignment = Enum.TextXAlignment.Right
	keyHint.Parent = gui

	local function refreshKeyHint()
		keyHint.Visible = UserInputService.PreferredInput ~= Enum.PreferredInput.Touch
	end
	UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(refreshKeyHint)
	refreshKeyHint()

	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	gui.Parent = playerGui
end

function HudController.start()
	buildGui()

	-- Cheap path: cash and income ride on player attributes.
	LocalPlayer:GetAttributeChangedSignal("SnackCash"):Connect(function()
		local cash = LocalPlayer:GetAttribute("SnackCash")
		if typeof(cash) == "number" then
			cashLabel.Text = formatMoney(cash)
		end
	end)
	LocalPlayer:GetAttributeChangedSignal("SnackIncome"):Connect(function()
		local income = LocalPlayer:GetAttribute("SnackIncome")
		if typeof(income) == "number" then
			incomeLabel.Text = `+{formatMoney(income)}/s`
		end
	end)

	Net.StateChanged.OnClientEvent:Connect(onSnapshot)
	Net.Toast.OnClientEvent:Connect(HudController.showToast)
	Net.InspectorChanged.OnClientEvent:Connect(onInspectorChanged)
	Net.PityChanged.OnClientEvent:Connect(onPityChanged)

	-- Only the wanted action glows: BUY lights up when a walker is in reach, PLACE
	-- lights up while the player is carrying. Checked twice a second, not per frame.
	task.spawn(function()
		while true do
			task.wait(0.5)
			if buyButton then
				buyButton.BackgroundColor3 = if findNearestWalkerId() ~= nil
					then Color3.fromRGB(60, 220, 90)
					else Color3.fromRGB(35, 90, 50)
			end
			if placeButton then
				placeButton.BackgroundColor3 = if snapshot and snapshot.carryingId ~= nil
					then Color3.fromRGB(70, 160, 255)
					else Color3.fromRGB(35, 70, 110)
			end
		end
	end)

	-- The lock timer ticks locally once a second; the server re-publishes on change.
	task.spawn(function()
		while true do
			task.wait(1)
			if snapshot then
				refreshStallPanel()
			end
		end
	end)
end

return HudController
