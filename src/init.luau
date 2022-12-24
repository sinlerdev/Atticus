local PlayerService = game:GetService("Players")

local raycastHitbox = require(script.RaycastHitboxV4)
local Atticus = {}
Atticus.__index = Atticus

export type AtticusData = {
	swingAnimations: { number },
	holdingAnimations: { number },
	raycastParam: RaycastParams?,
	processor: (BasePart, Humanoid, RaycastResult, string, number) -> (boolean),
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
	Hit = true,
	SwingEnded = true,
	OwnerChanged = true,
}

type events = "Hit" | "SwingEnded" | "OwnerChanged"

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
	for _, fn in connectionTable do
		SpawnWithReuse(fn, ...)
	end
end

function Atticus.new(toolInformation: AtticusToolInformation, data: AtticusData)
	local collisionPart = toolInformation.collisionPart
	local collisionPartSize = collisionPart.Size

	local self = setmetatable({
		hitbox = raycastHitbox.new(collisionPart),
		IsSwinging = false,
		tracks = { swing = {}, hold = {} },
		signals = {},
		lastSwingIndex = 0,
		allSwingCount = #data.holdingAnimations
	}, Atticus)

	for Event in Events do
		self.signals[Event] = {}
	end

	self.hitbox.Visualizer = true

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
	local lastCountHit = 0
	self.hitbox.OnHit:Connect(function(hit, humanoid: Humanoid, RaycastResults, group)
		if not data.processor(hit, humanoid, RaycastResults, group, lastCountHit) then
			return
		end

		if lastCountHit ~= data.criticalInterval then
			humanoid:TakeDamage(data.normalDamage)
			lastCountHit += 1
		else
			humanoid:TakeDamage(data.criticalDamage)
			lastCountHit = 0
		end

		fireConnections(self.signals["Hit"], hit, humanoid, RaycastResults, group, lastCountHit)
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

function Atticus:on(eventName: events, fn)
	local event = self.signals[eventName]
	table.insert(event, fn)
end

function Atticus:swing()
	self.lastSwingIndex += 1

	if self.lastSwingIndex > self.allSwingCount then
		self.lastSwingIndex = 1
	end

	self.hitbox:HitStart()

	local track = self.tracks.swing[self.lastSwingIndex]

	track:Play()
	track.Stopped:Wait()

	self.hitbox:HitStop()

	fireConnections(self.signals["SwingEnded"])
end

return Atticus
