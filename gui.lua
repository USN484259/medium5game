#!/usr/bin/env lua

local version = { 0, 0, 1 }

-- default config
local locale = "zh-cn"
local font_list = {
	"wqy-zenhei.ttc",
	"NotoColorEmoji.ttf",
}
local resource_folder = "resources"
local locale_folder = "locale"
local map_folder = "maps"
local rng_source = "os"
local rng_seed = nil

-- module including
local platform = require("lua_platform")
local util = require("core/util")
local core = require("core/core")
local hexagon = require("core/hexagon")

local gl_window = require("gl/window")
local gl_misc = require("gl/misc")
local gl_motion = require("gl/motion")
local gl_image = require("gl/image")
local gl_text = require("gl/text")


-- global variables
local window

local element_color = {
	physical = {0.3, 0.3, 0.3},
	mental = {0.788, 0.212, 0.882},
	fire = {0.969, 0.227, 0.227},
	water = {0.416, 0.788, 0.980},
	air = {0.502, 0.973, 0.894},
	light = {0.980, 0.996, 0.451},
	earth = {1.000, 0.847, 0.361},
}

local function show_version()
	return version[1] .. '.' .. version[2] .. '.' .. version[3]
end

local function floating_text(map, obj, str, color)
	-- local pos = map.gui:tile(obj.pos)

	gl_motion.add(obj.gui, {{
		name = "overlay",
		args = {
			-- element-info
			{
				type = "text",
				layer = gl_misc.layer.overlay,
				str = str,
				size = 64,
				color = {
					color[1],
					color[2],
					color[3],
					0,
				},
				offset = {
					0,
					map.gui.size / 4,
				},
			},
			-- motion-list
			{{
				name = "fade_in",
				duration = 0.3,
				args = { color[4] },
			}, {
				name = "signal",
			}, {
				name = "move",
				duration = 0.8,
				args = {{
					0,
					map.gui.size,
				}},
				watch = 0,
			}, {
				name = "remove",
			}},
		}
	}})
end

local event_table = {
	new_map = function(map)
		local size = math.floor((gl_misc.coordinate_radix * 7 / 8) / (1 + 3 * map.scale / 2))
		map.gui = window.root:add({
			type = "map",
			layer = gl_misc.layer.background,
			map = map,
			size = size,
		})
	end,
	spawn = function(map, obj)
		local path = string.sub(obj.name, 1 + string.find(obj.name, '.', 1, true))
		local ui = map.gui:add({
			type = "image",
			layer = gl_misc.layer.common,
			path = path,
		})
		ui.scale = 3 / 2 * map.gui.size / math.max(ui.width, ui.height)
		ui.offset = map.gui:tile(obj.pos)
		obj.gui = ui
		ui.color[4] = 0
		gl_motion.add(ui, {{
			name = "fade_in",
			duration = 0.6,
		}})
	end,
	kill = function(map, obj)
		gl_motion.add(obj.gui, {{
			name = "fade_out",
			duration = 0.6,
		}, {
			name = "remove",
		}})

		obj.gui = nil
	end,
	move = function(map, obj, waypoint)
		local queue = {}
		local pos = obj.pos

		for i, d in ipairs(waypoint) do
			pos = hexagon.direction(pos, d)
			table.insert(queue, {
				name = "move",
				duration = 0.5,
				args = { map.gui:tile(pos) },
			})
		end

		gl_motion.add(obj.gui, queue)
	end,
	teleport = function(map, obj, target)
		gl_motion.add(obj.gui, {{
			name = "fade_out",
			duration = 0.3,
		}, {
			name = "move",
			duration = 0,
			args = { map.gui:tile(target) },
		}, {
			name = "fade_in",
			duration = 0.3,
		}})
	end,
	heal = function(map, obj, heal)
		print("heal", obj.name, heal)
		floating_text(map, obj, '+' .. tostring(math.floor(heal)), {0, 0.7, 0, 1})
	end,
	damage = function(map, obj, damage, element)
		print("damage", obj.name, damage, element)

		local color = {}
		for i, c in ipairs(element_color[element]) do
			color[i] = c * 0.8
		end
		color[4] = 1

		floating_text(map, obj, tostring(math.floor(damage)), color)
	end,
	miss = function(map, obj)
		print("miss", obj.name)
		floating_text(map, obj, "miss", {0.3, 0.3, 0.3, 1})
	end,
	shield = function(map, obj, sh, blk)
		print("shield", obj.name, sh.name, blk)
		floating_text(map, obj, '🛡' .. tostring(math.floor(blk)), {0.3, 0.3, 0.3, 1})
	end,
	generate = function(map, obj, power)
		print("generate", obj.name, power)
		floating_text(map, obj, '⚡' .. tostring(math.floor(power)), {0.0, 0.6, 0.5, 1})
	end,
}

