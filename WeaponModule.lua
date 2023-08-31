Equipment = {}
Equipment.__index = Equipment

local UIS = game:GetService("UserInputService")
local Debris = game:GetService("Debris")


local IgnoreList = workspace:WaitForChild("IgnoreList")
local EnemiesFolder = workspace.Enemies;
local TweenService = game:GetService("TweenService")
--EQUIP AND UNEQUIP FUNCTIONS

function Equipment.equip(Client, Object, Slot)
	--Client Module Contains Player, Gui
	local newEquip = {
		--Core References
		Client = Client;
		Player = Client.Player;
		Character = Client.Player.Character;
		Mouse = Client.Mouse;
		Gui = Client.Gui;
		--Animation References
		Animator = Client.Player.Character:WaitForChild("Humanoid"):WaitForChild("Animator");
		Animations = {};
		--Gun References
		Model = nil;
		Object = Object;
		Connections = {};
		Config = require(Object:WaitForChild("Config"));
		Slot = Slot;
		--Status Variables
		Reloading = false;
		Shoving = false;
		FireCooldown = false;
		MB1Down = false;	
		Unequipped = false;
		--Spread Variables
		CurrentSpread = 0;
		LastShot = tick();
	
		--Shove Variables
		
	}
	setmetatable(newEquip, Equipment)
	
	--CALL EQUIP ON SERVER
	newEquip.Client.Remotes.WeaponEquip:FireServer(Object)
	
	--WELD AND SET UP GUN MODEL
	newEquip.Model = Object.Model:Clone()
	local motor = newEquip.Model.Handle.Welds.Grip
	motor.Part0 = newEquip.Character:WaitForChild("RightHand")
	motor.Part1 = newEquip.Model.Handle
	motor.Parent = newEquip.Model.Handle

	--LOAD GUN INTO PLAYER
	newEquip.Model.Parent = newEquip.Character
	
	--LOAD AMMO VALUES INTO GUI
	Client.Gui.Equipment[Slot].Ammo.Text = Object.Data.ReserveAmmo.Value
	
	Client.Gui.GunHUD.Ammo.Text = Object.Data.Mag.Value
	Client.Gui.GunHUD.Ammo.TextColor3 = if Object.Data.Mag.Value/newEquip.Config.magsize < 0.33 then Color3.new(1,0,0) else Color3.new(1, 1, 1)
	
	Client.Gui.GunHUD.Ammo.Visible = true
	Client.Gui.GunHUD.Progress.Visible = false
	--SETUP VIEWPOINT ICON AND LOAD GUNHUD
	Client.Gui.GunHUD.Adornee = newEquip.Model.Eject
	
	--LOAD ANIMATIONS AND START IDLE ANIMATION LOOP
	for _, Animation in newEquip.Object.Animations:GetChildren() do
		newEquip.Animations[Animation.Name] = newEquip.Animator:LoadAnimation(Animation)
	end
	
	newEquip.Animations["Idle"]:Play()
	
	--SET UP INITIAL SPREAD AND ZOOM
	newEquip.currentSpread = newEquip.Config.spread.min
	newEquip.maxFOV = newEquip.Config.maxFOV
	
	--SETUP CONNECTIONS
	--TODO ADD MOBILE SUPPORT
	newEquip.Connections["MB1Down"] = newEquip.Mouse.Button1Down:connect(function() newEquip:onMB1Down() end)
	newEquip.Connections["MB1Up"] = newEquip.Mouse.Button1Up:connect(function() newEquip:onMB1Up() end)
	newEquip.Connections["MB2Down"] = newEquip.Mouse.Button2Down:connect(function() newEquip:onMB2Down() end)
	newEquip.Connections["R"] = UIS.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.R then newEquip:reload() end
		end
	end)

	return newEquip
end

function Equipment:unequip()
	--REMOVE GUN MODEL FROM PLAYER
	self.Unequipped = true
	self.Model:Destroy()
	self.Client.Remotes.WeaponUnequip:FireServer(self.Object.Data.Mag.Value, self.Object.Data.ReserveAmmo.Value)

	--STOP AND UNLOAD ANIMATIONS
	for _, Animation in self.Animations do 
		Animation:Stop()
		Animation:Destroy() 
	end
	
	--UNLOAD CONNECTIONS
	for _, Connection in self.Connections do 
		Connection:Disconnect()
	end

