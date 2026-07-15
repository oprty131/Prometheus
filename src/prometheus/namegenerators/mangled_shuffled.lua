-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- namegenerators/mangled_shuffled.lua
--
-- This Script provides a function for generation of mangled names with shuffled character order


local util = require("prometheus.util")
local chararray = util.chararray

local VarDigits = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
local VarStartDigits = chararray("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
local UnicodeDigits = {"І", "Ӏ", "ⅼ", "ǀ", "ℓ", "𝟙", "𝟏", "1̶", "𐌠", "Ⅰ", "ǁ", "ǂ", "ǃ", "ǀ"}

local function generateName(id, _)
	local name = ''
	local d = id % #VarStartDigits
	id = (id - d) / #VarStartDigits
	name = name..VarStartDigits[d+1]
	while id > 0 do
		local e = id % #VarDigits
		id = (id - e) / #VarDigits
		if math.random() > 0.8 then
			name = name..UnicodeDigits[math.random(#UnicodeDigits)]
		else
			name = name..VarDigits[e+1]
		end
	end
	return name
end

local function prepare(_)
	util.shuffle(VarDigits)
	util.shuffle(VarStartDigits)
	util.shuffle(UnicodeDigits)
end

return {
	generateName = generateName,
	prepare = prepare
}
