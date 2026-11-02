local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HUD = require(script.Parent.HUD)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
if not remotes then
	warn("[FORTIS] Server remotes did not initialize within 30 seconds")
	return
end

local action = remotes:WaitForChild("Action", 15)
local state = remotes:WaitForChild("State", 15)
local notify = remotes:WaitForChild("Notify", 15)
if not action or not state or not notify then
	warn("[FORTIS] Incomplete remote protocol")
	return
end

local hud = HUD.new(player, { Action = action, State = state, Notify = notify })
script.Destroying:Connect(function()
	hud:destroy()
end)
