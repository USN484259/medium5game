local gl = require("moongl")
local img = require("moonimage")

local vertex_shader = [[
#version 330 core

uniform float aspect_ratio;
uniform vec2 scale;
uniform vec2 offset;
layout(location=0) in vec2 pos;
layout(location=1) in vec2 vertex_uv;
out vec2 uv;

void main()
{
	gl_Position = vec4((offset + pos * scale) / 0x1000, 0.0, 1.0) * vec4(aspect_ratio, 1.0, 1.0, 1.0);
	uv = vertex_uv;
}
]]

local fragment_shader = [[
#version 330 core

uniform sampler2D tex;
uniform float alpha;
in vec2 uv;
out vec4 out_color;

void main()
{
	out_color = texture(tex, uv) * vec4(1.0, 1.0, 1.0, alpha);
}
]]

local prog
local vertex_array
local loc_ratio
local loc_scale
local loc_offset
local loc_texture
local loc_alpha

local function render(self, w, h)
	gl.use_program(prog)

	gl.uniform(loc_ratio, "float", h / w)


	local scale = {
		self.scale * self.width / 2,
		self.scale * self.height / 2,
	}
	gl.uniform(loc_scale, "float", table.unpack(scale))

	gl.uniform(loc_offset, "float", table.unpack(self.pos))

	gl.uniform(loc_alpha, "float", self.alpha)

	gl.active_texture(1)
	gl.bind_texture("2d", self.texture)

	gl.uniform(loc_texture, "int", 1)

	gl.bind_vertex_array(vertex_array)
	gl.draw_arrays("triangle strip", 0, 4)

	gl.unbind_vertex_array()
	gl.use_program(0)
end

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

local function new_image(path)
	local t = gl.new_texture("2d")
	-- gl.bind_texture("2d", t)

	local image, w, h = img.load(path, "rgba")

	gl.texture_image("2d", 0, "rgba", "rgba", "ubyte", image, w, h)

	gl.texture_parameter("2d", "base level", 0)
	gl.texture_parameter("2d", "max level", 0)
	gl.texture_parameter('2d', 'wrap s', 'repeat')
	gl.texture_parameter('2d', 'wrap t', 'repeat')
	gl.texture_parameter('2d', 'min filter', 'linear')
	gl.texture_parameter('2d', 'mag filter', 'linear')

	-- gl.generate_mipmap("1d")
	gl.unbind_texture("2d")

	return {
		texture = t,
		width = w,
		height = h,
		pos = {0, 0},
		scale = 1,
		alpha = 1,
		render = render,
	}
end

prog = gl.make_program_s("vertex", vertex_shader, "fragment", fragment_shader)
loc_ratio = gl.get_uniform_location(prog, "aspect_ratio")
loc_scale = gl.get_uniform_location(prog, "scale")
loc_offset = gl.get_uniform_location(prog, "offset")
loc_texture = gl.get_uniform_location(prog, "tex")
loc_alpha = gl.get_uniform_location(prog, "alpha")

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

return {
	new_image = new_image,
}

