local PlayerService = game:GetService("Players")

local raycastHitbox = require(script.RaycastHitboxV4)
local Atticus = {}
Atticus.__index = Atticus

export type AtticusData = {
	swingAnimations: { number },
	holdingAnimations: { number },
	raycastParam: RaycastParams?,
	processor: (BasePart, Humanoid, RaycastResult, string) -> (boolean),
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
}

type events = "Hit" | "SwingEnded"

local function makeAnimation(id)
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. id
	return animation
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
	}, Atticus)

	for Event in Events do
		self.signals[Event] = {}
	end

	self.hitbox.Visualizer = true
	local points = {}

	if toolInformation.automaticCollision then
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
	end
	self.hitbox.RaycastParams = data.raycastParam or self.hitbox.RaycastParams

	-- setup hit detection
	local lastCountHit = 0
	self.hitbox.OnHit:Connect(function(hit, humanoid: Humanoid, RaycastResults, group)
		if not data.processor(hit, humanoid, RaycastResults, group) then
			return
		end

		if lastCountHit ~= data.criticalInterval then
			humanoid:TakeDamage(data.normalDamage)
			lastCountHit += 1
		else
			humanoid:TakeDamage(data.criticalDamage)
			lastCountHit = 0
		end

		fireConnections(self.signals["Hit"], hit, humanoid, RaycastResults, group)
	end)

	toolInformation.Equipped:Connect(function()
		local owner = PlayerService:GetPlayerFromCharacter(toolInformation.ToolWrapper.Parent)
		local animator = owner.Character.Humanoid.Animator :: Animator
		if owner ~= self.owner then
			if self.owner then
				for _, value in self.tracks do
					for _, track in value do
						track:Destroy()
					end
				end
				table.clear(self.tracks.hold)
				table.clear(self.tracks.swing)
			end

			for _, id in data.swingAnimations do
				local object = makeAnimation(id)
				table.insert(self.tracks.swing, animator:LoadAnimation(object))
			end

			for _, id in data.holdingAnimations do
				local object = makeAnimation(id)
				table.insert(self.tracks.hold, animator:LoadAnimation(object))
			end

			self.owner = owner
		end

		for _, animationTrack in self.tracks.hold do
			animationTrack:Play()
			animationTrack.Stopped:Wait()
		end
	end)
	return self
end

function Atticus:On(eventName: events, fn)
	local event = self.signal[eventName]
	table.insert(event, fn)
end

function Atticus:swing()
	self.IsSwinging = true
	self.hitbox:HitStart()
	local track = self.tracks.swing[1]
	track:Play()
	track.Stopped:Wait()
	self.IsSwinging = false
	self.hitbox:HitStop()
end

return Atticus
