#!/usr/bin/env lua

local platform = require("lua_platform")

print("\x1B[38;2;192;192;64maaaaa\x1B[0m")
print("\x1B[38;5;128;1mbbbbbb\x1B[0m")

print(platform.uname())
print(platform.cwd())
local l = platform.ls("maps")
for k, v in pairs(l) do
	print(k, v)
end


local window = require("gl.window").new_window()
local scene = {}

local gl_map = require("gl/map").new_map(4, 100)
local overlay = {
	{1.0, 0.0, 0.0, 0.4},
	{1.0, 1.0, 0.0, 0.4},
	{0.0, 1.0, 0.0, 0.4},
	{0.0, 1.0, 1.0, 0.4},
	{0.0, 0.0, 1.0, 0.4},
	{1.0, 0.0, 1.0, 0.4},
}

gl_map:set({1, 2}, overlay)

table.insert(scene, gl_map)

local function anime_rotation(obj, delta, time)
	return {
		rotation = obj.rotation,
		tick = function(self, obj, t)
			if not self.timestamp then
				self.timestamp = t
				return true
			else
				local dis = math.min(1, (t - self.timestamp) / time)
				obj.rotation = self.rotation + dis * delta
				return t - self.timestamp < time
			end
		end
	}
end

local function anime_translation(obj, delta, time)
	return {
		pos = obj.pos,
		tick = function(self, obj, t)
			if not self.timestamp then
				self.timestamp = t
				return true
			else
				local dis = math.min(1, (t - self.timestamp) / time)
				obj.pos = {
					self.pos[1] + dis * delta[1],
					self.pos[2] + dis * delta[2],
				}
				return t - self.timestamp < time
			end
		end
	}
end

local gl_image = require("gl/image").new_image("resources/chiyu.png")

gl_image.rotation = 60
gl_image.scale = 1
gl_image.alpha = 0.6
gl_image.pos = {800, 500}

table.insert(scene, gl_image)

local function anime_color(obj, delta, time)
	return {
		color = obj.color,
		tick = function(self, obj, t)
			if not self.timestamp then
				self.timestamp = t
				return true
			else
				local dis = math.min(1, (t - self.timestamp) / time)
				obj.color = {
					self.color[1] + dis * delta[1],
					self.color[2] + dis * delta[2],
					self.color[3] + dis * delta[3],
					self.color[4] + dis * delta[4],
				}
				return t - self.timestamp < time

			end
		end
	}
end

local str = "Hello测试World!"

local gl_text = require("gl/text").new_font("resources/wqy-zenhei.ttc", 64):new_text(str)

gl_text.scale = 2
gl_text.color = {1.0, 0.0, 1.0, 1.0}
gl_text.pos = {-1000, -1000}


table.insert(scene, gl_text)

window:scene(scene)

window:on_key(function(wnd, key, action)
	print(key, action)
	if key == "space" and action == "press" then
		gl_image:animation(anime_rotation, 720, 3)
		gl_image:animation(anime_translation, {-3000, -2000}, 3)
		gl_text:animation(anime_color, {0.0, 1.0, -1.0, 0.0}, 3)
		gl_text:animation(anime_translation, {1000, 3000}, 3)
	end
end)

while window:step() do end



--[[
local hexagon = require("hexagon")

local function dump(array)
	for k, v in pairs(array) do
		if type(v) == "table" then
			print(k, '{')
			dump(v)
			print('}')
		else
			print(k, v)
		end
	end
end

dump(hexagon.range({1, 1}, 2))
print("----")
dump(hexagon.fan({3, 3}, 3, 4, 6))
print("----")
dump(hexagon.line({2, 7}, 2, 6))
--]]
