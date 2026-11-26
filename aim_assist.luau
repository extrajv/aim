--!optimize 2
const repository = "https://raw.githubusercontent.com/extrajv/aim/refs/heads/main/"
local collection_service = game:GetService("CollectionService")
local replicated_storage = game:GetService("ReplicatedStorage")

local function get(name)
	local success, err = pcall(function()
		return game:HttpGet(repository..name)
	end)
	return success, err
end

local abcurves = (shared.abcurves ~= nil) and shared.abcurves or (function()
	warn("[INIT] ABCurves not loaded, downloading from repository, sit tight")

	local success, err = get('abcurves.luau')
	if success then
		local abcurves = loadstring(success)()

		shared.abcurves = abcurves
		return abcurves
	end

	if not success then
		warn('[FAIL] Failed to fetch abcurves.luau from '..repository..', Error:'..err)
	end
end)()

if not abcurves then
	return false
end

local aim_assist = {}
aim_assist.__index = aim_assist
aim_assist.radians_per_count = abcurves.radians_per_count

local function angles(direction: Vector3): (number, number)
	return math.atan2(-direction.X, -direction.Z), math.atan2(direction.Y, math.sqrt(direction.X ^ 2 + direction.Z ^ 2))
end

function aim_assist.new()
	return setmetatable({
		enabled = false,
		movement = nil,
		start = 0,
		target = nil,
		head = nil,
		humanoid = nil,
		has_target = false,
		target_x = 0,
		target_y = 0,
		trail_x = table.create(180, 0),
		trail_y = table.create(180, 0),
		trail_at = 0,
		trail_count = 0,
		sample_count = 0,
	}, aim_assist)
end

function aim_assist.restart(self)
	local options = { seed = math.random(1, 2147483647), initial_x = 0, initial_y = 0 }
	if self.movement then
		self.movement:reset(options)
	else
		self.movement = abcurves.load(options)
	end
	self.start = os.clock()
	self.has_target = false
	self.trail_at = 0
	self.trail_count = 0
	self.sample_count = 0
end

function aim_assist.set_enabled(self, enabled: boolean)
	self.enabled = enabled
	self.target = nil
	self.head = nil
	self.humanoid = nil
	if enabled then
		self:restart()
	end
end

function aim_assist.pick(self, camera: Camera)
	local origin = camera.CFrame.Position
	local look = camera.CFrame.LookVector
	local best_dot = -2
	self.target = nil
	self.head = nil
	self.humanoid = nil
	for _, target in collection_service:GetTagged("sniper_target") do
		local humanoid = nil
		local head = nil
		if target:IsA("BasePart") then
			head = target
		else
			humanoid = target:FindFirstChildOfClass("Humanoid")
			head = if humanoid and humanoid.Health > 0 then target:FindFirstChild("Head") else nil
		end
		if head and head:IsDescendantOf(workspace) then
			local dot = (head.Position - origin).Unit:Dot(look)
			if dot > best_dot then
				best_dot = dot
				self.target = target
				self.head = head
				self.humanoid = humanoid
			end
		end
	end
end

function aim_assist.step(self, camera: Camera, offset_yaw: number, offset_pitch: number): (number, number)
	local movement = self.movement
	local head = self.head
	local humanoid = self.humanoid
	if not head or not head:IsDescendantOf(workspace) or (humanoid and humanoid.Health <= 0) then
		self:pick(camera)
		head = self.head
	end
	local now_us = math.floor((os.clock() - self.start) * 1e6)
	if head then
		local target_yaw, target_pitch = angles(head.Position - camera.CFrame.Position)
		local yaw, pitch = angles(camera.CFrame.LookVector)
		local error_yaw = (target_yaw - (yaw - offset_yaw) + math.pi) % (2 * math.pi) - math.pi
		local error_pitch = target_pitch - (pitch - offset_pitch)
		local x = -error_yaw / abcurves.radians_per_count
		local y = error_pitch / abcurves.radians_per_count
		local size = math.sqrt(x * x + y * y)
		if size > 2000 then
			x, y = x * 2000 / size, y * 2000 / size
		end
		self.target_x = movement.x + x
		self.target_y = movement.y + y
		movement:update_target(self.target_x, self.target_y, now_us)
	end
	self.has_target = head ~= nil
	local before_x, before_y = movement.x, movement.y
	local ok, count, xs, ys = pcall(movement.advance, movement, now_us)
	if not ok then
		warn(count)
		self:restart()
		return 0, 0
	end
	for sample = 1, count do
		self.sample_count += 1
		if self.sample_count % 4 == 0 then
			self.trail_at = self.trail_at % 180 + 1
			self.trail_count = math.min(self.trail_count + 1, 180)
			self.trail_x[self.trail_at] = xs[sample]
			self.trail_y[self.trail_at] = ys[sample]
		end
	end
	return -(movement.x - before_x) * abcurves.radians_per_count, (movement.y - before_y) * abcurves.radians_per_count
end

return aim_assist
