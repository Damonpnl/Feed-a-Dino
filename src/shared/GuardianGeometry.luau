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
