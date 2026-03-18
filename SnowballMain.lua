--services and remotes for communication between the client and the server
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SnowCarvingTime = ReplicatedStorage:WaitForChild("Events"):WaitForChild("SnowCarvingTime")
local ChangePlayerFOV = ReplicatedStorage:WaitForChild("Events"):WaitForChild("ChangePlayerFOV")
local AllowSnowCarving = ReplicatedStorage:WaitForChild("Events"):WaitForChild("AllowSnowCarving")
local CreateBeam = game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("CreateBeam")
--pre made destroyed snow model that we will clone for a cool effect when the snowball hits the ground
local DestroyedSnow = ReplicatedStorage:WaitForChild("DestroyedSnow")
--animations for holding big and small snowballs
local BigCarryEquip = script:WaitForChild("BigCarryEquip")
local SmallCarryEquip = script:WaitForChild("SmallCarryEquip")
--table used to create a throw accuracy ui animation for each individual player by storing the frame, accuracy time and a boolean to check if the loop is going or not
local playerdata = {}
--table to store an os.clock start time so we can calculate how long the player was carving snow for, because if we let the client just send the information it could be exploitable 
local carvingstart = {}

--a function we will use to create a throw accuracy ui animation for when they are holding a snowball
local function accuracyloop(plr)
	local pd = playerdata[plr]
	if not pd then return end
	--while the loopgoing boolean stored in the playerdata table is true the loop will contunue running, so we can easily control when this should run and when it shouldnt
	while pd.loopgoing do
		--save the starting time for the first direction the accuracy bar will loop in
		local starttime = os.clock()
		--this is the first direction loop where we go from 0 to 100. we check if the loop is still going and if the time elapsed is less than the total time in the player data that we set later in this script using a mathematical equation depending on the size of the snowballs
		while pd.loopgoing and os.clock() - starttime < pd.accuracytiming do
			--we calculate the progress of the bar and then set the position of the bar to the calculated position
			local progress = (os.clock() - starttime) / pd.accuracytiming
			local acc = math.floor(progress * 100)
			local bary = 0.973 + (0.026 - 0.973) * (acc / 100)
			pd.frame.Position = UDim2.new(0.501, 0, bary, 0)
			--we use an invisible part so later we can add a beam to show the trajectory the snowball / projectile will take
			if pd.trajpart then
				--we get the character and humanoid root part of the player so we can put the part as many studs infront of the player as the current accuracy score
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					--we use roblox's built in physics: lerp to smoothly move the part while the accuracy is changing
					local lookvector = hrp.CFrame.LookVector
					local targetpos = hrp.Position + lookvector * acc
					targetpos = Vector3.new(targetpos.X, pd.trajpart.Position.Y, targetpos.Z)
					pd.trajpart.Position = pd.trajpart.Position:Lerp(targetpos, 0.15)
				end
			end
			--update every frame
			RunService.Heartbeat:Wait()
		end
		--same thing as everything above but going 100 to 0
		starttime = os.clock()
		while pd.loopgoing and os.clock() - starttime < pd.accuracytiming do
			local progress = (os.clock() - starttime) / pd.accuracytiming
			local acc = 100 - math.floor(progress * 100)
			local bary = 0.973 + (0.026 - 0.973) * (acc / 100)
			pd.frame.Position = UDim2.new(0.501, 0, bary, 0)
			if pd.trajpart then
				local char = plr.Character
				local hrp = char and char:FindFirstChild("HumanoidRootPart")
				if hrp then
					local lookvector = hrp.CFrame.LookVector
					local targetpos = hrp.Position + lookvector * acc
					targetpos = Vector3.new(targetpos.X, pd.trajpart.Position.Y, targetpos.Z)
					pd.trajpart.Position = pd.trajpart.Position:Lerp(targetpos, 0.15)
				end
			end
			RunService.Heartbeat:Wait()
		end
	end
