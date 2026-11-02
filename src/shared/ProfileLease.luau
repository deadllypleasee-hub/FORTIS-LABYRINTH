--!strict
-- Pure UpdateAsync transformations. No callback yields or mutates the old record.
local ProfileRules = require(if script then script.Parent.ProfileRules else "./ProfileRules")

local ProfileLease = {}
local LEASE_SECONDS = 120

export type Record = {
	data: ProfileRules.Profile,
	lock: { session: string, expires: number }?,
	-- A release retry may observe its own prior commit after an ambiguous timeout.
	-- Acquiring a fresh lease always removes this marker.
	releasedBy: string?,
}

local function finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

local function validRequest(session: string, now: number): boolean
	return #session > 0 and finite(now) and now >= 0
end

local function knownSchema(old: any): boolean
	if old == nil then
		return true
	end
	if type(old) ~= "table" or type(old.data) ~= "table" then
		return false
	end
	local version = old.data.version
	-- A missing version is the legacy version 0; other malformed values fail closed.
	return version == nil or (finite(version) and version >= 0 and version <= 1 and version % 1 == 0)
end

local function validLock(lock: any): boolean
	return type(lock) == "table" and type(lock.session) == "string" and #lock.session > 0 and finite(lock.expires)
end

function ProfileLease.acquire(old: any, session: string, now: number): Record?
	if not validRequest(session, now) or not knownSchema(old) then
		return nil
	end
	if old and old.lock ~= nil then
		if not validLock(old.lock) then
			return nil
		end
		if old.lock.session ~= session and old.lock.expires > now then
			return nil
		end
	end
	return {
		data = ProfileRules.normalize(if old then old.data else nil),
		lock = { session = session, expires = now + LEASE_SECONDS },
	}
end

function ProfileLease.save(
	old: any,
	session: string,
	snapshot: ProfileRules.Profile,
	release: boolean,
	now: number
): Record?
	if not validRequest(session, now) or old == nil or not knownSchema(old) then
		return nil
	end
	if old.lock == nil then
		if release and old.releasedBy == session then
			-- Return the committed value, never a newer/different caller snapshot.
			return old
		end
		return nil
	end
	if not validLock(old.lock) or old.lock.session ~= session then
		return nil
	end
	return {
		data = ProfileRules.normalize(snapshot),
		lock = if release then nil else { session = session, expires = now + LEASE_SECONDS },
		releasedBy = if release then session else nil,
	}
end

return table.freeze(ProfileLease)
