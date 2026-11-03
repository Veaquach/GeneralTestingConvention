local Tests = {}
local Results = {}
local Start = os.clock()

local Passes, Fails = 0, 0

local Categories = {
	"Actors",
	"Cache",
	"Closure",
	"Crypt",
	"Debug",
	"Drawing",
	"Environment",
	"FileSystem",
	"Input",
	"Instance",
	"Oth",
	"Metatable",
	"Miscellaneous",
	"Reflection",
	"Script",
	"Signal",
}

local CurrentCategory = "Oth"

local Icons = {
	Passed = "｜✅｜",
	Failed = "｜❌｜",
	Skipped = "｜🟡｜",
}

local function GetFunctionFromName(Path: string)
	local Current = getgenv()

	for _, Segment in ipairs(string.split(Path, ".")) do
		if Current == nil then
			return nil
		end

		local Success, Value = pcall(function()
			return Current[Segment]
		end)

		if not Success or Value == nil then
			return nil
		end

		Current = Value
	end

	return Current
end

local function WaitFor(Predicate, Timeout: number?)
	local Deadline = os.clock() + (Timeout or 1)

	while not Predicate() and os.clock() < Deadline do
		task.wait()
	end

	return Predicate()
end

local function SetCategory(Category: string)
	CurrentCategory = Category
end

local function AddName(Category: string, Name: string)
	local Names = Results[Category]

	if not Names then
		Names = {}
		Results[Category] = Names
	end

	if not table.find(Names, Name) then
		table.insert(Names, Name)
	end
end

local function Test(Options)
	if type(Options) ~= "table" then
		error("A test has called Test() without providing a table.", 2)
	end

	local Name = Options.Name

	if type(Name) ~= "string" or Name == "" then
		error("Test() was called without a Name.", 2)
	end

	local Run = Options.Function

	if type(Run) ~= "function" then
		error(`Test("{Name}") was called without a Function to run.`, 2)
	end

	local Category = Options.Category or CurrentCategory
	local Function = GetFunctionFromName(Name)
	local Started = os.clock()
	local Status, Passed, Reason

	if Function == nil then
		Status = "Skipped"
		Passed = nil
		Reason = `the executor does not have {Name}.`
		Fails += 1
	else
		local Success, First, Second = pcall(Run, Function)

		if not Success then
			Status = "Failed"
			Passed = false

			local Message = tostring(First)
			Reason = Message:match("^[^\n]-:%d+:%s*(.*)$") or Message
			Fails += 1
		elseif First == false then
			Status = "Failed"
			Passed = false
			Reason = if type(Second) == "string" then Second else "the checks returned false."
			Fails += 1
		elseif type(First) == "string" then
			Status = "Passed"
			Passed = true
			Reason = First
			Passes += 1
		else
			Status = "Passed"
			Passed = true
			Reason = if type(Second) == "string"
				then Second
				elseif Options.Reason then Options.Reason
				else "the checks completed without error."
			Passes += 1
		end
	end

	local Entry = {
		Name = Name,
		Category = Category,
		Description = Options.Description or "",
		Status = Status,
		Passed = Passed,
		Reason = Reason,
		Duration = (os.clock() - Started) * 1000,
	}

	if Entry.Duration >= 250 then
		print(`{Entry.Name} took {math.floor(Entry.Duration)} ms`)
	end

	local Previous = Tests[Name]

	if Previous and Previous.Category ~= Category then
		local Names = Results[Previous.Category]

		if Names then
			local Index = table.find(Names, Name)

			if Index then
				table.remove(Names, Index)
			end
		end
	end

	Tests[Name] = Entry
	AddName(Category, Name)

	return Entry
end

local function Get(Category: string?)
	local List = {}

	if Category then
		for _, Name in ipairs(Results[Category] or {}) do
			table.insert(List, Tests[Name])
		end

		return List
	end

	local Seen = {}

	for _, Name in ipairs(Categories) do
		Seen[Name] = true

		for _, Entry in ipairs(Get(Name)) do
			table.insert(List, Entry)
		end
	end

	local Extra = {}

	for Name in pairs(Results) do
		if not Seen[Name] and #Results[Name] > 0 then
			table.insert(Extra, Name)
		end
	end

	table.sort(Extra)

	for _, Name in ipairs(Extra) do
		for _, Entry in ipairs(Get(Name)) do
			table.insert(List, Entry)
		end
	end

	return List
end

local function GetPassed(Name: string): boolean?
	local Entry = Tests[Name]

	if not Entry then
		return nil
	end

	return Entry.Passed
end

local function Report(Category: string?)
	local Names = {}

	if Category then
		table.insert(Names, Category)
	else
		table.insert(Names, table.unpack(Categories))

		for Name in pairs(Results) do
			if not table.find(Names, Name) then
				table.insert(Names, Name)
			end
		end
	end

	local Lines = {}
	local Passed, Failed, Skipped = 0, 0, 0

	for _, Name in ipairs(Names) do
		local Entries = Get(Name)

		if #Entries > 0 then
			local CPasses, CFails = 0, 0

			for _, Entry in ipairs(Entries) do
				if Entry.Status == "Passed" then
					CPasses += 1
				elseif Entry.Status == "Failed" then
					CFails += 1
				end
			end

			print("\n\n| " .. Name .. " | " .. CPasses .. "/" .. (CPasses + CFails) .. "\n\n")

			for _, Entry in ipairs(Entries) do
				if Entry.Status == "Passed" then
					Passed += 1
				elseif Entry.Status == "Failed" then
					Failed += 1
				else
					Skipped += 1
				end

				table.insert(Lines, `{Icons[Entry.Status] or ""} {Entry.Name}:`)

				if Entry.Description ~= "" then
					print(
						`{Icons[Entry.Status] or ""} {Entry.Name}:\nWhat it does: {Entry.Description}\n{Entry.Status} in {math.floor(
							Entry.Duration
						)} ms because {Entry.Reason}\n`
					)
				end

				table.insert(Lines, `{Entry.Status} in {math.floor(Entry.Duration)} ms because {Entry.Reason}`)
				table.insert(Lines, "")
			end
		end
	end

	table.insert(Lines, `{Passed} passed, {Failed} failed, {Skipped} skipped.\n`)

	local Output = table.concat(Lines, "\n")
	--print(Output)

	return Output
end

local function Clear()
	table.clear(Tests)
	table.clear(Results)
end

SetCategory("Cache")

Test({
	Name = "cloneref",
	Description = "Creates a new Instance for the same underlying Instance and returns it.",
	Function = function(CloneRef)
		assert(CloneRef, "Global not found")

		local Part = Instance.new("Part")
		local OriginalService = game:GetService("CoreGui")

		assert(CloneRef(OriginalService) ~= OriginalService, "cloned service cannot be equal to original reference")
		Part.Parent = workspace

		if setrawmetatable then
			local SameTable = {}
			setrawmetatable(Part, {
				__type = "Instance",
				__index = function()
					return SameTable
				end,
			})
		end

		local PartNewRef = CloneRef(Part)

		pcall(function()
			PartNewRef.Name = math.random()
		end)

		assert(Part ~= PartNewRef, "cloned part cannot be equal to original reference")
		assert(Part.Name == PartNewRef.Name, "The new xref does not contain the same metadata as the original")

		pcall(function()
			Part:Destroy()
		end)

		return "Passed"
	end,
})
Test({
	Name = "compareinstances",
	Description = "Compares the Instance references stored in two instance object values.",
	Function = function(Target)
		local Players = game:GetService("Players")

		local Workspace = game.Workspace

		assert(not Target(Players, Workspace), "returned value told us 2 Instances are the same when they are not.")
		assert(Target(Players, Players), "returned value told us 2 same services are not the same.")
		assert(
			Target(cloneref(Players), Players),
			"returned value told us a cloned reference is the same as the original reference."
		)

		return "returned values correctly identified on all tests."
	end,
})

Test({
	Name = "cache.invalidate",
	Description = "Removes the cached Instance entry for an Instance.",
	Function = function(Target)
		local Service = game:GetService("TestService")
		assert(Service == game:GetService("TestService"), "the cache was already unstable before invalidating.")

		Target(Service)
		assert(not cache.iscached(Service), "the invalidated reference is still marked as cached.")

		local Fresh = game:GetService("TestService")
		assert(Service ~= Fresh, "cache was kept after invalidating.")
		assert(typeof(Service) == "Instance", "the old reference stopped being an Instance.")

		return "the cached entry was dropped and the old reference stayed usable."
	end,
})

Test({
	Name = "cache.iscached",
	Description = "Returns whether the given Instance has a valid Instance cache.",
	Function = function(Target)
		local TestService = game:GetService("SocialService")
		assert(Target(TestService), "value wrongly returned a cached Instance as not cached.")
		assert(GetPassed("cache.invalidate") == true, "cache.invalidate failed, no more tests can be done.")
		cache.invalidate(TestService)
		assert(not Target(TestService), "cache supposedly still remained after invalidation of cache.")

		return "values properly identified cached and non-cached entries."
	end,
})

Test({
	Name = "cache.replace",
	Description = "Makes future lookups of one Instance return another Instance's cached reference.",
	Function = function(CacheReplace)
		local Holder = Instance.new("Folder")
		local Original = Instance.new("Part")
		Original.Parent = Holder

		local Replacement = Instance.new("Fire")
		assert(Original ~= Replacement, "I have no words. How is this possible?")

		CacheReplace(Original, Replacement)

		assert(Original ~= Replacement, "cache.replace changed an existing local reference.")

		local Resolved = Holder.Part
		assert(Resolved == Replacement, "future lookups still returned the old cached reference.")
		assert(typeof(Resolved) == "Instance", "replacement is no longer an Instance.")

		Holder:Destroy()
		return "the cached reference was replaced for future lookups."
	end,
})

Report("Cache")

SetCategory("Closure")

Test({
	Name = "checkcaller",
	Description = "Returns true on executor threads and false when called from a clientside hook.",
	Function = function(Target)
		local TestFunction = hookmetamethod
		assert(
			TestFunction,
			"hookmetamethod not available, cannot properly test (could mean executor is not internal i.e hookmetamethod is impossible to implement)."
		)
		local Thread = Target()
		assert(Thread == true, "checkcaller returned false on executor thread.")

		local Hook, Original
		Original = TestFunction(game, "__namecall", function(...)
			if Hook == nil then
				Hook = Target()
			end
			return Original(...)
		end)

		task.spawn(function() -- Professional optimization from the optimizer himself.
			tostring(game)
			task.wait(0.1)

			hookmetamethod(game, "__namecall", Original)

			assert(Hook == false, "checkcaller did not return false when hooked.")
			return "returned true on executor thread and false in a hook."
		end)
	end,
})

Test({
	Name = "clonefunction",
	Description = "Clones a function while preserving its behavior, stack depth, and environment.",
	Function = function(CloneFunction)
		local DebugInfo, TaskWait = debug.info, task.wait
		local Yielded = false

		local Original = function(...)
			local Frames = 0
			for Index = 1, 20 do
				if DebugInfo(Index, "f") then
					Frames += 1
				end
			end

			TaskWait()
			Yielded = true

			return 1, Frames, ...
		end

		local Environment = {}
		setfenv(Original, Environment)

		local Clone = CloneFunction(Original)
		assert(Clone ~= Original, "clonefunction returned the original function.")

		local _, OriginalFrames = Original()
		Yielded = false

		local Results = table.pack(Clone(nil))

		assert(Yielded, "the clone's body never ran (it did not yield).")
		assert(Results[1] == 1, "the clone changed the first return value.")
		assert(Results[3] == nil, "the clone changed the second argument.")
		assert(Results.n == 3, `the clone returned {Results.n} values instead of 3.`)
		assert(Results[2] == OriginalFrames, "the clone changed the stack frame count.")

		local OriginalSource, OriginalName, OriginalLine, OriginalNArgs, OriginalVararg = DebugInfo(Original, "snla")
		local CloneSource, CloneName, CloneLine, CloneNArgs, CloneVararg = DebugInfo(Clone, "snla")

		assert(OriginalSource == CloneSource, "the clone changed the source.")
		assert(OriginalName == CloneName, "the clone changed the function name.")
		assert(OriginalLine == CloneLine, "the clone changed the line.")
		assert(OriginalNArgs == CloneNArgs, "the clone changed the argument count.")
		assert(OriginalVararg == CloneVararg, "the clone changed vararg status.")
		assert(getfenv(Clone) == Environment, "the clone changed the environment.")

		return "the clone matched the original's behavior, stack depth, and environment."
	end,
})

Test({
	Name = "comparefunctions",
	Description = "Reports whether two function values are considered the same function.",
	Function = function(CompareFunctions)
		local function Make()
			return function()
				return 1
			end
		end

		local A, B = Make(), Make()

		assert(CompareFunctions(A, A), "a function compared unequal to itself.")
		assert(CompareFunctions(print, print), "the same C function compared unequal to itself.")
		assert(not CompareFunctions(A, print), "a Lua function compared equal to a C function.")
		assert(not CompareFunctions(print, A), "a C function compared equal to a Lua function.")

		local SameDefinition = CompareFunctions(A, B)
		local CloneFunction = GetFunctionFromName("clonefunction")
		local CloneAware = CloneFunction and CompareFunctions(A, CloneFunction(A))

		return `same-definition closures compare {SameDefinition and "equal" or "unequal"}; clonefunction copies compare {CloneAware == true and "equal" or (CloneAware == false and "unequal" or "untestable")}.`
	end,
})

Test({
	Name = "getfunctionhash",
	Description = "Returns the hash of a Luau function in SHA384.",
	Function = function(Target)
		local TestFunction = function()
			return "General Testing Convention"
		end
		local OldHash = Target(TestFunction)
		hookfunction(TestFunction, function() end)
		local NewHash = Target(TestFunction)

		assert(OldHash ~= NewHash, "hash returned the same hash for a hooked function as it's unhooked variant.")

		return "it properly returned correct and different hashes."
	end,
})

Test({
	Name = "hookfunction",
	Description = "Replaces a function with a hook and returns the original, so calls can be intercepted and restored.",
	Function = function(HookFunction)
		local HookCalls = 0
		local ReceivedA, ReceivedB

		local function Target(A, B)
			return A + B, A * B
		end

		local Original = HookFunction(Target, function(A, B)
			HookCalls += 1
			ReceivedA, ReceivedB = A, B
			return "hooked", A * B
		end)

		assert(type(Original) == "function", "hookfunction did not return the original function.")

		local First, Second = Target(2, 3)

		assert(HookCalls == 1, "the hook was not called exactly once.")
		assert(ReceivedA == 2 and ReceivedB == 3, "the hook did not receive the original arguments.")
		assert(First == "hooked" and Second == 6, "the hook's return values were not used.")

		local OriginalFirst, OriginalSecond = Original(2, 3)

		assert(OriginalFirst == 5 and OriginalSecond == 6, "the returned original does not run the original body.")
		assert(HookCalls == 1, "calling the returned original went through the hook.")

		HookFunction(Target, Original)

		local RestoredFirst, RestoredSecond = Target(2, 3)

		assert(HookCalls == 1, "the hook still ran after restoring the function.")
		assert(
			RestoredFirst == 5 and RestoredSecond == 6,
			"restoring the function did not restore the original behaviour."
		)

		return "the hook intercepted the call with the original arguments, and restoring returned the original behaviour."
	end,
})

