--!strict
--!native
--!optimize 2
--!nolint LocalUnused

--[[
	******************************************************************************
	* @file		: .../management/src/libs/scheduler.lua
	* @author	: Cod2rDude
	* @date		: December 31 2025
	* @lastEdit	: January 5 2025 @ 23:35
	* @brief	: Scheduler for scheduling tasks per tick.
	* @version	: 1.5.0
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
local serverScriptService			= game:GetService"ServerScriptService"

--// Libs
local __log__						= require(script.Parent.Parent.__log__.__log__)
local config						= require(script.Parent.Parent.__config)
local tickManager					= require(script.Parent.tickManager)
local enums							= require(script.Parent.Parent.global.enums)
local types							= require(script.Parent.Parent.global.types)

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
local taskCounter					= 0

local actors						= serverScriptService.server.actors

local executors						=
{
	[1]								= function(obj : customTask, ct : number)
		if typeof(obj.callbackOrActor) ~= "function" then return end

		local success, err = pcall(obj.callbackOrActor, ct)

		if not success then
			-- gotAnErrorWhileExecutingTask
			__log__.new(0x15, {err :: string})
		end
	end,
	[2]								= function(obj : customTask, ct : number)
		if typeof(obj.callbackOrActor) ~= "function" then return end
		--TODO: Promises
		task.spawn(obj.callbackOrActor, ct)
	end,
	[3]								= function(obj : customTask, ct : number)
		if type(obj.callbackOrActor) == "string" and actors[obj.callbackOrActor] and actors[obj.callbackOrActor]:IsA("Actor") then
			local actor = actors[obj.callbackOrActor] :: Actor
			actor:SendMessage("work", ct)
		end
	end
}

local toToEI_lookupTable			= -- goofy ahh variable name.
{
	[1]								= 3,
	[2]								= 2,
	[3]								= 2,
	[4]								= 1,
}

--// Custom Type Definitions/Declerations
type customTask						= types.customTask

--// Enums
local enum							= {
	taskOperationType				= enums.taskOperationType
}

--// Logs
local alreadyRunning				= 0x10
local alreadyStopped				= 0x11
local succesfullyInitalized			= 0x12
local succesfullyStopped			= 0x13
local succesfullyAddedTaskToSchedule= 0x14
local gotAnErrorWhileExecutingTask	= 0x15
local cantAddEphemeralTask			= 0x16
local wrongTaskOperationType		= 0x17
--local r1							= 0x18
--local r2							= 0x19
--local r3							= 0x1A
--local r4							= 0x1B
--local r5							= 0x1C
--local r6							= 0x1D
--local r7							= 0x1E
--local r8							= 0x1F
-- go to local r1, press ctrl+v, go to local r8, press I, press - twice

--// Functions
function taskOperationTypeToExecutorsIndex(taskOperationType: number)
	return toToEI_lookupTable[taskOperationType] and toToEI_lookupTable[taskOperationType] or -1
end

function insert<T>(t : {}, v : any)
	if not v then return 1 end
	local i = #t+1
	t[i] = v
	return i
end

function swap(t : {}, i : number, j : number)
	t[i], t[j] = t[j], t[i]
end

--// Lib Decleration
local scheduler						= {}

--// Lib Variables
scheduler.ephemeralTasks			= queues_priorityMax.new(MAX_EPHEMERAL_QUEUE_LIMIT)
scheduler.tasksByIntervals			= {}
scheduler.tasksByNextRunTickAndType	= {}
scheduler.inputRequests				= {}
scheduler.remoteEvents				= {}

--// Lib Local Functions (Essentialy require variables above)
function createNewTickBucket(n)
	scheduler.tasksByNextRunTickAndType[n] = {} 
	return scheduler.tasksByNextRunTickAndType[n]
end

function createNewOperationBucket(n, j)
	scheduler.tasksByNextRunTickAndType[n][j] = {}
	return scheduler.tasksByNextRunTickAndType[n][j]
end

function processInputRequests()
	
end

function processRemoteEvents()
	
end

function processEphemeralTasks(ct : number)
	if scheduler.ephemeralTasks:isEmpty() then return end

	for i = 1, math.min(MAX_EPHEMERAL_TASKS_PER_TICK, scheduler.ephemeralTasks:size()), 1 do
		local removedTask : customTask = scheduler.ephemeralTasks:dequeue()

		executors[taskOperationTypeToExecutorsIndex(removedTask.operationType)](removedTask, ct)
	end
end

function processTasksWithInterval(ct : number)
	if not scheduler.tasksByNextRunTickAndType[ct] then return end

	local taskBucketForThisTick = scheduler.tasksByNextRunTickAndType[ct]

	for i : number, taskBucketForOperationTypes : {{number}} in taskBucketForThisTick do
		if #taskBucketForOperationTypes == 0 then continue end

		local executorIndex = taskOperationTypeToExecutorsIndex(i)
		if executorIndex <= 0 then continue end
		local executor = executors[executorIndex]

		for j = 1, #taskBucketForOperationTypes do
			local indexData = taskBucketForOperationTypes[j]
			
			if not scheduler.tasksByIntervals[indexData[1]][indexData[2]] then
				continue
			end

			local retrievedTask : customTask = scheduler.tasksByIntervals[indexData[1]][indexData[2]]

			executor(retrievedTask, ct)

			local nextTick = ct + retrievedTask.interval
			local nextRunTickBucket = scheduler.tasksByNextRunTickAndType[nextTick] or createNewTickBucket(nextTick)
			local nextOperationBucket = nextRunTickBucket[retrievedTask.operationType] or createNewOperationBucket(nextTick, retrievedTask.operationType) 
			
			insert(nextOperationBucket, indexData)
		end

		scheduler.tasksByNextRunTickAndType[ct][i] = nil
	end

	scheduler.tasksByNextRunTickAndType[ct] = nil
end

function onEveryFrame(ticksInThisFrame : number)
	local difference = ticksInThisFrame - tickCountInPrevFrame
	local didWeSkipTicks = difference > MAX_TICKS_PER_FRAME
	
	if didWeSkipTicks then
		difference = MAX_TICKS_PER_FRAME
	end
	
	local internalAccumulator = tickCountInPrevFrame
	
	if not didWeSkipTicks then
		for i = 1, difference do
			internalAccumulator += 1
			print(internalAccumulator)

			--[[
				## Schedule
				1. Input Requests
				2. Remote Events
				3. Ephemeral Tasks
				4. Tasks That Run Every Tick
				5. Tasks That Run Every x Tick

				Essentialy 4 & 5 is same
			]]
		
			processInputRequests()
			processRemoteEvents()
			processEphemeralTasks(internalAccumulator)
			processTasksWithInterval(internalAccumulator)
		end
	else
		local last = 0
		local nextFrameStartTick = ticksInThisFrame + 1
		local startIndex = tickCountInPrevFrame + 1
		local endIndex = ticksInThisFrame - 1

		for i = startIndex, endIndex do -- reschedule sh*t
			if not scheduler.tasksByNextRunTickAndType[i] then last+=1; continue end

			--swap(scheduler.tasksByNextRunTickAndType, i, nextFrameStartTick + last)
			-- im dumb asf

			

			last+=1
		end
	end

	tickCountInPrevFrame = ticksInThisFrame
end

--// Lib Functions

--[[
	@params
	*	@param taskOperationType_ : string Operation type of that task. Check @notes for further info.
	*	@param callbackOrActorName : function | string Actor name if its a physics task else function.
	*	@param interval : number How often does that task run, 0 if it's an ephemeral task.
	*	@param priority : number? Priority of task, only if its an ephemeral task.
	@brief Adds a task to scheduler.
	@returns
	*	@r1 string? Id of task.
	@notes
	*	Task operation type is an enum, please check global/enums for further info.
]]
scheduler.addTask					= function(
	taskOperationType_ : number,
	callbackOrActor_ : (ct : number, ...any) -> (...any?) | string,
	interval_ : number, priority_ : number?
) : string?
	local isMyIntervalLessOrEqualToZero = interval_ <= 0

	--TODO: log here

	if isMyIntervalLessOrEqualToZero and scheduler.ephemeralTasks:size() >= MAX_EPHEMERAL_QUEUE_LIMIT then
		__log__.new(cantAddEphemeralTask, {})
		return nil
	end

	if taskOperationType_ < 1 or taskOperationType_ > enum.taskOperationType.__count then
		__log__.new(wrongTaskOperationType, {tostring(taskOperationType_)})
		return nil
	end

	-- i need a priority queue that lets me look at object with x'nd priority without removing it.

	taskCounter += 1

	local self				= {
		id					= "task"..tostring(taskCounter),
		operationType		= taskOperationType_,
		interval			= math.max(interval_, 0),
		callbackOrActor		= callbackOrActor_,
	} :: customTask

	if isMyIntervalLessOrEqualToZero then
		priority_ = math.clamp(priority_ and priority_ or DEFAULT_PRIORITY, PRIORITY_MIN, PRIORITY_MAX)

		scheduler.ephemeralTasks:enqueue(self, priority_ :: number)
	else
		local firstRun = tickManager.getCurrentTicks() + self.interval + 1

		if not scheduler.tasksByIntervals[self.interval] then
			scheduler.tasksByIntervals[self.interval] = {}
		end

		local idx = insert(
			scheduler.tasksByIntervals[self.interval],
			self
		)

		if not scheduler.tasksByNextRunTickAndType[firstRun] then
			scheduler.tasksByNextRunTickAndType[firstRun] = {}
		end
		if not scheduler.tasksByNextRunTickAndType[firstRun][self.operationType] then
			scheduler.tasksByNextRunTickAndType[firstRun][self.operationType] = {}
		end

		local idx2 = insert(
			scheduler.tasksByNextRunTickAndType[firstRun][self.operationType],
			{self.interval, idx}
		)

		__log__.new(succesfullyAddedTaskToSchedule, {self.id})
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
	-- but its okay for our case. (i guess)
	
	return true
end

return scheduler