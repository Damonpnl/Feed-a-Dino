--!nonstrict
-- Server-local random tickets bound to the existing world GUID. Failed commits,
-- new previews and ownership transfers cannot reroll a still-live resource.
local FeedRolls={}
function FeedRolls.new(nextNumber)
	local tickets={}
	return {
		forResource=function(id)
			local index=0
			return function()
				index+=1
				tickets[id]=tickets[id] or {}
				if tickets[id][index]==nil then
					local value=nextNumber()
					assert(type(value)=="number" and value>=0 and value<1,"Invalid server RNG")
					tickets[id][index]=value
				end
				return tickets[id][index]
			end
		end,
		prune=function(exists)
			for id in tickets do if not exists(id) then tickets[id]=nil end end
		end,
	}
end
return FeedRolls