end

--GUN FUNCTIONS

function Equipment:fire(Position)
	--CHECK IF RELOAD IS NECESSARY
	if self.Object.Data.Mag.Value <= 0 then self:reload() end
	
	if self.Object.Data.Mag.Value > 0 and not self.FireCooldown and not self.Reloading and not self.Shoving then
		--SET COOLDOWN AND DECREMENT MAG VALUE
		self.FireCooldown = true
		self.Object.Data.Mag.Value = self.Object.Data.Mag.Value - 1
		
		--UPDATE GUI VALUES
		self.Gui.GunHUD.Ammo.TextColor3 = if self.Object.Data.Mag.Value/self.Config.magsize < 0.33 then Color3.new(1, 0, 0) else Color3.new(1, 1, 1)
		self.Gui.GunHUD.Ammo.Text = self.Object.Data.Mag.Value
		
		--PLAY ANIMATIONS AND SOUND
		self.Animations["Shoot"]:Play()
		self.Model.Handle.Sounds.Shoot:Play()
		
		--SHELL EJECTION 
		local shell = self.Object.Effects.Debris.Shell:Clone()
		shell.CFrame = self.Model.Eject.CFrame
		self:addDebris(shell, self.Config.debrisLifetime)
		
		shell:ApplyImpulse(CFrame.Angles(0,math.pi/2,0):VectorToWorldSpace(self.Model.Eject.CFrame.lookVector) * (0.5))
		shell:ApplyAngularImpulse(Vector3.new(math.random(1, 5)/50, math.random(1, 5)/50, math.random(1, 5)/50))

		--MUZZLE FLASH AND LIGHTS
		self.Model.Barrel.LightFX.Enabled = true
		for _, v in pairs(self.Model.Barrel:GetChildren()) do if v:IsA("ParticleEmitter") then v:Emit(1) end end
		
		--SPREAD RECOVERY
		self.CurrentSpread -= (tick() - self.LastShot) * self.Config.spread.recovery
		self.CurrentSpread = math.max(self.CurrentSpread, self.Config.spread.min)

		--SETUP RAYCAST TO GET Y POSITION OF SHOT
		local origin = self.Model.Barrel.Position
		local lvector = self.Character.HumanoidRootPart.CFrame.LookVector * self.Config.range
		
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Whitelist
		params.FilterDescendantsInstances = {EnemiesFolder} 
		
		local initalRayResults = game.Workspace:Raycast(origin, lvector, params) 
		
		if initalRayResults then
			local hrpPos = self:getCharacterFromPart(initalRayResults.Instance).HumanoidRootPart.Position
			lvector = CFrame.new(origin, Vector3.new(initalRayResults.Position.X, hrpPos.Y, initalRayResults.Position.Z)).LookVector * self.Config.range
		end
	
		--MAIN PROJECTILE RAYCASTS
		local directions = {}
		for projectile=1, self.Config.projectiles do
	
			local direction = CFrame.Angles(
				math.rad(math.random(-self.CurrentSpread*10, self.CurrentSpread*10)/60),
				math.rad(math.random(-self.CurrentSpread*10, self.CurrentSpread*10)/20),
				math.rad(math.random(-self.CurrentSpread*10, self.CurrentSpread*10)/20)
			):VectorToWorldSpace(lvector)
			
			table.insert(directions, direction)
		
			local blacklist = {workspace.CurrentCamera, self.Character, IgnoreList} 
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = blacklist

			local lastHit = direction + origin
			local penetrationLeft = self.Config.penetration
			
			while penetrationLeft > 0 do
				
				local rayresults = game.Workspace:Raycast(origin, direction, raycastParams) 

				if rayresults then
					print(rayresults.Instance.Parent)
					if rayresults.Instance:FindFirstAncestor(EnemiesFolder.Name) then
						table.insert(blacklist, self:getCharacterFromPart(rayresults.Instance))
						raycastParams.FilterDescendantsInstances = blacklist
						if penetrationLeft < 1 then lastHit = rayresults.Position end
						self:createImpact(rayresults, true)
						--TODO damage code here
					else
						lastHit = rayresults.Position
						self:createImpact(rayresults, false)
						break
					end
				
				else
					break
				end
				penetrationLeft -= 1
			end
		self:drawRay(origin, lastHit)
			
		end
		--SPREAD INCREASE
		self.CurrentSpread += self.Config.spread.recoil
		self.CurrentSpread = math.min(self.CurrentSpread, self.Config.spread.max)
		self.LastShot = tick()
		
		--REPLICATE TO SERVER
		self.Client.Remotes.GunFire:FireServer(origin, directions)

		--THREADS FOR LIGHT AND FIRECOOLDOWN
		delay(0.07, function() self.Model.Barrel.LightFX.Enabled = false end)
		delay(60/self.Config.firerate, function() self.FireCooldown = false end)
	end
		
		
