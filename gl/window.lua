local gl = require("moongl")
local glfw = require("moonglfw")


local function step(self)
	if glfw.window_should_close(self.window) then
		return false
	end

	glfw.poll_events()
	gl.clear("color")

	local w, h = glfw.get_window_size(self.window)
	local t = glfw.get_time()

	for i, v in ipairs(self.cur_scene) do
		v:render(t, w, h)
	end

	glfw.swap_buffers(self.window)
	return true
end

local function scene(self, new_scene)
	local res = self.cur_scene
	if new_scene then
		self.cur_scene = new_scene
	end

	return res
end

local function on_key(self, func, ...)
	local args = {...}
	glfw.set_key_callback(self.window, function(window, key, scancode, action)
		func(self, key, action, table.unpack(args))
	end)
end

local function on_resize(window, w, h)
	gl.viewport(0, 0, w, h)
end

local function new_window(w, h, title)
	w = w or 800
	h = h or 600
	title = title or "moonglfw"

	glfw.window_hint('context version major', 3)
	glfw.window_hint('context version minor', 3)
	glfw.window_hint('opengl profile', 'core')
	local window = glfw.create_window(w, h, title)
	glfw.make_context_current(window)
	gl.init()
	gl.clear_color(1, 1, 1, 1)

	gl.enable("blend")
	gl.blend_func("src alpha", "one minus src alpha")
	glfw.set_window_size_callback(window, on_resize)

	return {
		window = window,
		step = step,
		scene = scene,
		on_key = on_key,
	}
end

return {
	new_window = new_window,
}
