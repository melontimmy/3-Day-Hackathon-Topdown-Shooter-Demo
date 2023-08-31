
local player = game.Players.LocalPlayer
local mouse = player:GetMouse()
local screenGui = script.Parent
local camera = workspace.CurrentCamera

local RS = game:GetService("ReplicatedStorage")
local GameData = game:GetService("ReplicatedStorage"):WaitForChild("GameData")
local Client = require(GameData.Modules.ClientModule)

local baseWalkspeed = 16

local localClient = Client.new(game.Players.LocalPlayer, script.Parent)
local Inventory = RS.PlayerData:WaitForChild(player.Name).Inventory
local m4New = Inventory.Weapon1.M4
local m42New = Inventory.Weapon2.M42


localClient:pickUp("Weapon1", m4New)
localClient:pickUp("Weapon2", m42New)




player.Character.Humanoid.Health = 90