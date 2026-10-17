Connected Discord-GitHub

local ReplicatedStorage = game:GetService("ReplicatedStorage") -- stores replicatedStorage
local RunService = game:GetService("RunService") -- stores RunService
local Players = game:GetService("Players") -- Stores Players service

local player = Players.LocalPlayer -- stores the local player
local playerGui = player:WaitForChild("PlayerGui") -- stores the player gui
local RadarGui = playerGui:WaitForChild("RadarGui") -- stores the radar gui

local radarHolderGui = RadarGui:WaitForChild("Holder") -- stores the rader holder frame

local targetPositionPart = ReplicatedStorage:WaitForChild("TargetPosition"):Clone() -- clones the targetPositionPart to be used
targetPositionPart.Parent = workspace -- moves it to the workspace so it renders for the player and he can see it

local radar = workspace:WaitForChild("Radar") -- stores the radar model
local radarSpinnerBase = radar:WaitForChild("SpinnerBase") -- stores the non-rotating base of the model
local radarDish = radar:WaitForChild("RadarDish") -- stores the dish model
local radarSpinner = radarDish:WaitForChild("RadarDish") -- stores the position reference part of the dish model
local antenna = radarDish:WaitForChild("Antenna") -- stores the antenna of the dish model

local gun = workspace:WaitForChild("Gun") -- stores the gun model
local gunSpinnerBase = gun:WaitForChild("Base") -- stores the non-rotating base of the model
local rotatingGun = gun:WaitForChild("RotatingGun") -- stores the rotating model
local gunSpinner = rotatingGun:WaitForChild("Spinner") -- stores the position reference part of the rotating model
local gunTip = rotatingGun:WaitForChild("GunTip") -- stores the guntip of the rotating model

local gravity = workspace.Gravity -- stores the gravity

local TRAJECTORY_CALCULATION_ITERATION = 200 -- how many times to repeat the trajectory calculation (slightly heavy, but worth it)

local RADAR_SPEED = 100 -- radar rotate speed in degrees per second
local RADAR_OFFSET = Vector3.new(0, 4, 0) -- offset between the radar spinner base and the radar dish spinner
local MAX_DETECT_ANGLE = 70 -- maximum angle from the direction the antenna is facing to the direction where the target is
local MAX_DETECT_DISTANCE = 1000 -- maximum distance the radar can detect

local GUN_ROTATION_SPEED = 20 -- storing how fast the guns can rotate
local GUN_OFFSET = Vector3.new(0, 2.5, 0) -- offset between the gun spinner base and the rotating gun spinner
local MAX_ANGLE_DIFFERENCE = 1 -- maximum angle of how far the gun can him away from the target for it to shoot

local BULLET_SPEED = 700 -- bullet speed in studs per second
local LIFE_TIME = 10
local FIRE_RATE = 0.3 -- gun firerate in bullets per second

local gunAngle = 0 -- storing the X axis angle of the gun rotation from the base front towards the spinner front 
local gunElevationAngle = 0 -- storing the Y axis angle of the gun rotation from the base front towards the spinner front
local gunTargetAngle = 0 -- storing the target X axis angle for gunAngle variable
local radarAngle = 0 -- storing the X axis angle of the radar rotation from the base front towards the dish spinner front
local bulletCooldown = 0 -- storing how much time is remaining / had passed since last shot
local targets = {} -- stores all the targets
local previousLockedTarget = nil
local lockedTarget = nil -- stores the locked Target
local previousTargetPosition = nil -- stores the previous target position
local smoothVelocity = Vector3.zero -- stores the smooth velocity (this value changes to smoothly change velocity without instantly snapping)
local bullets = {} -- stores all the bullets to be easily accessible in the loop

local function isCharacter(model: Model) -- creates a local function
	if not model or not model:IsA("Model") then -- checks if the model exists (to prevent errors), and checks that its actually a model
		return false -- returns false indicating there is no character
	end
	return model:FindFirstChildOfClass("Humanoid") ~= nil -- returns true if the model has a humanoid
end

