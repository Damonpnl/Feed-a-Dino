--!nonstrict
-- Swept server geometry in a warning-locked frame. X = long lane, Z = cross lane.
-- Character root centers define contact; the visible boundary is not secretly enlarged.
local Geometry = {}
local function clip(a,b,low,high,t0,t1)
	local delta=b-a
	if math.abs(delta)<1e-8 then return t0,t1,a>=low and a<=high end
	local enter,leave=(low-a)/delta,(high-a)/delta
	if enter>leave then enter,leave=leave,enter end
	t0,t1=math.max(t0,enter),math.min(t1,leave)
	return t0,t1,t0<=t1
end
-- Segment vs rounded oriented box: exact translation sweep, no larger catch radius.
-- Relative endpoints also follow rotation; the server samples short rotational arcs.
function Geometry.catchSegment(a,b,size,reach,vertical)
	local lo,hi,ok=clip(a.Y,b.Y,-size.Y/2-vertical,size.Y/2+vertical,0,1)
	if not ok then return false end
	local dx,dz=b.X-a.X,b.Z-a.Z local hx,hz=size.X/2,size.Z/2
	local cuts={lo,hi}
	for _,v in {{a.X,dx,hx},{a.Z,dz,hz}} do
		if math.abs(v[2])>1e-8 then for _,edge in {-v[3],v[3]} do
			local t=(edge-v[1])/v[2] if t>lo and t<hi then table.insert(cuts,t) end
		end end
	end
	table.sort(cuts)
	local function distance(t)
		local x=math.max(0,math.abs(a.X+dx*t)-hx) local z=math.max(0,math.abs(a.Z+dz*t)-hz)
		return x*x+z*z
	end
	for i=1,#cuts-1 do
		local l,h=cuts[i],cuts[i+1] local m=(l+h)/2
		local x,z=a.X+dx*m,a.Z+dz*m
		local ax,bx=if math.abs(x)>hx then a.X-math.sign(x)*hx else 0,if math.abs(x)>hx then dx else 0
		local az,bz=if math.abs(z)>hz then a.Z-math.sign(z)*hz else 0,if math.abs(z)>hz then dz else 0
		local denom=bx*bx+bz*bz
		local t=if denom>0 then math.clamp(-(ax*bx+az*bz)/denom,l,h) else l
		if math.min(distance(l),distance(h),distance(t))<=reach*reach then return true end
	end
	return distance(lo)<=reach*reach
end
function Geometry.hit(config, frame, previous, current, alpha0, alpha1)
	local a,b=frame:PointToObjectSpace(previous),frame:PointToObjectSpace(current)
	local t0,t1,ok=clip(a.Y,b.Y,0,config.Height,0,1)
	if not ok then return false end
	alpha0,alpha1=math.clamp(alpha0,0,1),math.clamp(alpha1,0,1)
	if config.Kind=="Shockwave" then
		-- Expanding filled disc: exact segment vs linearly expanding radius.
		local dx,dz=b.X-a.X,b.Z-a.Z
		local r0,dr=config.Radius*alpha0,config.Radius*(alpha1-alpha0)
		local qa,qb,qc=dx*dx+dz*dz-dr*dr,2*(a.X*dx+a.Z*dz-r0*dr),a.X*a.X+a.Z*a.Z-r0*r0
		local function f(t) return (qa*t+qb)*t+qc end
		local minimum=math.min(f(t0),f(t1))
		if qa>0 then minimum=math.min(minimum,f(math.clamp(-qb/(2*qa),t0,t1))) end
		return minimum<=1e-6
	end
	local cross=config.Kind=="FireSweep"
	local length=if cross then config.Width else config.Length
	local start=-length/2+config.Front/2
	local travel=length-config.Front
	local aAxis,bAxis=if cross then a.Z else a.X,if cross then b.Z else b.X
	local aSide,bSide=if cross then a.X else a.Z,if cross then b.X else b.Z
	local side=if cross then config.Length else config.Width
	t0,t1,ok=clip(aSide,bSide,-side/2,side/2,t0,t1)
	if not ok then return false end
	_,_,ok=clip(aAxis-(start+travel*alpha0),bAxis-(start+travel*alpha1),-config.Front/2,config.Front/2,t0,t1)
	return ok
end
function Geometry.visual(config,frame,alpha,warning)
	if config.Kind=="Shockwave" then
		local diameter=math.max(0.1,config.Radius*2*(if warning then 1 else math.clamp(alpha,0,1)))
		return frame*CFrame.new(0,0.12,0)*CFrame.Angles(0,0,math.pi/2),Vector3.new(0.2,diameter,diameter),Enum.PartType.Cylinder
	end
	local size=Vector3.new(config.Length,0.2,config.Width)
	local offset=Vector3.zero
	if not warning then
		if config.Kind=="FireSweep" then
			size=Vector3.new(config.Length,0.2,config.Front)
			offset=Vector3.new(0,0,(-config.Width/2+config.Front/2)+(config.Width-config.Front)*alpha)
		else
			size=Vector3.new(config.Front,0.2,config.Width)
			offset=Vector3.new((-config.Length/2+config.Front/2)+(config.Length-config.Front)*alpha,0,0)
		end
	end
	return frame*CFrame.new(offset+Vector3.new(0,0.12,0)),size,Enum.PartType.Block
end
return Geometry
