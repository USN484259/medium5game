local config = require("base/config")
local cfg = config.buff

local util = require("core/util")
local core = require("core/core")
local buff = require("core/buff")

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

				if entity.type ~= "character" or entity.status.fly or entity.immune.drown then
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

				if buff.remove(entity, "wet") or buff.get(entity, "bubble") then
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
		}},

		initial = function(self)
			local entity = self.owner
			local b = buff.get(entity, "burn")
			if b then
				b.duration = math.max(b.duration, self.duration)
				b.damage = math.max(b.damage, self.damage)
				return false
			end

			return true
		end,
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

				if entity.type == "character" then
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
							entity.map:event(entity, "shield", b, blk)
							b.strength = math.floor(b.strength - blk / t.energy_efficiency)
							return damage
						end
					})
				end
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
			local b = buff.get(entity, "bubble")
			if b then
				if b.team == team then
					b.duration = b.duration + self.duration
					b.strength = math.max(b.strength, self.strength)
				end
				return false
			end

			if buff.remove(entity, "burn") then
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
				block_tick(entity, self.power * t.enemy.block_ratio)
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

				d = util.copy_table(t.extra)
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
			return true
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
			return true
		end,

	}
end

return {
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



