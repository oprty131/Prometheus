-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- EncryptStrings.lua
--
-- This Script provides a Simple Obfuscation Step that encrypts strings

local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local visitast = require("prometheus.visitast")
local util = require("prometheus.util")
local AstKind = Ast.AstKind

local EncryptStrings = Step:extend()
EncryptStrings.Description = "This Step will encrypt strings within your Program."
EncryptStrings.Name = "Encrypt Strings"

EncryptStrings.SettingsDescriptor = {}

function EncryptStrings:init(_) end

function EncryptStrings:CreateEncryptionService()
	local usedSeeds = {}
	local secret_key_6 = math.random(0, 63)
	local secret_key_7 = math.random(0, 127)
	local secret_key_44 = math.random(0, 17592186044415)
	local secret_key_8 = math.random(0, 255)
	local secret_key_9 = math.random(0, 255)
	local secret_key_10 = math.random(0, 255)
	local secret_key_11 = math.random(0, 255)
	local floor = math.floor

	local function primitive_root_257(idx)
		local g, m, d = 1, 128, 2 * idx + 1
		repeat
			g, m, d = g * g * (d >= m and 3 or 1) % 257, m / 2, d % m
		until m < 1
		return g
	end

	local param_mul_8 = primitive_root_257(secret_key_7)
	local param_mul_45 = secret_key_6 * 4 + 1
	local param_add_45 = secret_key_44 * 2 + 1
	local state_45 = 0
	local state_8 = 2
	local prev_values = {}
	
	local function set_seed(seed_53)
		state_45 = seed_53 % 35184372088832
		state_8 = seed_53 % 255 + 2
		prev_values = {}
	end

	local function gen_seed()
		local seed
		repeat
			seed = math.random(0, 35184372088832)
		until not usedSeeds[seed]
		usedSeeds[seed] = true
		return seed
	end

	local function get_random_32()
		state_45 = (state_45 * param_mul_45 + param_add_45) % 35184372088832
		repeat
			state_8 = state_8 * param_mul_8 % 257
		until state_8 ~= 1
		local r = state_8 % 32
		local n = floor(state_45 / 2 ^ (13 - (state_8 - r) / 32)) % 2 ^ 32 / 2 ^ r
		return floor(n % 1 * 2 ^ 32) + floor(n)
	end

	local function get_next_pseudo_random_byte()
		if #prev_values == 0 then
			local rnd = get_random_32()
			local low_16 = rnd % 65536
			local high_16 = (rnd - low_16) / 65536
			local b1 = low_16 % 256
			local b2 = (low_16 - b1) / 256
			local b3 = high_16 % 256
			local b4 = (high_16 - b3) / 256
			prev_values = { b1, b2, b3, b4 }
		end
		return table.remove(prev_values)
	end

	local function encrypt(str)
		local seed = gen_seed()
		set_seed(seed)
		local len = string.len(str)
		local out = {}
		local prevVal = secret_key_8
		local key2 = secret_key_9
		local key3 = secret_key_10
		local key4 = secret_key_11
		for i = 1, len do
			local byte = string.byte(str, i)
			local rnd = get_next_pseudo_random_byte()
			byte = (byte - (rnd + prevVal + key2)) % 256
			byte = (byte ~ (key3 * (i % 7 + 1))) % 256
			byte = (byte + key4 * ((i * 3 + 7) % 11)) % 256
			out[i] = string.char(byte)
			prevVal = byte
			key2 = (key2 * 7 + 13) % 256
			key3 = (key3 * 11 + 7) % 256
			key4 = (key4 * 13 + 3) % 256
		end
		return table.concat(out), seed
	end

	local function genCode()
		local code = [[
do
	local __dc = 0
	]] .. table.concat(util.shuffle{
		"local floor = math.floor",
		"local random = math.random",
		"local remove = table.remove",
		"local char = string.char",
		"local state_45 = 0",
		"local state_8 = 2",
		"local charmap = {}",
		"local nums = {}"
	}, "\n") .. [[
	for i = 1, 256 do
		nums[i] = i
	end

	repeat
		local idx = random(1, #nums)
		local n = remove(nums, idx)
		charmap[n] = char(n - 1)
	until #nums == 0

	local prev_values = {}
	local key2 = ]] .. tostring(secret_key_9) .. [[
	local key3 = ]] .. tostring(secret_key_10) .. [[
	local key4 = ]] .. tostring(secret_key_11) .. [[
	
	local function get_next_pseudo_random_byte()
		if #prev_values == 0 then
			state_45 = (state_45 * ]] .. tostring(param_mul_45) .. [[ + ]] .. tostring(param_add_45) .. [[) % 35184372088832
			repeat
				state_8 = state_8 * ]] .. tostring(param_mul_8) .. [[ % 257
			until state_8 ~= 1
			local r = state_8 % 32
			local shift = 13 - (state_8 - r) / 32
			local n = floor(state_45 / 2 ^ shift) % 4294967296 / 2 ^ r
			local rnd = floor(n % 1 * 4294967296) + floor(n)
			local low_16 = rnd % 65536
			local high_16 = (rnd - low_16) / 65536
			prev_values = { low_16 % 256, (low_16 - low_16 % 256) / 256, high_16 % 256, (high_16 - high_16 % 256) / 256 }
		end
		local prevValuesLen = #prev_values
		local removed = prev_values[prevValuesLen]
		prev_values[prevValuesLen] = nil
		key2 = (key2 * 7 + 13) % 256
		key3 = (key3 * 11 + 7) % 256
		key4 = (key4 * 13 + 3) % 256
		return (removed + key2 + key3 * (prevValuesLen + 1) + key4 * ((prevValuesLen * 3 + 7) % 11)) % 256
	end

	local realStrings = {}
	local __mt = {}
	__mt.__index = function(t, k)
		local r = realStrings[k]
		if r then return r end
		return nil
	end
	__mt.__newindex = function(t, k, v)
		realStrings[k] = v
	end
	STRINGS = setmetatable({}, __mt)
	
  	function DECRYPT(str, seed)
		local realStringsLocal = realStrings
		if(realStringsLocal[seed]) then return seed else
			prev_values = {}
			local chars = charmap
			state_45 = seed % 35184372088832
			state_8 = seed % 255 + 2
			local len = #str
			realStringsLocal[seed] = ""
			local prevVal = ]] .. tostring(secret_key_8) .. [[
			local k2 = ]] .. tostring(secret_key_9) .. [[
			local k3 = ]] .. tostring(secret_key_10) .. [[
			local k4 = ]] .. tostring(secret_key_11) .. [[
			local s = ""
			for i=1, len, 1 do
				local rnd = get_next_pseudo_random_byte()
				local byte = (string.byte(str, i) + rnd + prevVal + k2) % 256
				byte = (byte ~ (k3 * (i % 7 + 1))) % 256
				byte = (byte - k4 * ((i * 3 + 7) % 11)) % 256
				prevVal = byte
				s = s .. chars[byte + 1]
				k2 = (k2 * 7 + 13) % 256
				k3 = (k3 * 11 + 7) % 256
				k4 = (k4 * 13 + 3) % 256
			end
			realStringsLocal[seed] = s
		end
		return seed
	end
end]]
		return code
	end

	return {
		encrypt = encrypt,
		param_mul_45 = param_mul_45,
		param_mul_8 = param_mul_8,
		param_add_45 = param_add_45,
		secret_key_8 = secret_key_8,
		genCode = genCode,
	}
end

function EncryptStrings:apply(ast, _)
	local Encryptor = self:CreateEncryptionService()
	local code = Encryptor.genCode()
	local newAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(code)
	local doStat = newAst.body.statements[1]
	local scope = ast.body.scope
	local decryptVar = scope:addVariable()
	local stringsVar = scope:addVariable()
	local decoy1Id = scope:addVariable()
	local decoy2Id = scope:addVariable()
	
	local decoyCode = [[
	local function decoy1(data)
		local result = ""
		for i = 1, #data do
			result = result .. string.char(string.byte(data, i) ~ (i % 7 + 1))
		end
		return result
	end
	local function decoy2(data, key)
		local result = ""
		for i = 1, #data do
			result = result .. string.char((string.byte(data, i) + key) % 256)
		end
		return result
	end
	]]
	
	local decoyAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(decoyCode)
	for _, st in ipairs(decoyAst.body.statements) do
		table.insert(ast.body.statements, math.random(1, #ast.body.statements + 1), st)
	end

	doStat.body.scope:setParent(ast.body.scope)

	visitast(newAst, nil, function(node, data)
		if(node.kind == AstKind.FunctionDeclaration) then
			if(node.scope:getVariableName(node.id) == "DECRYPT") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id)
				data.scope:addReferenceToHigherScope(scope, decryptVar)
				node.scope = scope
				node.id = decryptVar
			end
		end
		if(node.kind == AstKind.AssignmentVariable or node.kind == AstKind.VariableExpression) then
			if(node.scope:getVariableName(node.id) == "STRINGS") then
				data.scope:removeReferenceToHigherScope(node.scope, node.id)
				data.scope:addReferenceToHigherScope(scope, stringsVar)
				node.scope = scope
				node.id = stringsVar
			end
		end
	end)

	visitast(ast, nil, function(node, data)
		if(node.kind == AstKind.StringExpression) then
			data.scope:addReferenceToHigherScope(scope, stringsVar)
			data.scope:addReferenceToHigherScope(scope, decryptVar)
			local encrypted, seed = Encryptor.encrypt(node.value)
			local call = Ast.FunctionCallExpression(Ast.VariableExpression(scope, decryptVar), {
				Ast.StringExpression(encrypted), 
				Ast.NumberExpression(seed),
			})
			local wrapper = Ast.AddExpression(
				Ast.MulExpression(
					Ast.NumberExpression(1),
					call
				),
				Ast.NumberExpression(0)
			)
			return Ast.IndexExpression(
				Ast.VariableExpression(scope, stringsVar),
				wrapper
			)
		end
	end)

	table.insert(ast.body.statements, 1, doStat)
	table.insert(ast.body.statements, 1, Ast.LocalVariableDeclaration(scope, util.shuffle{ decryptVar, stringsVar }, {}))
	return ast
end

return EncryptStrings
