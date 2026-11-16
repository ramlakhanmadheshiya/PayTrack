class_name QR
extends RefCounted
## Makes QR codes (byte mode, error correction level M, versions 1–40).
## Follows the QR standard (ISO/IEC 18004), ported from Project Nayuki's
## reference "QR Code generator" (MIT licence).
##   var m := QR.encode("https://…")   # Array of rows, each an Array of bool (true = dark)
##   var img := QR.image(m, 10)         # Image, 10 px per module, 4-module white border

const ECC_PER_BLOCK_M := [-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28]
const BLOCKS_M := [-1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49]
const ECL_M_FORMAT := 0

var size := 0
var version := 1
var modules: Array = []      # [y][x] bool
var is_function: Array = []  # [y][x] bool


static func encode(text: String) -> Array:
	var data := text.to_utf8_buffer()
	var ver := 1
	while true:
		var cap_bits := _num_data_codewords(ver) * 8
		var count_bits := 8 if ver <= 9 else 16
		var used := 4 + count_bits + data.size() * 8
		if used <= cap_bits:
			break
		ver += 1
		if ver > 40:
			push_error("QR: text too long")
			return []
	var q := QR.new()
	q._build(ver, data)
	return q.modules


static func image(m: Array, scale := 8, border := 4) -> Image:
	var n := m.size()
	var px := (n + border * 2) * scale
	var img := Image.create(px, px, false, Image.FORMAT_RGB8)
	img.fill(Color.WHITE)
	for y in n:
		for x in n:
			if m[y][x]:
				img.fill_rect(Rect2i((x + border) * scale, (y + border) * scale, scale, scale), Color.BLACK)
	return img


# ---------------------------------------------------------------------------

func _build(ver: int, data: PackedByteArray) -> void:
	version = ver
	size = ver * 4 + 17
	modules = []
	is_function = []
	for y in size:
		var r1 := []
		var r2 := []
		r1.resize(size)
		r2.resize(size)
		r1.fill(false)
		r2.fill(false)
		modules.append(r1)
		is_function.append(r2)
	# Data bits.
	var bits: Array = []
	_append_bits(bits, 0x4, 4)
	_append_bits(bits, data.size(), 8 if ver <= 9 else 16)
	for b in data:
		_append_bits(bits, b, 8)
	var cap_bits := _num_data_codewords(ver) * 8
	_append_bits(bits, 0, mini(4, cap_bits - bits.size()))
	_append_bits(bits, 0, (8 - bits.size() % 8) % 8)
	var pad := 0xEC
	while bits.size() < cap_bits:
		_append_bits(bits, pad, 8)
		pad = 0x11 if pad == 0xEC else 0xEC
	var codewords := PackedByteArray()
	codewords.resize(bits.size() / 8)
	for i in bits.size():
		if bits[i]:
			codewords[i >> 3] |= 1 << (7 - (i & 7))
	# Function patterns, codewords, best mask.
	_draw_function_patterns()
	var all := _add_ecc_and_interleave(codewords)
	_draw_codewords(all)
	var best_mask := 0
	var min_penalty := 1 << 62
	for m in 8:
		_apply_mask(m)
		_draw_format_bits(m)
		var p := _penalty()
		if p < min_penalty:
			best_mask = m
			min_penalty = p
		_apply_mask(m)   # undo (XOR)
	_apply_mask(best_mask)
	_draw_format_bits(best_mask)


static func _append_bits(bits: Array, val: int, n: int) -> void:
	for i in range(n - 1, -1, -1):
		bits.append(((val >> i) & 1) != 0)


static func _num_raw_modules(ver: int) -> int:
	var result := (16 * ver + 128) * ver + 64
	if ver >= 2:
		var num_align := ver / 7 + 2
		result -= (25 * num_align - 10) * num_align - 55
		if ver >= 7:
			result -= 36
	return result


static func _num_data_codewords(ver: int) -> int:
	return _num_raw_modules(ver) / 8 - ECC_PER_BLOCK_M[ver] * BLOCKS_M[ver]


func _set_function(x: int, y: int, dark: bool) -> void:
	modules[y][x] = dark
	is_function[y][x] = true


func _draw_function_patterns() -> void:
	for i in size:
		_set_function(6, i, i % 2 == 0)
		_set_function(i, 6, i % 2 == 0)
	_draw_finder(3, 3)
	_draw_finder(size - 4, 3)
	_draw_finder(3, size - 4)
	var pos := _alignment_positions()
	var n := pos.size()
	for i in n:
		for j in n:
			if not ((i == 0 and j == 0) or (i == 0 and j == n - 1) or (i == n - 1 and j == 0)):
				_draw_alignment(pos[i], pos[j])
	_draw_format_bits(0)
	_draw_version()


func _draw_finder(x: int, y: int) -> void:
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var dist := maxi(absi(dx), absi(dy))
			var xx := x + dx
			var yy := y + dy
			if xx >= 0 and xx < size and yy >= 0 and yy < size:
				_set_function(xx, yy, dist != 2 and dist != 4)


func _draw_alignment(x: int, y: int) -> void:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			_set_function(x + dx, y + dy, maxi(absi(dx), absi(dy)) != 1)


func _alignment_positions() -> Array:
	if version == 1:
		return []
	var num_align := version / 7 + 2
	var step := 26 if version == 32 else int(ceil(float(version * 4 + 4) / float(num_align * 2 - 2))) * 2
	var result := [6]
	var p := size - 7
	var tail := []
	for i in num_align - 1:
		tail.insert(0, p)
		p -= step
	return result + tail


