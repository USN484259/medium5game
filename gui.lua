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
local gl_text = require("gl/text")

-- global variables
local locale_table
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

local function translate(name, ...)
	local cnt = select("#", ...)
	if cnt > 0 then
		local prefix = ""
		for i = cnt, 1, -1 do
			prefix = prefix .. (select(i, ...)) .. '.'
		end
		name = prefix .. name
	end

	-- print("translating key: " .. name)

	local l = locale_table
	for k in string.gmatch(name, "([^%.]+)") do
		if type(l) ~= "table" then
			return name
		end
		l = l[k]
	end

	if type(l) == "string" then
		return l, name
	elseif type(l) == "table" and type(l[1]) == "string" then
		return color(l[2]) .. l[1] .. color(), name
	else
		return name
	end
end

local function floating_text(map, obj, str, color)
	local pos = map.gui:tile(obj.pos)

	gl_motion.add(obj.gui, {{
		name = "overlay",
		args = {
			-- element-info
			{
				type = "text",
				args = { str, 64 },
				overrides = {
					color = {
						color[1],
						color[2],
						color[3],
						0,
					},
					pos = {
						pos[1],
						pos[2] + map.gui.size / 4,
					},
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
					pos[1],
					pos[2] + map.gui.size,
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
			args = {map.scale, size},
		})
	end,
	spawn = function(map, obj)
		local path = "resources/" .. string.sub(obj.name, 1 + string.find(obj.name, '.', 1, true)) .. ".png"
		local ui = map.gui:add({
			type = "image",
			args = {path},
		})
		ui.scale = 3 / 2 * map.gui.size / math.max(ui.width, ui.height)
		ui.pos = map.gui:tile(obj.pos)
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

	window:clear()
	local map = require("core/map")(map_info)

	local tid = 0
	local round = 1
	local action_list = {{
		cmd = "round_start"
	}}
--[[
	cmd:	quit, round_start, round_end, action

--]]

	return window:run(function(wnd)
		if wnd.motion_count > 0 then
			return
		end
		if #action_list > 0 then
			local action = table.remove(action_list, 1)
			assert(type(action) == "table")

			if action.cmd == "quit" then
				return action.cmd
			elseif action.cmd == "round_start" then
				print("round_start\tteam: " .. tid .. "\tround: " .. round)
				action_list = map:round_start(tid, round)
				if action_list then
					table.insert(action_list, 1, {
						cmd = "skill_update",
					})
				else
					action_list = {{
						cmd = "round_end",
					}}
				end
			elseif action.cmd == "round_end" then
				print("round_end\tteam: " .. tid .. "\tround: " .. round)
				map:round_end(tid, round)
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
	local y = gl_misc.coordinate_radix - 64
	for i, v in ipairs(map_list) do
		local l = window.root:add({
			type = "text",
			args = {v, 64},
			overrides = {
				pos = {0, y},
				color = {0, 0, 0, 1},
				handler = function(self, wnd, ev, info)
					if ev == "mouse_move" or ev == "mouse_press" then
						if self:bound(info.pos) then
							self.color = {1, 0, 0, 1}
							if ev == "mouse_press" then
								map_name = self.str
								return true
							end
						else
							self.color = {0, 0, 0, 1}
						end
					end
				end
			},
		})
		print(l.str, y)
		y = y - l.height
	end

	return window:run(function(wnd)
		return map_name
	end)
end

local function main_window()
	util.random_setup(rng_source, rng_seed or os.time())
	locale_table = require(locale_folder .. '/' .. locale)

	for i, v in ipairs(font_list) do
		gl_text.add_face(resource_folder .. '/' .. v)
	end

	local title = translate("ui.game_title")
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
