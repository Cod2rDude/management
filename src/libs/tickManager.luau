--!strict
--!native
--!optimize 2

--[[
	******************************************************************************
	* @file		: .../management/libs/tickManager.lua
	* @author	: Cod2rDude
	* @date		: December 23 2025
	* @lastEdit	: December 31 2025 @ 21:16
	* @brief	: Tick counter for managing tasks on the server.
	* @version	: 1.1.0
	******************************************************************************
	* @attention
	*
	* Copyright © 2025 Axon Corporation.
	* All rights reserved.
	*
	* This software is licensed under terms that can be found in the LICENSE file
	* in the root directory of this software component.
	* If no LICENSE file comes with this software, it is provided AS-IS.
	*
	******************************************************************************
--]]

--// Services
local runService			= game:GetService("RunService")
local serverScriptService	= game:GetService("ServerScriptService")

--// Libs
local __log__				= require(script.Parent.Parent.src.__log__.__log__)
local config				= require(script.Parent.Parent.src.__config)

--// CONSTANTS
local SOFTSTART_FRAMES		= 1024
local MIN_TPS				= 10
local MAX_TPS				= 60
local DEFAULT_TPS			= 20
local MAX_TICKS_PER_FRAME	= math.floor(MAX_TPS/6 + 1) -- deprecated.

--// Variables
local amIRunning			= false -- (¬_¬)
local amISoftstarting		= false

local tps					= DEFAULT_TPS
local rate					= 1/tps

local softstartFrames		= 0
local accumulated			= 0
local currentTicks			= 0

local heartbeatConnection	= nil :: RBXScriptConnection?

--// Logs
local alreadyRunning		= 0x5
local alreadyStopped		= 0x6
local cantResetWhileRunning	= 0x7
local succesfullyInitalized	= 0x8
local succesfullyStopped	= 0x9
local succesfullyReset		= 0xA
local softstartDone			= 0xB
local softstarting			= 0xC
local succesfullyAddedSub	= 0xD
local succesfullyRemovedSub	= 0xE
local reserved				= 0xF

--// Functions
function safeGetTPS()
	local t = config.tps or DEFAULT_TPS
	t = math.clamp(t, MIN_TPS, MAX_TPS)
	
	return t
end

--// Lib Decleration
local tickManager			= {}

--// Lib Variables
tickManager.myTickSubscriber= nil :: (tick : number) -> (...any?)?

--// Lib Functions
tickManager.init			= function(softstart : boolean) : boolean
	if amIRunning then
		__log__.new(alreadyRunning, {})
		return false
	end
	
	amIRunning = true
	
	tps = safeGetTPS()
	rate = 1 / tps
	accumulated = 0
	amISoftstarting = false
	
	local softstartTime = tick()
	
	if softstart then
		amISoftstarting = true
		softstartFrames = 0
		
		__log__.new(softstarting, {})
	end
	
	heartbeatConnection = runService.Heartbeat:Connect(function(deltaTime : number)
		if amISoftstarting then
			softstartFrames += 1
			
			if softstartFrames <= SOFTSTART_FRAMES then
				return
			else
				__log__.new(softstartDone, {"Took "..tostring(SOFTSTART_FRAMES).." and "..
					tostring(tick()-softstartTime).." seconds to softstart."})
				amISoftstarting = false
			end
		end
		
		accumulated += deltaTime
		local ticksCountedInThisFrame = 0
		
		while accumulated >= rate do
			accumulated -= rate
			ticksCountedInThisFrame += 1
		end
		
		if ticksCountedInThisFrame > 0 then
			currentTicks += ticksCountedInThisFrame
			
			--[[
			-- Are there any other ways to do this.
			-- This seems like a bad approach,
			-- Attributes are kinda bad though,
			-- Best option would be a subscription system i guess.
			
			newTickBindableEvent:Fire(currentTicks, ticksCountedInThisFrame)
			--]]
			
			-- I only added one subscription maximum,
			-- Since the only thing that will read ticks and do stuff with them
			-- is scheduler.
			if tickManager.myTickSubscriber then
				tickManager.myTickSubscriber(currentTicks)
			end
		end
	end)
	
	__log__.new(succesfullyInitalized, {})
	
	return true
end

tickManager.stop			= function() : boolean
	if not amIRunning then
		__log__.new(alreadyStopped, {})
		return false
	end
	
	amIRunning = false
	
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	
	__log__.new(succesfullyStopped, {})
	
	return true
end

tickManager.reset			= function() : boolean
	if amIRunning then
		__log__.new(cantResetWhileRunning, {})
		return false
	end
	
	accumulated = 0
	amISoftstarting = false
	softstartFrames = 0
	currentTicks = 0
	
	__log__.new(succesfullyReset, {})
	
	return true
end

tickManager.getCurrentTicks	= function() : number
	return currentTicks
end

tickManager.subscribe		= function(callback : (currentTick : number) -> (...any?)) : boolean
	if typeof(callback) ~= "function" then return false end
	
	tickManager.myTickSubscriber = callback
	
	__log__.new(succesfullyAddedSub, {})
	
	return true
end

tickManager.unsubscribe		= function() : boolean
	-- did we need this?
	
	tickManager.myTickSubscriber = nil
	
	__log__.new(succesfullyRemovedSub, {})
	
	return true
end

return tickManager