local function updateRadarTargets() -- creates a local function
	local newTargets = {} -- create a table for storing all targets that the radar is going to detect when the function calls
	
	for _, model: Model in pairs(workspace:GetChildren()) do -- loops through all workspace children
		if isCharacter(model) then -- checks if its a character
			local antennaDirection = antenna.CFrame.LookVector -- gets the direction that the antenna is facing
			local radarToCharacter = (model:GetPivot().Position - radarSpinnerBase.Position) -- gets the offset between the radar and the character
			
			local angle = math.deg(math.acos(antennaDirection:Dot(radarToCharacter.Unit))) -- gets the dot product between the antenna and radarToCharacter directions, converts it from cosine to radians angle, and from radians to degrees angle

			if angle > MAX_DETECT_ANGLE then -- checks if the angle is above the maximum detect angle
				continue -- skips this model and continues with the next one
			end
			
			if radarToCharacter.Magnitude > MAX_DETECT_DISTANCE then -- converts offset to distance and checks if this model is away from the max detect distance
				continue -- skips this model and continues with the next one
			end
			
			table.insert(newTargets, model) -- add the model of the target to newTargets list
		end
	end

	for index = #targets, 1, -1 do -- reversely loop through the number of targets (i didint use for in because calling table.remove will change the index of some targets)
		local targetTable = targets[index] -- create a refrence to the targetTable in main targets table
		local modelFound = false -- create a variable to detect if the same model in newTargets is found
		
		for _, model in pairs(newTargets) do -- loop through newTargets
			if targetTable.model == model then -- check if targetsTable in main targts table is detected again (in newTargets table)
				modelFound = true -- set modelFound to true
			end
		end
		
		if not modelFound then -- if the model was not found (no longer detected)
			targetTable.connection:Disconnect() -- disconnect the click connection
			if lockedTarget == targetTable.model then -- check if it was locked on
				lockedTarget = nil -- set the locked to nothing (nil)
			end
			targetTable.ui:Destroy() -- destroy its ui
			table.remove(targets, index) -- remove it from the main targets table
		end
	end
	
	for index, model in ipairs(newTargets) do -- loop through the new targets
		local tableCreated = false -- create a variable to detect if they have a table in main targets table
		
		for _, targetTable in pairs(targets) do -- loop through the main targets table
			if model == targetTable.model then -- check if it already has a table (check if there is a model that matches)
				tableCreated = true -- set tableCreated to true if a table was found
			end
		end
		
		if not tableCreated then -- check if a table was not created for that new target
			local targetUI = radarHolderGui.Template:Clone() -- clone the template ui
			targetUI.Name = model.Name -- set its name to the model name
			targetUI.BackgroundColor3 = Color3.new(0.1, 0.6, 1) -- set its color to blue
			targetUI.Parent = radarHolderGui -- set its parent to the holder
			targetUI.Visible = true -- set it to visible
			
			local clickConnection = targetUI.MouseButton1Click:Connect(function() -- create a new click connection and create a variable for it
				if lockedTarget == model then --  check if the locked target was the model
					lockedTarget = nil -- unlock on the model
				else -- check if the target was not the model
					lockedTarget = model -- set the model to the locked target
				end
			end)

			table.insert(targets, { -- create a new table inside targets table
				model = model, -- create a refrence to the model
				ui = targetUI, -- refrence to the ui
				connection = clickConnection -- refrence to the click connection
			})
		end
	end
	
	if lockedTarget ~= previousLockedTarget or lockedTarget == nil then -- check if lockedtarget changed or if there isnt a locked target
		smoothVelocity = Vector3.zero -- set smoothVelocity to 0
	end
	
	previousLockedTarget = lockedTarget -- set the previous locked target to the target (and when locked target doesint exist, the previous locked target will be set to nil intentionally)
end

local function updateRadarGui() -- create a function to update the radar gui
	for index, targetTable in ipairs(targets) do -- loop through all targets (detected objects, not including bullets etc.)
		local x = (targetTable.model:GetPivot().Position.X - radarSpinnerBase.Position.X) / (MAX_DETECT_DISTANCE * 2) -- get the x position of the ui by getting the offset between the radar and the target position, then dividing it by the max distance times by two(same as dividing it by two then diving it by max distance)
		local y = (targetTable.model:GetPivot().Position.Z - radarSpinnerBase.Position.Z) / (MAX_DETECT_DISTANCE * 2) -- get the y position of the ui by getting the offset between the radar and the target position, then dividing it by the max distance times by two(same as dividing it by two then diving it by max distance)
		
		targetTable.ui.Position = UDim2.new(x + 0.5, 0, y + 0.5, 0) -- set the target ui position indicator
		
		if lockedTarget == targetTable.model then -- check if the locked target was this target in the loop
			targetTable.ui.BackgroundColor3 = Color3.new(1, 0, 0) -- set its color to red
		else -- if its not locked on
			targetTable.ui.BackgroundColor3 = Color3.new(0.1, 0.6, 1) -- set it to blue
		end
	end
	
	radarHolderGui.RightAngle.Rotation = -radarAngle + MAX_DETECT_ANGLE -- show the maximum angle on the right (basicly the frame rotates, and its in the center and there is another frame, so that one rotates along an axis that is in the center)
	radarHolderGui.LeftAngle.Rotation = -radarAngle - MAX_DETECT_ANGLE -- show the maximum angle on the left (basicly the frame rotates, and its in the center and there is another frame, so that one rotates along an axis that is in the center)
