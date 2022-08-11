local util = require("core/util")
local hexagon = require("core/hexagon")
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

local function skill_overlay(hud)
	local overlay = hud.root.skill_overlay
	if not hud.cur_skill then
		overlay.hidden = true
		overlay.on_move = nil
		return
	end
	local name = hud.cur_skill.type
	print("skill_overlay", name, hexagon.print(hud.ref_tile))
	if name == "target" or name == "multitarget" then
		overlay:load("icon.crosshair")
		overlay.color = misc.element_color(hud.cur_entity.element, {1, 1, 1, 1})
		misc.fit(overlay, "scale", 200, 200)
		overlay.rotation = 0
		overlay.on_move = function(self, pos)
			self.pos = pos
		end
		overlay.hidden = false
	elseif name == "waypoint" or name == "direction" then
		local anchor_point = hud.root.parent.map:tile2point(hud.ref_tile)
		overlay:load("icon.arrow")
		overlay.color = misc.element_color(hud.cur_entity.element, {1, 1, 1, 1})
		misc.fit(overlay, "scale", 200, 200)
		overlay.on_move = function(self, pos)
			local rot = math.atan(pos[2] - anchor_point[2], pos[1] - anchor_point[1])
			self.rotation = math.deg(rot)
			self.pos = {
				anchor_point[1] + self.scale * self.width * math.cos(rot) * 3 / 4,
				anchor_point[2] + self.scale * self.width * math.sin(rot) * 3 / 4,
			}
		end
		overlay.hidden = false
	else
		error("unknown overlay type " .. name)
	end
end

local function skill_check(hud, sk)
	if not (hud.cur_entity and sk and hud.cur_entity.active and sk.enable and sk.remain == 0) then
		hud.cur_skill = nil
		skill_overlay(hud)
		return
	end

	if hud.cur_skill and hud.cur_skill == sk then
		hud.callbacks.use_skill(hud.cur_entity, hud.cur_skill, hud.skill_args)
		hud.cur_skill = nil
		skill_overlay(hud)
	elseif sk.type == "toggle" or sk.type == "effect" then
		hud.callbacks.use_skill(hud.cur_entity, sk, {})
		hud.cur_skill = nil
		skill_overlay(hud)
	else
		hud.cur_skill = sk
		hud.ref_tile = hud.cur_entity.pos
		hud.skill_args = {}
		skill_overlay(hud)
	end
end

local skill_picker_table = {
	waypoint = function(hud, tile, dir)
		table.insert(hud.skill_args, dir)
		hud.ref_tile = hexagon.direction(hud.ref_tile, dir)
		skill_overlay(hud)
		return #hud.skill_args >= hud.cur_skill.step
	end,
	target = function(hud, tile, dir)
		hud.skill_args = { tile }
		return true
	end,
	multitarget = function(hud, tile, dir)
		table.insert(hud.skill_args, tile)
		return #hud.skill_args >= hud.cur_skill.shots
	end,
	direction = function(hud, tile, dir)
		hud.skill_args = { dir }
		return true
	end,
	vector = function(hud, tile, dir)
		error "TODO"
	end,
	line = function(hud, tile, dir)
		error "TODO"
	end,
}

local function skill_pick(hud, tile, dir)
	local sk = hud.cur_skill
	assert(sk)

	if not tile then
		return
	end

	if skill_picker_table[sk.type](hud, tile, dir) then
		return skill_check(hud, sk)
	end
end

