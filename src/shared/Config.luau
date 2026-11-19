--!strict
-- SNACK ATTACK: the game's tuning and its cast, in one data table.
-- The server reads prices, rates and timings from here to decide everything; the client
-- reads the same table to draw the collection index and the shop labels, so the two sides
-- can never disagree about what a brainrot is worth. Nothing here is a secret: prices are
-- data, and the server still re-checks every purchase against this table.

local Types = require(script.Parent.Types)

export type RarityInfo = {
	color: Color3,
	spawnWeight: number, -- share of conveyor spawns that roll this rarity
}

local Config = {}

Config.RARITIES = {
	Common = { color = Color3.fromRGB(200, 200, 200), spawnWeight = 0.45 },
	Rare = { color = Color3.fromRGB(80, 160, 255), spawnWeight = 0.28 },
	Epic = { color = Color3.fromRGB(180, 90, 255), spawnWeight = 0.15 },
	Legendary = { color = Color3.fromRGB(255, 170, 40), spawnWeight = 0.07 },
	Mythic = { color = Color3.fromRGB(255, 70, 120), spawnWeight = 0.04 },
	Brainrot = { color = Color3.fromRGB(255, 220, 0), spawnWeight = 0.01 },
} :: { [Types.RarityName]: RarityInfo }

Config.RARITY_ORDER = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Brainrot" } :: { Types.RarityName }

-- Mutations: rolled when a brainrot is bought, re-rollable at the stall for a fee.
-- The multiplier applies to that brainrot's coins per second.
Config.MUTATIONS = {
	Normal = { multiplier = 1, rollWeight = 85 },
	Golden = { multiplier = 2, rollWeight = 10 },
	Rainbow = { multiplier = 3, rollWeight = 4 },
	Void = { multiplier = 5, rollWeight = 1 },
} :: { [Types.MutationName]: { multiplier: number, rollWeight: number } }

-- Re-rolling a stall brainrot's mutation always lands on at least Golden.
Config.MUTATE_REROLL = {
	Golden = 70,
	Rainbow = 25,
	Void = 5,
} :: { [string]: number }
Config.MUTATE_FEE = 1000

-- Rebirth: own at least one brainrot of every rarity, ever, and hold the cash target.
-- The stall and the cash reset; the collection index and the multiplier stay.
Config.REBIRTH = {
	cashRequired = 10000,
	raritiesRequired = 6,
	multiplierPerRebirth = 1.25,
	startingCash = 100,
}

Config.STARTING_CASH = 100
Config.MAX_CASH = 1000000000000 -- 1e12, the economy's ceiling

-- The conveyor: brainrots walk from west to east along the belt, and despawn at the end.
Config.CONVEYOR = {
	startX = -45,
	endX = 45,
	z = -30,
	topY = 1,
	walkSpeed = 2.2, -- studs per second
	spawnIntervalSeconds = 7,
	maxWalkers = 6,
}

-- The Health Inspector: a sweep every cycle, warned in advance, that makes carriers drop
-- their haul unless they are inside their own stall when the front passes them.
Config.INSPECTOR = {
	cycleSeconds = 150, -- a full cycle: calm, then warning, then the sweep
	warnSeconds = 30, -- countdown shown on the HUD before the sweep starts
	sweepSeconds = 25, -- the front crosses the map west to east
	pathZ = 0,
	startX = -60,
	endX = 60,
	catchRadius = 6, -- studs around the front that drop a carried brainrot
}

-- Base lock: a player can lock their stall so nobody can steal from it. The fee makes
-- the lock a real money sink: you pay to protect what you have earned.
Config.LOCK = {
	durationSeconds = 60,
	cooldownSeconds = 120,
	fee = 250,
}

-- Pity: after this many conveyor spawns without an Epic-or-better brainrot, the next
-- spawn is guaranteed Epic or better, so an unlucky streak still progresses.
Config.PITY = {
	threshold = 8,
}

Config.STALL_SLOT_COUNT = 6
Config.STALL_COUNT = 8