end

local function calculateTrajectory(targetPosition, dt)
	local gunDirection = gunSpinnerBase.CFrame.LookVector -- gets the direction that the gun is facing
	local gunToTarget = (targetPosition - gunTip.Position) -- gets the position offset from the gunSpinner to the target

	local cross = gunDirection:Cross(gunToTarget.Unit).Y -- gets the Y component of the cross product between the gun direction and the direction to the target
	local dot = gunDirection:Dot(gunToTarget.Unit) -- gets the dot product between the gun direction and the direction to the target. this only gives a range (how much the angle is)

	local gunTargetAngle = math.deg(math.atan2(cross, dot)) -- gets the angle from gun base to direction to target using the cross and dot. (cross tells it if it should be + or -. dot tells it how much angle is) and then it gets converted into degrees

	local horizontalDistance = Vector3.new(gunToTarget.X, 0, gunToTarget.Z).Magnitude -- gets the horizontal distance only
	local verticalDistance = gunToTarget.Y -- gets the vertical distance only

	local squareRootValue = (BULLET_SPEED^4 - gravity * (gravity * horizontalDistance^2 + 2 * verticalDistance * BULLET_SPEED^2)) -- does the first part of the calculation required trajectory elevation
	local targetElevationAngle = squareRootValue >= 0 and math.deg(math.atan((BULLET_SPEED^2 - math.sqrt(squareRootValue)) / (gravity * horizontalDistance))) or 0 -- checks if the value was more or equals to 0. if it is, then sets targetElevationAngle to the complete calculation. if not, sets targetElevationAngle to 0

	local horizontalVelocity = math.cos(math.rad(targetElevationAngle)) * BULLET_SPEED -- obtaining the horizontal velocity the bullet travels in using trigonometry. Cos(angle) = adjacent / hypotnuse, which is then changed to Cos(angle) * hypotnuse = adjacent. in this case hypotnuse is the bullet velocity and adjacent is horizontal velocity

	local predictedTime = horizontalDistance / horizontalVelocity -- gets the estimated predicted time it would take for the bullet to hit the target
	
	return squareRootValue >= 0, targetElevationAngle * 1.0085, predictedTime, gunTargetAngle -- return if it can hit, gun elevation angle, predicted time from fire to hit, and the target gun angle(left/right)
end