func _draw_format_bits(mask: int) -> void:
	var data := (ECL_M_FORMAT << 3) | mask
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits := ((data << 10) | rem) ^ 0x5412
	for i in range(0, 6):
		_set_function(8, i, _bit(bits, i))
	_set_function(8, 7, _bit(bits, 6))
	_set_function(8, 8, _bit(bits, 7))
	_set_function(7, 8, _bit(bits, 8))
	for i in range(9, 15):
		_set_function(14 - i, 8, _bit(bits, i))
	for i in range(0, 8):
		_set_function(size - 1 - i, 8, _bit(bits, i))
	for i in range(8, 15):
		_set_function(8, size - 15 + i, _bit(bits, i))
	_set_function(8, size - 8, true)


func _draw_version() -> void:
	if version < 7:
		return
	var rem := version
	for i in 12:
		rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
	var bits := (version << 12) | rem
	for i in 18:
		var bit := _bit(bits, i)
		var a := size - 11 + i % 3
		var b := i / 3
		_set_function(a, b, bit)
		_set_function(b, a, bit)


static func _bit(x: int, i: int) -> bool:
	return ((x >> i) & 1) != 0


func _add_ecc_and_interleave(data: PackedByteArray) -> PackedByteArray:
	var num_blocks: int = BLOCKS_M[version]
	var block_ecc_len: int = ECC_PER_BLOCK_M[version]
	var raw_codewords := _num_raw_modules(version) / 8
	var num_short := num_blocks - raw_codewords % num_blocks
	var short_len := raw_codewords / num_blocks
	var blocks: Array = []
	var divisor := _rs_divisor(block_ecc_len)
	var k := 0
	for i in num_blocks:
		var dat_len := short_len - block_ecc_len + (0 if i < num_short else 1)
		var dat := data.slice(k, k + dat_len)
		k += dat_len
		var ecc := _rs_remainder(dat, divisor)
		var block := PackedByteArray(dat)
		if i < num_short:
			block.append(0)   # placeholder, skipped when interleaving
		block.append_array(ecc)
		blocks.append(block)
	var result := PackedByteArray()
	for i in (blocks[0] as PackedByteArray).size():
		for j in blocks.size():
			if i != short_len - block_ecc_len or j >= num_short:
				result.append(blocks[j][i])
	return result


static func _rs_divisor(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			result[j] = _rs_multiply(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = _rs_multiply(root, 0x02)
	return result


static func _rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for b in data:
		var factor := b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in result.size():
			result[i] ^= _rs_multiply(divisor[i], factor)
	return result


static func _rs_multiply(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * 0x11D)
		z ^= ((y >> i) & 1) * x
	return z & 0xFF


func _draw_codewords(data: PackedByteArray) -> void:
	var i := 0
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		for vert in size:
			for j in 2:
				var x := right - j
				var upward := ((right + 1) & 2) == 0
				var y := size - 1 - vert if upward else vert
				if not is_function[y][x] and i < data.size() * 8:
					modules[y][x] = _bit(data[i >> 3], 7 - (i & 7))
					i += 1
		right -= 2


func _apply_mask(mask: int) -> void:
	for y in size:
		for x in size:
			var invert := false
			match mask:
				0: invert = (x + y) % 2 == 0
				1: invert = y % 2 == 0
				2: invert = x % 3 == 0
				3: invert = (x + y) % 3 == 0
				4: invert = (x / 3 + y / 2) % 2 == 0
				5: invert = x * y % 2 + x * y % 3 == 0
				6: invert = (x * y % 2 + x * y % 3) % 2 == 0
				7: invert = ((x + y) % 2 + x * y % 3) % 2 == 0
			if invert and not is_function[y][x]:
				modules[y][x] = not modules[y][x]


func _penalty() -> int:
	var result := 0
	# Runs in rows and columns, and finder-like patterns.
	for pass_i in 2:
		for a in size:
			var run_color := false
			var run_len := 0
			var history := [0, 0, 0, 0, 0, 0, 0]
			for b in size:
				var c: bool = modules[a][b] if pass_i == 0 else modules[b][a]
				if c == run_color:
					run_len += 1
					if run_len == 5:
						result += 3
					elif run_len > 5:
						result += 1
				else:
					_finder_add_history(run_len, history)
					if not run_color:
						result += _finder_count_patterns(history) * 40
					run_color = c
					run_len = 1
			result += _finder_terminate(run_color, run_len, history) * 40
	# 2x2 blocks.
	for y in size - 1:
		for x in size - 1:
			var c: bool = modules[y][x]
			if c == modules[y][x + 1] and c == modules[y + 1][x] and c == modules[y + 1][x + 1]:
				result += 3
	# Balance of dark modules.
	var dark := 0
	for y in size:
		for x in size:
			if modules[y][x]:
				dark += 1
	var total := size * size
	var k := int(ceil(absf(dark * 20.0 - total * 10.0) / total)) - 1
	result += maxi(k, 0) * 10
	return result


func _finder_add_history(run_len: int, history: Array) -> void:
	if history[0] == 0:
		run_len += size
	history.pop_back()
	history.insert(0, run_len)


func _finder_count_patterns(h: Array) -> int:
	var n: int = h[1]
	var core: bool = n > 0 and h[2] == n and h[3] == n * 3 and h[4] == n and h[5] == n
	return (1 if core and h[0] >= n * 4 and h[6] >= n else 0) + (1 if core and h[6] >= n * 4 and h[0] >= n else 0)


func _finder_terminate(run_color: bool, run_len: int, history: Array) -> int:
	if run_color:
		_finder_add_history(run_len, history)
		run_len = 0
	run_len += size
	_finder_add_history(run_len, history)
	return _finder_count_patterns(history)
