return {
	[0x1] = {
		type = "warning";
		message = {
			[1] = "Logger";
			[2] = "Can not find message in given id. Please check if given index is valid.";
		};
	};
	[0x2] = {
		type = "warning";
		message = {
			[1] = "Logger";
			[2] = "Given message partition is not a string.";
		};
	};
	[0x3] = {
		type = "warning";
		message = {
			[1] = "Logger";
			[2] = "Message is empty.";
		};
	};
	[0x4] = {
		type = "warning";
		message = {
			[1] = "Logger";
			[2] = "While given message is an error, it does not include a level. Did you forget it?";
		};
	};
	
	[0x5] = {
		type = "warning";
		message = {
			[1] = "Tick Manager";
			[2] = "Already running.";
		};
	};
	[0x6] = {
		type = "warning";
		message = {
			[1] = "Tick Manager";
			[2] = "Already stopped.";
		};
	};
	[0x7] = {
		type = "warning";
		message = {
			[1] = "Tick Manager";
			[2] = "Can not reset while running.";
		};
	};
	[0x8] = {
		type = "log";
		message = {
			[1] = "Tick Manager";
			[2] = "Succesfully initalized.";
		};
	};
	[0x9] = {
		type = "log";
		message = {
			[1] = "Tick Manager";
			[2] = "Succesfully reset.";
		};
	};
	[0xA] = {
		type = "log";
		message = {
			[1] = "Tick Manager";
			[2] = "Succesfully stopped.";
		};
	};
	[0xB] = {
		type = "log";
		message = {
			[1] = "Tick Manager";
			[2] = "Succesfully softstarted.";
		};
	};
	[0xC] = {
		type = "log";
		message = {
			[1] = "Tick Manager";
			[2] = "Softstarting.";
		};
	};
	[0xD] = {
		type = "log";
		message = {
			[1] = "Tick Manager";
			[2] = "Succesfully added subscriber.";
		};
	};
	[0xE] = {
		type = "log";
		message = {
			[1] = "Tick Manager";
			[2] = "Succesfully removed subscriber.";
		};
	};
	[0xF] = {
		type = "log";
		message = {
			[1] = "Tick Manager";
			[2] = "Reserved.";
		};
	};
	
	--
	
	[0x10] = {
		type = "log";
		message = {
			[1] = "Scheduler";
			[2] = "Already running.";
		};
	};
	[0x11] = {
		type = "log";
		message = {
			[1] = "Scheduler";
			[2] = "Already stopped.";
		};
	};
	[0x12] = {
		type = "log";
		message = {
			[1] = "Scheduler";
			[2] = "Succesfully initalized.";
		};
	};
	[0x13] = {
		type = "log";
		message = {
			[1] = "Scheduler";
			[2] = "Succesfully stopped.";
		};
	};
}