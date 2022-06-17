
local shian = {}
shian.template = {
	element = "earth",
	health_cap = 700,
	power = 200,
	speed = 3,
	accuracy = 3,
	sight = 2,
	energy_cap = 1000,
	generator = 100,
	immune = {
		burn = true,
	},
}

shian.template.resistance = {
	physical = 0.6,
	fire = 0.8,
	water = 0.6,
	air = 0.7,
	earth = 0.9,
	light = 0.5,
	mental = 0.6,
}

shian.quiver = {
	single = {
		cost = 60,
		range = 5,
		damage = {
			ratio = 1,
			element = "physical",
		},
	},
	area = {
		damage = {
			damage = 200,
			element = "physical",
		},
	},
}

shian.item = {}
shian.item.shield = {
	modes = { "hammer", "shield" },
	radius = 1,
	speed_ratio = 0.5,
	absorb_efficiency = 1,
	energy_efficiency = 2,
}
shian.item.apple = {
	cooldown = 5,
	initial = 0,
	duration = 4,
	boost_duration = 3,
	generator_boost = 2,
	power_boost = 5 / 4,
	speed_boost = 1,
	accuracy_boost = 1,
	damage = {
		damage = 5,
		element = "mental",
		real = true,
	},
}

shian.skill = {}
shian.skill.move = {
	shield = {
		cooldown = 2,
		cost = 50,
		step = 1,
		power_req = 1 / 4,
	},
	hammer = {
		cooldown = 1,
		cost = 30,
		step = 1,
		power_req = 1 / 4,
	},
}
shian.skill.attack = {
	shield = {
		cooldown = 2,
		cost = 200,
		power_req = 1 / 2,
		angle = 1,
		extent = 2,
		damage = {
			ratio = 0.5,
			element = "physical",
			type = "ground",
		},
		block = {
			ratio = 0.5,
			duration = 1,
		}
	},
	hammer = {
		cooldown = 2,
		cost = 200,
		power_req = 1 / 2,
		damage = {
			ratio = 2,
			element = "physical",
			accuracy = true,
			type = "ground",
			down_duration = 1,
		},
		splash = {
			radius = 1,
			ratio = 0.4,
			element = "physical",
		},
	},
}
shian.skill.transform = {
	cooldown = 0,
	cost = 0,
}
shian.skill.cannon = {
	cooldown = 5,
	cost = 500,
	power_req = 3 / 4,
	range = { 2, 5 },
	damage = {
		ratio = 2,
		element = "physical",
		accuracy = true,
		down_duration = 1,
	},
	air_extra = {
		ratio = 2,
		element = "physical",
		type = "air",
	},
	splash = {
		radius = 1,
		ratio = 0.4,
		element = "physical",
	},
}
shian.skill.apple = {
	cooldown = 0,
	cost = 0,
	power_req = nil,
	instant = {
		generate = 200,
		damage = {
			damage = 10,
			element = "mental",
			real = true,
		},
	},
}
shian.skill.final_guard = {
	cooldown = 20,
	cost = 0,
	power_req = nil,
	duration = 4,
	max_resistance = 0.2,
	energy_efficiency = 2,
	blood_efficiency = 2,
}

local chiyu = {}
chiyu.template = {
	element = "fire",
	health_cap = 800,
	power = 120,
	speed = 7,
	accuracy = 8,
	sight = 3,
	energy_cap = 1000,
	generator = 100,
	immune = {
		burn = true,
	},
}
chiyu.template.resistance = {
	physical = 0.2,
	file = 0.7,
	water = -0.2,
	air = 0.3,
	earth = 0,
	light = 0,
	mental = 0.4,
}

chiyu.quiver = {
	single = {
		cost = 30,
		damage = {
			damage = 60,
			element = "fire",
		},
		burn = {
			duration = 2,
			damage = 30,
		},
	},
	area = {
		damage = {
			damage = 100,
			element = "fire",
		},
		set_fire = {
			duration = 1,
			damage = 30,
		}
	},
}

