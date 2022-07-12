#!/usr/bin/env lua

local version = { 0, 0, 1 }

-- default config
local locale = "zh-cn"
local font_path = nil
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
local gl_map = require("gl/map")
local gl_image = require("gl/image")
local gl_text = require("gl/text")

-- global variables
local locale_table
local face
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

local event_table = {
	new_map = function(map)
		local size = math.floor((gl_misc.coordinate_radix * 7 / 8) / (1 + 3 * map.scale / 2))
		local ui = gl_map.new_map(map.scale, size)
		window:add(ui)
		map.gui = ui
	end,
	spawn = function(map, obj)
		local path = "resources/" .. string.sub(obj.name, 1 + string.find(obj.name, '.', 1, true)) .. ".png"
		local ui = gl_image.new_image(path)
		ui.scale = 3 / 2 * map.gui.size / math.max(ui.width, ui.height)
		ui.pos = map.gui:tile(obj.pos)
		ui.alpha = 0
		window:add(ui)
		obj.gui = ui

		local duration = 0.6
		local anime_spawn = gl_misc.animation_list.fade_in(obj.gui, duration)

		window.anime:add(obj.gui, anime_spawn)
	end,
	kill = function(map, obj)
		local duration = 0.6
		local delay = 1
		local anime_kill = gl_misc.animation_list.fade_out(obj.gui, duration)
		anime_kill.done = function(self, element, time)
			assert(element == obj.gui)
			window:remove(obj.gui)
			-- FIXME close gui object
			obj.gui = nil
		end
		window.anime:add(obj.gui, anime_kill, delay)
	end,
	move = function(map, obj, waypoint)
		local points = {}
		local pos = obj.pos

		for i, d in ipairs(waypoint) do
			pos = hexagon.direction(pos, d)
			table.insert(points, map.gui:tile(pos))
		end

		local anime_move = {
			pos = map.gui:tile(obj.pos),
			points = points,
			duration = 0.5,
			tick = function(self, element, time)
				local dis = gl_misc.animation_progress(self, time)
				element.pos = {
					self.pos[1] * (1 - dis) + self.points[1][1] * dis,
					self.pos[2] * (1 - dis) + self.points[1][2] * dis,
				}

				if dis == 1 then
					self.timestamp = time
					self.pos = table.remove(self.points, 1)
				end

				return #self.points ~= 0
			end,
		}
		window.anime:add(obj.gui, anime_move)
	end,
	teleport = function(map, obj, target)
		local anime_teleport = {
			moved = false,
			duration = 0.3,
			tick = function(self, element, time)
				local dis = gl_misc.animation_progress(self, time)

				if self.moved then
					element.alpha = dis
					if dis == 1 then
						return false
					end
				else
					element.alpha = 1 - dis

					if dis == 1 then
						self.timestamp = time
						element.pos = map.gui:tile(target)
						self.moved = true
					end
				end

				return true
			end,
		}
		window.anime:add(obj.gui, anime_teleport)
	end,
	heal = function(map, obj, heal)
		print("heal", obj.name, heal)
		local text = face:new_text('+' .. heal)
		text.color = {0, 0.7, 0, 1}
		local pos = map.gui:tile(obj.pos)
		pos[2] = pos[2] + map.gui.size / 8
		text.pos = pos

		window:add(text)

		local duration = 0.6
		local target = {
			pos[1],
			pos[2] + map.gui.size / 2,
		}
		local anime_move = gl_misc.animation_list.move(text, target, duration)
		anime_move.done = function(self, element, time)
			assert(element == text)
			window:remove(element)
		end

		window.anime:add(text, anime_move)
	end,
	damage = function(map, obj, damage, element)
		print("damage", obj.name, damage, element)
		local text = face:new_text(tostring(damage))

		text.color = {}
		for i, c in ipairs(element_color[element]) do
			text.color[i] = c * 0.8
		end
		text.color[4] = 1

		local pos = map.gui:tile(obj.pos)
		pos[2] = pos[2] + map.gui.size / 8
		text.pos = pos

		window:add(text)

		local duration = 0.6
		local target = {
			pos[1],
			pos[2] + map.gui.size / 2,
		}
		local anime_move = gl_misc.animation_list.move(text, target, duration)
		anime_move.done = function(self, element, time)
			assert(element == text)
			window:remove(element)
		end

		window.anime:add(text, anime_move)

	end,
	miss = function(map, obj)
		print("miss", obj.name)
		local text = face:new_text("miss")
		text.color = {0.3, 0.3, 0.3, 1}
		local pos = map.gui:tile(obj.pos)
		pos[2] = pos[2] + map.gui.size / 8
		text.pos = pos

		window:add(text)

		local duration = 0.6
		local target = {
			pos[1],
			pos[2] + map.gui.size / 2,
		}
		local anime_move = gl_misc.animation_list.move(text, target, duration)
		anime_move.done = function(self, element, time)
			assert(element == text)
			window:remove(element)
		end

		window.anime:add(text, anime_move)
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
--[[
	for i, v in ipairs(map_info.teams) do
		-- util.merge_table(v, event_table)
		if type(v.round) == "string" then
			if v.round == "player" then
				v.round = player_control
			elseif v.round == "enemy" then
				v.round = enemy_control
			else
				print("unknown round " .. v.round)
				return true
			end
		end
	end
--]]
	local team_count = #map_info.teams

	window:clear()

	local map = require("core/map")(map_info)
	window.anime:commit()

	local tid = 0
	local round = 1
	local action_list = {{
		cmd = "round_start"
	}}
--[[
	cmd:	quit, round_start, round_end, action

--]]

	return window:run(function(wnd)
		if not wnd.anime:check() then
			return
		end
		if #action_list > 0 then
			window.anime:reset()
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

			window.anime:commit()
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
	local y = gl_misc.coordinate_radix - 2 * face.height
	for i, v in ipairs(map_list) do
		local l = face:new_text(v)
		l.pos = {0, y}
		l.color = {0, 0, 0, 1}
		l.handler = function(self, wnd, ev, info)
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
		print(l.str, y)
		window:add(l)
		y = y - face.height
	end

	return window:run(function(wnd)
		return map_name
	end)
end

local function main_window()
	util.random_setup(rng_source, rng_seed or os.time())
	locale_table = require(locale_folder .. '/' .. locale)

	if not font_path then
		-- find font in resource folder
		local l = platform.ls(resource_folder)
		for k, v in pairs(l) do
			-- TODO check symbolic link
			if string.lower(string.sub(k, -4)) == ".ttc" then
				font_path = resource_folder .. '/' .. k
				break
			end
		end
	end
	face = gl_text.new_face(font_path)

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
