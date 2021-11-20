--!strict
-- For appropriate use, this must be initialized on the server first.
local BadgeService = game:GetService("BadgeService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Replicate;
if script:FindFirstChild("Replicate") then
	Replicate = script.Replicate
else
	if RunService:IsClient() then
		error("This module was required on the client before it was required on the server. Please ensure that the server initializes it first.")
	end
	Replicate = Instance.new("RemoteEvent", script)
	Replicate.Name = "Replicate"
end

local BadgeData = {}

function BadgeData.UserHasBadge(player: number | Player, badgeId: number)
	local userId: number = 0;
	if (typeof(player) == "Instance") then
		userId = (player::Player).UserId
	else
		userId = player::number
	end
	
	if RunService:IsClient() then
		local id = HttpService:GenerateGUID()
		local recvId: string = ""
		local hasBadge: boolean = false
		Replicate:FireServer(id, userId, badgeId)
		repeat	
			recvId, hasBadge = Replicate.OnClientEvent:Wait()
		until recvId == id
		return hasBadge
	else
		return BadgeService:UserHasBadgeAsync(userId, badgeId)
	end
end

if RunService:IsServer() then
	Replicate.OnServerEvent:Connect(function (player: Player, eventId: string, userId: number, badgeId: number)
		if typeof(userId) ~= "number" or typeof(badgeId) ~= "number" or typeof(eventId) ~= "string" then 
			Replicate:FireClient(player, eventId, false)
			return
		end
		
		local hasBadge = BadgeService:UserHasBadgeAsync(userId, badgeId)
		Replicate:FireClient(player, eventId, hasBadge)
	end :: any) -- The Any cast makes it stop complaining
end

return BadgeData