-- Eight stalls in two rows around the plaza. Each stall's centre is its pad's centre.
Config.STALLS = {
	{ name = "Stall1", center = Vector3.new(-33, 0, -14) },
	{ name = "Stall2", center = Vector3.new(-11, 0, -14) },
	{ name = "Stall3", center = Vector3.new(11, 0, -14) },
	{ name = "Stall4", center = Vector3.new(33, 0, -14) },
	{ name = "Stall5", center = Vector3.new(-33, 0, 14) },
	{ name = "Stall6", center = Vector3.new(-11, 0, 14) },
	{ name = "Stall7", center = Vector3.new(11, 0, 14) },
	{ name = "Stall8", center = Vector3.new(33, 0, 14) },
}

-- Six slots on a stall floor, in local offsets from the stall centre (3 across, 2 deep).
Config.STALL_SLOTS = {
	Vector3.new(-3.5, 0, -2),
	Vector3.new(0, 0, -2),
	Vector3.new(3.5, 0, -2),
	Vector3.new(-3.5, 0, 2),
	Vector3.new(0, 0, 2),
	Vector3.new(3.5, 0, 2),
}

Config.SPAWN_POSITION = Vector3.new(0, 3, 30)

-- Steal rules, enforced on the server: how close a thief must stand to the victim's stall,
-- and how long a stolen brainrot stays "hot" (the victim's lock cannot be bought while hot).
Config.STEAL = {
	reachStuds = 12, -- thief must stand within this of the victim stall centre
	stealCooldownSeconds = 5, -- per thief, between steal attempts
}

Config.BUY = {
	reachStuds = 10, -- buyer must stand within this of the walker on the belt
	buyCooldownSeconds = 1,
}

Config.INCOME_TICK_SECONDS = 1

-- The cast: 14 original food-meme characters across 6 rarities. Each one is built from
-- three primitive parts (body, head/gag, accessory) so every silhouette reads at a glance.
-- `rate` is coins per second on a stall; `price` is the conveyor buy price.
local function part(shape: string, size: Vector3, offset: Vector3, color: Color3): Types.CharacterPartSpec
	return { shape = shape, size = size, offset = offset, color = color }
end

Config.CHARACTERS = {
	{
		id = "sir-fries-a-lot",
		name = "Sir Fries-A-Lot",
		rarity = "Common",
		rate = 1,
		price = 25,
		parts = {
			part("Block", Vector3.new(2, 2.4, 1.6), Vector3.new(0, 1.2, 0), Color3.fromRGB(220, 60, 60)),
			part("Block", Vector3.new(1.6, 1.2, 0.4), Vector3.new(0, 2.8, 0), Color3.fromRGB(255, 220, 80)),
			part("Block", Vector3.new(1.4, 0.5, 1.2), Vector3.new(0, 3.6, 0), Color3.fromRGB(255, 215, 0)),
		},
	},
	{
		id = "captain-noodle",
		name = "Captain Noodle",
		rarity = "Common",
		rate = 2,
		price = 50,
		parts = {
			part("Cylinder", Vector3.new(2.2, 2.2, 2.2), Vector3.new(0, 1.1, 0), Color3.fromRGB(245, 245, 245)),
			part("Ball", Vector3.new(1.8, 0.8, 1.8), Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 200, 90)),
			part("Block", Vector3.new(2.4, 0.4, 2.4), Vector3.new(0, 3.1, 0), Color3.fromRGB(255, 255, 255)),
		},
	},
	{
		id = "baron-von-burger",
		name = "Baron Von Burger",
		rarity = "Common",
		rate = 3,
		price = 100,
		parts = {
			part("Ball", Vector3.new(2.4, 1.4, 2.4), Vector3.new(0, 2.2, 0), Color3.fromRGB(230, 180, 110)),
			part("Cylinder", Vector3.new(2.4, 0.8, 2.4), Vector3.new(0, 1.4, 0), Color3.fromRGB(120, 70, 30)),
			part("Ball", Vector3.new(0.5, 0.5, 0.5), Vector3.new(1.1, 2.6, 0.8), Color3.fromRGB(255, 215, 0)),
		},
	},
	{
		id = "duchess-donut",
		name = "Duchess Donut",
		rarity = "Rare",
		rate = 6,
		price = 250,
		parts = {
			part("Cylinder", Vector3.new(2.4, 1.2, 2.4), Vector3.new(0, 0.6, 0), Color3.fromRGB(255, 150, 200)),
			part("Ball", Vector3.new(1.6, 0.9, 1.6), Vector3.new(0, 1.5, 0), Color3.fromRGB(255, 190, 220)),
			part("Block", Vector3.new(1.2, 0.4, 0.8), Vector3.new(0, 2.3, 0), Color3.fromRGB(255, 215, 0)),
		},
	},
	{
		id = "professor-pizza",
		name = "Professor Pizza",
		rarity = "Rare",
		rate = 9,
		price = 500,
		parts = {
			part("Wedge", Vector3.new(2.4, 0.6, 3), Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 210, 90)),
			part("Ball", Vector3.new(0.6, 0.4, 0.6), Vector3.new(0.4, 0.8, 0.4), Color3.fromRGB(200, 40, 40)),
			part("Ball", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-0.7, 1.4, 0.9), Color3.fromRGB(30, 30, 30)),
		},
	},
	{
		id = "count-croissant",
		name = "Count Croissant",
		rarity = "Rare",
		rate = 12,
		price = 900,
		parts = {
			part("Ball", Vector3.new(2.6, 1.6, 1.8), Vector3.new(0, 1.2, 0), Color3.fromRGB(220, 150, 60)),
			part("Block", Vector3.new(2.2, 2, 0.3), Vector3.new(0, 1.4, -1.1), Color3.fromRGB(160, 20, 40)),
			part("Block", Vector3.new(0.5, 0.5, 0.3), Vector3.new(0, 2.4, 1), Color3.fromRGB(255, 255, 255)),
		},
	},
	{
		id = "madame-macaron",
		name = "Madame Macaron",
		rarity = "Epic",
		rate = 20,
		price = 2000,
		parts = {
			part("Cylinder", Vector3.new(2.4, 0.9, 2.4), Vector3.new(0, 0.45, 0), Color3.fromRGB(255, 130, 200)),
			part("Cylinder", Vector3.new(2.4, 0.9, 2.4), Vector3.new(0, 1.35, 0), Color3.fromRGB(255, 240, 230)),
			part("Cylinder", Vector3.new(2.2, 0.4, 2.2), Vector3.new(0, 2.1, 0), Color3.fromRGB(60, 40, 90)),
		},
	},
	{
		id = "general-taco",
		name = "General Taco",
		rarity = "Epic",
		rate = 30,
		price = 3500,
		parts = {
			part("Wedge", Vector3.new(2.6, 1.8, 2), Vector3.new(0, 0.9, 0), Color3.fromRGB(240, 200, 80)),
			part("Ball", Vector3.new(1.8, 0.8, 1.4), Vector3.new(0, 2, 0), Color3.fromRGB(90, 180, 80)),
			part("Ball", Vector3.new(1.8, 0.9, 1.8), Vector3.new(0, 2.7, 0), Color3.fromRGB(120, 120, 130)),
		},
	},
	{
		id = "lady-boba",
		name = "Lady Boba",
		rarity = "Epic",
		rate = 45,
		price = 6000,
		parts = {
			part("Cylinder", Vector3.new(2, 2.6, 2), Vector3.new(0, 1.3, 0), Color3.fromRGB(150, 90, 50)),
			part("Cylinder", Vector3.new(0.35, 1.6, 0.35), Vector3.new(0.5, 3.2, 0), Color3.fromRGB(220, 40, 60)),
			part("Block", Vector3.new(1.5, 0.5, 1.1), Vector3.new(0, 4, 0), Color3.fromRGB(255, 215, 0)),
		},
	},
	{
		id = "emperor-espresso",
		name = "Emperor Espresso",
		rarity = "Legendary",
		rate = 80,
		price = 12000,
		parts = {
			part("Cylinder", Vector3.new(2, 2.2, 2), Vector3.new(0, 1.1, 0), Color3.fromRGB(250, 250, 250)),
			part("Ball", Vector3.new(1.2, 0.9, 1.2), Vector3.new(0, 2.6, 0), Color3.fromRGB(235, 235, 235)),
			part("Block", Vector3.new(1.8, 0.4, 0.4), Vector3.new(0, 3.2, 0), Color3.fromRGB(255, 215, 0)),
		},
	},
	{
		id = "queen-quiche",
		name = "Queen Quiche",
		rarity = "Legendary",
		rate = 120,
		price = 20000,
		parts = {
			part("Cylinder", Vector3.new(2.4, 1, 2.4), Vector3.new(0, 0.5, 0), Color3.fromRGB(230, 190, 90)),
			part("Cylinder", Vector3.new(0.3, 2.4, 0.3), Vector3.new(1.2, 1.6, 0), Color3.fromRGB(255, 215, 0)),
			part("Block", Vector3.new(1.4, 0.5, 1), Vector3.new(0, 3.1, 0), Color3.fromRGB(255, 215, 0)),
		},
	},
	{
		id = "king-kebab",
		name = "King Kebab",
		rarity = "Mythic",
		rate = 200,
		price = 40000,
		parts = {
			part("Cylinder", Vector3.new(0.4, 4, 0.4), Vector3.new(0, 2, 0), Color3.fromRGB(180, 180, 190)),
			part("Ball", Vector3.new(1.4, 1.2, 1.4), Vector3.new(0, 1.2, 0), Color3.fromRGB(140, 80, 40)),
			part("Block", Vector3.new(1.8, 0.6, 1.3), Vector3.new(0, 4.2, 0), Color3.fromRGB(255, 215, 0)),
		},
	},
	{
		id = "duke-dumpling",
		name = "Duke Dumpling",
		rarity = "Mythic",
		rate = 300,
		price = 75000,
		parts = {
			part("Ball", Vector3.new(2.4, 1.8, 2), Vector3.new(0, 1.1, 0), Color3.fromRGB(250, 240, 220)),
			part("Block", Vector3.new(2.2, 2, 0.3), Vector3.new(0, 1.4, -1.2), Color3.fromRGB(180, 30, 50)),
			part("Ball", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 2.4, 0), Color3.fromRGB(40, 40, 40)),
		},
	},
	{
		id = "the-almighty-snack",
		name = "The Almighty Snack",
		rarity = "Brainrot",
		rate = 600,
		price = 150000,
		parts = {
			part("Block", Vector3.new(2.6, 2, 2), Vector3.new(0, 1, 0), Color3.fromRGB(255, 200, 0)),
			part("Ball", Vector3.new(2, 1.4, 2), Vector3.new(0, 2.6, 0), Color3.fromRGB(255, 90, 160)),
			part("Block", Vector3.new(2.2, 0.7, 1.6), Vector3.new(0, 3.7, 0), Color3.fromRGB(255, 215, 0)),
		},
	},
} :: { Types.CharacterDef }