Test({
	Name = "hookmetamethod",
	Description = "Replaces an object's metamethod and returns the original, so it can be intercepted and restored.",
	Function = function(HookMetamethod)
		local IndexCalls = 0

		local OriginalIndex = function(_, Key)
			return "original:" .. Key
		end

		local Object = setmetatable({}, {
			__index = OriginalIndex,
		})

		assert(Object.Hello == "original:Hello", "the test metamethod did not work before hooking.")

		local IndexOriginal = HookMetamethod(Object, "__index", function(_, Key)
			IndexCalls += 1
			return `hooked:{Key}`
		end)

		assert(type(IndexOriginal) == "function", "hookmetamethod did not return the original metamethod.")
		assert(Object.Hello == "hooked:Hello", "the hooked __index was not invoked.")
		assert(IndexCalls == 1, "the hooked __index was not invoked exactly once.")
		assert(
			IndexOriginal(Object, "Hello") == "original:Hello",
			"the returned original does not run the original metamethod."
		)

		HookMetamethod(Object, "__index", IndexOriginal)

		assert(Object.Hello == "original:Hello", "restoring __index did not restore the original metamethod.")
		assert(IndexCalls == 1, "the hook still ran after restoring __index.")

		local NamecallCalls = 0
		local GameOriginal

		GameOriginal = HookMetamethod(game, "__namecall", function(...)
			NamecallCalls += 1
			return GameOriginal(...)
		end)

		assert(type(GameOriginal) == "function", "hookmetamethod did not return the original __namecall.")

		local Workspace = game:FindFirstChild("Workspace")

		HookMetamethod(game, "__namecall", GameOriginal)

		assert(NamecallCalls >= 1, "the hooked __namecall was never invoked.")
		assert(typeof(Workspace) == "Instance", "the original __namecall was not called through the hook.")

		local Before = NamecallCalls
		game:FindFirstChild("Players")

		assert(NamecallCalls == Before, "the hook still ran after restoring __namecall.")

		return "intercepted and restored a table metamethod, and forwarded an Instance namecall."
	end,
})

Test({
	Name = "restorefunction",
	Description = "Restores a previously hooked function to its original state.",
	Function = function(RestoreFunction)
		local HookFunction = hookfunction
		assert(HookFunction, "hookfunction not available, cannot properly test restorefunction.")

		local TargetCalls = 0
		local OtherCalls = 0

		local function Target(A, B)
			return A + B
		end

		local function Other()
			return "other"
		end

		local OtherOriginal = HookFunction(Other, function()
			OtherCalls += 1
			return "other-hooked"
		end)

		local TargetOriginal = HookFunction(Target, function()
			TargetCalls += 1
			return "hooked"
		end)

		assert(type(TargetOriginal) == "function", "hookfunction did not return the original function.")
		assert(Target(2, 3) == "hooked", "the hook was not installed before testing restorefunction.")
		assert(TargetCalls == 1, "the hook was not called before testing restorefunction.")

		RestoreFunction(Target)

		assert(Target(2, 3) == 5, "restorefunction did not restore the original behaviour.")
		assert(TargetCalls == 1, "the hook still ran after restorefunction.")
		assert(Other() == "other-hooked" and OtherCalls == 1, "restorefunction affected an unrelated hooked function.")

		HookFunction(Other, OtherOriginal)

		assert(Other() == "other", "restoring the unrelated function failed.")

		return "restored only the hooked function it was given."
	end,
})

Test({
	Name = "iscclosure",
	Description = "Reports whether a function is a C closure.",
	Function = function(Target)
		local NativeFunction = math.floor
		local LuaFunction = function()
			return 1
		end

		assert(Target(NativeFunction) == true, "identified a native C function as a Luau closure.")
		assert(Target(LuaFunction) == false, "identified a Luau closure as a C closure.")

		return "correctly told native C functions and Luau closures apart."
	end,
})

Test({
	Name = "isexecutorclosure",
	Description = "Reports whether a function belongs to the executor.",
	Function = function(Target)
		local NativeFunction = math.floor
		local ScriptFunction = function()
			return 1
		end

		assert(Target(NativeFunction) == false, "identified a native C function as an executor closure.")
		-- assert(Target(ScriptFunction) == false, "identified a script closure as an executor closure."), bad check: executors can count our functions as executor's since the executor makes them
		assert(Target(Target) == true, "did not identify the executor's own function as an executor closure.")

		return "identified the executor closure and rejected native and script closures."
	end,
})

Test({
	Name = "isfunctionhooked",
	Description = "Reports whether a function has been replaced by a hook.",
	Function = function(Target)
		assert(type(hookfunction) == "function", "hookfunction not available, cannot properly test isfunctionhooked.")

		local Original = function(A, B)
			return A + B
		end

		assert(Target(Original) == false, "identified an unhooked function as hooked.")

		local Restore = hookfunction(Original, function(A, B)
			return A + B
		end)

		assert(Target(Original) == true, "failed to detect a function that was just hooked.")

		restorefunction(Original)

		assert(Target(Original) == false, "still reported the function as hooked after restoring it.")

		return "detected a hooked function and saw it unhooked again after restoring."
	end,
})

Test({
	Name = "islclosure",
	Description = "Reports whether a function is a Luau closure.",
	Function = function(Target)
		local NativeFunction = math.floor
		local LuaFunction = function()
			return 1
		end

		local Captured = 1
		local CapturingFunction = function()
			return Captured
		end

		assert(Target(LuaFunction) == true, "identified a Luau closure as a C closure.")
		assert(Target(CapturingFunction) == true, "identified a capturing Luau closure as a C closure.")
		assert(Target(NativeFunction) == false, "identified a native C function as a Luau closure.")

		return "correctly told Luau closures and native C functions apart."
	end,
})

Test({
	Name = "isnewcclosure",
	Description = "Reports whether a function was produced by newcclosure.",
	Function = function(Target)
		assert(type(newcclosure) == "function", "newcclosure not available, cannot properly test isnewcclosure.")

		local Original = function()
			return 1
		end

		local Wrapped = newcclosure(Original)

		assert(Target(Wrapped) == true, "did not recognise a function produced by newcclosure.")
		assert(Target(Original) == false, "identified a plain Luau closure as a newcclosure.")
		assert(Target(math.floor) == false, "identified a native C function as a newcclosure.")

		return "recognised newcclosure wrappers and rejected plain and native functions."
	end,
})

Test({
	Name = "newcclosure",
	Description = "Wraps a function into a C closure while preserving its behaviour.",
	Function = function(Target)
		local Calls = 0

		local Original = function(A, B)
			Calls += 1
			return A + B, A * B
		end

		local Wrapped = Target(Original)

		assert(type(Wrapped) == "function", "newcclosure did not return a function.")
		assert(Wrapped ~= Original, "newcclosure returned the original function.")

		local First, Second = Wrapped(2, 3)

		assert(First == 5 and Second == 6, "the wrapped function changed the return values.")
		assert(Calls == 1, "the wrapped function did not call the original exactly once.")

		if type(iscclosure) == "function" then
			assert(iscclosure(Wrapped) == true, "the wrapped function is not a C closure.")
		end

		return "wrapped a function into a C closure without changing its behaviour."
	end,
})

Test({
	Name = "newlclosure",
	Description = "Wraps a function into a Luau closure while preserving its behaviour.",
	Function = function(Target)
		local Calls = 0

		local Original = function(A, B)
			Calls += 1
			return A + B
		end

		local Wrapped = Target(Original)

		assert(type(Wrapped) == "function", "newlclosure did not return a function.")
		assert(Wrapped ~= Original, "newlclosure returned the original function.")
		assert(Wrapped(2, 3) == 5, "the wrapped function changed the return value.")
		assert(Calls == 1, "the wrapped function did not call the original exactly once.")

		if type(islclosure) == "function" then
			assert(islclosure(Wrapped) == true, "the wrapped function is not a Luau closure.")
		end

		return "wrapped a function into a Luau closure without changing its behaviour."
	end,
})

Report("Closure")

SetCategory("Environment")

Test({
	Name = "getgenv",
	Description = "Returns the executor's global environment table.",
	Function = function(Target)
		local Environment = Target()

		assert(type(Environment) == "table", "getgenv did not return a table.")

		local Key = "GeneralTestingConvention_" .. math.random(1, 1000000000)
		Environment[Key] = true

		local GetRenV = GetFunctionFromName("getrenv")
		local Leaked = false

		if type(GetRenV) == "function" then
			local Success, GameEnvironment = pcall(GetRenV)

			if Success and type(GameEnvironment) == "table" then
				local Inner = rawget(GameEnvironment, "_G")
				Leaked = type(Inner) == "table" and rawget(Inner, Key) ~= nil
			end
		end

		Environment[Key] = nil

		assert(not Leaked, "getgenv leaked a key into the game environment.")

		return "returned a table that is separate from the game environment."
	end,
})

Test({
	Name = "getrenv",
	Description = "Returns the game's environment table without executor additions.",
	Function = function(Target)
		local Environment = Target()

		assert(type(Environment) == "table", "getrenv did not return a table.")
		assert(type(Environment.print) == "function", "getrenv is missing the standard library.")
		assert(Environment.getgenv == nil, "getrenv contains executor-only functions.")

		return "returned the game environment without executor additions."
	end,
})

Test({
	Name = "getthreadidentity",
	Description = "Returns the identity of the current thread.",
	Function = function(Target)
		local Identity = Target()

		assert(type(Identity) == "number", "getthreadidentity did not return a number.")
		assert(Identity > 0, "getthreadidentity returned a non-positive identity.")

		return `returned an identity of {Identity}.`
	end,
})

Test({
	Name = "setthreadidentity",
	Description = "Changes the identity of the current thread.",
	Function = function(Target)
		local GetIdentity = GetFunctionFromName("getthreadidentity") or GetFunctionFromName("getthreadcontext")

		assert(type(GetIdentity) == "function", "getthreadidentity is required to test setthreadidentity.")

		local Original = GetIdentity()
		local Success = pcall(Target, 3)
		local Shifted = GetIdentity()

		pcall(Target, Original)

		assert(Success, "setthreadidentity errored while changing the identity.")
		assert(Shifted == 3, `setthreadidentity set the identity to {tostring(Shifted)} instead of 3.`)

		return "changed the thread identity and restored it."
	end,
})

Test({
	Name = "identifyexecutor",
	Description = "Returns the name of the executor.",
	Function = function(Target)
		local Name = Target()

		assert(type(Name) == "string", "identifyexecutor did not return a string.")
		assert(#Name > 0, "identifyexecutor returned an empty string.")

		return `identified the executor as {Name}.`
	end,
})

Test({
	Name = "getreg",
	Description = "Returns the Luau registry table.",
	Function = function(Target)
		local Registry = Target()

		assert(type(Registry) == "table", "getreg did not return a table.")

		local Count = 0

		for _ in pairs(Registry) do
			Count += 1
		end

		assert(Count > 0, "getreg returned an empty registry.")

		return `returned a registry containing {Count} entries.`
	end,
})

Report("Environment")

SetCategory("FileSystem")

Test({
	Name = "writefile",
	Description = "Writes a string to a file in the workspace.",
	Function = function(Target)
		local IsFile = GetFunctionFromName("isfile")
		local ReadFile = GetFunctionFromName("readfile")
		local DeleteFile = GetFunctionFromName("delfile")

		assert(
			type(IsFile) == "function" and type(ReadFile) == "function",
			"isfile and readfile are required to test writefile."
		)

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000) .. ".txt"
		local Contents = "hello from the General Testing Convention"

		Target(Name, Contents)

		local Exists = IsFile(Name)
		local Read = if Exists then ReadFile(Name) else nil

		if DeleteFile then
			pcall(DeleteFile, Name)
		end

		assert(Exists, "writefile did not create the file.")
		assert(Read == Contents, "writefile wrote different contents than it was given.")

		return "wrote a file that could be read back byte for byte."
	end,
})

Test({
	Name = "readfile",
	Description = "Reads the contents of a file in the workspace.",
	Function = function(Target)
		local WriteFile = GetFunctionFromName("writefile")
		local IsFile = GetFunctionFromName("isfile")
		local DeleteFile = GetFunctionFromName("delfile")

		assert(
			type(WriteFile) == "function" and type(IsFile) == "function",
			"writefile and isfile are required to test readfile."
		)

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000) .. ".txt"

		WriteFile(Name, "hello, world!")
		assert(IsFile(Name), "writefile did not create the file, cannot test readfile.")

		local Contents = Target(Name)

		if DeleteFile then
			pcall(DeleteFile, Name)
		end

		assert(type(Contents) == "string", "readfile did not return a string.")
		assert(Contents == "hello, world!", "readfile returned different contents than were written.")

		return "read back exactly what was written to the file."
	end,
})

Test({
	Name = "loadfile",
	Description = "Loads a file in the workspace as a chunk.",
	Function = function(Target)
		local WriteFile = GetFunctionFromName("writefile")
		local IsFile = GetFunctionFromName("isfile")
		local DeleteFile = GetFunctionFromName("delfile")

		assert(
			type(WriteFile) == "function" and type(IsFile) == "function",
			"writefile and isfile are required to test loadfile."
		)

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000) .. ".txt"

		WriteFile(Name, "return 'hello world'")
		assert(IsFile(Name), "writefile did not create the file, cannot test loadfile.")

		local Chunk = Target(Name)
		local Value = if type(Chunk) == "function" then Chunk() else nil

		if DeleteFile then
			pcall(DeleteFile, Name)
		end

		assert(type(Chunk) == "function", "loadfile did not return a chunk.")
		assert(Value == "hello world", "the chunk returned something other than what the file contained.")

		return "loaded a file into a chunk that ran and returned its value."
	end,
})

Test({
	Name = "isfile",
	Description = "Returns whether a path is an existing file.",
	Function = function(Target)
		local WriteFile = GetFunctionFromName("writefile")
		local DeleteFile = GetFunctionFromName("delfile")

		assert(type(WriteFile) == "function", "writefile is required to test isfile.")

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000) .. ".txt"

		WriteFile(Name, "hello world!")
		local Found = Target(Name)
		local StillFound = nil

		if DeleteFile then
			pcall(DeleteFile, Name)
			StillFound = Target(Name)
		end

		assert(Found == true, "did not see a file that writefile created.")

		if DeleteFile then
			assert(StillFound == false, "still saw a file after delfile removed it.")
		end

		return "saw files that exist and not files that were deleted."
	end,
})

Test({
	Name = "delfile",
	Description = "Deletes a file in the workspace.",
	Function = function(Target)
		local WriteFile = GetFunctionFromName("writefile")
		local IsFile = GetFunctionFromName("isfile")

		assert(
			type(WriteFile) == "function" and type(IsFile) == "function",
			"writefile and isfile are required to test delfile."
		)

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000) .. ".txt"

		WriteFile(Name, "testing delfile")
		assert(IsFile(Name), "writefile did not create the file, cannot test delfile.")

		Target(Name)

		assert(not IsFile(Name), "the file still exists after delfile.")

		return "removed a file from the workspace."
	end,
})

Test({
	Name = "makefolder",
	Description = "Creates a folder in the workspace.",
	Function = function(Target)
		local IsFolder = GetFunctionFromName("isfolder")
		local DeleteFolder = GetFunctionFromName("delfolder")

		assert(type(IsFolder) == "function", "isfolder is required to test makefolder.")

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000)

		Target(Name)

		local Exists = IsFolder(Name)

		if DeleteFolder then
			pcall(DeleteFolder, Name)
		end

		assert(Exists == true, "makefolder did not create the folder.")

		return "created a folder that isfolder could see."
	end,
})