RunService.Heartbeat:Connect(function(dt) -- loops every physics step
	if not lockedTarget then -- checks if there isnt a locked target
		radarAngle += RADAR_SPEED * dt -- increases the rotation based on the time passed since the last step
		if radarAngle > 360 then -- checks if the rotation is over 360 degrees (full circle is 360 degrees)
			radarAngle -= 360  -- removes 360 degrees to make sure it doesint go over 360 degrees (didint reset it to 0 because that would affect the rotation)
		end
	else -- if there is a locked target
		local antennaDirection = antenna.CFrame.LookVector -- gets the direction that the antenna is facing
		local radarToCharacter = (lockedTarget:GetPivot().Position - radarSpinnerBase.Position) -- gets the offset between the radar and the character

		local angle = math.deg(math.acos(math.clamp(antennaDirection:Dot(radarToCharacter.Unit), -1, 1))) -- gets the angle between the antenna direction and the radat to character direction (angle between current and target)
		
		local cross = antennaDirection:Cross(radarToCharacter.Unit) -- get the cross product between the antenna direction and the radar to character direction (current to target)

		if cross.Y < 0 then angle = -angle end -- if the cross product is less than 0, make the angle negative
		
		radarAngle += math.clamp(angle, -RADAR_SPEED, RADAR_SPEED) * dt -- move the radar angle depending on angle offset between current and target angle
	end
	
	radarDish:PivotTo(radarSpinnerBase.CFrame * CFrame.Angles(0, math.rad(radarAngle), 0) + RADAR_OFFSET) -- sets the cframe of the dish to the cframe of the base + offset, and rotates it by the radarAngle
	
	updateRadarTargets() -- updates the radar target
	
	if lockedTarget and previousTargetPosition then -- checks if the radar has a locked target and last position was recorded
		local targetPosition = lockedTarget:GetPivot().Position -- stores the locked target position to avoid repeatedly calculating it
		local canHit, targetElevationAngle, predictedTime, gunTargetAngle = calculateTrajectory(targetPosition, dt) -- calculate trajectory
		
		local targetVelocity = ((targetPosition - previousTargetPosition) * 1.01 ) / dt -- gets the target velocity by using the previous and current position
		smoothVelocity = smoothVelocity + (targetVelocity - smoothVelocity) * 6 * dt -- smoothly change the variable smoothVelocity to the target Velocity

		local predictedTargetPosition = targetPosition + smoothVelocity * predictedTime -- gets the predicted position the target will be using position plus velocity times by estimated time it takes for bullet to hit
		
		for i=1, TRAJECTORY_CALCULATION_ITERATION do -- loop
			if not canHit then -- checks if the bullet trajectory cannot hit the target
				break -- breaks the loop
			end
			canHit, targetElevationAngle, predictedTime, gunTargetAngle = calculateTrajectory(predictedTargetPosition, dt) -- calculate trajectory
			predictedTargetPosition = targetPosition + smoothVelocity * predictedTime -- calculate predictedTarget position
		end
		targetPosition = predictedTargetPosition -- set the target position to the predicted position
		targetPositionPart.Position = targetPosition -- moves the visual part towards the predicted target position
		
		local angleOffset = (gunTargetAngle - gunAngle + 180) % 360 - 180 -- gets the angle difference between the gunAngle and gunTargetAngle, and this was used instead of math.lerp to prevent gun from rotating from 350 -> 200 -> 10 instead of 350 -> 10

		gunAngle += angleOffset * GUN_ROTATION_SPEED * dt -- smoothly rotate the gunAngle towards the desired targetAngle
		
		gunElevationAngle += (targetElevationAngle - gunElevationAngle) * GUN_ROTATION_SPEED * dt -- finds the angle difference, and times it by the gun speed and delaytime and adds that to the gunElevationAngle to smoothly move it

		rotatingGun:PivotTo(gunSpinnerBase.CFrame * CFrame.Angles(0,math.rad(gunAngle),0) * CFrame.Angles(math.rad(gunElevationAngle),0,0) + GUN_OFFSET) -- sets the cframe of the rotatingGun model to the cframe of the base + offset, then it rotates it by the gunAngle
		
		local updatedGunDirection = gunSpinnerBase.CFrame.LookVector -- gets the updated direction that the gun is facing
		local updatedGunToTarget = (targetPosition - gunTip.Position) --gets the updated position offset from the gunTip to the target position
		
		local angleDifference = updatedGunDirection:Dot(updatedGunToTarget.Unit) -- gets the angle between the gun direction and gun to target direction
		
		bulletCooldown -= dt -- subtracts time passed since last step to the bulletCooldown
		if canHit and bulletCooldown <= 0 and math.abs(angleDifference) <= MAX_ANGLE_DIFFERENCE then -- checks if the bullet can hit or not, and checks to make sure that bulletCooldown isnt more than 0(cooldown active), and checks to make sure that the angle difference isnt too high(gun not pointing at target, since gun rotates smoothly and not instantly)
			bulletCooldown = FIRE_RATE -- sets bulletCooldown to the firerate
			
			local bullet = ReplicatedStorage.Bullet:Clone() -- clones the bullet in replicatedStorage to be used
			bullet.Parent = workspace -- parents it to workspace so the player can render it and see it
			
			local x = (predictedTargetPosition.X - radarSpinnerBase.Position.X) / (MAX_DETECT_DISTANCE * 2) -- get the x position of the ui by getting the offset between the radar and the predicted position, then dividing it by the max distance times by two(same as dividing it by two then diving it by max distance)
			local y = (predictedTargetPosition.Z - radarSpinnerBase.Position.Z) / (MAX_DETECT_DISTANCE * 2) -- get the y position of the ui by getting the offset between the radar and the predicted position, then dividing it by the max distance times by two(same as dividing it by two then diving it by max distance)
			
			local predictionUI -- create a new variable called predictionUI
			if Vector2.new(x, y).Magnitude <= 0.5 then -- check if the position from center is lower than the radius (inside the circle)
				predictionUI = radarHolderGui.BulletTemplate:Clone() -- clone the bullet ui template to be used for the predicted position ui
				predictionUI.Name = "BulletPrediction" -- change the name to BulletPrediction
				predictionUI.Parent = radarHolderGui -- set its parent to the holder
				predictionUI.BackgroundColor3 = Color3.new(1, 1, 0) -- change its color to yellow
				predictionUI.Size = UDim2.new(0.01, 0, 0.01, 0) -- change its size to 0.01x0.01 (scale)
				predictionUI.Position = UDim2.new(x + 0.5, 0, y + 0.5, 0) -- change its position
				predictionUI.Visible = true -- make it visible
			end
			
			local bulletUI = radarHolderGui.BulletTemplate:Clone() -- clone the bullet ui template to be used for indicating where the bullet is
			bulletUI.Name = "Bullet" -- change the UI name so it doesint get mistaken for being a template
			bulletUI.Parent = radarHolderGui -- set its parent to the holder
			bulletUI.Visible = true -- make it visible
			
			table.insert(bullets, { -- creates a table to add the bullet and store its values
				part = bullet, -- stores the bullet part
				position = gunTip.Position, -- stores the bullet position (used gunTip.Position cuz thats where i want the bullet to spawn)
				previousPosition = gunTip.Position,
				velocity = gunTip.CFrame.LookVector * BULLET_SPEED, -- stores the velocity (direction * speed gives a velocity)
				lifetime = 0, -- stores the lifetime of the bullet
				ui = bulletUI, -- store the bullet indicator ui
				predictionUI = predictionUI, -- store the predicted position ui
			})
		end
	end
	
	if lockedTarget then -- if there was a locked target
		previousTargetPosition = lockedTarget:GetPivot().Position -- set previous position to the locked target position
	end
	
	for bulletIndex, bulletTable in ipairs(bullets) do -- loops through all bullets
		local bullet = bulletTable.part -- create a refrence to the bullet part to be reused without calling bulletTable.part many times
		if bulletTable.lifetime > LIFE_TIME then -- if bullets been here for long
			bullet:Destroy() -- destroy the bullet
			table.remove(bullets, bulletIndex) -- and remove it from the table
			continue -- continue with other bullets without running the code below
		end
		
		bulletTable.velocity += Vector3.new(0, -gravity, 0) * dt -- adds gravity force
		bulletTable.position += bulletTable.velocity * dt -- moves the bullet according to its velocity
		
		local raycastParams = RaycastParams.new() -- create a new raycast params
		raycastParams.FilterType = Enum.RaycastFilterType.Exclude -- set its filter type to exclude
		raycastParams.FilterDescendantsInstances = {gun} -- filter out the gun and its descendants

		local raycast = workspace:Raycast(bulletTable.previousPosition, bulletTable.position - bulletTable.previousPosition, raycastParams) -- shoot a raycast from previous position towards the new position

		if raycast and raycast.Instance then -- check if it hit a instance
			bullet:Destroy() -- destroy the bullet
			bulletTable.ui:Destroy() -- destroy the bullet position indicator ui
			if bulletTable.predictionUI then -- check if predictionUI exists (because i dont always create it, only create it if its inside the circle)
				bulletTable.predictionUI:Destroy() -- delete it
			end
			table.remove(bullets, bulletIndex) -- and remove it from the table
			continue -- continue with other bullets without running the code below
		end
		
		local x = (bulletTable.position.X - radarSpinnerBase.Position.X) / (MAX_DETECT_DISTANCE * 2) -- get the x position of the ui by getting the offset between the radar and the bullet, then dividing it by the max distance times by two(same as dividing it by two then diving it by max distance)
		local y = (bulletTable.position.Z - radarSpinnerBase.Position.Z) / (MAX_DETECT_DISTANCE * 2) -- get the y position of the ui by getting the offset between the radar and the bullet, then dividing it by the max distance times by two(same as dividing it by two then diving it by max distance)
		
		if Vector2.new(x, y).Magnitude <= 0.5 then -- check if the position from center is lower than the radius (inside the circle)
			bulletTable.ui.Visible = true -- make the ui visible
			bulletTable.ui.Position = UDim2.new(x + 0.5, 0, y + 0.5, 0) -- set the position of the ui to the target position
		else -- if its outside circle
			bulletTable.ui.Visible = false -- make the ui hidden
		end
		
		bullet:PivotTo(CFrame.new(bulletTable.position, bulletTable.position + bulletTable.velocity)) -- sets the cframe of the actual bullet to where its supposed to be, and makes it face the direction that its going
		bulletTable.lifetime += dt -- add delta time to the bullet life time
		bulletTable.previousPosition = bulletTable.position -- store the previous position to the current position
	end
	
	updateRadarGui() -- call the update the radar gui function
end)
