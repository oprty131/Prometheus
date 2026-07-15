-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- AntiTamper.lua
--
-- This Script provides an Obfuscation Step, that breaks the script, when someone tries to tamper with it.

local Step = require("prometheus.step")
local RandomStrings = require("prometheus.randomStrings")
local Parser = require("prometheus.parser")
local Enums = require("prometheus.enums")
local logger = require("logger")

local AntiTamper = Step:extend()
AntiTamper.Description = "This Step Breaks your Script when it is modified. This is only effective when using the new VM."
AntiTamper.Name = "Anti Tamper"

AntiTamper.SettingsDescriptor = {
	UseDebug = {
		type = "boolean",
		default = true,
		description = "Use debug library. (Recommended, however scripts will not work without debug library.)",
	},
}

local function generateSanityCheck()
	local sanityCheckAnswers = {}
	local sanityPasses = math.random(1, 10)
	for i = 1, sanityPasses do
		sanityCheckAnswers[i] = (math.random(1, 2 ^ 24) % 2 == 1)
	end
	local primaryCheck = RandomStrings.randomString()
	local codeParts = {}
	local function addCode(fmt, ...)
		table.insert(codeParts, string.format(fmt, ...))
	end

	local function generateAssignment(idx)
		local index = math.min(idx, sanityPasses)
		addCode("            valid = %s;\n", tostring(sanityCheckAnswers[index]))
	end
	local function generateValidation(idx)
		local index = math.min(idx - 1, sanityPasses)
		addCode("            if valid == %s then\n", tostring(sanityCheckAnswers[index]))
		addCode("            else\n")
		addCode("                while true do end\n")
		addCode("            end\n")
	end

	addCode("do local valid = '%s';", primaryCheck)
	addCode("for i = 0, %d do\n", sanityPasses)
	for i = 0, sanityPasses do
		if i == 0 then
			addCode("        if i == 0 then\n")
			addCode("            if valid ~= '%s' then\n", primaryCheck)
			addCode("                while true do end\n")
			addCode("            end\n")
			addCode("            valid = %s;\n", tostring(sanityCheckAnswers[1]))
		elseif i == 1 then
			addCode("        elseif i == 1 then\n")
			addCode("            if valid == %s then\n", tostring(sanityCheckAnswers[1]))
			addCode("            end\n")
		else
			addCode("        elseif i == %d then\n", i)
			if i % 2 == 0 then
				generateAssignment(i)
			else
				generateValidation(i)
			end
		end
	end
	addCode("        end\n")
	addCode("    end\n")
	addCode("do valid = true end\n")
	return table.concat(codeParts)
end

function AntiTamper:init(settings) end

