local cfg = require("base/config").entity.toolman
local util = require("core/util")
local core = require("core/core")
local hexagon = require("core/hexagon")
local buff = require("core/buff")

return function(health_cap)
	local template = util.copy_table(cfg.template)
	if health_cap then
		template.health_cap = health_cap
	end

	local obj = core.new_character("entity.toolman", template, {{
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
