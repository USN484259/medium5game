local core = require("core")

local template = {
	health_cap = 1000,
	resistance = {

	},
}

return function()
	return core.new_entity("target", template)
end
