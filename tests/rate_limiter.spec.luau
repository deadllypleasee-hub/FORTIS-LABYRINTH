local RateLimiter = require("../src/server/RateLimiter")

return function(test)
	test("remote burst is bounded and tokens refill over elapsed time", function()
		local now = 0
		local limiter = RateLimiter.new(function()
			return now
		end)
		assert(limiter:allow("1:Attack", 2, 2))
		assert(limiter:allow("1:Attack", 2, 2))
		assert(not limiter:allow("1:Attack", 2, 2))
		now = 0.49
		assert(not limiter:allow("1:Attack", 2, 2))
		now = 0.5
		assert(limiter:allow("1:Attack", 2, 2))
		assert(not limiter:allow("1:Attack", 2, 2))
	end)
	test("long idle time cannot accumulate an unlimited remote burst", function()
		local now = 0
		local limiter = RateLimiter.new(function()
			return now
		end)
		assert(limiter:allow("1:Attack", 2, 2))
		now = 10000
		assert(limiter:allow("1:Attack", 2, 2))
		assert(limiter:allow("1:Attack", 2, 2))
		assert(not limiter:allow("1:Attack", 2, 2))
	end)
	test("players and actions have independent rate budgets", function()
		local limiter = RateLimiter.new(function()
			return 0
		end)
		assert(limiter:allow("1:Attack", 1, 1))
		assert(not limiter:allow("1:Attack", 1, 1))
		assert(limiter:allow("2:Attack", 1, 1))
		assert(limiter:allow("1:UsePotion", 1, 1))
	end)
	test("player removal releases only the matching user's buckets", function()
		local limiter = RateLimiter.new(function()
			return 0
		end)
		assert(limiter:allow("1:Attack", 1, 0))
		assert(limiter:allow("10:Attack", 1, 0))
		limiter:forgetPrefix("1:")
		assert(limiter:allow("1:Attack", 1, 0))
		assert(not limiter:allow("10:Attack", 1, 0))
	end)
end
