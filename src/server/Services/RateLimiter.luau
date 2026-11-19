--!strict
-- SNACK ATTACK: a token-bucket rate limiter, one bucket per player.
-- Every remote handler asks its limiter first. Bursts are allowed up to the capacity;
-- sustained spam drains the bucket and the handler silently drops the request.
-- Buckets are cleared when a player leaves, so Player keys never leak.

local Players = game:GetService("Players")

local RateLimiter = {}

export type Limiter = (player: Player) -> boolean

function RateLimiter.new(capacity: number, windowSeconds: number): Limiter
	local refillRate = capacity / windowSeconds
	local buckets: { [Player]: { tokens: number, last: number } } = {}

	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	return function(player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if not bucket then
			bucket = { tokens = capacity, last = now }
			buckets[player] = bucket
		else
			bucket.tokens = math.min(capacity, bucket.tokens + (now - bucket.last) * refillRate)
			bucket.last = now
		end
		if bucket.tokens >= 1 then
			bucket.tokens -= 1
			return true
		end
		return false
	end
end

return RateLimiter