Test({
	Name = "isfolder",
	Description = "Returns whether a path is an existing folder.",
	Function = function(Target)
		local MakeFolder = GetFunctionFromName("makefolder")
		local DeleteFolder = GetFunctionFromName("delfolder")

		assert(type(MakeFolder) == "function", "makefolder is required to test isfolder.")

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000)

		MakeFolder(Name)
		local Exists = Target(Name)
		local StillExists = nil

		if DeleteFolder then
			pcall(DeleteFolder, Name)
			StillExists = Target(Name)
		end

		assert(Exists == true, "did not see a folder that makefolder created.")

		if DeleteFolder then
			assert(StillExists == false, "still saw a folder after delfolder removed it.")
		end

		return "saw folders that exist and not folders that were deleted."
	end,
})

Test({
	Name = "delfolder",
	Description = "Deletes a folder in the workspace.",
	Function = function(Target)
		local MakeFolder = GetFunctionFromName("makefolder")
		local IsFolder = GetFunctionFromName("isfolder")

		assert(
			type(MakeFolder) == "function" and type(IsFolder) == "function",
			"makefolder and isfolder are required to test delfolder."
		)

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000)

		MakeFolder(Name)
		assert(IsFolder(Name), "makefolder did not create the folder, cannot test delfolder.")

		Target(Name)

		assert(not IsFolder(Name), "the folder still exists after delfolder.")

		return "removed a folder from the workspace."
	end,
})

Test({
	Name = "appendfile",
	Description = "Appends a string to the end of a file in the workspace.",
	Function = function(Target)
		local WriteFile = GetFunctionFromName("writefile")
		local ReadFile = GetFunctionFromName("readfile")
		local DeleteFile = GetFunctionFromName("delfile")

		assert(
			type(WriteFile) == "function" and type(ReadFile) == "function",
			"writefile and readfile are required to test appendfile."
		)

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000) .. ".txt"

		WriteFile(Name, "base_payload")
		Target(Name, "_appended_payload")

		local Contents = ReadFile(Name)

		if DeleteFile then
			pcall(DeleteFile, Name)
		end

		assert(Contents == "base_payload_appended_payload", "appendfile did not add to the end of the file.")

		return "appended to a file without replacing its existing contents."
	end,
})

Test({
	Name = "listfiles",
	Description = "Returns the contents of a folder in the workspace.",
	Function = function(Target)
		local Success, Files = pcall(Target, "")

		if not Success then
			Success, Files = pcall(Target, ".")
		end

		if not Success then
			Success, Files = pcall(Target)
		end

		assert(Success, "listfiles errored on every argument form.")
		assert(type(Files) == "table", "listfiles did not return a table.")

		return `listed {#Files} entries.`
	end,
})

Report("FileSystem")

local function FindLocalScript()
	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local PlayerScripts = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerScripts")
	local Found = PlayerScripts and PlayerScripts:FindFirstChildWhichIsA("LocalScript", true)

	if not Found then
		Found = game:GetService("ReplicatedFirst"):FindFirstChildWhichIsA("LocalScript", true)
	end

	return Found
end

local function FindModuleScripts()
	local Found = {}

	local Containers = {
		game:GetService("ReplicatedStorage"),
		game:GetService("ReplicatedFirst"),
		game:GetService("StarterPlayer"),
		game:GetService("StarterGui"),
	}

	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local PlayerScripts = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerScripts")

	if PlayerScripts then
		table.insert(Containers, PlayerScripts)
	end

	for _, Container in ipairs(Containers) do
		for _, Item in ipairs(Container:GetDescendants()) do
			if Item:IsA("ModuleScript") then
				table.insert(Found, Item)

				if #Found >= 5 then
					return Found
				end
			end
		end
	end

	return Found
end

-- Local AES-256-CBC reference. Everything below is self contained so the suite never
-- depends on a file outside of itself.

local ReferenceKey = "GMVIsgHnxm0YDYwUGkBhtRWSrSsfRMjY"
local ReferenceIV = "1234567890abcdef"
local ReferenceCiphertext = "jxF03fu7V3WKm7b2oRMo9HYz+KVDymqKU29qmsiTP4E="