-- Fast lookup by id, built once at require time.
Config.CHARACTER_BY_ID = {} :: { [string]: Types.CharacterDef }
for _, def in Config.CHARACTERS do
	Config.CHARACTER_BY_ID[def.id] = def
end

function Config.getCharacter(id: string): Types.CharacterDef?
	return Config.CHARACTER_BY_ID[id]
end

-- Weighted pick of a rarity for the next conveyor spawn.
function Config.rollRarity(random: Random): Types.RarityName
	local roll = random:NextNumber()
	local running = 0
	for _, rarity in Config.RARITY_ORDER do
		running += Config.RARITIES[rarity].spawnWeight
		if roll <= running then
			return rarity
		end
	end
	return "Common"
end

-- Pick a random character of a given rarity.
function Config.randomCharacterOfRarity(rarity: Types.RarityName, random: Random): Types.CharacterDef
	local pool = {}
	for _, def in Config.CHARACTERS do
		if def.rarity == rarity then
			table.insert(pool, def)
		end
	end
	return pool[random:NextInteger(1, #pool)]
end

-- Weighted pick of a mutation for a fresh purchase.
function Config.rollMutation(random: Random): Types.MutationName
	local total = 0
	for _, info in Config.MUTATIONS do
		total += info.rollWeight
	end
	local roll = random:NextInteger(1, total)
	local running = 0
	for name, info in Config.MUTATIONS do
		running += info.rollWeight
		if roll <= running then
			return name :: Types.MutationName
		end
	end
	return "Normal"
end

-- Re-roll at the stall: always at least Golden.
function Config.rollMutateReroll(random: Random): Types.MutationName
	local roll = random:NextInteger(1, 100)
	local running = 0
	for name, weight in Config.MUTATE_REROLL do
		running += weight
		if roll <= running then
			return name :: Types.MutationName
		end
	end
	return "Golden"
end

return Config
