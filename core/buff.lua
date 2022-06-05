local config = require("config")
local cfg = config.buff
local util = require("util")
local core = require("core")

local list

local function buff_get(entity, name)
	if string.sub(name, 1, 5) ~= "buff." then
		name = "buff." .. name
	end
	for k, b in pairs(entity.buff) do
		if b.name == name then
			return b
		end
	end
end

local function buff_remove(entity, tar)
	if type(tar) == "string" and string.sub(tar, 1, 5) ~= "buff." then
		tar = "buff." .. tar
	end
	for i = 1, #entity.buff, 1 do
		local b = entity.buff[i]
		if (type(tar) == "string" and b.name == tar) or (tar == b) then
			if b.remove then
				b:remove()
			end
			b.removed = true
			table.remove(entity.buff, k)
			return b
		end
	end
end

local function buff_insert(initial_tick, entity, name, ...)
	local b
	if type(name) == "string" then
		b = list[name](...)
	elseif type(name) == "table" then
		b = util.copy_table(name)
	elseif type(name) == "function" then
		b = name(...)
	else
		error(name)
	end

	b.owner = entity

	if b.initial and not b:initial() then
		return
	end

	if initial_tick and b.tick then
		for i = 1, #b.tick, 1 do
			local f = b.tick[i]
			if f[1] < core.priority.damage and not f[2](b) then
				return
			end
		end
	end

	table.insert(entity.buff, b)
	return b
end

local function buff_tick(team)
	local queue = {}
	for k, e in pairs(team) do
		local new_buff = {}
		for i = 1, #e.buff, 1 do
			local b = e.buff[i]
			if core.common_tick(b) then
				table.insert(new_buff, b)
				if b.tick then
					for k, v in pairs(b.tick) do
						table.insert(queue, {
							buff = b,
							priority = v[1],
							func = v[2],
						})
					end
				end
			elseif b.remove then
				b:remove()
			end
		end
		e.buff = new_buff
	end

	util.stable_sort(queue, function(a, b)
		return a.priority < b.priority
	end)

	for i = 1, #queue, 1 do
		local f = queue[i]
		local b = f.buff

		if not b.removed and not f.func(b) then
			buff_remove(b.owner, b)
		end
	end
end

local function buff_defer(team)
	local queue = {}
	for k, e in pairs(team) do
		for k, b in pairs(e.buff) do
			if b.defer then
				table.insert(queue, b)
			end
		end
	end
	table.sort(queue, function(a, b)
		return a.defer[1] < b.defer[1]
	end)
	for i = 1, #queue, 1 do
		local b = queue[i]
		b.defer[2](b)
	end
end
local function fly(power)
	return {
		name = "buff.fly",
		power = power or 0,

		tick = {{
			core.priority.fly, function(self)
				local entity = self.owner
				if not entity.status.down and entity.power >= self.power then
					entity.status.fly = true
				end
				return true
			end,
		}}
	}
end

local function down(duration)
	return {
		name = "buff.down",
		duration = duration,

		tick = {{
			core.priority.down, function(self)
				local entity = self.owner
				if not entity.status.ultimate then
					entity.status.down = true
					entity.power = 0
					entity.speed = 0
					core.weaken(entity, cfg.down.weaken.value, cfg.down.weaken.ratio)
				end
				return true
			end
		}}
	}
end

local function block_tick(entity, strength)
	if entity.power and entity.speed and not entity.status.down then
		local v = strength / entity.power
		local t
		if v > cfg.block.strong.threshold then
			t = cfg.block.strong
		elseif v > cfg.block.normal.threshold then
			t = cfg.block.normal
		end

		if t then
			if t.speed then
				entity.speed = math.floor(entity.speed * t.speed)
			end
			if t.weaken then
				core.weaken(entity, t.weaken.value, t.weaken.ratio)
			end
		end

		entity.power = math.max(0, entity.power - strength)
	end
	entity.status.block = strength
end

local function block(strength, duration)
	return {
		name = "buff.block",
		duration = duration,
		strength = strength,

		tick = {{
			core.priority.block, function(self)
				local entity = self.owner
				block_tick(entity, self.strength)
				return true
			end
		}}
	}
end

local function drown()
	return {
		name = "buff.drown",

		tick = {{
			core.priority.drown, function(self)
				local entity = self.owner

				if entity.status.fly or entity.immune.drown then
					return false
				end

				entity.status.drown = true
				entity.status.wet = true
				if entity.speed and entity.power then
					entity.speed = math.floor(entity.speed * cfg.drown.speed)
					entity.power = math.floor(entity.power * cfg.drown.power)
					core.weaken(entity, cfg.drown.weaken.value, cfg.drown.weaken.ratio)
				end

				return true
			end
		}, {
			core.priority.damage, function(self)
				local entity = self.owner
				core.damage(entity, {
					damage = entity.health_cap * cfg.drown.ratio,
					element = "water",
					real = true,
				})

				return false
			end,
		}}
	}
end

