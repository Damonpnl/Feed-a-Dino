--!nonstrict
local expect = {}
function expect.equal(actual, expected) assert(actual == expected, string.format("expected %s, got %s", tostring(expected), tostring(actual))) end
function expect.truthy(value) assert(value, "expected truthy") end
function expect.falsy(value) assert(not value, "expected falsy") end
function expect.near(actual, expected, tolerance) assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6), "values differ") end
function expect.throws(fn) local ok = pcall(fn) assert(not ok, "expected exception") end
function expect.deepEqual(actual, expected)
	local function same(a, b)
		if a == b then return true end
		if type(a) ~= "table" or type(b) ~= "table" then return false end
		for k, v in a do if not same(v, b[k]) then return false end end
		for k in b do if a[k] == nil then return false end end
		return true
	end
	assert(same(actual, expected), "tables differ")
end
return function(filter, timeout)
	local totals = {run = 0, passed = 0, failed = 0}
	for _, module in script.Parent.Cases:GetDescendants() do
		if not module:IsA("ModuleScript") or filter and not string.find(module.Name, filter, 1, true) then continue end
		local t = {expect = expect}
		function t.test(name, fn)
			totals.run += 1
			local done, success, message = false, false, nil
			local thread = task.spawn(function() success, message = pcall(fn) done = true end)
			local waited = 0
			while not done and waited < (timeout or 5) do waited += task.wait() end
			if not done then task.cancel(thread) success, message = false, "TIMEOUT" end
			if success then totals.passed += 1 print("[PASS] " .. module.Name .. " > " .. name)
			else totals.failed += 1 warn("[FAIL] " .. module.Name .. " > " .. name .. ": " .. tostring(message)) end
		end
		local ok, errorMessage = pcall(function() require(module)(t) end)
		if not ok then totals.run += 1 totals.failed += 1 warn("[FAIL] " .. module.Name .. ": " .. tostring(errorMessage)) end
	end
	print(string.format("[SUMMARY] %d run, %d passed, %d failed", totals.run, totals.passed, totals.failed))
	return totals
end
