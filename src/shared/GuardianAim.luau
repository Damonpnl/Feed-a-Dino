--!nonstrict
-- Bounded prediction and committed frames. No random targeting or client requests.
local Chase=require(script.Parent.GuardianChase)
local Aim={}
function Aim.predict(position,velocity,seconds,maxLead)
	local flat=Vector3.new(velocity.X,0,velocity.Z)
	if not(flat.Magnitude<math.huge) then flat=Vector3.zero end
	if flat.Magnitude>72 then flat=flat.Unit*72 end
	local offset=flat*math.clamp(seconds,0,1.25)
	if offset.Magnitude>maxLead then offset=offset.Unit*maxLead end
	return position+offset
end
function Aim.frame(runway,c,origin,target,velocity,speed,safety)
	local predicted=Chase.clamp(runway,Aim.predict(target,velocity,c.Lead,c.MaxLead))
	local direction=if (predicted-origin):Dot(runway.axis)<0 then -runway.axis else runway.axis
	local center
	if c.Kind=="Shockwave" or c.Kind=="FireSweep" then center=predicted
	else center=origin+direction*(c.Length/2-c.Front/2) end
	-- Reserve reaction time while choosing the frame, rather than rejecting every
	-- stationary slam after the older resolver has used the entire warning budget.
	local budget=table.clone(c)
	budget.Warning=math.max(0,c.Warning-.25)
	local frame=Chase.fairFrame(runway,budget,center,predicted,speed,safety)
	if not frame then return nil end
	frame=CFrame.fromMatrix(frame.Position,direction,Vector3.yAxis,direction:Cross(Vector3.yAxis))
	-- Entire warning footprint stays on the traversable runway and outside safety.
	local along=Chase.along(runway,frame.Position)
	local half=Chase.footprintHalf(c)
	local sideHalf=if c.Kind=="Shockwave" then c.Radius else c.Width/2
	local side=(frame.Position-runway.origin):Dot(runway.lateral)
	local limit=runway.halfWidth+6-sideHalf
	if limit<0 or along-half<runway.entrance+Chase.Timing.HazardPad or along+half>runway.maxAlong then return nil end
	frame=frame+runway.lateral*(math.clamp(side,-limit,limit)-side)
	-- After clipping, test the current target's reaction budget too. A future aim point
	-- must not silently make today's position unavoidable. Allow 0.25s human reaction.
	local p=frame:PointToObjectSpace(target)
	local exit=Chase.exitDistance(c,p,if p.Z>=0 then 1 else -1)
	if exit and exit>speed*safety*math.max(0,Chase.dodgeTime(c,p)-.25)+1e-3 then return nil end
	if c.Kind=="Shockwave" and Chase.horizontal(origin,frame.Position)>c.LeapRange then return nil end
	return frame
end
return Aim
