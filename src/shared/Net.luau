--!strict
-- SNACK ATTACK: every RemoteEvent the game uses, defined once in one place.
-- The server creates them; the client waits for them. Both sides require this module,
-- so a typo in a remote name fails at require time instead of silently at runtime.
-- Client-to-server remotes carry intents only ("I want to buy walker 3"); the server
-- decides everything. Server-to-client remotes carry state changes and toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "SnackRemotes"
local IS_SERVER = RunService:IsServer()

local folder: Instance
if IS_SERVER then
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = FOLDER_NAME
		created.Parent = ReplicatedStorage
		folder = created
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

local function getRemote(name: string): RemoteEvent
	if IS_SERVER then
		local existing = folder:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
		return remote
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	-- Client -> server intents. Payloads are small ids/numbers; the server validates all.
	BuyBrainrot = getRemote("BuyBrainrot"), -- (walkerId: string)
	PlaceBrainrot = getRemote("PlaceBrainrot"), -- () place the carried brainrot on your stall
	StealBrainrot = getRemote("StealBrainrot"), -- (ownerUserId: number, slot: number)
	LockBase = getRemote("LockBase"), -- () lock your own stall
	MutateBrainrot = getRemote("MutateBrainrot"), -- (slot: number) re-roll one stall brainrot
	RequestRebirth = getRemote("RequestRebirth"), -- () try to rebirth
	-- Server -> client state.
	StateChanged = getRemote("StateChanged"), -- (snapshot: PlayerSnapshot) to one player
	Toast = getRemote("Toast"), -- (text: string) to one player
	InspectorChanged = getRemote("InspectorChanged"), -- (phase: string, secondsLeft: number) to all
	PityChanged = getRemote("PityChanged"), -- (pity: number, threshold: number) to all
}
