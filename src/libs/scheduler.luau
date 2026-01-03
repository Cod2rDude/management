--!strict
--!native
--!optimize 2

--[[
	******************************************************************************
	* @file		: .../management/libs/scheduler.lua
	* @author	: Cod2rDude
	* @date		: December 31 2025
	* @lastEdit	: January 3 2025 @ 19:42
	* @brief	: Scheduler for scheduling tasks per tick.
	* @version	: 1.0.0
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

--[[
	******************************************************************************
	* @sources				:
	*						https://dev.to/kevwan/implement-a-timing-wheel-for-millions-of-concurrent-tasks-30oi
	*						https://mropert.github.io/2025/04/30/making_games_tick_part2/
	*						https://mropert.github.io/2025/07/15/making_games_tick_part6/
	*						https://en.wikipedia.org/wiki/Scheduling_(computing)#Manual_scheduling
	*						https://en.wikipedia.org/wiki/Amortized_analysis
	*						https://coinsbench.com/swap-and-pop-algorithm-9fb85bd74d48
	*						https://luau.org/performance#optimized-table-length
	******************************************************************************
]]

--// Services
local replicatedStorage				= game:GetService"ReplicatedStorage"

--// Libs
local __log__						= require(script.Parent.Parent.__log__.__log__)
local config						= require(script.Parent.Parent.__config)
local tickManager					= require(script.Parent.tickManager)
local enums							= require(script.Parent.Parent.global.enums)

local packages						= replicatedStorage.replicated.packages
local queues						= require(packages.queues)
local queues_fifo					= queues.fifo
local queues_priorityMax			= queues.priorityMax

--// Constants
local MAX_TICKS_PER_FRAME			= 4
local MAX_EPHEMERAL_TASKS_PER_TICK	= 16
local MAX_EPHEMERAL_QUEUE_LIMIT		= 128
local DEFAULT_PRIORITY				= 1
local PRIORITY_MIN					= 0
local PRIORITY_MAX					= MAX_EPHEMERAL_QUEUE_LIMIT

--// Variables
local amIRunning					= false

local tickCountInPrevFrame			= -1

--// Custom Type Definitions/Declerations
type customTask						=
{
	id								: string, --?
	operationType					: number,
	callbackOrActor					: (number, ...any) -> (...any?) | string,
	interval						: number,
}

--// Enums
local taskOperationType				= enums.taskOperationType

--// Logs
local alreadyRunning				= 0x10
local alreadyStopped				= 0x11
local succesfullyInitalized			= 0x12
local succesfullyStopped			= 0x13

--// Functions
function onEveryFrame(ticksInThisFrame : number)
	local difference = ticksInThisFrame - tickCountInPrevFrame
	local didWeSkipTicks = difference > MAX_TICKS_PER_FRAME
	
	if didWeSkipTicks then
		difference = MAX_TICKS_PER_FRAME
	end
	
	local internalAccumulator = tickCountInPrevFrame
	
	for i = 1, difference do
		print(internalAccumulator)
		
		internalAccumulator += 1
	end
	
	if didWeSkipTicks then
		-- reschedule
	end
	
	tickCountInPrevFrame = ticksInThisFrame
end

--// Lib Decleration
local scheduler						= {}

--// Lib Variables
scheduler.ephemeralTasks			= queues_priorityMax.new(MAX_EPHEMERAL_QUEUE_LIMIT)
scheduler.tasksByIntervals			= {}
scheduler.tasksByNextRunTickAndType	= {}

--// Lib Functions

--[[
	@params
	*	@param taskOperationType : number Operation type of that task. Check @notes for further info.
	*	@param callbackOrActorName : function | string Actor name if its a physics task else function.
	*	@param interval : number How often does that task run, 0 if it's an ephemeral task.
	*	@param priority : number? Priority of task, only if its an ephemeral task.
	@brief Adds a task to scheduler.
	@returns
	*	@r1 string? Id of task.
	@notes
	*	
]]
scheduler.addTask					= function(
	taskOperationType_ : number,
	callbackOrActorName : (number, ...any) -> (...any?) | string,
	interval : number, priority : number?
) : string?
	local isMyIntervalLessOrEqualToZero = interval <= 0

	if isMyIntervalLessOrEqualToZero and #scheduler.ephemeralTasks >= MAX_EPHEMERAL_QUEUE_LIMIT then
		return nil
	end

	--TODO: Priority queue for ephemeral tasks.
	--TODO: tasksByNextRunTickAndType[nextRunTick][type] = {} -> pointers to tasks in tasksByIntervals

	local self				= {
		id					= "task"..time(),
		operationType		= taskOperationType,
		interval			= math.max(interval, 0),
		callbackOrActorName	= callbackOrActorName
	} :: customTask

	if isMyIntervalLessOrEqualToZero then
		
	else
		local firstRun = tickManager.getCurrentTicks() + self.interval

		if not scheduler.tasksByIntervals[self.interval] then
			
		end
	end

	return self.id
end

scheduler.init						= function() : boolean?
	if amIRunning then
		__log__.new(alreadyRunning, {})
		return nil
	end
	
	amIRunning = true
	
	tickManager.subscribe(onEveryFrame)
	tickManager.init(config.softstart)
	
	__log__.new(succesfullyInitalized, {})
	
	-- normally initalized isnt same as running
	-- and we shouldnt run immediately run after initalizing
	-- but its okay for our case.
	
	return true
end

return scheduler