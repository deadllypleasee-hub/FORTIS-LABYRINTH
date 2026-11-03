--!strict
-- Pure MemoryStore transformation: one ticket authorizes one admission attempt.
local RunTicket = { Lifetime = 180 }

local function integer(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge and value % 1 == 0
end

function RunTicket.claim(ticket: any, userId: number, serverId: string, jobId: string, claimId: string, now: number)
	if type(ticket) ~= "table" or not integer(now) or now < 0 or #serverId == 0 or #jobId == 0 or #claimId == 0 then
		return nil
	end
	if ticket.userId ~= userId or ticket.privateServerId ~= serverId then
		return nil
	end
	if not integer(ticket.seed) or ticket.seed < 1 or ticket.seed > 2147483646 then
		return nil
	end
	if not integer(ticket.issuedAt) or ticket.issuedAt > now or now - ticket.issuedAt >= RunTicket.Lifetime then
		return nil
	end
	if ticket.claimedBy ~= nil or ticket.claimId ~= nil then
		if ticket.claimedBy ~= jobId or ticket.claimId ~= claimId then
			return nil
		end
	end
	local claimed = table.clone(ticket)
	claimed.claimedBy = jobId
	claimed.claimId = claimId
	return claimed
end

return table.freeze(RunTicket)