end
--we wait for the client to send the SnowCarvingTime event so we can give the player a tool (snowball) that they can then throw
SnowCarvingTime.OnServerEvent:Connect(function(plr, status)
	local playergui = plr:WaitForChild("PlayerGui")
	--we check the status (its either Start or End)
	if status == "Start" then
		--if its Start we save an os.clock() to the carvingstart table so when we get the next event fired with the "End" status we can calculate how long it took
		carvingstart[plr] = os.clock()
	elseif status == "End" then
		--if its End that means the player stopped holding left click and now we can calculate the duration. we do it this way because if we let the client simply send how long the player was holding left click, an exploiter could easily just send a ridiculous number like 4725832 (even tho it later we clamp to a 100 its better to have the game be 100% legit and not exploitable)
		local start = carvingstart[plr]
		--incase an exploiter fires an "End" and there is no start we simply dont continue
		if not start then return end
		--we calculate the duration by simply subtracting the start from the current os.clock()
		local duration = os.clock() - start
		--now we reset the carvingstart table to nil which basically means nothing. not 0, but nothing.
		carvingstart[plr] = nil
		--as i mentioned we clamp the duration between 0-100, because its kindof pointless to have bigger snowballs. clamping basically means setting a minimum and a maximum, and if anything is lower or higher it will simply adjust to the minimum and maximum
		duration = math.clamp(duration, 0, 100)
		--we check if the duration was atleast 0.5 (we dont use clamp for this because someone can hold down their mouse for 0.1 second and get a 0.5 durationed snowball which is kindof unfair, so we clamp it betweem 0-100 and simply not continue if its under 0.5)
		if duration < 0.5 then return end
		--we create a tool, name it Snowball and use the %.2fkg method to format the first 2 digits of the duration, so instead of getting something like 0.7437257835485184583 we get 0.74, then we simply parent it to the players backpack and set some properties
		local snowball = Instance.new("Tool")
		snowball.Name = string.format("Snowball %.2fkg", duration)
		snowball.CanBeDropped = false
		snowball.Parent = plr.Backpack
		--we create a part named Handle, and when a part is named "Handle" inside a tool, it basically becomes the base of the tool, we give it a snowbally look, and parent it to the tool. we divide the size by 2 to get a more realistic sized snowball
		local handle = Instance.new("Part")
		handle.Parent = snowball
		handle.Name = "Handle"
		handle.Shape = Enum.PartType.Ball
		handle.Material = Enum.Material.Snow
		handle.Color = Color3.fromRGB(205, 205, 205)
		handle.Size = Vector3.new(duration / 2, duration / 2, duration / 2)
		handle.CanCollide = false
		handle.Massless = true
		--we create a hitbox that we will use as part0 for the visual trajectory beam, and we make the size be the same as the handle
		local hitbox = Instance.new("Part")
		hitbox.Parent = snowball
		hitbox.Name = "Hitbox"
		hitbox.Transparency = 1
		hitbox.CanCollide = false
		hitbox.Size = Vector3.new(duration / 2, duration / 2, duration / 2)
		hitbox.Massless = true
		--we use a weldconstraint to weld the hitbox and the handle (snowball) together
		local weld = Instance.new("WeldConstraint")
		weld.Parent = snowball
		weld.Name = "weld"
		weld.Part0 = handle
		weld.Part1 = hitbox
		--we get all this information so we can play animations when snowballs are equipped
		local char = plr.Character or snowball.Parent
		local hum = char:WaitForChild("Humanoid")
		local anim1 = hum:LoadAnimation(BigCarryEquip)
		local anim2 = hum:LoadAnimation(SmallCarryEquip)
		--we use the built in .Equipped event to check when the tool is equipped
		snowball.Equipped:Connect(function()
			--we use a client event to make the client not be able create new snowballs and send the server more events
			AllowSnowCarving:FireClient(plr, false)
			--we create a cool little realistic walkspeed, the heavier the snowball the slower you go, and we use math.clamp yet again, because if the size was 0.5 our speed would be insane, so we simply clamp it between 0.64 and 16
			hum.WalkSpeed = math.clamp(64 / handle.Size.X, 0.64, 16)
			--this is a complicated equation. basically i decided i want a 0.5 kg snowball's loop to be a total of 4 seconds long (so 0-100 being 2 and 100-0 being another 2) and wanted a 100kg snowball to have a 0.5 total time (so 0.25 each loop), and we use math.log to get the exponent we are going to use while calculating using the power law decay/power function equation
			local x = handle.Size.X * 2
			local k = math.log(0.25 / 2) / math.log(0.5 / 100)
			local accuracytime = 2 * ((0.5 / x) ^ k)
			--we create all the playerdata we need for the loop (accuracy bar)
			playerdata[plr] = {
				frame = playergui:WaitForChild("UI"):WaitForChild("ThrowingBar"):WaitForChild("AccuracyBar"),
				accuracytiming = accuracytime,
				loopgoing = true,
			}
			--we create the part that we are going to use to create a cool trajectory showing where the snowball will land
			local trajpart = Instance.new("Part")
			trajpart.Name = plr.Name.."_TrajectoryPart"
			trajpart.Anchored = true
			trajpart.CanCollide = false
			trajpart.Transparency = 1
			trajpart.Size = Vector3.new(1,1,1)
			trajpart.Parent = workspace
			--we save it in the plrdata and also make the accuracy bar visible
			playerdata[plr].trajpart = trajpart
			playerdata[plr].frame.Parent.Visible = true
			--we wait a little before creating the beam on the client to make sure everything is loaded
			task.wait(0.1)
			--we create the beam on the client
			CreateBeam:FireClient(plr, hitbox, trajpart)
			--we start the loop, and to avoid everything stopping and waiting for the loop to be finished we use a task.spawn meaning the loop continues running while everything else continues running
			task.spawn(accuracyloop, plr)
			--i decided that anything 10kg or more counts as a big snowball, and anything below counts as small, because it would look kinda weird holding a 100kg ball in 1 hand, and since 10kg = 5 studs we check if the x axis is atleast 5 or more (it doesnt have to be the x, it can be any because its all the same but i chose x)
			if handle.Size.X >= 5 then
				--usually handles are put in your hand by getting the middle of the part to be where your character holds, however we want the snowball to be held at the very edge, meaning we need to divide the z axis, since the edge from the middle is 2x away in any direction
				local offset = handle.Size.Z / 2
				--then we set the grip to it (also adding a  1.5 x axis since this is the big snowball and we want it to be over our heads)
				snowball.Grip = CFrame.new(1.5, 0, offset - 0.5)
				--now we play the animation i made
				anim1:Play()
				--and change the FOV of the player to 100
				ChangePlayerFOV:FireClient(plr, 100)
			else
				--same thing as above except theres no 1.5 x axis
				local offset = handle.Size.Z / 2
				snowball.Grip = CFrame.new(0, 0, offset)
				--we play the animation i made
				anim2:Play()
				--and this time only make the fov 80
				ChangePlayerFOV:FireClient(plr, 80)
			end
			--now we use the .activated built in event to see when the player activates the tool which is usually left click but on phone just a tap
			snowball.Activated:Connect(function()
				local pd = playerdata[plr]
				if not pd or not pd.trajpart then return end
				--we stop the loop from going, since we are ready to throw, and the accuracy that the loop had while we stopped it is the power the snowball will have while throwing
				pd.loopgoing = false
				--we make the frame invisible
				pd.frame.Parent.Visible = false
				--stop both the animations (was kinda lazy but we could technically check which animation is playing and only stop that but this works aswell)
				anim1:Stop()
				anim2:Stop()
				--we can use the trajectorypart that is invisible to calculate where the snowball will land
				local throwtarget = pd.trajpart.Position
				--and use the handle as the starter position (obviously) but we could also use the hitbox it doesnt really make a difference
				local startpos = handle.Position
				--now we clone the handle from our inventory
				local projectile = handle:Clone()
				--we give it all this info
				projectile.Name = plr.Name .. "'s projectile"
				projectile.Parent = workspace
				projectile.CFrame = handle.CFrame
				projectile.Anchored = false
				projectile.Massless = false
				projectile.CanCollide = false
				--wait a tiny bit to make sure the ball doesnt collide with the player and then re enable it so it can collide with everything else
				task.delay(0.1, function()
					if projectile then
						projectile.CanCollide = true
					end
				end)
				local trajpartref = pd.trajpart
				playerdata[plr] = nil
				--we us the .Touched event to see when the snowball hits something
				projectile.Touched:Connect(function(hit)
					--if whatever it hit had cancollide on then we return and then wait to see if it ever hits anything collidable
					if hit.CanCollide == false then return end
					--if whatever it hit is part of the character of the player who was throwing, it should return and wait for something else to be touched
					if hit:IsDescendantOf(char) then return end
					--now we check if it has a humanoid, if it does we take damage
					local hum = hit.Parent:FindFirstChild("Humanoid")
					if hum then
						hum.Health -= duration * 2.5
					--if it doesnt have a humaanoid we simply clone the snowbump from replicatedstorage to create a little destroyed snowball effect
					else
						local snowbump = DestroyedSnow:Clone()
						snowbump.Name = plr.Name .. "'s destroyed snow"
						snowbump.Parent = workspace
						snowbump.Size = Vector3.new(duration / 2, duration / 4, duration / 2)
						--we calculate to make sure the snowbumps bottom is on the hit's top
						local hittop = hit.Position.Y + (hit.Size.Y / 2)
						snowbump.Position = Vector3.new(projectile.Position.X, hittop + snowbump.Size.Y / 2, projectile.Position.Z)
						--60 seconds later it clears all these bumps
						task.spawn(function()
							task.wait(60)
							if snowbump then
								snowbump:Destroy()
							end
						end)
					end
					--then we destroy the projectile
					projectile:Destroy()
				end)
				
				task.spawn(function()
					--full time for the snowball to travel from the player to the target
					local totaltime = 0.5
					--the current elapsed time
					local t = 0
					--loop runs as long as t is less than totaltime and the projectile (snowball) still exists in the workspace
					while t < totaltime and projectile.Parent do
						--we wait for the next frame, and get the time elapsed since the last frame
						local dt = RunService.Heartbeat:Wait()
						t += dt
						--we calculate the progress of the throw (0 = start, 1 = end)
						local progress = t / totaltime
						--we calculate the peak height of the arc based on the snowball size
						local peak = 2 + handle.Size.Y / 2
						--we make this insert the horizontal position from start to target overtime
						local pos = startpos:Lerp(throwtarget, progress)
						--we calculate a parabolic arc for vertical movement
						local arc = 4 * peak * progress * (1 - progress)
						--we update the projectile (snowball) position by adding the arc height to the Y axis
						projectile.Position = Vector3.new(pos.X, pos.Y + arc, pos.Z)
					end
					--destroy the projectile and trajectorypart
					if projectile then projectile:Destroy() end
					if trajpartref then trajpartref:Destroy() end
				end)
				--now we destroy the tool from the players inventory
				snowball:Destroy()
				--change the fov back to the original 70
				ChangePlayerFOV:FireClient(plr, 70)
				--make more snow collecting possible
				AllowSnowCarving:FireClient(plr, true)
				--reset the humanoid walkspeed to the normal 16
				hum.WalkSpeed = 16
				--remove the trajpart from the playerdata aswell
				if pd.trajpart then
					pd.trajpart:Destroy()
				end
				playerdata[plr] = nil
			end)
		end)
		--we use the .Unequipped event to see when the player unequips the tool
		snowball.Unequipped:Connect(function()
			local pd = playerdata[plr]
			if pd then
				--we stop the looping, make the accuracy bar invisible, make sure we allow snow carving again, reset the humanoid walkspeed, stop both the animations, reset the fov, and remove the traj part from the playerdata
				pd.loopgoing = false
				pd.frame.Parent.Visible = false
				AllowSnowCarving:FireClient(plr, true)
				hum.WalkSpeed = 16
				anim1:Stop()
				anim2:Stop()
				ChangePlayerFOV:FireClient(plr, 70)
				if pd.trajpart then
					pd.trajpart:Destroy()
					pd.trajpart = nil
				end
				playerdata[plr] = nil
			end
		end)
	end
end)