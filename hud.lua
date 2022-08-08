local util = require("core/util")
local misc = require("gl/misc")
local motion = require("gl/motion")

--[[

map ==> hud
select_tile

core ==> map
tile_change

core ==> hud
round_start
round_end
update

hud ==> core
query_action
use_skill
end_round
quit

--]]

local function skill_check(hud, sk)
	assert(hud.cur_entity)
	if not sk then
		hud.cur_skill = nil
		return
	end

	if hud.cur_skill and hud.cur_skill == sk then
		hud.callbacks.use_skill(hud.cur_entity, hud.cur_skill, hud.skill_args)
		hud.cur_skill = nil
	elseif sk.type == "toggle" or sk.type == "effect" then
		hud.callbacks.use_skill(hud.cur_entity, sk, {})
		hud.cur_skill = nil
	else
		hud.cur_skill = sk
		hud.skill_args = {}
	end
end

local function skill_pick(hud, tile, dir)
	error "TODO"
end

local function show_info(hud, obj)
	if hud.cur_entity == obj then
		return
	end
	hud.cur_entity = obj
	hud.cur_skill = nil

	local left_panel = hud.root.left_panel
	local illustration = hud.root.right_panel.illustration
	motion.clear(illustration)
	left_panel:clear()
	if not obj then
		illustration.hidden = true
		return
	end

	local entity_name = string.sub(obj.name, 8)

	illustration:load("illustration_" .. entity_name)
	misc.fit(illustration, "scale", 1000, 1200)
	misc.align(illustration, "bottom", -misc.coordinate_radix)
	misc.align(illustration, "right", -200)
	illustration.color[4] = 0
	illustration.hidden = false
	motion.add(illustration, {{
		name = "fade_in",
		duration = 0.6,
		args = {0.6},
	}, {
		name = "move",
		duration = 0.6,
		args = {{
			illustration.offset[1] - 200,
			illustration.offset[2],
		}},
		watch = 0,
	}})

	local icon = left_panel:add({
		type = "image",
		path = "icon_" .. entity_name,
		offset = {0, 0},
	})
	misc.fit(icon, "scale", 300, 300)
	misc.align(icon, "left", 40)
	misc.align(icon, "top", -1000)

	local name = left_panel:add({
		type = "image",
		path = "name_" .. entity_name,
		offset = {icon.offset[1], 0},
	})
	misc.fit(name, "scale", 200, 200)
	misc.align(name, "top", 20, icon)

	local hp_text = left_panel:add({
		type = "text",
		size = 64,
		str = "HP " .. obj.health .. '/' .. obj.health_cap,
		offset = {0, 0}
	})
	misc.align(hp_text, "left", 40, icon)
	misc.align(hp_text, "top", -950)

	local mp_text = left_panel:add({
		type = "text",
		size = 64,
		str = "MP " .. obj.energy .. '/' .. (obj.energy_cap or 0),
		offset = {0, 0}
	})
	misc.align(mp_text, "left", 40, icon)
	misc.align(mp_text, "top", 20, hp_text)

	local skill_panel = left_panel:add({
		type = "hub",
		size = 160,
		offset = {450, -600}
	})

	for i = 1, 7, 1 do
		local skill_pos = {0, 0}
		if i > 1 then
			local rad = math.rad((i - 2) * 60)
			skill_pos = {
				skill_panel.size * math.sqrt(3) * math.cos(rad),
				skill_panel.size * math.sqrt(3) * math.sin(rad),
			}
		end
		local sk = obj.skills[i]
		if sk then
			skill_panel:add({
				type = "button",
				frame = "hexagon",
				radius = skill_panel.size,
				offset = skill_pos,
				fill_color = {0.8, 0.8, 0.8, 1},
				border_color = {0, 0, 0, 1},

				label = {
					type = "text",
					offset = {0, 0},
					size = 48,
					str = util.translate(sk.name),
					color = {0, 0, 0, 1},
				},
				hover = function(self, val)
					if val then
						-- TODO set description
						self.label.color = {1, 0, 0, 1}
					else
						self.label.color = {0, 0, 0, 1}
					end
				end,
				press = function(self, key)
					if key == "left" and obj.team == hud.cur_team and not hud:is_busy() then
						skill_check(hud, sk)
					end
				end,
			})
		else
			skill_panel:add({
				type = "hexagon",
				radius = skill_panel.size,
				offset = skill_pos,
				fill_color = {0.8, 0.8, 0.8, 1},
				border_color = {0, 0, 0, 1},
			})
		end

	end
