Client = {}
Client.__index = Client

local Remotes = (game.ReplicatedStorage.GameData.RemoteEvents)
local GunModule = require(game.ReplicatedStorage.GameData.Modules.WeaponModule)
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

function Client.new(Player, Gui)

	local Character = Player.Character
	local Mouse = Player:GetMouse()
	local Camera = workspace.CurrentCamera
	
	local obj = {
		Player = Player;
		Character = Character;
		Mouse = Mouse;
		Camera = Camera;
		Gui = Gui;
		CurrentEquipped = nil;
		CurrentSlot = "";
		baseFOV = 70;
		Remotes = game.ReplicatedStorage:WaitForChild("GameData"):WaitForChild("RemoteEvents");
		Inventory = game.ReplicatedStorage.PlayerData[Player.Name].Inventory;
	}
	setmetatable(obj, Client)

	--SET UP GUI
	Gui.Equipment.Visible = true
	
	--SET UP STAMINA
	local maxStam = 100
	Character:WaitForChild("Humanoid"):SetAttribute("Stamina", maxStam)
	Character.Humanoid:SetAttribute("MaxStamina", maxStam)
	
	--DISABLE AUTO ROTATE
	Character.Humanoid.AutoRotate = false
	
	--SET UP SURFACE GUI FOR HEALTH AND STAMINA
	local guiPart = script.guiPart:Clone()
	guiPart.Motor6D.Part0 = Character:WaitForChild("HumanoidRootPart")
	guiPart.Parent = Character
	Gui.HUD.Adornee = guiPart
	
	--HEALTH BAR SETUP
	Character.Humanoid.HealthChanged:Connect(function()
		local percent = math.min((Character.Humanoid.Health/Character.Humanoid.MaxHealth) * 360, 360)
		local F1, F2 = Gui.HUD.Health.Frame1.ImageLabel, Gui.HUD.Health.Frame2.ImageLabel
		local trans0 = 0.5
		local trans1 = 1
		F1.UIGradient.Rotation = math.clamp(percent,180,360)
		F2.UIGradient.Rotation = math.clamp(percent,0,180) 
		
		--F1.ImageColor3 = ColorSequence.new({

		F1.UIGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, trans0),
			NumberSequenceKeypoint.new(0.5, trans0),
			NumberSequenceKeypoint.new(0.501, trans1),
			NumberSequenceKeypoint.new(1, trans1)})
		F2.UIGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, trans0),
			NumberSequenceKeypoint.new(0.5, trans0),
			NumberSequenceKeypoint.new(0.501, trans1),
			NumberSequenceKeypoint.new(1, trans1)})
	end)
	
	--STAMINA BAR SETUP
	Character.Humanoid:GetAttributeChangedSignal("Stamina"):Connect(function()
		local percent = math.min((Character.Humanoid:GetAttribute("Stamina")/Character.Humanoid:GetAttribute("MaxStamina")) * 360, 360)
		local F1, F2 = Gui.HUD.Stamina.Frame1.ImageLabel, Gui.HUD.Stamina.Frame2.ImageLabel
		local trans0 = 0.2
		local trans1 = 1
		F1.UIGradient.Rotation = math.clamp(percent,180,360)
		F2.UIGradient.Rotation = math.clamp(percent,0,180) 
		
		F1.UIGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, trans0),
			NumberSequenceKeypoint.new(0.5, trans0),
			NumberSequenceKeypoint.new(0.501, trans1),
			NumberSequenceKeypoint.new(1, trans1)})
		F2.UIGradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, trans0),
			NumberSequenceKeypoint.new(0.5, trans0),
			NumberSequenceKeypoint.new(0.501, trans1),
			NumberSequenceKeypoint.new(1, trans1)})
		
		local trans = 1 - math.clamp(Character.Humanoid:GetAttribute("Stamina")/40, 0 ,1)
		F1.ImageTransparency = trans
		F2.ImageTransparency = trans

	end)
	
	--SET UP CAMERA AND STAMINA RECOVERY
	local recoveryPerTick = 0.5
	game:GetService("RunService").RenderStepped:connect(function()
		local cameraPos = Vector3.new(0, 40, 0) + Character.HumanoidRootPart.Position
		Character.HumanoidRootPart.CFrame = CFrame.new(Character.HumanoidRootPart.Position) * CFrame.Angles(0, math.atan2(Mouse.X - Gui.AbsoluteSize.X/2, Mouse.Y - Gui.AbsoluteSize.Y/2) + math.pi/2, 0)
		Camera.CFrame = CFrame.new(cameraPos, cameraPos + Vector3.new(0, -1, 0))
		Camera.CameraType = Enum.CameraType.Scriptable
		Character.Humanoid:SetAttribute("Stamina", math.min(maxStam, recoveryPerTick + Character.Humanoid:GetAttribute("Stamina")))
	end)--]]
	
	--SET UP KEYBOARD CONNECTIONS
	local UIS = game:GetService("UserInputService")
	UIS.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.One then 
				obj:equip("Weapon1")
			elseif input.KeyCode == Enum.KeyCode.Two then
				obj:equip("Weapon2")
			end
		end
	end)
	
	--SET UP CHARACTER COLLISION GROUPS
	for i, v in ipairs(Character:GetDescendants()) do
		if v:IsA("BasePart") then v.CollisionGroup = "Players" end
	end
	
	--SET UP CLIENT EVENTS
	obj:setupClientEvents()
	--Character.Humanoid.WalkSpeed = baseWalkspeed + currentGun.Config.walkspeedModifier
	return obj
