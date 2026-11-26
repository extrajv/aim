--!native
--!optimize 2
local weights = (function()
	local http_service = game:GetService("HttpService")
	local index = http_service:JSONDecode([==[{"bytes":753368,"chunks":6,"arrays":[{"name":"motor.velocity_basis","kind":"f64","offset":0,"shape":[128,21]},{"name":"motor.carry_velocity","kind":"f64","offset":21504,"shape":[128]},{"name":"motor.input.0.weight","kind":"f32","offset":22528,"shape":[96,9]},{"name":"motor.input.0.bias","kind":"f32","offset":25984,"shape":[96]},{"name":"motor.encoder.weight_ih_l0","kind":"f32","offset":26368,"shape":[288,96]},{"name":"motor.encoder.weight_hh_l0","kind":"f32","offset":136960,"shape":[288,96]},{"name":"motor.encoder.bias_ih_l0","kind":"f32","offset":247552,"shape":[288]},{"name":"motor.encoder.bias_hh_l0","kind":"f32","offset":248704,"shape":[288]},{"name":"motor.trunk.0.weight","kind":"f32","offset":249856,"shape":[96,158]},{"name":"motor.trunk.0.bias","kind":"f32","offset":310528,"shape":[96]},{"name":"motor.output.weight","kind":"f32","offset":310912,"shape":[672,96]},{"name":"motor.output.bias","kind":"f32","offset":568960,"shape":[672]},{"name":"motor.selection.unary.0.weight","kind":"f32","offset":571648,"shape":[64,112]},{"name":"motor.selection.unary.0.bias","kind":"f32","offset":600320,"shape":[64]},{"name":"motor.selection.unary.2.weight","kind":"f32","offset":600576,"shape":[1,64]},{"name":"motor.selection.unary.2.bias","kind":"f32","offset":600832,"shape":[1]},{"name":"motor.selection.context.0.weight","kind":"f32","offset":600840,"shape":[16,96]},{"name":"motor.selection.context.0.bias","kind":"f32","offset":606984,"shape":[16]},{"name":"motor.selection.pair.0.weight","kind":"f32","offset":607048,"shape":[32,36]},{"name":"motor.selection.pair.0.bias","kind":"f32","offset":611656,"shape":[32]},{"name":"motor.selection.pair.2.weight","kind":"f32","offset":611784,"shape":[1,32]},{"name":"motor.selection.pair.2.bias","kind":"f32","offset":611912,"shape":[1]},{"name":"events.encoder.0.weight","kind":"f32","offset":611920,"shape":[96,32]},{"name":"events.encoder.0.bias","kind":"f32","offset":624208,"shape":[96]},{"name":"events.encoder.2.weight","kind":"f32","offset":624592,"shape":[96,96]},{"name":"events.encoder.2.bias","kind":"f32","offset":661456,"shape":[96]},{"name":"events.brake.weight","kind":"f32","offset":661840,"shape":[176,96]},{"name":"events.brake.bias","kind":"f32","offset":729424,"shape":[176]},{"name":"events.frequency.weight","kind":"f32","offset":730128,"shape":[16,96]},{"name":"events.frequency.bias","kind":"f32","offset":736272,"shape":[16]},{"name":"events.hazard.0.weight","kind":"f32","offset":736336,"shape":[64,32]},{"name":"events.hazard.0.bias","kind":"f32","offset":744528,"shape":[64]},{"name":"events.hazard.2.weight","kind":"f32","offset":744784,"shape":[32,64]},{"name":"events.hazard.2.bias","kind":"f32","offset":752976,"shape":[32]},{"name":"events.hazard.4.weight","kind":"f32","offset":753104,"shape":[2,32]},{"name":"events.hazard.4.bias","kind":"f32","offset":753360,"shape":[2]}]}]==])

	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local lookup = table.create(256, 0)
	for position = 1, 64 do
		lookup[string.byte(alphabet, position) + 1] = position - 1
	end

	local blob = buffer.create(math.ceil(index.bytes / 3) * 3)
	local cursor = 0
	for chunk_index = 1, index.chunks do
		local text = require(script:FindFirstChild("chunk_" .. chunk_index)) :: string
		local source = buffer.fromstring(text)
		for offset = 0, #text - 4, 4 do
			local packed = lookup[buffer.readu8(source, offset) + 1] * 262144
				+ lookup[buffer.readu8(source, offset + 1) + 1] * 4096
				+ lookup[buffer.readu8(source, offset + 2) + 1] * 64
				+ lookup[buffer.readu8(source, offset + 3) + 1]
			buffer.writeu8(blob, cursor, packed // 65536)
			buffer.writeu8(blob, cursor + 1, (packed // 256) % 256)
			buffer.writeu8(blob, cursor + 2, packed % 256)
			cursor += 3
		end
	end

	local arrays = {}
	for _, entry in index.arrays do
		arrays[entry.name] = entry
	end

	local weights = {}

	function weights.numbers(name: string): { number }
		local entry = arrays[name]
		local count = 1
		for _, extent in entry.shape do
			count *= extent
		end
		local out = table.create(count)
		if entry.kind == "f64" then
			for i = 0, count - 1 do
				out[i + 1] = buffer.readf64(blob, entry.offset + i * 8)
			end
		else
			for i = 0, count - 1 do
				out[i + 1] = buffer.readf32(blob, entry.offset + i * 4)
			end
		end
		return out
	end

	function weights.vector_rows(name: string, first_column: number?, column_count: number?): ({ vector }, number)
		local entry = arrays[name]
		local rows, columns = entry.shape[1], entry.shape[2]
		local first = first_column or 0
		local count = column_count or columns
		local stride = math.ceil(count / 3)
		local out = table.create(rows * stride)
		for row = 0, rows - 1 do
			local base = entry.offset + (row * columns + first) * 4
			for k = 0, stride - 1 do
				local column = k * 3
				local x = buffer.readf32(blob, base + column * 4)
				local y = if column + 1 < count then buffer.readf32(blob, base + (column + 1) * 4) else 0
				local z = if column + 2 < count then buffer.readf32(blob, base + (column + 2) * 4) else 0
				out[row * stride + k + 1] = vector.create(x, y, z)
			end
		end
		return out, stride
	end

	return weights
end)()

local numeric = (function()
	local scratch = buffer.create(4)

	local numeric = {}

	local function fround(value: number): number
		buffer.writef32(scratch, 0, value)
		return buffer.readf32(scratch, 0)
	end

	local function log1p(value: number): number
		local shifted = 1 + value
		if shifted == 1 then
			return value
		end
		return math.log(shifted) * value / (shifted - 1)
	end

	local function asinh(value: number): number
		local magnitude = math.abs(value)
		local squared = magnitude * magnitude
		local result = log1p(magnitude + squared / (1 + math.sqrt(1 + squared)))
		return if value < 0 then -result else result
	end

	numeric.fround = fround
	numeric.log1p = log1p
	numeric.asinh = asinh

	return numeric
end)

local rng = (function()
	local fround = numeric.fround
	local log1p = numeric.log1p

	local rng = {}
	rng.__index = rng

	function rng.new(seed: number)
		local self = setmetatable({}, rng)
		local state = table.create(624)
		local value = seed % 4294967296
		state[1] = value
		for i = 1, 623 do
			local mixed = bit32.bxor(value, bit32.rshift(value, 30))
			local low = mixed % 65536
			local high = mixed // 65536
			value = (1812433253 * low + ((1812433253 * high) % 65536) * 65536 + i) % 4294967296
			state[i + 1] = value
		end
		self.state = state
		self.at = 624
		return self
	end

	function rng.word(self): number
		local state = self.state
		if self.at >= 624 then
			for k = 1, 624 do
				local following = state[if k == 624 then 1 else k + 1]
				local y = bit32.bor(bit32.band(state[k], 0x80000000), bit32.band(following, 0x7fffffff))
				local shifted = state[(k + 396) % 624 + 1]
				local twisted = bit32.bxor(shifted, bit32.rshift(y, 1))
				if y % 2 == 1 then
					twisted = bit32.bxor(twisted, 0x9908b0df)
				end
				state[k] = twisted
			end
			self.at = 0
		end
		self.at += 1
		local y = state[self.at]
		y = bit32.bxor(y, bit32.rshift(y, 11))
		y = bit32.bxor(y, bit32.band(bit32.lshift(y, 7), 0x9d2c5680))
		y = bit32.bxor(y, bit32.band(bit32.lshift(y, 15), 0xefc60000))
		y = bit32.bxor(y, bit32.rshift(y, 18))
		return y
	end

	function rng.uniform(self): number
		return (self:word() % 16777216) / 16777216
	end

	function rng.exponential(self): number
		local high = self:word()
		local low = self:word()
		local uniform = ((high % 2097152) * 4294967296 + low) / 9007199254740992
		return fround(-log1p(-uniform))
	end

	function rng.categorical(self, probabilities: { number }, count: number): number
		local best_index = 0
		local best_score = -math.huge
		for i = 1, count do
			local score = fround(probabilities[i] / self:exponential())
			if score > best_score then
				best_score = score
				best_index = i - 1
			end
		end
		return best_index
	end

	function rng.discard_categorical(self, count: number)
		for _ = 1, count * 2 do
			self:word()
		end
	end

	function rng.softmax(logits: { number }, out: { number })
		local peak = -math.huge
		for i = 1, 16 do
			local value = fround(logits[i])
			if value > peak then
				peak = value
			end
		end
		for i = 1, 16 do
			out[i] = fround(math.exp(fround(fround(logits[i]) - peak)))
		end
		local a = fround(fround(out[1] + out[9]) + fround(out[2] + out[10]))
		local b = fround(fround(out[3] + out[11]) + fround(out[4] + out[12]))
		local c = fround(fround(out[5] + out[13]) + fround(out[6] + out[14]))
		local d = fround(fround(out[7] + out[15]) + fround(out[8] + out[16]))
		local total = fround(fround(a + b) + fround(c + d))
		if total ~= total or total <= 0 or total == math.huge then
			error("invalid categorical probabilities")
		end
		for i = 1, 16 do
			out[i] = fround(out[i] / total)
		end
	end

	return rng
end)()

local neural = (function()
	local fround = numeric.fround
	local dot = vector.dot
	local create = vector.create

	local input_weight = weights.vector_rows("motor.input.0.weight")
	local input_bias = weights.numbers("motor.input.0.bias")
	local input_gates = weights.vector_rows("motor.encoder.weight_ih_l0")
	local input_gate_bias = weights.numbers("motor.encoder.bias_ih_l0")
	local recurrent_weight = weights.vector_rows("motor.encoder.weight_hh_l0")
	local recurrent_bias = weights.numbers("motor.encoder.bias_hh_l0")
	local trunk_weight = weights.vector_rows("motor.trunk.0.weight")
	local trunk_bias = weights.numbers("motor.trunk.0.bias")
	local output_weight = weights.vector_rows("motor.output.weight")
	local output_bias = weights.numbers("motor.output.bias")

	local unary_latent = weights.vector_rows("motor.selection.unary.0.weight", 0, 96)
	local unary_geometry = weights.vector_rows("motor.selection.unary.0.weight", 96, 16)
	local unary_bias = weights.numbers("motor.selection.unary.0.bias")
	local unary_output = weights.numbers("motor.selection.unary.2.weight")
	local unary_output_bias = weights.numbers("motor.selection.unary.2.bias")[1]
	local context_weight = weights.vector_rows("motor.selection.context.0.weight")
	local context_bias = weights.numbers("motor.selection.context.0.bias")
	local pair_geometry = weights.vector_rows("motor.selection.pair.0.weight", 0, 20)
	local pair_context = weights.vector_rows("motor.selection.pair.0.weight", 20, 16)
	local pair_bias = weights.numbers("motor.selection.pair.0.bias")
	local pair_output = weights.numbers("motor.selection.pair.2.weight")
	local pair_output_bias = weights.numbers("motor.selection.pair.2.bias")[1]

	local hazard_first = weights.vector_rows("events.hazard.0.weight")
	local hazard_first_bias = weights.numbers("events.hazard.0.bias")
	local hazard_second = weights.vector_rows("events.hazard.2.weight")
	local hazard_second_bias = weights.numbers("events.hazard.2.bias")
	local hazard_final = weights.vector_rows("events.hazard.4.weight")
	local hazard_final_bias = weights.numbers("events.hazard.4.bias")

	local brake_first = weights.vector_rows("events.encoder.0.weight")
	local brake_first_bias = weights.numbers("events.encoder.0.bias")
	local brake_second = weights.vector_rows("events.encoder.2.weight")
	local brake_second_bias = weights.numbers("events.encoder.2.bias")
	local brake_weight = weights.vector_rows("events.brake.weight")
	local brake_bias = weights.numbers("events.brake.bias")
	local frequency_weight = weights.vector_rows("events.frequency.weight")
	local frequency_bias = weights.numbers("events.frequency.bias")

	local function rows_of(flat: { vector }, count: number): { { vector } }
		local out = table.create(count)
		for row = 1, count do
			out[row] = table.move(flat, (row - 1) * 32 + 1, row * 32, 1, table.create(32))
		end
		return out
	end

	local input_rows = rows_of(input_gates, 288)
	local recurrent_rows = rows_of(recurrent_weight, 288)
	local token_cache = table.create(128, false)

	local token_values = table.create(96, 0)
	local token_vectors = table.create(32, vector.zero)
	local projected = table.create(288, 0)
	local recurrent = table.create(288, 0)
	local combined = table.create(158, 0)
	local combined_vectors = table.create(53, vector.zero)
	local encoded = table.create(96, 0)
	local encoded_vectors = table.create(32, vector.zero)
	local coefficients = table.create(672, 0)

	local shared = table.create(64, 0)
	local geometry_vectors = table.create(6, vector.zero)
	local selection_context = table.create(16, 0)
	local selection_context_vectors = table.create(6, vector.zero)
	local shared_pair = table.create(32, 0)
	local pair_vectors = table.create(7, vector.zero)
	local logits = table.create(16, 0)

	local event_vectors = table.create(11, vector.zero)
	local hazard_hidden = table.create(64, 0)
	local hazard_hidden_vectors = table.create(22, vector.zero)
	local hazard_narrow = table.create(32, 0)
	local hazard_narrow_vectors = table.create(11, vector.zero)
	local hazard_logits = table.create(2, 0)

	local brake_hidden = table.create(96, 0)
	local brake_hidden_vectors = table.create(32, vector.zero)
	local brake_encoded = table.create(96, 0)
	local brake_encoded_vectors = table.create(32, vector.zero)
	local brake_parameters = table.create(176, 0)
	local brake_duration = table.create(16, 0)
	local brake_coefficients = table.create(160, 0)
	local brake_frequency = table.create(16, 0)

	local function tanh_pade(value: number): number
		local x = math.clamp(value, -7, 7)
		local z = x * x
		local numerator = x * (34459425 + z * (4729725 + z * (135135 + z * (990 + z))))
		local denominator = 34459425 + z * (16216200 + z * (945945 + z * (13860 + 45 * z)))
		return math.clamp(numerator / denominator, -1, 1)
	end

	local function sigmoid_pade(value: number): number
		return 0.5 + 0.5 * tanh_pade(0.5 * value)
	end

	local function sigmoid(value: number): number
		local z = math.exp(-math.abs(value))
		return if value >= 0 then 1 / (1 + z) else z / (1 + z)
	end

	local function pack(source: { number }, offset: number, count: number, out: { vector })
		local full = count // 3
		for k = 1, full do
			local at = offset + k * 3
			out[k] = create(source[at - 2], source[at - 1], source[at])
		end
		local rest = count - full * 3
		if rest == 1 then
			out[full + 1] = create(source[offset + count], 0, 0)
		elseif rest == 2 then
			out[full + 1] = create(source[offset + count - 1], source[offset + count], 0)
		end
	end

	local function affine(weight: { vector }, stride: number, rows: number, input: { vector }, bias: { number }, out: { number })
		for row = 0, rows - 1 do
			local base = row * stride
			local sum = bias[row + 1]
			for k = 1, stride do
				sum += dot(weight[base + k], input[k])
			end
			out[row + 1] = sum
		end
	end

	local function swish(values: { number }, count: number)
		for i = 1, count do
			local value = values[i]
			values[i] = value * sigmoid(value)
		end
	end

	local neural = {}

	function neural.new_encoder()
		return { hidden = table.create(96, 0), vectors = table.create(32, vector.zero) }
	end

	function neural.reset_encoder(encoder)
		local hidden, vectors = encoder.hidden, encoder.vectors
		for column = 1, 96 do
			hidden[column] = 0
		end
		for k = 1, 32 do
			vectors[k] = vector.zero
		end
	end

	local function encode_dots(encoder, slot: number, key: number, f1: number, f2: number, f3: number, f4: number, f5: number, f6: number, f7: number, f8: number, f9: number)
		local values = projected
		local known = false
		if slot > 0 then
			local entry = token_cache[slot]
			if not entry then
				entry = { -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, projected = table.create(288, 0) }
				token_cache[slot] = entry
			end
			values = entry.projected
			if entry[1] == key and entry[2] == f1 and entry[3] == f2 and entry[4] == f3 and entry[5] == f4
				and entry[6] == f5 and entry[7] == f6 and entry[8] == f7 and entry[9] == f8 and entry[10] == f9 then
				known = true
			else
				entry[1], entry[2], entry[3], entry[4], entry[5] = key, f1, f2, f3, f4
				entry[6], entry[7], entry[8], entry[9], entry[10] = f5, f6, f7, f8, f9
			end
		end
		if not known then
			local first = create(f1, f2, f3)
			local second = create(f4, f5, f6)
			local third = create(f7, f8, f9)
			for column = 0, 95 do
				local base = column * 3
				local value = input_bias[column + 1]
					+ dot(input_weight[base + 1], first)
					+ dot(input_weight[base + 2], second)
					+ dot(input_weight[base + 3], third)
				token_values[column + 1] = value * sigmoid_pade(value)
			end
			pack(token_values, 0, 96, token_vectors)
			local t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31, t32 = table.unpack(token_vectors, 1, 32)
			for gate = 0, 287 do
				local b = gate * 32
				values[gate + 1] = input_gate_bias[gate + 1] + dot(input_gates[b + 1], t1) + dot(input_gates[b + 2], t2) + dot(input_gates[b + 3], t3) + dot(input_gates[b + 4], t4) + dot(input_gates[b + 5], t5) + dot(input_gates[b + 6], t6) + dot(input_gates[b + 7], t7) + dot(input_gates[b + 8], t8) + dot(input_gates[b + 9], t9) + dot(input_gates[b + 10], t10) + dot(input_gates[b + 11], t11) + dot(input_gates[b + 12], t12) + dot(input_gates[b + 13], t13) + dot(input_gates[b + 14], t14) + dot(input_gates[b + 15], t15) + dot(input_gates[b + 16], t16) + dot(input_gates[b + 17], t17) + dot(input_gates[b + 18], t18) + dot(input_gates[b + 19], t19) + dot(input_gates[b + 20], t20) + dot(input_gates[b + 21], t21) + dot(input_gates[b + 22], t22) + dot(input_gates[b + 23], t23) + dot(input_gates[b + 24], t24) + dot(input_gates[b + 25], t25) + dot(input_gates[b + 26], t26) + dot(input_gates[b + 27], t27) + dot(input_gates[b + 28], t28) + dot(input_gates[b + 29], t29) + dot(input_gates[b + 30], t30) + dot(input_gates[b + 31], t31) + dot(input_gates[b + 32], t32)
			end
		end
		local hidden, vectors = encoder.hidden, encoder.vectors
		local h1, h2, h3, h4, h5, h6, h7, h8, h9, h10, h11, h12, h13, h14, h15, h16, h17, h18, h19, h20, h21, h22, h23, h24, h25, h26, h27, h28, h29, h30, h31, h32 = table.unpack(vectors, 1, 32)
		for gate = 0, 287 do
			local b = gate * 32
			recurrent[gate + 1] = recurrent_bias[gate + 1] + dot(recurrent_weight[b + 1], h1) + dot(recurrent_weight[b + 2], h2) + dot(recurrent_weight[b + 3], h3) + dot(recurrent_weight[b + 4], h4) + dot(recurrent_weight[b + 5], h5) + dot(recurrent_weight[b + 6], h6) + dot(recurrent_weight[b + 7], h7) + dot(recurrent_weight[b + 8], h8) + dot(recurrent_weight[b + 9], h9) + dot(recurrent_weight[b + 10], h10) + dot(recurrent_weight[b + 11], h11) + dot(recurrent_weight[b + 12], h12) + dot(recurrent_weight[b + 13], h13) + dot(recurrent_weight[b + 14], h14) + dot(recurrent_weight[b + 15], h15) + dot(recurrent_weight[b + 16], h16) + dot(recurrent_weight[b + 17], h17) + dot(recurrent_weight[b + 18], h18) + dot(recurrent_weight[b + 19], h19) + dot(recurrent_weight[b + 20], h20) + dot(recurrent_weight[b + 21], h21) + dot(recurrent_weight[b + 22], h22) + dot(recurrent_weight[b + 23], h23) + dot(recurrent_weight[b + 24], h24) + dot(recurrent_weight[b + 25], h25) + dot(recurrent_weight[b + 26], h26) + dot(recurrent_weight[b + 27], h27) + dot(recurrent_weight[b + 28], h28) + dot(recurrent_weight[b + 29], h29) + dot(recurrent_weight[b + 30], h30) + dot(recurrent_weight[b + 31], h31) + dot(recurrent_weight[b + 32], h32)
		end
		for column = 1, 96 do
			local reset = sigmoid_pade(values[column] + recurrent[column])
			local update = sigmoid_pade(values[96 + column] + recurrent[96 + column])
			local candidate = tanh_pade(values[192 + column] + reset * recurrent[192 + column])
			hidden[column] = candidate + (hidden[column] - candidate) * update
		end
		pack(hidden, 0, 96, vectors)
	end

	local function encode_rows(encoder, slot: number, key: number, f1: number, f2: number, f3: number, f4: number, f5: number, f6: number, f7: number, f8: number, f9: number)
		local values = projected
		local known = false
		if slot > 0 then
			local entry = token_cache[slot]
			if not entry then
				entry = { -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, projected = table.create(288, 0) }
				token_cache[slot] = entry
			end
			values = entry.projected
			if entry[1] == key and entry[2] == f1 and entry[3] == f2 and entry[4] == f3 and entry[5] == f4
				and entry[6] == f5 and entry[7] == f6 and entry[8] == f7 and entry[9] == f8 and entry[10] == f9 then
				known = true
			else
				entry[1], entry[2], entry[3], entry[4], entry[5] = key, f1, f2, f3, f4
				entry[6], entry[7], entry[8], entry[9], entry[10] = f5, f6, f7, f8, f9
			end
		end
		if not known then
			local first = create(f1, f2, f3)
			local second = create(f4, f5, f6)
			local third = create(f7, f8, f9)
			for column = 0, 95 do
				local base = column * 3
				local value = input_bias[column + 1]
					+ dot(input_weight[base + 1], first)
					+ dot(input_weight[base + 2], second)
					+ dot(input_weight[base + 3], third)
				token_values[column + 1] = value * sigmoid_pade(value)
			end
			pack(token_values, 0, 96, token_vectors)
			local t1, t2, t3, t4, t5, t6, t7, t8, t9, t10, t11, t12, t13, t14, t15, t16, t17, t18, t19, t20, t21, t22, t23, t24, t25, t26, t27, t28, t29, t30, t31, t32 = table.unpack(token_vectors, 1, 32)
			for gate = 0, 287 do
				local row = input_rows[gate + 1]
				local sum = row[1] * t1 + row[2] * t2 + row[3] * t3 + row[4] * t4 + row[5] * t5 + row[6] * t6 + row[7] * t7 + row[8] * t8 + row[9] * t9 + row[10] * t10 + row[11] * t11 + row[12] * t12 + row[13] * t13 + row[14] * t14 + row[15] * t15 + row[16] * t16 + row[17] * t17 + row[18] * t18 + row[19] * t19 + row[20] * t20 + row[21] * t21 + row[22] * t22 + row[23] * t23 + row[24] * t24 + row[25] * t25 + row[26] * t26 + row[27] * t27 + row[28] * t28 + row[29] * t29 + row[30] * t30 + row[31] * t31 + row[32] * t32
				values[gate + 1] = input_gate_bias[gate + 1] + (sum.x + sum.y + sum.z)
			end
		end
		local hidden, vectors = encoder.hidden, encoder.vectors
		local h1, h2, h3, h4, h5, h6, h7, h8, h9, h10, h11, h12, h13, h14, h15, h16, h17, h18, h19, h20, h21, h22, h23, h24, h25, h26, h27, h28, h29, h30, h31, h32 = table.unpack(vectors, 1, 32)
		for gate = 0, 287 do
			local row = recurrent_rows[gate + 1]
			local sum = row[1] * h1 + row[2] * h2 + row[3] * h3 + row[4] * h4 + row[5] * h5 + row[6] * h6 + row[7] * h7 + row[8] * h8 + row[9] * h9 + row[10] * h10 + row[11] * h11 + row[12] * h12 + row[13] * h13 + row[14] * h14 + row[15] * h15 + row[16] * h16 + row[17] * h17 + row[18] * h18 + row[19] * h19 + row[20] * h20 + row[21] * h21 + row[22] * h22 + row[23] * h23 + row[24] * h24 + row[25] * h25 + row[26] * h26 + row[27] * h27 + row[28] * h28 + row[29] * h29 + row[30] * h30 + row[31] * h31 + row[32] * h32
			recurrent[gate + 1] = recurrent_bias[gate + 1] + (sum.x + sum.y + sum.z)
		end
		for column = 1, 96 do
			local reset = sigmoid_pade(values[column] + recurrent[column])
			local update = sigmoid_pade(values[96 + column] + recurrent[96 + column])
			local candidate = tanh_pade(values[192 + column] + reset * recurrent[192 + column])
			hidden[column] = candidate + (hidden[column] - candidate) * update
		end
		pack(hidden, 0, 96, vectors)
	end

	local function fastest_encoder(): string
		local encoder = neural.new_encoder()
		local best_kind, best_time = "dots", math.huge
		for _ = 1, 4 do
			for kind, encode in neural.encoders do
				local started = os.clock()
				encode(encoder, 0, 0, 0.1, -0.2, 0.3, -0.4, 0.05, -0.05, 1, 1, 1)
				encode(encoder, 0, 0, -0.3, 0.1, -0.2, 0.6, -0.02, 0.04, 1, 1, 0.25)
				local elapsed = os.clock() - started
				if elapsed < best_time then
					best_kind, best_time = kind, elapsed
				end
			end
		end
		return best_kind
	end

	neural.encoders = { dots = encode_dots, rows = encode_rows }
	neural.encoder_kind = fastest_encoder()
	neural.encode_token = neural.encoders[neural.encoder_kind]

	function neural.finish(encoder, fine: { number }, dynamics: { number })
		table.move(encoder.hidden, 1, 96, 1, combined)
		table.move(fine, 1, 54, 97, combined)
		table.move(dynamics, 1, 8, 151, combined)
		pack(combined, 0, 158, combined_vectors)
		affine(trunk_weight, 53, 96, combined_vectors, trunk_bias, encoded)
		for column = 1, 96 do
			local value = encoded[column]
			encoded[column] = fround(value * sigmoid_pade(value))
		end
		pack(encoded, 0, 96, encoded_vectors)
		affine(output_weight, 32, 672, encoded_vectors, output_bias, coefficients)
		for column = 1, 672 do
			coefficients[column] = fround(coefficients[column])
		end
		return encoded, coefficients
	end

	local scratch_encoder = neural.new_encoder()

	function neural.motor(coarse: { number }, fine: { number }, dynamics: { number })
		neural.reset_encoder(scratch_encoder)
		for row = 0, 69 do
			local at = row * 9
			neural.encode_token(
				scratch_encoder,
				0, 0,
				coarse[at + 1], coarse[at + 2], coarse[at + 3],
				coarse[at + 4], coarse[at + 5], coarse[at + 6],
				coarse[at + 7], coarse[at + 8], coarse[at + 9]
			)
		end
		return neural.finish(scratch_encoder, fine, dynamics)
	end

	function neural.choice(latent: { number }, geometry: { number }, pairs: { number }, previous_valid: boolean)
		pack(latent, 0, 96, encoded_vectors)
		affine(unary_latent, 32, 64, encoded_vectors, unary_bias, shared)
		for head = 0, 15 do
			pack(geometry, head * 16, 16, geometry_vectors)
			local logit = unary_output_bias
			for column = 0, 63 do
				local base = column * 6
				local value = shared[column + 1]
				for k = 1, 6 do
					value += dot(unary_geometry[base + k], geometry_vectors[k])
				end
				logit += value * sigmoid(value) * unary_output[column + 1]
			end
			logits[head + 1] = logit
		end
		if previous_valid then
			affine(context_weight, 32, 16, encoded_vectors, context_bias, selection_context)
			swish(selection_context, 16)
			pack(selection_context, 0, 16, selection_context_vectors)
			affine(pair_context, 6, 32, selection_context_vectors, pair_bias, shared_pair)
			for head = 0, 15 do
				pack(pairs, head * 20, 20, pair_vectors)
				local transition = pair_output_bias
				for column = 0, 31 do
					local base = column * 7
					local value = shared_pair[column + 1]
					for k = 1, 7 do
						value += dot(pair_geometry[base + k], pair_vectors[k])
					end
					transition += value * sigmoid(value) * pair_output[column + 1]
				end
				logits[head + 1] += transition
			end
		end
		return logits
	end

	function neural.hazard(context: { number })
		pack(context, 0, 32, event_vectors)
		affine(hazard_first, 11, 64, event_vectors, hazard_first_bias, hazard_hidden)
		swish(hazard_hidden, 64)
		pack(hazard_hidden, 0, 64, hazard_hidden_vectors)
		affine(hazard_second, 22, 32, hazard_hidden_vectors, hazard_second_bias, hazard_narrow)
		swish(hazard_narrow, 32)
		pack(hazard_narrow, 0, 32, hazard_narrow_vectors)
		affine(hazard_final, 11, 2, hazard_narrow_vectors, hazard_final_bias, hazard_logits)
		return hazard_logits
	end

	function neural.brake(context: { number })
		pack(context, 0, 32, event_vectors)
		affine(brake_first, 11, 96, event_vectors, brake_first_bias, brake_hidden)
		swish(brake_hidden, 96)
		pack(brake_hidden, 0, 96, brake_hidden_vectors)
		affine(brake_second, 32, 96, brake_hidden_vectors, brake_second_bias, brake_encoded)
		swish(brake_encoded, 96)
		pack(brake_encoded, 0, 96, brake_encoded_vectors)
		affine(brake_weight, 32, 176, brake_encoded_vectors, brake_bias, brake_parameters)
		for head = 0, 15 do
			local at = head * 11
			local log_duration = math.clamp(fround(brake_parameters[at + 1]), 1.3862943611198906, 5.2574953720277815)
			brake_duration[head + 1] = fround(math.exp(fround(log_duration)))
			for column = 1, 10 do
				brake_coefficients[head * 10 + column] = fround(64 * fround(brake_parameters[at + column + 1]))
			end
		end
		affine(frequency_weight, 32, 16, brake_encoded_vectors, frequency_bias, brake_frequency)
		return brake_duration, brake_coefficients, brake_frequency
	end

	return neural
end)()

local kernels = (function()
	local fround = numeric.fround
	local asinh = numeric.asinh

	local velocity_scale = 1.1982087601807259
	local position_scale = 81.73350722609987
	local event_scales = { 10, 0.1, 0.1, 0.1, 1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.01, 10, 128, 1, 1, 1, 128, 10, 10, 0.1, 1, 10 }

	local velocity_basis = weights.numbers("motor.velocity_basis")
	local carry_velocity = weights.numbers("motor.carry_velocity")

	local mean_basis = table.create(16 * 21, 0)
	local mean_carry = table.create(16, 0)
	for group = 0, 15 do
		for column = 1, 21 do
			local sum = 0
			for row = 0, 3 do
				sum += velocity_basis[(group * 4 + row) * 21 + column]
			end
			mean_basis[group * 21 + column] = sum / 4
		end
		local sum = 0
		for row = 1, 4 do
			sum += carry_velocity[group * 4 + row]
		end
		mean_carry[group + 1] = sum / 4
	end

	local known = table.create(640, false)
	local fine = table.create(54, 0)
	local dynamics = table.create(8, 0)
	local heads = table.create(16 * 32, 0)
	local geometry = table.create(16 * 16, 0)
	local pairs_input = table.create(16 * 20, 0)
	local raw = table.create(22, 0)
	local context = table.create(32, 0)
	local action_x = table.create(32, 0)
	local action_y = table.create(32, 0)

	local kernels = {}

	function kernels.new_preparation()
		return {
			encoder = neural.new_encoder(),
			hx = table.create(640, 0),
			hy = table.create(640, 0),
			motion = table.create(640, false),
			ready = false,
			time_us = 0,
			px = 0,
			py = 0,
			total_x = 0,
			total_y = 0,
			cumulative_x = 0,
			cumulative_y = 0,
			tokens = 0,
		}
	end

	function kernels.begin_tokens(preparation, hx, hy, motion_known, px: number, py: number, cut_us: number)
		local total_x, total_y = 0, 0
		for i = 1, 640 do
			if motion_known[i] then
				total_x += hx[i]
				total_y += hy[i]
			end
		end
		preparation.time_us = cut_us
		preparation.px = px
		preparation.py = py
		preparation.total_x = total_x
		preparation.total_y = total_y
		preparation.cumulative_x = 0
		preparation.cumulative_y = 0
		preparation.tokens = 0
		preparation.ready = true
		neural.reset_encoder(preparation.encoder)
	end

	function kernels.advance_tokens(preparation, hx, hy, motion_known, tx, ty, available, valid, offset: number, last_slot: number, limit: number)
		local encoder = preparation.encoder
		local cut_us = preparation.time_us
		local px, py = preparation.px, preparation.py
		local total_x, total_y = preparation.total_x, preparation.total_y
		local cumulative_x, cumulative_y = preparation.cumulative_x, preparation.cumulative_y
		local token = preparation.tokens
		local done = 0
		while token < 70 and done < limit do
			local width = if token < 30 then 16 else 4
			local start = if token < 30 then token * 16 else 480 + (token - 30) * 4
			local finish = start + width
			if finish > last_slot then
				break
			end
			local sum_x, sum_y, count = 0, 0, 0
			for j = start + 1, finish do
				if motion_known[j] then
					sum_x += hx[j]
					sum_y += hy[j]
					cumulative_x += hx[j]
					cumulative_y += hy[j]
					count += 1
				end
			end
			local at = (offset + finish - 1) % 640 + 1
			local here = valid[at] and available[at] <= cut_us + (finish - 640) * 1000
			local relative_x, relative_y, drift_x, drift_y = 0, 0, 0, 0
			if here and motion_known[finish] then
				relative_x = fround(asinh((tx[at] - (px + cumulative_x - total_x)) / position_scale))
				relative_y = fround(asinh((ty[at] - (py + cumulative_y - total_y)) / position_scale))
			end
			if finish > 32 and here then
				local before = (offset + finish - 33) % 640 + 1
				if valid[before] and available[before] <= cut_us + (finish - 672) * 1000 then
					drift_x = fround((tx[at] - tx[before]) / 32 / velocity_scale)
					drift_y = fround((ty[at] - ty[before]) / 32 / velocity_scale)
				end
			end
			local finish_ms = cut_us // 1000 - 640 + finish
			neural.encode_token(
				encoder,
				if token < 30 then finish_ms // 16 % 64 + 1 else finish_ms // 4 % 64 + 65,
				finish_ms,
				fround(sum_x / width / velocity_scale),
				fround(sum_y / width / velocity_scale),
				relative_x,
				relative_y,
				drift_x,
				drift_y,
				if here then 1 else 0,
				fround(count / width),
				if token < 30 then 1 else 0.25
			)
			token += 1
			done += 1
		end
		preparation.tokens = token
		preparation.cumulative_x = cumulative_x
		preparation.cumulative_y = cumulative_y
	end

	function kernels.fine_features(hx, hy, tx, ty, available, valid, motion_known, px: number, py: number, cut_us: number)
		local coverage = 0
		for i = 1, 640 do
			if motion_known[i] then
				coverage += 1
			end
		end
		for i = 0, 15 do
			local slot = 625 + i
			if motion_known[slot] then
				fine[i * 2 + 1] = fround(hx[slot] / velocity_scale)
				fine[i * 2 + 2] = fround(hy[slot] / velocity_scale)
				fine[33 + i] = 1
			else
				fine[i * 2 + 1] = 0
				fine[i * 2 + 2] = 0
				fine[33 + i] = 0
			end
		end
		local latest = valid[640] and available[640] <= cut_us
		local paired = latest and valid[608] and available[608] <= cut_us - 32000
		if latest then
			fine[49] = fround(asinh((tx[640] - px) / position_scale))
			fine[50] = fround(asinh((ty[640] - py) / position_scale))
		else
			fine[49] = 0
			fine[50] = 0
		end
		if paired then
			fine[51] = fround((tx[640] - tx[608]) / 32 / velocity_scale)
			fine[52] = fround((ty[640] - ty[608]) / 32 / velocity_scale)
		else
			fine[51] = 0
			fine[52] = 0
		end
		fine[53] = if latest then 1 else 0
		fine[54] = fround(coverage / 640)

		local steady = true
		for i = 41, 48 do
			steady = steady and fine[i] > 0.5
		end
		local single_scale = fround(velocity_scale)
		for axis = 0, 1 do
			local recent, earlier = 0, 0
			for i = 0, 3 do
				recent = fround(recent + fine[(12 + i) * 2 + axis + 1])
				earlier = fround(earlier + fine[(8 + i) * 2 + axis + 1])
			end
			local acceleration = fround(fround(recent / 4) - fround(earlier / 4))
			acceleration = fround(fround(acceleration * single_scale) / 4)
			dynamics[axis + 1] = fine[31 + axis]
			dynamics[axis + 3] = if steady then fround(acceleration / 0.25) else 0
		end
		local error_x = math.sinh(fine[49]) * position_scale
		local error_y = math.sinh(fine[50]) * position_scale
		local magnitude = math.sqrt(error_x * error_x + error_y * error_y + 100)
		local direction_x = if fine[53] > 0.5 then fround(error_x / magnitude) else 0
		local direction_y = if fine[53] > 0.5 then fround(error_y / magnitude) else 0
		local relative_x = fround(fine[31] - fine[51])
		local relative_y = fround(fine[32] - fine[52])
		local acceleration_x, acceleration_y = dynamics[3], dynamics[4]
		dynamics[5] = fround(fround(relative_x * direction_x) + fround(relative_y * direction_y))
		dynamics[6] = fround(fround(relative_x * -direction_y) + fround(relative_y * direction_x))
		dynamics[7] = fround(fround(acceleration_x * direction_x) + fround(acceleration_y * direction_y))
		dynamics[8] = fround(fround(acceleration_x * -direction_y) + fround(acceleration_y * direction_x))
		return fine, dynamics
	end

	function kernels.decode_geometry(coefficients: { number }, incoming_x: number, incoming_y: number)
		for head = 0, 15 do
			local q = head * 42
			for step = 0, 15 do
				local base = step * 21
				local x, y = 0, 0
				for j = 1, 21 do
					local weight = mean_basis[base + j]
					x += weight * coefficients[q + j * 2 - 1]
					y += weight * coefficients[q + j * 2]
				end
				local carry = mean_carry[step + 1]
				local at = head * 32 + step * 2
				heads[at + 1] = fround(x + carry * incoming_x)
				heads[at + 2] = fround(y + carry * incoming_y)
			end
		end
		return heads
	end

	function kernels.decode_selected(coefficients: { number }, chosen: number, incoming_x: number, incoming_y: number)
		local q = chosen * 42
		for step = 0, 31 do
			local base = step * 21
			local x, y = 0, 0
			for j = 1, 21 do
				local weight = velocity_basis[base + j]
				x += weight * coefficients[q + j * 2 - 1]
				y += weight * coefficients[q + j * 2]
			end
			local carry = carry_velocity[step + 1]
			action_x[step + 1] = x + carry * incoming_x
			action_y[step + 1] = y + carry * incoming_y
		end
		return action_x, action_y
	end

	function kernels.selector_inputs(previous: { number }?, actual_x: number, actual_y: number)
		local sum_x, sum_y, prefix_x, prefix_y = 0, 0, 0, 0
		local step_x, step_y = fround(actual_x), fround(actual_y)
		if previous then
			for i = 0, 15 do
				sum_x = fround(sum_x + previous[i * 2 + 1])
				sum_y = fround(sum_y + previous[i * 2 + 2])
				if i < 8 then
					prefix_x = fround(prefix_x + previous[i * 2 + 1])
					prefix_y = fround(prefix_y + previous[i * 2 + 2])
				end
			end
		end
		for head = 0, 15 do
			local source = head * 32
			local total_x, total_y = 0, 0
			for i = 1, 16 do
				local value = heads[source + i]
				geometry[head * 16 + i] = fround(asinh(value))
				if previous then
					pairs_input[head * 20 + i] = fround(asinh(fround(previous[16 + i] - value)))
					if i % 2 == 1 then
						total_x = fround(total_x + value)
					else
						total_y = fround(total_y + value)
					end
				end
			end
			if previous then
				local at = head * 20
				local endpoint_x = fround(fround(fround(fround(sum_x * 4) - step_x) - fround(total_x * 4)) / 32)
				local endpoint_y = fround(fround(fround(fround(sum_y * 4) - step_y) - fround(total_y * 4)) / 32)
				local feedback_x = fround(fround(fround(prefix_x * 4) - step_x) / 32)
				local feedback_y = fround(fround(fround(prefix_y * 4) - step_y) / 32)
				pairs_input[at + 17] = fround(asinh(endpoint_x))
				pairs_input[at + 18] = fround(asinh(endpoint_y))
				pairs_input[at + 19] = fround(asinh(feedback_x))
				pairs_input[at + 20] = fround(asinh(feedback_y))
			end
		end
		return geometry, pairs_input
	end

	local function mean(values: { number }, first: number, last: number): number
		local sum = 0
		for i = first, last do
			sum += values[i]
		end
		return sum / (last - first + 1)
	end

	local function norm(x: number, y: number): number
		return math.sqrt(x * x + y * y)
	end

	function kernels.event_features(
		hx, hy, tx, ty, available, valid, motion_known,
		px: number, py: number, cut_us: number,
		hold_age: number, hold_goal_x: number, hold_goal_y: number,
		hold_position_x: number, hold_position_y: number,
		initial_error: number, innovation_age: number, mode: number
	)
		local motion_count = 0
		for i = 1, 640 do
			known[i] = valid[i] and available[i] <= cut_us + (i - 640) * 1000
			if motion_known[i] then
				motion_count += 1
			end
		end
		local latest = known[640]
		local goal_x = if latest then tx[640] else px
		local goal_y = if latest then ty[640] else py
		local error_x, error_y = goal_x - px, goal_y - py
		local distance = norm(error_x, error_y)
		local axis_x, axis_y = error_x / math.max(distance, 1e-8), error_y / math.max(distance, 1e-8)
		local v1x, v1y = hx[640], hy[640]
		local v8x, v8y = mean(hx, 633, 640), mean(hy, 633, 640)
		local v32x, v32y = mean(hx, 609, 640), mean(hy, 609, 640)
		local acceleration_x = (v8x - mean(hx, 625, 632)) / 8
		local acceleration_y = (v8y - mean(hy, 625, 632)) / 8
		local s1, s8, s32 = norm(v1x, v1y), norm(v8x, v8y), norm(v32x, v32y)

		local tv8x, tv8y, tv32x, tv32y, tv128x, tv128y = 0, 0, 0, 0, 0, 0
		if latest and known[632] then
			tv8x, tv8y = (goal_x - tx[632]) / 8, (goal_y - ty[632]) / 8
		end
		if latest and known[608] then
			tv32x, tv32y = (goal_x - tx[608]) / 32, (goal_y - ty[608]) / 32
		end
		if latest and known[512] then
			tv128x, tv128y = (goal_x - tx[512]) / 128, (goal_y - ty[512]) / 128
		end
		local ts8, ts32, ts128 = norm(tv8x, tv8y), norm(tv32x, tv32y), norm(tv128x, tv128y)

		local growth = 0
		if latest and known[608] then
			local old_distance = norm(tx[608] - (px - v32x * 32), ty[608] - (py - v32y * 32))
			growth = (distance - old_distance) / 32
		end
		local last_change = -1
		local excursion = 0
		local target_count = 0
		for i = 513, 640 do
			local offset = norm(tx[i] - goal_x, ty[i] - goal_y)
			if offset > 1e-8 or not known[i] then
				last_change = i - 513
			end
			if known[i] then
				excursion = math.max(excursion, offset)
				target_count += 1
			end
		end

		local holding = mode ~= 0
		raw[1] = fround(distance)
		raw[2] = fround(s1)
		raw[3] = fround(s8)
		raw[4] = fround(s32)
		raw[5] = fround(s8 / math.max(s32, 0.005))
		raw[6] = fround(ts32)
		raw[7] = fround(ts128)
		raw[8] = fround(v8x * axis_x + v8y * axis_y)
		raw[9] = fround(math.abs(v8x * axis_y - v8y * axis_x))
		raw[10] = fround(growth)
		raw[11] = fround(-(acceleration_x * v8x + acceleration_y * v8y) / math.max(s8, 0.005))
		raw[12] = fround(excursion)
		raw[13] = 127 - last_change
		raw[14] = fround(target_count / 128)
		raw[15] = if latest then 1 else 0
		raw[16] = fround(motion_count / 640)
		raw[17] = fround(math.min(hold_age, 4096))
		raw[18] = if holding then fround(norm(goal_x - hold_goal_x, goal_y - hold_goal_y)) else 0
		raw[19] = if holding then fround(norm(px - hold_position_x, py - hold_position_y)) else 0
		raw[20] = fround(ts8)
		raw[21] = fround((v8x * tv32x + v8y * tv32y) / math.max(s8 * ts32, 1e-8))
		raw[22] = if holding then fround(initial_error) else 0

		if distance > 1e-6 then
			axis_x, axis_y = error_x / math.max(distance, 1e-9), error_y / math.max(distance, 1e-9)
		elseif s8 > 1e-6 then
			axis_x, axis_y = v8x / math.max(s8, 1e-9), v8y / math.max(s8, 1e-9)
		else
			axis_x, axis_y = 1, 0
		end

		for j = 1, 22 do
			local value = if j == 17 then math.min(raw[j], 256) else raw[j]
			context[j] = fround(asinh(value / event_scales[j]))
		end
		context[23] = fround(asinh(v1x * axis_x + v1y * axis_y))
		context[24] = fround(asinh(-v1x * axis_y + v1y * axis_x))
		context[25] = fround(asinh((acceleration_x * axis_x + acceleration_y * axis_y) * 8))
		context[26] = fround(asinh((-acceleration_x * axis_y + acceleration_y * axis_x) * 8))
		context[27] = fround(asinh(tv32x * axis_x + tv32y * axis_y))
		context[28] = fround(asinh(-tv32x * axis_y + tv32y * axis_x))
		context[29] = fround(asinh(tv128x * axis_x + tv128y * axis_y))
		context[30] = fround(asinh(-tv128x * axis_y + tv128y * axis_x))
		context[31] = fround(asinh(-v8x * axis_y + v8y * axis_x))
		context[32] = fround(asinh(math.min(2048, innovation_age) / 128))
		return raw, context, axis_x, axis_y
	end

	local function curve_point(s: number, vx: number, vy: number, ax: number, ay: number, duration: number, coefficients: { number })
		local z = 2 * s - 1
		local envelope = 64 * s ^ 3 * (1 - s) ^ 3
		local carry = (s - 6 * s ^ 3 + 8 * s ^ 4 - 3 * s ^ 5) * duration
		local push = 0.5 * s * s * (1 - s) ^ 3 * duration ^ 2
		local goal = 10 * s ^ 3 - 15 * s ^ 4 + 6 * s ^ 5
		local r1 = envelope * z
		local r2 = envelope * (3 * z * z - 1) / 2
		local r3 = envelope * (5 * z * z * z - 3 * z) / 2
		local x = carry * vx + push * ax + goal * coefficients[1]
			+ (envelope * coefficients[3] + r1 * coefficients[5] + r2 * coefficients[7] + r3 * coefficients[9])
		local y = carry * vy + push * ay + goal * coefficients[2]
			+ (envelope * coefficients[4] + r1 * coefficients[6] + r2 * coefficients[8] + r3 * coefficients[10])
		return x, y
	end

	function kernels.brake_actions(vx: number, vy: number, ax: number, ay: number, duration: number, coefficients: { number }, age: number)
		local previous_x, previous_y = curve_point(math.clamp(age / duration, 0, 1), vx, vy, ax, ay, duration, coefficients)
		for step = 1, 32 do
			local x, y = curve_point(math.clamp((age + step) / duration, 0, 1), vx, vy, ax, ay, duration, coefficients)
			action_x[step] = x - previous_x
			action_y[step] = y - previous_y
			previous_x, previous_y = x, y
		end
		return action_x, action_y
	end

	function kernels.hold_actions()
		for step = 1, 32 do
			action_x[step] = 0
			action_y[step] = 0
		end
		return action_x, action_y
	end

	return kernels
end)

local planner = (function()
	local fround = numeric.fround

	local probabilities = table.create(16, 0)

	local planner = {}
	planner.__index = planner

	function planner.new()
		local self = setmetatable({}, planner)
		self.previous = table.create(32, 0)
		self.coeff = table.create(10, 0)
		self.preparation = kernels.new_preparation()
		self:reset(7)
		return self
	end

	function planner.expects_motor(self, target_x: number, target_y: number, px: number, py: number): boolean
		if self.mode == 0 then
			return true
		end
		if self.mode ~= 2 then
			return false
		end
		local shift = math.sqrt((target_x - self.hold_goal_x) ^ 2 + (target_y - self.hold_goal_y) ^ 2)
		local distance = math.sqrt((target_x - px) ^ 2 + (target_y - py) ^ 2)
		return self.changed or shift > 1e-7 or distance > 10
	end

	function planner.begin_preparation(self, px: number, py: number, time_us: number)
		local preparation = self.preparation
		kernels.begin_tokens(preparation, preparation.hx, preparation.hy, preparation.motion, px, py, time_us)
	end

	function planner.prepare(self, tx, ty, available, valid, offset: number, last_slot: number, limit: number)
		local preparation = self.preparation
		if preparation.ready and preparation.tokens < 70 then
			kernels.advance_tokens(
				preparation, preparation.hx, preparation.hy, preparation.motion,
				tx, ty, available, valid, offset, last_slot, limit
			)
		end
	end

	function planner.reset(self, seed: number)
		local base = seed % 4294967296
		self.motor_rng = rng.new(base)
		self.selector_rng = rng.new(bit32.bxor(base, 0x5397A1))
		self.brake_rng = rng.new(bit32.bxor(base, 0x1763B4))
		self.mode = nil
		self.preparation.ready = false
		self.previous_valid = false
		self.has_origin = false
		self.origin_x = 0
		self.origin_y = 0
		self.last_head = -1
		self.decision_count = 0
		self.motor_evaluations = 0
	end

	function planner.initialize(self, hx, hy, px: number, py: number, goal_x: number, goal_y: number, now_us: number)
		local peak = 0
		for i = 609, 640 do
			peak = math.max(peak, math.abs(hx[i]), math.abs(hy[i]))
		end
		self.mode = if peak <= 1e-12 then 2 else 0
		self.age = 160
		self.duration = 64
		self.brake_vx, self.brake_vy = 0, 0
		self.brake_ax, self.brake_ay = 0, 0
		for i = 1, 10 do
			self.coeff[i] = 0
		end
		self.hold_goal_x, self.hold_goal_y = goal_x, goal_y
		self.hold_position_x, self.hold_position_y = px, py
		self.hold_error = math.sqrt((goal_x - px) ^ 2 + (goal_y - py) ^ 2)
		self.changed = self.hold_error > 1e-7
		self.innov_at = if self.changed then now_us / 1000 else 0 / 0
		self.resume_integral = 0
		self.stop_integral = 0
		self.resume_budget = fround(-math.log(math.max(self.selector_rng:uniform(), fround(1e-8))))
		self.stop_budget = fround(-math.log(math.max(self.brake_rng:uniform(), fround(1e-8))))
	end

	function planner.motor(self, hx, hy, tx, ty, available, valid, motion_known, px: number, py: number, now_us: number)
		local preparation = self.preparation
		if not (preparation.ready and preparation.time_us == now_us and preparation.px == px and preparation.py == py) then
			kernels.begin_tokens(preparation, hx, hy, motion_known, px, py, now_us)
		end
		kernels.advance_tokens(preparation, hx, hy, motion_known, tx, ty, available, valid, 0, 640, 70)
		preparation.ready = false
		local fine, dynamics = kernels.fine_features(hx, hy, tx, ty, available, valid, motion_known, px, py, now_us)
		local encoded, coefficients = neural.finish(preparation.encoder, fine, dynamics)
		local heads = kernels.decode_geometry(coefficients, hx[640], hy[640])
		local step_x = if self.has_origin then px - self.origin_x else 0
		local step_y = if self.has_origin then py - self.origin_y else 0
		local geometry, pairs = kernels.selector_inputs(if self.previous_valid then self.previous else nil, step_x, step_y)
		local logits = neural.choice(encoded, geometry, pairs, self.previous_valid)
		rng.softmax(logits, probabilities)
		local chosen = self.motor_rng:categorical(probabilities, 16)
		table.move(heads, chosen * 32 + 1, chosen * 32 + 32, 1, self.previous)
		self.origin_x, self.origin_y = px, py
		self.has_origin = true
		self.previous_valid = true
		self.motor_evaluations += 1
		self.last_head = chosen
		return kernels.decode_selected(coefficients, chosen, hx[640], hy[640])
	end

	function planner.plan(self, hx, hy, tx, ty, available, valid, motion_known, px: number, py: number, now_us: number)
		local known = valid[640] and available[640] <= now_us
		local goal_x = if known then tx[640] else px
		local goal_y = if known then ty[640] else py
		if self.mode == nil then
			self:initialize(hx, hy, px, py, goal_x, goal_y, now_us)
		end
		local old = self.mode
		self.last_head = -1
		if old ~= 0 then
			self.previous_valid = false
			for i = 0, 31 do
				local slot = 609 + i
				if valid[slot] and available[slot] <= now_us + (i - 31) * 1000 then
					local dx, dy = tx[slot] - self.hold_goal_x, ty[slot] - self.hold_goal_y
					if math.sqrt(dx * dx + dy * dy) > 1e-7 then
						self.changed = true
						if self.innov_at ~= self.innov_at then
							self.innov_at = now_us / 1000 - 31 + i
						end
						break
					end
				end
			end
		end
		local innovation_age = if self.innov_at ~= self.innov_at then 0 else math.max(0, now_us / 1000 - self.innov_at)
		local raw, context, axis_x, axis_y = kernels.event_features(
			hx, hy, tx, ty, available, valid, motion_known, px, py, now_us,
			self.age, self.hold_goal_x, self.hold_goal_y, self.hold_position_x, self.hold_position_y,
			self.hold_error, innovation_age, old
		)
		local drift = math.sqrt((px - self.hold_position_x) ^ 2 + (py - self.hold_position_y) ^ 2)
		local innovation = old == 2 and (self.changed or drift > 1e-5 or raw[1] > 10)
		local stop_probability, resume_probability = 0, 0
		if old == 0 or innovation then
			local hazard = neural.hazard(context)
			stop_probability = fround(1 / fround(1 + fround(math.exp(-math.clamp(fround(hazard[1]), -40, 40)))))
			resume_probability = fround(1 / fround(1 + fround(math.exp(-math.clamp(fround(hazard[2]), -40, 40)))))
			if stop_probability ~= stop_probability or resume_probability ~= resume_probability then
				error("nonfinite event probabilities")
			end
		end
		local first_draw = self.selector_rng:uniform()
		local second_draw = self.selector_rng:uniform()
		local braked = false
		if old == 0 then
			if known then
				self.stop_integral += -math.log(math.max(1e-8, 1 - stop_probability))
			end
			if self.stop_integral >= self.stop_budget and known then
				local duration, coefficients, frequency = neural.brake(context)
				rng.softmax(frequency, probabilities)
				local head = self.brake_rng:categorical(probabilities, 16)
				braked = true
				self.mode = 1
				self.age = 0
				self.brake_vx, self.brake_vy = hx[640], hy[640]
				local recent_x, recent_y, earlier_x, earlier_y = 0, 0, 0, 0
				for i = 633, 640 do
					recent_x += hx[i]
					recent_y += hy[i]
					earlier_x += hx[i - 8]
					earlier_y += hy[i - 8]
				end
				self.brake_ax = (recent_x / 8 - earlier_x / 8) / 8
				self.brake_ay = (recent_y / 8 - earlier_y / 8) / 8
				self.duration = duration[head + 1]
				for k = 0, 4 do
					local along = coefficients[head * 10 + k * 2 + 1]
					local across = coefficients[head * 10 + k * 2 + 2]
					self.coeff[k * 2 + 1] = along * axis_x - across * axis_y
					self.coeff[k * 2 + 2] = along * axis_y + across * axis_x
				end
				self.hold_goal_x, self.hold_goal_y = goal_x, goal_y
				self.hold_error = raw[1]
				self.changed = false
				self.innov_at = 0 / 0
			end
		elseif old == 2 then
			if innovation and known then
				self.resume_integral += -math.log(math.max(1e-8, 1 - resume_probability))
			end
			if innovation and self.resume_integral >= self.resume_budget and known then
				self.mode = 0
				self.age = 0
				self.changed = false
				self.innov_at = 0 / 0
				self.stop_integral = 0
				self.stop_budget = fround(-math.log(math.max(first_draw, 1e-8)))
			end
		end
		if not braked then
			self.brake_rng:discard_categorical(16)
		end

		local action_x, action_y
		if self.mode == 0 then
			action_x, action_y = self:motor(hx, hy, tx, ty, available, valid, motion_known, px, py, now_us)
		else
			self.motor_rng:discard_categorical(16)
		end

		if self.mode == 1 then
			action_x, action_y = kernels.brake_actions(
				self.brake_vx, self.brake_vy, self.brake_ax, self.brake_ay, self.duration, self.coeff, self.age
			)
			self.age += 32
			if self.age >= self.duration then
				local sum_x, sum_y = 0, 0
				for step = 1, 32 do
					sum_x += action_x[step]
					sum_y += action_y[step]
				end
				self.mode = 2
				self.age = math.max(0, self.age - self.duration)
				self.hold_position_x, self.hold_position_y = px + sum_x, py + sum_y
				self.hold_goal_x, self.hold_goal_y = goal_x, goal_y
				self.hold_error = math.sqrt((goal_x - self.hold_position_x) ^ 2 + (goal_y - self.hold_position_y) ^ 2)
				self.changed = false
				self.innov_at = 0 / 0
				self.resume_integral = 0
				self.resume_budget = fround(-math.log(math.max(second_draw, 1e-8)))
			end
		elseif self.mode == 2 then
			action_x, action_y = kernels.hold_actions()
			self.age += 32
		else
			self.age += 32
		end
		if self.mode ~= 0 then
			self.previous_valid = false
		end
		for step = 1, 32 do
			local x, y = action_x[step], action_y[step]
			if x ~= x or y ~= y or math.abs(x) > 1e5 or math.abs(y) > 1e5 then
				error("invalid finite primitive")
			end
		end
		self.decision_count += 1
		return action_x, action_y
	end

	return planner
end)()

local runtime = (function()
	local runtime = {}
	runtime.__index = runtime

	local window_hx = table.create(640, 0)
	local window_hy = table.create(640, 0)
	local window_tx = table.create(640, 0)
	local window_ty = table.create(640, 0)
	local window_available = table.create(640, 0)
	local window_valid = table.create(640, false)
	local window_motion = table.create(640, false)

	local function check_number(value: number, label: string): number
		if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then
			error(label .. " must be a finite number")
		end
		return value
	end

	function runtime.new(policy, options)
		local self = setmetatable({}, runtime)
		self.planner = policy
		self.initial_x = check_number(options.initial_x or 0, "initial_x")
		self.initial_y = check_number(options.initial_y or 0, "initial_y")
		self.initial_history_x = options.history_x
		self.initial_history_y = options.history_y
		self.seed = options.seed or 7
		self.prepare_enabled = options.prepare ~= false
		self.history_x = table.create(640, 0)
		self.history_y = table.create(640, 0)
		self.target_x = table.create(640, 0)
		self.target_y = table.create(640, 0)
		self.available = table.create(640, 0)
		self.valid = table.create(640, false)
		self.motion_known = table.create(640, false)
		self.actions_x = table.create(32, 0)
		self.actions_y = table.create(32, 0)
		self.points_x = table.create(32, 0)
		self.points_y = table.create(32, 0)
		self.out_x = {}
		self.out_y = {}
		self:reset()
		return self
	end

	function runtime.reset(self, options)
		if options then
			self.initial_x = check_number(options.initial_x or self.initial_x, "initial_x")
			self.initial_y = check_number(options.initial_y or self.initial_y, "initial_y")
			self.seed = options.seed or self.seed
			if options.history_x then
				self.initial_history_x = options.history_x
				self.initial_history_y = options.history_y
			end
		end
		self.planner:reset(self.seed)
		self.clock_origin = os.clock()
		self.now_us = 0
		self.requested_us = 0
		self.last_receipt_us = -1
		self.receipt_us = 0
		self.events = {}
		self.event_head = 1
		self.has_target = false
		self.current_target_x = 0
		self.current_target_y = 0
		self.x = self.initial_x
		self.y = self.initial_y
		self.cursor = 0
		for i = 1, 640 do
			local warm = i > 480
			self.history_x[i] = if warm and self.initial_history_x then self.initial_history_x[i - 480] else 0
			self.history_y[i] = if warm and self.initial_history_y then self.initial_history_y[i - 480] else 0
			self.target_x[i] = 0
			self.target_y[i] = 0
			self.available[i] = 0
			self.valid[i] = false
			self.motion_known[i] = warm
		end
		self.pending_index = 32
		self.preparing = false
		self.prepare_offset = 0
		self.prepare_time = 0
		self.observed = false
		self.fresh_decisions = 0
		self.failed = false
	end

	function runtime.time(self, timestamp_us: number?): number
		if timestamp_us == nil then
			return math.floor((os.clock() - self.clock_origin) * 1e6)
		end
		if timestamp_us < 0 or timestamp_us % 1 ~= 0 then
			error("time must be a nonnegative integer microsecond offset")
		end
		return timestamp_us
	end

	function runtime.update_target(self, x: number, y: number, timestamp_us: number?)
		local at = self:time(timestamp_us)
		check_number(x, "target x")
		check_number(y, "target y")
		if at < math.max(self.now_us, self.last_receipt_us) then
			error("target receipts must be monotonic and not precede committed movement")
		end
		table.insert(self.events, { at, x, y })
		self.last_receipt_us = at
	end

	function runtime.arrive(self)
		local events = self.events
		local event = events[self.event_head]
		if not event or event[1] > self.now_us then
			return
		end
		while event and event[1] <= self.now_us do
			self.receipt_us = event[1]
			self.current_target_x = event[2]
			self.current_target_y = event[3]
			self.has_target = true
			events[self.event_head] = nil
			self.event_head += 1
			event = events[self.event_head]
		end
		if not event then
			self.events = {}
			self.event_head = 1
		end
		local at = (self.cursor + 639) % 640 + 1
		self.target_x[at] = self.current_target_x
		self.target_y[at] = self.current_target_y
		self.available[at] = self.receipt_us
		self.valid[at] = true
		self:consider_preparing()
	end

	function runtime.append(self, dx: number, dy: number)
		local at = self.cursor + 1
		self.history_x[at] = dx
		self.history_y[at] = dy
		if self.has_target then
			self.target_x[at] = self.current_target_x
			self.target_y[at] = self.current_target_y
			self.available[at] = self.receipt_us
			self.valid[at] = true
		else
			self.target_x[at] = 0
			self.target_y[at] = 0
			self.available[at] = 0
			self.valid[at] = false
		end
		self.motion_known[at] = true
		self.cursor = (self.cursor + 1) % 640
	end

	function runtime.plan(self)
		local cursor = self.cursor
		if not self.observed then
			for i = 0, 479 do
				local at = (cursor + i) % 640 + 1
				self.history_x[at] = 0
				self.history_y[at] = 0
				self.target_x[at] = 0
				self.target_y[at] = 0
				self.available[at] = 0
				self.valid[at] = false
				self.motion_known[at] = false
			end
			self.observed = true
		end
		local tail = 640 - cursor
		table.move(self.history_x, cursor + 1, 640, 1, window_hx)
		table.move(self.history_y, cursor + 1, 640, 1, window_hy)
		table.move(self.target_x, cursor + 1, 640, 1, window_tx)
		table.move(self.target_y, cursor + 1, 640, 1, window_ty)
		table.move(self.available, cursor + 1, 640, 1, window_available)
		table.move(self.valid, cursor + 1, 640, 1, window_valid)
		table.move(self.motion_known, cursor + 1, 640, 1, window_motion)
		if cursor > 0 then
			table.move(self.history_x, 1, cursor, tail + 1, window_hx)
			table.move(self.history_y, 1, cursor, tail + 1, window_hy)
			table.move(self.target_x, 1, cursor, tail + 1, window_tx)
			table.move(self.target_y, 1, cursor, tail + 1, window_ty)
			table.move(self.available, 1, cursor, tail + 1, window_available)
			table.move(self.valid, 1, cursor, tail + 1, window_valid)
			table.move(self.motion_known, 1, cursor, tail + 1, window_motion)
		end
		self.preparing = false
		local action_x, action_y = self.planner:plan(
			window_hx, window_hy, window_tx, window_ty, window_available, window_valid, window_motion,
			self.x, self.y, self.now_us
		)
		local origin_x, origin_y = self.x, self.y
		for offset = 0, 24, 8 do
			local sum_x, sum_y = 0, 0
			for step = offset + 1, offset + 8 do
				self.actions_x[step] = action_x[step]
				self.actions_y[step] = action_y[step]
				sum_x += action_x[step]
				sum_y += action_y[step]
				self.points_x[step] = sum_x + origin_x
				self.points_y[step] = sum_y + origin_y
			end
			origin_x, origin_y = self.points_x[offset + 8], self.points_y[offset + 8]
		end
		self.pending_index = 0
		self.fresh_decisions += 1
		self:consider_preparing()
	end

	function runtime.consider_preparing(self)
		if not self.prepare_enabled or self.preparing or self.pending_index >= 32 then
			return
		end
		local policy = self.planner
		local final_x, final_y = self.points_x[32], self.points_y[32]
		if not policy:expects_motor(self.current_target_x, self.current_target_y, final_x, final_y) then
			return
		end
		local remaining = 32 - self.pending_index
		local offset = (self.cursor + remaining) % 640
		local preparation = policy.preparation
		local hx, hy, motion = preparation.hx, preparation.hy, preparation.motion
		for i = 1, 640 - remaining do
			local at = (offset + i - 1) % 640 + 1
			hx[i] = self.history_x[at]
			hy[i] = self.history_y[at]
			motion[i] = self.motion_known[at]
		end
		for step = self.pending_index + 1, 32 do
			local i = 608 + step
			hx[i] = self.actions_x[step]
			hy[i] = self.actions_y[step]
			motion[i] = true
		end
		self.prepare_offset = offset
		self.prepare_time = self.now_us + remaining * 1000
		policy:begin_preparation(final_x, final_y, self.prepare_time)
		self.preparing = true
	end

	function runtime.advance(self, timestamp_us: number?)
		if self.failed then
			error("runtime has failed; reset before advancing")
		end
		local until_us = self:time(timestamp_us)
		if until_us < self.requested_us then
			error("advance clock must be monotonic")
		end
		self.requested_us = until_us
		local count = (until_us - self.now_us) // 1000
		local out_x, out_y = self.out_x, self.out_y
		self:arrive()
		for output_at = 1, count do
			if self.pending_index == 32 and not self.has_target then
				self:append(0, 0)
			else
				if self.pending_index == 32 then
					local ok, message = pcall(self.plan, self)
					if not ok then
						self.failed = true
						error("policy action failed: " .. tostring(message))
					end
				end
				local at = self.pending_index + 1
				self.x = self.points_x[at]
				self.y = self.points_y[at]
				self:append(self.actions_x[at], self.actions_y[at])
				self.pending_index = at
			end
			self.now_us += 1000
			self:arrive()
			if self.preparing then
				self.planner:prepare(
					self.target_x, self.target_y, self.available, self.valid, self.prepare_offset,
					639 - (self.prepare_time - self.now_us) // 1000, 3
				)
			end
			out_x[output_at] = self.x
			out_y[output_at] = self.y
		end
		return count, out_x, out_y
	end

	return runtime
end)()

local abcurves = {}

abcurves.radians_per_count = 0.0003509487083280618

function abcurves.load(options)
	return runtime.new(planner.new(), options or {})
end

function abcurves.prepare_history(raw_x: { number }, raw_y: { number }, current_x: number, current_y: number)
	if #raw_x ~= 164 or #raw_y ~= 164 then
		error("prepare_history needs exactly 164 one millisecond displacements per axis")
	end
	local history_x, history_y = table.create(160), table.create(160)
	for i = 1, 160 do
		history_x[i] = (raw_x[i] + 2 * raw_x[i + 1] + 3 * raw_x[i + 2] + 2 * raw_x[i + 3] + raw_x[i + 4]) / 9
		history_y[i] = (raw_y[i] + 2 * raw_y[i + 1] + 3 * raw_y[i + 2] + 2 * raw_y[i + 3] + raw_y[i + 4]) / 9
	end
	local lag_x = (8 * raw_x[164] + 6 * raw_x[163] + 3 * raw_x[162] + raw_x[161]) / 9
	local lag_y = (8 * raw_y[164] + 6 * raw_y[163] + 3 * raw_y[162] + raw_y[161]) / 9
	return {
		history_x = history_x,
		history_y = history_y,
		filtered_x = current_x - lag_x,
		filtered_y = current_y - lag_y,
		initial_x = current_x,
		initial_y = current_y,
	}
end

return abcurves
