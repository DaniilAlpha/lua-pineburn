#!/bin/luajit

local posix = require("posix")
table.unpack = table.unpack or unpack

local FOREST_WIDTH, FOREST_HEIGHT = tonumber(arg[1] or 32), tonumber(arg[2] or 16) - 1
local SIMULATION_PERIOD_MS = 0.033

local CELL_AIR = 0
local CELL_ASH = 1
local CELL_TREE = 2
local CELL_FIRE = 3

local TREE_SPREAD_CHANCE = 0.25 * SIMULATION_PERIOD_MS
local AIR_TREE_GROWTH_CHANCE = 0.01 * SIMULATION_PERIOD_MS / (FOREST_WIDTH * FOREST_HEIGHT)
local ASH_TREE_GROWTH_CHANCE = 0.00001 * SIMULATION_PERIOD_MS
local FIRE_APPEARANCE_CHANCE = 0.0001 * SIMULATION_PERIOD_MS
local FIRE_SPREAD_CHANCE = 0.8
local ASH_DECAY_CHANCE = 0.1 * SIMULATION_PERIOD_MS

local CELL_GRAPHICS = {
	[CELL_AIR] = " ",
	[CELL_TREE] = "\27[1;32mA\27[0m",
	[CELL_TREE] = "\27[1;32mλ\27[0m",
	[CELL_TREE] = "\27[1;32m\27[0m",
	[CELL_FIRE] = "\27[1;31m&\27[0m",
	[CELL_FIRE] = "\27[1;31mφ\27[0m",
	[CELL_FIRE] = "\27[1;31m\27[0m",
	[CELL_ASH] = "\27[1;30m.\27[0m",
}

function math.clamp(num, min, max)
	return math.min(math.max(num, min), max)
end

--- @param old_forest number[][]
local function simulate(old_forest, forest)
	local DIJ_SETS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }

	for i, old_forest_line in ipairs(old_forest) do
		for j, cell in ipairs(old_forest_line) do
			for _, dij in ipairs(DIJ_SETS) do
				local di, dj = dij[1], dij[2]
				local ni, nj = math.clamp(i + di, 1, #old_forest), math.clamp(j + dj, 1, #old_forest_line)

				local ncell = old_forest[ni][nj]

				if cell == CELL_TREE then
					if math.random() <= FIRE_APPEARANCE_CHANCE then
						forest[i][j] = CELL_FIRE
					end

					if (ncell == CELL_AIR or ncell == CELL_ASH) and math.random() <= TREE_SPREAD_CHANCE then
						forest[ni][nj] = CELL_TREE
					end
				elseif cell == CELL_FIRE then
					forest[i][j] = CELL_ASH

					if ncell == CELL_TREE and math.random() <= FIRE_SPREAD_CHANCE then
						forest[ni][nj] = CELL_FIRE
					end
				elseif cell == CELL_ASH then
					if math.random() <= ASH_DECAY_CHANCE then
						forest[i][j] = CELL_AIR
					elseif math.random() <= ASH_TREE_GROWTH_CHANCE then
						forest[i][j] = CELL_TREE
					end
				else
					if math.random() <= AIR_TREE_GROWTH_CHANCE then
						forest[i][j] = CELL_TREE
					end
				end
			end
		end
	end
end

local function main()
	--- @type number[][], number[][]
	local old_forest, forest = {}, {}
	for i = 1, FOREST_HEIGHT do
		old_forest[i] = {}
		forest[i] = {}
		for j = 1, FOREST_WIDTH do
			old_forest[i][j] = CELL_AIR
			forest[i][j] = CELL_AIR
		end
	end

	io.write("\27c")
	while true do
		local clock = os.clock()

		for i = 1, #forest do
			for j = 1, #forest[i] do
				old_forest[i][j] = forest[i][j]
			end
		end
		simulate(old_forest, forest)

		local words = { "\27[H" }
		for _, line in ipairs(forest) do
			for _, cell in ipairs(line) do
				words[#words + 1] = CELL_GRAPHICS[cell]
			end
			words[#words + 1] = "\n"
		end
		io.write(table.concat(words))

		clock = os.clock() - clock
		io.write(string.format("time: % 6.2fms", clock * 1000))

		io.flush()

		posix.time.nanosleep({ tv_nsec = math.min(SIMULATION_PERIOD_MS - clock, 0.999999999) * 1000000000 })
	end
end

main()
