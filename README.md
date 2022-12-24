# Atticus
Atticus is a general, minimal, tool-independent and fast solution for sword creation on Roblox. It makes use of TeamSwordphin's [RaycastHitbox V4](https://devforum.roblox.com/t/raycast-hitbox-401-for-all-your-melee-needs/374482) to handle all the hitbox management.

These are the features that Atticus currently support:
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
    