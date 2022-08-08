local gl = require("moongl")
local img = require("moonimage")
local misc = require("gl/misc")
local motion = require("gl/motion")
local util = require("core/util")

local vertex_shader = string.format([[
#version 330 core

uniform float aspect_ratio;
uniform mat2 rotation;
uniform vec2 scale;
uniform vec2 offset;
layout(location=0) in vec2 pos;
layout(location=1) in vec2 vertex_uv;
out vec2 uv;

void main()
{
	gl_Position = vec4((offset + rotation * (pos * scale)) / %d, 0.0, 1.0) * vec4(aspect_ratio, 1.0, 1.0, 1.0);
	uv = vertex_uv;
}
]], misc.coordinate_radix)

local fragment_shader = [[
#version 330 core

uniform sampler2D tex;
uniform vec4 color;
in vec2 uv;
out vec4 out_color;

void main()
{
	out_color = color * texture(tex, uv);
}
]]

local prog
local vertex_array
local loc_ratio
local loc_rotation
local loc_scale
local loc_offset
local loc_texture
local loc_color

local rc_path = nil
local image_table = {}

local function render(self, aspect_ratio)
	if not self.texture then return end

	gl.use_program(prog)
	gl.uniform(loc_ratio, "float", aspect_ratio)

	local rad = math.rad(self.rotation)
	local rotation = {
		math.cos(rad), -math.sin(rad),
		math.sin(rad), math.cos(rad),
	}
	gl.uniform_matrix(loc_rotation, "float", "2x2", true, table.unpack(rotation))

	local scale = {
		self.scale * self.width / 2,
		self.scale * self.height / 2,
	}
	gl.uniform(loc_scale, "float", table.unpack(scale))

	gl.uniform(loc_offset, "float", table.unpack(self.pos))

	gl.uniform(loc_color, "float", table.unpack(self.color))

	gl.active_texture(1)
	gl.bind_texture("2d", self.texture)

	gl.uniform(loc_texture, "int", 1)

	gl.bind_vertex_array(vertex_array)
	gl.draw_arrays("triangle strip", 0, 4)

	gl.unbind_vertex_array()
	gl.use_program(0)
end

local function bound(self, pos)
	-- FIXME consider rotation
	local left = self.pos[1] - self.scale * self.width / 2
	local right = self.pos[1] + self.scale * self.width / 2

	local top = self.pos[2] + self.scale * self.height / 2
	local bot = self.pos[2] - self.scale * self.height / 2

	return pos[1] > left and pos[1] < right and pos[2] > bot and pos[2] < top
end

local function gl_setup()
	if not prog then
		local points = {
			-1.0, -1.0,
			1.0, -1.0,
			-1.0, 1.0,
			1.0, 1.0,
		}

		local uv = {
			0.0, 1.0,
			1.0, 1.0,
			0.0, 0.0,
			1.0, 0.0,
		}

		prog = gl.make_program_s("vertex", vertex_shader, "fragment", fragment_shader)
		loc_ratio = gl.get_uniform_location(prog, "aspect_ratio")
		loc_rotation = gl.get_uniform_location(prog, "rotation")
		loc_scale = gl.get_uniform_location(prog, "scale")
		loc_offset = gl.get_uniform_location(prog, "offset")
		loc_texture = gl.get_uniform_location(prog, "tex")
		loc_color = gl.get_uniform_location(prog, "color")

		vertex_array = gl.new_vertex_array()

		local bp = gl.new_buffer("array")
		gl.buffer_data("array", gl.pack("float", points), "static draw")
		gl.vertex_attrib_pointer(0, 2, "float", false, 0, 0)
		gl.enable_vertex_attrib_array(0)
		gl.unbind_buffer("array")

		local bv = gl.new_buffer("array")
		gl.buffer_data("array", gl.pack("float", uv), "static draw")
		gl.vertex_attrib_pointer(1, 2, "float", false, 0, 0)
		gl.enable_vertex_attrib_array(1)
		gl.unbind_buffer("array")

		gl.unbind_vertex_array()
	end
end

local function load_image(self, path)
	self.texture = nil
	if not image_table[path] then
		-- gl.bind_texture("2d", t)

		local res, image, w, h = pcall(img.load, rc_path .. path .. ".png", "rgba")
		if not res then
			print("WARNING\tcannot load image " .. path)
			return
		end

		local t = gl.new_texture("2d")
		gl.texture_image("2d", 0, "rgba", "rgba", "ubyte", image, w, h)

		gl.texture_parameter("2d", "base level", 0)
		gl.texture_parameter("2d", "max level", 0)
		gl.texture_parameter('2d', 'wrap s', 'repeat')
		gl.texture_parameter('2d', 'wrap t', 'repeat')
		gl.texture_parameter('2d', 'min filter', 'linear')
		gl.texture_parameter('2d', 'mag filter', 'linear')

		-- gl.generate_mipmap("1d")
		gl.unbind_texture("2d")

		image_table[path] = {
			texture = t,
			width = w,
			height = h,
		}
	end

	util.merge_table(self, image_table[path] or {
		width = 0,
		height = 0,
	})
	self.path = path
end

local function new_image(element)
	gl_setup()

	if element.path then
		load_image(element, element.path)
	end

	return util.merge_table(element, {
		load = load_image,
		render = render,
		bound = bound,
	}, {
		width = 0,
		height = 0,
		pos = {0, 0},
		rotation = 0,
		scale = 1,
		color = {1, 1, 1, 1},
	})
end

local function set_rc_path(path)
	rc_path = path
	if string.sub(path, -1) ~= '/' then
		rc_path = rc_path .. '/'
	end
end

return {
	new = new_image,
	set_rc_path = set_rc_path
}
