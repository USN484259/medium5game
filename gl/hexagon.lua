local gl = require("moongl")
local misc = require("gl/misc")
local motion = require("gl/motion")
local util = require("core/util")

local vertex_shader = string.format([[
#version 330 core

uniform float aspect_ratio;
uniform mat2 rotation;
uniform float scale;
uniform vec2 offset;
layout(location=0) in vec2 pos;
layout(location=1) in vec4 in_color;
out vec4 color;

void main()
{
	gl_Position = vec4((offset + rotation * (pos * scale)) / %d, 0.0, 1.0) * vec4(aspect_ratio, 1.0, 1.0, 1.0);
	color = in_color;
}
]], misc.coordinate_radix)

local fragment_shader = [[
#version 330 core

uniform vec4 color_mask;
in vec4 color;
out vec4 out_color;

void main()
{
	out_color = color_mask * color;
}
]]

local prog
local vertex_array
local color_buffer
local loc_ratio
local loc_rotation
local loc_scale
local loc_offset
local loc_color

local function render(self, aspect_ratio)
	if not (self.fill_color or self.border_color) then
		return
	end

	gl.use_program(prog)
	gl.uniform(loc_ratio, "float", aspect_ratio)

	local rad = math.rad(self.rotation)
	local rotation = {
		math.cos(rad), -math.sin(rad),
		math.sin(rad), math.cos(rad),
	}
	gl.uniform_matrix(loc_rotation, "float", "2x2", true, table.unpack(rotation))

	gl.uniform(loc_scale, "float", self.scale * self.radius)

	gl.uniform(loc_offset, "float", table.unpack(self.pos))

	gl.uniform(loc_color, "float", table.unpack(self.color))

	gl.bind_vertex_array(vertex_array)
	gl.bind_buffer("array", color_buffer)

	if self.fill_color then
		gl.buffer_sub_data("array", 0, gl.pack("float", self.fill_color))
		gl.draw_arrays("triangle fan", 0, 8)
	end

	if self.border_color then
		gl.buffer_sub_data("array", gl.sizeof("float") * 4 * 1, gl.pack("float", self.border_color))
		gl.draw_arrays("line loop", 1, 6)
	end

	gl.unbind_buffer("array")
	gl.unbind_vertex_array()
	gl.use_program(0)
end

local function bound(self, pos)
	local dis_p2 = (pos[1] - self.pos[1]) ^ 2 + (pos[2] - self.pos[2]) ^ 2
	local lim_p2 = self.radius ^ 2 * 3 / 4

	return dis_p2 < lim_p2
end

local function gl_setup()
	if prog then
		return
	end

	local sin60 = math.sqrt(3) / 2
	local points = {
		0.0, 0.0,
		0.0, 1.0,
		-sin60, 0.5,
		-sin60, -0.5,
		0.0, -1.0,
		sin60, -0.5,
		sin60, 0.5,
		0.0, 1.0,
	}

	prog = gl.make_program_s("vertex", vertex_shader, "fragment", fragment_shader)
	loc_ratio = gl.get_uniform_location(prog, "aspect_ratio")
	loc_rotation = gl.get_uniform_location(prog, "rotation")
	loc_scale = gl.get_uniform_location(prog, "scale")
	loc_offset = gl.get_uniform_location(prog, "offset")
	loc_color = gl.get_uniform_location(prog, "color_mask")

	vertex_array = gl.new_vertex_array()

	local bp = gl.new_buffer("array")
	gl.buffer_data("array", gl.pack("float", points), "static draw")
	gl.vertex_attrib_pointer(0, 2, "float", false, 0, 0)
	gl.enable_vertex_attrib_array(0)
	gl.unbind_buffer("array")

	color_buffer = gl.new_buffer("array")
	gl.buffer_data("array", gl.sizeof("float") * 4 * 8, "dynamic draw")
	gl.vertex_attrib_pointer(1, 4, "float", false, 0, 0)
	gl.enable_vertex_attrib_array(1)
	gl.unbind_buffer("array")

	gl.unbind_vertex_array()
end

local function set_color(self, fill, border)
	if fill then
		self.fill_color = {}
		if type(fill[1]) == "table" then
			for i = 1, 7, 1 do
				util.append_table(self.fill_color, fill[i])
			end
			util.append_table(self.fill_color, fill[2])
		else
			for i = 1, 8, 1 do
				util.append_table(self.fill_color, fill)
			end
		end
	else
		self.fill_color = nil
	end

	if border then
		self.border_color = {}
		if type(border[1]) == "table" then
			for i = 1, 6, 1 do
				util.append_table(self.border_color, border[i])
			end
		else
			for i = 1, 6, 1 do
				util.append_table(self.border_color, border)
			end
		end
	else
		self.border_color = nil
	end
end

local function new_hexagon(element)
	gl_setup()

	set_color(element, element.fill_color, element.border_color)

	return util.merge_table(element, {
		set_color = set_color,
		render = render,
		bound = bound,
	}, {
		radius = 0,
		pos = {0, 0},
		rotation = 0,
		scale = 1,
		color = {1, 1, 1, 1},
	})
end

return {
	new = new_hexagon,
}
