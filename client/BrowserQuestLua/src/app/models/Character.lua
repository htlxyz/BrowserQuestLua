
local Entity = import(".Entity")
local Orientation = import(".Orientation")
local Utilitys = import(".Utilitys")
local Character = class("Character", Entity)

Character.MOVE_STEP_TIME = 0.3
Character.COOL_DOWN_TIME = 0.3

Character.PATH_FINISH = "pathingFinish"

function Character:ctor(args)
	local sm = cc.load("statemachine")
	args.states = {
		events = {
			{name = "born",		from = "none",   		to = "idle" },
			{name = "move",		from = {"idle", "walk"},to = "walk" },
			{name = "attack",	from = "idle",   		to = "atk" },
			{name = "stop",		from = {"walk", "atk"}, to = "idle" },
			{name = "kill",   	from = sm.WILDCARD,   	to = "death" }
		}
	}
	
	self.orientation_ = Orientation.DOWN
	self.path_ = {}
	Character.super.ctor(self, args)
end

function Character:doEvent(eventName, orientation)
	if self.fsm_:canDoEvent(eventName) then

		self.orientation_ = orientation or self.orientation_
		self.fsm_:doEvent(eventName)
	end
end

function Character:onAfterEvent(event)
	local bHandler = true

	if "walk" == event.to then
		self:playWalk(self.orientation_)
	elseif "idle" == event.to then
		self:playIdle()
	elseif "atk" == event.to then
		self:playAtk()
	else
		bHandler = false
	end

	if not bHandler then
		Character.super.onAfterEvent(self, event)
	end
end

function Character:setAttackSpeed(speed)
	self.atkSpeed_ = speed
end

function Character:setWalkSpeed(speed)
	self.walkSpeed_ = speed
end

function Character:walkPos(pos)
	local path = Game:findPath(pos, self.curPos_)
	self:walkPath(path)
end

function Character:walkTo(pos)
	if not pos then
		return
	end

	local orientation = Utilitys.getOrientation(self.curPos_, pos)
	if not orientation then
		-- the same, needn't walk
		print("Character:walkTo is same")
		return
	end

	self:walkStep(orientation)
end

function Character:walkPath(path)
	if path[1].x == self.curPos_.x and path[1].y == self.curPos_.y then
		table.remove(path, 1)
	end

	if #path < 1 then
		return
	end

	self.path_ = path

	if not self.isWalking_ then
		self:walkTo(table.remove(self.path_, 1))
	end
end

function Character:walkStep(dir, step)
	if self.isWalking_ then
		printInfo("Entity:walkStep is walking just return")
		return
	end

	local pos
	local cur = clone(self.curPos_)
	step = step or 1
	if Orientation.UP == dir then
		cur.y = cur.y - step
	elseif Orientation.DOWN == dir then
		cur.y = cur.y + step
	elseif Orientation.LEFT == dir then
		cur.x = cur.x - step
	elseif Orientation.RIGHT == dir then
		cur.x = cur.x + step
	end

	-- TODO check the cur pos is valid

	pos = cur
	local args = Utilitys.pos2px(pos)
	args.time = Character.MOVE_STEP_TIME * step
	args.onComplete = handler(self, self.onWalkStepComplete_)
	self.curPos_ = pos
	self.isWalking_ = true
	self.view_:moveTo(args)

	self:doEvent("move", dir)
end

function Character:onWalkStepComplete_()
	self.isWalking_ = false

	if 0 == #self.path_ then
		if self.onPathingFinish_ then
			self.onPathingFinish_()
		end
		self:doEvent("stop")
	else
		if self.fllowEntity_ then
			local dis = self:distanceWith(self.fllowEntity_)
			if dis > 1 then
				self:walkTo(table.remove(self.path_, 1))
			elseif 1 == dis then
				self:doEvent("stop")
				self:lookAt(self.fllowEntity_)
				self:attack()
			end
		else
			self:walkTo(table.remove(self.path_, 1))
		end
	end
end

function Character:onPathingFinish(callback)
	self.onPathingFinish_ = self.onPathingFinish_ or {}
	self.onPathingFinish_ = callback
end

function Character:playWalk(orientation)
	local orientation = self.orientation_
	if Orientation.UP == orientation then
		self:play("walk_up")
	elseif Orientation.DOWN == orientation then
		self:play("walk_down")
	elseif Orientation.LEFT == orientation then
		self:play("walk_left")
	elseif Orientation.RIGHT == orientation then
		self:play("walk_right")
	end
end

function Character:playIdle(orientation)
	local orientation = orientation or self.orientation_
	if Orientation.UP == orientation then
		self:play("idle_up")
	elseif Orientation.DOWN == orientation then
		self:play("idle_down")
	elseif Orientation.LEFT == orientation then
		self:play("idle_left")
	elseif Orientation.RIGHT == orientation then
		self:play("idle_right")
	end
end

function Character:playAtk(orientation)
	local args = {
		isOnce = true,
		onComplete = function()
			print("attack finish")
			self.isCoolDown = true
			self:doEvent("stop")
			local handler
			handler = cc.Director:getInstance():getScheduler():scheduleScriptFunc(function()
				cc.Director:getInstance():getScheduler():unscheduleScriptEntry(handler)
				self.isCoolDown = false
				self:attack()
			end, self.COOL_DOWN_TIME, false)
		end}
	local orientation = orientation or self.orientation_
	if Orientation.UP == orientation then
		self:play("atk_up", args)
	elseif Orientation.DOWN == orientation then
		self:play("atk_down", args)
	elseif Orientation.LEFT == orientation then
		self:play("atk_left", args)
	elseif Orientation.RIGHT == orientation then
		self:play("atk_right", args)
	end
end

function Character:fllow(entity)	
	self.fllowEntity_ = entity or self.fllowEntity_

	if not self.fllowEntity_ then
		return
	end

	if self:distanceWith(self.fllowEntity_) > 1 then
		local pos = self.fllowEntity_:getMapPos()
		self:walkPos(pos)
	end
end

function Character:lookAt(entity)
	if not self.isWalking_ then
	end

	local orientation = Utilitys.getOrientation(self.curPos_, entity:getMapPos())
	self.orientation_ = orientation or self.orientation_
end

function Character:distanceWith(entity)
	local disX = math.abs(entity.curPos_.x - self.curPos_.x)
	local disY = math.abs(entity.curPos_.y - self.curPos_.y)

	return disX + disY
end

function Character:attack(entity)
	self:fllow(entity)
	self.attackEntity_ = entity or self.attackEntity_

	if not self.fllowEntity_ then
		return
	end

	if 1 == self:distanceWith(self.attackEntity_) then
		if not self.isCoolDown then
			self:doEvent("attack", Utilitys.getOrientation(self.curPos_, self.attackEntity_:getMapPos()))
		else
			print("Character:attack in cool down time")
		end
	end
end


return Character