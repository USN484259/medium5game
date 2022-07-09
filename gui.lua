#!/usr/bin/env lua

local version = { 0, 0, 1 }

local locale = "zh-cn"
local font_path = nil
local resource_folder = "resources"
local locale_folder = "locale"
local map_folder = "maps"
local rng_source = "os"
local rng_seed = nil


local platform = require("lua_platform")
local util = require("core/util")
local core = require("core/core")


local gl_window = require("gl/window")
local gl_misc = require("gl/misc")
local gl_map = require("gl/map")
local gl_image = require("gl/image")
local gl_text = require("gl/text")

local locale_table
local face
local window
local map
local anime

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

local function anime_group()
	return {
		list = {},
		add = function(self, element, anime, offset)
			anime.done = function(e)
				self.count = self.count - 1
			end
			table.insert(self.list, {element, anime, offset or 0})
		end,
		commit = function(self)
			local timestamp = gl_window.get_time()
			self.count = #self.list
			for i, v in ipairs(self.list) do
				v[1]:animation(timestamp + v[3], v[2])
			end

			self.list = nil
		end,
		check = function(self)
			return self.count == 0
		end,
	}
end

local event_table = {
	new_map = function(map)
		local size = math.floor(gl_misc.coordinate_radix / (1 + 3 * map.scale / 2))
		local ui = gl_map.new_map(map.scale, size)
		window:add(ui)
		map.gui = ui
	end,
	spawn = function(map, obj)
		local path = "resources/" .. string.sub(obj.name, 1 + string.find(obj.name, '.', 1, true)) .. ".png"
		local ui = gl_image.new_image(path)
		ui.scale = 3 / 2 * map.gui.size / math.max(ui.width, ui.height)
		ui.pos = map.gui:tile(obj.pos)
		window:add(ui)
		obj.gui = ui
	end,
	kill = function(map, obj)
		window:remove(obj.gui)
		-- FIXME close gui object
		obj.gui = nil
	end,
	move = function(map, obj, waypoint)
		local base_time = 1
		local points = {}
		local pos = obj.pos

		for i, d in ipairs(waypoint) do
			pos = hexagon.adjacent(pos, d)
			table.insert(points, map.ui:tile(pos))
		end

		local anime_move = {
			pos = map.gui:tile(obj.pos),
			points = points,
			tick = function(self, obj, t)
				if not self.timestamp then
					self.timestamp = t
				end

				local dis = math.min(1, (t - self.timestamp) / base_time)
				obj.pos = {
					self.pos[1] * (1 - dis) + self.points[0][1] * dis,
					self.pos[2] * (1 - dis) + self.points[0][2] * dis,
				}

				if dis == 1 then
					self.timestamp = t
					self.pos = table.remove(self.points, 1)
				end

				return #self.points ~= 0
			end,
		}
		obj.gui:animation(anime_move)
	end,
}

local function load_map(map_name)
	local chunk, err = loadfile(map_folder .. '/' .. map_name .. ".lua")
	if not chunk then
		print("failed to load map " .. map_name, err)
		return
	end

	local res, map_info = pcall(chunk)
	if not res or type(map_info) ~= "table" then
		print("failed to load map " .. map_name, map_info)
		return
	end

	map_info.event_table = event_table

	for i, v in ipairs(map_info.teams) do
		-- util.merge_table(v, event_table)
		if type(v.round) == "string" then
			if v.round == "player" then
				v.round = player_control
			elseif v.round == "enemy" then
				v.round = enemy_control
			else
				print("unknown round " .. v.round)
				return
			end
		end
	end

	window:clear()

	anime = anime_group()
	map = require("core/map")(map_info)
	anime:commit()

	return true
end

local function main_menu()
	local l = platform.ls(map_folder)
	local map_list = {}
	for k, v in pairs(l) do
		-- TODO check symbolic link
		if string.lower(string.sub(k, -4)) == ".lua" then
			table.insert(map_list, string.sub(k, 1, -5))
		end
	end

	window:clear()
	local y = gl_misc.coordinate_radix - 2 * face.height
	for i, v in ipairs(map_list) do
		local l = face:new_text(v)
		l.pos = {0, y}
		l.color = {0, 0, 0, 1}
		l.handler = function(self, ev, info)
			if ev == "mouse_move" or ev == "mouse_press" then
				if self:bound(info.pos) then
					self.color = {1, 0, 0, 1}
					if ev == "mouse_press" then
						load_map(self.str)
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

	main_menu()

	while window:step() do end
end

return main_window()
