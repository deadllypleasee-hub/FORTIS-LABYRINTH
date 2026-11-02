--!strict
-- Token bucket keyed by UserId and action; discarded on PlayerRemoving.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

function RateLimiter.new(clock)
	return setmetatable({ buckets = {}, clock = clock or os.clock }, RateLimiter)
end

function RateLimiter:allow(key, capacity, refill)
	local now = self.clock()
	local bucket = self.buckets[key]
	if not bucket then
		bucket = { tokens = capacity, time = now }
		self.buckets[key] = bucket
	end
	bucket.tokens = math.min(capacity, bucket.tokens + math.max(0, now - bucket.time) * refill)
	bucket.time = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens -= 1
	return true
end

function RateLimiter:forgetPrefix(prefix)
	for key in self.buckets do
		if string.sub(key, 1, #prefix) == prefix then
			self.buckets[key] = nil
		end
	end
end

return RateLimiter