local function main_game(map_name)
	local chunk, err = loadfile(map_folder .. '/' .. map_name .. ".lua")
	if not chunk then
		print("failed to load map " .. map_name, err)
		return true
	end

	local res, map_info = pcall(chunk)
	if not res or type(map_info) ~= "table" then
		print("failed to load map " .. map_name, map_info)
		return true
	end

	map_info.event_table = event_table

	local team_count = #map_info.teams
	local control_team

	for i, v in ipairs(map_info.teams) do
		if v.faction == "player" then
			control_team = i
			break
		end
	end

	window:clear()
	local map = require("core/map")(map_info)

	-- cmd:	quit, round_start, round_end, action
	local action_list = {{
		cmd = "round_start"
	}}
	local tid = 0
	local round = 1
	local quit_reason = nil

	local hud = require("hud")(window, {
		query_action = function()
			if #action_list == 0 then
				return nil
			else
				return action_list[1].cmd
			end
		end,
		quit = function()
			quit_reason = "hud"
		end,
		end_round = function()
			table.insert(action_list, {
				cmd = "round_end",
			})
		end,
		use_skill = function(entity, skill, args)
			error "TODO"
		end,
	}, control_team)

	map.hud = hud

	return window:run(function(wnd)
		if quit_reason then
			return quit_reason
		end
		if wnd.motion_count > 0 then
			return
		end
		if #action_list > 0 then
			local action = table.remove(action_list, 1)
			assert(type(action) == "table")

			if action.cmd == "round_start" then
				print("round_start\tteam: " .. tid .. "\tround: " .. round)
				hud:round_start(tid, round)
				action_list = map:round_start(tid, round)
				if action_list then
					table.insert(action_list, 1, {
						cmd = "skill_update",
					})
				elseif tid == control_team then
					action_list = {{
						cmd = "skill_update",
					}}
				else
					action_list = {{
						cmd = "round_end",
					}}
				end
			elseif action.cmd == "round_end" then
				print("round_end\tteam: " .. tid .. "\tround: " .. round)
				map:round_end(tid, round)
				hud:round_end(tid, round)
				if tid == team_count then
					tid = 0
					round = round + 1
				else
					tid = tid + 1
				end
				table.insert(action_list, {
					cmd = "round_start",
				})
			elseif action.cmd == "action" then
				local res = action.entity:action(action.skill, table.unpack(action.args or {}))
				if not res then
					print("action failed", action.entity.name, action.skill.name)
				end
				table.insert(action_list, 1, {
					cmd = "skill_update",
				})
			elseif action.cmd == "skill_update" then
				local team = map:get_team(tid)
				for k, e in ipairs(team) do
					for i, sk in ipairs(e.skills) do
						sk:update()
					end
				end
			else
				error(action.cmd)
			end
		end
	end)
end

local function main_menu()
	local l = platform.ls(map_folder)
	local map_list = {}
	local map_name = nil
	for k, v in pairs(l) do
		-- TODO check symbolic link
		if string.lower(string.sub(k, -4)) == ".lua" then
			table.insert(map_list, string.sub(k, 1, -5))
		end
	end

	table.sort(map_list)

	window:clear()
	local last_button = nil
	local y = gl_misc.coordinate_radix - 64
	for i, v in ipairs(map_list) do
		local button = window.root:add({
			type = "button",
			frame = "box",
			layer = gl_misc.layer.hud,
			margin = {40, 20},
			offset = {0, 0},
			fill_color = {
				{0.6, 0.6, 0.6, 0.8},
				{0.6, 0, 0, 0.8},
				{0, 0.6, 0, 0.8},
				{0, 0, 0.6, 0.8},
				{0.6, 0.6, 0, 0.8},
			},
			border_color = {0, 0, 0, 1},
			label = {
				type = "text",
				offset = {0, 0},
				str = v,
				size = 64,
				color = {0, 0, 0, 1},
			},
			hover = function(self, val)
				if val then
					self.label.color = {1, 0, 0, 1}
				else
					self.label.color = {0, 0, 0, 1}
				end
			end,
			press = function(self)
				map_name = self.label.str
			end,
		})
		if last_button then
			gl_misc.align(button, "top", 0, last_button)
		else
			button.offset = {0, 900}
		end

		last_button = button

	end

	return window:run(function(wnd)
		return map_name
	end)
end

local function main_window()
	util.locale_setup(locale, locale_folder)
	util.random_setup(rng_source, rng_seed or os.time())
	gl_image.set_rc_path(resource_folder)

	for i, v in ipairs(font_list) do
		gl_text.add_face(resource_folder .. '/' .. v)
	end

	local title = util.translate("ui.game_title")
	window = gl_window.new_window(title)


	while true do
		local map_name = main_menu()
		if not map_name then
			break
		end

		if not main_game(map_name) then
			break
		end
	end
end

return main_window()