chiyu.item = {}
chiyu.item.ember = {
	initial = 0,
	heat_gain = {
		damage = 3,
		kill = 8,
	},
	regenerate = {
		cap = 1 / 10,
		ratio = 1 / 20,
	},
	power = function(power, heat, wet)
		if wet then
			power = power * 0.8
		end

		return power * (1 + 0.1 * (heat // 10))
	end,
	dissipate = function(wind, wet, down)
		local val = 2
		if wind then
			if wind == "storm" then
				val = val + 2
			elseif wind == "wind" then
				val = val + 1
			end
		end
		if wet then
			val = val * 2
		end
		if down then
			return val // 2
		end

		return val
	end,
	damage = function(heat)
		local mental, fire

		if heat > 40 then
			mental = (heat - 40) // 4
			fire = (chiyu.template.health_cap // 100) * (heat - 40) // 4
		end

		return mental, fire
	end,
}
chiyu.item.feather = {
	cooldown = 5,
	initial = 0,
}

chiyu.skill = {}
chiyu.skill.move = {
	cooldown = 0,
	cost = 10,
	step = 2,
	power_req = 1 / 4,
}
chiyu.skill.attack = {
	cooldown = 1,
	cost = 40,
	power_req = 1 / 2,
	damage = {
		ratio = 1,
		element = "physical",
		accuracy = true,
	},
	--[[
	extra = {
		ratio = 0.5,
		element = "fire",
	},
	--]]
	burn = {
		duration = 1,
		damage = 40,
	},
}
chiyu.skill.charge = {
	cooldown = 3,
	cost = 300,
	range = { 2, 5 },
	power_req = 3 / 4,
	damage = {
		ratio = 1,
		element = "fire",
	},
	burn = {
		duration = 1,
		damage = 40,
	},
	back = {
		ratio = 2,
		element = "physical",
		accuracy = true,
		down_duration = 1,
	},
}
chiyu.skill.ignition = {
	cooldown = 1,
	cost = 200,
	range = { 1, 4 },
	power_req = nil,
	radius = 1,
	damage_ratio = 1,
	burn = {
		duration = 1,
		damage = 30,
	},
	set_fire = {
		duration = 1,
		damage = 30,
	},
}
chiyu.skill.sweep = {
	cooldown = 3,
	cost = 200,
	power_req = 3 / 4,
	damage = {
		angle = 1,
		extent = 1,
		ratio = 1,
		element = "physical",
		accuracy = true,
	},
	flame = {
		angle = 1,
		extent = 2,
		ratio = 1,
		element = "fire",
	},
	burn = {
		duration = 1,
		damage = 30,
	},
}
chiyu.skill.nirvana = {
	cooldown = 10,
	cost = 0,
	power_req = nil,
	threshold = 0.3,
	set_fire = {
		radius = 1,
		duration = 1,
		damage = 100,
	},
}
chiyu.skill.phoenix = {
	cooldown = 12,
	cost = 800,
	power_req = nil,
	main = {
		damage = {
			ratio = 2,
			element = "fire",
		},
		burn = {
			duration = 2,
			damage = 30,
		},
	},
	sides = {
		damage = {
			ratio = 1,
			element = "fire",
		},
		burn = {
			duration = 2,
			damage = 30,
		},
	},
	back = {
		damage = {
			ratio = 2,
			element = "fire",
		},
		extra = {
			ratio = 2,
			element = "physical",
		},
		down_duration = 2,
	},
	set_fire = {
		duration = 2,
		damage = 30,
	},
}

local cangqiong = {}
cangqiong.template = {
	element = "air",
	health_cap = 850,
	speed = 9,
	accuracy = 9,
	power = 100,
	sight = 4,
	energy_cap = 1000,
	generator = 100,
}
cangqiong.template.resistance = {
	physical = 0,
	fire = 0,
	water = 0,
	air = 0.2,
	earth = 0,
	light = 0,
	mental = 0,
}
cangqiong.quiver = {
	single = {
		shots = 2,
	},
	area = {
		damage = {
			damage = 150,
			element = "air",
		},
	},
}
cangqiong.item = {}
cangqiong.item.lanyu = {
	reach = 1,
}
cangqiong.item.butterfly = {
	cooldown = 6,
}

cangqiong.skill = {}
cangqiong.skill.move = {
	cooldown = 0,
	step = 3,
	cost = 10,
	power_req = 1 / 4,
}
cangqiong.skill.attack = {
	cooldown = 1,
	cost = 40,
	power_req = 1 / 2,
	damage = {
		ratio = 1,
		element = "physical",
		accuracy = true,
	},
}
cangqiong.skill.select_arrow = {
	cooldown = 0,
	cost = 0,
	power_req = nil,
}
cangqiong.skill.probe = {
	cooldown = 0,
	cost = 80,
	power_req = nil,
}
cangqiong.skill.wind_control = {
	cooldown = 0,
	cost = 80,
	range = 4,
	length = 3,
	power_req = 1 / 4,
	duration = 2,
}
cangqiong.skill.arrow_rain = {
	cooldown = 6,
	cost = 300,
	radius = 3,
	power_req = 3 / 4,
}
cangqiong.skill.storm = {
	cooldown = 12,
	cost = 800,
	radius = 4,
	duration = 3,
	power_req = nil,
	power_ratio = 1,
	speed_ratio = 0.5,
	ally = {
		speed = 2,
		accuracy = 2,
	},
	enemy = {
		speed = -1,
		accuracy = -3,
		block_ratio = 1,
	},
	damage = {
		ratio = 1 / 2,
		element = "air",
	},
	extra = {
		ratio = 1,
		element = "air",
		type = "air",
	},
}

local stardust = {}
stardust.template = {
	element = "light",
	health_cap = 800,
	speed = 6,
	accuracy = 7,
	power = 100,
	sight = 3,
	energy_cap = 65535,
	generator = 0,
}
stardust.template.resistance = {
	physical = 0.2,
	fire = 0.2,
	water = 0.2,
	air = 0.2,
	earth = 0.2,
	light = 0.9,
	mental = 0.4,
}
stardust.quiver = {
	single = {
		cost = 40,
		damage = {
			damage = 100,
			element = "light",
		},
		charge = 0,
	},
	area = {
		damage = {
			damage = 100,
			element = "light",
		},
		charge = 100,
	},
}

stardust.charge = {
	dissipate = 100,
	damage = function(contained, new)
		return contained + new / 2
	end,
}

stardust.generator = {
	range = 4,
	exp = 1.5,
}

stardust.item = {}
stardust.item.lance = {
	energy_cap = 200,
	initial = 200,
}
stardust.item.mirror = {
	energy_cap = 800,
	initial = 0,
}
stardust.item.prism = {
	energy_cap = 2000,
	initial = 0,
}

stardust.skill = {}
stardust.skill.move = {
	ground = {
		cooldown = 0,
		cost = 0,
		step = 1,
		power_req = 1 / 4,
	},
	hover = {
		cooldown = 0,
		cost = 10,
		step = 3,
		power_req = 1 / 4,
	},
}
stardust.skill.attack = {
	cooldown = 0,
	cost = 0,
	range = 5,
	power_req = 1 / 2,
	damage = {
		ratio = 1,
		element = "physical",
		accuracy = true,
	},
	charge_rate = 1,
}
stardust.skill.hover = {
	cooldown = 0,
	cost = 40,
	power_req = 1 / 4,
	speed_boost = 2,
}
stardust.skill.teleport = {
	cooldown = 1,
	cost = 0,
	power_req = 1 / 4,
	portal_duration = 1,
	energy_cost = {
		solo = 0.5,
		group = 1,
	}
}
stardust.skill.blackhole = {
	cooldown = 1,
	cost = 0,
	range = 6,
	power_req = 1 / 2,
	radius = 1,
	duration = 2,
	energy_cost = 3 / 4,
	power_ratio = 1,
	block_ratio = 1 / 4,
	crush_threshold = 2,
	damage = {
		damage = function(power, cap)
			return math.max(power / 16, cap * power / 2048)
		end,
		element = "physical",
	}
}
stardust.skill.lazer = {
	cooldown = 1,
	cost = 0,
	power_req = 3 / 4,
	threshold = 0.5,
	efficiency = 0.5,
	charge_rate = 0.5,
}
stardust.skill.starfall = {
	cooldown = 20,
	cost = 0,
	-- remain = 10,
	power_req = 1 / 2,
	power_ratio = 1,
	down_duration = 1,
	damage = {
		radius = 2,
		ratio = 4,
		element = "light",
	},
	trigger_radius = 2,
}

local haiyi = {}
haiyi.template = {
	element = "water",
	health_cap = 900,
	speed = 5,
	accuracy = 6,
	power = 80,
	sight = 3,
	energy_cap = 1000,
	generator = 100,
	immune = {
		drown = true,
	},
}
haiyi.template.resistance = {
	physical = 0.2,
	fire = 0.4,
	water = 0.7,
	air = 0.1,
	earth = 0.2,
	light = 0.3,
	mental = 0.3,
}

haiyi.quiver = {
	single = {
		cost = 30,
		damage = {
			damage = 100,
			element = "water",
		},
		bubble = {
			strength = 80,
			duration = 2,
		},
	},
	area = {
		damage = {
			damage = 100,
			element = "water",
		},
		heal = {
			dst_ratio = 0.2,
			max_cap = 100,
		},
		bubble = {
			strength = 80,
			duration = 2,
		},
	},
}

haiyi.item = {}
haiyi.item.wand = {
	cooldown = 1,
	center_weight = 3,

	threshold = 20,

	ground = {
		self = nil,
		team = {
			radius = 1,
			speed = 1,
		},
	},
	water = {
		self = {
			speed = 4,
			accuracy = 2,
			power_ratio = 2,
		},
		team = {
			radius = 1,
			speed = 2,
			power_ratio = 5 / 4,
			resistance = {
				value = 0.1,
				cap = 0.7,
			},
			wet = true,
		},
	},
	-- ultimate stat in skill.downpour
}
haiyi.item.jellyfish = {
	water_cap = 800,
	threshold = 50,
	absorb_ratio = 1 / 4,
	absorb_cap = 100,
}

haiyi.skill = {}
haiyi.skill.move = {
	ground = {
		cooldown = 0,
		cost = 20,
		step = 2,
		power_req = 1 / 4,
	},
	water = {
		cooldown = 0,
		cost = 10,
		step = 8,
		power_req = 1 / 4,
	},
}
haiyi.skill.attack = {
	ground = {
		cooldown = 1,
		shots = 1,
		cost = 40,
		water_cost = 30,
		range = 3,
		power_req = 1 / 2,
		damage = {
			ratio = 1,
			element = "water",
			accuracy = true,
			wet_duation = 2,
		},
		heal = {
			src_ratio = 1,
			limit = 1,
			wet_duration = 2,
		},
	},
	water = {
		cooldown = 1,
		shots = 4,
		cost = 40,
		water_cost = 150,
		range = 6,
		power_req = 1 / 2,
		damage = {
			ratio = 2,
			element = "water",
			accuracy = true,
			wet_duration = 2,
		},
		heal = {
			src_ratio = 2,
			limit = 1,
			wet_duration = 2,
		},
	},
}
haiyi.skill.convert = {
	cooldown = 0,
	cost = 80,
	generate = 50,
	power_req = nil,
}
haiyi.skill.bubble = {
	ground = {
		cooldown = 2,
		cost = 80,
		water_cost = 40,
		shots = 1,
		range = 2,
		power_req = 1 / 2,
		bubble = {
			ratio = 1,
			duration = 2,
		},
	},
	water = {
		cooldown = 2,
		cost = 80,
		water_cost = 100,
		shots = 2,
		range = 4,
		power_req = 1 / 2,
		bubble = {
			ratio = 1,
			duration = 2,
		}
	},
}
haiyi.skill.revive = {
	ground = {
		cooldown = 8,
		cost = 200,
		water_cost = 200,
		power_req = 1 / 2,
		heal = {
			dst_ratio = 0.6,
			min_cap = 100,
			overcap = true,
		},
		bubble = {
			ratio = 1,
			duration = 2,
		},
	},
	water = {
		cooldown = 8,
		step = 8,
		cost = 200,
		water_cost = 200,
		power_req = 1 / 2,
		heal = {
			dst_ratio = 0.6,
			min_cap = 100,
			overcap = true,
		},
		bubble = {
			ratio = 1,
			duration = 2,
		},
	},
}
haiyi.skill.downpour = {
	cooldown = 12,
	cost = 300,
	water_cost = 800,
	power_req = nil,
	duration = 4,
	bubble_duration = 2,
	rain = {
		radius = 4,
		duration = 3,
		power_ratio = 1,
		bubble_duration = 2,
		depth = 10,
		-- bubble = 100,
	},
	damage = {
		radius = 2,
		ratio = 0.5,
		element = "water",
		wet_duration = 2,
	},
	heal = {
		radius = 2,
		src_ratio = 1 / 4,
		wet_duration = 2,
	},
	self = {
		speed = 3,
		power_ratio = 2,
		wet = true,
	},
	team = {
		radius = 2,
		speed = 2,
		power_ratio = 5 / 4,
		wet = true,
	},
}

local bubble = {
	resistance = {
		water = 0.4,
		fire = -0.2,
	},
	immune = {
		drown = true,
		bubble = true,
	},
	health_ratio = 1,
	damage = {
		radius = 1,
		ratio = 1,
		element = "water",
		wet_duration = 1,
	},
}
local toolman = {}
toolman.template = {
	health_cap = 1000,
	power = 100,
	speed = 3,
	accuracy = 7,
}
toolman.template.resistance = {}


local buff = {}
buff.down = {
	threshold = 1000,
	weaken = {
		ratio = 1 / 2,
		value = 0.2,
	}
}
buff.block = {
	normal = {
		threshold = 1 / 2,
		speed = 3 / 4,
		weaken = {
			value = 0.1,
		}
	},
	strong = {
		threshold = 1,
		speed = 1 / 2,
		weaken = {
			value = 0.2
		},
	},
}
buff.drown = {
	depth = 1000,
	ratio = 1 / 4,
	speed = 1 / 2,
	power = 1 / 2,
	weaken = {
		value = 0.2,
		ratio = 0.5,
	},
}
buff.bubble = {
	absorb_efficiency = 1 / 2,
	energy_efficiency = 1,
	block_ratio = 1,
}

local layer = {}
layer.water = {
	drown_depth = 1000,
}
layer.fire = {
	burn_duration = 2,
	power_fire = 5 / 4,
	power_water = 1 / 2,
}

return {
	entity = {
		shian = shian,
		chiyu = chiyu,
		cangqiong = cangqiong,
		stardust = stardust,
		haiyi = haiyi,

		bubble = bubble,
		toolman = toolman,
	},
	buff = buff,
	layer = layer,
}
