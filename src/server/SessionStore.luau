--!nonstrict
-- Save lifecycle with an injected store. Tests never call production DataStores.
local PlayerData = require(game.ReplicatedStorage.Shared.PlayerData)
local SessionStore = {}
SessionStore.__index = SessionStore
local function same(a, b)
	if type(a) ~= type(b) then return false end
	if type(a) ~= "table" then return a == b end
	for k, v in a do if not same(v, b[k]) then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
local function readable(raw)
	if raw == nil then return true end
	if type(raw) ~= "table" then return false end
	for _, key in {"Monsters","BaseUpgrades","Stats","DiscoveredAreas"} do
		if raw[key] ~= nil and type(raw[key]) ~= "table" then return false end
	end
	if raw.Monsters then
		for id, record in raw.Monsters do if type(id) ~= "string" or type(record) ~= "table" then return false end end
	end
	return true
end
function SessionStore.new(adapter, options)
	options = options or {}
	return setmetatable({adapter=adapter, sessions={}, wait=options.wait or task.wait,
		log=options.log or warn, attempts=options.attempts or 3, readOnly=options.readOnly == true},SessionStore)
end
function SessionStore:get(key)
	local session=self.sessions[key]
	return session and session.status~="Loading" and not session.closing and session.data or nil
end
function SessionStore:status(key)
	local s=self.sessions[key]
	return s and {Status=s.status,CanSave=s.canSave,Closing=s.closing==true,Saving=s.saving==true} or nil
end
function SessionStore:load(key)
	local existing=self.sessions[key]
	if existing then
		while existing.status=="Loading" do self.wait() end
		return existing.data
	end
	local session={status="Loading",canSave=false,closing=false,saving=false}
	self.sessions[key]=session -- Reserve before the first yielding request.
	local ok, raw=false,nil
	for attempt=1,self.attempts do
		ok,raw=pcall(self.adapter.get,key)
		if ok then break end
		if attempt<self.attempts then self.wait(attempt) end
	end
	if ok and readable(raw) then
		session.data=PlayerData.normalize(raw)
		session.baseline=PlayerData.copy(raw)
		session.status=if self.readOnly then "StudioReadOnly" elseif raw==nil then "Missing" else "Loaded"
		session.canSave=not self.readOnly
	else
		session.data=PlayerData.default()
		session.status=if ok then "InvalidData" else "LoadFailed"
		self.log("[DataService] "..session.status..": session is read-only; existing saved data will not be overwritten.")
	end
	return session.data
end
function SessionStore:save(key)
	local s=self.sessions[key]
	if not s then return false,"NoSession" end
	while s.status=="Loading" or s.saving do self.wait() end
	if self.sessions[key]~=s or not s.canSave then return false,s.status end
	s.saving=true
	local snapshot=PlayerData.copy(s.data)
	local ok,result,approved=false,nil,false
	for attempt=1,self.attempts do
		ok,result=pcall(self.adapter.update,key,function(current,info)
			approved=false
			-- Compare the complete last-read/saved record, including fields owned by other systems.
			if not same(current,s.baseline) then return nil end
			approved=true
			return snapshot, info and info:GetUserIds() or nil, info and info:GetMetadata() or nil
		end)
		if ok then break end
		if attempt<self.attempts then self.wait(attempt) end
	end
	if ok and approved and result~=nil then
		s.baseline=PlayerData.copy(result)
	elseif ok then
		s.status,s.canSave="Conflict",false
		self.log("[DataService] Save conflict: newer stored data was preserved; this session is now read-only.")
	else
		self.log("[DataService] Save failed after retries; session data remains in memory for a later retry.")
	end
	s.saving=false
	return ok and approved and result~=nil, if ok then s.status else "SaveFailed"
end
function SessionStore:release(key)
	local s=self.sessions[key]
	if not s then return false end
	if s.closing then
		while self.sessions[key]==s do self.wait() end
		return true
	end
	s.closing=true
	local ok,reason=self:save(key)
	self.sessions[key]=nil
	return ok,reason
end
return SessionStore
