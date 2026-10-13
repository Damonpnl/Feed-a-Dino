--!strict
-- Shared compact formatting for authoritative requirements and presentation.
local Format = {}
function Format.compact(value: number): string
	local suffixes = {"", "K", "M", "B", "T"}
	local index = 1
	while math.abs(value) >= 1000 and index < #suffixes do value /= 1000 index += 1 end
	local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
	return text .. suffixes[index]
end
function Format.needPower(value: number): string return "NEED " .. Format.compact(value) .. " POWER" end
return Format
