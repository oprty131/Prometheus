-- This Script is Part of the Prometheus Obfuscator by levno-710
--
-- Vmify.lua
--
-- This Script provides a Complex Obfuscation Step that will compile the entire Script to  a fully custom bytecode that does not share it's instructions
-- with lua, making it much harder to crack than other lua obfuscators

local Step = require("prometheus.step")
local Compiler = require("prometheus.compiler.compiler")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local visitast = require("prometheus.visitast")

local Vmify = Step:extend()
Vmify.Description = "This Step will Compile your script into a fully-custom Bytecode Format and emit a vm for executing it."
Vmify.Name = "Vmify"

Vmify.SettingsDescriptor = {}

function Vmify:init(_) end

function Vmify:apply(ast)
	local compiler = Compiler:new()
	local result = compiler:compile(ast)
	
	local scope = result.body.scope
	local posId = nil
	
	visitast(result, nil, function(node, data)
		if node.kind == Ast.AstKind.WhileStatement and node.condition and node.condition.kind == Ast.AstKind.VariableExpression then
			posId = node.condition.id
		end
	end)
	
	if posId then
		visitast(result, nil, function(node, data)
			if node.kind == Ast.AstKind.IfStatement then
				local originalCondition = node.condition
				local x = Ast.NumberExpression(math.random(1, 100))
				local y = Ast.NumberExpression(math.random(1, 100))
				local invariant = Ast.EqualsExpression(
					Ast.ModExpression(
						Ast.AddExpression(
							Ast.MulExpression(x, Ast.NumberExpression(2)),
							Ast.NumberExpression(1)
						),
						Ast.NumberExpression(2)
					),
					Ast.NumberExpression(1)
				)
				node.condition = Ast.AndExpression(originalCondition, invariant)
			end
		end)
	end
	
	return result
end

return Vmify
