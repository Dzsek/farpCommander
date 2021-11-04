farpCommander = {}

-- side = 0 neutral, 1 red, 2 blue
--dispatcher = {
--	{ tozone = "c2", supplyUnit = "redcap1", attackGroup = "redattack1" }
--}

--farpCommander.addFarp("c1", 0, 0, {"redcap1","bluecap1"}, { "blue1", "blue2", "blue3"}, { "red1", "red2", "red3"}, {"blueCargo1"}, dispatcher)
--farpCommander.init()

do
	farpCommander.farps = {}
	farpCommander.redColor = {1,0,0,0.3}
	farpCommander.blueColor = {0,0,1,0.3}
	farpCommander.neutralColor = {0.7,0.7,0.7,0.3}
	farpCommander.aiSpawnerDelay = 600
	farpCommander.connections = {}
	
	function farpCommander.addFarp(_zone, _side, _level, _captureHelis, _upgradesBlue, _upgradesRed, _acceptedCrates, _redDispatcher, _blueDispatcher)
		table.insert(farpCommander.farps, {
			zone = _zone,
			side = _side,
			level = _level,
			captureHelis = _captureHelis,
			upgradesBlue = _upgradesBlue,
			upgradesRed = _upgradesRed,
			acceptedCrates = _acceptedCrates,
			builtupgrades = {},
			redDispatcher = _redDispatcher,
			blueDispatcher = _blueDispatcher
		})
	end
	
	function farpCommander.init()
		for i,v in ipairs(farpCommander.farps) do
			if #v.builtupgrades < v.level then
				local upgrades
				if v.side == 1 then
					upgrades = v.upgradesRed
				elseif v.side == 2 then
					upgrades = v.upgradesBlue
				else
					upgrades = {}
				end
				
				for i2,v2 in pairs(upgrades) do
					if not v.builtupgrades[i2] and i2<=v.level then
						local gr = mist.cloneInZone(v2, v.zone)
						v.builtupgrades[i2] = gr.name
					end
				end
			end
			
			local zone = trigger.misc.getZone(v.zone)
			local color = farpCommander.neutralColor
			if v.side == 1 then
				color = farpCommander.redColor
			elseif v.side == 2 then
				color = farpCommander.blueColor
			end
			
			trigger.action.circleToAll(-1,i,zone.point, zone.radius,color,color,1)
			trigger.action.textToAll(-1,2000+i,zone.point, {0,0,0,0.5}, {0,0,0,0}, 15, true, v.zone)
			
			if v.redDispatcher then
				for i2,v2 in ipairs(v.redDispatcher) do
					local u = Unit.getByName(v2.supplyUnit)
					if u then
						u:destroy()
					end
					
					local gr = Group.getByName(v2.attackGroup)
					if gr then
						gr:destroy()
					end
					
					local gr = Group.getByName(v2.cap)
					if gr then
						gr:destroy()
					end
				end
			end
			
			if v.blueDispatcher then
				for i2,v2 in ipairs(v.blueDispatcher) do
					local u = Unit.getByName(v2.supplyUnit)
					if u then
						u:destroy()
					end
					
					local gr = Group.getByName(v2.attackGroup)
					if gr then
						gr:destroy()
					end
					
					local gr = Group.getByName(v2.cap)
					if gr then
						gr:destroy()
					end
				end
			end
		end
		
		for i,v in ipairs(farpCommander.connections) do
			local from = trigger.misc.getZone(v.from)
			local to = trigger.misc.getZone(v.to)
			
			trigger.action.lineToAll(-1, 1000+i, from.point, to.point, {1,1,1,0.5}, 2)
		end
		
		mist.scheduleFunction(farpCommander.makeDecissions, {}, timer.getTime() + 1, 10)
		
		mist.scheduleFunction(farpCommander.makeDispatches, {}, timer.getTime() + farpCommander.aiSpawnerDelay, farpCommander.aiSpawnerDelay)
	end
	
	function farpCommander.makeDispatches()
		for i,v in ipairs(farpCommander.farps) do
			if v.redDispatcher and v.side == 1 then
				if farpCommander.isFullyUpgraded(v) then
					farpCommander.decideWhatToSend(v)
				end
			elseif v.blueDispatcher and v.side == 2 then
				if farpCommander.isFullyUpgraded(v) then
					farpCommander.decideWhatToSend(v)
				end
			end			
		end
	end
	
	function farpCommander.decideWhatToSend(initiatorfarp)
		local dp = {}
		if initiatorfarp.side == 1 then
			dp = initiatorfarp.redDispatcher
		elseif initiatorfarp.side == 2 then
			dp = initiatorfarp.blueDispatcher
		end
		
		for i,v in ipairs(dp) do
			local targetfarp = farpCommander.getFarpByZone(v.tozone)
			if targetfarp then
				-- check if supply needed
				local un = Unit.getByName(v.supplyUnit)
				if un and (un:getCategory()==Unit.Category.AIRPLANE or un:getCategory()==Unit.Category.HELICOPTER) and farpCommander.isLanded(un) then
					un:destroy()
				end
				
				un = Unit.getByName(v.supplyUnit)
				if not un then
					if targetfarp.side == initiatorfarp.side or targetfarp.side == 0 then
						if not farpCommander.isFullyUpgraded(targetfarp) then
							trigger.action.outText(initiatorfarp.zone..' sending supplies to '..targetfarp.zone, 5)
							mist.respawnGroup(v.supplyUnit,true)
						end
					end
				end
				
				-- check if attack needed
				
				local gr = Group.getByName(v.attackGroup)
				if gr then
					for ix,vx in ipairs(gr:getUnits()) do
						if (vx:getCategory()==Unit.Category.AIRPLANE or vx:getCategory()==Unit.Category.HELICOPTER) and farpCommander.isLanded(vx) then
							vx:destroy()
						end
				    end
				end
				
				gr = Group.getByName(v.attackGroup)
				if not gr then
					if targetfarp.side ~= 0 and targetfarp.side ~= initiatorfarp.side then
						trigger.action.outText(initiatorfarp.zone..' attacking '..targetfarp.zone, 5)
						mist.respawnGroup(v.attackGroup,true)
					end
				end
				
				-- check if cap needed
				
				local gr = Group.getByName(v.cap)
				if gr then
					for ix,vx in ipairs(gr:getUnits()) do
						if (vx:getCategory()==Unit.Category.AIRPLANE or vx:getCategory()==Unit.Category.HELICOPTER) and farpCommander.isLanded(vx) then
							vx:destroy()
						end
				    end
				end
				
				gr = Group.getByName(v.cap)
				if not gr then
					if targetfarp.side == initiatorfarp.side then
						trigger.action.outText(initiatorfarp.zone..' sending patrol to '..targetfarp.zone, 5)
						mist.respawnGroup(v.cap,true)
					end
				end
			end
		end
	end
	
	function farpCommander.isLanded(unit)
		if (farpCommander.getAGL(unit)<5 and mist.vec.mag(unit:getVelocity())<0.10) or (not unit:inAir()) then
			return true
		else
			return false
		end
	end
	
	function farpCommander.getFarpByZone(zonename)
		for i,v in ipairs(farpCommander.farps) do
			if v.zone == zonename then
				return v
			end
		end
		
		return nil
	end
	
	function farpCommander.isFullyUpgraded(farp)
		if farp.side == 0 then
			return false
		end
	
		local upgrades = {}
		if farp.side == 1 then
			upgrades = farp.upgradesRed
		elseif farp.side == 2 then
			upgrades = farp.upgradesBlue
		end
		
		return #farp.builtupgrades == #upgrades
	end
	
	function farpCommander.makeDecissions()
		for i,v in ipairs(farpCommander.farps) do
			
			for i2,v2 in ipairs(v.captureHelis) do
				farpCommander.checkLogisticUnitArrived(v, v2, i)
			end
			
			for i2,v2 in ipairs(v.acceptedCrates) do
				farpCommander.checkCrateInZone(v, v2, i)
			end
			
			farpCommander.checkUpgradesDestroyed(v)
			
			farpCommander.checkFarpNeutral(v, i)
		end
	end
	
	function farpCommander.checkCrateInZone(farp, crate, index)
		local zone = trigger.misc.getZone(farp.zone)
		local crate = StaticObject.getByName(crate)
		if not crate then 
			return 
		end
		
		local dist = mist.utils.get3DDist(crate:getPosition().p,zone.point)
		local height = farpCommander.getAGL(crate)
		if zone and crate and dist < zone.radius and height < 1 then
			if farp.side == 0 then
				farp.side = crate:getCoalition()
				if farp.side==1 then
					trigger.action.outText(farp.zone..' captured by RED', 5)
					trigger.action.setMarkupColorFill(index, farpCommander.redColor)
					trigger.action.setMarkupColor(index, farpCommander.redColor)
					for i2,v2 in pairs(farp.upgradesRed) do
						if not farp.builtupgrades[i2] then
							local gr = mist.cloneInZone(v2, farp.zone)
							farp.builtupgrades[i2] = gr.name
							break
						end
					end
				elseif farp.side==2 then
					trigger.action.outText(farp.zone..' captured by BLUE', 5)
					trigger.action.setMarkupColorFill(index, farpCommander.blueColor)
					trigger.action.setMarkupColor(index, farpCommander.blueColor)
					for i2,v2 in pairs(farp.upgradesBlue) do
						if not farp.builtupgrades[i2] then
							local gr = mist.cloneInZone(v2, farp.zone)
							farp.builtupgrades[i2] = gr.name
							break
						end
					end
				end
				crate:destroy()
			elseif crate:getCoalition() == farp.side then
				if farp.side == 1 then
					upgrades = farp.upgradesRed
				elseif farp.side == 2 then
					upgrades = farp.upgradesBlue
				else
					upgrades = {}
				end
				
				for i2,v2 in pairs(upgrades) do
					if not farp.builtupgrades[i2] then
						crate:destroy()
						local gr = mist.cloneInZone(v2, farp.zone)
						farp.builtupgrades[i2] = gr.name
						trigger.action.outText(farp.zone..' ugpraded', 5)
						break
					end
				end
			end
		end
	end
	
	function farpCommander.checkLogisticUnitArrived(farp, unit, index)
		local zone = trigger.misc.getZone(farp.zone)
		local cpUnit = Unit.getByName(unit)
		if not cpUnit then 
			return 
		end
		
		local dist = mist.utils.get3DDist(cpUnit:getPosition().p,zone.point)
		if zone and cpUnit and farpCommander.isLanded(cpUnit) and dist < zone.radius then
			if farp.side == 0 then
				farp.side = cpUnit:getCoalition()
				if farp.side==1 then
					trigger.action.outText(farp.zone..' captured by RED', 5)
					trigger.action.setMarkupColorFill(index, farpCommander.redColor)
					trigger.action.setMarkupColor(index, farpCommander.redColor)
					for i2,v2 in pairs(farp.upgradesRed) do
						if not farp.builtupgrades[i2] then
							local gr = mist.cloneInZone(v2, farp.zone)
							farp.builtupgrades[i2] = gr.name
							break
						end
					end
				elseif farp.side==2 then
					trigger.action.outText(farp.zone..' captured by BLUE', 5)
					trigger.action.setMarkupColorFill(index, farpCommander.blueColor)
					trigger.action.setMarkupColor(index, farpCommander.blueColor)
					for i2,v2 in pairs(farp.upgradesBlue) do
						if not farp.builtupgrades[i2] then
							local gr = mist.cloneInZone(v2, farp.zone)
							farp.builtupgrades[i2] = gr.name
							break
						end
					end
				end
				cpUnit:destroy()
			elseif cpUnit:getCoalition() == farp.side then
				if farp.side == 1 then
					upgrades = farp.upgradesRed
				elseif farp.side == 2 then
					upgrades = farp.upgradesBlue
				else
					upgrades = {}
				end
				
				for i2,v2 in pairs(upgrades) do
					if not farp.builtupgrades[i2] then
						cpUnit:destroy()
						local gr = mist.cloneInZone(v2, farp.zone)
						farp.builtupgrades[i2] = gr.name
						trigger.action.outText(farp.zone..' ugpraded', 5)
						break
					end
				end
			end
		end
	end
	
	function farpCommander.checkUpgradesDestroyed(farp)
		-- check if any upgrades were destroyed
		for i2,v2 in pairs(farp.builtupgrades) do
			local gr = Group.getByName(v2)
			if gr and gr:getSize()==0 then
				gr:destroy()
			end
			
			local gr = Group.getByName(v2)
			if not gr then
				farp.builtupgrades[i2] = nil
				trigger.action.outText(farp.zone..' lost group '..v2, 5)
			end		
		end
	end
	
	function farpCommander.checkFarpNeutral(farp, index)
		-- check if farp went back to neutral
		local empty = true
		for i2,v2 in pairs(farp.builtupgrades) do
			if v2 then
				empty = false
				break
			end
		end
		
		if empty and farp.side ~= 0 then
			farp.side = 0
			trigger.action.outText(farp.zone..' is now neutral ', 5)
			trigger.action.setMarkupColorFill(index, farpCommander.neutralColor)
			trigger.action.setMarkupColor(index, farpCommander.neutralColor)
		end
	end
	
	function farpCommander.getAGL(object)
		local pt = object:getPoint()
		return pt.y - land.getHeight({ x = pt.x, y = pt.z })
	end