end

function Equipment:reload()	
	if not self.Reloading
		and self.Object.Data.ReserveAmmo.Value > 0 and self.Object.Data.Mag.Value < self.Config.magsize then
		
		self.Reloading = true
		self.Model.Handle.Sounds.Reload.PlaybackSpeed = self.Model.Handle.Sounds.Reload.TimeLength/self.Config.reloadTime
		self.Model.Handle.Sounds.Reload:Play()
		
		spawn(function()
			self.Gui.GunHUD.Progress.Visible = true
			self.Gui.GunHUD.Ammo.Visible = false
			local percent = 0
			local start = tick()
			
			while percent < 360 and not self.Unequipped do
				percent = math.min((tick() - start)/self.Config.reloadTime * 360, 360)
				local F1, F2 = self.Gui.GunHUD.Progress.Frame1.ImageLabel, self.Gui.GunHUD.Progress.Frame2.ImageLabel
				local color0 = Color3.new(1, 1, 1)
				local color1 = Color3.new(0, 0, 0)
				local trans0 = 0
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
					NumberSequenceKeypoint.new(1, trans1)})--]]
				
				F1.UIGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0,color0),
					ColorSequenceKeypoint.new(0.5,color0),
					ColorSequenceKeypoint.new(0.501,color1),
					ColorSequenceKeypoint.new(1,color1)})
				
				F2.UIGradient.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0,color0),
					ColorSequenceKeypoint.new(0.5,color0),
					ColorSequenceKeypoint.new(0.501,color1),
					ColorSequenceKeypoint.new(1,color1)})
				wait()
			end
			
			self.Gui.Equipment[self.Slot].Ammo.Text = self.Object.Data.ReserveAmmo.Value
			self.Gui.Equipment[self.Slot].Ammo.TextColor3 = if self.Config.magsize >= self.Object.Data.ReserveAmmo.Value then Color3.new(1, 0, 0) else Color3.new(1, 1, 1)
			self.Gui.GunHUD.Ammo.Text = self.Object.Data.Mag.Value
			self.Gui.GunHUD.Ammo.TextColor3 = Color3.new(1, 1, 1)
			self.Gui.GunHUD.Progress.Visible = false
			self.Gui.GunHUD.Ammo.Visible = true
			
		end)
		self.Client.Remotes.GunReload:FireServer()
		
		self.Animations["Reload"]:Play(0.10, 1, self.Animations["Reload"].Length/self.Config.reloadTime)
		
		local mag = self.Object.Effects.Debris.Mag:Clone()
		mag.CFrame = self.Model.Handle.CFrame * CFrame.Angles(0, math.pi/2, 0)
		self:addDebris(mag, self.Config.debrisLifetime)
		
		delay(self.Config.reloadTime, function()
			if not self.Unequipped then
				self.Reloading = false
				if self.Object.Data.ReserveAmmo.Value + self.Object.Data.Mag.Value >= self.Config.magsize then
					self.Object.Data.ReserveAmmo.Value -= self.Config.magsize - self.Object.Data.Mag.Value
					self.Object.Data.Mag.Value = self.Config.magsize
				else
					self.Object.Data.Mag.Value += self.Object.Data.ReserveAmmo.Value
					self.Object.Data.ReserveAmmo.Value = 0
				end
			end
		end)
	end
end