local Base64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function EncodeBase64(Data: string): string
	local Output = {}

	for Index = 1, #Data, 3 do
		local First, Second, Third = string.byte(Data, Index, Index + 2)
		local Combined = bit32.bor(bit32.lshift(First, 16), bit32.lshift(Second or 0, 8), Third or 0)

		local function Pick(Shift: number): string
			local Value = bit32.band(bit32.rshift(Combined, Shift), 63)

			return string.sub(Base64Alphabet, Value + 1, Value + 1)
		end

		Output[#Output + 1] = Pick(18)
		Output[#Output + 1] = Pick(12)
		Output[#Output + 1] = if Second then Pick(6) else "="
		Output[#Output + 1] = if Third then Pick(0) else "="
	end

	return table.concat(Output)
end

local Base64Values = {}

for Index = 1, #Base64Alphabet do
	Base64Values[string.sub(Base64Alphabet, Index, Index)] = Index - 1
end

local function DecodeBase64(Data: string): string
	local Output = {}
	local Buffer, Bits = 0, 0

	for Index = 1, #Data do
		local Character = string.sub(Data, Index, Index)

		if Character == "=" then
			break
		end

		local Value = Base64Values[Character]

		assert(Value, `{Data} is not valid base64.`)

		Buffer = bit32.bor(bit32.lshift(Buffer, 6), Value)
		Bits += 6

		if Bits >= 8 then
			Bits -= 8
			Output[#Output + 1] = string.char(bit32.band(bit32.rshift(Buffer, Bits), 255))
		end
	end

	return table.concat(Output)
end

local AESSubstitution = {
	99,
	124,
	119,
	123,
	242,
	107,
	111,
	197,
	48,
	1,
	103,
	43,
	254,
	215,
	171,
	118,
	202,
	130,
	201,
	125,
	250,
	89,
	71,
	240,
	173,
	212,
	162,
	175,
	156,
	164,
	114,
	192,
	183,
	253,
	147,
	38,
	54,
	63,
	247,
	204,
	52,
	165,
	229,
	241,
	113,
	216,
	49,
	21,
	4,
	199,
	35,
	195,
	24,
	150,
	5,
	154,
	7,
	18,
	128,
	226,
	235,
	39,
	178,
	117,
	9,
	131,
	44,
	26,
	27,
	110,
	90,
	160,
	82,
	59,
	214,
	179,
	41,
	227,
	47,
	132,
	83,
	209,
	0,
	237,
	32,
	252,
	177,
	91,
	106,
	203,
	190,
	57,
	74,
	76,
	88,
	207,
	208,
	239,
	170,
	251,
	67,
	77,
	51,
	133,
	69,
	249,
	2,
	127,
	80,
	60,
	159,
	168,
	81,
	163,
	64,
	143,
	146,
	157,
	56,
	245,
	188,
	182,
	218,
	33,
	16,
	255,
	243,
	210,
	205,
	12,
	19,
	236,
	95,
	151,
	68,
	23,
	196,
	167,
	126,
	61,
	100,
	93,
	25,
	115,
	96,
	129,
	79,
	220,
	34,
	42,
	144,
	136,
	70,
	238,
	184,
	20,
	222,
	94,
	11,
	219,
	224,
	50,
	58,
	10,
	73,
	6,
	36,
	92,
	194,
	211,
	172,
	98,
	145,
	149,
	228,
	121,
	231,
	200,
	55,
	109,
	141,
	213,
	78,
	169,
	108,
	86,
	244,
	234,
	101,
	122,
	174,
	8,
	186,
	120,
	37,
	46,
	28,
	166,
	180,
	198,
	232,
	221,
	116,
	31,
	75,
	189,
	139,
	138,
	112,
	62,
	181,
	102,
	72,
	3,
	246,
	14,
	97,
	53,
	87,
	185,
	134,
	193,
	29,
	158,
	225,
	248,
	152,
	17,
	105,
	217,
	142,
	148,
	155,
	30,
	135,
	233,
	206,
	85,
	40,
	223,
	140,
	161,
	137,
	13,
	191,
	230,
	66,
	104,
	65,
	153,
	45,
	15,
	176,
	84,
	187,
	22,
}

local AESRoundConstants = { 1, 2, 4, 8, 16, 32, 64, 128, 27, 54, 108, 216, 171, 77 }

local function AESMultiply(Value: number): number
	local Doubled = bit32.band(bit32.lshift(Value, 1), 255)

	if bit32.band(Value, 128) ~= 0 then
		Doubled = bit32.bxor(Doubled, 27)
	end

	return Doubled
end

local function AESExpandKey(Key: string)
	local Bytes = {}

	for Index = 1, #Key do
		Bytes[Index] = string.byte(Key, Index)
	end

	local Words = #Bytes // 4
	local Rounds = Words + 6
	local Schedule = {}

	for Index = 1, Words do
		Schedule[Index] = { Bytes[Index * 4 - 3], Bytes[Index * 4 - 2], Bytes[Index * 4 - 1], Bytes[Index * 4] }
	end

	for Index = Words + 1, 4 * (Rounds + 1) do
		local Word = table.clone(Schedule[Index - 1])
		local Step = (Index - 1) % Words

		if Step == 0 then
			Word = { Word[2], Word[3], Word[4], Word[1] }

			for Position = 1, 4 do
				Word[Position] = AESSubstitution[Word[Position] + 1]
			end

			Word[1] = bit32.bxor(Word[1], AESRoundConstants[(Index - 1) // Words])
		elseif Words > 6 and Step == 4 then
			for Position = 1, 4 do
				Word[Position] = AESSubstitution[Word[Position] + 1]
			end
		end

		local Previous = Schedule[Index - Words]

		Schedule[Index] = {
			bit32.bxor(Previous[1], Word[1]),
			bit32.bxor(Previous[2], Word[2]),
			bit32.bxor(Previous[3], Word[3]),
			bit32.bxor(Previous[4], Word[4]),
		}
	end

	return Schedule, Rounds
end

local function AESEncryptBlock(Schedule, Rounds: number, Input: { number }): { number }
	local State = table.clone(Input)

	local function AddRoundKey(Round: number)
		for Index = 0, 15 do
			State[Index + 1] = bit32.bxor(State[Index + 1], Schedule[Round * 4 + Index // 4 + 1][Index % 4 + 1])
		end
	end

	local function Substitute()
		for Index = 1, 16 do
			State[Index] = AESSubstitution[State[Index] + 1]
		end
	end

	local function Shift()
		local Copy = table.clone(State)

		for Row = 1, 3 do
			for Column = 0, 3 do
				State[Column * 4 + Row + 1] = Copy[(Column + Row) % 4 * 4 + Row + 1]
			end
		end
	end

	local function Mix()
		for Column = 0, 3 do
			local First, Second, Third, Fourth =
				State[Column * 4 + 1], State[Column * 4 + 2], State[Column * 4 + 3], State[Column * 4 + 4]
			local Total = bit32.bxor(First, Second, Third, Fourth)

			State[Column * 4 + 1] = bit32.bxor(First, Total, AESMultiply(bit32.bxor(First, Second)))
			State[Column * 4 + 2] = bit32.bxor(Second, Total, AESMultiply(bit32.bxor(Second, Third)))
			State[Column * 4 + 3] = bit32.bxor(Third, Total, AESMultiply(bit32.bxor(Third, Fourth)))
			State[Column * 4 + 4] = bit32.bxor(Fourth, Total, AESMultiply(bit32.bxor(Fourth, First)))
		end
	end

	AddRoundKey(0)

	for Round = 1, Rounds - 1 do
		Substitute()
		Shift()
		Mix()
		AddRoundKey(Round)
	end

	Substitute()
	Shift()
	AddRoundKey(Rounds)

	return State
end

local function AESEncryptCBC(Plaintext: string, Key: string, IV: string): string
	local Schedule, Rounds = AESExpandKey(Key)
	local Previous = {}

	for Index = 1, 16 do
		Previous[Index] = string.byte(IV, Index)
	end

	local Padding = 16 - #Plaintext % 16
	local Padded = Plaintext .. string.rep(string.char(Padding), Padding)
	local Output = {}

	for Index = 1, #Padded, 16 do
		local Block = {}

		for Offset = 1, 16 do
			Block[Offset] = bit32.bxor(string.byte(Padded, Index + Offset - 1), Previous[Offset])
		end

		Previous = AESEncryptBlock(Schedule, Rounds, Block)

		for Offset = 1, 16 do
			Output[#Output + 1] = string.char(Previous[Offset])
		end
	end

	return table.concat(Output)
end

local function AssertReference()
	assert(
		EncodeBase64(AESEncryptCBC("1234567890abcdef", ReferenceKey, ReferenceIV)) == ReferenceCiphertext,
		"the local AES reference disagreed with the known reference vector."
	)
end

SetCategory("Crypt")

Test({
	Name = "base64_encode",
	Description = "Encodes a string into base64.",
	Function = function(Target)
		local Encoded = Target("hello world")

		assert(type(Encoded) == "string", "base64_encode did not return a string.")
		assert(Encoded == "aGVsbG8gd29ybGQ=", `base64_encode returned {Encoded} instead of aGVsbG8gd29ybGQ=.`)

		return "encoded a known string to the expected base64 value."
	end,
})

Test({
	Name = "base64_decode",
	Description = "Decodes a base64 string back into text.",
	Function = function(Target)
		local Decoded = Target("aGVsbG8gd29ybGQ=")

		assert(type(Decoded) == "string", "base64_decode did not return a string.")
		assert(Decoded == "hello world", `base64_decode returned {Decoded} instead of hello world.`)

		return "decoded a known base64 value to the expected string."
	end,
})

Test({
	Name = "lz4compress",
	Description = "Compresses a string with LZ4.",
	Function = function(Target)
		local Data = "test_lz4_string_compression_data_123!"
		local Compressed = Target(Data)

		assert(type(Compressed) == "string", "lz4compress did not return a string.")
		assert(Compressed ~= Data, "lz4compress returned the input unchanged.")

		return "compressed data into a different string."
	end,
})

Test({
	Name = "lz4decompress",
	Description = "Decompresses an LZ4 compressed string.",
	Function = function(Target)
		local Compress = GetFunctionFromName("lz4compress")

		assert(type(Compress) == "function", "lz4compress is required to test lz4decompress.")

		local Data = "test_lz4_string_compression_data_123!"
		local Decompressed = Target(Compress(Data), #Data)

		assert(type(Decompressed) == "string", "lz4decompress did not return a string.")
		assert(Decompressed == Data, "lz4decompress did not rebuild the original data.")

		return "rebuilt the original data from a compressed string."
	end,
})

Test({
	Name = "crypt.encrypt",
	Description = "Encrypts a string with AES-256-CBC using a Base64 key and IV.",
	Function = function(Target)
		AssertReference()

		local Plaintext = "GeneralTestingConvention_encryption"
		local Expected = EncodeBase64(AESEncryptCBC(Plaintext, ReferenceKey, ReferenceIV))
		local Success, Encrypted =
			pcall(Target, Plaintext, EncodeBase64(ReferenceKey), EncodeBase64(ReferenceIV), "CBC")

		assert(Success, `crypt.encrypt errored: {tostring(Encrypted)}.`)
		assert(type(Encrypted) == "string", `crypt.encrypt returned {typeof(Encrypted)}, not a string.`)
		assert(Encrypted == Expected, "crypt.encrypt did not match the reference ciphertext.")

		return "encrypted a string to the reference ciphertext."
	end,
})

Test({
	Name = "crypt.decrypt",
	Description = "Decrypts Base64 AES-256-CBC ciphertext using a Base64 key and IV.",
	Function = function(Target)
		AssertReference()

		local Plaintext = "GeneralTestingConvention_encryption"
		local Ciphertext = EncodeBase64(AESEncryptCBC(Plaintext, ReferenceKey, ReferenceIV))
		local Success, Decrypted =
			pcall(Target, Ciphertext, EncodeBase64(ReferenceKey), EncodeBase64(ReferenceIV), "CBC")

		assert(Success, `crypt.decrypt errored: {tostring(Decrypted)}.`)
		assert(type(Decrypted) == "string", `crypt.decrypt returned {typeof(Decrypted)}, not a string.`)
		assert(Decrypted == Plaintext, "crypt.decrypt did not return the original string.")

		return "decrypted the reference ciphertext back to the original string."
	end,
})

Test({
	Name = "crypt.hash",
	Description = "Hashes a string with the requested algorithm.",
	Function = function(Target)
		local Digests = {
			{ "md5", "aa39362cc72b25918aaf443d3c7e86ef" },
			{ "sha1", "8a0e38abbd784796e0ceb2455098bfbd31d1551f" },
			{ "sha224", "6217b88a947fcf19f3266a1e68645db03892f301fc78d1b594678e72" },
			{ "sha256", "0597955faf24cde12e5f91f77794a0a938108bca686df0cad269489140889068" },
			{
				"sha384",
				"368c5054df9ffab72c8c1bb8b46f8376cd8dc9aafb62e0970453a01dd203b384c4806b24e4f025832353467e2cfe8bff",
			},
			{
				"sha512",
				"6454bf8242f5184e3c770afdf098f8f11ec1d4f6bc09f68923efdb27b97c45583e2211df38d42c282ca64429b4af3b54e42003c15d9df5c182f85605c5dd749d",
			},
			{ "sha3-256", "406ea26a267c8eda63ae494c35e86e26d5b83b67af1074de8c3b65dcf74fab16" },
			{
				"sha3-384",
				"57a8309bb9f263d50b481f176e1463d70e6fa50e4bcac9e7f5e0c20aae3dc8661dffd17649b22a29ae19e815bdb51e13",
			},
			{
				"sha3-512",
				"4776a57dc3c5611a09d868a9adfba256484a95c7923a408d3274330f3d1e46a1dcd26a77fb9690c90111e182e303710f0d40fbd6957c2f5da0d4f7828b16dde9",
			},
		}

		for _, Entry in ipairs(Digests) do
			local Algorithm, Expected = Entry[1], Entry[2]
			local Success, Actual = pcall(Target, "MYRIAD", Algorithm)

			assert(Success, `crypt.hash({Algorithm}) errored: {tostring(Actual)}.`)
			assert(type(Actual) == "string", `crypt.hash({Algorithm}) returned {typeof(Actual)}.`)
			assert(string.lower(Actual) == Expected, `crypt.hash({Algorithm}) returned the wrong digest.`)
		end

		return "hashed a string with every supported algorithm."
	end,
})

Test({
	Name = "crypt.hmac",
	Description = "Signs a string with HMAC-SHA256 using the given key.",
	Function = function(Target)
		local Signature = Target("secret_key", "MYRIAD", "sha256")

		assert(type(Signature) == "string", `crypt.hmac returned {typeof(Signature)}.`)
		assert(
			Signature == "FaDPiTSLlbxRP5rKvomt0dzwl7zhszc46/QFPsZRGWY=",
			"crypt.hmac did not match the reference signature."
		)

		return "signed a string to the reference HMAC-SHA256 value."
	end,
})

Test({
	Name = "crypt.generatekey",
	Description = "Generates a random AES key as base64.",
	Function = function(Target)
		local First, Second = Target(), Target()

		assert(type(First) == "string", `crypt.generatekey returned {typeof(First)}.`)
		assert(type(Second) == "string", `crypt.generatekey returned {typeof(Second)}.`)

		local Length = #DecodeBase64(First)
		assert(Length == 32, `crypt.generatekey returned a {Length} byte key.`)
		assert(First ~= Second, "crypt.generatekey returned the same key twice.")

		return "generated two unique 32 byte keys."
	end,
})

Test({
	Name = "crypt.generatebytes",
	Description = "Generates random bytes as base64 in the requested size.",
	Function = function(Target)
		for _, Size in ipairs({ 1, 16, 255, 512 }) do
			local Encoded = Target(Size)

			assert(type(Encoded) == "string", `crypt.generatebytes({Size}) returned {typeof(Encoded)}.`)

			local Length = #DecodeBase64(Encoded)
			assert(Length == Size, `crypt.generatebytes({Size}) returned {Length} bytes.`)
		end

		assert(Target(16) ~= Target(16), "crypt.generatebytes returned the same bytes twice.")

		return "generated the requested amount of random bytes."
	end,
})

Test({
	Name = "crypt.random",
	Description = "Returns a string of random bytes with the requested length.",
	Function = function(Target)
		local Success, Bytes = pcall(Target, 64)

		assert(Success, `crypt.random(64) errored: {tostring(Bytes)}.`)
		assert(type(Bytes) == "string", `crypt.random returned {typeof(Bytes)}.`)
		assert(#Bytes == 64, `crypt.random(64) returned {#Bytes} bytes.`)
		assert(#Target(0) == 0, "crypt.random(0) did not return an empty string.")
		assert(#Target(512) == 512, "crypt.random(512) did not return 512 bytes.")
		assert(Target(32) ~= Target(32), "crypt.random returned the same bytes twice.")
		assert(not pcall(Target, -1), "crypt.random accepted a negative length.")

		return "returned random bytes of the requested length."
	end,
})

Report("Crypt")

SetCategory("Reflection")

Test({
	Name = "debug.getprotos",
	Description = "Returns every prototype nested inside a function.",
	Function = function(Target)
		local function Outer()
			return function()
				return "active"
			end
		end

		Outer()()

		local Protos = Target(Outer)

		assert(type(Protos) == "table", "debug.getprotos did not return a table.")
		assert(#Protos > 0 or next(Protos) ~= nil, "debug.getprotos returned no prototypes.")

		return "returned the nested prototypes of a function."
	end,
})

Test({
	Name = "debug.getproto",
	Description = "Returns a single nested prototype from a function.",
	Function = function(Target)
		local function Outer()
			return function()
				return "active"
			end
		end

		Outer()()

		local Success, Proto = pcall(Target, Outer, 1, true)

		if not Success or (type(Proto) ~= "function" and type(Proto) ~= "table") then
			Success, Proto = pcall(Target, Outer, 1)
		end

		assert(Success, "debug.getproto errored on both call forms.")
		assert(
			type(Proto) == "function" or type(Proto) == "table" or type(Proto) == "userdata",
			"debug.getproto did not return a prototype."
		)

		return "returned a nested prototype from a function."
	end,
})

Test({
	Name = "debug.getinfo",
	Description = "Returns an info table describing a function.",
	Function = function(Target)
		local function NoParameters()
			return "a"
		end

		local function ThreeParameters(A, B, C)
			return A
		end

		local Info = Target(NoParameters)
		local Info2 = Target(ThreeParameters)

		assert(type(Info) == "table" and type(Info2) == "table", "debug.getinfo did not return tables.")
		assert(type(Info.nups) ~= "number" or Info.nups >= 0, "debug.getinfo returned a negative upvalue count.")
		assert(Info.linedefined ~= -1, "debug.getinfo could not resolve the line the function was defined on.")
		assert(Info.func == NoParameters, "debug.getinfo returned a func that is not the function it was given.")

		if Info.numparams and Info2.numparams then
			assert(Info.numparams == 0, "debug.getinfo reported a parameter count for a function with none.")
			assert(Info2.numparams == 3, "debug.getinfo reported the wrong parameter count.")
		end

		return "returned a correct info table for both functions."
	end,
})

Test({
	Name = "debug.getupvalue",
	Description = "Returns a single upvalue of a closure.",
	Function = function(Target)
		local function MakeClosure(Value)
			return function()
				return Value
			end
		end

		local Closure = MakeClosure("target_upvalue_signature")
		local First, Second = Target(Closure, 1)

		assert(
			First == "target_upvalue_signature" or Second == "target_upvalue_signature",
			"debug.getupvalue did not return the value the closure captured."
		)

		return "read the first upvalue of a closure."
	end,
})

Test({
	Name = "debug.getupvalues",
	Description = "Returns every upvalue of a closure.",
	Function = function(Target)
		local function MakeClosure(Number, Text)
			return function()
				return Number, Text
			end
		end

		local Closure = MakeClosure(50, "string_state")
		local Upvalues = Target(Closure)

		assert(type(Upvalues) == "table", "debug.getupvalues did not return a table.")

		local SawNumber, SawText = false, false

		for _, Value in pairs(Upvalues) do
			if Value == 50 then
				SawNumber = true
			elseif Value == "string_state" then
				SawText = true
			end
		end

		assert(SawNumber and SawText, "debug.getupvalues did not include both captured values.")

		return "returned every upvalue the closure captured."
	end,
})

Test({
	Name = "debug.setupvalue",
	Description = "Changes the value of a closure's upvalue.",
	Function = function(Target)
		local function MakeClosure(Value)
			return function()
				return Value
			end
		end

		local Closure = MakeClosure("initial_state")

		local Success = pcall(Target, Closure, 1, "mutated_state")

		if not Success then
			Success = pcall(Target, Closure, "Value", "mutated_state")
		end

		assert(Success, "debug.setupvalue errored on both call forms.")
		assert(Closure() == "mutated_state", "debug.setupvalue did not change what the closure returns.")

		return "changed an upvalue and the closure saw the new value."
	end,
})

Test({
	Name = "debug.getconstant",
	Description = "Returns a constant from a function's constant table.",
	Function = function(Target)
		local function Sample()
			return "test_constant_val"
		end

		local Found = false

		for Index = 1, 10 do
			local Success, Constant = pcall(Target, Sample, Index)

			if Success and Constant == "test_constant_val" then
				Found = true
				break
			end
		end

		assert(Found, "debug.getconstant could not find the constant the function returns.")

		return "found a known constant in a function's constant table."
	end,
})

Test({
	Name = "debug.getconstants",
	Description = "Returns the constant table of a function.",
	Function = function(Target)
		local Compile = GetFunctionFromName("loadstring") or loadstring

		assert(type(Compile) == "function", "loadstring is required to build a test function.")

		local Marker = `original_constants_val_{math.random(1, 1000000000)}`
		local Factory = Compile(`return function() return "{Marker}" end`)

		assert(type(Factory) == "function", "could not compile the test function.")

		local Sample = Factory()
		local Constants = Target(Sample)

		assert(type(Constants) == "table", "debug.getconstants did not return a table.")

		local Found = false

		for _, Constant in pairs(Constants) do
			if Constant == Marker then
				Found = true
				break
			end
		end

		assert(Found, "debug.getconstants did not include the constant the function returns.")

		return "found a known constant in a function's constant table."
	end,
})

Test({
	Name = "debug.setconstant",
	Description = "Replaces a constant in a function's constant table.",
	Function = function(Target)
		local GetConstant = GetFunctionFromName("debug.getconstant")

		assert(type(GetConstant) == "function", "debug.getconstant is required to test debug.setconstant.")

		-- Constant tables live on the compiled prototype, so a literal written in
		-- this file would already be modified by a second run in the same session.
		-- Compile a fresh function with a unique literal instead.
		local Compile = GetFunctionFromName("loadstring") or loadstring

		assert(type(Compile) == "function", "loadstring is required to build a test function.")

		local Marker = `original_constant_val_{math.random(1, 1000000000)}`
		local Factory = Compile(`return function() return "{Marker}" end`)

		assert(type(Factory) == "function", "could not compile the test function.")

		local Sample = Factory()

		local Index = nil

		for Candidate = 1, 10 do
			local Success, Constant = pcall(GetConstant, Sample, Candidate)

			if Success and Constant == Marker then
				Index = Candidate
				break
			end
		end

		assert(Index ~= nil, "could not find the constant to replace.")

		local Success = pcall(Target, Sample, Index, "altered_constant_val")

		assert(Success, "debug.setconstant errored while replacing a constant.")
		assert(Sample() == "altered_constant_val", "debug.setconstant did not change what the function returns.")

		return "replaced a constant and the function returned the new value."
	end,
})

Test({
	Name = "debug.getstack",
	Description = "Returns the values on a stack level.",
	Function = function(Target)
		local function Capture()
			return Target(1)
		end

		local Success, Stack = pcall(Capture)

		assert(Success, "debug.getstack errored.")
		assert(type(Stack) == "table", "debug.getstack did not return a table.")

		local Count = 0

		for _ in pairs(Stack) do
			Count += 1
		end

		assert(Count > 0, "debug.getstack returned an empty stack.")

		return `returned a stack table with {Count} values.`
	end,
})

Test({
	Name = "debug.setstack",
	Description = "Writes a value onto a stack level.",
	Function = function(Target)
		local GetStack = GetFunctionFromName("debug.getstack")

		assert(type(GetStack) == "function", "debug.getstack is required to test debug.setstack.")

		local function Write()
			local Stack = GetStack(1)

			if type(Stack) ~= "table" then
				return nil, "debug.getstack did not return a table."
			end

			local Slots = {}

			for Index in pairs(Stack) do
				if type(Index) == "number" then
					table.insert(Slots, Index)
				end
			end

			table.sort(Slots)

			local Reason = "debug.getstack returned no numeric slots."

			for _, Slot in ipairs(Slots) do
				if pcall(Target, 2, Slot, Stack[Slot]) or pcall(Target, 1, Slot, Stack[Slot]) then
					return Slot, nil
				end

				Reason = select(2, pcall(Target, 2, Slot, Stack[Slot]))
			end

			return nil, Reason
		end

		local Slot, Reason = Write()

		assert(Slot ~= nil, `debug.setstack did not accept a write to any stack slot: {tostring(Reason)}`)

		return `wrote an existing value back to stack slot {Slot}.`
	end,
})

Test({
	Name = "getrendersteppedlist",
	Description = "Returns every callback bound with BindToRenderStep.",
	Function = function(Target)
		local RunService = game:GetService("RunService")
		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000)
		local Priority = Enum.RenderPriority.Camera.Value + 1

		local Bound = pcall(function()
			RunService:BindToRenderStep(Name, Priority, function() end)
		end)

		assert(Bound, "could not bind a render step to test getrendersteppedlist.")

		local Success, List = pcall(Target)

		pcall(function()
			RunService:UnbindFromRenderStep(Name)
		end)

		assert(Success, `getrendersteppedlist errored: {tostring(List)}`)
		assert(type(List) == "table", "getrendersteppedlist did not return a table.")

		local Found = nil

		for _, Entry in ipairs(List) do
			if type(Entry) == "table" and Entry.Name == Name then
				Found = Entry
				break
			end
		end

		assert(Found ~= nil, "getrendersteppedlist did not include a render step that was just bound.")
		assert(type(Found.Priority) == "number", "the returned entry has no numeric Priority.")
		assert(
			Found.Priority == Priority,
			`the returned entry has priority {tostring(Found.Priority)} instead of {Priority}.`
		)
		assert(
			type(Found.Function) == "function" or type(Found.Thread) == "thread",
			"the returned entry has neither a Function nor a Thread."
		)

		local _, After = pcall(Target)

		if type(After) == "table" then
			for _, Entry in ipairs(After) do
				assert(
					not (type(Entry) == "table" and Entry.Name == Name),
					"getrendersteppedlist still listed a render step after it was unbound."
				)
			end
		end

		return "listed a bound render step and dropped it after unbinding."
	end,
})

Report("Reflection")

SetCategory("Script")

Test({
	Name = "getscripthash",
	Description = "Returns the hash of a script's bytecode.",
	Function = function(Target)
		local Script = FindLocalScript()

		assert(Script ~= nil, "no LocalScript was available to hash.")

		local Hash = Target(Script)

		assert(type(Hash) == "string", "getscripthash did not return a string.")
		assert(#Hash == 96 or #Hash == 64, `the hash was {#Hash} characters, expected 96 (SHA-384) or 64 (SHA-256).`)

		return "hashed a live script to a SHA-384 or SHA-256 length string."
	end,
})

Test({
	Name = "getscriptbytecode",
	Description = "Returns the bytecode of a script.",
	Function = function(Target)
		local Script = FindLocalScript()

		assert(Script ~= nil, "no LocalScript was available to read bytecode from.")

		local Bytecode = Target(Script)

		assert(type(Bytecode) == "string", "getscriptbytecode did not return a string.")
		assert(#Bytecode > 0, "getscriptbytecode returned an empty string.")

		return `returned {#Bytecode} bytes of bytecode.`
	end,
})

Test({
	Name = "getscriptclosure",
	Description = "Returns the main closure of a script.",
	Function = function(Target)
		local Script = FindLocalScript()

		assert(Script ~= nil, "no LocalScript was available to turn into a closure.")

		local Closure = Target(Script)

		assert(type(Closure) == "function", "getscriptclosure did not return a function.")

		return "returned a closure for a live script and refused one with no bytecode."
	end,
})

Test({
	Name = "getscripts",
	Description = "Returns every script in the game.",
	Function = function(Target)
		local Scripts = Target()

		assert(type(Scripts) == "table", "getscripts did not return a table.")
		assert(#Scripts > 0, "getscripts returned an empty table.")
		assert(typeof(Scripts[1]) == "Instance", "getscripts returned something that is not an Instance.")

		return `returned {#Scripts} script instances.`
	end,
})

Test({
	Name = "getrunningscripts",
	Description = "Returns every script that is currently running.",
	Function = function(Target)
		local Scripts = Target()

		assert(type(Scripts) == "table", "getrunningscripts did not return a table.")
		assert(#Scripts > 0, "getrunningscripts returned an empty table.")
		assert(#Scripts < 5000, `getrunningscripts returned {#Scripts} entries, which looks like a full Instance dump.`)

		return `returned {#Scripts} running scripts.`
	end,
})

Test({
	Name = "getcallingscript",
	Description = "Returns the script that is calling the executor.",
	Function = function(Target)
		local Script = Target()

		assert(Script == nil or typeof(Script) == "Instance", "getcallingscript did not return an Instance or nil.")

		return "returned a script instance or nil outside of a script context."
	end,
})

Test({
	Name = "getloadedmodules",
	Description = "Returns every ModuleScript the game has loaded.",
	Function = function(Target)
		local Modules = Target()

		assert(type(Modules) == "table", "getloadedmodules did not return a table.")
		assert(#Modules > 0, "getloadedmodules returned an empty table.")

		local Invalid = 0

		for Index = 1, math.min(#Modules, 10) do
			local Module = Modules[Index]

			if typeof(Module) ~= "Instance" or not Module:IsA("ModuleScript") then
				Invalid += 1
			end
		end

		assert(Invalid == 0, `{Invalid} of the checked entries were not ModuleScripts.`)

		return `returned {#Modules} loaded modules.`
	end,
})

Test({
	Name = "getsenv",
	Description = "Returns the environment table of a running script.",
	Function = function(Target)
		local GetRunningScripts = GetFunctionFromName("getrunningscripts")

		assert(type(GetRunningScripts) == "function", "getrunningscripts is required to test getsenv.")

		local Running = GetRunningScripts()

		if type(Running) ~= "table" or #Running == 0 then
			return "no running scripts were available to inspect."
		end

		local Environment = Target(Running[1])

		assert(type(Environment) == "table", "getsenv did not return a table.")

		return "returned the environment table of a running script."
	end,
})

Test({
	Name = "decompile",
	Description = "Decompiles a script into Luau source.",
	Function = function(Target)
		local Script = FindLocalScript()

		assert(Script ~= nil, "no LocalScript was available to decompile.")

		local Source = Target(Script)

		assert(type(Source) == "string", "decompile did not return a string.")
		assert(#Source > 0, "decompile returned an empty string.")

		local Empty = Instance.new("LocalScript")
		local Success, EmptySource = pcall(Target, Empty)
		Empty:Destroy()

		assert(not (Success and EmptySource == Source), "decompile returned the same output for two different scripts.")

		return `decompiled a live script to {#Source} characters of source.`
	end,
})

Test({
	Name = "getscriptfromthread",
	Description = "Returns the script a thread belongs to.",
	Function = function(Target)
		local Thread = coroutine.running()

		Target(Thread)

		local Success = pcall(Target, "NotAThread")

		assert(not Success, "getscriptfromthread accepted a string as a thread.")

		return "accepted a real thread and rejected a string."
	end,
})

Test({
	Name = "require",
	Description = "Loads a ModuleScript and caches the result.",
	Function = function(Target)
		local Candidates = FindModuleScripts()

		assert(#Candidates > 0, "no ModuleScript was available to require.")

		local Module, Value, LastError = nil, nil, nil

		for _, Candidate in ipairs(Candidates) do
			local Success, Result = pcall(Target, Candidate)

			if Success then
				Module, Value = Candidate, Result
				break
			end

			LastError = Result
		end

		assert(Module ~= nil, `require could not load any available ModuleScript: {tostring(LastError)}`)

		local Success, Second = pcall(Target, Module)

		assert(Success, "require errored when loading an already-loaded ModuleScript.")
		assert(Value == Second, "require returned a different value for the same ModuleScript on a second call.")

		return "loaded a ModuleScript and returned the cached value on a second call."
	end,
})

Report("Script")

SetCategory("Drawing")

Test({
	Name = "Drawing.new",
	Description = "Creates a new drawable object of the given shape.",
	Function = function(Target)
		local Line = Target("Line")

		assert(Line ~= nil, "Drawing.new did not return an object.")
		assert(Line.Visible ~= nil, "the drawing object is missing a Visible property.")

		Line.Visible = false
		Line:Remove()

		return "created a drawable object with the expected properties."
	end,
})

Test({
	Name = "Drawing.Fonts",
	Description = "Holds the font ids a drawing object can use.",
	Function = function(Target)
		assert(type(Target) == "table", "Drawing.Fonts is not a table.")
		assert(Target.UI ~= nil or Target.Monospace ~= nil, "Drawing.Fonts has no font entries.")

		return "exposed the font table."
	end,
})

Test({
	Name = "isrenderobj",
	Description = "Reports whether a value is a drawable object.",
	Function = function(Target)
		local New = GetFunctionFromName("Drawing.new")

		assert(type(New) == "function", "Drawing.new is required to test isrenderobj.")

		local Text = New("Text")
		local IsRender = Target(Text)

		assert(type(IsRender) == "boolean", "isrenderobj did not return a boolean.")
		assert(IsRender == true, "isrenderobj did not recognise a drawing object.")

		Text:Remove()

		local Part = Instance.new("Part")
		local IsPart = Target(Part)
		Part:Destroy()

		assert(IsPart == false, "isrenderobj identified an Instance as a drawing object.")

		return "recognised drawing objects and rejected Instances."
	end,
})

Test({
	Name = "getrenderproperty",
	Description = "Returns a property from a drawable object.",
	Function = function(Target)
		local New = GetFunctionFromName("Drawing.new")

		assert(type(New) == "function", "Drawing.new is required to test getrenderproperty.")

		local Square = New("Square")
		Square.Visible = true

		local Value = Target(Square, "Visible")
		Square:Remove()

		assert(Value == true, `getrenderproperty returned {tostring(Value)} instead of true.`)

		return "read a property back off a drawing object."
	end,
})

Test({
	Name = "cleardrawcache",
	Description = "Clears every drawing object that is still cached.",
	Function = function(Target)
		local New = GetFunctionFromName("Drawing.new")
		local Created = if type(New) == "function" then New("Line") else nil

		Target()

		if Created then
			pcall(function()
				Created:Remove()
			end)
		end

		return "cleared the draw cache without erroring."
	end,
})

Test({
	Name = "setrenderproperty",
	Description = "Sets a property on a drawable object.",
	Function = function(Target)
		local New = GetFunctionFromName("Drawing.new")

		assert(type(New) == "function", "Drawing.new is required to test setrenderproperty.")

		local Line = New("Line")

		assert(Line ~= nil, "Drawing.new did not return a drawing object.")

		local ThicknessSet = pcall(Target, Line, "Thickness", 3)
		local VisibleSet = pcall(Target, Line, "Visible", false)

		local Thickness = Line.Thickness
		local Visible = Line.Visible

		pcall(function()
			Line:Remove()
		end)

		assert(ThicknessSet, "setrenderproperty errored while setting Thickness.")
		assert(VisibleSet, "setrenderproperty errored while setting Visible.")
		assert(Thickness == 3, `setrenderproperty left Thickness at {tostring(Thickness)}.`)
		assert(Visible == false, `setrenderproperty left Visible at {tostring(Visible)}.`)

		return "set two drawing properties and read them back."
	end,
})

Report("Drawing")

SetCategory("Metatable")

Test({
	Name = "getrawmetatable",
	Description = "Returns the real metatable of a value, including protected metamethods.",
	Function = function(Target)
		local Metatable = Target(game)

		assert(type(Metatable) == "table", "getrawmetatable did not return a table.")
		assert(rawget(Metatable, "__index") ~= nil, "the metatable has no __index.")

		return "returned the real metatable of an Instance, protected metamethods included."
	end,
})

Test({
	Name = "setrawmetatable",
	Description = "Replaces the metatable of a value even when it is protected.",
	Function = function(Target)
		local GetRawMetatable = GetFunctionFromName("getrawmetatable")

		assert(type(GetRawMetatable) == "function", "getrawmetatable is required to test setrawmetatable.")

		local Part = Instance.new("Part")
		local Original = GetRawMetatable(Part)
		local Marker = "GeneralTestingConvention_setrawmetatable"

		local Replacement = table.clone(Original)
		Replacement.__index = function()
			return Marker
		end

		local Returned = Target(Part, Replacement)
		local Seen = Part.GeneralTestingConvention
		local Applied = GetRawMetatable(Part) == Replacement

		Target(Part, Original)

		local Restored = typeof(Part) == "Instance" and Part.Name ~= Marker

		pcall(function()
			Part:Destroy()
		end)

		assert(
			Returned == nil or Returned == Part,
			"setrawmetatable returned something other than the value it was given."
		)
		assert(Seen == Marker, "the replacement metatable's __index was not used.")
		assert(Applied, "getrawmetatable did not see the replacement metatable.")
		assert(Restored, "restoring the original metatable failed.")

		return "replaced and restored a protected Instance metatable."
	end,
})

Test({
	Name = "setreadonly",
	Description = "Locks or unlocks a table so it can or cannot be written to.",
	Function = function(Target)
		local Sample = { Value = 1 }

		Target(Sample, true)

		local Wrote = pcall(function()
			Sample.Value = 2
		end)

		assert(not Wrote, "the table was still writable after setreadonly.")
		assert(Sample.Value == 1, "the table changed even though it was locked.")

		Target(Sample, false)
		Sample.Value = 2

		assert(Sample.Value == 2, "setreadonly did not make the table writable again.")

		return "locked and unlocked a table."
	end,
})

Test({
	Name = "makereadonly",
	Description = "Locks a table so it can no longer be written to.",
	Function = function(Target)
		local Sample = { Value = 1 }

		local function Writable()
			local Wrote = pcall(function()
				Sample.Value = 2
			end)

			if Wrote then
				Sample.Value = 1
			end

			return Wrote
		end

		Target(Sample)

		if Writable() then
			pcall(Target, Sample, true)
		end

		assert(not Writable(), "the table was still writable after makereadonly.")
		assert(Sample.Value == 1, "the table changed even though it was locked.")

		local MakeWritable = GetFunctionFromName("makewritable")
		local SetReadonly = GetFunctionFromName("setreadonly")
		local Restored = nil

		if type(MakeWritable) == "function" then
			pcall(MakeWritable, Sample)

			Restored = pcall(function()
				Sample.Value = 3
			end)
		elseif type(SetReadonly) == "function" then
			pcall(SetReadonly, Sample, false)

			Restored = pcall(function()
				Sample.Value = 3
			end)
		end

		if Restored ~= nil then
			assert(Restored, "the table stayed locked after it was made writable again.")
		end

		return "locked a table against writes."
	end,
})

Test({
	Name = "isreadonly",
	Description = "Reports whether a table is locked against writes.",
	Function = function(Target)
		local Frozen = { Value = 1 }
		table.freeze(Frozen)

		assert(Target(Frozen) == true, "isreadonly did not identify a frozen table.")

		local Writable = { Value = 1 }

		assert(Target(Writable) == false, "isreadonly identified a normal table as read-only.")

		return "identified frozen and writable tables."
	end,
})

Test({
	Name = "getnamecallmethod",
	Description = "Returns the method name of the namecall that is running.",
	Function = function(Target)
		local GetRawMetatable = GetFunctionFromName("getrawmetatable")
		local SetReadonly = GetFunctionFromName("setreadonly")
		local NewCClosure = GetFunctionFromName("newcclosure")

		assert(type(GetRawMetatable) == "function", "getrawmetatable is required to test getnamecallmethod.")
		assert(type(SetReadonly) == "function", "setreadonly is required to test getnamecallmethod.")
		assert(type(NewCClosure) == "function", "newcclosure is required to test getnamecallmethod.")

		local Metatable = GetRawMetatable(game)
		local Original = Metatable.__namecall
		local Seen = nil

		SetReadonly(Metatable, false)
		Metatable.__namecall = NewCClosure(function()
			Seen = Target()
			return nil
		end)
		SetReadonly(Metatable, true)

		local Success = pcall(function()
			return workspace:FindFirstChild("Camera")
		end)

		SetReadonly(Metatable, false)
		Metatable.__namecall = Original
		SetReadonly(Metatable, true)

		assert(Success, "the namecall used to test getnamecallmethod errored.")
		assert(Seen == "FindFirstChild", `getnamecallmethod returned {tostring(Seen)} instead of FindFirstChild.`)

		return "reported the method name of the running namecall."
	end,
})

Report("Metatable")

SetCategory("Instance")

Test({
	Name = "getnilinstances",
	Description = "Returns every Instance that has no parent.",
	Function = function(Target)
		local Part = Instance.new("Part")
		Part.Name = "GeneralTestingConvention_" .. math.random(1, 1000000000)

		local Instances = Target()

		assert(type(Instances) == "table", "getnilinstances did not return a table.")

		local Found = false

		for _, Entry in ipairs(Instances) do
			if Entry == Part then
				Found = true
				break
			end
		end

		Part:Destroy()

		assert(Found, "an Instance with no parent was not in getnilinstances.")

		return "found an Instance that has no parent."
	end,
})

Test({
	Name = "getinstances",
	Description = "Returns every Instance the game currently holds.",
	Function = function(Target)
		local Instances = Target()

		assert(type(Instances) == "table", "getinstances did not return a table.")
		assert(#Instances > 0, "getinstances returned an empty table.")
		assert(typeof(Instances[1]) == "Instance", "getinstances returned something that is not an Instance.")

		return `returned {#Instances} Instances.`
	end,
})

Test({
	Name = "gethui",
	Description = "Returns the container that drawing and UI should be parented to.",
	Function = function(Target)
		local Container = Target()

		assert(typeof(Container) == "Instance", "gethui did not return an Instance.")

		return `returned a {Container.ClassName} as the hidden UI container.`
	end,
})

Test({
	Name = "sethiddenproperty",
	Description = "Sets a property that is normally not scriptable.",
	Function = function(Target)
		local Part = Instance.new("Part")
		local Position = Vector3.new(10, 20, 30)

		local Success, Reason = pcall(Target, Part, "Position", Position)

		assert(Success, `sethiddenproperty errored: {tostring(Reason)}`)
		assert(Part.Position == Position, "sethiddenproperty did not change the property.")

		local Fake = pcall(Target, Part, "GeneralTestingConventionNotAProperty", true)
		Part:Destroy()

		assert(not Fake, "sethiddenproperty accepted a property that does not exist.")

		return "set a real property and rejected a fake one."
	end,
})

Test({
	Name = "gethiddenproperty",
	Description = "Reads a property that is normally not scriptable.",
	Function = function(Target)
		local Part = Instance.new("Part")

		local Value = Target(Part, "Position")

		assert(typeof(Value) == "Vector3", "gethiddenproperty did not return a Vector3 for Position.")

		local Fake = pcall(Target, Part, "GeneralTestingConventionNotAProperty")
		Part:Destroy()

		return "read a real property and rejected a fake one."
	end,
})

Test({
	Name = "setscriptable",
	Description = "Changes whether a property is scriptable and returns the previous state.",
	Function = function(Target)
		local Part = Instance.new("Part")
		local Previous = Target(Part, "Position", true)
		Part:Destroy()

		assert(type(Previous) == "boolean", "setscriptable did not return the previous scriptable state.")

		return "set the scriptable state and returned the previous one."
	end,
})

Test({
	Name = "isscriptable",
	Description = "Reports whether a property is scriptable.",
	Function = function(Target)
		local Part = Instance.new("Part")
		local State = Target(Part, "Position")
		Part:Destroy()

		assert(type(State) == "boolean", "isscriptable did not return a boolean.")

		return "returned the scriptable state of a property."
	end,
})

Test({
	Name = "getcallbackvalue",
	Description = "Returns the function assigned to an Instance callback property.",
	Function = function(Target)
		local Bindable = Instance.new("BindableFunction")
		local Callback = function() end
		Bindable.OnInvoke = Callback

		local Value = Target(Bindable, "OnInvoke")
		Bindable:Destroy()

		assert(Value == Callback, "getcallbackvalue did not return the assigned callback.")

		return "returned the callback assigned to a BindableFunction."
	end,
})

Test({
	Name = "firetouchinterest",
	Description = "Fires the Touched event as if two parts touched.",
	Function = function(Target)
		local First = Instance.new("Part")
		First.Anchored = true
		First.CFrame = CFrame.new(0, 500, 0)
		First.Parent = workspace

		local Second = Instance.new("Part")
		Second.Anchored = true
		Second.CFrame = CFrame.new(0, 500, 0)
		Second.Parent = workspace

		local Touched = false
		local Connection = Second.Touched:Connect(function()
			Touched = true
		end)

		local Success = pcall(Target, First, Second, 0)
		task.wait()
		pcall(Target, First, Second, 1)
		task.wait()

		Connection:Disconnect()
		First:Destroy()
		Second:Destroy()

		assert(Success, "firetouchinterest errored.")
		assert(Touched, "firetouchinterest did not fire the Touched event.")

		return "fired the Touched event on a part."
	end,
})

Test({
	Name = "saveinstance",
	Description = "Saves an Instance to a file in the workspace.",
	Function = function(Target)
		local ListFiles = GetFunctionFromName("listfiles")
		local DeleteFile = GetFunctionFromName("delfile")

		assert(type(ListFiles) == "function", "listfiles is required to test saveinstance.")

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000)
		local Part = Instance.new("Part")
		Part.Name = Name
		Part.Anchored = true

		local Success = pcall(Target, Part, { FileName = Name })

		local function ListPattern()
			local Ok, Files = pcall(ListFiles, "")

			if not Ok then
				Ok, Files = pcall(ListFiles, ".")
			end

			if not Ok then
				Ok, Files = pcall(ListFiles)
			end

			return Ok, Files
		end

		local Found = nil
		local Deadline = os.clock() + 2

		repeat
			local SuccessList, Files = ListPattern()

			if SuccessList and type(Files) == "table" then
				for _, File in ipairs(Files) do
					if type(File) == "string" and string.find(File, Name, 1, true) then
						Found = File
						break
					end
				end
			end

			if not Found and os.clock() < Deadline then
				task.wait(0.05)
			end
		until Found or os.clock() >= Deadline

		if Found and type(DeleteFile) == "function" then
			pcall(DeleteFile, Found)
		end

		Part:Destroy()

		assert(Success, "saveinstance errored while saving a Part.")
		assert(Found ~= nil, "saveinstance did not create a file whose name matched FileName.")

		return "saved a Part to a file and found it with listfiles."
	end,
})

Report("Instance")

SetCategory("Signal")

Test({
	Name = "getconnections",
	Description = "Returns every connection attached to a signal.",
	Function = function(Target)
		local function Method(Entry, Name)
			local Success, Value = pcall(function()
				return Entry[Name]
			end)

			if Success and type(Value) == "function" then
				return Value
			end

			return nil
		end

		local Bindable = Instance.new("BindableEvent")
		local CountA, CountB = 0, 0

		local ConnectionA = Bindable.Event:Connect(function()
			CountA += 1
		end)

		local ConnectionB = Bindable.Event:Connect(function()
			CountB += 1
		end)

		local Connections = Target(Bindable.Event)

		assert(type(Connections) == "table", "getconnections did not return a table.")
		assert(#Connections >= 2, `getconnections returned {#Connections} connections instead of 2.`)

		local Total = #Connections

		Bindable:Fire()
		task.wait()

		assert(CountA == 1 and CountB == 1, "the connections did not fire before the checks began.")

		local Disabled = 0

		for _, Entry in ipairs(Connections) do
			local Disable = Method(Entry, "Disable") or Method(Entry, "disable")

			if Disable and pcall(Disable, Entry) then
				Disabled += 1
			end
		end

		CountA, CountB = 0, 0
		Bindable:Fire()
		task.wait()

		assert(Disabled > 0, "no connection object exposed a working Disable method.")
		assert(CountA == 0 and CountB == 0, "Disable did not stop the connections from firing.")

		local Enabled = 0

		for _, Entry in ipairs(Connections) do
			local Enable = Method(Entry, "Enable") or Method(Entry, "enable")

			if Enable and pcall(Enable, Entry) then
				Enabled += 1
			end
		end

		CountA, CountB = 0, 0
		Bindable:Fire()
		task.wait()

		assert(Enabled > 0, "no connection object exposed a working Enable method.")
		assert(CountA == 1 and CountB == 1, "Enable did not restore the connections.")

		assert(Method(Connections[1], "Disconnect") ~= nil, "no connection object exposed a Disconnect method.")

		ConnectionA:Disconnect()
		CountA, CountB = 0, 0
		Bindable:Fire()
		task.wait()

		ConnectionB:Disconnect()
		Bindable:Destroy()

		assert(CountA == 0 and CountB == 1, "a disconnected connection still fired.")

		return `returned {Total} connection objects with working Disable, Enable and Disconnect.`
	end,
})

Test({
	Name = "firesignal",
	Description = "Runs every listener attached to a signal with the given arguments.",
	Function = function(Target)
		local Bindable = Instance.new("BindableEvent")
		local Fired = false

		local Connection = Bindable.Event:Connect(function(Argument)
			if Argument == "verification_token" then
				Fired = true
			end
		end)

		local Success = pcall(Target, Bindable.Event, "verification_token")
		task.wait()

		Connection:Disconnect()
		Bindable:Destroy()

		assert(Success, "firesignal errored.")
		assert(Fired, "firesignal did not run the connected listener.")

		return "fired a signal and the listener received the argument."
	end,
})

Test({
	Name = "cansignalreplicate",
	Description = "Reports whether a signal can be fired through the replication layer.",
	Function = function(Target)
		local Bindable = Instance.new("BindableEvent")
		local Success, Allowed, Reason = pcall(Target, Bindable.Event)

		assert(Success, `cansignalreplicate errored: {tostring(Allowed)}`)
		assert(type(Allowed) == "boolean", `cansignalreplicate returned {typeof(Allowed)}, not a boolean.`)
		assert(Reason == nil or type(Reason) == "string", "cansignalreplicate returned a non-string reason.")
		assert(Allowed == false, "cansignalreplicate said a BindableEvent can be replicated.")

		local Replicate = GetFunctionFromName("replicatesignal")

		if type(Replicate) == "function" then
			local Replicated, Message = pcall(Replicate, Bindable.Event)

			assert(
				not Replicated,
				`replicatesignal fired a BindableEvent that cansignalreplicate said cannot be replicated ({tostring(
					Message
				)}).`
			)
		end

		Bindable:Destroy()

		return "correctly reported that a BindableEvent cannot be replicated."
	end,
})

Test({
	Name = "replicatesignal",
	Description = "Fires a signal through the replication layer.",
	Function = function(Target)
		local Remote = Instance.new("RemoteEvent")

		local Success, Reason = pcall(Target, Remote.OnClientEvent)
		Remote:Destroy()

		if not Success then
			local Message = tostring(Reason)

			assert(
				string.find(Message, "cannot be replicated") or string.find(Message, "not replicate"),
				`replicatesignal errored for an unexpected reason: {Message}`
			)

			return "refused to replicate a client-only signal, which is the correct behaviour."
		end

		return "replicated a signal without erroring."
	end,
})

Test({
	Name = "Signal.new",
	Description = "Creates a signal with Connect, Once, Wait, Fire and Disconnect.",
	Function = function(Target)
		local Signal = Target()

		assert(type(Signal) == "table" or typeof(Signal) == "userdata", "Signal.new did not return an object.")

		for _, Method in ipairs({ "Connect", "Once", "Wait", "Fire" }) do
			assert(type(Signal[Method]) == "function", `the created signal is missing {Method}.`)
		end

		local Fired = false
		local Arguments = nil
		local Connection = Signal:Connect(function(...)
			Fired = true
			Arguments = table.pack(...)
		end)

		Signal:Fire("signal_token", 42)

		assert(Fired, "Signal:Fire did not run a connected listener.")
		assert(
			Arguments ~= nil and Arguments[1] == "signal_token" and Arguments[2] == 42,
			"Signal:Fire did not forward its arguments."
		)
		assert(
			type(Connection) == "table" or typeof(Connection) == "userdata",
			"Signal:Connect did not return a connection."
		)
		assert(type(Connection.Disconnect) == "function", "the connection has no Disconnect method.")

		Connection:Disconnect()
		Fired = false
		Signal:Fire("after_disconnect")

		assert(not Fired, "a listener ran after its connection was disconnected.")

		local OnceCalls = 0

		Signal:Once(function()
			OnceCalls += 1
		end)

		Signal:Fire()
		Signal:Fire()

		assert(OnceCalls == 1, `Signal:Once ran {OnceCalls} times instead of exactly once.`)

		local Waited = nil

		task.spawn(function()
			Waited = table.pack(Signal:Wait())
		end)

		task.wait()
		Signal:Fire("wait_token")

		local Resumed = WaitFor(function()
			return Waited ~= nil
		end)

		assert(Resumed, "Signal:Wait did not resume after Signal:Fire.")
		assert(Waited[1] == "wait_token", "Signal:Wait did not return the value passed to Signal:Fire.")

		return "created a signal and exercised Connect, Fire, Disconnect, Once and Wait."
	end,
})

Test({
	Name = "getsignalarguments",
	Description = "Returns the argument names a signal passes to its listeners.",
	Function = function(Target)
		local Part = Instance.new("Part")
		local Success, Arguments = pcall(Target, Part.Touched)
		Part:Destroy()

		assert(Success, `getsignalarguments errored: {tostring(Arguments)}`)
		assert(type(Arguments) == "table", "getsignalarguments did not return a table.")
		assert(#Arguments > 0, "getsignalarguments returned an empty table.")
		assert(type(Arguments[1]) == "string", "getsignalarguments returned a non-string argument name.")

		return `returned {#Arguments} argument name(s) for Part.Touched.`
	end,
})

Test({
	Name = "getsignalargumentsinfo",
	Description = "Returns the name and type of each argument a signal passes.",
	Function = function(Target)
		local Part = Instance.new("Part")
		local Success, Info = pcall(Target, Part.Touched)
		Part:Destroy()

		assert(Success, `getsignalargumentsinfo errored: {tostring(Info)}`)
		assert(type(Info) == "table", "getsignalargumentsinfo did not return a table.")
		assert(#Info > 0, "getsignalargumentsinfo returned an empty table.")
		assert(type(Info[1]) == "table", "getsignalargumentsinfo entries are not tables.")
		assert(type(Info[1].Name) == "string", "an entry has no string Name.")
		assert(type(Info[1].Type) == "string", "an entry has no string Type.")

		return `returned {#Info} argument descriptor(s) for Part.Touched.`
	end,
})

Test({
	Name = "getsignalwhitelist",
	Description = "Returns the signal filter whitelist entries.",
	Function = function(Target)
		local Success, Whitelist = pcall(Target)

		assert(Success, `getsignalwhitelist errored: {tostring(Whitelist)}`)
		assert(type(Whitelist) == "table", "getsignalwhitelist did not return a table.")
		assert(#Whitelist > 0, "getsignalwhitelist returned an empty table.")
		assert(type(Whitelist[1]) == "table", "getsignalwhitelist entries are not tables.")
		assert(type(Whitelist[1].Event) == "string", "an entry has no string Event.")
		assert(type(Whitelist[1].Parent) == "string", "an entry has no string Parent.")

		return `returned {#Whitelist} whitelist entry(ies).`
	end,
})

Report("Signal")

SetCategory("Input")

Test({
	Name = "isrbxactive",
	Description = "Returns whether the current Roblox window is in focus.",
	Function = function(Target)
		if not Target or Target() ~= true and Target() ~= false then
			return "value wasn't true or false"
		end

		return "function exists and returned " .. tostring(Target())
	end,
})

Test({
	Name = "keypress",
	Description = "Simulates pressing a key.",
	Function = function(Target)
		local TestPassed = false
		local Connection = game:GetService("UserInputService").InputBegan:Connect(function(Input)
			if Input.KeyCode == Enum.KeyCode.H then
				TestPassed = true
			end
		end)

		Target(0x48)
		local Passed = WaitFor(function()
			return TestPassed
		end)
		Connection:Disconnect()
		if type(GetFunctionFromName("keyrelease")) == "function" then
			pcall(GetFunctionFromName("keyrelease"), 0x48)
		end
		assert(Passed, "InputBegan did not catch keypress's keypress.")

		return "function properly fired InputBegan."
	end,
})

Test({
	Name = "keyclick",
	Description = "Simulates pressing a key.",
	Function = function(Target)
		local KeyRelease = GetFunctionFromName("keyrelease")
		if type(KeyRelease) == "function" then
			pcall(KeyRelease, 0x48)
			task.wait()
		end
		local Pressed, Ended = false, false
		local Connection = game:GetService("UserInputService").InputBegan:Connect(function(Input)
			if Input.KeyCode == Enum.KeyCode.H then
				Pressed = true
			end
		end)

		local Connection2 = game:GetService("UserInputService").InputEnded:Connect(function(Input)
			if Input.KeyCode == Enum.KeyCode.H then
				Ended = true
			end
		end)

		Target(0x48)

		local Passed = WaitFor(function()
			return (Pressed and Ended) == true
		end)

		assert(Passed, "InputBegan did not catch keyclick's key press.")
		Connection:Disconnect()
		Connection2:Disconnect()

		return "function properly fired InputBegan and InputEnded."
	end,
})

Test({
	Name = "keyrelease",
	Description = "Simulates releasing a key.",
	Function = function(Target)
		local TestPassed = false
		local KeyPress = GetFunctionFromName("keypress")
		assert(type(KeyPress) == "function", "keypress is required to test keyrelease.")
		KeyPress(0x48)
		task.wait()
		local Connection = game:GetService("UserInputService").InputEnded:Connect(function(Input)
			if Input.KeyCode == Enum.KeyCode.H then
				TestPassed = true
			end
		end)

		Target(0x48)
		local Passed = WaitFor(function()
			return TestPassed
		end)
		Connection:Disconnect()
		assert(Passed, "InputEnded did not catch keyrelease's release.")

		return "function properly fired InputEnded."
	end,
})

local UserInputService = game:GetService("UserInputService")

local function WatchMouseButton(Button)
	local State = { Pressed = false, Released = false }

	local PressConnection = UserInputService.InputBegan:Connect(function(Input)
		if Input.UserInputType == Button then
			State.Pressed = true
		end
	end)

	local ReleaseConnection = UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType == Button then
			State.Released = true
		end
	end)

	State.Stop = function()
		PressConnection:Disconnect()
		ReleaseConnection:Disconnect()
	end

	return State
end

local function ButtonHeld(Button)
	local Success, Pressed = pcall(function()
		return UserInputService:IsMouseButtonPressed(Button)
	end)

	return Success and Pressed == true
end

local function ClearMouseButton(Button, Release)
	-- Releasing a button that is already up queues nothing, so it cannot poison the
	-- batch and there is nothing to settle.
	if not ButtonHeld(Button) then
		return true
	end

	if type(Release) == "function" then
		pcall(Release)
	end

	local Deadline = os.clock() + 1

	while ButtonHeld(Button) and os.clock() < Deadline do
		task.wait()
	end

	-- Some executors drop a press that arrives in the same input batch as a release,
	-- so let the engine settle before the next press is issued.
	task.wait(0.05)

	return not ButtonHeld(Button)
end

local function PressUntilSeen(Button, Press, State, Timeout)
	local Deadline = os.clock() + (Timeout or 2)

	repeat
		pcall(Press)

		-- A dropped press is invisible: nothing is held and no event arrives, so
		-- retry after a couple of frames instead of waiting out a whole interval.
		local Frames = 0

		while not State.Pressed and os.clock() < Deadline do
			task.wait()
			Frames += 1

			if Frames >= 2 and not ButtonHeld(Button) then
				break
			end
		end
	until State.Pressed or os.clock() > Deadline

	return State.Pressed
end

Test({
	Name = "mouse1click",
	Description = "Simulates a left mouse button click.",
	Function = function(Target)
		local Button = Enum.UserInputType.MouseButton1
		local Release = GetFunctionFromName("mouse1release")

		ClearMouseButton(Button, Release)

		local State = WatchMouseButton(Button)

		Target()

		local Passed = WaitFor(function()
			return State.Pressed and State.Released
		end, 2)

		State.Stop()

		if type(Release) == "function" then
			pcall(Release)
		end

		assert(
			Passed,
			`mouse1click did not fire both InputBegan and InputEnded (pressed={State.Pressed}, released={State.Released}).`
		)

		return "fired InputBegan and InputEnded for the left mouse button."
	end,
})

Test({
	Name = "mouse1press",
	Description = "Simulates holding down the left mouse button.",
	Function = function(Target)
		local Button = Enum.UserInputType.MouseButton1
		local Release = GetFunctionFromName("mouse1release")

		ClearMouseButton(Button, Release)

		local WasHeld = ButtonHeld(Button)
		local State = WatchMouseButton(Button)

		local Passed = PressUntilSeen(Button, Target, State, 2)

		State.Stop()

		if type(Release) == "function" then
			pcall(Release)
		end

		assert(
			Passed,
			`mouse1press did not fire InputBegan for the left mouse button (the button was {WasHeld and "still held" or "released"} before the press).`
		)

		return "held the left mouse button and fired InputBegan."
	end,
})

Test({
	Name = "mouse1release",
	Description = "Simulates releasing the left mouse button.",
	Function = function(Target)
		local Button = Enum.UserInputType.MouseButton1
		local Press = GetFunctionFromName("mouse1press")

		assert(type(Press) == "function", "mouse1press is required to test mouse1release.")

		ClearMouseButton(Button, Target)

		local State = WatchMouseButton(Button)
		local Held = PressUntilSeen(Button, Press, State, 2)

		assert(Held, `mouse1press did not hold the left mouse button, so it could not be released.`)

		Target()

		local Released = WaitFor(function()
			return State.Released
		end, 2)

		State.Stop()

		assert(Released, "mouse1release did not fire InputEnded for the left mouse button.")

		return "released the left mouse button and fired InputEnded."
	end,
})

Test({
	Name = "mouse2click",
	Description = "Simulates a right mouse button click.",
	Function = function(Target)
		local Button = Enum.UserInputType.MouseButton2
		local Release = GetFunctionFromName("mouse2release")

		ClearMouseButton(Button, Release)

		local State = WatchMouseButton(Button)

		Target()

		local Passed = WaitFor(function()
			return State.Pressed and State.Released
		end, 2)

		State.Stop()

		if type(Release) == "function" then
			pcall(Release)
		end

		assert(
			Passed,
			`mouse2click did not fire both InputBegan and InputEnded (pressed={State.Pressed}, released={State.Released}).`
		)

		return "fired InputBegan and InputEnded for the right mouse button."
	end,
})

Test({
	Name = "mouse2press",
	Description = "Simulates holding down the right mouse button.",
	Function = function(Target)
		local Button = Enum.UserInputType.MouseButton2
		local Release = GetFunctionFromName("mouse2release")

		ClearMouseButton(Button, Release)

		local WasHeld = ButtonHeld(Button)
		local State = WatchMouseButton(Button)

		local Passed = PressUntilSeen(Button, Target, State, 2)

		State.Stop()

		if type(Release) == "function" then
			pcall(Release)
		end

		assert(
			Passed,
			`mouse2press did not fire InputBegan for the right mouse button (the button was {WasHeld and "still held" or "released"} before the press).`
		)

		return "held the right mouse button and fired InputBegan."
	end,
})

Test({
	Name = "mouse2release",
	Description = "Simulates releasing the right mouse button.",
	Function = function(Target)
		local Button = Enum.UserInputType.MouseButton2
		local Press = GetFunctionFromName("mouse2press")

		assert(type(Press) == "function", "mouse2press is required to test mouse2release.")

		ClearMouseButton(Button, Target)

		local State = WatchMouseButton(Button)
		local Held = PressUntilSeen(Button, Press, State, 2)

		assert(Held, `mouse2press did not hold the right mouse button, so it could not be released.`)

		Target()

		local Released = WaitFor(function()
			return State.Released
		end, 2)

		State.Stop()

		assert(Released, "mouse2release did not fire InputEnded for the right mouse button.")

		return "released the right mouse button and fired InputEnded."
	end,
})

Test({
	Name = "mousemoveabs",
	Description = "Moves the mouse cursor to an absolute screen position.",
	Function = function(Target)
		local UserInputService = game:GetService("UserInputService")

		local Moved = false
		local Connection = UserInputService.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				Moved = true
			end
		end)

		local function MoveTo(X, Y, Previous)
			Target(X, Y)

			local Deadline = os.clock() + 1
			local Location = UserInputService:GetMouseLocation()

			while (Location - Previous).Magnitude <= 0.5 and os.clock() < Deadline do
				task.wait()
				Location = UserInputService:GetMouseLocation()
			end

			return Location
		end

		local Start = UserInputService:GetMouseLocation()
		local First = MoveTo(200, 200, Start)
		local Second = MoveTo(400, 300, First)
		local Third = MoveTo(200, 200, Second)

		Connection:Disconnect()

		assert(Moved, "mousemoveabs did not fire InputChanged with MouseMovement.")
		assert(
			Second.X > First.X and Second.Y > First.Y,
			`mousemoveabs did not move the cursor towards the larger target (from {First} to {Second}).`
		)
		assert(
			(Third - First).Magnitude <= 2,
			`mousemoveabs did not return the cursor to the same position (expected {First}, got {Third}).`
		)

		return "moved the cursor to absolute positions and back."
	end,
})

Test({
	Name = "mousemoverel",
	Description = "Moves the mouse cursor by a relative offset.",
	Function = function(Target)
		local UserInputService = game:GetService("UserInputService")
		local MoveAbs = GetFunctionFromName("mousemoveabs")

		if type(MoveAbs) == "function" then
			pcall(MoveAbs, 300, 300)
			task.wait()
		end

		local Moved = false
		local Connection = UserInputService.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				Moved = true
			end
		end)

		local function MoveBy(X, Y)
			local Before = UserInputService:GetMouseLocation()

			Target(X, Y)

			local Deadline = os.clock() + 1
			local After = UserInputService:GetMouseLocation()

			while (After - Before).Magnitude <= 0.5 and os.clock() < Deadline do
				task.wait()
				After = UserInputService:GetMouseLocation()
			end

			return After - Before
		end

		local First = MoveBy(25, 25)
		local Second = MoveBy(25, 25)
		local Back = MoveBy(-25, -25)

		Connection:Disconnect()

		assert(Moved, "mousemoverel did not fire InputChanged with MouseMovement.")
		assert(First.X > 0 and First.Y > 0, `mousemoverel(25, 25) moved the cursor by ({First.X}, {First.Y}).`)
		assert(
			(Second - First).Magnitude <= 2,
			`mousemoverel moved by ({Second.X}, {Second.Y}) for the same input that produced ({First.X}, {First.Y}).`
		)
		assert(Back.X < 0 and Back.Y < 0, `mousemoverel(-25, -25) moved the cursor by ({Back.X}, {Back.Y}).`)

		return "moved the cursor by relative offsets and back."
	end,
})

Test({
	Name = "mousescroll",
	Description = "Simulates scrolling the mouse wheel.",
	Function = function(Target)
		local UserInputService = game:GetService("UserInputService")
		local Scroll = nil

		local Connection = UserInputService.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseWheel then
				Scroll = Input.Position.Z
			end
		end)

		Target(1)
		local UpFired = WaitFor(function()
			return Scroll ~= nil
		end, 2)
		local Up = Scroll

		Scroll = nil
		Target(-1)
		local DownFired = WaitFor(function()
			return Scroll ~= nil
		end, 2)
		local Down = Scroll

		Connection:Disconnect()

		assert(UpFired, "mousescroll did not fire InputChanged with MouseWheel for a positive delta.")
		assert(DownFired, "mousescroll did not fire InputChanged with MouseWheel for a negative delta.")
		assert(type(Up) == "number" and Up > 0, `mousescroll(1) reported a wheel delta of {tostring(Up)}.`)
		assert(type(Down) == "number" and Down < 0, `mousescroll(-1) reported a wheel delta of {tostring(Down)}.`)
		assert(Up == -Down, `mousescroll used different magnitudes for opposite directions ({Up} and {Down}).`)

		return "scrolled the wheel in both directions and reported matching deltas."
	end,
})

Test({
	Name = "setclipboard",
	Description = "Copies a string to the system clipboard.",
	Function = function(Target)
		local GetClipboard = GetFunctionFromName("getclipboard")
		local Token = "GeneralTestingConvention_clipboard_" .. math.random(1, 1000000000)

		local Success, Reason = pcall(Target, Token)

		assert(Success, `setclipboard errored while copying a string: {tostring(Reason)}`)

		if type(GetClipboard) == "function" then
			local Read, Value = pcall(GetClipboard)

			assert(Read, "getclipboard errored while reading the clipboard back.")
			assert(Value == Token, `the system clipboard contained {tostring(Value)} instead of the copied token.`)

			return "copied a token to the system clipboard and read it back."
		end

		return "copied a token to the system clipboard (getclipboard is unavailable, so it could not be read back)."
	end,
})

Test({
	Name = "setrbxclipboard",
	Description = "Copies a string into Roblox's clipboard.",
	Function = function(Target)
		local GetClipboard = GetFunctionFromName("getclipboard")
		local Token = "GeneralTestingConvention_rbxclipboard_" .. math.random(1, 1000000000)

		local Success, Reason = pcall(Target, Token)

		assert(Success, `setrbxclipboard errored while copying a string: {tostring(Reason)}`)

		if type(GetClipboard) == "function" then
			local Read, Value = pcall(GetClipboard)

			if Read and Value == Token then
				return "copied a token into Roblox's clipboard and read it back."
			end
		end

		return "copied a token into Roblox's clipboard without erroring (no API was available to read it back)."
	end,
})

Test({
	Name = "fireclickdetector",
	Description = "Fires a ClickDetector as if it was clicked.",
	Function = function(Target)
		local Part = Instance.new("Part")
		Part.Anchored = true
		Part.CFrame = CFrame.new(0, 500, 0)
		Part.Parent = workspace

		local Detector = Instance.new("ClickDetector")
		Detector.Parent = Part

		local Clicked = false
		local Connection = Detector.MouseClick:Connect(function()
			Clicked = true
		end)

		local Success = pcall(Target, Detector)
		task.wait()

		Connection:Disconnect()
		Part:Destroy()

		assert(Success, "fireclickdetector errored.")
		assert(Clicked, "fireclickdetector did not fire MouseClick.")

		return "fired MouseClick on a ClickDetector."
	end,
})

Test({
	Name = "fireproximityprompt",
	Description = "Fires a ProximityPrompt as if it was triggered.",
	Function = function(Target)
		local Part = Instance.new("Part")
		Part.Anchored = true
		Part.CFrame = CFrame.new(0, 500, 0)
		Part.Parent = workspace

		local Prompt = Instance.new("ProximityPrompt")
		Prompt.Parent = Part

		local Triggered = false
		local Connection = Prompt.Triggered:Connect(function()
			Triggered = true
		end)

		local Success = pcall(Target, Prompt)
		task.wait()

		Connection:Disconnect()
		Part:Destroy()

		assert(Success, "fireproximityprompt errored.")
		assert(Triggered, "fireproximityprompt did not fire Triggered.")

		return "fired Triggered on a ProximityPrompt."
	end,
})

Report("Input")

SetCategory("Actors")

local function FindActor()
	local GetActors = GetFunctionFromName("getactors")

	if type(GetActors) == "function" then
		local Success, Actors = pcall(GetActors)

		if Success and type(Actors) == "table" then
			for _, Actor in ipairs(Actors) do
				if typeof(Actor) == "Instance" and Actor:IsA("Actor") then
					return Actor
				end
			end
		end
	end

	local Containers = {
		workspace,
		game:GetService("ReplicatedStorage"),
		game:GetService("ReplicatedFirst"),
	}

	local Players = game:GetService("Players")
	local LocalPlayer = Players.LocalPlayer
	local PlayerScripts = LocalPlayer and LocalPlayer:FindFirstChildOfClass("PlayerScripts")

	if PlayerScripts then
		table.insert(Containers, PlayerScripts)
	end

	for _, Container in ipairs(Containers) do
		local Found = Container:FindFirstChildWhichIsA("Actor", true)

		if Found then
			return Found
		end
	end

	return nil
end

local function GetTestActor()
	local Existing = FindActor()

	if Existing then
		return Existing, false
	end

	local Created = Instance.new("Actor")
	Created.Name = "GeneralTestingConvention_Actor"
	Created.Parent = workspace

	return Created, true
end

Test({
	Name = "isparallel",
	Description = "Reports whether the current thread is running in parallel.",
	Function = function(Target)
		local RunOnActor = GetFunctionFromName("run_on_actor")

		assert(type(RunOnActor) == "function", "run_on_actor is required to test isparallel.")

		local Actor, Created = GetTestActor()

		assert(Actor ~= nil, "no Actor was available to run parallel code on.")

		local MainThread = Target()
		local Attribute = "GeneralTestingConvention_parallel_" .. math.random(1, 1000000000)
		local Code = string.format(
			[[
				task.desynchronize()
				local Parallel = isparallel()
				task.synchronize()
				workspace:SetAttribute(%q, Parallel)
			]],
			Attribute
		)

		local Success = pcall(RunOnActor, Actor, Code)
		local Seen = false

		if Success then
			Seen = WaitFor(function()
				return workspace:GetAttribute(Attribute) == true
			end, 2)
		end

		local Value = workspace:GetAttribute(Attribute)
		workspace:SetAttribute(Attribute, nil)

		if Created then
			Actor:Destroy()
		end

		assert(Success, "run_on_actor errored while running a parallel snippet.")
		assert(MainThread == false, "isparallel reported true on a normal thread.")
		assert(Seen, `isparallel returned {tostring(Value)} inside a desynchronized actor instead of true.`)
		assert(Target() == false, "isparallel reported true on the main thread after the actor ran.")

		return "reported false on a normal thread and true inside a desynchronized actor."
	end,
})

Test({
	Name = "run_on_actor",
	Description = "Runs Luau on an Actor with arguments.",
	Function = function(Target)
		local Actor, Created = GetTestActor()

		assert(Actor ~= nil, "no Actor was available to run code on.")

		local Token = "GeneralTestingConvention_roa_" .. math.random(1, 1000000000)
		local ResultKey = Token .. "_result"
		local Shared = { Token = Token }
		local Code = string.format(
			[[
				local Table, Number, Text, Boolean = ...
				workspace:SetAttribute(%q, table.concat({
					tostring(type(Table) == "table" and Table.Token == %q),
					tostring(Number == 7),
					tostring(Text == "actor_text"),
					tostring(Boolean == true),
				}, ","))
			]],
			ResultKey,
			Token
		)

		local Success = pcall(Target, Actor, Code, Shared, 7, "actor_text", true)
		local Seen = false

		if Success then
			Seen = WaitFor(function()
				return workspace:GetAttribute(ResultKey) ~= nil
			end, 2)
		end

		local Result = workspace:GetAttribute(ResultKey)
		workspace:SetAttribute(ResultKey, nil)

		if Created then
			Actor:Destroy()
		end

		assert(Success, "run_on_actor errored while running a snippet.")
		assert(Seen, "run_on_actor did not run the snippet on the actor.")
		assert(Result == "true,true,true,true", `run_on_actor forwarded its arguments incorrectly: {tostring(Result)}.`)

		return "ran code on an actor and forwarded a table, number, string and boolean."
	end,
})

Test({
	Name = "create_comm_channel",
	Description = "Creates a numbered channel that fires events across actors.",
	Function = function(Target)
		local GetChannel = GetFunctionFromName("get_comm_channel")
		local RunOnActor = GetFunctionFromName("run_on_actor")

		assert(type(GetChannel) == "function", "get_comm_channel is required to test create_comm_channel.")
		assert(type(RunOnActor) == "function", "run_on_actor is required to test create_comm_channel.")

		local Actor, Created = GetTestActor()

		assert(Actor ~= nil, "no Actor was available to test a communication channel.")

		local Success, Id, Channel = pcall(Target)

		if not Success then
			if Created then
				Actor:Destroy()
			end

			assert(false, `create_comm_channel errored: {tostring(Id)}`)
		end

		local Valid = type(Id) == "number"
			and math.floor(Id) == Id
			and (type(Channel) == "table" or typeof(Channel) == "userdata")
			and Channel.Event ~= nil
			and type(Channel.Fire) == "function"

		if not Valid then
			if Created then
				Actor:Destroy()
			end

			assert(false, "create_comm_channel did not return an integer id and an object with .Event and :Fire.")
		end

		assert(GetChannel(Id) == Channel, "get_comm_channel did not return the object for the created id.")

		local Token = "GeneralTestingConvention_channel_" .. math.random(1, 1000000000)
		local Received = nil
		local Connection = Channel.Event:Connect(function(...)
			Received = table.pack(...)
		end)

		local Code = string.format(
			[[
				local Channel = get_comm_channel(%d)
				Channel:Fire(%q, game)
			]],
			Id,
			Token
		)

		local Fired = pcall(RunOnActor, Actor, Code)
		local Seen = WaitFor(function()
			return Received ~= nil
		end, 2)

		Connection:Disconnect()

		if Created then
			Actor:Destroy()
		end

		assert(Fired, "run_on_actor errored while firing the channel.")
		assert(Seen, "the channel event never fired from the actor.")
		assert(Received[1] == Token, "the channel did not forward the string argument.")
		assert(Received[2] == game, "the channel did not convert the game reference back to the caller's instance.")

		return "created a channel, fired it from an actor and received the converted arguments."
	end,
})

Test({
	Name = "get_comm_channel",
	Description = "Returns a channel created by create_comm_channel, or nil for unknown ids.",
	Function = function(Target)
		local Create = GetFunctionFromName("create_comm_channel")

		assert(type(Create) == "function", "create_comm_channel is required to test get_comm_channel.")

		local Success, Id, Channel = pcall(Create)

		assert(Success, `create_comm_channel errored: {tostring(Id)}`)

		local FoundOk, Found = pcall(Target, Id)

		assert(FoundOk, `get_comm_channel errored for a real id: {tostring(Found)}`)
		assert(Found == Channel, "get_comm_channel did not return the channel for its id.")

		local MissingId = math.random(1, 1000000000) + 1000000000
		local MissingOk, Missing = pcall(Target, MissingId)

		assert(MissingOk, `get_comm_channel errored for an unknown id: {tostring(Missing)}`)
		assert(Missing == nil, "get_comm_channel returned a value for an unknown id.")

		return "looked up a real channel and returned nil for an unknown id."
	end,
})

Test({
	Name = "getactors",
	Description = "Returns every live Actor, resolved from the actor thread list.",
	Function = function(Target)
		local Compare = GetFunctionFromName("compareinstances") or function(Left, Right)
			return Left == Right
		end

		local Success, Actors = pcall(Target)

		assert(Success, `getactors errored: {tostring(Actors)}`)
		assert(type(Actors) == "table", "getactors did not return a table.")

		for _, Entry in ipairs(Actors) do
			local Kind = typeof(Entry)

			assert(
				Kind == "Instance" and Entry:IsA("Actor") and Entry:IsDescendantOf(game),
				`getactors returned {Kind}, not a live Actor.`
			)
		end

		local RunOnActor = GetFunctionFromName("run_on_actor")

		if type(RunOnActor) ~= "function" then
			return `returned {#Actors} live actor(s).`
		end

		local Actor = Instance.new("Actor")
		Actor.Name = "GeneralTestingConvention_Actor"
		Actor.Parent = workspace

		local Threaded = pcall(RunOnActor, Actor, "while true do task.wait(1) end")
		local Deadline = os.clock() + 1
		local Found = false

		while not Found and os.clock() < Deadline do
			task.wait()

			local Polled, Probe = pcall(Target)

			if Polled and type(Probe) == "table" then
				for _, Entry in ipairs(Probe) do
					if typeof(Entry) == "Instance" and Compare(Entry, Actor) then
						Found = true
						break
					end
				end
			end
		end

		Actor:Destroy()

		if Threaded then
			assert(Found, "getactors did not include the Actor running a thread.")
		end

		return "returned only live Actors, including the one running a thread."
	end,
})

Report("Actors")

SetCategory("Miscellaneous")

Test({
	Name = "loadstring",
	Description = "Compiles a string of Luau into a runnable chunk.",
	Function = function(Target)
		local Chunk, Reason = Target("return 1 + 1")

		assert(type(Chunk) == "function", `loadstring did not compile valid source: {tostring(Reason)}`)
		assert(Chunk() == 2, "the compiled chunk returned the wrong value.")

		local Failing, Message = Target("this is not luau")

		assert(Failing == nil, "loadstring compiled source that is not valid Luau.")
		assert(Message ~= nil, "loadstring did not explain why the source failed to compile.")

		return "compiled valid source and rejected invalid source."
	end,
})

Test({
	Name = "getgc",
	Description = "Returns every value the garbage collector is tracking.",
	Function = function(Target)
		local Objects = Target()

		assert(type(Objects) == "table", "getgc did not return a table.")
		assert(#Objects > 0, "getgc returned an empty table.")

		return `returned {#Objects} objects.`
	end,
})

Test({
	Name = "filtergc",
	Description = "Returns the garbage collector objects that match a filter.",
	Function = function(Target)
		local Token = { token = "GeneralTestingConvention_filtergc" }

		local Attempts = {
			function()
				return Target("table", {})
			end,
			function()
				return Target("tables", {})
			end,
			function()
				return Target("table", {}, false)
			end,
			function()
				return Target("tables", {}, false)
			end,
			function()
				return Target("table")
			end,
			function()
				return Target("tables")
			end,
			function()
				return Target()
			end,
		}

		local Results, LastError = nil, nil

		for _, Attempt in ipairs(Attempts) do
			local Success, Value = pcall(Attempt)

			if Success and type(Value) == "table" then
				Results = Value
				break
			end

			LastError = Value
		end

		assert(Results ~= nil, `filtergc errored on every call form: {tostring(LastError)}`)

		local Found = false

		for _, Value in pairs(Results) do
			if type(Value) == "table" and rawget(Value, "token") == "GeneralTestingConvention_filtergc" then
				Found = true
				break
			end
		end

		assert(Found, "filtergc did not include a table that was created moments before the scan.")

		return "found a table that was created moments before the scan."
	end,
})

Test({
	Name = "getcustomasset",
	Description = "Turns a workspace file into an asset URL that can be used by the game.",
	Function = function(Target)
		local WriteFile = GetFunctionFromName("writefile")
		local DeleteFile = GetFunctionFromName("delfile")

		assert(type(WriteFile) == "function", "writefile is required to test getcustomasset.")

		local Name = "GeneralTestingConvention_" .. math.random(1, 1000000000) .. ".txt"

		WriteFile(Name, "dummy asset")

		local Success, Asset = pcall(Target, Name)

		if DeleteFile then
			pcall(DeleteFile, Name)
		end

		assert(Success, `getcustomasset errored: {tostring(Asset)}`)
		assert(type(Asset) == "string", "getcustomasset did not return a string.")
		assert(
			string.find(Asset, "rbxassetid://") or string.find(Asset, "http") or string.find(Asset, "rbxasset://"),
			`getcustomasset returned {Asset}, which is not an asset URL.`
		)

		return "turned a workspace file into an asset URL."
	end,
})

Test({
	Name = "getfpscap",
	Description = "Returns the current frame rate cap.",
	Function = function(Target)
		local SetFpsCap = GetFunctionFromName("setfpscap")
		local Original = Target()

		assert(type(Original) == "number", "getfpscap did not return a number.")

		if type(SetFpsCap) == "function" then
			SetFpsCap(100)
			local Changed = Target()
			SetFpsCap(Original)

			assert(Changed == 100, `getfpscap returned {tostring(Changed)} after setfpscap set it to 100.`)

			return `read the fps cap and saw it change to 100 and back to {tostring(Original)}.`
		end

		return `read an fps cap of {tostring(Original)}.`
	end,
})

Test({
	Name = "setfpscap",
	Description = "Changes the frame rate cap.",
	Function = function(Target)
		local GetFpsCap = GetFunctionFromName("getfpscap")

		assert(type(GetFpsCap) == "function", "getfpscap is required to test setfpscap.")

		local Original = GetFpsCap()

		Target(100)
		local Changed = GetFpsCap()
		Target(Original)

		assert(Changed == 100, `setfpscap(100) left getfpscap returning {tostring(Changed)}.`)

		return "set the fps cap and getfpscap saw the change."
	end,
})

Report("Miscellaneous")

local IdentityChecksPassed = false
local Original = getthreadidentity()
local Test1, Test2, Test3
pcall(function()
	setthreadidentity(3)
	Test1 = (getthreadidentity() == 3)

	setthreadidentity(6)
	Test2 = (getthreadidentity() == 6)

	setthreadidentity(8)
	Test3 = (getthreadidentity() == 8)
end)

if Test1 and Test2 and Test3 then
	IdentityChecksPassed = true
end
pcall(setthreadidentity, Original)

local Internal = false
local InternalCheck = pcall(function(...)
	local a = setmetatable({}, {
		__index = function()
			return 1
		end,
	})
	pcall(function()
		hookmetamethod(a, "__index", function()
			return "GTC>sUNC"
		end)
	end)
	Internal = a.b == "GTC>sUNC"
end)

local Downsides = {}

pcall(function()
	game.OnClose = function(...)
		warn("GTC>sUNC")
	end
end)

if not Internal then
	table.insert(
		Downsides,
		"Executor is not internal, meaning it cannot run complex scripts and most silent aims (in short: it cannot hookfunction, hookmetamethod or hookmetatable)."
	)
end

local CallbackPassed = false

pcall(function()
	if getcallbackvalue(game, "OnClose") ~= nil then
		CallbackPassed = true
	end
end)

if not CallbackPassed then
	table.insert(
		Downsides,
		"getcallbackvalue returns nil on a specific test, this could point to low quality functions down the line."
	)
end

if not raknet or not raknet.add_send_hook then
	table.insert(Downsides, "The executor does not have RakNet, which makes desyncing a lot less simple.")
end

if not IdentityChecksPassed then
	table.insert(Downsides, "Executor has a weak setthreadidentity/getthreadidentity.")
end

local WasEnvLeaked = false
local function RandomString(Length)
	math.randomseed(os.time() ^ math.random())

	local CharacterSet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()_+-=[]{}|;:,.<>/?"
	local Result = ""

	for i = 1, Length do
		local RandomIndex = math.random(1, #CharacterSet)
		Result = Result .. CharacterSet:sub(RandomIndex, RandomIndex)
	end

	return Result
end
local Key = RandomString(100)
getgenv().GTCLeakingDetection = Key
local renv
local SetREnv = pcall(function()
	renv = getrenv()
end) -- BAC can detect this, will be removed if I have problems with it.
if SetREnv and renv.GTCLeakingDetection == Key or renv._G.GTCLeakingDetection == Key then
	WasEnvLeaked = true
end

if WasEnvLeaked then
	table.insert(Downsides, "The executor has a weak getgenv that can easily get leaked.")
end

local SpoofingIdentity = false
if Internal == false and getthreadidentity() > 3 then
	SpoofingIdentity = true
else
	SpoofingIdentity = false
end

if SpoofingIdentity then
	table.insert(
		Downsides,
		"The executor is spoofing it's identity. Supposedly, its identity is "
			.. getthreadidentity()
			.. " when it's actually 2-3."
	)
end

if #Downsides > 0 then
	print(
		"\n\n| Downsides |\nDownsides lets you know about potentially low quality function implementations.\n\n"
			.. table.concat(Downsides, "\n")
	)
end

local Summary = "The executor "
	.. (getexececutorname and getexecutorname() or identifyexecutor())
	.. " has passed "
	.. Passes
	.. " tests out of a total "
	.. (Passes + Fails)
	.. " tests, which adds up to a "
	.. math.round((if (Passes + Fails) > 0 then (Passes / (Passes + Fails)) * 100 else 0))
	.. "% pass rate that only took "
	.. string.format("%.6f", os.clock() - Start)
	.. " seconds."

task.defer(function()
	task.wait(0.025)
	game:GetService("LogService"):Info(("\n" .. Summary))
	game:GetService("LogService")
		:Info('\n\n"Executor testing, made accurate, fast and easy."\n - Veaquach @ General Testing Convention\n')

	print("General Testing Convention was made by Veaquach, github.com/Veaquach.")
end)