function AntiTamper:apply(ast, pipeline)
	if pipeline.PrettyPrint then
		logger:warn(string.format('"%s" cannot be used with PrettyPrint, ignoring "%s"', self.Name, self.Name))
		return ast
	end
	local antiTraceCode = [[
do
	local function detect_environment()
		local has_debug = type(debug) == "table"
		local has_loadstring = type(loadstring) == "function"
		local has_load = type(load) == "function"
		local env_checks = {
			pcall(function() return __log_leaf end),
			pcall(function() return _ENV.__log_leaf end),
			pcall(function() return rawget(_G, "__log_leaf") end),
			pcall(function() return rawget(_ENV or {}, "__log_leaf") end),
			pcall(function() return getfenv and getfenv().__log_leaf end),
		}
		local hook_count = 0
		if debug and debug.gethook then
			local hook = debug.gethook()
			if hook then
				hook_count = 1
			end
		end
		local function check_override(name)
			local original = _G[name]
			if not original then return false end
			local str = tostring(original)
			return str:find("stub") or str:find("__log_leaf") or str:find("trace")
		end
		local overrides = {
			check_override("print"),
			check_override("io"),
			check_override("load"),
			check_override("loadstring"),
			pcall(function() return type(debug.sethook) ~= "function" end),
		}
		local detected = false
		for _, check in ipairs(env_checks) do
			if check and check ~= true then
				detected = true
				break
			end
		end
		if not detected and hook_count > 0 then
			detected = true
		end
		if not detected then
			for _, override in ipairs(overrides) do
				if override then
					detected = true
					break
				end
			end
		end
		return detected
	end
	if detect_environment() then
		local function corrupt()
			local x = 0
			for i = 1, 1000 do
				x = x + i * (i % 3 + 1)
				if i % 100 == 0 then
					local y = x / (i + 1)
					x = y * i
				end
			end
			return x
		end
		local result = corrupt()
		if result % 2 == 0 then
			local _ = {}
			_.a = function() end
			_.b = function() end
			_G.__obfuscated = true
		end
		while true do
			local r = math.random(1, 10)
			if r == 100 then
				break
			end
		end
	end
end
]]
	local antiAst = Parser:new({ LuaVersion = Enums.LuaVersion.Lua51 }):parse(antiTraceCode)
	for i = #antiAst.body.statements, 1, -1 do
		table.insert(ast.body.statements, 1, antiAst.body.statements[i])
	end
	local code = generateSanityCheck()
	if self.UseDebug then
		local string = RandomStrings.randomString()
		code = code
			.. [[
            local sethook = debug and debug.sethook or function() end;
            local allowedLine = nil;
            local called = 0;
            sethook(function(s, line)
                if not line then
                    return
                end
                called = called + 1;
                if allowedLine then
                    if allowedLine ~= line then
                        sethook(error, "l", 5);
                    end
                else
                    allowedLine = line;
                end
            end, "l", 5);
            (function() end)();
            (function() end)();
            sethook();
            if called < 2 then
                valid = false;
            end
            if called < 2 then
                valid = false;
            end
            local funcs = {pcall, string.char, debug.getinfo, string.dump}
            for i = 1, #funcs do
                if debug.getinfo(funcs[i]).what ~= "C" then
                    valid = false;
                end
                if debug.getupvalue(funcs[i], 1) then
                    valid = false;
                end
                if pcall(string.dump, funcs[i]) then
                    valid = false;
                end
            end
            local function getTraceback()
                local str = (function(arg)
                    return debug.traceback(arg)
                end)("]] .. string .. [[");
                return str;
            end
            local traceback = getTraceback();
            valid = valid and traceback:sub(1, traceback:find("\n") - 1) == "]] .. string .. [[";
            local iter = traceback:gmatch(":(%d*):");
            local v, c = iter(), 1;
            for i in iter do
                valid = valid and i == v;
                c = c + 1;
            end
            valid = valid and c >= 2;
        ]]
    end
    code = code .. [[
    local gmatch = string.gmatch;
    local err = function() error("Tamper Detected!") end;
    local pcallIntact2 = false;
    local pcallIntact = pcall(function()
        pcallIntact2 = true;
    end) and pcallIntact2;
    local random = math.random;
    local tblconcat = table.concat;
    local unpkg = table and table.unpack or unpack;
    local n = random(3, 65);
    local acc1 = 0;
    local acc2 = 0;
    local pcallRet = {pcall(function() local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[ return "]] .. RandomStrings.randomString() .. [[" / a; end)};
    local origMsg = pcallRet[2];
    local line = tonumber(gmatch(tostring(origMsg), ':(%d*):')());
    for i = 1, n do
        local len = math.random(1, 100);
        local n2 = random(0, 255);
        local pos = random(1, len);
        local shouldErr = random(1, 2) == 1;
        local msg = origMsg:gsub(':(%d*):', ':' .. tostring(random(0, 10000)) .. ':');
        local arr = {pcall(function()
            if random(1, 2) == 1 or i == n then
                local line2 = tonumber(gmatch(tostring(({pcall(function() local a = ]] .. tostring(math.random(1, 2^24)) .. [[ - "]] .. RandomStrings.randomString() .. [[" ^ ]] .. tostring(math.random(1, 2^24)) .. [[ return "]] .. RandomStrings.randomString() .. [[" / a; end)})[2]), ':(%d*):')());
                valid = valid and line == line2;
            end
            if shouldErr then
                error(msg, 0);
            end
            local arr = {};
            for i = 1, len do
                arr[i] = random(0, 255);
            end
            arr[pos] = n2;
            return unpkg(arr);
        end)};
        if shouldErr then
            valid = valid and arr[1] == false and arr[2] == msg;
        else
            valid = valid and arr[1];
            acc1 = (acc1 + arr[pos + 1]) % 256;
            acc2 = (acc2 + n2) % 256;
        end
    end
    valid = valid and acc1 == acc2;
    if valid then else
        repeat
            return (function()
                while true do
                    l1, l2 = l2, l1;
                    err();
                end
            end)();
        until true;
        while true do
            l2 = random(1, 6);
            if l2 > 2 then
                l2 = tostring(l1);
            else
                l1 = l2;
            end
        end
        return;
    end
end
    local obj = setmetatable({}, {
        __tostring = err,
    });
    obj[math.random(1, 100)] = obj;
    (function() end)(obj);
    repeat until valid;
    ]]
    local parsed = Parser:new({LuaVersion = Enums.LuaVersion.Lua51}):parse(code)
    local doStat = parsed.body.statements[1]
    doStat.body.scope:setParent(ast.body.scope)
    table.insert(ast.body.statements, 1, doStat)
    return ast
end

return AntiTamper
