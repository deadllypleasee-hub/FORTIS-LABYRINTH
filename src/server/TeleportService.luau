--!strict
-- Only server-created tickets authorize production Dungeon admission.
local RobloxTeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Teleports = {}
local tickets = MemoryStoreService:GetHashMap("FortisRunTickets_v1")

function Teleports.toDungeon(player, seed)
	if Config.HubPlaceId <= 0 or Config.DungeonPlaceId <= 0 then
		return false, "В Config ещё не заданы ID двух Places."
	end
	local ok, err = pcall(function()
		local accessCode, privateServerId = RobloxTeleportService:ReserveServerAsync(Config.DungeonPlaceId)
		local runId = HttpService:GenerateGUID(false)
		tickets:SetAsync(runId, {
			userId = player.UserId,
			seed = seed,
			privateServerId = privateServerId,
			issuedAt = os.time(),
		}, 180)
		local options = Instance.new("TeleportOptions")
		options.ReservedServerAccessCode = accessCode
		options:SetTeleportData({ runId = runId })
		RobloxTeleportService:TeleportAsync(Config.DungeonPlaceId, { player }, options)
	end)
	if not ok then
		warn("[FORTIS] Dungeon teleport failed:", err)
	end
	return ok, if ok then nil else "Переход недоступен. Попробуйте ещё раз."
end

function Teleports.admit(player)
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		return nil
	end
	local join = player:GetJoinData()
	if join.SourcePlaceId ~= Config.HubPlaceId or type(join.TeleportData) ~= "table" then
		return nil
	end
	local runId = join.TeleportData.runId
	if type(runId) ~= "string" or #runId ~= 36 then
		return nil
	end
	local ok, record = pcall(function()
		return tickets:UpdateAsync(runId, function(ticket)
			if not ticket or ticket.userId ~= player.UserId or ticket.privateServerId ~= game.PrivateServerId then
				return nil
			end
			if os.time() - ticket.issuedAt > 180 then
				return nil
			end
			if ticket.claimedBy and ticket.claimedBy ~= game.JobId then
				return nil
			end
			ticket.claimedBy = game.JobId
			return ticket
		end, 180)
	end)
	if ok and record and record.claimedBy == game.JobId then
		return { id = runId, seed = record.seed }
	end
	return nil
end

function Teleports.toHub(player)
	if Config.HubPlaceId <= 0 then
		return false
	end
	local ok, err = pcall(function()
		RobloxTeleportService:TeleportAsync(Config.HubPlaceId, { player })
	end)
	if not ok then
		warn("[FORTIS] Hub teleport failed:", err)
	end
	return ok
end

return Teleports