end

local function new_hud(window, cb, tid)
	local hud = {
		callbacks = cb,
		control_team = tid,
		cur_round = nil,
		cur_team = nil,
		cur_entity = nil,
		cur_skill = nil,
		skill_args = {},
		is_busy = function(self)
			return self.cur_team ~= self.control_team or self.callbacks.query_action()
		end,
		round_start = function(self, tid, round)
			self.cur_team = tid
			self.cur_round = round

			local round_text = self.root.right_panel.round_text
			round_text:set_text(util.translate("lang.round") .. ' ' .. round)
			misc.align(round_text, "top", 40, self.root.right_panel.end_round)
		end,
		round_end = function(self, tid, round)
			self.cur_skill = nil
			self.cur_team = nil
		end,
		select_tile = function(self, tile, dir, obj)
			print(tile[1], tile[2], obj and obj.name)
			if not self:is_busy() and self.cur_skill then
				skill_pick(self, tile, dir)
			else
				show_info(self, obj)
			end
		end,
		update = function(self, obj)
			error "TODO"
		end,
	}

	local root = window.root:add({
		type = "hub",
		layer = misc.layer.hud,
		handler = function(self, wnd, ev, info)
			if ev == "mouse_press" and info.button == "right" then
				if hud.cur_skill then
					skill_check(hud, nil)
					return true
				elseif hud.cur_entity then
					show_info(hud, nil)
					return true
				end
			end
		end
	})
	hud.root = root

	local left_panel = root:add({
		type = "hub",
		pos = {0, 0},
	})
	motion.add(left_panel, {{
		name = "attach",
		args = {"left"},
	}})
	root.left_panel = left_panel

	local right_panel = root:add({
		type = "hub",
		pos = {0, 0},
	})
	motion.add(right_panel, {{
		name = "attach",
		args = {"right"},
	}})
	root.right_panel = right_panel

	local quit = right_panel:add({
		type = "button",
		frame = "box",
		fill_color = {0.6, 0.6, 0.6, 1},
		border_color = {0, 0, 0, 1},
		offset = {0, 0},
		margin = {40, 20},

		label = {
			type = "text",
			offset = {0, 0},
			size = 64,
			str = util.translate("ui.map_exit"),
			color = {0, 0, 0, 1},
		},
		hover = function(self, val)
			if val then
				self.label.color = {1, 0, 0, 1}
			else
				self.label.color = {0, 0, 0, 1}
			end
		end,
		press = function(self, key)
			if key == "left" then
				hud.callbacks.quit()
			end
		end,
	})
	misc.align(quit, "right", 60)
	misc.align(quit, "top", -960)

	local end_round = right_panel:add({
		type = "button",
		frame = "box",
		fill_color = {0.6, 0.6, 0.2, 1},
		border_color = {0, 0, 0, 1},
		offset = {0, 0},
		margin = {40, 20},

		label = {
			type = "text",
			offset = {0, 0},
			size = 64,
			str = util.translate("ui.round_end"),
			color = {0, 0, 0, 1},
		},

		hover = function(self, val)
			if val then
				self.label.color = {1, 0, 0, 1}
			else
				self.label.color = {0, 0, 0, 1}
			end
		end,
		press = function(self, key)
			if key == "left" and not hud:is_busy() then
				print(self.label.str, hud.cur_team)
				hud.callbacks.end_round(hud.cur_team)
			end
		end,
	})
	misc.align(end_round, "right", 60)
	misc.align(end_round, "top", 40, quit)
	right_panel.end_round = end_round

	local round_text = right_panel:add({
		type = "text",
		size = 64,
		offset = {end_round.offset[1], 0},
	})
	-- set_text & align in round_start
	right_panel.round_text = round_text

	local illustration = right_panel:add({
		type = "image",
		offset = {0, 0},
		hidden = true,
	})
	right_panel.illustration = illustration

	return hud
end

return new_hud
