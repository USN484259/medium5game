local gl = require("moongl")
local misc = require("gl/misc")

local vertex_shader = string.format([[
#version 330 core

uniform float ratio;
uniform vec2 offset;
layout(location=0) in vec2 pos;
layout(location=1) in vec4 in_color;
out vec4 color;

void main()
{
	gl_Position = vec4((offset + pos) / %d, 0.0, 1.0) * vec4(ratio, 1.0, 1.0, 1.0);
	color = in_color;
}
]], misc.coordinate_radix)

local fragment_shader = [[
#version 330 core

in vec4 color;
out vec4 out_color;

void main()
{
	out_color = color;
}
]]

local function tile_index(pos)
	local d = pos[1]
	if d == 0 then
		return 0
	end

	return 3 * d * (d - 1) + pos[2] + 1
end

local function tile_pos(pos, size)
	if pos[1] == 0 then
		return {0, 0}
	end
	local sqrt3 = math.sqrt(3)
	local dis = size * pos[1]
	local dir = math.rad((pos[2] // pos[1]) * 60)
	local pin = {
		sqrt3 * dis * math.cos(dir),
		sqrt3 * dis * math.sin(dir),
	}

	dis = size * (pos[2] % pos[1])
	dir = dir + math.rad(120)
	local off = {
		sqrt3 * dis * math.cos(dir),
		sqrt3 * dis * math.sin(dir),
	}

	return {
		pin[1] + off[1],
		pin[2] + off[2],
	}
end

local function make_points(scale, size)
	local points = { {0, 0} }
	local pos = {1, 0}

	while pos[1] <= scale do
		table.insert(points, tile_pos(pos, size))
		pos[2] = pos[2] + 1
		if pos[2] // pos[1] == 6 then
			pos[1] = pos[1] + 1
			pos[2] = 0
		end
	end
	return points
end

local function make_color(base, overlay)
	local data = {}
	table.move(base, 1, 4, 1, data)

	if not overlay or #overlay == 0 then
		for i = 0, 6, 1 do
			table.move(base, 1, 4, #data + 1, data)
		end
		return data
	end

	if #overlay <= 3 or #overlay >= 6 then
		for i = 0, 5, 1 do
			table.move(overlay[1 + i * #overlay // 6], 1, 4, #data + 1, data)
		end
	elseif #overlay == 4 then
		table.move(overlay[1], 1, 4, #data + 1, data)
		table.move(overlay[2], 1, 4, #data + 1, data)
		table.move(base, 1, 4, #data + 1, data)

		table.move(overlay[3], 1, 4, #data + 1, data)
		table.move(overlay[4], 1, 4, #data + 1, data)
		table.move(base, 1, 4, #data + 1, data)

	elseif #overlay == 5 then
		for i = 1, 5, 1 do
			table.move(overlay[i], 1, 4, #data + 1, data)
		end
		table.move(base, 1, 4, #data + 1, data)
	end
	table.move(overlay[1], 1, 4, #data + 1, data)

	return data
end

local prog
local loc_ratio
local loc_offset

local function render(self, t, w, h)
	gl.use_program(prog)
	gl.bind_vertex_array(self.vertex)

	gl.bind_buffer("array", self.color_buffer)
	gl.uniform(loc_ratio, "float", h / w)
	gl.buffer_sub_data("array", 0, gl.pack("float", self.bg_color))


	for i, offset in ipairs(self.points) do
		local overlay = self.overlay[i - 1]

		gl.uniform(loc_offset, "float", table.unpack(offset))
		if overlay then
			local colors = make_color(self.bg_color, overlay)
			gl.buffer_sub_data("array", 0, gl.pack("float", colors))
		end

		gl.draw_arrays("triangle fan", 0, 8)

		if overlay then
			gl.buffer_sub_data("array", 0, gl.pack("float", self.bg_color))
		end

	end

	gl.buffer_sub_data("array", 0, gl.pack("float", self.line_color))

	for i, offset in ipairs(self.points) do
		gl.uniform(loc_offset, "float", table.unpack(offset))
		gl.draw_arrays("line loop", 1, 6)
	end

	gl.unbind_buffer("array")
	gl.unbind_vertex_array()
	gl.use_program(0)
end

local function set(self, pos, color)
	local index = tile_index(pos)
	self.overlay[index] = color
end

local function new_map(scale, size)
	if not prog then
		prog = gl.make_program_s("vertex", vertex_shader, "fragment", fragment_shader)
		loc_ratio = gl.get_uniform_location(prog, "ratio")
		loc_offset = gl.get_uniform_location(prog, "offset")
	end

	local points = {0.0, 0.0}
	for i = 0, 6, 1 do
		local r = math.rad(60 * i - 30)
		local x = size * math.cos(r)
		local y = size * math.sin(r)

		table.move({x, y}, 1, 2, 1 + #points, points)
	end

	local v = gl.new_vertex_array()

	local bp = gl.new_buffer("array")
	gl.buffer_data("array", gl.pack("float", points), "static draw")
	gl.vertex_attrib_pointer(0, 2, "float", false, 0, 0)
	gl.enable_vertex_attrib_array(0)
	gl.unbind_buffer("array")

	local bc = gl.new_buffer("array")
	local bg_color = make_color({0.8, 0.8, 0.8, 1.0})
	gl.buffer_data("array", gl.pack("float", bg_color), "stream draw")
	gl.vertex_attrib_pointer(1, 4, "float", false, 0, 0)
	gl.enable_vertex_attrib_array(1)
	gl.unbind_buffer("array")

	gl.unbind_vertex_array()

	local line_color = make_color({0.0, 0.0, 0.0, 1.0})
	local points = make_points(scale, size)

	return {
		layer = misc.layer.back,
		scale = scale,
		size = size,
		points = points,
		bg_color = bg_color,
		line_color = line_color,
		overlay = {},
		vertex = v,
		color_buffer = bc,
		set = set,
		render = render,
		tile = function(self, pos)
			return tile_pos(pos, self.size)
		end,
	}
end

return {
	new_map = new_map,
}