end

function Client:equip(Slot)
	
	for _, equipmentFrame in self.Gui.Equipment:GetChildren() do
		equipmentFrame.UIStroke.Color = Color3.new()
		if equipmentFrame:FindFirstChild("ViewportFrame") then equipmentFrame.ViewportFrame.ImageTransparency = 0.8 end
		if equipmentFrame:FindFirstChild("Ammo") then equipmentFrame.Ammo.TextTransparency = 0.8 end
	end
	
	if self.CurrentEquipped then self.CurrentEquipped:unequip() end
	
	if self.CurrentSlot == Slot then
		self.CurrentSlot = ""
		TweenService:Create(self.Camera, TweenInfo.new(0.1), {FieldOfView=self.baseFOV}):Play()
		return
	end
	
	self.CurrentSlot = Slot
	self.Gui.Equipment[Slot].ViewportFrame.ImageTransparency = 0
	self.Gui.Equipment[Slot].Ammo.TextTransparency = 0
	self.Gui.Equipment[Slot].UIStroke.Color = Color3.new(1, 1, 1)
	
	if Slot == "Weapon1" or Slot == "Weapon2" then
		local Gun = self.Inventory[Slot]:FindFirstChildOfClass("Model")
		self.CurrentEquipped = GunModule.equip(self, Gun, Slot)
		TweenService:Create(self.Camera, TweenInfo.new(0.1), {FieldOfView=self.CurrentEquipped.Config.maxFOV}):Play()
	else
		TweenService:Create(self.Camera, TweenInfo.new(0.1), {FieldOfView=self.baseFOV}):Play()
	end
	
	--gunmod.equip(player, screenGui.Inventory.Weapon1.M4, nil, workspace:WaitForChild("Enemies"), screenGui, "Weapon1")--IgnoreList, EnemiesFolder
end

--TODO CHECK EMPTY LOGIC
function Client:pickUp(Slot, Equipment)
	Equipment.Parent = self.Inventory[Slot]
	--setup viewpoint icon
	local viewportFrame = self.Gui.Equipment[Slot].ViewportFrame

	local part = Equipment.Model.Handle:Clone()
	part.TextureID = ""
	part.CFrame = CFrame.new()
	part.Parent = viewportFrame

	local cam = Instance.new("Camera", viewportFrame)
	cam.CFrame = CFrame.new(Equipment.ViewpointCFrame.Value.Position, part.Position)
	viewportFrame.CurrentCamera = cam
	
	if Slot == "Weapon1" or Slot == "Weapon2" then
		local config = require(Equipment.Config)
		Equipment.Data.Mag.Value = if Equipment.Data.Mag.Value == -1 then config.magsize else Equipment.Data.Mag.Value
		Equipment.Data.ReserveAmmo.Value = if Equipment.Data.ReserveAmmo.Value == -1 then config.maxReserveAmmo else Equipment.Data.ReserveAmmo.Value
		
		self.Gui.Equipment[Slot].Ammo.TextColor3 = if config.magsize >= Equipment.Data.ReserveAmmo.Value then Color3.new(1, 0, 0) else Color3.new(1, 1, 1)
		
		self.Gui.Equipment[Slot].Ammo.Text = Equipment.Data.ReserveAmmo.Value	
		self.Gui.Equipment[Slot].Ammo.Visible = true
	
	end
	
	--Remotes.ClientPickup:FireServer(Equipment)

end

function Client:mouseRaycast(rayParams)
	local ray = self.Mouse.UnitRay
	local origin, direction = ray.Origin, ray.Direction.Unit * 500 
	return workspace:Raycast(origin, direction, rayParams)
end 

--CLIENT EVENTS

function Client:setupClientEvents()
	Remotes.WeaponEquip.OnClientEvent:Connect(function(Character, Model)
		print(Character, Model)
		self:renderOtherPlayerEquip(Character, Model)
	end)
	
	Remotes.WeaponUnequip.OnClientEvent:Connect(function(Character)
		self:renderOtherPlayerUnequip(Character)
	end)
	
	Remotes.GunFire.OnClientEvent:Connect(function(Character, GunData, RayImpactData)
		self:renderOtherPlayerFire(Character, GunData, RayImpactData)
	end)
	
	Remotes.GunReload.OnClientEvent:Connect(function(Character, GunData, reloadSpeed)
		self:renderOtherPlayerReload(Character, GunData, reloadSpeed)
	end)
