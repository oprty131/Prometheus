local Step = require("prometheus.step")
local Ast = require("prometheus.ast")
local Scope = require("prometheus.scope")
local visitast = require("prometheus.visitast")
local AstKind = Ast.AstKind

local DeadCode = Step:extend()
DeadCode.Description = "This Step inserts dead code to complicate static analysis"
DeadCode.Name = "Dead Code"

DeadCode.SettingsDescriptor = {
	Threshold = {
		type = "number",
		default = 1,
		min = 0,
		max = 1,
	},
	MaxInsertions = {
		type = "number",
		default = 3,
		min = 1,
		max = 10,
	},
}

function DeadCode:init(settings) end

function DeadCode:generateDeadCode(scope, depth)
	local stats = {}
	local count = math.random(1, self.MaxInsertions)
	
	for i = 1, count do
		local var1 = scope:addVariable()
		local var2 = scope:addVariable()
		local var3 = scope:addVariable()
		
		local val1 = Ast.NumberExpression(math.random(1, 1000))
		local val2 = Ast.NumberExpression(math.random(1, 100))
		
		local stat = Ast.LocalVariableDeclaration(scope, {var1, var2, var3}, {
			val1,
			Ast.AddExpression(
				Ast.VariableExpression(scope, var1),
				val2
			),
			Ast.MulExpression(
				Ast.VariableExpression(scope, var2),
				Ast.NumberExpression(math.random(2, 10))
			)
		})
		table.insert(stats, stat)
		
		if math.random() > 0.5 then
			local unusedVar = scope:addVariable()
			local deadStat = Ast.LocalVariableDeclaration(scope, {unusedVar}, {
				Ast.DivExpression(
					Ast.VariableExpression(scope, var3),
					Ast.NumberExpression(math.random(2, 100))
				)
			})
			table.insert(stats, deadStat)
		end
		
		if math.random() > 0.7 then
			local cond = Ast.GreaterThanExpression(
				Ast.VariableExpression(scope, var3),
				Ast.NumberExpression(math.random(0, 1000))
			)
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
			local deadIf = Ast.IfStatement(Ast.AndExpression(cond, invariant), Ast.Block({
				Ast.LocalVariableDeclaration(scope, {scope:addVariable()}, {
					Ast.NumberExpression(math.random(1, 10000))
				})
			}, Scope:new(scope)), {}, nil)
			table.insert(stats, deadIf)
		end
	end
	
	return stats
end

function DeadCode:apply(ast)
	visitast(ast, nil, function(node, data)
		if node.kind == AstKind.Block and node.isFunctionBlock and math.random() <= self.Threshold then
			local deadStats = self:generateDeadCode(node.scope)
			for i, stat in ipairs(deadStats) do
				local pos = math.random(2, #node.statements + 1)
				table.insert(node.statements, pos, stat)
			end
		end
	end)
	return ast
end

return DeadCode
