--!strict
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Rules = require(ReplicatedStorage.Shared.ProfileRules)
local Lease = require(ReplicatedStorage.Shared.ProfileLease)

local ProfileService = {}
ProfileService.__index = ProfileService

function ProfileService.new()
	local persistent = Config.EnablePersistence
		and not RunService:IsStudio()
		and ReplicatedStorage.PlaceKind.Value ~= "Preview"
	local self = setmetatable({
		entries = {},
		locks = {},
		persistent = persistent,
		store = if persistent then DataStoreService:GetDataStore("FortisProfiles_v1") else nil,
		session = game.JobId .. ":" .. HttpService:GenerateGUID(false),
		closed = false,
	}, ProfileService)
	task.spawn(function()
		while not self.closed do
			task.wait(30)
			if self.closed then
				break
			end
			for player in self.entries do
				task.spawn(function()
					self:save(player, false)
				end)
			end
		end
	end)
	return self
end

-- Serialize operations across entry replacement as well as within one entry.
-- A load waiting for release must acquire fresh data, never the released snapshot.
function ProfileService:_locked(player, callback)
	local deadline = os.clock() + 15
	while self.locks[player] and os.clock() < deadline do
		task.wait(0.1)
	end
	if self.locks[player] then
		return nil
	end
	self.locks[player] = true
	local ok, result = pcall(callback)
	self.locks[player] = nil
	if not ok then
		local entry = self.entries[player]
		if entry then
			entry.unavailable = true
			entry.releasing = false
		end
		warn("[FORTIS] Profile operation failed for user", player.UserId, result)
		return nil
	end
	return result
end

function ProfileService:load(player)
	return self:_locked(player, function()
		return self:_load(player)
	end)
end

function ProfileService:_load(player)
	if self.closed then
		return nil
	end
	if self.entries[player] then
		return self.entries[player].data
	end
	if not self.persistent then
		local data = Rules.new()
		self.entries[player] = { data = data }
		return data
	end
	for attempt = 1, 4 do
		if self.closed then
			return nil
		end
		local ok, record = pcall(function()
			return self.store:UpdateAsync("u:" .. player.UserId, function(old)
				return Lease.acquire(old, self.session, os.time())
			end)
		end)
		if ok and record and record.lock and record.lock.session == self.session then
			self.entries[player] = { data = record.data }
			if self.closed then
				self:_save(player, true)
				return nil
			end
			return record.data
		end
		if attempt < 4 then
			task.wait(attempt)
		end
	end
	warn("[FORTIS] Profile unavailable for user", player.UserId)
	return nil
end

function ProfileService:get(player)
	local entry = self.entries[player]
	return if entry then entry.data else nil
end

function ProfileService:mode()
	return if self.persistent then "Persistent" else "Session"
end

function ProfileService:save(player, release)
	return self:_locked(player, function()
		return self:_save(player, release)
	end) == true
end

function ProfileService:_save(player, release)
	local entry = self.entries[player]
	if not entry then
		return true
	end
	if not self.persistent then
		if release then
			self.entries[player] = nil
		end
		return true
	end
	entry.releasing = release
	local snapshot = Rules.normalize(entry.data)
	local saved = false
	for attempt = 1, 3 do
		local ok, record = pcall(function()
			return self.store:UpdateAsync("u:" .. player.UserId, function(old)
				return Lease.save(old, self.session, snapshot, release, os.time())
			end)
		end)
		if ok and record then
			saved = true
			break
		end
		if attempt < 3 then
			task.wait(attempt)
		end
	end
	entry.releasing = false
	if saved then
		entry.unavailable = false
	end
	if saved and release then
		self.entries[player] = nil
	end
	if not saved then
		-- Fail closed if session ownership cannot be renewed; no new rewards.
		entry.unavailable = true
		warn("[FORTIS] Profile save failed for user", player.UserId)
	end
	return saved
end

function ProfileService:isAvailable(player)
	local entry = self.entries[player]
	return entry ~= nil and not entry.unavailable and not entry.releasing
end

function ProfileService:close()
	self.closed = true
	local pending = 0
	for player in self.entries do
		pending += 1
		task.spawn(function()
			self:save(player, true)
			pending -= 1
		end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end
end

return ProfileService
