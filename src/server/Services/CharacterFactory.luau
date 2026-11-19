--!strict
-- SNACK ATTACK: builds a brainrot character Model from its Config definition.
-- Every character is three primitive parts (body, head/gag, accessory) from data, so the
-- 14 characters get 14 distinct silhouettes with no meshes and no uploaded assets.
-- The same builder makes the conveyor walkers, the stall displays and the carried
-- brainrot a thief runs off with; only the label and the anchor differ.
-- Mutations recolour the body: Golden goes gold, Rainbow cycles bright colours,
-- Void goes dark purple. The label always names the mutation, so it reads on screen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

local CharacterFactory = {}

local MUTATION_COLORS: { [Types.MutationName]: { Color3 } } = {
	Normal = {},
	Golden = { Color3.fromRGB(255, 215, 0), Color3.fromRGB(255, 190, 0), Color3.fromRGB(255, 230, 120) },
	Rainbow = { Color3.fromRGB(255, 90, 160), Color3.fromRGB(80, 200, 255), Color3.fromRGB(140, 255, 120) },
	Void = { Color3.fromRGB(60, 20, 90), Color3.fromRGB(40, 10, 70), Color3.fromRGB(90, 30, 130) },
}

local function partColor(def: Types.CharacterDef, mutation: Types.MutationName, index: number): Color3
	local palette = MUTATION_COLORS[mutation]
	if #palette == 0 then
		return def.parts[index].color
	end
	return palette[((index - 1) % #palette) + 1]
end

function CharacterFactory.build(def: Types.CharacterDef, mutation: Types.MutationName): Model
	local model = Instance.new("Model")
	model.Name = `Brainrot_{def.id}`

	for index, spec in def.parts do
		local part = Instance.new("Part")
		part.Name = `Part{index}`
		part.Shape = Enum.PartType[spec.shape]
		part.Size = spec.size
		part.CFrame = CFrame.new(spec.offset)
		part.Color = partColor(def, mutation, index)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
	end

	local primary = model:FindFirstChild("Part1") :: BasePart?
	if primary then
		model.PrimaryPart = primary
	end
	return model
end

-- The floating label above a brainrot: name, rarity colour, mutation, and coins per
-- second at its real rate. On the conveyor it also shows the buy price.
function CharacterFactory.attachLabel(
	model: Model,
	def: Types.CharacterDef,
	mutation: Types.MutationName,
	showPrice: boolean
)
	local rarityColor = Config.RARITIES[def.rarity].color
	local rate = def.rate * Config.MUTATIONS[mutation].multiplier
	local mutationText = if mutation == "Normal" then "" else ` [{mutation}]`

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "BrainrotLabel"
	billboard.Size = UDim2.new(0, 240, 0, 96)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.8, 0)
	billboard.MaxDistance = 90
	billboard.AlwaysOnTop = false

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.55
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextScaled = true
	label.RichText = true
	label.Font = Enum.Font.GothamBold
	local priceLine = if showPrice then `\n<b>${def.price}</b> — click to buy` else ""
	label.Text = `<b>{def.name}</b>{mutationText}\n<font color="#{rarityColor:ToHex()}">{def.rarity}</font>  ${rate}/s{priceLine}`
	label.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	billboard.Parent = model
	return billboard
end

-- Weld a brainrot model to a character so the player carries it in front of them.
-- Parts go unanchored and massless so the weld, not physics, moves them; the model is
-- named CarriedBrainrot so the stall and inspector code can find and remove it.
function CharacterFactory.attachCarried(model: Model, character: Model?)
	if not character then
		model:Destroy()
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local primary = model.PrimaryPart
	if not root or not primary then
		model:Destroy()
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			descendant.CanCollide = false
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = primary
	weld.C0 = CFrame.new(0, 0.5, 2.5)
	weld.Parent = primary
	model.Parent = character
end

function CharacterFactory.findCarriedModel(character: Model?): Model?
	if not character then
		return nil
	end
	local found = character:FindFirstChild("CarriedBrainrot")
	if found and found:IsA("Model") then
		return found
	end
	return nil
end

-- A tall sign for a stall: the owner's name and the lock state, readable across the plaza.
-- Two SurfaceGuis, one per face, so the sign reads from the plaza side no matter
-- which way the stall row faces.
function CharacterFactory.attachStallSign(stallPad: BasePart, ownerName: string)
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Name = `StallSign_{face.Name}`
		surface.Face = face
		surface.CanvasSize = Vector2.new(400, 120)
		surface.Parent = stallPad

		local label = Instance.new("TextLabel")
		label.Name = "OwnerLabel"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.Text = `{ownerName}'s STALL`
		label.Parent = surface
	end
end

return CharacterFactory
