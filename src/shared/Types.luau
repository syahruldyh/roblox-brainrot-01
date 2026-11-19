--!strict
-- SNACK ATTACK: shared type definitions.
-- Every module that talks about a brainrot, a stall slot, or a player snapshot uses these
-- types, so a rename or a new field lands in one place.

export type RarityName = "Common" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Brainrot"

export type MutationName = "Normal" | "Golden" | "Rainbow" | "Void"

-- One primitive part of a brainrot character's body. The CharacterFactory builds a Model
-- from a CharacterDef's list of these, so each character gets a distinct silhouette from
-- plain parts: no meshes, no uploaded assets, everything built from data.
export type CharacterPartSpec = {
	shape: string, -- "Block" | "Ball" | "Cylinder" | "Wedge"
	size: Vector3,
	offset: Vector3, -- relative to the character model's origin, on the ground
	color: Color3,
}

export type CharacterDef = {
	id: string,
	name: string,
	rarity: RarityName,
	rate: number, -- coins earned per second while it sits on a stall
	price: number, -- coins to buy it off the conveyor
	parts: { CharacterPartSpec },
}

-- One brainrot sitting on a stall slot.
export type StallBrainrot = {
	characterId: string,
	mutation: MutationName,
	slot: number, -- 1..6 inside its owner's stall
}

-- The snapshot the server sends a client when that player's state changes.
export type PlayerSnapshot = {
	cash: number,
	income: number, -- coins per second from the stall right now
	rebirths: number,
	rebirthMultiplier: number,
	collection: { string }, -- character ids ever owned, for the 14/14 index
	stallCount: number,
	lockUntil: number, -- workspace:GetServerTimeNow() timestamp, 0 when unlocked
	lockCooldownUntil: number,
	carryingId: string?, -- character id carried right now, nil when hands are empty
}
