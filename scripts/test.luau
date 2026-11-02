-- Lune verifies portable rules and static scene construction, not Roblox physics.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local passed, failed, compiled = 0, 0, 0

local function test(name, callback)
	local ok, err = pcall(callback)
	if ok then
		passed += 1
		print("PASS " .. name)
	else
		failed += 1
		warn("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function checkSyntax(directory)
	local names = fs.readDir(directory)
	table.sort(names)
	for _, name in names do
		local path = directory .. "/" .. name
		if fs.isDir(path) then
			checkSyntax(path)
		elseif string.match(name, "%.luau$") then
			local ok, err = pcall(luau.load, fs.readFile(path), { debugName = path })
			if ok then
				compiled += 1
			else
				failed += 1
				warn("SYNTAX FAIL " .. path .. ": " .. tostring(err))
			end
		end
	end
end

checkSyntax("src")
checkSyntax("tests")
checkSyntax("scripts")

local specs = fs.readDir("tests")
table.sort(specs)
for _, name in specs do
	if string.match(name, "%.spec%.luau$") then
		local module = "../tests/" .. string.gsub(name, "%.luau$", "")
		local ok, suite = pcall(require, module)
		if not ok or type(suite) ~= "function" then
			failed += 1
			warn("SUITE FAIL " .. name .. ": " .. tostring(suite))
		else
			local ran, err = pcall(suite, test)
			if not ran then
				failed += 1
				warn("SUITE FAIL " .. name .. ": " .. tostring(err))
			end
		end
	end
end

print(string.format("Compiled %d Luau files; tests: %d passed, %d failed.", compiled, passed, failed))
if failed > 0 then
	process.exit(1)
end
