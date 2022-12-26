local PlayerService = game:GetService("Players")

local raycastHitbox = require(script.Parent.RaycastHitbox)
--[=[
	@class Atticus

	The class used for creating Atticus objects.
]=]
local Atticus = {}
Atticus.__index = Atticus

--[=[
	@within Atticus
	@interface AtticusData
	.swingAnimations {number} -- Array of animationIds that will be chozen an animation from to be played each swing
	.holdingAnimations {number} -- Array of animationIds that will be played in order whenever the sword is equipped
	.raycastParam RaycastParams? -- a RaycastParams to override the default one
	.processor (BasePart, Humanoid, RaycastResult, string, { [Humanoid]: number }, Player) -> (boolean), -- a function that will be used for filtering hits
	.normalDamage number -- the number that will be taken out of the Humanoid's health
	.criticalDamage number -- the number that will be taken out of the Humanoid's health when the hit is a critical one
	.criticalInterval number -- Once the number of hits-per-humanoid reaches this number, a critical hit is landed.
]=]

--[=[
	@within Atticus
	@interface AtticusToolInformation
	.ToolWrapper Instance -- The object that houses all the tool's object
	.collisionPart BasePart -- The collision part that Atticus will create a new hitbox for
	.automaticCollision boolean? -- a bool to determine whether to let Atticus automatically calculate collisions or not.
	.Equipped any -- The event that fires whenever the tool is equipped
]=]

--[=[
	@within Atticus
	@type events "Hitting" | "Hit" | "Swinging" | "SwingEnded" | "OwnerChanged"
]=]

export type AtticusData = {
	swingAnimations: { number },
	holdingAnimations: { number },
	raycastParam: RaycastParams?,
	processor: (BasePart, Humanoid, RaycastResult, string, { [Humanoid]: number }, Player) -> (boolean),
	normalDamage: number,
	criticalDamage: number,
	criticalInterval: number,
}

export type AtticusToolInformation = {
	ToolWrapper: Instance,
	collisionPart: BasePart,
	automaticCollision: boolean,
	Equipped: any,
}

local Events = {
	Hitting = true,
	Hit = true,
	Swinging = true,
	SwingEnded = true,
	OwnerChanged = true,
}

type events = "Hitting" | "Hit" | "Swinging" | "SwingEnded" | "OwnerChanged"

local function makeAnimation(id)
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. id
	return animation
end