local function show_info(hud, obj)
	local update = (hud.cur_entity == obj)

	hud.cur_entity = obj
	skill_check(hud, nil)

	local left_panel = hud.root.left_panel
	local illustration = hud.root.right_panel.illustration

	if not obj then
		left_panel:clear()
		illustration.hidden = true
		return
	end

	local entity_name = string.gsub(obj.name, "entity%.([^%s]+)", "%1")

	if not update then
		left_panel:clear()
		motion.clear(illustration)
		illustration:load("illustration." .. entity_name)
		misc.fit(illustration, "scale", 1200, 1200)
		misc.align(illustration, "bottom", -misc.coordinate_radix)
		misc.align(illustration, "right", 0)
		illustration.color[4] = 0
		illustration.hidden = false
		motion.add(illustration, {{
			name = "fade_in",
			duration = 0.4,
			args = {0.8},
		}})
	end

	local icon = left_panel.icon

	if not update then
		icon = left_panel:add({
			type = "image",
			path = "icon." .. entity_name,
			offset = {0, 0},
		})
		left_panel.icon = icon
		misc.fit(icon, "scale", 300, 300)
		misc.align(icon, "left", 40)
		misc.align(icon, "top", -1000)
	end

	local name = left_panel.name

	if not update then
		name = left_panel:add({
			type = "image",
			path = "name." .. entity_name,
			offset = {icon.offset[1], 0},
		})
		left_panel.name = name
		misc.fit(name, "scale", 200, 200)
		misc.align(name, "top", 20, icon)
	end

	local hp_text = left_panel.hp_text

	if not update then
		hp_text = left_panel:add({
			type = "text",
			size = 64,
			offset = {0, 0},
		})
		left_panel.hp_text = hp_text
	end
	hp_text:set_text("HP " .. obj.health .. '/' .. obj.health_cap)
	misc.align(hp_text, "left", 40, icon)
	misc.align(hp_text, "top", -950)

	local mp_text = left_panel.mp_text

	if not update then
		mp_text = left_panel:add({
			type = "text",
			size = 64,
			offset = {0, 0}
		})
		left_panel.mp_text = mp_text
	end
	mp_text:set_text("MP " .. obj.energy .. '/' .. (obj.energy_cap or 0))
	misc.align(mp_text, "left", 40, icon)
	misc.align(mp_text, "top", 20, hp_text)

	local status_str = nil
	for k, v in pairs(obj.status) do
		local str = util.translate(k, "status")
		if type(v) == "number" then
			str = str .. '(' .. v .. ')'
		end

		if status_str then
			status_str = status_str .. ' ' .. str
		else
			status_str = str
		end
	end

	local status_text = left_panel.status_text

	if not update then
		status_text = left_panel:add({
			type = "text",
			size = 64,
			offset = {0, 0},
		})
		left_panel.status_text = status_text
	end
	status_text:set_text(status_str)
	misc.align(status_text, "left", 40, icon)
	misc.align(status_text, "top", 20, mp_text)

	if obj.team ~= hud.control_team then
		return
	end

	local last_item = nil
	left_panel.item = left_panel.item or {}
	for i, item in ipairs(obj.inventory) do
		local item_str = util.translate(item.name)
		if item.remain then
			item_str = item_str .. ' ' .. (item.cooldown - item.remain) .. '/' .. item.cooldown
		elseif item.modes then
			local mode = item.modes[item.select]
			item_str = item_str .. ':' .. util.translate(type(mode) == "table" and mode.name or mode, entity_name, "item")
		elseif item.energy then
			item_str = item_str .. ' ' .. item.energy .. '/' .. item.energy_cap
		elseif item.water then
			item_str = item_str .. ' ' .. item.water .. '/' .. item.water_cap
		end

		local item_button = left_panel.item[i]
		if update then
			item_button.label:set_text(item_str)
		else
			item_button = left_panel:add({
				type = "button",
				frame = "box",
				width = 200,
				height = 200,
				offset = {0, 0},
				fill_color = {0.5, 0.5, 0.5, 0.2},
				border_color = {0, 0, 0, 1},
				image = {
					type = "image",
					mode = "fit",
					path = item.name,
					offset = {0, 0},
				},
				label = {
					type = "text",
					size = 32,
					str = item_str,
					offset = {0, -80},
				}
			})
			left_panel.item[i] = item_button

			if last_item then
				item_button.offset[1] = last_item.offset[1]
				misc.align(item_button, "top", 0, last_item)
			else
				misc.align(item_button, "left", 40)
				misc.align(item_button, "top", 40, name)
			end
		end

		last_item = item_button
	end

	local skill_panel = left_panel.skill_panel
	if not update then
		skill_panel = left_panel:add({
			type = "hub",
			size = 150,
			offset = {450, -600}
		})
		left_panel.skill_panel = skill_panel
		skill_panel.skill = {}
	end

	for i = 1, 7, 1 do
		local skill_button = skill_panel.skill[i]
		local sk = obj.skills[i]
		if not update then
			local skill_pos = {0, 0}
			if i > 1 then
				local rad = math.rad((i - 2) * 60)
				skill_pos = {
					skill_panel.size * math.sqrt(3) * math.cos(rad),
					skill_panel.size * math.sqrt(3) * math.sin(rad),
				}
			end
			local info = {
				type = "button",
				frame = "hexagon",
				radius = skill_panel.size,
				offset = skill_pos,
				fill_color = {0.8, 0.8, 0.8, 1},
				border_color = {0, 0, 0, 1},
			}
			if sk then
				info.label = {
					type = "text",
					offset = {0, 0},
					size = 48,
					color = {0, 0, 0, 1},
				}
				info.hover = function(self, val)
					if val then
						-- TODO set description
						self.label.color = {1, 1, 1, 1}
					else
						self.label.color = {0, 0, 0, 1}
					end
				end
				info.press = function(self, key)
					if key == "left" and obj.team == hud.cur_team and not hud:is_busy() then
						skill_check(hud, sk)
					end
				end
			end
			skill_button = skill_panel:add(info)
			skill_panel.skill[i] = skill_button
		end

		if sk then
			skill_button.label:set_text(util.translate(sk.name))
		end

		if sk and obj.active and sk.enable and sk.remain == 0 then
			skill_button.color = misc.element_color(obj.element, {1, 1, 1, 1})
		else
			skill_button.color = {1, 1, 1, 1}
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
		query_anchor = function(self)
			return self.ref_tile
		end,
		round_start = function(self, tid, round)
			self.cur_team = tid
			self.cur_round = round

			local round_text = self.root.right_panel.round_text
			round_text:set_text(util.translate("lang.round") .. ' ' .. round)
			misc.align(round_text, "top", 40, self.root.right_panel.end_round)
		end,
		round_end = function(self, tid, round)
			self.cur_team = nil
			show_info(self, self.cur_entity)
		end,
		select_tile = function(self, tile, dir, obj)
			print("select_tile", hexagon.print(tile), dir, obj and obj.name)
			if not self:is_busy() and self.cur_skill then
				skill_pick(self, tile, dir)
			else
				show_info(self, obj)
			end
		end,
		update = function(self)
			show_info(self, self.cur_entity)
		end,
		message = function(self, str, color)
			color = color or {0, 0, 0, 0.7}
			motion.add(self.root, {{
				name = "overlay",
				skip = true,
				args = {
					-- element-info
					{
						type = "text",
						layer = misc.layer.top,
						str = str,
						size = 64,
						color = {
							color[1],
							color[2],
							color[3],
							0,
						},
						offset = {0, misc.coordinate_radix / 2},
					},
					-- motion-list
					{{
						name = "fade_in",
						duration = 0.4,
						args = { color[4] },
						skip = true,
					}, {
						name = "signal",
					}, {
						name = "move",
						duration = 1.5,
						args = {{
							0,
							misc.coordinate_radix * 3 / 4
						}},
						watch = 0,
						skip = true,
					}, {
						name = "remove",
						skip = true,
					}},
				},
			}})
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

	root.skill_overlay = root:add({
		type = "image",
		layer = root.layer + 0x20,
		pos = {0, 0},
		hidden = true,
		handler = function(self, wnd, ev, info)
			if ev == "mouse_move" and self.on_move then
				self:on_move(info.pos)
			end
		end,
	})

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
				-- print(self.label.str, hud.cur_team)
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