--TODO SERVERSIDE - LOW PRIORITY
function Equipment:shove()
	if not self.Shoving and self.Character.Humanoid:GetAttribute("Stamina") >= 40 then
		self.Shoving = true
		self.Animations["Shove"]:Play()
		self.Character.Humanoid:SetAttribute("Stamina", math.max(0, self.Character.Humanoid:GetAttribute("Stamina") - 40))
		local boxCFrame = self.Character.HumanoidRootPart.CFrame:ToWorldSpace(CFrame.new(0, 0, -self.Config.shove.range/2))
		local size = Vector3.new(self.Config.shove.width, 4, self.Config.shove.range)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Whitelist
		params.FilterDescendantsInstances = {EnemiesFolder}
		
		local results = workspace:GetPartBoundsInBox(boxCFrame, size, params)
		local enemiesHit = {}
		for _, result in results do
			local hit = self:getCharacterFromPart(result)
			enemiesHit[hit] = hit
		end
		
		delay(0.2, function()
			local origin = self.Character.HumanoidRootPart.Position
			for _, enemy in enemiesHit do
				print(enemy.Name)
				
				local lvector = CFrame.new(origin, enemy.HumanoidRootPart.Position).lookVector 
				local direction = lvector * self.Config.shove.knockback
				local params = RaycastParams.new()
				params.FilterDescendantsInstances = {workspace.CurrentCamera, self.Character, EnemiesFolder} 
				
				local info = TweenInfo.new(0.2, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out)

				local rayResults = game.Workspace:Raycast(origin, direction, params)
				if not rayResults then
					TweenService:Create(enemy.HumanoidRootPart, info, {CFrame = CFrame.new(origin + direction, origin)}):Play()	
					local track = enemy.Humanoid.Animator:LoadAnimation(enemy.Humanoid.Animator.Staggered)
					track:Play()
				else
					TweenService:Create(enemy.HumanoidRootPart, info, {CFrame = CFrame.new(rayResults.Position, origin)}):Play()
					local track = enemy.Humanoid.Animator:LoadAnimation(enemy.Humanoid.Animator.Staggered)
					track:Play()
				end
			end
		end)
		delay(self.Animations["Shove"].Length, function()
			self.Shoving = false
		end)
	end
end

--SUPPORTING FUNCTIONS

function Equipment:getCharacterFromPart(Part)
	local currentDepth = Part
	while currentDepth.Parent ~= EnemiesFolder do currentDepth = currentDepth.Parent end
	return currentDepth
end

function Equipment:drawRay(v0, v1)
	local rayPart = self.Object.Effects.BulletTrail:Clone()
	local mag = (v0 - v1).Magnitude
	rayPart.Size = Vector3.new(0.2, 0.2, mag)
	rayPart.CFrame = CFrame.lookAt(v0, v1) * CFrame.new(0, 0, -mag / 2)
	self:addDebris(rayPart, 0.03)
end

function Equipment:addDebris(Part, lifeSpan)
	Part.CollisionGroup = "Debris"
	Part.Parent = workspace.CurrentCamera
	Debris:AddItem(Part, lifeSpan)
end

function Equipment:createImpact(rayResult, enemy)
	local hole = script.bulletHole:Clone()
	hole.CFrame = CFrame.new(rayResult.Position, self.Character.HumanoidRootPart.Position)
	
	local effect = self.Object.Effects.Impact.Default
	if enemy then
		effect = self.Object.Effects.Impact.Enemy
	elseif self.Object.Effects.Impact:FindFirstChild(rayResult.Material) then
		effect = self.Object.Effects.Impact[rayResult.Material]
	end
	
	effect = effect:Clone()
	effect.Enabled = false
	effect.EmissionDirection = Enum.NormalId.Front
	effect.Parent = hole
	
	local sound = self.Object.Sounds.Impact.Default
	if enemy then
		sound = self.Object.Sounds.Impact.Enemy
	elseif self.Object.Sounds.Impact:FindFirstChild(rayResult.Material) then
		sound = self.Object.Sounds.Impact[rayResult.Material]
	end

	sound = sound:Clone()
	sound.Parent = hole
	
	self:addDebris(hole, 2)
	effect:Emit(1)
	sound:Play()
end

--INPUT EVENTS

function Equipment:onMB1Down()
	self.MB1Down = true
	
	if self.Character.Humanoid.Health <= 0 then return end
	
	if self.Config.firemode == "auto" then
		spawn(function()
			while self.MB1Down and self.Character.Humanoid.Health > 0 do
				self:fire()
				wait(60/self.Config.firerate)
			end
		end)
	else
		self:fire()
	end
end

function Equipment:onMB1Up()
	self.MB1Down = false
end

function Equipment:onMB2Down()	
	
	if self.Character.Humanoid.Health <= 0 then return end
	
	self:shove()
end




return Equipment