---
sidebar_position: 1
---

# Atticus
Atticus is a general, minimal, tool-independent and fast solution for sword creation on Roblox. It makes use of TeamSwordphin's [RaycastHitbox V4](https://devforum.roblox.com/t/raycast-hitbox-401-for-all-your-melee-needs/374482) to handle all the hitbox management.

## These are the features that Atticus currently support:
* Swing animations:
    * Every time a swing happens, Atticus will switch to the next defined animation.
* Holding Animations
    * Every time a sword is equipped, all the holding animations are ran in the order they were defined in.
* RaycastParams
    * Allows you to define blacklists/whitelists, and other stuff RaycastParams are used for.
* Processors
    * Allows you to write logic that allows for filtering hits.
* Critical Attacks support
    * Atticus offers critical attacks' features *(critical attack interval/ critical damage)*, so that you wouldn't have to code it yourself.
* Detached from Roblox Tools:
    * Atticus, unlike other libraries, can work out of the box for your already-existing tooling system.
* Automatic/Manual Collision Calculation
    * Automatic: Let Atticus calculate all of your swords collisions- it will evenly spread all the points across your collisionPart's size *(which could be a tool's handle)*.
    * Manual: Atticus allows you to manually create collisions for your sword using Attachments that are called `DmgPoint`.
* Eager Animation Loading
    * Atticus eager loads all of your animations, so that your memory isn't leaked, and you won't suffer from performance loses- on top of that, Atticus also cleans up all of that animation mess when an owner is changed.
# Example
Before doing anything, grab a sword that contains a BasePart that is the Handle, and then put in in workspace.

After that, copy the following snippet and paste it in a **server-sided** script.

Aside from fixing/developing the tool model you got *(welding its parts together, etc etc)*, there isn't much you need to manage when working with Atticus.
```lua
local Atticus = require(game.ReplicatedStorage.Atticus)
local tool = workspace.Tool

local sword = Atticus.new(
	{
		ToolWrapper = tool,
		collisionPart = tool.Handle,
		automaticCollision = true,
		Equipped = tool.Equipped
	},
	{
            -- replace the 000s with actual animations.
		swingAnimations = {000, 000, 000},
		holdingAnimations = {000},
		processor = function(hit, humanoid, RaycastResults, group, lastCountHit, owner)
			local ownerHumanoid = owner.Character.Humanoid
			
			return humanoid ~= ownerHumanoid
		end,
		normalDamage = 10,
		criticalDamage = 200,
		criticalInterval = 3
	}
)

-- this makes your sword hitbox visible!
sword.hitbox.Visualizer = true

sword:on("SwingEnded", function()
	print("print swing ended")
end)

tool.Activated:Connect(function()
	if not sword.IsSwinging then
		sword:swing()
	end
end)
```