local function LoadAnimation(inputArray: { number }, animator: Animator): { AnimationTrack }
	local output = table.create(#inputArray)
	for _, id in inputArray do
		local object = makeAnimation(id)
		table.insert(output, animator:LoadAnimation(object))
	end

	return output
end

local freeThread -- Thread reusage

local function Passer(fn, ...)
	local acquiredThread = freeThread
	freeThread = nil
	fn(...)
	freeThread = acquiredThread
end

local function yielder()
	while true do
		Passer(coroutine.yield())
	end
end

local function SpawnWithReuse(fn, ...)
	if not freeThread then
		freeThread = coroutine.create(yielder)
		coroutine.resume(freeThread)
	end
	task.spawn(freeThread, fn, ...)
end

local function fireConnections(connectionTable, ...)
	for fn in connectionTable do
		SpawnWithReuse(fn, ...)
	end
end

--[=[
	@within Atticus
	Constructs a new Atticus Instance *(not to be confused with Roblox Instances)*.

	This follows a specific set of instructions, which are *(order matters)*:
	1. Initializes all events
	2. Automatically calculates all the collision info for `collisionPart`- if `automaticCollision` was passed as true
	3. Overrides the default raycastParams if there is a provided one
	4. Initalizes the hitbox detection system, which follows another set of instruction, which are:
		1. Calls the provided processor, and will stop execution if a falsy value was returned
		2. Fires the `Hitting` event
		3. Increases the lastHitCount for the humanoid that was hitten
		4. if the lastHitCount is equal to criticalInterval, Humanoid will take damage equal to `criticalDamage` and the lastHitCount for that Humanoid is reset to 0
		5. otherwise, the humanoid will take damage equal to `normalDamage`.
		6. Fires the `Hit` event.
	5. Initializes a connection for Equipped, which follows yet another instruction set:
		1. If the current owner is different than the old one:
			1. If there was an older owner:
				1. Destroys all the animation tracks
				2. cleanup all the tables that holded those said tracks
				3. fire "OwnerChanged" event
			2. Load all the animation IDs into the current owner's Animator
			2. change Atticus.owner to the new owner
		2. Play all the loaded holding animation tracks in order.
	
	@param toolInformation AtticusToolInformation
	@param data AtticusData
	@return AtticusObj
]=]
function Atticus.new(toolInformation: AtticusToolInformation, data: AtticusData)
	local collisionPart = toolInformation.collisionPart
	local collisionPartSize = collisionPart.Size

	local self = setmetatable({
		hitbox = raycastHitbox.new(collisionPart),
		IsSwinging = false,
		tracks = { swing = {}, hold = {} },
		signals = {} :: { [events]: {} },
		lastSwingIndex = 0,
		allSwingCount = #data.swingAnimations,
	}, Atticus)

	for Event in Events do
		self.signals[Event] = {}
	end

	if toolInformation.automaticCollision then
		local points = {}
		-- Automatically create set of points that emulate the shape of the given collisionPart
		local halfX = (collisionPartSize.X / 2)
		local halfZ = (collisionPartSize.Z / 2)
		local halfY = (collisionPartSize.Y / 2)
		for y = -halfY, halfY, 1 do
			for x = -halfX, halfX, 1 do
				for z = -halfZ, halfZ, 1 do
					table.insert(points, Vector3.new(x, y, z))
				end
			end
		end

		self.hitbox:SetPoints(collisionPart, points, "AutoCollision")
		table.clear(points)
	end
	self.hitbox.RaycastParams = data.raycastParam or self.hitbox.RaycastParams

	-- setup hit detection
	local lastCountRecord = {}
	self.hitbox.OnHit:Connect(function(hit, humanoid: Humanoid, RaycastResults, group)
		if not data.processor(hit, humanoid, RaycastResults, group, lastCountRecord, self.owner) then
			return
		end
		fireConnections(self.signals["Hitting"], hit, humanoid, RaycastResults, group)
		if not lastCountRecord[humanoid] then
			lastCountRecord[humanoid] = 0
		end

		humanoid.Destroying:Connect(function()
			lastCountRecord[humanoid] = nil
		end)

		lastCountRecord[humanoid] += 1

		if lastCountRecord[humanoid] ~= data.criticalInterval then
			humanoid:TakeDamage(data.normalDamage)
		else
			humanoid:TakeDamage(data.criticalDamage)
			lastCountRecord[humanoid] = 0
		end

		fireConnections(self.signals["Hit"], hit, humanoid, RaycastResults, group, lastCountRecord)
	end)

	-- setup eager animation loading + cleanup when changed to a new owner
	self.equippedConnection = toolInformation.Equipped:Connect(function()
		local owner = PlayerService:GetPlayerFromCharacter(toolInformation.ToolWrapper.Parent)
		local animator = owner.Character.Humanoid.Animator :: Animator
		local tracks = self.tracks
		if owner ~= self.owner then
			if self.owner then
				for _, value in tracks do
					for _, track in value do
						track:Destroy()
					end
				end
				table.clear(tracks.hold)
				table.clear(tracks.swing)

				fireConnections(self.signals["OwnerChanged"], owner, self.owner)
			end

			tracks.swing = LoadAnimation(data.swingAnimations, animator)
			tracks.hold = LoadAnimation(data.holdingAnimations, animator)

			self.owner = owner
		end

		for _, animationTrack in tracks.hold do
			animationTrack:Play()
			animationTrack.Stopped:Wait()
		end
	end)
	return self
end


--[=[
	@within Atticus
	Connects a function to a specific signal. Returns a function that will disconnect that connection.
	
	@param eventName events
	@param fn (...any) -> ()
	@return () -> () 
]=]
function Atticus:on(eventName: events, fn)
	local event = self.signals[eventName]
	event[fn] = true
	return function()
		event[fn] = nil
	end
end

--[=[
	@within Atticus
	Performs a swing, that will do the following in this exact order:
	1. fire the `Swinging` event
	2. Sets AtticusObj.IsSwinging to true
	3. Chooses the next swinging animation- if there is no next, will start from the first one
	4. Starts the hitbox detection
	5. Plays the chosen animation- and if there are no defined animation, will instead wait for 0.5 seconds
	6. Stops the hitbox detection 
	7. Sets AtticusObj.IsSwinging to false
	8. fire the `SwingEnded` event
]=]
function Atticus:swing()
	fireConnections(self.signals["Swinging"])
	self.IsSwinging = true
	self.lastSwingIndex += 1

	if self.lastSwingIndex > self.allSwingCount then
		self.lastSwingIndex = 1
	end

	self.hitbox:HitStart()

	local track = self.tracks.swing[self.lastSwingIndex]
	local waitForTime
	if track then
		track:Play()
		track.Stopped:Wait()
	else
		waitForTime = 0.5
	end

	if waitForTime then
		task.wait(waitForTime)
	end

	self.hitbox:HitStop()
	self.IsSwinging = false

	fireConnections(self.signals["SwingEnded"])
end

return Atticus
