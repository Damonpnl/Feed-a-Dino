--!strict
-- The one authoritative order. Spawn probabilities live only in area pools.
local RarityDefinitions = {}
export type RarityId = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary" | "Mythic" | "Cosmic" | "Secret" | "Eternal" | "Divine"
RarityDefinitions.Order = {"Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine"}
local definitions = {}
local colors = {
	Color3.fromRGB(245,245,248), Color3.fromRGB(115,255,125), Color3.fromRGB(100,195,255),
	Color3.fromRGB(205,120,255), Color3.fromRGB(255,200,65), Color3.fromRGB(255,90,175),
	Color3.fromRGB(125,145,255), Color3.fromRGB(160,120,230), Color3.fromRGB(235,210,255), Color3.fromRGB(255,240,175),
}
for priority, name in RarityDefinitions.Order do
	definitions[name] = {Priority = priority, Color = colors[priority], SecretPlus = priority >= 8}
end
function RarityDefinitions.get(id: string) return definitions[id] end
function RarityDefinitions.isValid(id: string): boolean return definitions[id] ~= nil end
function RarityDefinitions.priority(id: string): number return if definitions[id] then definitions[id].Priority else 0 end
function RarityDefinitions.isSecretPlus(id: string): boolean return definitions[id] ~= nil and definitions[id].SecretPlus end
function RarityDefinitions.getColor(id: string): Color3 return (definitions[id] or definitions.Common).Color end
return RarityDefinitions