end

c1bluedp = {
	{ tozone = "c2", supplyUnit = "bluecap1", attackGroup = "blueattack1", cap="bluecap1" }
}

c2bluedp = {
	{ tozone = "c3", supplyUnit = "bluecap2", attackGroup = "blueattack2", cap="bluecap2" }
}

c3bluedp = {
	{ tozone = "c4", supplyUnit = "bluecap3", attackGroup = "blueattack3", cap="bluecap3" }
}

c4reddp = {
	{ tozone = "c3", supplyUnit = "redcap3", attackGroup = "redattack3", cap="redcap3" }
}

c3reddp = {
	{ tozone = "c2", supplyUnit = "redcap2", attackGroup = "redattack2", cap="redcap2" }
}

c2reddp = {
	{ tozone = "c1", supplyUnit = "redcap1", attackGroup = "redattack1", cap="redcap1"}
}

farpCommander.addFarp("c1", 2, 3, {"redcap2"}, { "blue1", "blue2", "blue3"}, { "red1", "red2", "red3"}, {}, nil, c1bluedp)
farpCommander.addFarp("c2", 0, 0, {"bluecap1","redcap3"}, { "blue1", "blue2", "blue3"}, { "red1", "red2", "red3"}, {}, c2reddp, c2bluedp)
farpCommander.addFarp("c3", 0, 0, {"redcap3", "bluecap2"}, { "blue1", "blue2", "blue3"}, { "red1", "red2", "red3"}, {}, c3reddp, c3bluedp)
farpCommander.addFarp("c4", 1, 3, {"bluecap3"}, { "blue1", "blue2", "blue3"}, { "red1", "red2", "red3"}, {}, c4reddp, nil)
farpCommander.aiSpawnerDelay = 300
farpCommander.connections = {
	{ from="c1", to="c2"},
	{ from="c2", to="c3"},
	{ from="c3", to="c4"}
}
farpCommander.init()