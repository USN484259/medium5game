local cfg = require("config").entity.toolman
local core = require("core")
local hexagon = require("hexagon")
local buff = require("buff")

local template = {
	health_cap = 1000,
	energy = 0,
	resistance = {},
}

return function()
	local obj = core.new_character("entity.toolman", cfg.template, {{
		name = "skill.toolman.attack",
		type = "effect",
		cooldown = 1,
		remain = 0,
		enable = true,
		cost = 0,

		update = core.skill_update,
		use = function(self)
			local entity = self.owner
			local area = hexagon.adjacent(entity.pos)
			entity.map:damage(entity, area, {
				ratio = 1,
				element = "physical",
				accuracy = true,
			})

			return true
		end,
	}})

	obj.energy = 0
	return obj
end