local function burn(damage, duration)
	return {
		name = "buff.burn",
		duration = duration,
		damage = damage,

		tick = {{
			core.priority.post_stat, function(self)
				local entity = self.owner
				if entity.immune.burn then
					return false
				end

				if buff_remove(entity, "wet") or buff_get(entity, "bubble") then
					return false
				end

				entity.status.burn = true
				return true
			end,
		}, {
			core.priority.damage, function(self)
				local entity = self.owner
				core.damage(entity, {
					damage = self.damage,
					element = "fire",
				})
				return true
			end,
		}}
	}
end

local function wet(duration)
	return {
		name = "buff.wet",
		duration = duration,

		tick = {{
			core.priority.pre_stat, function(self)
				local entity = self.owner
				entity.status.wet = true
				return true
			end,
		}}
	}
end

local function bubble(team, strength, duration)
	local tick_table = {
		[true] = {{
			core.priority.pre_stat, function(self)
				local entity = self.owner
				entity.status.wet = true

				if self.strength == 0 then
					return false
				end

				entity.immune.drown = true
				entity.status.bubble = self.strength
				core.hook(entity, {
					name = "bubble",
					src = self,
					priority = core.priority.bubble,
					func = function(self, entity, damage)
						local b = self.src
						local t = cfg.bubble
						local blk
						blk, damage = core.shield(damage, b.strength * t.energy_efficiency, t.absorb_efficiency)
						entity.map:event(b, "shield", blk)
						b.strength = math.floor(b.strength - blk / t.energy_efficiency)
						return damage
					end
				})
				return true
			end,
		}},

		[false] = {{
			core.priority.pre_stat, function(self)
				local entity = self.owner
				entity.status.wet = true
				entity.status.bubble = self.strength
				return true
			end,
		}, {
			core.priority.block, function(self)
				local entity = self.owner
				block_tick(entity, self.strength * cfg.bubble.block_ratio)
				return true
			end,
		}},
	}

	return {
		name = "buff.bubble",
		strength = strength,
		duration = duration,
		team = team,

		initial = function(self)
			local entity = self.owner
			if entity.immune.bubble then
				return false
			end
			local b = buff_get(entity, "bubble")
			if b then
				if b.team == team then
					b.duration = b.duration + self.duration
					b.strength = math.max(b.strength, self.strength)
				end
				return false
			end

			if buff_remove(entity, "burn") then
				return false
			end

			self.tick = tick_table[entity.team == team]

			return true
		end,
	}

end

local function storm(team, power)
	local tick_table = {
		[true] = {{
			core.priority.stat, function(self)
				local entity = self.owner
				local t = config.entity.cangqiong.skill.storm
				entity.speed = entity.speed + t.ally.speed
				entity.accuracy = entity.accuracy + t.ally.accuracy
				return false
			end,
		}},
		[false] = {{
			core.priority.block, function(self)
				local entity = self.owner
				local t = config.entity.cangqiong.skill.storm
				block_tick(entity, self.strength * t.enemy.block_ratio)
				entity.speed = math.max(0, entity.speed + t.enemy.speed)
				entity.accuracy = math.max(0, entity.accuracy + t.enemy.accuracy)
				return true
			end,
		}, {
			core.priority.damage, function(self)
				local entity = self.owner
				local t = config.entity.cangqiong.skill.storm
				local d = util.copy_table(t.damage)
				d.damage = self.power * d.ratio
				d.ratio = nil
				core.damage(entity, d)

				d = util,copy_table(t.extra)
				d.damage = self.power * d.ratio
				d.ratio = nil
				core.damage(entity, d)
				return false
			end,
		}},
	}

	return {
		name = "buff.storm",
		power = power,

		initial = function(self)
			local entity = self.owner

			self.tick = tick_table[entity.team == team]
		end,
	}
end

local function blackhole(team, power)
	local tick_table = {
		[true] = {{
			core.priority.stat, function(self)
				-- noop
				return true
			end,
		}},
		[false] = {{
			core.priority.block, function(self)
				local entity = self.owner
				local t = config.entity.stardust.skill.blackhole
				block_tick(entity, self.power * t.block_ratio)
				return true
			end,
		}, {
			core.priority.damage, function(self)
				local entity = self.owner
				local t = config.entity.stardust.skill.blackhole

				core.damage(entity, util.merge_table(
					util.copy_table(t.damage), {
						damage = t.damage.damage(self.power, entity.health_cap),
					}))
				return false
			end,
		}},
	}

	return {
		name = "buff.blackhole",
		power = power,

		initial = function(self)
			local entity = self.owner

			self.tick = tick_table[entity.team == team]
		end,

	}
end

list = {
	fly = fly,
	down = down,
	block = block,
	drown = drown,
	burn = burn,
	wet = wet,
	bubble = bubble,
	storm = storm,
	blackhole = blackhole,
}


return {
	insert = function(...)
		return buff_insert(true, ...)
	end,
	insert_notick = function(...)
		return buff_insert(false, ...)
	end,
	get = buff_get,
	remove = buff_remove,

	tick = buff_tick,
	defer = buff_defer,
}