end

function Client:renderOtherPlayerEquip(Character, Model)
	--SANITY CHECK
	if Character == self.Character then return end
	
	--LOAD AND WELD EQUIPMENT
	local WeaponModel = Model:Clone()
	WeaponModel.Name = "VisualEquipment"
	local motor = WeaponModel.Handle.Welds.Grip
	motor.Part0 = Character:WaitForChild("RightHand")
	motor.Part1 = WeaponModel.Handle
	motor.Parent = WeaponModel.Handle
	WeaponModel.Parent = Character
	
end

function Client:renderOtherPlayerUnequip(Character)
	--SANITY CHECK
	if Character == self.Character then return end
	
	--DESTROY VISUAL
	if Character:FindFirstChild("VisualEquipment") then
		Character.VisualEquipment:Destroy()
	end
end

function Client:renderOtherPlayerFire(Character, GunData, RayImpactData)
	--SANITY CHECK
	if Character == self.Character then return end
	if not Character:FindFirstChild("VisualEquipment") then return end
	--PLAY SOUND
	Character.VisualEquipment.Handle.Sounds.Shoot:Play()

	--SHELL EJECTION 
	local shell = GunData.Effects.Debris.Shell:Clone()
	shell.CFrame = Character.VisualEquipment.Eject.CFrame
	shell.CollisionGroup = "Debris"
	shell.Parent = workspace.CurrentCamera
	Debris:AddItem(shell, 1)

	shell:ApplyImpulse(CFrame.Angles(0,math.pi/2,0):VectorToWorldSpace(Character.VisualEquipment.Eject.CFrame.lookVector) * (0.5))
	shell:ApplyAngularImpulse(Vector3.new(math.random(1, 5)/50, math.random(1, 5)/50, math.random(1, 5)/50))

	--MUZZLE FLASH AND LIGHTS
	Character.VisualEquipment.Barrel.LightFX.Enabled = true
	for _, v in pairs(Character.VisualEquipment.Barrel:GetChildren()) do if v:IsA("ParticleEmitter") then v:Emit(1) end end
	delay(0.07, function() Character.VisualEquipment.Barrel.LightFX.Enabled = false end)
	
	--DRAW RAYS
	for _, lastHit in RayImpactData.lastHits do
		local rayPart = GunData.Effects.BulletTrail:Clone()
		local mag = (RayImpactData.origin - lastHit).Magnitude
		rayPart.Size = Vector3.new(0.2, 0.2, mag)
		rayPart.CFrame = CFrame.lookAt(RayImpactData.origin, lastHit) * CFrame.new(0, 0, -mag / 2)
		rayPart.CollisionGroup = "Debris"
		rayPart.Parent = workspace.CurrentCamera
		Debris:AddItem(rayPart, 0.03)
	end
	
	--CREATE IMPACTS
	for _, impactData in RayImpactData.Impacts do
		local hole = script.bulletHole:Clone()
		hole.CFrame = CFrame.new(impactData[2], RayImpactData.origin)

		local effect = GunData.Effects.Impact.Default
		if impactData[1] then
			effect = GunData.Effects.Impact.Enemy
		elseif GunData.Effects.Impact:FindFirstChild(impactData[3]) then
			effect = GunData.Effects.Impact[impactData[3]]
		end

		effect = effect:Clone()
		effect.Enabled = false
		effect.EmissionDirection = Enum.NormalId.Front
		effect.Parent = hole

		local sound = GunData.Sounds.Impact.Default
		if impactData[1] then
			sound = GunData.Sounds.Impact.Enemy
		elseif GunData.Sounds.Impact:FindFirstChild(impactData[3]) then
			sound = GunData.Sounds.Impact[impactData[3]]
		end

		sound = sound:Clone()
		sound.Parent = hole

		hole.CollisionGroup = "Debris"
		hole.Parent = workspace.CurrentCamera
		Debris:AddItem(hole, 1)
		
		effect:Emit(1)
		sound:Play()
	end
	
end

function Client:renderOtherPlayerReload(Character, GunData, reloadSpeed)
	--SANITY CHECK
	if Character == self.Character then return end
	if not Character:FindFirstChild("VisualEquipment") then return end
	
	--MAG DROP AND SOUND
	local mag = GunData.Effects.Debris.Mag:Clone()
	mag.CFrame = Character.VisualEquipment.Handle.CFrame * CFrame.Angles(0, math.pi/2, 0)
	mag.CollisionGroup = "Debris"
	mag.Parent = workspace.CurrentCamera
	Debris:AddItem(mag, 1)
	
	Character.VisualEquipment.Handle.Sounds.Reload.PlaybackSpeed = Character.VisualEquipment.Handle.Sounds.Reload.TimeLength/reloadSpeed
	Character.VisualEquipment.Handle.Sounds.Reload:Play()
end

function Client:renderEnemyShoved(Enemy)
	
end


return Client