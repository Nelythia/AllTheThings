--------------------------------------------------------------------------------
--                        A L L   T H E   T H I N G S                         --
--------------------------------------------------------------------------------
--				Copyright 2017-2021 Dylan Fortune (Crieve-Sargeras)           --
--------------------------------------------------------------------------------

local app = select(2, ...);
local L = app.L;

-- Assign the FactionID.
app.Faction = UnitFactionGroup("player");
if app.Faction == "Horde" then
	app.FactionID = Enum.FlightPathFaction.Horde;
elseif app.Faction == "Alliance" then
	app.FactionID = Enum.FlightPathFaction.Alliance;
else
	-- Neutral Pandaren or... something else. Scourge? Neat.
	app.FactionID = 0;
end

-- Performance Cache
-- While this may seem silly, caching references to commonly used APIs is actually a performance gain...
local C_ArtifactUI_GetAppearanceInfoByID = C_ArtifactUI.GetAppearanceInfoByID;
local C_Item_IsDressableItemByID = C_Item.IsDressableItemByID;
local C_TransmogCollection_GetAppearanceSourceInfo = C_TransmogCollection.GetAppearanceSourceInfo;
local C_TransmogCollection_GetAllAppearanceSources = C_TransmogCollection.GetAllAppearanceSources;
local C_TransmogCollection_GetIllusionSourceInfo = C_TransmogCollection.GetIllusionSourceInfo;
local C_TransmogCollection_GetItemInfo = C_TransmogCollection.GetItemInfo;
local C_TransmogCollection_PlayerHasTransmogItemModifiedAppearance = C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance;
local C_TransmogCollection_GetSourceInfo = C_TransmogCollection.GetSourceInfo;
local C_Map_GetMapInfo = C_Map.GetMapInfo;
local SetPortraitTexture = _G["SetPortraitTexture"];
local SetPortraitTextureFromDisplayID = _G["SetPortraitTextureFromCreatureDisplayID"];
local EJ_GetCreatureInfo = _G["EJ_GetCreatureInfo"];
local EJ_GetEncounterInfo = _G["EJ_GetEncounterInfo"];
local GetAchievementCriteriaInfo = _G["GetAchievementCriteriaInfo"];
local GetAchievementInfo = _G["GetAchievementInfo"];
local GetAchievementLink = _G["GetAchievementLink"];
local GetClassInfo = _G["GetClassInfo"];
local GetDifficultyInfo = _G["GetDifficultyInfo"];
local GetFactionInfoByID = _G["GetFactionInfoByID"];
local GetItemInfo = _G["GetItemInfo"];
local GetItemInfoInstant = _G["GetItemInfoInstant"];
local GetItemSpecInfo = _G["GetItemSpecInfo"];
local GetTitleName = _G["GetTitleName"];
local PlayerHasToy = _G["PlayerHasToy"];
local IsTitleKnown = _G["IsTitleKnown"];
local InCombatLockdown = _G["InCombatLockdown"];
local MAX_CREATURES_PER_ENCOUNTER = 9;
local DESCRIPTION_SEPARATOR = "`";
local rawget, rawset, tinsert, string_lower, tostring, ipairs, pairs, tonumber, wipe, sformat
	= rawget, rawset, tinsert, string.lower, tostring, ipairs, pairs, tonumber, wipe, string.format;
local ATTAccountWideData;
local ALLIANCE_ONLY = {
	1,
	3,
	4,
	7,
	11,
	22,
	25,
	29,
	30,
	32,
	34,
	37,
};
local HORDE_ONLY = {
	2,
	5,
	6,
	8,
	9,
	10,
	26,
	27,
	28,
	31,
	35,
	36,
};

-- Print/Debug/Testing Functions
app.print = function(...)
	print(L["TITLE"], ...);
end
app.report = function(...)
	if ... then
		app.print(...);
	end
	app.print(app.Version .. L["PLEASE_REPORT_MESSAGE"]);
end
app.PrintGroup = function(group,depth)
	depth = depth or 0;
	if group then
		local p = "";
		for i=0,depth,1 do
			p = p .. "-";
		end
		p = p .. tostring(group.key or group.text) .. ":" .. tostring(group[group.key or "NIL"]);
		print(p);
		if group.g then
			for i,sg in ipairs(group.g) do
				app.PrintGroup(sg,depth + 1);
			end
		end
	end
	print("---")
end
app.PrintTable = function(t,depth)
	if not t then print("nil"); return; end
	if type(t) ~= "table" then print(type(t),t); return; end
	depth = depth or 0;
	if depth == 0 then app._PrintTable = {}; end
	local p = "";
	for i=1,depth,1 do
		p = p .. "-";
	end
	-- dont accidentally recursively print the same table
	if not app._PrintTable[t] then
		app._PrintTable[t] = true;
		print(p,tostring(t)," {");
		for k,v in pairs(t) do
			if type(v) == "table" then
				print(p,k,":");
				if k == "parent" or k == "sourceParent" then
					print("SKIPPED")
				elseif k == "g" then
					print("#",v and #v)
				else
					app.PrintTable(v,depth + 1);
				end
			else
				print(p,k,":",tostring(v))
			end
		end
		if getmetatable(t) then
			print(p,"__index:");
			app.PrintTable(getmetatable(t).__index, depth + 1);
		end
		print(p,"}");
	else
		print(p,tostring(t),"RECURSIVE");
	end
end
--[[]]
app.PrintMemoryUsage = function(...)
	-- update memory value for ATT
	UpdateAddOnMemoryUsage();
	if ... then app.print(..., GetAddOnMemoryUsage("AllTheThings"));
	else app.print("Memory",GetAddOnMemoryUsage("AllTheThings")); end
end
--]]

-- Coroutine Helper Functions
app.refreshing = {};
app.EmptyTable = {};
app.EmptyFunction = function() end;
local function OnUpdate(self)
	for i=#self.__stack,1,-1 do
		-- print("Running Stack " .. i .. ":" .. self.__stack[i][2])
		if not self.__stack[i][1](self) then
			-- print("Removing Stack " .. i .. ":" .. self.__stack[i][2])
			table.remove(self.__stack, i);
		end
	end
	-- Stop running OnUpdate if nothing in the Stack to process
	if #self.__stack < 1 then
		self:SetScript("OnUpdate", nil);
	end
end
local function Push(self, name, method)
	if not self.__stack then
		self.__stack = {};
	end
	-- print("Push->" .. name);
	tinsert(self.__stack, { method, name });
	self:SetScript("OnUpdate", OnUpdate);
end
local function StartCoroutine(name, method, delaySec)
	if method and not app.refreshing[name] then
		local instance = coroutine.create(method);
		app.refreshing[name] = true;
		local pushCo = function()
				-- Check the status of the coroutine
				if instance and coroutine.status(instance) ~= "dead" then
					local ok, err = coroutine.resume(instance);
					if ok then return true;	-- This means more work is required.
					else
						-- Throw the error. Returning nothing is the same as canceling the work.
						-- local instanceTrace = debugstack(instance);
						error(err,2);
						-- print(debugstack(instance));
						-- print(err);
						-- app.report();
					end
				end
				-- print("coroutine complete",name);
				app.refreshing[name] = nil;
			end;
		if delaySec and delaySec > 0 then
			-- print("delayed coroutine",delaySec,name);
			C_Timer.After(delaySec, function() Push(app, name, pushCo) end);
		else
			-- print("coroutine starting",name);
			Push(app, name, pushCo);
		end
	-- else print("skipped coroutine",name);
	end
end
local Callback = app.Callback;
-- Triggers a timer callback method to run after the provided number of seconds with the provided params; the method can only be set to run once per delay
local function DelayedCallback(method, delaySec, ...)
	if not app.__callbacks[method] then
		app.__callbacks[method] = ... and {...} or true;
		-- app.PrintDebug("DelayedCallback:",method, ...)
		local newCallback = function()
			local args = app.__callbacks[method];
			app.__callbacks[method] = nil;
			-- callback with args/void
			if args ~= true then
				-- app.PrintDebug("DelayedCallback/args Running",method, unpack(args))
				method(unpack(args));
			else
				-- app.PrintDebug("DelayedCallback/void Running",method)
				method();
			end
			-- app.PrintDebug("DelayedCallback Done",method)
		end;
		C_Timer.After(math.max(0, delaySec or 0), newCallback);
	end
end
-- Triggers a timer callback method to run on the next game frame or following combat if in combat currently with the provided params; the method can only be set to run once per frame
local function AfterCombatCallback(method, ...)
	if not InCombatLockdown() then Callback(method, ...); return; end
	if not app.__callbacks[method] then
		app.__callbacks[method] = ... and {...} or true;
		-- If in combat, register to trigger on leave combat
		-- print("AfterCombatCallback:",method, ...)
		local newCallback = function()
			local args = app.__callbacks[method];
			app.__callbacks[method] = nil;
			-- AfterCombatCallback with args/void
			if args ~= true then
				-- print("AfterCombatCallback/args Running",method, unpack(args))
				method(unpack(args));
			else
				-- print("AfterCombatCallback/void Running",method)
				method();
			end
			-- print("AfterCombatCallback:Done",method)
		end;
		tinsert(app.__combatcallbacks, 1, newCallback);
		app:RegisterEvent("PLAYER_REGEN_ENABLED");
	end
end
-- Triggers a timer callback method to run either when current combat ends, or after the provided delay; the method can only be set to run once until it has been run
local function AfterCombatOrDelayedCallback(method, delaySec, ...)
	if InCombatLockdown() then
		-- print("chose AfterCombatCallback")
		AfterCombatCallback(method, ...);
	else
		-- print("chose DelayedCallback",delaySec)
		DelayedCallback(method, delaySec, ...);
	end
end
local function LocalizeGlobal(globalName, init)
	local val = _G[globalName];
	if init and not val then
		val = {};
		_G[globalName] = val;
	end
	return val;
end
local constructor = function(id, t, typeID)
	if t then
		if not rawget(t, "g") and rawget(t, 1) then
			return { g=t, [typeID]=id };
		else
			rawset(t, typeID, id);
			return t;
		end
	else
		return {[typeID] = id};
	end
end
local contains = function(arr, value)
	for _,value2 in ipairs(arr) do
		if value2 == value then return true; end
	end
end
local containsAny = function(arr, arr2)
	for _,v in ipairs(arr) do
		for _,w in ipairs(arr2) do
			if v == w then return true; end
		end
	end
end
local containsValue = function(dict, value)
	for _,value2 in pairs(dict) do
		if value2 == value then return true; end
	end
end
local indexOf = function(arr, value)
	for i,value2 in ipairs(arr) do
		if value2 == value then return i; end
	end
end

-- Iterative Function Runner
do
local FunctionQueue, ParameterBucketQueue, ParameterSingleQueue, Config = {}, {}, {}, { PerFrame = 1 };
local QueueIndex = 1;

-- maybe a coroutine directly which can be restarted without needing to be re-created?
local FunctionRunnerCoroutine = function()
	local i, perFrame = 1, Config.PerFrame;
	local params;
	local func = FunctionQueue[i];
	while func do
		perFrame = perFrame - 1;
		params = ParameterBucketQueue[i];
		if params then
			-- app.PrintDebug("FRC.Run.N",i,params)
			func(unpack(params));
		else
			-- app.PrintDebug("FRC.Run.1",i,ParameterSingleQueue[i])
			func(ParameterSingleQueue[i]);
		end
		-- app.PrintDebug("FRC.Done",i)
		if perFrame <= 0 then
			-- app.PrintDebug("FRC.Yield")
			coroutine.yield();
			perFrame = Config.PerFrame;
		end
		i = i + 1;
		func = FunctionQueue[i];
	end
	-- Run the OnEnd function if it exists
	local OnEnd = FunctionQueue[0];
	if OnEnd then OnEnd(); end
	-- when done with all functions in the queue, reset the queue index and clear the queues of data
	QueueIndex = 1;
	-- app.PrintDebug("FRC.End",#FunctionQueue)
	wipe(FunctionQueue);
	wipe(ParameterBucketQueue);
	wipe(ParameterSingleQueue);
end

-- Provides a utility which will process a given number of functions each frame in a queue
local FunctionRunner = {
	-- Adds a function to be run with any necessary parameters
	["Run"] = function(func, ...)
		if type(func) ~= "function" then
			error("Must be a 'function' type!")
		end
		FunctionQueue[QueueIndex] = func;
		-- app.PrintDebug("FR.Add",QueueIndex,...)
		local arrs = select("#", ...);
		if arrs == 1 then
			ParameterSingleQueue[QueueIndex] = ...;
		elseif arrs > 1 then
			ParameterBucketQueue[QueueIndex] = { ... };
		end
		QueueIndex = QueueIndex + 1;
		StartCoroutine("FunctionRunnerCoroutine", FunctionRunnerCoroutine);
	end,
	-- Defines how many functions will be executed per frame
	["SetPerFrame"] = function(count)
		Config.PerFrame = math.max(1, tonumber(count) or 1);
		-- app.PrintDebug("FR:",Config.PerFrame)
	end,
	-- Set a function to be run once the queue is empty. This function takes no parameters.
	["OnEnd"] = function(func)
		FunctionQueue[0] = func;
	end,
};

app.FunctionRunner = FunctionRunner;
end

-- Sorting Logic
(function()
local defaultComparison = function(a,b)
	-- If either object doesn't exist
	if a then
		if not b then
			return true;
		end
	elseif b then
		return false;
	else
		-- neither a or b exists, equality returns false
		return false;
	end
	-- If comparing non-tables
	if type(a) ~= "table" or type(b) ~= "table" then
		return a < b;
	end
	local acomp, bcomp;
	-- Maps 1st
	acomp = a.mapID;
	bcomp = b.mapID;
	if acomp then
		if not bcomp then return true; end
	elseif bcomp then
		return false;
	end
	-- Raids/Encounter 2nd
	acomp = a.isRaid;
	bcomp = b.isRaid;
	if acomp then
		if not bcomp then return true; end
	elseif bcomp then
		return false;
	end
	-- Quests 3rd
	acomp = a.questID;
	bcomp = b.questID;
	if acomp then
		if not bcomp then return true; end
	elseif bcomp then
		return false;
	end
	-- Items 4th
	acomp = a.itemID;
	bcomp = b.itemID;
	if acomp then
		if not bcomp then return true; end
	elseif bcomp then
		return false;
	end
	-- Any two similar-type groups via name
	acomp = string_lower(tostring(a.name));
	bcomp = string_lower(tostring(b.name));
	return acomp < bcomp;
end
local defaultTextComparison = function(a,b)
	-- If either object doesn't exist
	if a then
		if not b then
			return true;
		end
	elseif b then
		return false;
	else
		-- neither a or b exists, equality returns false
		return false;
	end
	-- Any two similar-type groups with text
	a = string_lower(tostring(a));
	b = string_lower(tostring(b));
	return a < b;
end
local defaultNameComparison = function(a,b)
	-- If either object doesn't exist
	if a then
		if not b then
			return true;
		end
	elseif b then
		return false;
	else
		-- neither a or b exists, equality returns false
		return false;
	end
	-- Any two similar-type groups with text
	a = string_lower(tostring(a.name));
	b = string_lower(tostring(b.name));
	return a < b;
end
local defaultValueComparison = function(a,b)
	-- If either object doesn't exist
	if a then
		if not b then
			return true;
		end
	elseif b then
		return false;
	else
		-- neither a or b exists, equality returns false
		return false;
	end
	return a < b;
end
local defaultHierarchyComparison = function(a,b)
	-- If either object doesn't exist
	if a then
		if not b then
			return true;
		end
	elseif b then
		return false;
	else
		-- neither a or b exists, equality returns false
		return false;
	end
	local acomp, bcomp;
	acomp = a.g and #a.g or 0;
	bcomp = b.g and #b.g or 0;
	return acomp < bcomp;
end
local defaultTotalComparison = function(a,b)
	-- If either object doesn't exist
	if a then
		if not b then
			return true;
		end
	elseif b then
		return false;
	else
		-- neither a or b exists, equality returns false
		return false;
	end
	local acomp, bcomp;
	acomp = a.total or 0;
	bcomp = b.total or 0;
	return acomp < bcomp;
end
app.SortDefaults = {
	["Global"] = defaultComparison,
	["Text"] = defaultTextComparison,
	["Name"] = defaultNameComparison,
	["Value"] = defaultValueComparison,
	-- Sorts objects first by whether they do not have sub-groups [.g] defined
	["Hierarchy"] = defaultHierarchyComparison,
	-- Sorts objects first by how many total collectibles they contain
	["Total"] = defaultTotalComparison,
};
local function Sort(t, compare, nested)
	if t then
		if not compare then compare = defaultComparison; end
		table.sort(t, compare);
		if nested then
			for i=#t,1,-1 do
				Sort(t[i].g, compare, nested);
			end
		end
	end
end
-- Safely-sorts a table using a provided comparison function and whether to propogate to nested groups
-- Wrapping in a pcall since sometimes the sorted values are able to change while being within the sort method. This causes the 'invalid sort order function' error
app.Sort = function(t, compare, nested)
	pcall(Sort, t, compare, nested);
end
local sortByNameSafely = function(a, b)
	if a and a.name then
		if b and b.name then
			return a.name <= b.name;
		end
		return true;
	end
	return false;
end
local function GetGroupSortValue(group)
	-- sub-groups on top
	-- >= 1
	if group.g then
		local total = group.total;
		if total then
			local progress = group.progress;
			-- completed groups at the very top, ordered by their own total
			if total == progress then
				-- 3 <= p
				return 2 + total;
			-- partially completed next
			elseif progress and progress > 0 then
				-- 1 < p <= 2
				return 1 + (progress / total);
			-- no completion, ordered by their own total in reverse
			-- 0 < p <= 1
			else
				return (1 / total);
			end
		end
	-- collectibles next
	-- >= 0
	elseif group.collectible then
		-- = 0.5
		if group.collected then
			return 0.5;
		else
			-- 0 <= p < 0.5
			return (group.sortProgress or 0) / 2;
		end
	-- trackables next
	-- -1 <= p <= -0.5
	elseif group.trackable then
		if group.saved then
			return -0.5;
		else
			return -1;
		end
	-- remaining last
	-- = -2
	else
		return -2;
	end
end
-- Sorts a group using the provided sortType, whether to recurse through nested groups, and whether sorting should only take place given the group having a conditional field
local function SortGroup(group, sortType, row, recur, conditionField)
	if group.g then
		-- either sort visible groups or by conditional
        if (not conditionField and group.visible) or (conditionField and group[conditionField]) then
			-- app.PrintDebug("sorting",group.key,group.key and group[group.key],"by",sortType,"recur",recur,"condition",conditionField)
			if sortType == "name" then
				app.Sort(group.g);
			elseif sortType == "progress" then
				local progA, progB;
				app.Sort(group.g, function(a, b)
					progA = GetGroupSortValue(a);
					progB = GetGroupSortValue(b);
					return progA > progB;
				end);
			else
				local sortA, sortB;
				app.Sort(group.g, function(a, b)
					sortA = a and tostring(a[sortType]);
					sortB = b and tostring(b[sortType]);
					return sortA < sortB;
				end);
			end
			-- since this group was sorted, clear any SortInfo which may have caused it
			group.SortInfo = nil;
		end
		-- TODO: Add more sort types?
		if recur then
			for _,o in ipairs(group.g) do
				SortGroup(o, sortType, nil, recur, conditionField);
			end
		end
	end
	if row then
		row:GetParent():GetParent():Update();
		app.print("Finished Sorting.");
	end
end
app.SortGroup = SortGroup;
-- Allows defining SortGroup data which is only executed when the group is actually expanded
local function SortGroupDelayed(group, sortType, row, recur, conditionField)
	-- app.PrintDebug("Delayed Sort defined for",group.text)
	group.SortInfo = { sortType, row, recur, conditionField };
end
app.SortGroupDelayed = SortGroupDelayed;
end)();

-- Performs table.concat(tbl, sep, i, j) on the given table, but uses the specified field of table values if provided,
-- with a default fallback value if the field does not exist on the table entry
app.TableConcat = function(tbl, field, def, sep, i, j)
	if tbl then
		if field then
			local tblvals, tinsert = {}, tinsert;
			for _,val in ipairs(tbl) do
				tinsert(tblvals, val[field] or def);
			end
			return table.concat(tblvals, sep, i, j);
		else
			return table.concat(tbl, sep, i, j);
		end
	end
	return "";
end
-- Allows efficiently appending the content of multiple arrays (in sequence) onto the end of the provided array, or new empty array
app.ArrayAppend = function(a1, ...)
	local arrs = select("#", ...);
	if arrs > 0 then
		a1 = a1 or {};
		local i, select, a = #a1 + 1, select;
		for n=1,arrs do
			a = select(n, ...);
			if a then
				for ai=1,#a do
					a1[i] = a[ai];
					i = i + 1;
				end
			end
		end
	end
	return a1;
end
-- Allows for returning a reversed array. Will do nothing for un-ordered tables or tables with a single entry
app.ReverseOrder = function(a)
	if a[1] and a[2] then
		local b, n, j = {}, #a, 1;
		for i=n,1,-1 do
			b[j] = a[i];
			j = j + 1;
		end
		return b;
	end
	return a;
end

-- Data Lib
local attData;
local AllTheThingsTempData = {}; 	-- For temporary data.
local AllTheThingsAD = {};			-- For account-wide data.
local function SetDataMember(member, data)
	rawset(AllTheThingsAD, member, data);
end
local function GetDataMember(member, default)
	attData = rawget(AllTheThingsAD, member);
	if attData == nil then
		rawset(AllTheThingsAD, member, default);
		return default;
	else
		return attData;
	end
end
local function SetTempDataMember(member, data)
	rawset(AllTheThingsTempData, member, data);
end
local function GetTempDataMember(member, default)
	attData = rawget(AllTheThingsTempData, member);
	if attData == nil then
		rawset(AllTheThingsTempData, member, default);
		return default;
	else
		return attData;
	end
end
local function SetDataSubMember(member, submember, data)
	attData = rawget(AllTheThingsAD, member);
	if attData == nil then
		attData = {};
		rawset(attData, submember, data);
		rawset(AllTheThingsAD, member, attData);
	else
		rawset(attData, submember, data);
	end
end
local function GetDataSubMember(member, submember, default)
	attData = rawget(AllTheThingsAD,member);
	if attData then
		attData = rawget(attData, submember);
		if attData == nil then
			rawset(rawget(AllTheThingsAD,member), submember, default);
			return default;
		else
			return attData;
		end
	else
		attData = {};
		rawset(attData, submember, default);
		rawset(AllTheThingsAD, member, attData);
		return default;
	end
end
local function SetTempDataSubMember(member, submember, data)
	attData = rawget(AllTheThingsTempData, member);
	if attData == nil then
		attData = {};
		rawset(attData, submember, data);
		rawset(AllTheThingsTempData, member, attData);
	else
		rawset(attData, submember, data);
	end
end
local function GetTempDataSubMember(member, submember, default)
	attData = rawget(AllTheThingsTempData,member);
	if attData then
		attData = rawget(attData, submember);
		if attData == nil then
			rawset(rawget(AllTheThingsTempData,member), submember, default);
			return default;
		else
			return attData;
		end
	else
		attData = {};
		rawset(attData, submember, default);
		rawset(AllTheThingsTempData, member, attData);
		return default;
	end
end

-- Returns an object which contains no data, but can return values from an overrides table, and be loaded/created when a specific field is attempted to be referenced
-- i.e. Create a data group which contains no information but will attempt to populate itself when [loadField] is referenced
app.DelayLoadedObject = function(objFunc, loadField, overrides, ...)
	local o;
	local params = {...};
	local loader = {
		__index = function(t, key)
			-- load the object if it matches the load field and not yet loaded
			if not o and key == loadField then
				o = objFunc(unpack(params));
				-- parent of the underlying object should correspond to the hierarchical parent of t (dlo)
				-- local dloParent = rawget(t, "parent");
				-- app.PrintDebug("DLO:Loaded-parent:",dloParent,dloParent and dloParent.hash)
				rawset(o, "parent", rawget(t, "parent"));
				rawset(t, "__o", o);
				-- DLOs can now have an OnLoad function which runs here when loaded for the first time
				if overrides.OnLoad then overrides.OnLoad(o); end
			end

			-- override for the object
			local override = overrides and overrides[key];
			if override ~= nil then
				-- overrides can also be a function which will execute once the object has been created
				if o and type(override) == "function" then
					return override(o, key);
				else
					return override;
				end
			-- existing object, then reference the respective key
			elseif o then
				return o[key];
			end
		end,
		-- transfer field sets to the underlying object if the field does not have an override for the object
		__newindex = function(t, key, val)
			if o then
				if not overrides[key] then
					-- app.PrintDebug("DLO:__newindex:",o.hash,key,val)
					rawset(o, key, val);
				end
			elseif key == "parent" then
				rawset(t, key, val);
			end
		end,
	};
	-- data is just an empty table with a loader metatable
	local dlo = setmetatable({__dlo=true}, loader);
	return dlo;
end
app.SetDataMember = SetDataMember;
app.GetDataMember = GetDataMember;
app.SetDataSubMember = SetDataSubMember;
app.GetDataSubMember = GetDataSubMember;
app.GetTempDataMember = GetTempDataMember;
app.GetTempDataSubMember = GetTempDataSubMember;
app.ReturnTrue = function() return true; end
app.ReturnFalse = function() return false; end

local function RoundNumber(number, decimalPlaces)
	local ret;
	if number < 60 then
		ret = number .. " second(s)";
	else
		ret = (("%%.%df"):format(decimalPlaces)):format(number/60) .. " minute(s)";
	end
	return ret;
end

local function formatNumericWithCommas(amount)
  local formatted, k = amount
  while true do
	formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
	if (k==0) then
	  break
	end
  end
  return formatted
end
local function GetMoneyString(amount)
	if amount > 0 then
		local formatted
		local g,s,c = math.floor(amount / 100 / 100), math.floor((amount / 100) % 100), math.floor(amount % 100)
		if g > 0 then
			formatted = formatNumericWithCommas(g) .. "|TInterface\\MONEYFRAME\\UI-GoldIcon:0|t"
		end
		if s > 0 then
			formatted = (formatted or "") .. s .. "|TInterface\\MONEYFRAME\\UI-SilverIcon:0|t"
		end
		if c > 0 then
			formatted = (formatted or "") .. c .. "|TInterface\\MONEYFRAME\\UI-CopperIcon:0|t"
		end
		return formatted
	end
	return amount
end

do -- TradeSkill Functionality
local tradeSkillSpecializationMap = {
	[202] = {	-- Engineering
		20219,    -- Gnomish Engineering
		20222     -- Goblin Engineering
	},
	[164] = {	-- Blacksmithing
		9788,	-- Armorsmith
		9787,	-- Weaponsmith
	},
};
local specializationTradeSkillMap = {
	-- Engineering Skills
	[20219] = 202,  -- Gnomish Engineering
	[20222] = 202,   -- Goblin Engineering
	-- Blacksmithing Skills
	[9788] = 9788,	-- Armorsmith
	[9787] = 9787,	-- Weaponsmith
	[17041] = 17041,	-- Master Axesmith
	[17040] = 17040,	-- Master Hammersmith
	[17039] = 17039,	-- Master Swordsmith
	-- Leatherworking
	[10656] = 10656,	-- Dragonscale Leatherworking
	[10658] = 10658,	-- Elemental Leatherworking
	[10660] = 10660,	-- Tribal Leatherworking
	-- Tailoring
	[26801] = 26801,	-- Shadoweave Tailoring
	[26797] = 26797,	-- Spellfire Tailoring
	[26798] = 26798,	-- Mooncloth Tailoring
};
-- Map all Skill IDs to the old Skill IDs
local tradeSkillMap = {
	-- Alchemy Skills
	[171] = 171,	-- Alchemy [7.3.5]
	[2485] = 171,	-- Classic Alchemy [8.0.1]
	[2484] = 171,	-- Outland Alchemy [8.0.1]
	[2483] = 171,	-- Northrend Alchemy [8.0.1]
	[2482] = 171,	-- Cataclysm Alchemy [8.0.1]
	[2481] = 171,	-- Pandaria Alchemy [8.0.1]
	[2480] = 171,	-- Draenor Alchemy [8.0.1]
	[2479] = 171,	-- Legion Alchemy [8.0.1]
	[2478] = 171,	-- Kul Tiran Alchemy [8.0.1]
	[2750] = 171,	-- Shadowlands Alchemy [9.0.1]

	-- Archaeology Skills
	[794] = 794,	-- Archaeology [7.3.5]

	-- Blacksmithing Skills
	[164] = 164,	-- Blacksmithing [7.3.5]
	[2477] = 164,	-- Classic Blacksmithing [8.0.1]
	[2476] = 164,	-- Outland Blacksmithing [8.0.1]
	[2475] = 164,	-- Northrend Blacksmithing [8.0.1]
	[2474] = 164,	-- Cataclysm Blacksmithing [8.0.1]
	[2473] = 164,	-- Pandaria Blacksmithing [8.0.1]
	[2472] = 164,	-- Draenor Blacksmithing [8.0.1]
	[2454] = 164,	-- Legion Blacksmithing [8.0.1]
	[2437] = 164,	-- Kul Tiran Blacksmithing [8.0.1]
	[2751] = 164,	-- Shadowlands Blacksmithing [9.0.1]

	-- Cooking Skills
	[185] = 185,	-- Cooking [7.3.5]
	[975] = 185,	-- Way of the Grill
	[976] = 185,	-- Way of the Wok
	[977] = 185,	-- Way of the Pot
	[978] = 185,	-- Way of the Steamer
	[979] = 185,	-- Way of the Oven
	[980] = 185,	-- Way of the Brew
	[2548] = 185,	-- Classic Cooking [8.0.1]
	[2547] = 185,	-- Outland Cooking [8.0.1]
	[2546] = 185,	-- Northrend Cooking [8.0.1]
	[2545] = 185,	-- Cataclysm Cooking [8.0.1]
	[2544] = 185,	-- Pandaria Cooking [8.0.1]
	[2543] = 185,	-- Draenor Cooking [8.0.1]
	[2542] = 185,	-- Legion Cooking [8.0.1]
	[2541] = 185,	-- Kul Tiran Cooking [8.0.1]
	[2752] = 185,	-- Shadowlands Cooking [9.0.1]

	-- Enchanting Skills
	[333] = 333,	-- Enchanting [7.3.5]
	[2494] = 333,	-- Classic Enchanting [8.0.1]
	[2493] = 333,	-- Outland Enchanting [8.0.1]
	[2492] = 333,	-- Northrend Enchanting [8.0.1]
	[2491] = 333,	-- Cataclysm Enchanting [8.0.1]
	[2489] = 333,	-- Pandaria Enchanting [8.0.1]
	[2488] = 333,	-- Draenor Enchanting [8.0.1]
	[2487] = 333,	-- Legion Enchanting [8.0.1]
	[2486] = 333,	-- Kul Tiran Enchanting [8.0.1]
	[2753] = 333,	-- Shadowlands Enchanting [8.0.1]

	-- Engineering Skills
	[202] = 202,	-- Engineering [7.3.5]
	[2506] = 202,	-- Classic Engineering [8.0.1]
	[2505] = 202,	-- Outland Engineering [8.0.1]
	[2504] = 202,	-- Northrend Engineering [8.0.1]
	[2503] = 202,	-- Cataclysm Engineering [8.0.1]
	[2502] = 202,	-- Pandaria Engineering [8.0.1]
	[2501] = 202,	-- Draenor Engineering [8.0.1]
	[2500] = 202,	-- Legion Engineering [8.0.1]
	[2499] = 202,	-- Kul Tiran Engineering [8.0.1]
	[2755] = 202,	-- Shadowlands Engineering [9.0.1]

	-- First Aid Skills
	[129] = 129,	-- First Aid [7.3.5] [REMOVED FROM GAME]

	-- Fishing Skills
	[356] = 356,	-- Fishing [7.3.5]
	[2592] = 356,	-- Classic Fishing [8.0.1]
	[2591] = 356,	-- Outland Fishing [8.0.1]
	[2590] = 356,	-- Northrend Fishing [8.0.1]
	[2589] = 356,	-- Cataclysm Fishing [8.0.1]
	[2588] = 356,	-- Pandaria Fishing [8.0.1]
	[2587] = 356,	-- Draenor Fishing [8.0.1]
	[2586] = 356,	-- Legion Fishing [8.0.1]
	[2585] = 356,	-- Kul Tiran Fishing [8.0.1]
	[2754] = 356,	-- Shadowlands Fishing [9.0.1]

	-- Herbalism Skills
	[182] = 182,	-- Herbalism [7.3.5]
	[2556] = 182,	-- Classic Herbalism [8.0.1]
	[2555] = 182,	-- Outland Herbalism [8.0.1]
	[2554] = 182,	-- Northrend Herbalism [8.0.1]
	[2553] = 182,	-- Cataclysm Herbalism [8.0.1]
	[2552] = 182,	-- Pandaria Herbalism [8.0.1]
	[2551] = 182,	-- Draenor Herbalism [8.0.1]
	[2550] = 182,	-- Legion Herbalism [8.0.1]
	[2549] = 182,	-- Kul Tiran Herbalism [8.0.1]
	[2760] = 182,	-- Shadowlands Herbalism [9.0.1]

	-- Inscription Skills
	[773] = 773,	-- Inscription [7.3.5]
	[2514] = 773,	-- Classic Inscription [8.0.1]
	[2513] = 773,	-- Outland Inscription [8.0.1]
	[2512] = 773,	-- Northrend Inscription [8.0.1]
	[2511] = 773,	-- Cataclysm Inscription [8.0.1]
	[2510] = 773,	-- Pandaria Inscription [8.0.1]
	[2509] = 773,	-- Draenor Inscription [8.0.1]
	[2508] = 773,	-- Legion Inscription [8.0.1]
	[2507] = 773,	-- Kul Tiran Inscription [8.0.1]
	[2756] = 773,	-- Shadowlands Inscription [8.0.1]

	-- Jewelcrafting Skills
	[755] = 755,	-- Jewelcrafting [7.3.5]
	[2524] = 755,	-- Classic Jewelcrafting [8.0.1]
	[2523] = 755,	-- Outland Jewelcrafting [8.0.1]
	[2522] = 755,	-- Northrend Jewelcrafting [8.0.1]
	[2521] = 755,	-- Cataclysm Jewelcrafting [8.0.1]
	[2520] = 755,	-- Pandaria Jewelcrafting [8.0.1]
	[2519] = 755,	-- Draenor Jewelcrafting [8.0.1]
	[2518] = 755,	-- Legion Jewelcrafting [8.0.1]
	[2517] = 755,	-- Kul Tiran Jewelcrafting [8.0.1]
	[2757] = 755,	-- Shadowlands Jewelcrafting [9.0.1]

	-- Leatherworking Skills
	[165] = 165,	-- Leatherworking [7.3.5]
	[2532] = 165,	-- Classic Leatherworking [8.0.1]
	[2531] = 165,	-- Outland Leatherworking [8.0.1]
	[2530] = 165,	-- Northrend Leatherworking [8.0.1]
	[2529] = 165,	-- Cataclysm Leatherworking [8.0.1]
	[2528] = 165,	-- Pandaria Leatherworking [8.0.1]
	[2527] = 165,	-- Draenor Leatherworking [8.0.1]
	[2526] = 165,	-- Legion Leatherworking [8.0.1]
	[2525] = 165,	-- Kul Tiran Leatherworking [8.0.1]
	[2758] = 165,	-- Shadowlands Leatherworking [9.0.1]

	-- Mining Skills
	[186] = 186,	-- Mining [7.3.5]
	[2572] = 186,	-- Classic Mining [8.0.1]
	[2571] = 186,	-- Outland Mining [8.0.1]
	[2570] = 186,	-- Northrend Mining [8.0.1]
	[2569] = 186,	-- Cataclysm Mining [8.0.1]
	[2568] = 186,	-- Pandaria Mining [8.0.1]
	[2567] = 186,	-- Draenor Mining [8.0.1]
	[2566] = 186,	-- Legion Mining [8.0.1]
	[2565] = 186,	-- Kul Tiran Mining [8.0.1]
	[2761] = 186,	-- Shadowlands Mining [9.0.1]

	-- Skinning Skills
	[393] = 393,	-- Skinning [7.3.5]
	[2564] = 393,	-- Classic Skinning [8.0.1]
	[2563] = 393,	-- Outland Skinning [8.0.1]
	[2562] = 393,	-- Northrend Skinning [8.0.1]
	[2561] = 393,	-- Cataclysm Skinning [8.0.1]
	[2560] = 393,	-- Pandaria Skinning [8.0.1]
	[2559] = 393,	-- Draenor Skinning [8.0.1]
	[2558] = 393,	-- Legion Skinning [8.0.1]
	[2557] = 393,	-- Kul Tiran Skinning [8.0.1]
	[2762] = 393,	-- Shadowlands Skinning [9.0.1]

	-- Tailoring Skills
	[197] = 197,	-- Tailoring [7.3.5]
	[2540] = 197,	-- Classic Tailoring [8.0.1]
	[2539] = 197,	-- Outland Tailoring [8.0.1]
	[2538] = 197,	-- Northrend Tailoring [8.0.1]
	[2537] = 197,	-- Cataclysm Tailoring [8.0.1]
	[2536] = 197,	-- Pandaria Tailoring [8.0.1]
	[2535] = 197,	-- Draenor Tailoring [8.0.1]
	[2534] = 197,	-- Legion Tailoring [8.0.1]
	[2533] = 197,	-- Kul Tiran Tailoring [8.0.1]
	[2759] = 197,	-- Shadowlands Tailoring [9.0.1]
};
local function GetBaseTradeSkillID(skillID)
	return tradeSkillMap[skillID] or skillID;
end
local function GetTradeSkillSpecialization(skillID)
	return tradeSkillSpecializationMap[skillID];
end
app.GetTradeSkillLine = function()
	local profInfo = C_TradeSkillUI.GetBaseProfessionInfo();
	return GetBaseTradeSkillID(profInfo.professionID);
end
app.GetSpecializationBaseTradeSkill = function(specializationID)
	return specializationTradeSkillMap[specializationID];
end
-- Refreshes the known Trade Skills/Professions of the current character (app.CurrentCharacter.Professions)
app.RefreshTradeSkillCache = function()
	local cache = app.CurrentCharacter.Professions;
	wipe(cache);
	-- "Professions" that anyone can "know"
	cache[2720] = true;	-- Junkyard Tinkering
	cache[2791] = true;	-- Ascension Crafting
	cache[2819] = true;	-- Protoform Synthesis
	cache[2847] = true;	-- Tuskarr Fishing Gear
	local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions();
	for i,j in ipairs({prof1 or 0, prof2 or 0, archaeology or 0, fishing or 0, cooking or 0, firstAid or 0}) do
		if j ~= 0 then
			local prof = select(7, GetProfessionInfo(j));
			cache[GetBaseTradeSkillID(prof)] = true;
			local specializations = GetTradeSkillSpecialization(prof);
			if specializations ~= nil then
				for _,s in pairs(specializations) do
					if s and app.IsSpellKnownHelper(s) then
						cache[s] = true;
					end
				end
			end
		end
	end
end
end -- TradeSkill Functionality

-- Game Tooltip Icon
local GameTooltipIcon = CreateFrame("FRAME", nil, GameTooltip);
GameTooltipIcon:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", 0, 0);
GameTooltipIcon:SetSize(72, 72);
GameTooltipIcon.icon = GameTooltipIcon:CreateTexture(nil, "ARTWORK");
GameTooltipIcon.icon:SetAllPoints(GameTooltipIcon);
GameTooltipIcon.icon:Show();
GameTooltipIcon.icon.Background = GameTooltipIcon:CreateTexture(nil, "BACKGROUND");
GameTooltipIcon.icon.Background:SetAllPoints(GameTooltipIcon);
GameTooltipIcon.icon.Background:Show();
GameTooltipIcon.icon.Border = GameTooltipIcon:CreateTexture(nil, "BORDER");
GameTooltipIcon.icon.Border:SetAllPoints(GameTooltipIcon);
GameTooltipIcon.icon.Border:Show();
GameTooltipIcon:Hide();

-- Model is used to display the model of an NPC/Encounter.
local GameTooltipModel, model, fi = CreateFrame("FRAME", "ATTGameTooltipModel", GameTooltip, BackdropTemplateMixin and "BackdropTemplate");
GameTooltipModel:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", 0, 0);
GameTooltipModel:SetSize(128, 128);
GameTooltipModel:SetBackdrop({
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
});
GameTooltipModel:SetBackdropBorderColor(1, 1, 1, 1);
GameTooltipModel:SetBackdropColor(0, 0, 0, 1);
GameTooltipModel.Models = {};
GameTooltipModel.Model = CreateFrame("DressUpModel", nil, GameTooltipModel);
GameTooltipModel.Model:SetPoint("TOPLEFT", GameTooltipModel ,"TOPLEFT", 4, -4)
GameTooltipModel.Model:SetPoint("BOTTOMRIGHT", GameTooltipModel ,"BOTTOMRIGHT", -4, 4)
GameTooltipModel.Model:SetFacing(MODELFRAME_DEFAULT_ROTATION);
GameTooltipModel.Model:SetScript("OnUpdate", function(self, elapsed)
	self:SetFacing(self:GetFacing() + elapsed);
end);
GameTooltipModel.Model:Hide();

for i=1,MAX_CREATURES_PER_ENCOUNTER do
	model = CreateFrame("DressUpModel", "ATTGameTooltipModel" .. i, GameTooltipModel);
	model:SetPoint("TOPLEFT", GameTooltipModel ,"TOPLEFT", 4, -4);
	model:SetPoint("BOTTOMRIGHT", GameTooltipModel ,"BOTTOMRIGHT", -4, 4);
	model:SetCamDistanceScale(1.7);
	model:SetDisplayInfo(987);
	model:SetFacing(MODELFRAME_DEFAULT_ROTATION);
	fi = math.floor(i / 2);
	model:SetPosition(fi * -0.1, (fi * (i % 2 == 0 and -1 or 1)) * ((MAX_CREATURES_PER_ENCOUNTER - i) * 0.1), fi * 0.2 - 0.3);
	--model:SetDepth(i);
	model:Hide();
	tinsert(GameTooltipModel.Models, model);
end
GameTooltipModel.HideAllModels = function(self)
	for i=1,MAX_CREATURES_PER_ENCOUNTER do
		GameTooltipModel.Models[i]:Hide();
	end
	GameTooltipModel.Model:Hide();
end
GameTooltipModel.SetCreatureID = function(self, creatureID)
	GameTooltipModel.HideAllModels(self);
	if creatureID > 0 then
		self.Model:SetUnit("none");
		self.Model:SetCreature(creatureID);
		local displayID = self.Model:GetDisplayInfo();
		if not displayID then
			Push(app, "SetCreatureID", function()
				if self.lastModel == creatureID then
					self:SetCreatureID(creatureID);
				end
			end);
		end
	end
	self:Show();
end
GameTooltipModel.SetRotation = function(number)
	GameTooltipModel.Model:SetFacing(number and ((number * math.pi) / 180) or MODELFRAME_DEFAULT_ROTATION);
end
GameTooltipModel.SetScale = function(number)
	GameTooltipModel.Model:SetCamDistanceScale(number or 1);
end
GameTooltipModel.TrySetDisplayInfos = function(self, reference, displayInfos)
	if displayInfos then
		local count = #displayInfos;
		if count > 0 then
			local rotation = reference.modelRotation and ((reference.modelRotation * math.pi) / 180) or MODELFRAME_DEFAULT_ROTATION;
			local scale = reference.modelScale or 1;
			if count > 1 then
				count = math.min(count, MAX_CREATURES_PER_ENCOUNTER);
				local ratio = count / MAX_CREATURES_PER_ENCOUNTER;
				if count < 3 then
					for i=1,count do
						model = self.Models[i];
						model:SetDisplayInfo(displayInfos[i]);
						model:SetCamDistanceScale(scale);
						model:SetFacing(rotation);
						model:SetPosition(0, (i % 2 == 0 and 0.5 or -0.5), 0);
						model:Show();
					end
				else
					scale = (1 + (ratio * 0.5)) * scale;
					for i=1,count do
						model = self.Models[i];
						model:SetDisplayInfo(displayInfos[i]);
						model:SetCamDistanceScale(scale);
						model:SetFacing(rotation);
						fi = math.floor(i / 2);
						model:SetPosition(fi * -0.1, (fi * (i % 2 == 0 and -1 or 1)) * ((MAX_CREATURES_PER_ENCOUNTER - i) * 0.1), fi * 0.2 - (ratio * 0.15));
						model:Show();
					end
				end
			else
				self.Model:SetFacing(rotation);
				self.Model:SetCamDistanceScale(scale);
				self.Model:SetDisplayInfo(displayInfos[1]);
				self.Model:Show();
			end
			self:Show();
			return true;
		end
	end
end
-- Attempts to return the displayID for the data, or every displayID if 'all' is specified
local function GetDisplayID(data, all)
	-- don't create a displayID for groups with a sourceID/itemID already
	if data.s or data.itemID or data.difficultyID then return; end
	if all then
		local displayInfo, _ = {};
		-- specific displayID
		_ = data.displayID;
		if _ then tinsert(displayInfo, _); rawset(data,"displayInfo",displayInfo); return displayInfo; end

		-- specific creatureID for displayID
		_ = data.creatureID and app.NPCDisplayIDFromID[data.creatureID];
		if _ then tinsert(displayInfo, _); rawset(data,"displayInfo",displayInfo); return displayInfo; end

		-- loop through "n" providers
		if data.providers then
			for k,v in pairs(data.providers) do
				-- if one of the providers is an NPC, we should show its texture regardless of other providers
				if v[1] == "n" then
					_ = v[2] and app.NPCDisplayIDFromID[v[2]];
					if _ then tinsert(displayInfo, _); end
				end
			end
		end
		if displayInfo[1] then rawset(data,"displayInfo",displayInfo); return displayInfo; end

		-- for quest givers
		if data.qgs then
			for k,v in pairs(data.qgs) do
				_ = v and app.NPCDisplayIDFromID[v];
				if _ then tinsert(displayInfo, _); end
			end
		end
		if displayInfo[1] then rawset(data,"displayInfo",displayInfo); return displayInfo; end

		-- otherwise use the attached crs if so
		if data.crs then
			for k,v in pairs(data.crs) do
				_ = v and app.NPCDisplayIDFromID[v];
				if _ then tinsert(displayInfo, _); end
			end
		end
		if displayInfo[1] then rawset(data,"displayInfo",displayInfo); return displayInfo; end
	else
		-- specific displayID
		local _ = data.displayID or data.fetchedDisplayID;
		if _ then return _; end

		-- specific creatureID for displayID
		_ = data.creatureID and app.NPCDisplayIDFromID[data.creatureID];
		if _ then rawset(data,"fetchedDisplayID",_); return _; end

		-- loop through "n" providers
		if data.providers then
			for k,v in pairs(data.providers) do
				-- if one of the providers is an NPC, we should show its texture regardless of other providers
				if v[1] == "n" then
					_ = v[2] and app.NPCDisplayIDFromID[v[2]];
					if _ then rawset(data,"fetchedDisplayID",_); return _; end
				end
			end
		end

		-- for quest givers
		if data.qgs then
			for k,v in pairs(data.qgs) do
				_ = v and app.NPCDisplayIDFromID[v];
				if _ then rawset(data,"fetchedDisplayID",_); return _; end
			end
		end

		-- otherwise use the attached crs if so
		if data.crs then
			for k,v in pairs(data.crs) do
				_ = v and app.NPCDisplayIDFromID[v];
				if _ then rawset(data,"fetchedDisplayID",_); return _; end
			end
		end
	end
end
GameTooltipModel.TrySetModel = function(self, reference)
	GameTooltipModel.HideAllModels(self);
	if app.Settings:GetTooltipSetting("Models") then
		self.lastModel = reference;
		local displayInfos = reference.displayInfo or GetDisplayID(reference, true);
		if GameTooltipModel.TrySetDisplayInfos(self, reference, displayInfos) then
			return true;
		end

		if reference.displayID then
			self.Model:SetFacing(reference.modelRotation and ((reference.modelRotation * math.pi) / 180) or MODELFRAME_DEFAULT_ROTATION);
			self.Model:SetCamDistanceScale(reference.modelScale or 1);
			self.Model:SetDisplayInfo(reference.displayID);
			self.Model:Show();
			self:Show();
			return true;
		elseif reference.modelID then
			self.Model:SetFacing(reference.modelRotation and ((reference.modelRotation * math.pi) / 180) or MODELFRAME_DEFAULT_ROTATION);
			self.Model:SetCamDistanceScale(reference.modelScale or 1);
			self.Model:SetDisplayInfo(reference.modelID);
			self.Model:Show();
			self:Show();
			return true;
		elseif reference.unit and not reference.icon then
			self.Model:SetFacing(reference.modelRotation and ((reference.modelRotation * math.pi) / 180) or MODELFRAME_DEFAULT_ROTATION);
			self.Model:SetCamDistanceScale(reference.modelScale or 1);
			self.Model:SetUnit(reference.unit);
			self.Model:Show();
			self:Show();
		end

		if reference.s and reference.artifactID then
			-- TODO: would be cool if this showed for all sourceID's, but it seems to be random which items show a model from the visualID
			local sourceInfo = C_TransmogCollection_GetSourceInfo(reference.s);
			if sourceInfo and sourceInfo.visualID then
				self.Model:SetCamDistanceScale(0.8);
				self.Model:SetItemAppearance(sourceInfo.visualID);
				self.Model:Show();
				self:Show();
				return true;
			end
		end

		local modelID = tonumber(reference.model);
		if modelID and modelID > 0 then
			self.Model:SetFacing(reference.modelRotation and ((reference.modelRotation * math.pi) / 180) or MODELFRAME_DEFAULT_ROTATION);
			self.Model:SetCamDistanceScale(reference.modelScale or 1);
			self.Model:SetUnit("none");
			self.Model:SetModel(modelID);
			self.Model:Show();
			self:Show();
			return true;
		elseif reference.creatureID and reference.creatureID > 0 then
			self.Model:SetFacing(reference.modelRotation and ((reference.modelRotation * math.pi) / 180) or MODELFRAME_DEFAULT_ROTATION);
			self.Model:SetCamDistanceScale(reference.modelScale or 1);
			self:SetCreatureID(reference.creatureID);
			self.Model:Show();
			return true;
		end
		if reference.atlas then
			GameTooltipIcon:SetSize(64,64);
			GameTooltipIcon.icon:SetAtlas(reference.atlas);
			GameTooltipIcon:Show();
			if reference["atlas-background"] then
				GameTooltipIcon.icon.Background:SetAtlas(reference["atlas-background"]);
				GameTooltipIcon.icon.Background:Show();
			end
			if reference["atlas-border"] then
				GameTooltipIcon.icon.Border:SetAtlas(reference["atlas-border"]);
				GameTooltipIcon.icon.Border:Show();
				if reference["atlas-color"] then
					local swatches = reference["atlas-color"];
					GameTooltipIcon.icon.Border:SetVertexColor(swatches[1], swatches[2], swatches[3], swatches[4] or 1.0);
				else
					GameTooltipIcon.icon.Border:SetVertexColor(1, 1, 1, 1.0);
				end
			end
			return true;
		end
	end
end
GameTooltipModel:Hide();

app.AlwaysShowUpdate = function(data) data.visible = true; return true; end
app.AlwaysShowUpdateWithoutReturn = function(data) data.visible = true; end

-- Screenshot
function app:TakeScreenShot(type)
	if app.Settings:GetTooltipSetting("Screenshot") and (not type or app.Settings:Get("Thing:"..type)) then
		Screenshot();
	end
end

-- audio lib
app.SoundDelays = {};
function app:PlayCompleteSound()
	if app.Settings:GetTooltipSetting("Celebrate") then
		app:PlayAudio(app.Settings.AUDIO_COMPLETE_TABLE, "Complete");
	end
end
function app:PlayFanfare()
	if app.Settings:GetTooltipSetting("Celebrate") then
		app:PlayAudio(app.Settings.AUDIO_FANFARE_TABLE, "Celebrate");
	end
end
function app:PlayRareFindSound()
	if app.Settings:GetTooltipSetting("Celebrate") then
		app:PlayAudio(app.Settings.AUDIO_RAREFIND_TABLE, "RareFind");
	end
end
function app:PlayRemoveSound()
	if app.Settings:GetTooltipSetting("Warn:Removed") then
		app:PlayAudio(app.Settings.AUDIO_REMOVE_TABLE, "Removed");
	end
end
function app:PlayReportSound()
	if app.Settings:GetTooltipSetting("Warn:Removed") or app.Settings:GetTooltipSetting("Celebrate") then
		app:PlayAudio(app.Settings.AUDIO_REPORT_TABLE, "Report");
	end
end
function app:PlayAudio(targetAudio, delay)
	if targetAudio and type(targetAudio) == "table" then
		-- Don't spam the users. It's nice sometimes, but let's put a delay of at least 1 second on there.
		local now = time();
		if (app.SoundDelays[delay] or 0) < now then
			app.SoundDelays[delay] = now + 1;
			local id = math.random(1, #targetAudio);
			if targetAudio[id] then PlaySoundFile(targetAudio[id], app.Settings:GetTooltipSetting("Channel")); end
		end
	end
end

-- Color Lib
local GetProgressColor, Colorize, RGBToHex;
local function HexToARGB(hex)
	return tonumber("0x"..hex:sub(1,2)), tonumber("0x"..hex:sub(3,4)), tonumber("0x"..hex:sub(5,6)), tonumber("0x"..hex:sub(7,8));
end
local function HexToRGB(hex)
	return tonumber("0x"..hex:sub(1,2)) / 255, tonumber("0x"..hex:sub(3,4)) / 255, tonumber("0x"..hex:sub(5,6)) / 255;
end
(function()
local RAID_CLASS_COLORS = RAID_CLASS_COLORS;
local Alliance, Horde = Enum.FlightPathFaction.Alliance, Enum.FlightPathFaction.Horde;
-- Color AARRGGBB values used throughout ATT
app.Colors = {
	["Raid"] = "ffff8000",
	["SourceIgnored"] = "ffd15517",
	["Locked"] = "ff7f40bf",
	["LockedWarning"] = "ffd15517",
	["Horde"] = "ffcc6666",
	["Alliance"] = "ff407fbf",
	["Completed"] = "ff15abff",
	["ChatLinkError"] = "ffff5c6c",
	["ChatLinkHQT"] = "ff7aff92",
	["ChatLink"] = "ff149bfd",
	["TooltipDescription"] = "ff66ccff",
	["TooltipLore"] = "ff42a7eb",
	["DefaultDifficulty"] = "ff1eff00",
	["RemovedWithPatch"] = "ffffaaaa",
	["AddedWithPatch"] = "ffaaffaa",
};
Colorize = function(str, color)
	return "|c" .. color .. str .. "|r";
end
RGBToHex = function(r, g, b)
	return sformat("ff%02x%02x%02x",
		r <= 255 and r >= 0 and r or 0,
		g <= 255 and g >= 0 and g or 0,
		b <= 255 and b >= 0 and b or 0);
end
-- Attempts to determine the colorized text for a given Group
app.TryColorizeName = function(group, name)
	if not name or name == RETRIEVING_DATA then return name; end
	-- raid headers
	if group.isRaid then
		return Colorize(name, app.Colors.Raid);
	-- groups which are ignored for progress
	elseif group.sourceIgnored then
		return Colorize(name, app.Colors.SourceIgnored);
	-- faction rep status
	elseif group.factionID and group.standing then
		return app.GetCurrentFactionStandingText(group.factionID, group.standing, name);
	-- locked/breadcrumb things
	elseif group.locked or group.isBreadcrumb then
		return Colorize(name, app.Colors.Locked);
		-- if people REALLY only want to see colors in account/debug then we can comment this in
	elseif app.Settings:GetTooltipSetting("UseMoreColors") --and (app.MODE_ACCOUNT or app.MODE_DEBUG)
	then
		-- class color
		if group.classID then
			return Colorize(name, RAID_CLASS_COLORS[select(2, GetClassInfo(group.classID))].colorStr);
		elseif group.c and #group.c == 1 then
			return Colorize(name, RAID_CLASS_COLORS[select(2, GetClassInfo(group.c[1]))].colorStr);
		-- faction colors
		elseif group.r then
			-- red for Horde
			if group.r == Horde then
				return Colorize(name, app.Colors.Horde);
			-- blue for Alliance
			elseif group.r == Alliance then
				return Colorize(name, app.Colors.Alliance);
			end
		-- specific races
		elseif group.races then
			local hrace = containsAny(group.races, HORDE_ONLY);
			local arace = containsAny(group.races, ALLIANCE_ONLY);
			if hrace and not arace then
				-- this group requires a horde-only race, and not any alliance race
				return Colorize(name, app.Colors.Horde);
			elseif arace and not hrace then
				-- this group requires a alliance-only race, and not any horde race
				return Colorize(name, app.Colors.Alliance);
			end
		-- un-acquirable color
		-- grey color for things which are otherwise not available to the current character (would only show in account mode due to filtering)
		elseif not app.CurrentCharacterFilters(group) then
			return Colorize(name, "ff808080");
		end
	end
	return name;
end
local CS = CreateFrame("ColorSelect", nil, app._);
CS:Hide();
local function ConvertColorRgbToHsv(r, g, b)
  CS:SetColorRGB(r, g, b);
  local h,s,v = CS:GetColorHSV()
  return {h=h,s=s,v=v}
end
local red, green = ConvertColorRgbToHsv(1,0,0), ConvertColorRgbToHsv(0,1,0);
local abs, floor = abs, floor;
local progress_colors = setmetatable({[1] = app.Colors.Completed}, {
	__index = function(t, p)
		local h;
		p = tonumber(p);
		if abs(red.h - green.h) > 180 then
			local angle = (360 - abs(red.h - green.h)) * p;
			if red.h < green.h then
				h = floor(red.h - angle);
				if h < 0 then h = 360 + h end
			else
				h = floor(red.h + angle);
				if h > 360 then h = h - 360 end
			end
		else
			h = floor(red.h-(red.h-green.h)*p)
		end
		CS:SetColorHSV(h, red.s-(red.s-green.s)*p, red.v-(red.v-green.v)*p);
		local r,g,b = CS:GetColorRGB();
		local color = RGBToHex(r * 255, g * 255, b * 255);
		rawset(t, p, color);
		return color;
	end
});
GetProgressColor = function(p)
	return progress_colors[p];
end
end)();

local function GetNumberWithZeros(number, desiredLength)
	if desiredLength > 0 then
		local str = tostring(number);
		local length = string.len(str);
		local pos = string.find(str,"[.]");
		if not pos then
			str = str .. ".";
			for i=desiredLength,1,-1 do
				str = str .. "0";
			end
		else
			local totalExtra = desiredLength - (length - pos);
			for i=totalExtra,1,-1 do
				str = str .. "0";
			end
			if totalExtra < 1 then
				str = string.sub(str, 1, pos + desiredLength);
			end
		end
		return str;
	else
		return tostring(floor(number));
	end
end
local function GetProgressTextDefault(progress, total)
	return tostring(progress or 0) .. " / " .. tostring(total);
end
local function GetProgressTextRemaining(progress, total)
	return tostring((total or 0) - (progress or 0));
end
local function GetProgressPercent(progress, total)
	local percent = (progress or 0) / total;
	return percent, app.Settings:GetTooltipSetting("Show:Percentage")
		and (" (" .. GetNumberWithZeros(percent * 100, app.Settings:GetTooltipSetting("Precision")) .. "%)");
end
local function GetProgressColorText(progress, total)
	if total and total > 0 then
		local percent, percentText = GetProgressPercent(progress, total);
		return "|c" .. GetProgressColor(percent) .. app.GetProgressText(progress, total) .. (percentText or " ") .. "|r";
	end
end
local function GetCollectionIcon(state)
	return L[(state and (state == 2 and "COLLECTED_APPEARANCE_ICON" or "COLLECTED_ICON")) or "NOT_COLLECTED_ICON"];
end
local function GetCollectionText(state)
	return L[(state and (state == 2 and "COLLECTED_APPEARANCE" or "COLLECTED")) or "NOT_COLLECTED"];
end
local function GetCompletionIcon(state)
	return L[state and "COMPLETE_ICON" or "INCOMPLETE_ICON"];
end
local function GetCompletionText(state)
	return L[(state == 2 and "COMPLETE_OTHER") or (state and "COMPLETE") or "INCOMPLETE"];
end
local function GetStateIcon(data, iconOnly)
	if data.collectible then
		return iconOnly and GetCollectionIcon(data.collected) or GetCollectionText(data.collected);
	elseif data.trackable then
		local saved = data.saved;
		-- only show if the data is saved, or is not repeatable
		if saved or not rawget(data, "repeatable") then
			return iconOnly and GetCompletionIcon(saved) or GetCompletionText(saved);
		end
	end
end
local function GetProgressTextForRow(data)
	local total = data.total;
	local isCollectible = data.collectible;
	local isContainer = total and (total > 1 or (total > 0 and not isCollectible));
	local stateIcon = GetStateIcon(data, true);

	if isContainer then

		-- Uncollected Collectible (show uncollected icon & container info)
		if isCollectible and not data.collected then
			return GetCollectionIcon().." "..GetProgressColorText(data.progress or 0, total);
		end

		-- Cost & Progress (show cost icon & container info)
		if data.filledCost then
			return L["COST_ICON"].." "..GetProgressColorText(data.progress or 0, total);
		end

		local costTotal = data.costTotal;
		local isCost = costTotal and costTotal > 0;
		-- Cost (show cost icon)
		if isCost then
			return L["COST_ICON"];
		end

		-- Progress Only
		return GetProgressColorText(data.progress or 0, total);
	elseif stateIcon then
		return stateIcon;
	elseif data.visible then
		if data.count then
			return (data.count .. "x");
		end
		if data.g and not data.expanded and #data.g > 0 then
			return "+++";
		end
		return "---";
	end
end
local function GetProgressTextForTooltip(data, iconOnly)
	local total = data.total;
	local isCollectible = data.collectible;
	local isContainer = total and (total > 1 or (total > 0 and not isCollectible));
	local stateText = GetStateIcon(data, iconOnly);

	if isContainer then

		-- Uncollected Collectible (show uncollected state & container info)
		if isCollectible and not data.collected then
			if stateText then
				-- this should be the case 100% of the time, unless a Type defines 'collectible' without 'collected'
				return stateText.." "..GetProgressColorText(data.progress or 0, total);
			else
				return GetProgressColorText(data.progress or 0, total);
			end
		end

		-- Cost & Progress (show cost icon & container info)
		if data.filledCost then
			if stateText then
				return stateText.." "..L["COST_TEXT"].." "..GetProgressColorText(data.progress or 0, total);
			else
				return L["COST_TEXT"].." "..GetProgressColorText(data.progress or 0, total);
			end
		end

		local costTotal = data.costTotal;
		local isCost = costTotal and costTotal > 0;
		-- Cost (show cost icon)
		if isCost then
			if stateText then
				return stateText.." "..L["COST_TEXT"];
			else
				return L["COST_TEXT"];
			end
		end

		-- Progress Only
		if stateText then
			return stateText.." "..GetProgressColorText(data.progress or 0, total);
		else
			return GetProgressColorText(data.progress or 0, total);
		end
	end
	return stateText;
end
local function GetAddedWithPatchString(awp)
	if awp then
		awp = tonumber(awp);
		return sformat(L["ADDED_WITH_PATCH_FORMAT"], math.floor(awp / 10000) .. "." .. (math.floor(awp / 100) % 10) .. "." .. (awp % 10));
	end
end
local function GetRemovedWithPatchString(rwp)
	rwp = tonumber(rwp);
	if rwp then
		return sformat(L["REMOVED_WITH_PATCH_FORMAT"], math.floor(rwp / 10000).."."..(math.floor(rwp / 100) % 10).."."..(rwp % 10));
	end
end
app.GetProgressText = GetProgressTextDefault;
app.GetProgressTextDefault = GetProgressTextDefault;
app.GetProgressTextRemaining = GetProgressTextRemaining;

-- Source ID Harvesting Lib
local DressUpModel = CreateFrame('DressUpModel');
local inventorySlotsMap = {	-- Taken directly from CanIMogIt (Thanks!)
	["INVTYPE_HEAD"] = {1},
	["INVTYPE_NECK"] = {2},
	["INVTYPE_SHOULDER"] = {3},
	["INVTYPE_BODY"] = {4},
	["INVTYPE_CHEST"] = {5},
	["INVTYPE_ROBE"] = {5},
	["INVTYPE_WAIST"] = {6},
	["INVTYPE_LEGS"] = {7},
	["INVTYPE_FEET"] = {8},
	["INVTYPE_WRIST"] = {9},
	["INVTYPE_HAND"] = {10},
	["INVTYPE_RING"] = {11},
	["INVTYPE_TRINKET"] = {12},
	["INVTYPE_CLOAK"] = {15},
	["INVTYPE_WEAPON"] = {16, 17},
	["INVTYPE_SHIELD"] = {17},
	["INVTYPE_2HWEAPON"] = {16, 17},
	["INVTYPE_WEAPONMAINHAND"] = {16},
	["INVTYPE_RANGED"] = {16},
	["INVTYPE_RANGEDRIGHT"] = {16},
	["INVTYPE_WEAPONOFFHAND"] = {17},
	["INVTYPE_HOLDABLE"] = {17},
	["INVTYPE_TABARD"] = {19},
};
local function BuildGroups(parent, g)
	g = g or parent.g;
	if g then
		-- Iterate through the groups
		for _,group in ipairs(g) do
			-- Set the group's parent
			group.parent = parent;
			group.indent = nil;
			group.back = nil;
			BuildGroups(group);
		end
	end
end
local function BuildSourceText(group, l)
	local parent = group.sourceParent or group.parent;
	if parent then
		-- From ATT-Classic .. needs some modification to handle Retail source depths
		-- if not group.itemID and (parent.key == "filterID" or parent.key == "spellID" or ((parent.headerID or (parent.spellID and group.categoryID))
		-- 	and ((parent.headerID == -2 or parent.headerID == -17 or parent.headerID == -7) or (parent.parent and parent.parent.parent)))) then
		-- 	return BuildSourceText(parent.sourceParent or parent.parent, 5) .. DESCRIPTION_SEPARATOR .. (group.text or RETRIEVING_DATA) .. " (" .. (parent.text or RETRIEVING_DATA) .. ")";
		-- end
		-- if group.headerID then
		-- 	if group.headerID == 0 then
		-- 		if group.crs and #group.crs == 1 then
		-- 			return BuildSourceText(parent, l + 1) .. DESCRIPTION_SEPARATOR .. (app.NPCNameFromID[group.crs[1]] or RETRIEVING_DATA) .. " (Drop)";
		-- 		end
		-- 		return BuildSourceText(parent, l + 1) .. DESCRIPTION_SEPARATOR .. (group.text or RETRIEVING_DATA);
		-- 	end
		-- 	if parent.parent then
		-- 		return BuildSourceText(parent, l + 1) .. DESCRIPTION_SEPARATOR .. (group.text or RETRIEVING_DATA);
		-- 	end
		-- end
		-- if parent.key == "categoryID" or group.key == "filterID" or group.key == "spellID" or group.key == "encounterID" or (parent.key == "mapID" and group.key == "npcID") then
		-- 	return BuildSourceText(parent, 5) .. DESCRIPTION_SEPARATOR .. (group.text or RETRIEVING_DATA);
		-- end
		if l < 1 then
			return BuildSourceText(parent, l + 1);
		else
			return BuildSourceText(parent, l + 1) .. " > " .. (group.text or RETRIEVING_DATA);
		end
	end
	return group.text or RETRIEVING_DATA;
end
local function BuildSourceTextForChat(group, l)
	if group.sourceParent or group.parent then
		if l < 1 then
			return BuildSourceTextForChat(group.sourceParent or group.parent, l + 1);
		else
			return BuildSourceTextForChat(group.sourceParent or group.parent, l + 1) .. " > " .. (group.text or "*");
		end
	end
	return "ATT";
end
local function BuildSourceTextForTSM(group, l)
	if group.sourceParent or group.parent then
		if l < 1 or not group.text then
			return BuildSourceTextForTSM(group.sourceParent or group.parent, l + 1);
		else
			return BuildSourceTextForTSM(group.sourceParent or group.parent, l + 1) .. "`" .. group.text;
		end
	end
	return L["TITLE"];
end
-- Fields which are dynamic or pertain only to the specific ATT window and should never merge automatically
app.MergeSkipFields = {
	-- true -> never
	["expanded"] = true,
	["indent"] = true,
	["g"] = true,
	["progress"] = true,
	["total"] = true,
	["visible"] = true,
	-- 1 -> only when cloning
	["modItemID"] = 1,
	["u"] = 1,
	["pvp"] = 1,
	["pb"] = 1,
	["requireSkill"] = 1,
	["sourceIgnored"] = 1,
};
-- Fields on a Thing which are specific to where the Thing is Sourced or displayed in a ATT window
app.SourceSpecificFields = {
-- Returns the 'most obtainable' unobtainable value from the provided set of unobtainable values
	["u"] = function(...)
		-- print("GetMostObtainableValue:")
		local vals, max, check, new = {...}, -1;
		-- app.PrintTable(vals)
		local reasons = L["UNOBTAINABLE_ITEM_REASONS"];
		local record;
		for _,u in pairs(vals) do
			-- missing u value means NOT unobtainable
			if not u then return; end
			record = reasons[u];
			if record then
				check = record[1];
			else
				-- otherwise it's an invalid unobtainable filter
				app.print("Invalid Unobtainable Filter:",u);
				return;
			end
			-- track the highest unobtainable value, which is the most obtainable (according to UNOBTAINABLE_ITEM_TEXTURES)
			if check > max then
				new = u;
				max = check;
			end
		end
			-- print("new:",new)
		return new;
	end,
-- Returns the 'highest' Removed with Patch value from the provided set of `rwp` values
	["rwp"] = function(...)
		local vals, max = {...}, -1;
		for _,rwp in pairs(vals) do
			-- missing rwp value means NOT removed
			if not rwp then return; end
			-- track the highest rwp value, which is the furthest-future patch
			if rwp > max then
				max = rwp;
			end
		end
		-- print("max:",max)
		return max;
	end,
-- Simple boolean
	["pvp"] = true,
	["pb"] = true,
	["requireSkill"] = true,
};
-- Merges the properties of the t group into the g group, making sure not to alter the filterability of the group.
-- Additionally can specify that the object is being cloned so as to skip special merge restrictions
local function MergeProperties(g, t, noReplace, clone)
	if g and t then
		local skips = app.MergeSkipFields;
		if noReplace then
			for k,v in pairs(t) do
				-- certain keys should never transfer to the merge group directly
				if k == "parent" then
					if not rawget(g, "sourceParent") then
						rawset(g, "sourceParent", v);
					end
				elseif not skips[k] then
					if not rawget(g, k) then
						rawset(g, k, v);
					end
				end
			end
		elseif clone then
			for k,v in pairs(t) do
				-- certain keys should never transfer to the merge group directly
				if k == "parent" then
					if not rawget(g, "sourceParent") then
						rawset(g, "sourceParent", v);
					end
				elseif skips[k] ~= true then
					rawset(g, k, v);
				end
			end
		else
			for k,v in pairs(t) do
				-- certain keys should never transfer to the merge group directly
				if k == "parent" then
					if not rawget(g, "sourceParent") then
						rawset(g, "sourceParent", v);
					end
				elseif not skips[k] then
					rawset(g, k, v);
				end
			end
		end
		-- custom special logic for fields which need to represent the commonality between all Sources of a group
		-- loop through specific fields for custom logic
		-- initial creation of a g object, has no key
		if not g.key then
			for k,_ in pairs(app.SourceSpecificFields) do
				g[k] = t[k];
			end
		else
			local gk, tk;
			for k,f in pairs(app.SourceSpecificFields) do
				-- existing is set
				gk = g[k];
				if gk then
					tk = t[k];
					-- no value on merger
					if not tk then
						-- print("remove",k,gk,tk)
						g[k] = nil;
					elseif f and type(f) == "function" then
						-- two different values with a compare function
						-- print("compare",k,gk,tk)
						g[k] = f(gk, tk);
						-- print("result",gk)
					end
				end
			end
		end
		-- only copy metatable to g if another hasn't been set already
		if not getmetatable(g) and getmetatable(t) then
			setmetatable(g, getmetatable(t));
		end
	end
end
-- The base logic for turning a Table of data into an 'object' that provides dynamic information concerning the type of object which was identified
-- based on the priority of possible key values
local function CreateObject(t, rootOnly)
	if not t then return {}; end

	-- already an object, so need to create a new instance of the same data
	if t.key then
		local s = {};
		-- app.PrintDebug("CreateObject from key via merge",t.key,t[t.key], t, s);
		MergeProperties(s, t, nil, true);
		-- include the raw g since it will be replaced at the end with new objects
		s.g = t.g;
		t = s;
		-- app.PrintDebug("Merge done",s.key,s[s.key], t, s);
	-- is it an array of raw datas which needs to be turned into ana rray of usable objects
	elseif t[1] then
		local s = {};
		-- array
		-- if app.DEBUG_PRINT then print("CreateObject on array",#t); end
		for _,o in ipairs(t) do
			tinsert(s, CreateObject(o, rootOnly));
		end
		return s;
	-- use the highest-priority piece of data which exists in the table to turn it into an object
	else
		if t.mapID then
			t = app.CreateMap(t.mapID, t);
		elseif t.s then
			t = app.CreateItemSource(t.s, t.itemID, t);
		elseif t.encounterID then
			t = app.CreateEncounter(t.encounterID, t);
		elseif t.instanceID then
			t = app.CreateInstance(t.instanceID, t);
		elseif t.currencyID then
			t = app.CreateCurrencyClass(t.currencyID, t);
		elseif t.speciesID then
			t = app.CreateSpecies(t.speciesID, t);
		elseif t.objectID then
			t = app.CreateObject(t.objectID, t);
		elseif t.followerID then
			t = app.CreateFollower(t.followerID, t);
		elseif t.illusionID then
			t = app.CreateIllusion(t.illusionID, t);
		elseif t.professionID then
			t = app.CreateProfession(t.professionID, t);
		elseif t.categoryID then
			t = app.CreateCategory(t.categoryID, t);
		elseif t.criteriaID then
			t = app.CreateAchievementCriteria(t.criteriaID, t);
		elseif t.achID or t.achievementID then
			t = app.CreateAchievement(t.achID or t.achievementID, t);
		elseif t.recipeID then
			t = app.CreateRecipe(t.recipeID, t);
		elseif t.itemID then
			if t.isToy then
				t = app.CreateToy(t.itemID, t);
			elseif t.runeforgePowerID then
				t = app.CreateRuneforgeLegendary(t.runeforgePowerID, t);
			elseif t.conduitID then
				t = app.CreateConduit(t.conduitID, t);
			else
				t = app.CreateItem(t.itemID, t);
			end
		elseif t.npcID or t.creatureID then
			t = app.CreateNPC(t.npcID or t.creatureID, t);
		elseif t.questID then
			if t.isVignette then
				t = app.CreateVignette(t.questID, t);
			else
				t = app.CreateQuest(t.questID, t);
			end

		-- Non-Thing groups
		elseif t.classID then
			t = app.CreateCharacterClass(t.classID, t);
		elseif t.headerID then
			t = app.CreateNPC(t.headerID, t);
		elseif t.tierID then
			t = app.CreateTier(t.tierID, t);
		elseif t.unit then
			t = app.CreateUnit(t.unit, t);
		elseif t.difficultyID then
			t = app.CreateDifficulty(t.difficultyID, t);
		elseif t.spellID then
			t = app.CreateSpell(t.spellID, t);
		else
			-- if app.DEBUG_PRINT then print("CreateObject by value, no specific object type"); app.PrintTable(t); end
			if rootOnly then
				-- shallow copy the root table only, since using t as a metatable will allow .g to exist still on the table
				-- app.PrintDebug("rootOnly copy of",t.text)
				local s = {};
				for k,v in pairs(t) do
					s[k] = v;
				end
				t = s;
			else
				-- app.PrintDebug("metatable copy of",t.text)
				t = setmetatable({}, { __index = t });
			end
		end
	end

	-- allows for copying an object without all of the sub-groups
	if rootOnly then
		t.g = nil;
	end

	-- if app.DEBUG_PRINT then print("CreateObject key/value",t.key,t[t.key]); end
	-- if g, then replace each object in all sub groups with an object version of the table
	if t.g then
		local sourceg = t.g;
		t.g = {};
		-- if app.DEBUG_PRINT then print("CreateObject for sub-groups of",t.key,t[t.key]); end
		for i,o in pairs(sourceg) do
			t.g[i] = CreateObject(o);
		end
	end

	return t;
end
-- Clones the data and attempts to create all sub-groups into cloned objects as well
local function CloneData(data)
	return CreateObject(data);
end
local function RawCloneData(data, clone)
	clone = clone or {};
	for key,value in pairs(data) do
		if not clone[key] then
			rawset(clone, key, value);
		end
	end
	-- maybe better solution at another time?
	clone.__type = nil;
	clone.__index = nil;
	return clone;
end
(function()
local GetSlotForInventoryType = C_Transmog.GetSlotForInventoryType;
app.SlotByInventoryType = setmetatable({}, {
	__index = function(t, key)
		local slot = GetSlotForInventoryType(key);
		rawset(t, key, slot);
		return slot;
	end
})
end)();
local function GetSourceID(itemLink)
	if C_Item_IsDressableItemByID(itemLink) then
		-- Updated function courtesy of CanIMogIt, Thanks AmiYuy and Team! :D
		local sourceID = select(2, C_TransmogCollection_GetItemInfo(itemLink));
		if sourceID then return sourceID, true; end

		-- if app.DEBUG_PRINT then print("Failed to directly retrieve SourceID",itemLink) end
		local itemID, _, _, slotName = GetItemInfoInstant(itemLink);
		if slotName then
			local slots = inventorySlotsMap[slotName];
			if slots then
				DressUpModel:SetUnit('player');
				DressUpModel:Undress();
				for _,slot in pairs(slots) do
					DressUpModel:TryOn(itemLink, slot);
					local tmogInfo = DressUpModel:GetItemTransmogInfo(slot);
					-- print("SlotInfo",slot)
					-- app.PrintTable(tmogInfo)
					local sourceID = tmogInfo and tmogInfo.appearanceID;
					if sourceID and sourceID ~= 0 then
						-- Added 5/4/2018 - Account for DressUpModel lag... sigh
						local sourceItemLink = select(6, C_TransmogCollection_GetAppearanceSourceInfo(sourceID));
						-- print("SourceID from DressUpModel",sourceID,sourceItemLink)
						if sourceItemLink and tonumber(sourceItemLink:match("item:(%d+)")) == itemID then
							return sourceID, true;
						end
					end
				end
			end
		end
		return nil, true;
	end
	return nil, false;
end
-- verifies that an item group either has no sourceID or that its sourceID matches what the in-game API returns
-- based on the itemID and modID of the item
local function VerifySourceID(item)
	-- ignore things which arent items
	if not item.itemID then return true; end
	-- no source at all, try to get it
	if not item.s or item.s == 0 then return; end
	-- unobtainable item, don't change the sourceID
	if item.u then return true; end
	local sourceInfo = C_TransmogCollection_GetSourceInfo(item.s);
	-- no source info or no item for the source
	-- ignore this, maybe blizz removed a sourceID that we tracked in the past...?
	if not sourceInfo or not sourceInfo.itemID then
		print("Invalid SourceID",item.itemID,item.modID,item.s);
		return;
	end
	-- item for the source is different than the current item
	if sourceInfo.itemID and sourceInfo.itemID ~= item.itemID then
		print("Inaccurate SourceID",item.itemID,item.modID,item.s,"=>",sourceInfo.itemID,sourceInfo.itemModID);
		return;
	end
	-- check that the group's itemlink still returns the same sourceID as saved in the group
	if item.link and not item.retries then
		-- quality below UNCOMMON means no source
		if item.q and item.q < 2 then return true; end

		local linkInfoSourceID = GetSourceID(item.link);
		if linkInfoSourceID and linkInfoSourceID ~= item.s then
			print("Mismatched SourceID",item.link,item.s,"=>",linkInfoSourceID);
			return;
		end
	-- item has not pulled its link yet, so include it for re-sourcing anyway
	elseif item.retries then
		return;
	end
	-- at this point the game source information matches the information for this item group
	return true;
end
-- Attempts to determine an ItemLink which will return the provided SourceID
app.DetermineItemLink = function(sourceID)
	local link;
	local sourceInfo = C_TransmogCollection_GetSourceInfo(sourceID);
	local itemID = sourceInfo and sourceInfo.itemID;
	if not itemID then
		-- app.print("Could not generate Item Link for",sourceID,"(No Source Info from Blizzard)");
		return;
	end
	local checkID, found;
	local itemFormat = "item:"..itemID;
	-- Check Raw Item
	link = itemFormat;
	checkID, found = GetSourceID(link);
	if found and checkID == sourceID then return link; end

	-- Check ModIDs
	-- bonusID 3524 seems to imply "use ModID to determine SourceID" since without it, everything with ModID resolves as the base SourceID from links
	itemFormat = "item:"..itemID..":::::::::::%d:1:3524";
	-- /dump AllTheThings.GetSourceID("item:188859:::::::::::5:1:3524")
	for m=1,99,1 do
		link = sformat(itemFormat, m);
		checkID, found = GetSourceID(link);
		-- print(link,checkID,found)
		if found and checkID == sourceID then return link; end
	end

	-- Check BonusIDs
	itemFormat = "item:"..itemID.."::::::::::::1:%d";
	for b=1,9999,1 do
		link = sformat(itemFormat, b);
		checkID, found = GetSourceID(link);
		-- print(link,checkID,found)
		if found and checkID == sourceID then return link; end
	end
	-- app.print("Could not generate Item Link for",sourceID,"(No ModID or BonusID match)");
end
app.IsComplete = function(o)
	if o.total and o.total > 0 then return o.total == o.progress; end
	if o.collectible then return o.collected; end
	if o.trackable then return o.saved; end
	return true;
end
app.GetSourceID = GetSourceID;
app.MaximumItemInfoRetries = 400;
local function GetUnobtainableTexture(groupORu)
	-- old reasons are set to 0, so use 1 instead
	-- if unobtainable stuff changes again, this logic may need to adjust
	local isTable = type(groupORu) == "table";
	local u = isTable and groupORu.u or groupORu;
	-- non-unobtainable group
	if not u then return; end
	-- non-NYI item or spell which is BoE and not a holiday (u<1000), use green dot
	if isTable and (groupORu.itemID or groupORu.spellID) and u > 1 and u < 1000 and not app.IsBoP(groupORu) then
		u = 3;
	else
		local record = L["UNOBTAINABLE_ITEM_REASONS"][u];
		if record then
			u = record[1];
		else
			-- otherwise it's an invalid unobtainable filter
			app.print("Invalid Unobtainable Filter:",u);
			return;
		end
	end
	-- found an unobtainable record, so grab the texture index [1]
	return L["UNOBTAINABLE_ITEM_TEXTURES"][u or 0];
end
-- Returns an applicable Indicator Icon Texture for the specific group if one can be determined
app.GetIndicatorIcon = function(group)
	if group.trackable and group.saved then
		if group.parent and group.parent.locks or group.repeatable then
			return app.asset("known");
		else
			return app.asset("known_green");
		end
	else
		local asset = group.indicatorIcon;
		if asset then
			return app.asset(asset);
		elseif group.u then
			asset = GetUnobtainableTexture(group);
			if asset then
				return asset;
			end
		end
	end
end
local function SetIndicatorIcon(self, data)
	local texture = app.GetIndicatorIcon(data);
	if texture then
		self:SetTexture(texture);
		return true;
	end
end
local function SetPortraitIcon(self, data)
	local displayID = GetDisplayID(data);
	if displayID then
		SetPortraitTextureFromDisplayID(self, displayID);
		self:SetTexCoord(0, 1, 0, 1);
		return true;
	elseif data.unit and not data.icon then
		SetPortraitTexture(self, data.unit);
		self:SetTexCoord(0, 1, 0, 1);
		return true;
	end

	-- Fallback to a traditional icon.
	if data.atlas then
		self:SetAtlas(data.atlas);
		self:SetTexCoord(0, 1, 0, 1);
		if data["atlas-background"] then
			self.Background:SetAtlas(data["atlas-background"]);
			self.Background:SetWidth(self:GetHeight());
			self.Background:Show();
		end
		if data["atlas-border"] then
			self.Border:SetAtlas(data["atlas-border"]);
			self.Border:SetWidth(self:GetHeight());
			self.Border:Show();
			if data["atlas-color"] then
				local swatches = data["atlas-color"];
				self.Border:SetVertexColor(swatches[1], swatches[2], swatches[3], swatches[4] or 1.0);
			else
				self.Border:SetVertexColor(1, 1, 1, 1.0);
			end
		end
		return true;
	elseif data.icon then
		self:SetTexture(data.icon);
		local texcoord = data.texcoord;
		if texcoord then
			self:SetTexCoord(texcoord[1], texcoord[2], texcoord[3], texcoord[4]);
		else
			self:SetTexCoord(0, 1, 0, 1);
		end
		return true;
	end
end
local function GetRelativeDifficulty(group, difficultyID)
	if group then
		if group.difficultyID then
			if group.difficultyID == difficultyID then
				return true;
			end
			if group.difficulties then
				for i, difficulty in ipairs(group.difficulties) do
					if difficulty == difficultyID then
						return true;
					end
				end
			end
			return false;
		end
		if group.parent then
			return GetRelativeDifficulty(group.sourceParent or group.parent, difficultyID);
		else
			return true;
		end
	end
end
local function GetRelativeMap(group, currentMapID)
	if group then
		return group.mapID or (group.maps and (contains(group.maps, currentMapID) and currentMapID or group.maps[1])) or GetRelativeMap(group.sourceParent or group.parent, currentMapID);
	end
	return currentMapID;
end
local function GetRelativeField(group, field, value)
	if group then
		return group[field] == value or GetRelativeField(group.sourceParent or group.parent, field, value);
	end
end
local function GetRelativeValue(group, field)
	if group then
		return group[field] or GetRelativeValue(group.sourceParent or group.parent, field);
	end
end
local function GetDeepestRelativeValue(group, field)
	if group then
		return GetDeepestRelativeValue(group.sourceParent or group.parent, field) or group[field];
	end
end
-- Returns the ItemID of the group (if existing) with a decimal portion containing the modID/100 and bonusID/1000000
-- or converts a raw ItemID/ModID/BonusID into the combined modItemID value
-- Ex. 12345 (ModID 5) => 12345.05
-- Ex. 87654 (ModID 23)=> 87654.23
-- Ex. 102938 (ModID 1) (BonusID 4746) => 102938.014746
local function GetGroupItemIDWithModID(t, rawItemID, rawModID, rawBonusID)
	local i, m, b;
	if t then
		i = t.itemID or 0;
		m = t.modID;
		b = t.bonusID;
	else
		i = rawItemID and tonumber(rawItemID) or 0;
		m = rawModID and tonumber(rawModID);
		b = rawBonusID and tonumber(rawBonusID);
	end
	if m then
		i = i + (m / 100);
	end
	if b and b ~= 3524 then
		i = i + (b / 1000000);
	end
	return i;
end
-- Returns the ItemID, ModID, BonusID of the provided ModItemID
-- Ex. 12345.05		=> 12345, 5
-- Ex. 87654.23		=> 87654, 23
-- Ex. 102938.014746=> 102938, 1, 4746
local function GetItemIDAndModID(modItemID)
	if modItemID and tonumber(modItemID) then
		-- print("GetItemIDAndModID",modItemID)
		local itemID = math.floor(modItemID);
		modItemID = (modItemID - itemID) * 100;
		local modID = math.floor(modItemID);
		modItemID = (modItemID - modID) * 1000000;
		local bonusID = math.floor(modItemID);
		-- print(itemID,modID,bonusID)
		return itemID, modID, bonusID;
	end
end
local function GroupMatchesParams(group, key, value, ignoreModID)
	if not group then return false; end
	-- Items are special
	local itemID = group.itemID;
	if itemID and key == "itemID" then
		local modItemID = group.modItemID;
		if modItemID and modItemID == value then
			return true;
		elseif ignoreModID or not modItemID then
			value = GetItemIDAndModID(value);
			return itemID == value;
		end
	end
	-- exact specific match for other keys
	if group[key] == value then return true; end
	-- Some objects also need to check altquestID for questID
	if key == "questID" and group.otherFactionQuestID == value then return true; end
end
-- Filters a specs table to only those which the current Character class can choose
local function FilterSpecs(specs)
	if specs and #specs > 0 then
		local name, class, _;
		for i=#specs,1,-1 do
			_, name, _, _, _, class = GetSpecializationInfoByID(specs[i]);
			if class ~= app.Class or not name or name == "" then
				table.remove(specs, i);
			end
		end
		app.Sort(specs, app.SortDefaults.Value);
	end
end
-- Returns a string containing the spec icons, followed by their respective names if desired
local function GetSpecsString(specs, includeNames, trim)
	local icons, name, icon, _ = {};
	if includeNames then
		for i=#specs,1,-1 do
			_, name, _, icon, _, _ = GetSpecializationInfoByID(specs[i]);
			icons[i * 4 - 3] = "  |T";
			icons[i * 4 - 2] = icon;
			icons[i * 4 - 1] = ":0|t ";
			icons[i * 4] = name;
		end
	else
		for i=#specs,1,-1 do
			_, _, _, icon, _, _ = GetSpecializationInfoByID(specs[i]);
			icons[i * 3 - 2] = "|T";
			icons[i * 3 - 1] = icon;
			icons[i * 3] = ":0|t ";
		end
	end
	if trim then
		return string.match(table.concat(icons),'^%s*(.*%S)');
	end
	return table.concat(icons);
end
-- Returns proper, class-filtered specs for a given itemID
local function GetFixedItemSpecInfo(itemID)
	if itemID then
		local specs = GetItemSpecInfo(itemID);
		if not specs or #specs < 1 then
			specs = {};
			-- Starting with Legion items, the API seems to return no spec information when the item is in fact lootable by ANY spec
			local _, _, _, _, _, _, _, _, itemEquipLoc, _, _, itemClassID, itemSubClassID, _, expacID, _, _ = GetItemInfo(itemID);
			-- only Armor items
			if itemClassID and itemClassID == 4 then
				-- unable to distinguish between Trinkets usable by all specs (Font of Power) and Role-Specific trinkets which do not apply to any Role of the current Character
				if expacID >= 6 and (itemEquipLoc == "INVTYPE_NECK" or itemEquipLoc == "INVTYPE_FINGER") then
					local numSpecializations = GetNumSpecializations();
					if numSpecializations and numSpecializations > 0 then
						for i=1,numSpecializations,1 do
							local specID = GetSpecializationInfo(i);
							tinsert(specs, specID);
						end
					end
				end
			end
			app.Sort(specs, app.SortDefaults.Value);
		else
			FilterSpecs(specs);
		end
		if #specs > 0 then
			return specs;
		end
	end
end

-- Quest Completion Lib
-- Builds a table to be used in the SetupReportDialog to display text which is copied into Discord for player reports
app.BuildDiscordQuestInfoTable = function(id, infoText, questChange, questRef)
	local coord;
	local mapID = app.GetCurrentMapID();
	local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player");
	local covID, covData, covRenown = C_Covenants.GetActiveCovenantID();
	if covID and covID > 0 then
		covData = C_Covenants.GetCovenantData(covID);
		covRenown = C_CovenantSanctumUI.GetRenownLevel();
	end
	if position then
		local x,y = position:GetXY();
		x = math.floor(x * 1000) / 10;
		y = math.floor(y * 1000) / 10;
		coord = x..","..y;
	end
	return
	{
		"**"..(infoText or "quest-info")..":"..id.."**",

		"```",	-- discord fancy box

		questChange,
		"name:"..(C_TaskQuest.GetQuestInfoByQuestID(id) or C_QuestLog.GetTitleForQuestID(id) or "???"),
		"race:"..app.RaceID.." ("..app.Race..")",
		"class:"..app.ClassIndex.." ("..app.Class..")",
		"lvl:"..app.Level,
		"u:"..tostring(questRef and questRef.u),
		"sq:"..app.SourceQuestString(questRef or id),
		"lq:"..(app.LastQuestTurnedIn or ""),
		"cov:"..(covData and covData.name or "N/A")..(covRenown and ":"..covRenown or ""),
		mapID and ("mapID:"..mapID.." ("..C_Map_GetMapInfo(mapID).name..")") or "mapID:??",
		coord and ("coord:"..coord) or "coord:??",
		"ver:"..app.Version,

		"```",	-- discord fancy box
		-- TODO: put more info in here as it will be copy-paste into Discord
	};
end
-- Checks a given quest reference against the current character info to see if something is inaccurate
app.CheckInaccurateQuestInfo = function(questRef, questChange)
	if questRef and questRef.questID then
		-- print("CheckInaccurateQuestInfo",questRef.questID,questChange)
		local id = questRef.questID;
		if not (app.CurrentCharacterFilters(questRef)
			and app.ItemIsInGame(questRef)
			and not questRef.missingPrequisites) then

			-- Play a sound when a reportable error is found, if any sound setting is enabled
			app:PlayReportSound();

			local popupID = "quest-filter-" .. id;
			if app:SetupReportDialog(popupID, "Inaccurate Quest Info: " .. id,
				app.BuildDiscordQuestInfoTable(id, "inaccurate-quest", questChange, questRef)
			) then
				local reportMsg = app:Linkify(L["REPORT_INACCURATE_QUEST"], app.Colors.ChatLinkError, "dialog:" .. popupID);
				Callback(app.print, reportMsg);
			end
		end
	end
end
local PrintQuestInfo = function(questID, new, info)
	if app.IsReady and app.Settings:GetTooltipSetting("Report:CompletedQuests") then
		local questRef = app.SearchForObject("questID", questID) or app.SearchForField("questID", questID);
		questRef = (questRef and questRef[1]) or questRef;
		local questChange;
		if new == true then
			questChange = "accepted";
		elseif new == false then
			questChange = "unflagged";
		else
			questChange = "completed";
		end
		-- This quest doesn't meet the filter for this character, then ask to report in chat
		if questChange == "accepted" then
			DelayedCallback(app.CheckInaccurateQuestInfo, 0.5, questRef, questChange);
		end
		local chatMsg;
		if not questRef or GetRelativeField(questRef, "text", L["UNSORTED_1"]) then
			-- Play a sound when a reportable error is found, if any sound setting is enabled
			app:PlayReportSound();
			-- Linkify the output
			local popupID = "quest-" .. questID .. questChange;
			chatMsg = app:Linkify(questID .. " (Not in ATT " .. app.Version .. ")", app.Colors.ChatLinkError, "dialog:" .. popupID);
			app:SetupReportDialog(popupID, "Missing Quest: " .. questID,
				app.BuildDiscordQuestInfoTable(questID, "missing-quest", questChange)
			);
		else
			-- give a chat output if the user has just interacted with a quest flagged as NYI
			if questRef.u == 1 or GetRelativeField(questRef, "text", L["NEVER_IMPLEMENTED"]) then
				-- Play a sound when a reportable error is found, if any sound setting is enabled
				app:PlayReportSound();
				-- Linkify the output
				local popupID = "quest-" .. questID .. questChange;
				chatMsg = app:Linkify(questID .. " [NYI] ATT " .. app.Version, app.Colors.ChatLinkError, "dialog:" .. popupID);
				app:SetupReportDialog(popupID, "NYI Quest: " .. questID,
					app.BuildDiscordQuestInfoTable(questID, "nyi-quest", questChange)
				);
			-- tack on an 'HQT' tag if ATT thinks this QuestID is a Hidden Quest Trigger
			-- (sometimes 'real' quests are triggered complete when other 'real' quests are turned in and contribs may consider them HQT if not yet sourced
			-- so when a quest flagged as HQT is accepted/completed directly, it will be more noticable of being incorrectly sourced
			elseif GetRelativeField(questRef, "text", L["HIDDEN_QUEST_TRIGGERS"]) then
				if app.Settings:GetTooltipSetting("Report:UnsortedQuests") then
					return true;
				end
				-- Linkify the output
				chatMsg = app:Linkify(questID .. " [HQT]", app.Colors.ChatLinkHQT, "search:questID:" .. questID);
			else
				if app.Settings:GetTooltipSetting("Report:UnsortedQuests") then
					return true;
				end
				-- Linkify the output
				chatMsg = app:Linkify(questID, app.Colors.ChatLink, "search:questID:" .. questID);
			end
		end
		print("Quest",questChange,chatMsg,(info or ""));
	end
end
local DirtyQuests, TotalQuests = {}, 0;
local CompletedQuests = setmetatable({}, {__newindex = function (t, key, value)
	key = tonumber(key);
	if value then
		if not rawget(t, key) then
			TotalQuests = TotalQuests + 1;
		end
		rawset(t, key, value);
		rawset(DirtyQuests, key, true);
		rawset(DirtyQuests, "DIRTY", true);
		ATTAccountWideData.Quests[key] = 1;
		app.CurrentCharacter.Quests[key] = 1;
		PrintQuestInfo(key);
	elseif value == false then
		TotalQuests = TotalQuests - 1;
		rawset(DirtyQuests, key, true);
		rawset(DirtyQuests, "DIRTY", true);
		-- no need to actually set the key in the table since it's been marked as incomplete
		-- and this meta function only triggers on NEW key assignments
		PrintQuestInfo(key, false);
	end
end});
-- app.CompletedQuests = CompletedQuests;
-- returns nil if nil provided, otherwise true/false based on the specific quest being completed by the current character
local IsQuestFlaggedCompleted = function(questID)
	return questID and CompletedQuests[questID];
end
-- Calls the Blizz API to specifically check & cache whether a questID is completed if not already cached as completed
local IsQuestFlaggedCompletedForce = function(questID)
	if questID then
		if CompletedQuests[questID] then
			return true;
		end
		if C_QuestLog.IsQuestFlaggedCompleted(questID) then
			CompletedQuests[questID] = true;
			return true;
		end
	end
end
-- Returns true if any provided questID is currently completed for the current character
local IsAnyQuestFlaggedCompleted = function(quests)
	if quests then
		for _,questID in pairs(quests) do
			if CompletedQuests[questID] then return true; end
		end
	end
end
local IsQuestFlaggedCompletedForObject = function(t, questIDKey)
	-- allow specifying a specific 'questID' from the object
	questIDKey = questIDKey or "questID";
	-- nil if not a quest-based object
	local questID = t[questIDKey];
	if not questID then return; end
	-- 1 = This character completed this quest
	-- 2 = This quest was completed by another character on the account / This quest cannot be completed by this character
	-- If the quest is completed for this character, return completed.
	if IsQuestFlaggedCompleted(questID) then
		return 1;
	end
	-- account-mode: any character is viable to complete the quest, so alt quest completion shouldn't count for this quest
	-- this quest cannot be obtained if any altQuest is completed on this character and not tracking as account mode
	-- If the quest has an altQuest which was completed on this character and this character is not in Party Sync nor tracking Locked Quests, return shared completed
	if not app.MODE_DEBUG_OR_ACCOUNT and t.altcollected and not app.IsInPartySync and not app.CollectibleQuestsLocked then
		return 2;
	end
	-- If the quest is repeatable, then check other things to determine if it has ever been completed
	if t.repeatable and app.Settings:GetTooltipSetting("RepeatableFirstTime") then
		if app.CurrentCharacter.Quests[questID] then
			return 1;
		end
		-- can an alt quest of a repeatable quest be permanent?
		-- if not considering account-mode, consider the quest completed once if any altquest was also completed
		if not app.MODE_DEBUG_OR_ACCOUNT and t.altQuests then
			-- If the quest has an altQuest which was completed on this character, return shared completed
			for i,altQuestID in ipairs(t.altQuests) do
				-- any altQuest completed on this character, return shared completion
				if app.CurrentCharacter.Quests[altQuestID] then
					return 2;
				end
			end
		end
		if Grail then
			-- Import previously completed repeatable quest from Grail addon data
			if Grail:HasQuestEverBeenCompleted(questID) then
				ATTAccountWideData.Quests[questID] = 1;
				app.CurrentCharacter.Quests[questID] = 1;
				return 1;
			end
			-- if not considering account-mode tracking, consider the quest completed once if any altquest was also completed
			if not app.MODE_DEBUG_OR_ACCOUNT and t.altQuests then
				-- If the quest has an altQuest which was completed on this character, return shared completed
				local isCollected;
				for i,altQuestID in ipairs(t.altQuests) do
					-- any altQuest completed on this character, return shared completion
					if Grail:HasQuestEverBeenCompleted(altQuestID) then
						ATTAccountWideData.Quests[altQuestID] = 1;
						app.CurrentCharacter.Quests[altQuestID] = 1;
						isCollected = 2;
					end
				end
				if isCollected then return isCollected; end
			end
		end
		if WorldQuestTrackerAddon then
			-- Import previously completed repeatable quest from WorldQuestTracker addon data
			local wqt_questDoneHistory = WorldQuestTrackerAddon.db.profile.history.quest
			local wqt_global = wqt_questDoneHistory.global
			local wqt_local = wqt_questDoneHistory.character[app.GUID]

			if wqt_local and wqt_local[questID] and wqt_local[questID] > 0 then
				ATTAccountWideData.Quests[questID] = 1;
				app.CurrentCharacter.Quests[questID] = 1;
				return 1;
			end

			-- only consider altquest completion if not on account-mode
			if wqt_local and not app.MODE_DEBUG_OR_ACCOUNT and t.altQuests then
				local isCollected;
				for i,altQuestID in ipairs(t.altQuests) do
					-- any altQuest completed on this character, return shared completion
					if wqt_local[altQuestID] and wqt_local[altQuestID] > 0 then
						ATTAccountWideData.Quests[altQuestID] = 1;
						app.CurrentCharacter.Quests[altQuestID] = 1;
						isCollected = 2;
					end
				end
				if isCollected then return isCollected; end
			end

			-- quest completed on any character, return shared completion
			if wqt_global and wqt_global[questID] and wqt_global[questID] > 0 then
				ATTAccountWideData.Quests[questID] = 1;
				-- only return as completed if tracking account wide
				if app.AccountWideQuests then
					return 2;
				end
			end
		end
		-- quest completed on any character and tracking account-wide, return shared completion regardless of account-mode
		if app.AccountWideQuests then
			if ATTAccountWideData.Quests[questID] then
				return 2;
			end
		end
	end
	if not t.repeatable and app.AccountWideQuests then
		-- any character has completed this specific quest, return shared completion
		if ATTAccountWideData.Quests[questID] then
			return 2;
		end
	end
end
-- Generate a simple sourcequest completion string for a questRef
app.SourceQuestString = function(quest)
	if quest then
		if type(quest) == "string" or type(quest) == "number" then
			quest = app.SearchForObject("questID",tonumber(quest));
		end
	end
	if quest then
		if quest.missingPrequisites or quest.prereqs then
			local info = {};
			for sq,c in pairs(quest.prereqs) do
				tinsert(info, sq);
				tinsert(info, c)
			end
			return app.TableConcat(info, nil, nil, ":");
		elseif quest.sourceQuests then
			local info = {};
			for _,sq in ipairs(quest.sourceQuests) do
				tinsert(info, sq);
				tinsert(info, IsQuestFlaggedCompleted(sq) and "1" or "0")
			end
			return app.TableConcat(info, nil, nil, ":");
		end
	end
	return "?";
end

-- NPC & Title Name Harvesting Lib (https://us.battle.net/forums/en/wow/topic/20758497390?page=1#post-4, Thanks Gello!)
(function()
local NPCTitlesFromID = {};
local NPCHarvester = CreateFrame("GameTooltip", "AllTheThingsNPCHarvester", UIParent, "GameTooltipTemplate");
app.NPCNameFromID = setmetatable({}, { __index = function(t, id)
	if not id then return; end
	id = tonumber(id);
	if id > 0 then
		NPCHarvester:SetOwner(UIParent,"ANCHOR_NONE");
		NPCHarvester:SetHyperlink(format("unit:Creature-0-0-0-0-%d-0000000000",id));
		local title = AllTheThingsNPCHarvesterTextLeft1:GetText();
		if title and NPCHarvester:NumLines() > 2 then
			rawset(NPCTitlesFromID, id, AllTheThingsNPCHarvesterTextLeft2:GetText());
		end
		NPCHarvester:Hide();
		if title and title ~= RETRIEVING_DATA then
			rawset(t, id, title);
			return title;
		end
	else
		local title = L["HEADER_NAMES"][id];
		rawset(t, id, title);
		return title;
	end
	return RETRIEVING_DATA;
end});
app.NPCTitlesFromID = NPCTitlesFromID;
end)();

-- Search Caching
local searchCache = {};
-- Merges an Object into an existing set of Objects so as to not duplicate any incoming Objects
local MergeObject,
-- Nests an Object under another Object, only creating the 'g' group if necessary
-- ex. NestObject(parent, new, newCreate, index)
NestObject,
-- Merges multiple Objects into an existing set of Objects so as to not duplicate any incoming Objects
-- ex. MergeObjects(group, group2, newCreate)
MergeObjects,
-- Nests multiple Objects under another Object, only creating the 'g' group if necessary
-- ex. NestObjects(parent, groups, newCreate)
NestObjects,
-- Nests multiple Objects under another Object using an optional set of functions to determine priority on the adding of objects, only creating the 'g' group if necessary
-- ex. PriorityNestObjects(parent, groups, newCreate, function1, function2, ...)
PriorityNestObjects,
RefreshAchievementCollection;
app.searchCache = searchCache;
(function()
local keysByPriority = {	-- Sorted by frequency of use.
	"s",
	"toyID",
	"itemID",
	"speciesID",
	"questID",
	"npcID",
	"creatureID",
	"objectID",
	"mapID",
	"criteriaID",
	"achID",
	"currencyID",
	"encounterID",
	"instanceID",
	"factionID",
	"recipeID",
	"spellID",
	"classID",
	"professionID",
	"categoryID",
	"followerID",
	"illusionID",
	"tierID",
	"unit",
	"dungeonID",
	"headerID"
};
local function GetKey(t)
	for _,key in ipairs(keysByPriority) do
		if rawget(t, key) then
			return key;
		end
	end
	for _,key in ipairs(keysByPriority) do
		if t[key] then	-- This goes a bit deeper.
			return key;
		end
	end
	--[[
	print("could not determine key for object")
	for key,value in pairs(t) do
		print(key, value);
	end
	--]]
end
local function CreateHash(t)
	local key = t.key or GetKey(t) or t.text;
	if key then
		local hash = key .. (rawget(t, key) or t[key] or "NOKEY");
		if key == "criteriaID" and t.achievementID then
			hash = hash .. ":" .. t.achievementID;
		elseif key == "itemID" and t.modItemID and t.modItemID ~= t.itemID then
			hash = key .. t.modItemID;
		elseif key == "creatureID" then
			if t.encounterID then hash = hash .. ":" .. t.encounterID; end
			local difficultyID = GetRelativeValue(t, "difficultyID");
			if difficultyID then hash = hash .. "-" .. difficultyID; end
		elseif key == "encounterID" then
			if t.creatureID then hash = hash .. ":" .. t.creatureID; end
			local difficultyID = GetRelativeValue(t, "difficultyID");
			if difficultyID then hash = hash .. "-" .. difficultyID; end
			if t.crs then
				local numCrs = #t.crs;
				if numCrs == 1 then
					hash = hash .. t.crs[1];
				elseif numCrs == 2 then
					hash = hash .. t.crs[1] .. t.crs[2];
				elseif numCrs > 2 then
					hash = hash .. t.crs[1] .. t.crs[2] .. t.crs[3];
				end
			end
		elseif key == "difficultyID" then
			local instanceID = GetRelativeValue(t, "instanceID");
			if instanceID then hash = hash .. "-" .. instanceID; end
		elseif key == "headerID" then
			-- for custom headers, they may be used in conjunction with other bits of data that we don't want to merge together (because it makes no sense)
			-- Separate if using Class requirements
			if t.c then
				for _,class in pairs(t.c) do
					hash = "C" .. class .. hash;
				end
			end
			-- Separate if using Faction/Race requirements
			if t.r then
				hash = "F" .. t.r .. hash;
			elseif t.races then
				for _,race in pairs(t.races) do
					hash = "R" .. race .. hash;
				end
			end
		elseif key == "spellID" and t.itemID then
			-- Some recipes teach the same spell, so need to differentiate by their itemID as well
			hash = hash .. ":" .. t.itemID;
		end
		if t.rank then
			hash = hash .. "." .. t.rank;
			-- app.PrintDebug("hash.rank",hash)
		end
		rawset(t, "hash", hash);
		return hash;
	end
end
app.CreateHash = CreateHash;
MergeObject = function(g, t, index, newCreate)
	if g and t then
		local hash = t.hash;
		-- print("_",hash);
		if hash then
			for i,o in ipairs(g) do
				if o.hash == hash then
					MergeProperties(o, t, true);
					NestObjects(o, t.g, newCreate);
					return o;
				end
			end
		-- else app.PrintDebug("NO Hash for MergeObject",t.text)
		end
		if index then
			tinsert(g, index, newCreate and CreateObject(t) or t);
		else
			tinsert(g, newCreate and CreateObject(t) or t);
		end
	end
end
NestObject = function(p, t, newCreate, index)
	if p and t then
		local g = p.g;
		if g then
			MergeObject(g, t, index, newCreate);
		elseif newCreate then
			p.g = { CreateObject(t) };
		else
			p.g = { t };
		end
	end
end
MergeObjects = function(g, g2, newCreate)
	if g2 and #g2 > 25 then
		local hashTable,t = {};
		for i,o in ipairs(g) do
			local hash = o.hash;
			if hash then
				hashTable[hash] = o;
			end
		end
		local hash;
		if newCreate then
			for i,o in ipairs(g2) do
				hash = o.hash;
				-- print("_",hash);
				if hash then
					t = hashTable[hash];
					if t then
						MergeProperties(t, o, true);
						NestObjects(t, o.g, newCreate);
					else
						t = CreateObject(o);
						hashTable[hash] = t;
						tinsert(g, t);
					end
				else
					tinsert(g, CreateObject(o));
				end
			end
		else
			for i,o in ipairs(g2) do
				hash = o.hash;
				-- print("_",hash);
				if hash then
					t = hashTable[hash];
					if t then
						MergeProperties(t, o, true);
						NestObjects(t, o.g);
					else
						hashTable[hash] = o;
						tinsert(g, o);
					end
				else
					tinsert(g, o);
				end
			end
		end
	else
		for i,o in ipairs(g2) do
			MergeObject(g, o, nil, newCreate);
		end
	end
end
NestObjects = function(p, g, newCreate)
	if not g then return; end
	local pg = p.g;
	if pg then
		MergeObjects(pg, g, newCreate);
	elseif #g > 0 then
		p.g = {};
		MergeObjects(p.g, g, newCreate);
	end
end
PriorityNestObjects = function(p, g, newCreate, ...)
	if not g or #g == 0 then return; end
	local pFuncs = {...};
	if pFuncs[1] then
		-- print("PriorityNestObjects",#pFuncs,"Priorities",#g,"Objects")
		-- setup containers for the priority buckets
		local pBuckets, pBucket, skipped = {};
		for i,_ in ipairs(pFuncs) do
			pBuckets[i] = {};
		end
		-- check each object
		for _,o in ipairs(g) do
			-- check each priority function
			for i,pFunc in ipairs(pFuncs) do
				-- if the function matches, put the object in the bucket
				if pFunc(o) then
					-- print("Matched Priority Function",i,o.key,o.key and o[o.key])
					pBucket = pBuckets[i];
					tinsert(pBucket, o);
					break;
				end
			end
			-- no bucket was found, put in skipped
			if not pBucket then
				-- print("No Priority",o.key,o.key and o[o.key])
				if skipped then tinsert(skipped, o);
				else skipped = { o }; end
			end
			-- reset bucket
			pBucket = nil;
		end
		-- then nest each bucket in order of priority
		for i,pBucket in ipairs(pBuckets) do
			-- print("Nesting Priority Bucket",i,#pBucket)
			NestObjects(p, pBucket, newCreate);
		end
		-- and nest anything skipped
		-- print("Nesting Skipped",skipped and #skipped)
		NestObjects(p, skipped, newCreate);
	else
		NestObjects(p, g, newCreate);
	end
end
-- Mergess multiple sources of an object into a single object. Can specify to clean out all sub-groups of the result
app.MergedObject = function(group, rootOnly)
	if not group or not group[1] then return; end
	local merged = CreateObject(group[1], rootOnly);
	for i=2,#group do
		MergeProperties(merged, group[i]);
	end
	-- for a merged object, clean any other references it might still have
	merged.sourceParent = nil;
	merged.parent = nil;
	if rootOnly then
		merged.g = nil;
	end
	return merged;
end
end)();

local function ExpandGroupsRecursively(group, expanded, manual)
	-- expand if there is any sub-group
	if group.g then
		-- if manually expanding
		if (manual or
				-- it's not an item
				(not group.itemID and
				-- not a difficulty
				not group.difficultyID and
				-- incomplete things actually exist below itself
				((group.total or 0) > (group.progress or 0)) and
				-- account/debug mode is active or it is not a 'saved' thing for this character
				(app.MODE_DEBUG_OR_ACCOUNT or not group.saved))
			) then
			-- print("expanded",group.key,group[group.key]);
			group.expanded = expanded;
			for _,subgroup in ipairs(group.g) do
				ExpandGroupsRecursively(subgroup, expanded, manual);
			end
		end
	end
end

local ResolveSymbolicLink;
-- Fills & returns a group with its symlink references, along with all sub-groups recursively if specified
-- This should only be used on a cloned group so the source group is not contaminated
local function FillSymLinks(group, recursive)
	if recursive and group.g then
		for _,s in ipairs(group.g) do
			FillSymLinks(s, recursive);
		end
	end
	if group.sym then
		-- app.PrintDebug("FillSymLinks",group.hash)
		NestObjects(group, ResolveSymbolicLink(group));
		-- make sure this group doesn't waste time getting resolved again somehow
		group.sym = nil;
	end
	-- if app.DEBUG_PRINT == group then app.DEBUG_PRINT = nil; end
	return group;
end

(function()
local select, tremove, unpack =
	  select, tremove, unpack;
local FinalizeModID;
local ArrayAppend = app.ArrayAppend;
-- Checks if any of the provided arguments can be found within the first array object
local function ContainsAnyValue(arr, ...)
	local value;
	local vals = select("#", ...);
	for i=1,vals do
		value = select(i, ...);
		for _,v in ipairs(arr) do
			if v == value then return true; end
		end
	end
end
local function Resolve_Extract(results, group, field)
	if group[field] then
		tinsert(results, group);
	elseif group.g then
		for _,o in ipairs(group.g) do
			Resolve_Extract(results, o, field);
		end
	end
	return results;
end

-- Defines a known set of functions which can be run via symlink resolution. The inputs to each function will be identical in order when called.
-- searchResults - the current set of searchResults when reaching the current sym command
-- o - the specific group object which contains the symlink commands
-- (various expected components of the respective sym command)
local ResolveFunctions = {
	-- Instruction to search the full database for multiple of a given type
	["select"] = function(finalized, searchResults, o, cmd, field, ...)
		local cache, val;
		local vals = select("#", ...);
		for i=1,vals do
			val = select(i, ...);
			cache = app.CleanSourceIgnoredGroups(app.SearchForField(field, val));
			if cache then
				ArrayAppend(searchResults, cache);
			else
				print("Failed to select ", field, val);
			end
		end
	end,
	-- Instruction to select the parent object of the group that owns the symbolic link
	["selectparent"] = function(finalized, searchResults, o, cmd, level)
		level = level or 1;
		local parent = o.parent;
		-- app.PrintDebug("selectparent",level,parent and parent.hash)
		while level > 1 do
			parent = parent and parent.parent;
			level = level - 1;
			-- app.PrintDebug("selectparent",level,parent and parent.hash)
		end
		if parent then
			tinsert(searchResults, parent);
		else
			-- an extra search for the specific 'o' to retrieve the source parent since the parent is not actually attached to the reference resolving the symlink
			local searchedObject = app.SearchForMergedObject(o.key, o[o.key]);
			if searchedObject then
				parent = searchedObject.parent;
				while level > 1 do
					parent = parent and parent.parent;
					level = level - 1;
				end
				if parent then
					tinsert(searchResults, parent);
					return;
				end
			end
			print("Failed to select parent for",o.hash);
		end
	end,
	-- Instruction to find all content marked with the specified 'requireSkill'
	["selectprofession"] = function(finalized, searchResults, o, cmd, requireSkill)
		local search = app:BuildSearchResponse(app:GetDataCache().g, "requireSkill", requireSkill);
		ArrayAppend(searchResults, search);
	end,
	-- Instruction to fill with identical content cached elsewhere for this group (no symlinks)
	["fill"] = function(finalized, searchResults, o)
		local okey = o.key;
		if okey then
			local okeyval = o[okey];
			if okeyval then
				local cache = app.CleanSourceIgnoredGroups(app.SearchForField(okey, okeyval));
				if cache then
					for _,s in ipairs(cache) do
						ArrayAppend(searchResults, s.g);
					end
				end
			end
		end
	end,
	-- Instruction to finalize the current search results and prevent additional queries from affecting this selection
	["finalize"] = function(finalized, searchResults)
		ArrayAppend(finalized, searchResults);
		wipe(searchResults);
	end,
	-- Instruction to take all of the finalized and non-finalized search results and merge them back in to the processing queue
	["merge"] = function(finalized, searchResults)
		local orig;
		if #searchResults > 0 then
			orig = RawCloneData(searchResults);
		end
		wipe(searchResults);
		-- finalized first
		ArrayAppend(searchResults, finalized);
		wipe(finalized);
		-- then any existing searchResults
		ArrayAppend(searchResults, orig);
	end,
	-- Instruction to "push" all of the group values into an object as specified
	["push"] = function(finalized, searchResults, o, cmd, field, value)
		local orig;
		if #searchResults > 0 then
			orig = RawCloneData(searchResults);
		end
		wipe(searchResults);
		searchResults[1] = CreateObject({[field] = value, g = orig });
	end,
	-- Instruction to "pop" all of the group values up one level
	["pop"] = function(finalized, searchResults)
		local orig;
		if #searchResults > 0 then
			orig = RawCloneData(searchResults);
		end
		wipe(searchResults);
		if orig then
			for _,s in ipairs(orig) do
				-- insert raw & symlinked Things from this group
				ArrayAppend(searchResults, s.g, ResolveSymbolicLink(s));
			end
		end
	end,
	-- Instruction to include only search results where a key value is a value
	["where"] = function(finalized, searchResults, o, cmd, field, value)
		for k=#searchResults,1,-1 do
			local s = searchResults[k];
			if not s[field] or s[field] ~= value then
				tremove(searchResults, k);
			end
		end
	end,
	-- Instruction to extract all nested results which contain a given field
	["extract"] = function(finalized, searchResults, o, cmd, field)
		local orig;
		if #searchResults > 0 then
			orig = RawCloneData(searchResults);
		end
		wipe(searchResults);
		if orig then
			for _,o in ipairs(orig) do
				Resolve_Extract(searchResults, o, field);
			end
		end
	end,
	-- Instruction to include the search result with a given index within each of the selection's groups
	["index"] = function(finalized, searchResults, o, cmd, index)
		local orig;
		if #searchResults > 0 then
			orig = RawCloneData(searchResults);
		end
		wipe(searchResults);
		if orig then
			local s, g;
			for k=#orig,1,-1 do
				s = orig[k];
				g = s.g;
				if g and index <= #g then
					tinsert(searchResults, g[index]);
				end
			end
		end
	end,
	-- Instruction to include only search results where a key value is not a value
	["not"] = function(finalized, searchResults, o, cmd, field, ...)
		local vals = select("#", ...);
		if vals < 1 then
			print("'",cmd,"' had empty value set")
			return;
		end
		local s, value;
		for k=#searchResults,1,-1 do
			s = searchResults[k];
			for i=1,vals do
				value = select(i, ...);
				if s[field] == value then
					tremove(searchResults, k);
					break;
				end
			end
		end
	end,
	-- Instruction to include only search results where a key exists
	["is"] = function(finalized, searchResults, o, cmd, field)
		for k=#searchResults,1,-1 do
			local s = searchResults[k];
			if not s[field] then tremove(searchResults, k); end
		end
	end,
	-- Instruction to include only search results where a key doesn't exist
	["isnt"] = function(finalized, searchResults, o, cmd, field)
		for k=#searchResults,1,-1 do
			local s = searchResults[k];
			if s[field] then tremove(searchResults, k); end
		end
	end,
	-- Instruction to include only search results where a key value/table contains a value
	["contains"] = function(finalized, searchResults, o, cmd, field, ...)
		local vals = select("#", ...);
		if vals < 1 then
			print("'",cmd,"' had empty value set")
			return;
		end
		local s, kval;
		for k=#searchResults,1,-1 do
			s = searchResults[k];
			kval = s[field];
			-- key doesn't exist at all on the result
			if not kval then
				tremove(searchResults, k);
			-- none of the values match the contains values
			elseif type(kval) == "table" then
				if not ContainsAnyValue(kval, ...) then
					tremove(searchResults, k);
				end
			-- key exists with single value on the result
			else
				local match;
				for i=1,vals do
					if kval == select(i, ...) then
						match = true;
						break;
					end
				end
				if not match then
					tremove(searchResults, k);
				end
			end
		end
	end,
	-- Instruction to exclude search results where a key value contains a value
	["exclude"] = function(finalized, searchResults, o, cmd, field, ...)
		local vals = select("#", ...);
		if vals < 1 then
			print("'",cmd,"' had empty value set")
			return;
		end
		local s, kval;
		for k=#searchResults,1,-1 do
			s = searchResults[k];
			kval = s[field];
			-- key exists
			if kval then
				local match;
				for i=1,vals do
					if kval == select(i, ...) then
						match = true;
						break;
					end
				end
				if match then
					-- TEMP logic to allow Ensembles to continue working until they get fixed again...
					if field == "itemID" and s.g and kval == o[field] then
						ArrayAppend(searchResults, s.g);
					end
					tremove(searchResults, k);
				end
			end
		end
	end,
	-- Instruction to include only search results where an item is of a specific inventory type
	["invtype"] = function(finalized, searchResults, o, cmd, ...)
		local vals = select("#", ...);
		if vals < 1 then
			print("'",cmd,"' had empty value set")
			return;
		end
		local s, invtype;
		for k=#searchResults,1,-1 do
			s = searchResults[k];
			if s.itemID then
				invtype = select(4, GetItemInfoInstant(s.itemID));
				local match;
				for i=1,vals do
					if invtype == select(i, ...) then
						match = true;
						break;
					end
				end
				if not match then
					tremove(searchResults, k);
				end
			end
		end
	end,
	-- Instruction to search the full database for multiple achievementID's and persist only actual achievements
	["meta_achievement"] = function(finalized, searchResults, o, cmd, ...)
		local vals = select("#", ...);
		if vals < 1 then
			print("'",cmd,"' had empty value set")
			return;
		end
		local cache, value;
		for i=1,vals do
			value = select(i, ...);
			cache = app.CleanSourceIgnoredGroups(app.SearchForField("achievementID", value));
			if cache then
				ArrayAppend(searchResults, cache);
			else
				print("Failed to select achievementID",value);
			end
		end
		-- Remove any Criteria groups associated with those achievements
		for k=#searchResults,1,-1 do
			local s = searchResults[k];
			if s.criteriaID then tremove(searchResults, k); end
		end
	end,
	-- Instruction to include only search results where an item is of a specific relic type
	["relictype"] = function(finalized, searchResults, o, cmd, ...)
		local vals = select("#", ...);
		if vals < 1 then
			print("'",cmd,"' had empty value set")
			return;
		end
		--[[
		RELIC_SLOT_TYPE_ARCANE = "Arcane";
		RELIC_SLOT_TYPE_BLOOD = "Blood";
		RELIC_SLOT_TYPE_FEL = "Fel";
		RELIC_SLOT_TYPE_FIRE = "Fire";
		RELIC_SLOT_TYPE_FROST = "Frost";
		RELIC_SLOT_TYPE_HOLY = "Holy";
		RELIC_SLOT_TYPE_IRON = "Iron";
		RELIC_SLOT_TYPE_LIFE = "Life";
		RELIC_SLOT_TYPE_SHADOW = "Shadow";
		RELIC_SLOT_TYPE_WATER = "Water";
		RELIC_SLOT_TYPE_WIND = "Storm";
		]]--
		local types = {...};
		-- replace the short constant values with in-game localized values
		for i=#types,1,-1 do
			types[i] = _G["RELIC_SLOT_TYPE_" .. types[i]];
		end
		local s, itemID;
		for k=#searchResults,1,-1 do
			s = searchResults[k];
			itemID = s.itemID;
			if itemID and IsArtifactRelicItem(itemID) and contains(types, select(3, C_ArtifactUI.GetRelicInfoByItemID(itemID))) then
				-- We're good.
			else
				tremove(searchResults, k);
			end
		end
	end,
	-- Instruction to apply a specific modID to any Items within the finalized search results
	["modID"] = function(finalized, searchResults, o, cmd, modID)
		FinalizeModID = modID;
	end,
	-- Instruction to apply the modID from the Source object to any Items within the finalized search results
	["myModID"] = function(finalized, searchResults, o)
		FinalizeModID = o.modID;
	end,
	["achievement_criteria"] = function(finalized, searchResults, o)
		-- Instruction to select the criteria provided by the achievement this is attached to. (maybe build this into achievements?)
		if GetAchievementNumCriteria then
			local achievementID = o.achievementID;
			local cache;
			local criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString, id, criteriaObject;
			for criteriaID=1,GetAchievementNumCriteria(achievementID),1 do
				criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString, id = GetAchievementCriteriaInfo(achievementID, criteriaID);
				criteriaObject = app.CreateAchievementCriteria(id);
				if criteriaType == 27 then
					cache = app.SearchForField("questID", assetID);
				elseif criteriaType == 36 or criteriaType == 42 then	-- Items
					criteriaObject.providers = {{ "i", assetID }};
				elseif criteriaType == 110	-- Casting spells on specific target
					or criteriaType == 29 or criteriaType == 69	-- Buff Gained
					or criteriaType == 43 then	-- Exploration
					-- Ignored
				else
					print("Unhandled Criteria Type", criteriaType, assetID);
				end
				if cache then
					local uniques = {};
					MergeObjects(uniques, cache);
					for i,o in ipairs(uniques) do
						rawset(o, "text", nil);
						for key,value in pairs(o) do
							criteriaObject[key] = value;
						end
						rawset(o, "text", criteriaObject.text);
					end
				end
				criteriaObject.achievementID = achievementID;
				criteriaObject.parent = o;
				tinsert(searchResults, criteriaObject);
				app.CacheFields(criteriaObject);
			end
		end
	end,
	-- Instruction to include only search results where an item is a relic (Not used currently)
	-- ["isrelic"] = function(finalized, searchResults)
	-- 	local s, itemID;
	-- 	for k=#searchResults,1,-1 do
	-- 		s = searchResults[k];
	-- 		itemID = s.itemID;
	-- 		if not itemID or not IsArtifactRelicItem(itemID) then
	-- 			tremove(searchResults, k);
	-- 		end
	-- 	end
	-- end,
};
-- Subroutine Logic Cache
local SubroutineCache = {
	["pvp_gear_base"] = function(finalized, searchResults, o, cmd, tierID, headerID1, headerID2)
		local select, pop, where = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where;
		select(finalized, searchResults, o, "select", "tierID", tierID);	-- Select the Expansion header
		pop(finalized, searchResults);	-- Discard the Expansion header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID1);	-- Select the Season header
		if headerID2 then
			pop(finalized, searchResults);	-- Discard the Season header and acquire the children.
			where(finalized, searchResults, o, "where", "headerID", headerID2);	-- Select the Set header
		end
	end,
	["pvp_gear_faction_base"] = function(finalized, searchResults, o, cmd, tierID, headerID1, headerID2, headerID3)
		local select, pop, where = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where;
		select(finalized, searchResults, o, "select", "tierID", tierID);	-- Select the Expansion header
		pop(finalized, searchResults);	-- Discard the Expansion header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID1);	-- Select the Season header
		pop(finalized, searchResults);	-- Discard the Season header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID2);	-- Select the Faction header
		pop(finalized, searchResults);	-- Discard the Faction header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID3);	-- Select the Set header
	end,
	-- Set Gear
	["pvp_set_ensemble"] = function(finalized, searchResults, o, cmd, tierID, headerID1, headerID2, classID)
		local select, pop, where, extract = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.extract;
		select(finalized, searchResults, o, "select", "tierID", tierID);	-- Select the Expansion header
		pop(finalized, searchResults);	-- Discard the Expansion header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID1);	-- Select the Season header
		pop(finalized, searchResults);	-- Discard the Season header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID2);	-- Select the Set header
		pop(finalized, searchResults);	-- Discard the Set header and acquire the children.
		where(finalized, searchResults, o, "where", "classID", classID);	-- Select all the class header.
		extract(finalized, searchResults, o, "extract", "s");	-- Extract all Items with a SourceID
	end,
	["pvp_set_faction_ensemble"] = function(finalized, searchResults, o, cmd, tierID, headerID1, headerID2, headerID3, classID)
		local select, pop, where, extract = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.extract;
		select(finalized, searchResults, o, "select", "tierID", tierID);	-- Select the Expansion header
		pop(finalized, searchResults);	-- Discard the Expansion header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID1);	-- Select the Season header
		pop(finalized, searchResults);	-- Discard the Season header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID2);	-- Select the Faction header
		pop(finalized, searchResults);	-- Discard the Faction header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID3);	-- Select the Set header
		pop(finalized, searchResults);	-- Discard the Set header and acquire the children.
		where(finalized, searchResults, o, "where", "classID", classID);	-- Select all the class header.
		extract(finalized, searchResults, o, "extract", "s");	-- Extract all Items with a SourceID
	end,
	-- Weapons
	["pvp_weapons_ensemble"] = function(finalized, searchResults, o, cmd, tierID, headerID1, headerID2)
		local select, pop, where, extract = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.extract;
		select(finalized, searchResults, o, "select", "tierID", tierID);	-- Select the Expansion header
		pop(finalized, searchResults);	-- Discard the Expansion header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID1);	-- Select the Season header
		pop(finalized, searchResults);	-- Discard the Season header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID2);	-- Select the Set header
		pop(finalized, searchResults);	-- Discard the Set header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", -319);	-- Select the "Weapons" header.
		extract(finalized, searchResults, o, "extract", "s");	-- Extract all Items with a SourceID
	end,
	["pvp_weapons_faction_ensemble"] = function(finalized, searchResults, o, cmd, tierID, headerID1, headerID2, headerID3)
		local select, pop, where, extract = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.extract;
		select(finalized, searchResults, o, "select", "tierID", tierID);	-- Select the Expansion header
		pop(finalized, searchResults);	-- Discard the Expansion header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID1);	-- Select the Season header
		pop(finalized, searchResults);	-- Discard the Season header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID2);	-- Select the Faction header
		pop(finalized, searchResults);	-- Discard the Faction header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", headerID3);	-- Select the Set header
		pop(finalized, searchResults);	-- Discard the Set header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", -319);	-- Select the "Weapons" header.
		extract(finalized, searchResults, o, "extract", "s");	-- Extract all Items with a SourceID
	end,
	-- Common Northrend/Cataclysm Recipes Vendor
	["common_recipes_vendor"] = function(finalized, searchResults, o, cmd, npcID)
			local select, pop, is, exclude = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.is, ResolveFunctions.exclude;
		select(finalized, searchResults, o, "select", "creatureID", npcID);	-- Main Vendor
		pop(finalized, searchResults);	-- Remove Main Vendor and push his children into the processing queue.
		is(finalized, searchResults, o, "is", "itemID");	-- Only Items
		-- Exclude items specific to certain vendors
		exclude(finalized, searchResults, o, "exclude", "itemID",
			-- Borya <Tailoring Supplies> Cataclysm Tailoring
			6270,	-- Pattern: Blue Linen Vest
			6274,	-- Pattern: Blue Overalls
			10314,	-- Pattern: Lavender Mageweave Shirt
			10317,	-- Pattern: Pink Mageweave Shirt
			5772,	-- Pattern: Red Woolen Bag
			-- Sumi <Blacksmithing Supplies> Cataclysm Blacksmithing
			12162,	-- Plans: Hardened Iron Shortsword
			-- Tamar <Leatherworking Supplies> Cataclysm Leatherworking
			18731,	-- Pattern: Heavy Leather Ball
			-- Kithas <Enchanting Supplies> Cataclysm Enchanting
			6349,	-- Formula: Enchant 2H Weapon - Lesser Intellect
			20753,	-- Formula: Lesser Wizard Oil
			20752,	-- Formula: Minor Mana Oil
			20758,	-- Formula: Minor Wizard Oil
			22307,	-- Pattern: Enchanted Mageweave Pouch
			-- Marith Lazuria <Jewelcrafting Supplies> Cataclysm Jewelcrafting
			-- Shazdar <Sous Chef> Cataclysm Cooking
			-- Tiffany Cartier <Jewelcrafting Supplies> Northrend Jewelcrafting
			-- Timothy Jones <Jewelcrafting Trainer> Northrend Jewelcrafting
		0);	-- 0 allows the trailing comma on previous itemIDs for cleanliness
	end,
	["common_vendor"] = function(finalized, searchResults, o, cmd, npcID)
		local select, pop, is = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.is;
		select(finalized, searchResults, o, "select", "creatureID", npcID);	-- Main Vendor
		pop(finalized, searchResults);	-- Remove Main Vendor and push his children into the processing queue.
		is(finalized, searchResults, o, "is", "itemID");	-- Only Items
	end,
	-- TW Instance
	["tw_instance"] = function(finalized, searchResults, o, cmd, instanceID)
		local select, pop, where, push, finalize = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.push, ResolveFunctions.finalize;
		select(finalized, searchResults, o, "select", "itemID", 133543);	-- Infinite Timereaver
		push(finalized, searchResults, o, "push", "headerID", -1);	-- Push into 'Common Boss Drops' header
		finalize(finalized, searchResults);	-- capture current results
		select(finalized, searchResults, o, "select", "instanceID", instanceID);	-- select this instance
		where(finalized, searchResults, o, "where", "u", 1016);	-- only the instance which is marked as TIMEWALKING
		pop(finalized, searchResults);	-- pop the instance header
	end,
	-- Wod Dungeon
	["common_wod_dungeon_drop"] = function(finalized, searchResults, o, cmd, difficultyID, headerID)
		local select, pop, where = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where;
		select(finalized, searchResults, o, "select", "headerID", -23);	-- Common Dungeon Drops
		pop(finalized, searchResults);	-- Discard the Header and acquire all of their children.
		where(finalized, searchResults, o, "where", "difficultyID", difficultyID);	-- Normal/Heroic/Mythic/Timewalking
		pop(finalized, searchResults);	-- Discard the Diffculty Header and acquire all of their children.
		where(finalized, searchResults, o, "where", "headerID", headerID);	-- Head/Shoulder/Chest/Legs/Feet/Wrist/Hands/Waist
	end,
	-- Wod Dungeon TW
	["common_wod_dungeon_drop_tw"] = function(finalized, searchResults, o, cmd, difficultyID, headerID)
		local select, pop, where = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where;
		select(finalized, searchResults, o, "select", "headerID", -23);	-- Common Dungeon Drops
		where(finalized, searchResults, o, "where", "u", 1016);	-- only the Common Dungeon Drops which is marked as TIMEWALKING
		pop(finalized, searchResults);	-- Discard the Header and acquire all of their children.
		where(finalized, searchResults, o, "where", "headerID", headerID);	-- Head/Shoulder/Chest/Legs/Feet/Wrist/Hands/Waist
	end,
	-- Korthian Armaments
	["korthian_armaments"] = function(finalized, searchResults, o, cmd, inv)
		local select, pop, invtype = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.invtype;
		select(finalized, searchResults, o, "select", "itemID", 187187);	-- Korthian Armaments
		pop(finalized, searchResults);	-- Discard the Item Header and acquire all of their children.
		pop(finalized, searchResults);	-- Discard the Headers and acquire all of their children.
		invtype(finalized, searchResults, o, "invtype", inv);	-- Only slot-specific
	end,
	["bfa_azerite_armor_chest_dungeons"] = function(finalized, searchResults, o)
		local select, pop, where, is, invtype, modID = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.is, ResolveFunctions.invtype, ResolveFunctions.modID;
		-- Dungeons
		select(finalized, searchResults, o, "select", "instanceID",
			968,	-- Atal'Dazar
			1001,	-- Freehold
			1041,	-- King's Rest
			1178,	-- Operation: Mechagon ??
			1036,	-- Shrine of the Storm
			1023,	-- Siege of Boralus
			1030,	-- Temple of Sethraliss
			1012,	-- The MOTHERLODE!!
			1022,	-- The Underrot
			1002,	-- Tol Dagor
			1021	-- Waycrest Manor
		);

		-- Process the Dungeons, Normal Mode Only Loot for the azerite pieces.
		pop(finalized, searchResults);	-- Discard the Instance Headers and acquire all of their children.
		where(finalized, searchResults, o, "where", "difficultyID", 1);	-- Select only the Normal Difficulty Headers.
		pop(finalized, searchResults);	-- Discard the Difficulty Headers and acquire all of their children.
		pop(finalized, searchResults);	-- Discard the Encounter Headers and acquire all of their children.
		is(finalized, searchResults, o, "is", "itemID");	-- Only Items!
		invtype(finalized, searchResults, o, "invtype", "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE");	-- Only Head, Shoulders, and Chest items. (azerite)
		modID(finalized, searchResults, 1);	-- Normal
	end,
	["bfa_azerite_armor_chest_warfront"] = function(finalized, searchResults, o)
		local select, pop, where, is, invtype, modID = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.is, ResolveFunctions.invtype, ResolveFunctions.modID;
		select(finalized, searchResults, o, "select", "headerID", -10057);	-- War Effort
		pop(finalized, searchResults);	-- Discard the War Effort Header and acquire the children.
		where(finalized, searchResults, o, "where", "mapID", 14);	-- Arathi Highlands
		pop(finalized, searchResults);	-- Discard the Map Header and acquire the children.
		where(finalized, searchResults, o, "where", "headerID", -1);	-- Select the Common Boss Drop Header.
		pop(finalized, searchResults);	-- Discard the Common Boss Drop Header and acquire the children.
		is(finalized, searchResults, o, "is", "itemID");	-- Only Items!
		invtype(finalized, searchResults, o, "invtype", "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE");	-- Only Head, Shoulders, and Chest items. (azerite)
		modID(finalized, searchResults, 5);	-- iLvl 340
	end,
	["bfa_azerite_armor_chest_zonedrops"] = function(finalized, searchResults, o)
		local select, pop, where, is, invtype, myModID = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.is, ResolveFunctions.invtype, ResolveFunctions.myModID;
		-- World Quest Rewards
		select(finalized, searchResults, o, "select", "mapID",
			896,	-- Drustvar
			942,	-- Stormsong Valley
			895,	-- Tiragarde Sound
			863,	-- Nazmir
			864,	-- Vol'dun
			862	-- Zuldazar
		);

		-- Process the World Quest Rewards
		pop(finalized, searchResults);	-- Discard the Map Headers and acquire all of their children.
		where(finalized, searchResults, o, "where", "headerID", -903);	-- Select only the Zone Rewards Headers
		pop(finalized, searchResults);	-- Discard the Zone Rewards Headers and acquire all of their children.

		-- Process the headers for the Azerite Armor pieces.
		is(finalized, searchResults, o, "is", "itemID");	-- Only Items!
		invtype(finalized, searchResults, o, "invtype", "INVTYPE_HEAD", "INVTYPE_SHOULDER", "INVTYPE_CHEST", "INVTYPE_ROBE");	-- Only Head, Shoulders, and Chest items. (azerite)
		myModID(finalized, searchResults, o);	-- Apply matching ModID as source

	end,
	["bfa_azerite_armor_chest"] = function(finalized, searchResults, o)
		local sub = ResolveFunctions.sub;
		local modID = o.modID;
		-- Conditional checks to see which subroutine applies to this chest
		if modID == 1 or modID == 2 then
			sub(finalized, searchResults, o, "sub", "bfa_azerite_armor_chest_dungeons");
			return;
		end
		if modID == 5 then
			sub(finalized, searchResults, o, "sub", "bfa_azerite_armor_chest_warfront");
			return;
		end
		sub(finalized, searchResults, o, "sub", "bfa_azerite_armor_chest_zonedrops");
	end,
	["legion_relinquished_base"] = function(finalized, searchResults, o)
		local select, pop, where, is, finalize, merge, extract = ResolveFunctions.select, ResolveFunctions.pop, ResolveFunctions.where, ResolveFunctions.is, ResolveFunctions.finalize, ResolveFunctions.merge, ResolveFunctions.extract;
		-- Legion Legendaries
		--[[
		{"select", "npcID", 106655},	-- Arcanomancer Vridiel
		{"pop"},	-- Remove Arcanomancer Vridiel and push his children into the processing queue.
		{ "exclude", "itemID", 154879, 157796 },	-- Exclude the Purified Titan Essence and the Awoken Titan Essence
		{"pop"},	-- Remove the Legendary Tokens and push the children into the processing queue.
		{"finalize"},	-- Push the items to the finalized list.
		]]--

		-- PVP Gear
		--[[
		-- Demonic Combatant & Gladiator Season 7 Gear
		{"select", "headerID", -688},	-- Demonic Gladiator Season 7
		{"pop"},	-- Remove Season Header and push the children into the processing queue.
		{"pop"},	-- Remove Faction Header and push the children into the processing queue.
		{"contains", "headerID", -660, -661},	-- Select only the Aspirant / Combatant Gear & Gladiator Headers.
		{"pop"},	-- Remove Aspirant / Combatant Gear Header and push the children into the processing queue.
		{"pop"},	-- Remove Class / Armor Header and push the children into the processing queue.
		{"finalize"},	-- Push the items to the finalized list.
		]]--

		-- Unsullied Gear
		select(finalized, searchResults, o, "select", "itemID",
			152740,	-- Unsullied Cloak
			152738,	-- Unsullied Cloth Cap
			152734,	-- Unsullied Cloth Mantle
			153135,	-- Unsullied Cloth Robes
			152742,	-- Unsullied Cloth Cuffs
			153141,	-- Unsullied Cloth Mitts
			153156,	-- Unsullied Cloth Sash
			153154,	-- Unsullied Cloth Leggings
			153144,	-- Unsullied Cloth Slippers
			153139,	-- Unsullied Leather Headgear
			153145,	-- Unsullied Leather Spaulders
			153151,	-- Unsullied Leather Tunic
			153142,	-- Unsullied Leather Armbands
			152739,	-- Unsullied Leather Grips
			153148,	-- Unsullied Leather Belt
			152737,	-- Unsullied Leather Trousers
			153136,	-- Unsullied Leather Treads
			153147,	-- Unsullied Mail Coif
			153137,	-- Unsullied Mail Spaulders
			152741,	-- Unsullied Mail Chestguard
			153158,	-- Unsullied Mail Bracers
			153149,	-- Unsullied Mail Gloves
			152744,	-- Unsullied Mail Girdle
			153138,	-- Unsullied Mail Legguards
			153152,	-- Unsullied Mail Boots
			153155,	-- Unsullied Plate Helmet
			153153,	-- Unsullied Plate Pauldrons
			153143,	-- Unsullied Plate Breasplate
			153150,	-- Unsullied Plate Vambraces
			153157,	-- Unsullied Plate Gauntlets
			153140,	-- Unsullied Plate Waistplate
			153146,	-- Unsullied Plate Greaves
			152743,	-- Unsullied Plate Sabatons
			152736,	-- Unsullied Necklace
			152735,	-- Unsullied Ring
			152733,	-- Unsullied Trinket
			152799	-- Unsullied Relic
		);
		pop(finalized, searchResults);	-- Remove the Unsullied Tokens and push the children into the processing queue.
		finalize(finalized, searchResults);	-- Push the Unsullied items to the finalized list.

		-- World Bosses
		select(finalized, searchResults, o, "select", "encounterID",
			1790,	-- Ana-Mouz
			1956,	-- Apocron
			1883,	-- Brutallus
			1774,	-- Calamir
			1789,	-- Drugon the Frostblood
			1795,	-- Flotsam
			1770,	-- Humongris
			1769,	-- Levantus
			1884,	-- Malificus
			1783,	-- Na'zak the Fiend
			1749,	-- Nithogg
			1763,	-- Shar'thos
			1885,	-- Si'vash
			1756,	-- The Soultakers
			1796	-- Withered J'im
		);
		finalize(finalized, searchResults);	-- Push the unprocessed Bosses to the finalized list.

		-- Raids
		select(finalized, searchResults, o, "select", "instanceID",
			768,	-- Emerald Nightmare
			861,	-- Trial of Valor
			786,	-- The Nighthold
			875		-- Tomb of Sargeras
		);

		-- Process the Raids, Normal Mode Only Loot for bosses
		pop(finalized, searchResults);	-- Discard the Instance Headers and acquire all of their children.
		where(finalized, searchResults, o, "where", "difficultyID", 14);	-- Select only the Normal Difficulty Headers.
		pop(finalized, searchResults);	-- Discard the Difficulty Headers and acquire all of their children.
		is(finalized, searchResults, o, "is", "encounterID");	-- Only use the encounters themselves, no zone drops.
		finalize(finalized, searchResults);	-- Push the unprocessed Bosses to the finalized list.

		-- Dungeons
		select(finalized, searchResults, o, "select", "instanceID",
			777,	-- Assault on Violet Hold
			740,	-- Blackrook Hold
			900,	-- Cathedral of Eternal Night
			800,	-- Court of Stars
			762,	-- Darkheart Thicket
			716,	-- Eye of Azshara
			721,	-- Halls of Valor
			727,	-- Maw of Souls
			767,	-- Neltharion's Lair
			860,	-- Return to Karazhan
			945,	-- Seat of the Triumvirate
			749,	-- The Arcway
			707		-- Vault of the Wardens
		);

		-- Process the Dungeons, Mythic Mode Only Loot for bosses
		pop(finalized, searchResults);	-- Discard the Instance Headers and acquire all of their children.
		where(finalized, searchResults, o, "where", "difficultyID", 23);	-- Select only the Mythic Difficulty Headers.
		pop(finalized, searchResults);	-- Discard the Difficulty Headers and acquire all of their children.
		finalize(finalized, searchResults);	-- Push the unprocessed Bosses to the finalized list.

		-- World Quest Rewards
		select(finalized, searchResults, o, "select", "mapID",
			905,	-- Argus
			630,	-- Azsuna
			646,	-- Broken Shore
			650,	-- Highmountain
			634,	-- Stormheim
			680,	-- Suramar
			641		-- Val'sharah
		);

		-- Process the World Quest Rewards
		pop(finalized, searchResults);	-- Discard the Map Headers and acquire all of their children.
		where(finalized, searchResults, o, "where", "headerID", -34);	-- Select only the World Quest Headers
		pop(finalized, searchResults);	-- Discard the World Quest Headers and acquire all of their children.
		is(finalized, searchResults, o, "is", "headerID");	-- Only use the item sets themselves, no zone drops.
		finalize(finalized, searchResults);	-- Push the unprocessed Headers to the finalized list.

		merge(finalized, searchResults);	-- Merge the finalized Groups back into the processing queue.
		extract(finalized, searchResults, o, "extract", "itemID");	-- Extract all Items
	end,
	["legion_relinquished"] = function(finalized, searchResults, o, cmd, invtypes, ...)
		local sub, merge, invtype, contains, modID = ResolveFunctions.sub, ResolveFunctions.merge, ResolveFunctions.invtype, ResolveFunctions.contains, ResolveFunctions.modID;
		sub(finalized, searchResults, o, "sub", "legion_relinquished_base");	-- collect the base set of possible relinquished items
		merge(finalized, searchResults);	-- merge them back to be processed
		invtype(finalized, searchResults, o, "invtype", unpack(invtypes));	-- invtypes is a table of inventory slot strings to filter
		if select("#", ...) > 0 then
			contains(finalized, searchResults, o, "contains", "f", ...);	-- extra params are a set of allowed filterID (f) values
		end
		modID(finalized, searchResults, o, "modID", 43);	-- apply the relinquished modID
	end,
	["legion_relinquished_relic"] = function(finalized, searchResults, o, cmd, ...)
		local sub, merge, relictype, modID = ResolveFunctions.sub, ResolveFunctions.merge, ResolveFunctions.relictype, ResolveFunctions.modID;
		sub(finalized, searchResults, o, "sub", "legion_relinquished_base");	-- collect the base set of possible relinquished items
		merge(finalized, searchResults);	-- merge them back to be processed
		if select("#", ...) > 0 then
			relictype(finalized, searchResults, o, "relictype", ...);	-- only specific relic type(s)
		end
		modID(finalized, searchResults, o, "modID", 43);	-- apply the relinquished modID
	end,
};
-- Instruction to perform a specific subroutine using provided input values
ResolveFunctions.sub = function(finalized, searchResults, o, cmd, sub, ...)
	local subroutine = SubroutineCache[sub];
	-- new logic: no metatable cloning, no table creation for sub-commands
	if subroutine then
		-- app.PrintDebug("sub",o.hash,sub,...)
		subroutine(finalized, searchResults, o, cmd, ...);
		-- each subroutine result is finalized after being processed
		ResolveFunctions.finalize(finalized, searchResults);
		return;
	end
	print("Could not find subroutine", sub);
end;
local ResolveCache = {};
ResolveSymbolicLink = function(o)
	if o.resolved or (o.key and app.ThingKeys[o.key] and ResolveCache[o.hash]) then
		-- app.PrintDebug(o.resolved and "Object Resolve" or "Cache Resolve",o.hash,#(o.resolved or ResolveCache[o.hash]))
		local cloned = {};
		MergeObjects(cloned, o.resolved or ResolveCache[o.hash], true);
		return cloned;
	end
	if o and o.sym then
		FinalizeModID = nil;
		-- app.PrintDebug("Fresh Resolve:",o.hash)
		local searchResults, finalized = {}, {};
		local cmd, cmdFunc;
		for _,sym in ipairs(o.sym) do
			cmd = sym[1];
			cmdFunc = ResolveFunctions[cmd];
			-- app.PrintDebug("sym: '",cmd,"' for",o.hash,"with:",unpack(sym))
			if cmdFunc then
				cmdFunc(finalized, searchResults, o, unpack(sym));
			else
				print("Unknown symlink command",cmd);
			end
			-- app.PrintDebug("Finalized",#finalized,"Results",#searchResults,"after '",cmd,"' for",o.hash,"with:",unpack(sym))
		end

		-- If we have any pending finalizations to make, then merge them into the finalized table. [Equivalent to a "finalize" instruction]
		if #searchResults > 0 then
			for _,s in ipairs(searchResults) do
				tinsert(finalized, s);
			end
		end
		-- if app.DEBUG_PRINT then print("Forced Finalize",o.key,o.key and o[o.key],#finalized) end

		-- If we had any finalized search results, then clone all the records, store the results, and return them
		if #finalized > 0 then
			local cloned = {};
			MergeObjects(cloned, finalized, true);
			-- if app.DEBUG_PRINT then print("Symbolic Link for", o.key,o.key and o[o.key], "contains", #cloned, "values after filtering.") end
			-- if any symlinks are left at the lowest level, go ahead and fill them
			-- Apply any modID if necessary
			if FinalizeModID then
				-- app.PrintDebug("Applying FinalizeModID",FinalizeModID)
				for _,s in ipairs(cloned) do
					if s.itemID then
						s.modID = FinalizeModID;
					end
					-- in symlinking a Thing to another Source, we are effectively declaring that it is Sourced within this Source, for the specific scope
					s.sourceParent = nil;
					s.parent = nil;
					-- if somehow the symlink pulls in the same item as used as the source of the symlink, then skip putting it in the final group
					if s.hash and s.hash == o.hash then
						print("Symlink group pulled itself into finalized results!",o.hash)
					else
						FillSymLinks(s);
					end
				end
			else
				for _,s in ipairs(cloned) do
					-- in symlinking a Thing to another Source, we are effectively declaring that it is Sourced within this Source, for the specific scope
					s.sourceParent = nil;
					s.parent = nil;
					-- if somehow the symlink pulls in the same item as used as the source of the symlink, then skip putting it in the final group
					if s.hash and s.hash == o.hash then
						print("Symlink group pulled itself into finalized results!",o.hash)
					else
						FillSymLinks(s);
					end
				end
			end
			if o.key and app.ThingKeys[o.key] then
				-- global resolve cache if it's a 'Thing'
				-- app.PrintDebug("Thing Results",o.hash)
				ResolveCache[o.hash] = cloned;
			elseif o.key ~= false then
				-- otherwise can store it in the object itself (like a header from the Main list with symlink), if it's not specifically a pseudo-symlink resolve group
				o.resolved = cloned;
				-- app.PrintDebug("Object Results",o.hash)
			end
			return cloned;
		else
			-- if app.DEBUG_PRINT then print("Symbolic Link for ", o.key, " ",o.key and o[o.key], " contained no values after filtering.") end
		end
	end
end

local function ResolveSymlinkGroupAsync(group)
	-- app.PrintDebug("RSGa",group.hash)
	local groups = ResolveSymbolicLink(group);
	if groups then
		PriorityNestObjects(group, groups, nil, app.RecursiveGroupRequirementsFilter);
		group.sym = nil;
		-- app.PrintDebug("RSGa",group.g and #group.g,group.hash)
		-- newly added group data needs to be checked again for further content to fill, since it will not have been recursively checked
		-- on the initial pass due to the async nature
		app.FillGroups(group);
		BuildGroups(group);
		-- auto-expand the symlink group
		ExpandGroupsRecursively(group, true);
		app.DirectGroupUpdate(group);
	end
end
-- Fills the symlinks within a group by using an 'async' process to spread the filler function over multiple game frames to reduce stutter or apparent lag
app.FillSymlinkAsync = function(o)
	app.FunctionRunner.Run(ResolveSymlinkGroupAsync, o);
end
end)();

local function BuildContainsInfo(item, entries, indent, layer)
	if item and item.g then
		for i,group in ipairs(item.g) do
			-- If there's progress to display, then let's summarize a bit better.
			if group.visible then
				-- Insert into the display.
				-- app.PrintDebug("INCLUDE",app.DEBUG_PRINT,GetProgressTextForRow(group),group.hash,group.key,group.key and group[group.key])
				local o = { group = group, right = GetProgressTextForRow(group) };
				local indicator = app.GetIndicatorIcon(group);
				o.prefix = indicator and (string.sub(indent, 4) .. "|T" .. indicator .. ":0|t ") or indent;
				tinsert(entries, o);

				-- Only go down one more level.
				if layer < 4
					-- if there are sub groups
					and group.g and #group.g > 0
					-- not for things with a parent unless the parent has no difficultyID
					and (not group.parent or not group.parent.difficultyID)
					then
					BuildContainsInfo(group, entries, indent .. "  ", layer + 1);
				end
			-- else
			-- 	if app.DEBUG_PRINT then print("EXCLUDE",app.DEBUG_PRINT,GetProgressTextForRow(group),group.hash,group.key,group.key and group[group.key]) end
			end
		end
	end
end
-- Fields on groups which can be utilized in tooltips to show additional Source location info for that group (by order of priority)
app.TooltipSourceFields = {
	"professionID",
	"mapID",
	"maps",
	"instanceID",
	"npcID",
	"questID"
};
local function GetCachedSearchResults(search, method, paramA, paramB, ...)
	-- app.PrintDebug("GetCachedSearchResults",search,method,paramA,paramB,...)
	if not search or search:find("%[]") then return; end
	local cache = searchCache[search];
	if cache then return cache; end

	-- This method can be called nested, and some logic should only process for the initial call
	local topLevelSearch;
	if not app.InitialCachedSearch then
		-- app.PrintDebug("TopLevelSearch",paramA,paramB,...)
		app.InitialCachedSearch = search;
		topLevelSearch = true;
	end

	-- Determine if this tooltip needs more work the next time it refreshes.
	if not paramA then paramA = ""; end
	local working, info = false, {};

	-- Call to the method to search the database.
	local rawlink;
	-- Store the raw search link if no paramB
	if paramB then paramB = tonumber(paramB);
	else rawlink = paramA; end
	local group, a, b = method(paramA, paramB, ...);
	-- app.PrintDebug("Raw Search",search,a,b,group and #group, ...);
	if not group then group = {}; end
	if a then paramA = a; end
	if b then paramB = b; end

	-- Clean results which are cached under 'Source Ignored' content since they've been copied from another Source and we don't care about them in search results
	group = app.CleanSourceIgnoredGroups(group);
	-- app.PrintDebug("Removed Source Ignored",#group)

	-- For Creatures and Encounters that are inside of an instance, we only want the data relevant for the instance + difficulty.
	if paramA == "creatureID" or paramA == "encounterID" then
		if group and #group > 0 then
			local difficultyID = (IsInInstance() and select(3, GetInstanceInfo())) or (paramA == "encounterID" and EJ_GetDifficulty()) or 0;
			-- print("difficultyID",difficultyID,"params",paramA,paramB)
			if difficultyID > 0 then
				local subgroup = {};
				for _,j in ipairs(group) do
					-- print("Check",j.hash,GetRelativeValue(j, "difficultyID"))
					if GetRelativeDifficulty(j, difficultyID) then
						-- print("Match Difficulty")
						tinsert(subgroup, j);
					end
				end
				group = subgroup;
			end
		end
	elseif paramA == "achievementID" then
		local regroup = {};
		local criteriaID = ...;
		for i,j in ipairs(group) do
			if j.criteriaID == criteriaID then
				-- Don't do anything for things linked to maps/with no parents since it will show everything from the map in the tooltip...
				if j.mapID or not j.parent or not j.parent.parent then
					tinsert(regroup, setmetatable({["g"] = {}}, { __index = j }));
				else
					tinsert(regroup, j);
				end
			end
		end
		group = regroup;
	elseif paramA == "azeriteEssenceID" then
		local regroup = {};
		local rank = ...;
		if app.MODE_ACCOUNT then
			for i,j in ipairs(group) do
				if j.rank == rank and app.RecursiveUnobtainableFilter(j) then
					if j.mapID or j.parent == nil or j.parent.parent == nil then
						tinsert(regroup, setmetatable({["g"] = {}}, { __index = j }));
					else
						tinsert(regroup, j);
					end
				end
			end
		else
			for i,j in ipairs(group) do
				if j.rank == rank and app.RecursiveClassAndRaceFilter(j) and app.RecursiveUnobtainableFilter(j) and app.RecursiveGroupRequirementsFilter(j) then
					if j.mapID or j.parent == nil or j.parent.parent == nil then
						tinsert(regroup, setmetatable({["g"] = {}}, { __index = j }));
					else
						tinsert(regroup, j);
					end
				end
			end
		end

		group = regroup;
	elseif paramA == "titleID" then
		-- Don't do anything
		local regroup = {};
		if app.MODE_ACCOUNT then
			for i,j in ipairs(group) do
				if app.RecursiveUnobtainableFilter(j) then
					tinsert(regroup, setmetatable({["g"] = {}}, { __index = j }));
				end
			end
		else
			for i,j in ipairs(group) do
				if app.RecursiveClassAndRaceFilter(j) and app.RecursiveUnobtainableFilter(j) and app.RecursiveGroupRequirementsFilter(j) then
					tinsert(regroup, setmetatable({["g"] = {}}, { __index = j }));
				end
			end
		end

		group = regroup;
	elseif paramA == "followerID" then
		-- Don't do anything
		local regroup = {};
		if app.MODE_ACCOUNT then
			for i,j in ipairs(group) do
				if app.RecursiveUnobtainableFilter(j) then
					tinsert(regroup, setmetatable({["g"] = {}}, { __index = j }));
				end
			end
		else
			for i,j in ipairs(group) do
				if app.RecursiveClassAndRaceFilter(j) and app.RecursiveUnobtainableFilter(j) and app.RecursiveGroupRequirementsFilter(j) then
					tinsert(regroup, setmetatable({["g"] = {}}, { __index = j }));
				end
			end
		end

		group = regroup;
	else
		-- Determine if this is a cache for an item
		local itemID, sourceID, modID, bonusID, itemString;
		if not paramB then
			itemString = string.match(paramA, "item[%-?%d:]+");
			if itemString then
				sourceID = GetSourceID(paramA);
				-- print("ParamA SourceID",sourceID,paramA)
				if topLevelSearch and app.Settings:GetTooltipSetting("itemString") then tinsert(info, { left = itemString }); end
				local _, itemID2, enchantId, gemId1, gemId2, gemId3, gemId4, suffixId, uniqueId, linkLevel, specializationID, upgradeId, linkModID, numBonusIds, bonusID1 = strsplit(":", itemString);
				if itemID2 then
					itemID = tonumber(itemID2);
					modID = tonumber(linkModID) or 0;
					if modID == 0 then modID = nil; end
					bonusID = (tonumber(numBonusIds) or 0) > 0 and tonumber(bonusID1) or 3524;
					if bonusID == 3524 then bonusID = nil; end
					paramA = "itemID";
					paramB = GetGroupItemIDWithModID(nil, itemID, modID, bonusID) or itemID;
				end
				if #group > 0 then
					for i,j in ipairs(group) do
						if j.modItemID == paramB then
							if j.u and j.u == 2 and (not app.IsBoP(j)) and (tonumber(numBonusIds) or 0) > 0 then
								if topLevelSearch then tinsert(info, { left = L["RECENTLY_MADE_OBTAINABLE"] }); end
							end
						end
					end
				end
			else
				local kind, id = strsplit(":", paramA);
				kind = string_lower(kind);
				if id then id = tonumber(id); end
				if kind == "itemid" then
					paramA = "itemID";
					paramB = id;
					itemID = id;
				elseif kind == "questid" then
					paramA = "questID";
					paramB = id;
				elseif kind == "creatureid" or kind == "npcid" then
					paramA = "creatureID";
					paramB = id;
				elseif kind == "achievementid" then
					paramA = "achievementID";
					paramB = id;
				end
			end
		elseif paramA == "itemID" then
			-- itemID should only be the itemID, not including modID
			itemID = GetItemIDAndModID(paramB) or paramB;
		end

		if itemID then
			-- Merge the source group for all matching Sources of the search results
			local sourceGroup;
			for i,j in ipairs(group.g or group) do
				-- app.PrintDebug("sourceGroup?",j.key,j.key and j[j.key],j.modItemID)
				if sourceID and GroupMatchesParams(j, "s", sourceID) then
					-- app.PrintDebug("sourceID match",sourceID)
					if sourceGroup then MergeProperties(sourceGroup, j)
					else sourceGroup = CreateObject(j); end
				elseif GroupMatchesParams(j, paramA, paramB) then
					-- app.PrintDebug("exact match",paramA,paramB)
					if sourceGroup then MergeProperties(sourceGroup, j, true)
					else sourceGroup = CreateObject(j); end
				elseif GroupMatchesParams(j, paramA, paramB, true) then
					-- app.PrintDebug("match",paramA,paramB)
					if sourceGroup then MergeProperties(sourceGroup, j, true)
					else sourceGroup = CreateObject(j); end
				end
			end

			if not sourceGroup then sourceGroup = {}; end
			-- Show the unobtainable source text, if necessary.
			if sourceGroup.key then
				-- Acquire the SourceID if it hadn't been determined yet.
				if not sourceID and sourceGroup.link then
					sourceID = GetSourceID(sourceGroup.link) or sourceGroup.s;
				end
			else
				sourceGroup.missing = true;
			end

			if topLevelSearch then
				if sourceID then
					local sourceInfo = C_TransmogCollection_GetSourceInfo(sourceID);
					if sourceInfo and (sourceInfo.quality or 0) > 1 then
						local allVisualSources = C_TransmogCollection_GetAllAppearanceSources(sourceInfo.visualID) or app.EmptyTable;
						if #allVisualSources < 1 then
							-- Items with SourceInfo which don't register as having any visual data...
							-- This typically happens on Items which can have a collectible SourceID, but not usable for Transmog
							tinsert(info, 1, { left = L["FORCE_REFRESH_REQUIRED"], wrap = true, color = app.Colors.TooltipDescription });
						end
						if app.Settings:GetTooltipSetting("SharedAppearances") then
							local text;
							if app.Settings:GetTooltipSetting("OnlyShowRelevantSharedAppearances") then
								-- The user doesn't want to see Shared Appearances that don't match the item's requirements.
								for i,otherSourceID in ipairs(allVisualSources) do
									if otherSourceID == sourceID and not sourceGroup.missing then
										if app.Settings:GetTooltipSetting("IncludeOriginalSource") then
											local link = sourceGroup.link or sourceGroup.silentLink;
											if not link then
												link = RETRIEVING_DATA;
												working = true;
											end
											if sourceGroup.u then
												local texture = GetUnobtainableTexture(sourceGroup);
												if texture then
													text = "|T" .. texture .. ":0|t";
												else
													text = "   ";
												end
											else
												text = "   ";
											end
											tinsert(info, { left = text .. link .. (app.Settings:GetTooltipSetting("itemID") and " (*)" or ""), right = GetCollectionIcon(ATTAccountWideData.Sources[sourceID])});
										end
									else
										local otherATTSource = app.SearchForObject("s", otherSourceID);
										if otherATTSource then
											-- Only show Shared Appearances that match the requirements for this class to prevent people from assuming things.
											if (sourceGroup.f == otherATTSource.f or sourceGroup.f == 2 or otherATTSource.f == 2) and not otherATTSource.nmc and not otherATTSource.nmr then
												local link = otherATTSource.link or otherATTSource.silentLink;
												local otherItemID = otherATTSource.modItemID or otherATTSource.itemID or otherATTSource.silentItemID;
												if not link then
													link = RETRIEVING_DATA;
													working = true;
												end
												if otherATTSource.u then
													local texture = GetUnobtainableTexture(otherATTSource);
													if texture then
														text = "|T" .. texture .. ":0|t";
													else
														text = "   ";
													end
												else
													text = "   ";
												end
												tinsert(info, { left = text .. link .. (app.Settings:GetTooltipSetting("itemID") and (" (" .. (otherItemID or "???") .. ")") or ""), right = GetCollectionIcon(otherATTSource.collected)});
											end
										else
											local otherSource = C_TransmogCollection_GetSourceInfo(otherSourceID);
											if otherSource then
												local link = select(2, GetItemInfo(otherSource.itemID));
												if not link then
													link = RETRIEVING_DATA;
													working = true;
												end
												text = " |CFFFF0000!|r " .. link .. (app.Settings:GetTooltipSetting("itemID") and (" (" .. (otherSourceID == sourceID and "*" or otherSource.itemID or "???") .. ")") or "");
												if otherSource.isCollected then ATTAccountWideData.Sources[otherSourceID] = 1; end
												tinsert(info, { left = text	.. " |CFFFF0000(" .. (link == RETRIEVING_DATA and "INVALID BLIZZARD DATA " or "MISSING IN ATT ") .. otherSourceID .. ")|r", right = GetCollectionIcon(otherSource.isCollected)});	-- This is debug info for contribs, do not localize it
											end
										end
									end
								end
							else
								-- This is where we need to calculate the requirements differently because Unique Mode users are extremely frustrating.
								for i,otherSourceID in ipairs(allVisualSources) do
									if otherSourceID == sourceID and not sourceGroup.missing then
										if app.Settings:GetTooltipSetting("IncludeOriginalSource") then
											local link = sourceGroup.link or sourceGroup.silentLink;
											if not link then
												link = RETRIEVING_DATA;
												working = true;
											end
											if sourceGroup.u then
												local texture = GetUnobtainableTexture(sourceGroup);
												if texture then
													text = "|T" .. texture .. ":0|t";
												else
													text = "   ";
												end
											else
												text = "   ";
											end
											tinsert(info, { left = text .. link .. (app.Settings:GetTooltipSetting("itemID") and " (*)" or ""), right = GetCollectionIcon(ATTAccountWideData.Sources[sourceID])});
										end
									else
										local otherATTSource = app.SearchForObject("s", otherSourceID);
										if otherATTSource then
											-- Show information about the appearance:
											local failText = "";
											local link = otherATTSource.link or otherATTSource.silentLink;
											if not link then
												link = RETRIEVING_DATA;
												working = true;
											end
											if otherATTSource.u then
												local texture = GetUnobtainableTexture(otherATTSource);
												if texture then
													text = "|T" .. texture .. ":0|t";
												else
													text = "   ";
												end
											else
												text = "   ";
											end
											local otherItemID = otherATTSource.modItemID or otherATTSource.itemID or otherATTSource.silentItemID;
											text = text .. link .. (app.Settings:GetTooltipSetting("itemID") and (" (" .. (otherItemID or "???") .. ")") or "");

											-- Show all of the reasons why an appearance does not meet given criteria.
											-- Only show Shared Appearances that match the requirements for this class to prevent people from assuming things.
											if sourceGroup.f ~= otherATTSource.f then
												-- This is NOT the same type. Therefore, no credit for you!
												if #failText > 0 then failText = failText .. ", "; end
												failText = failText .. (L["FILTER_ID_TYPES"][otherATTSource.f] or "???");
											elseif otherATTSource.nmc then
												-- This is NOT for your class. Therefore, no credit for you!
												if #failText > 0 then failText = failText .. ", "; end
												-- failText = failText .. "Class Locked";
												for i,classID in ipairs(otherATTSource.c) do
													if i > 1 then failText = failText .. ", "; end
													failText = failText .. (GetClassInfo(classID) or "???");
												end
											elseif otherATTSource.nmr then
												-- This is NOT for your race. Therefore, no credit for you!
												if #failText > 1 then failText = failText .. ", "; end
												failText = failText .. L["RACE_LOCKED"];
											else
												-- Should be fine
											end

											if #failText > 0 then text = text .. " |CFFFF0000(" .. failText .. ")|r"; end
											tinsert(info, { left = text, right = GetCollectionIcon(otherATTSource.collected)});
										else
											local otherSource = C_TransmogCollection_GetSourceInfo(otherSourceID);
											if otherSource and (otherSource.quality or 0) > 1 then
												local link = select(2, GetItemInfo(otherSource.itemID));
												if not link then
													link = RETRIEVING_DATA;
													working = true;
												end
												text = " |CFFFF0000!|r " .. link .. (app.Settings:GetTooltipSetting("itemID") and (" (" .. (otherSourceID == sourceID and "*" or otherSource.itemID or "???") .. ")") or "");
												if otherSource.isCollected then ATTAccountWideData.Sources[otherSourceID] = 1; end
												tinsert(info, { left = text	.. " |CFFFF0000(" .. (link == RETRIEVING_DATA and "INVALID BLIZZARD DATA " or "MISSING IN ATT ") .. otherSourceID .. ")|r", right = GetCollectionIcon(otherSource.isCollected)});	-- This is debug info for contribs, do not localize it
											end
										end
									end
								end
							end
						end

						-- Special case to double-check VisualID collection in Unique/Main modes because blizzard doesn't return consistent data
						-- non-collected SourceID, non-collected* for Account, and in Unique Mode
						if not sourceInfo.isCollected and not rawget(ATTAccountWideData.Sources, sourceID) and not app.Settings:Get("Completionist") then
							local collected = app.ItemSourceFilter(sourceInfo);
							if collected then
								-- if this is true here, that means C_TransmogCollection_GetAllAppearanceSources() for this SourceID's VisualID
								-- does not return this SourceID, so it doesn't get flagged by the refresh logic and we need to track it manually for
								-- this Account as being 'collected'
								if topLevelSearch then tinsert(info, { left = Colorize(L["ADHOC_UNIQUE_COLLECTED_INFO"], app.Colors.ChatLinkError) }); end
								-- if the tooltip immediately refreshes for whatever reason the
								-- store this SourceID as being collected* so it can be properly collected* during force refreshes in the future without requiring a tooltip search
								if not ATTAccountWideData.BrokenUniqueSources then ATTAccountWideData.BrokenUniqueSources = {}; end
								local uniqueSources = ATTAccountWideData.BrokenUniqueSources;
								rawset(uniqueSources, sourceID, 1);
							end
						end

						if app.IsReady and sourceGroup.missing and itemID ~= 53097 then
							tinsert(info, { left = Colorize("Item Source not found in the " .. app.Version .. " database.\n" .. L["SOURCE_ID_MISSING"], app.Colors.ChatLinkError) });	-- Do not localize first part of the message, it is for contribs
							tinsert(info, { left = Colorize(sourceID .. ":" .. tostring(sourceInfo.visualID), app.Colors.SourceIgnored) });
							tinsert(info, { left = Colorize(itemString, app.Colors.SourceIgnored) });
						end
						if app.Settings:GetTooltipSetting("visualID") then tinsert(info, { left = L["VISUAL_ID"], right = tostring(sourceInfo.visualID) }); end
						if app.Settings:GetTooltipSetting("sourceID") then tinsert(info, { left = L["SOURCE_ID"], right = sourceID .. " " .. GetCollectionIcon(sourceInfo.isCollected) }); end
					end
				end

				if app.Settings:GetTooltipSetting("itemID") then tinsert(info, { left = L["ITEM_ID"], right = tostring(itemID) }); end
				if modID and app.Settings:GetTooltipSetting("modID") then tinsert(info, { left = "Mod ID", right = tostring(modID) }); end
				if bonusID and app.Settings:GetTooltipSetting("bonusID") then tinsert(info, { left = "Bonus ID", right = tostring(bonusID) }); end
				if app.Settings:GetTooltipSetting("SpecializationRequirements") then
					local specs = GetFixedItemSpecInfo(itemID);
					-- specs is already filtered/sorted to only current class
					if specs and #specs > 0 then
						tinsert(info, { right = GetSpecsString(specs, true, true) });
					elseif sourceID then
						tinsert(info, { right = L["NOT_AVAILABLE_IN_PL"] });
					end
				end

				if app.Settings:GetTooltipSetting("Progress") and IsArtifactRelicItem(itemID) then
					-- If the item is a relic, then let's compare against equipped relics.
					local relicType = select(3, C_ArtifactUI.GetRelicInfoByItemID(itemID));
					local myArtifactData = app.CurrentCharacter.ArtifactRelicItemLevels;
					if myArtifactData then
						local progress, total = 0, 0;
						local relicItemLevel = select(1, GetDetailedItemLevelInfo(search)) or 0;
						for relicID,artifactData in pairs(myArtifactData) do
							local infoString;
							for relicSlotIndex,relicData in pairs(artifactData) do
								if relicData.relicType == relicType then
									if infoString then
										infoString = infoString .. " | " .. relicData.iLvl;
									else
										infoString = relicData.iLvl;
									end
									total = total + 1;
									if relicData.iLvl >= relicItemLevel then
										progress = progress + 1;
										infoString = infoString .. " " .. GetCompletionIcon(1);
									else
										infoString = infoString .. " " .. GetCompletionIcon();
									end
								end
							end
							if infoString then
								local itemLink = select(2, GetItemInfo(relicID));
								tinsert(info, 1, {
									left = itemLink and ("   " .. itemLink) or RETRIEVING_DATA,
									right = L["iLvl"] .. " " .. infoString,
								});
							end
						end
						if total > 0 then
							tinsert(group, { itemID=itemID, total=total, progress=progress});
							tinsert(info, 1, { left = L["ARTIFACT_RELIC_COMPLETION"], right = L[progress == total and "TRADEABLE" or "NOT_TRADEABLE"] });
						end
					else
						tinsert(info, 1, { left = L["ARTIFACT_RELIC_CACHE"], wrap = true, color = app.Colors.TooltipDescription });
					end
				end
			end
		end
	end

	-- Create a list of sources
	-- app.PrintDebug("SourceLocations?",topLevelSearch,app.Settings:GetTooltipSetting("SourceLocations"),paramA,app.Settings:GetTooltipSetting(paramA == "creatureID" and "SourceLocations:Creatures" or "SourceLocations:Things"))
	if topLevelSearch and app.Settings:GetTooltipSetting("SourceLocations") and (not paramA or (paramA ~= "encounterID" and app.Settings:GetTooltipSetting(paramA == "creatureID" and "SourceLocations:Creatures" or "SourceLocations:Things"))) then
		local temp, text, parent = {};
		local unfiltered, uTexture = {};
		local showUnsorted = app.Settings:GetTooltipSetting("SourceLocations:Unsorted");
		local showCompleted = app.Settings:GetTooltipSetting("SourceLocations:Completed");
		local wrap = app.Settings:GetTooltipSetting("SourceLocations:Wrapping");
		local abbrevs = L["ABBREVIATIONS"];
		for _,j in ipairs(group.g or group) do
			parent = j.parent;
			-- app.PrintDebug("SourceLine?",parent and parent.hash,parent and parent.hideText,parent and parent.parent,app.IsComplete(j),app.HasCost(j, paramA, paramB))
			if parent and not parent.hideText and parent.parent
				and (showCompleted or not app.IsComplete(j))
				and not app.HasCost(j, paramA, paramB)
				then
				text = BuildSourceText(paramA ~= "itemID" and parent or j, paramA ~= "itemID" and 1 or 0);
				if showUnsorted or (not string.match(text, L["UNSORTED_1"]) and not string.match(text, L["HIDDEN_QUEST_TRIGGERS"])) then
					for source,replacement in pairs(abbrevs) do
						text = string.gsub(text, source, replacement);
					end
					-- doesn't meet current unobtainable filters
					if not app.RecursiveUnobtainableFilter(j) then
						tinsert(unfiltered, text .. " |TInterface\\FriendsFrame\\StatusIcon-DnD:0|t");
					-- from obtainable, different character source
					elseif not app.RecursiveClassAndRaceFilter(j) then
						tinsert(temp, text .. " |TInterface\\FriendsFrame\\StatusIcon-Away:0|t");
					else
						-- check if this needs an unobtainable icon even though it's being shown
						uTexture = GetUnobtainableTexture(j.u or app.RecursiveFirstParentWithField(parent, "u"));
						-- add the texture to the source line
						if uTexture then
							text = text .. " |T" .. uTexture .. ":0|t";
						end
						tinsert(temp, text);
					end
				end
			end
		end
		-- if in Debug or no sources visible, add any unfiltered sources
		if app.MODE_DEBUG or (#temp < 1 and not (paramA == "creatureID" or paramA == "encounterID")) then
			for _,j in ipairs(unfiltered) do
				tinsert(temp, j);
			end
		end
		if #temp > 0 then
			local listing = {};
			local maximum = app.Settings:GetTooltipSetting("Locations");
			app.Sort(temp, app.SortDefaults.Text);
			for i,j in ipairs(temp) do
				if not contains(listing, j) then
					tinsert(listing, 1, j);
				end
			end
			local count = #listing;
			if count > maximum + 1 then
				for i=count,maximum + 1,-1 do
					table.remove(listing, 1);
				end
				tinsert(listing, 1, L["AND_"] .. (count - maximum) .. L["_OTHER_SOURCES"] .. "...");
			end
			for i,text in ipairs(listing) do
				if not working and text:find(RETRIEVING_DATA) then working = true; end
				local left, right = strsplit(DESCRIPTION_SEPARATOR, text);
				tinsert(info, 1, { left = left, right = right, wrap = wrap });
			end
		end
	end

	-- Create clones of the search results
	if not group.g then
		-- Clone all the groups so that things don't get modified in the Source
		local cloned = {};
		local clearSourceParent = #group > 1;
		for _,o in ipairs(group) do
			tinsert(cloned, CreateObject(o));
		end
		-- replace the Source references with the cloned references
		group = cloned;
		-- Find or Create the root group for the search results, and capture the results which need to be nested instead
		local root;
		local nested = {};
		-- app.PrintDebug("Find Root for",paramA,paramB,"#group",group and #group);
		-- check for Item groups in a special way to account for extra ID's
		if paramA == "itemID" then
			local refinedMatches = app.GroupBestMatchingItems(group, paramB);
			if refinedMatches then
				-- move from depth 3 to depth 1 to find the set of items which best matches for the root
				for depth=3,1,-1 do
					if refinedMatches[depth] then
						-- print("refined",depth,#refinedMatches[depth])
						if not root then
							for _,o in ipairs(refinedMatches[depth]) do
								-- object meets filter criteria and is exactly what is being searched
								if app.RecursiveGroupRequirementsFilter(o) then
									-- print("filtered root");
									if root then
										local otherRoot = root;
										-- print("replace root",otherRoot.key,otherRoot[otherRoot.key]);
										root = o;
										MergeProperties(root, otherRoot);
										-- previous root content will be nested after
										if otherRoot.g then
											MergeObjects(nested, otherRoot.g);
										end
									else
										root = o;
									end
								else
									-- print("unfiltered root",o.key,o[o.key],o.modItemID,paramB);
									if root then MergeProperties(root, o, true);
									else root = o; end
								end
							end
						else
							for _,o in ipairs(refinedMatches[depth]) do
								-- Not accurate matched enough to be the root, so it will be nested
								-- print("nested")
								tinsert(nested, o);
							end
						end
					end
				end
			end
		else
			for _,o in ipairs(group) do
				-- If the obj "is" the root obj
				-- print(o.key,o[o.key],o.modItemID,"=parent>",o.parent and o.parent.key,o.parent and o.parent.key and o.parent[o.parent.key]);
				if GroupMatchesParams(o, paramA, paramB) then
					-- object meets filter criteria and is exactly what is being searched
					if app.RecursiveGroupRequirementsFilter(o) then
						-- print("filtered root");
						if root then
							local otherRoot = root;
							-- print("replace root",otherRoot.key,otherRoot[otherRoot.key]);
							root = o;
							MergeProperties(root, otherRoot);
							-- previous root content will be nested after
							if otherRoot.g then
								MergeObjects(nested, otherRoot.g);
							end
						else
							root = o;
						end
					else
						-- print("unfiltered root",o.key,o[o.key],o.modItemID,paramB);
						if root then MergeProperties(root, o, true);
						else root = o; end
					end
				else
					-- Not the root, so it will be nested
					-- print("nested")
					tinsert(nested, o);
				end
			end
		end
		if not root then
			-- app.PrintDebug("Create New Root",paramA,paramB)
			root = CreateObject({ [paramA] = paramB });
		end
		-- If rawLink exists, import it into the root
		if rawlink then
			app.ImportRawLink(root, rawlink);
		end
		-- Ensure the param values are consistent with the new root object values (basically only affects creatureID)
		paramA, paramB = root.key, root[root.key];
		-- Special Case for itemID, need to use the modItemID for accuracy in item matching
		if paramA == "itemID" then
			paramB = root.modItemID or paramB;
		end
		-- app.PrintDebug("Root",root.key,root[root.key],root.modItemID);
		-- app.PrintTable(root)
		-- app.PrintDebug("Root Collect",root.collectible,root.collected);
		-- app.PrintDebug("params",paramA,paramB);
		-- app.PrintDebug(#nested,"Nested total");
		-- Nest the objects by matching filter priority if it's not a currency
		if paramA ~= "currencyID" then
			PriorityNestObjects(root, nested, nil, app.RecursiveGroupRequirementsFilter);
		else
			-- do roughly the same logic for currency, but will not add the skipped objects afterwards
			local added = {};
			for i,o in ipairs(nested) do
				-- If the obj meets the recursive group filter
				if app.RecursiveGroupRequirementsFilter(o) then
					-- Merge the obj into the merged results
					-- print("Merge object",o.key,o[o.key])
					tinsert(added, o);
				end
			end
			-- Nest the added objects
			NestObjects(root, added);
		end

		-- if not root.key then
		-- 	app.PrintDebug("UNKNOWN ROOT GROUP",paramA,paramB)
		-- 	app.PrintTable(root)
		-- end

		-- Single group which matches the root, then collapse it
		-- This could only happen if a Thing is literally listed underneath itself...
		if root.g and #root.g == 1 then
			local o = root.g[1];
			-- if not o.key then
			-- 	app.PrintDebug("UNKNOWN OBJECT GROUP",paramA,paramB)
			-- 	app.PrintTable(o)
			-- end
			if o.key then
				-- print("Check Single",root.key,root.key and root[root.key],o.key and root[o.key],o.key,o.key and o[o.key],root.key and o[root.key])
				-- Heroic Tusks of Mannoroth triggers this logic
				if (root[o.key] == o[o.key]) or (root[root.key] == o[root.key]) then
					-- print("Single group")
					root.g = nil;
					MergeProperties(root, o, true);
				end
			end
		end

		-- Replace as the group
		group = root;
		-- Ensure no weird parent references attached to the base search result if there were multiple search results
		group.parent = nil;
		if clearSourceParent then
			group.sourceParent = nil;
		end

		-- app.PrintDebug(group.g and #group.g,"Merge total");
		-- app.PrintDebug("Final Group",group.key,group[group.key],group.collectible,group.collected,group.parent,group.sourceParent,rawget(group, "parent"),rawget(group, "sourceParent"));
		-- app.PrintDebug("Group Type",group.__type)

		-- Special cases
		-- Don't show nested criteria of achievements (unless loading popout/row content)
		if group.g and group.key == "achievementID" and app.SetSkipPurchases() < 2 then
			local noCrits = {};
			-- print("achieve group",#group.g)
			for i=1,#group.g do
				if group.g[i].key ~= "criteriaID" then
					tinsert(noCrits, group.g[i]);
				end
			end
			group.g = noCrits;
			-- print("achieve nocrits",#group.g)
		end

		-- Resolve Cost, but not if the search itself was skipped (Mark of Honor)
		if method ~= app.EmptyFunction then
			-- Fill up the group
			app.FillGroups(group);
			-- Sort by the heirarchy of the group
			app.Sort(group.g, app.SortDefaults.Hierarchy, true);
		end

		-- Only need to build/update groups from the top level
		if topLevelSearch then
			BuildGroups(group, group.g);
			app.TopLevelUpdateGroup(group);
		end
	-- delete sub-groups if there are none
	elseif #group.g == 0 then
		group.g = nil;
	end

	if topLevelSearch then
		-- Add various text to the group now that it has been consolidated from all sources
		if group.isLimited then
			tinsert(info, 1, { left = L.LIMITED_QUANTITY, wrap = false, color = app.Colors.TooltipDescription });
		end
		-- Description for Items
		if group.lore and app.Settings:GetTooltipSetting("Lore") then
			tinsert(info, 1, { left = group.lore, wrap = true, color = app.Colors.TooltipLore });
		end
		if group.description and app.Settings:GetTooltipSetting("Descriptions") then
			tinsert(info, 1, { left = group.description, wrap = true, color = app.Colors.TooltipDescription });
		end
		if group.rwp then
			tinsert(info, 1, { left = GetRemovedWithPatchString(group.rwp), wrap = true, color = app.Colors.RemovedWithPatch });
		end
		if group.awp then
			tinsert(info, 1, { left = GetAddedWithPatchString(group.awp), wrap = true, color = app.Colors.AddedWithPatch });
		end
		if group.u and (not group.crs or group.itemID or group.s) then
			tinsert(info, { left = L["UNOBTAINABLE_ITEM_REASONS"][group.u][2], wrap = true });
		end
		-- an item used for a faction which is repeatable
		if group.itemID and group.factionID and group.repeatable then
			tinsert(info, { left = L["ITEM_GIVES_REP"] .. (select(1, GetFactionInfoByID(group.factionID)) or ("Faction #" .. tostring(group.factionID))) .. "'", wrap = true, color = app.Colors.TooltipDescription });
		end
		-- Pet Battles
		if group.pb then
			tinsert(info, { left = L["REQUIRES_PETBATTLES"] });
		end
		-- PvP
		if group.pvp then
			tinsert(info, { left = L["REQUIRES_PVP"] });
		end
		if paramA == "itemID" and paramB == 137642 then
			if app.Settings:GetTooltipSetting("SummarizeThings") then
				tinsert(info, 1, { left = L["MARKS_OF_HONOR_DESC"], color = app.Colors.SourceIgnored });
			end
		end

		if group.g and app.Settings:GetTooltipSetting("SummarizeThings") then
			-- app.PrintDebug("SummarizeThings",group.hash,group.g and #group.g)
			local entries = {};
			-- app.DEBUG_PRINT = "CONTAINS-"..group.hash;
			BuildContainsInfo(group, entries, "  ", app.noDepth and 99 or 1);
			-- app.DEBUG_PRINT = nil;
			-- app.PrintDebug(entries and #entries,"contains entries")
			if #entries > 0 then
				local left, right;
				local tooltipSourceFields = app.TooltipSourceFields;
				tinsert(info, { left = L["CONTAINS"] });
				local containCount, item, entry = math.min(app.Settings:GetTooltipSetting("ContainsCount") or 25, #entries);
				local RecursiveParentField, SearchForObject = app.RecursiveFirstParentWithField, app.SearchForObject;
				for i=1,containCount do
					item = entries[i];
					entry = item.group;
					left = entry.text or RETRIEVING_DATA;
					if not working and (left == RETRIEVING_DATA or left:find("%[]")) then working = true; end

					-- If this entry has a specific Class requirement and is not itself a 'Class' header, tack that on as well
					if entry.c and entry.key ~= "classID" and #entry.c == 1 then
						local class = GetClassInfo(entry.c[1]);
						left = left .. " [" .. app.TryColorizeName(entry, class) .. "]";
					end
					if entry.icon then item.prefix = item.prefix .. "|T" .. entry.icon .. ":0|t "; end

					-- If this entry has specialization requirements, let's attempt to show the specialization icons.
					right = item.right;
					local specs = entry.specs;
					if specs and #specs > 0 then
						right = GetSpecsString(specs, false, false) .. right;
					end

					-- If this entry has customCollect requirements, list them for clarity
					if entry.customCollect then
						for i,c in ipairs(entry.customCollect) do
							local icon_color_str = L["CUSTOM_COLLECTS_REASONS"][c]["icon"].." |c"..L["CUSTOM_COLLECTS_REASONS"][c]["color"]..L["CUSTOM_COLLECTS_REASONS"][c]["text"];
							if i > 1 then
								right = icon_color_str .. " / " .. right;
							else
								right = icon_color_str .. "  " .. right;
							end
						end
					end

					-- If this entry is an Item, show additional Source information for that Item (since it needs to be acquired in a specific location most-likely)
					if entry.itemID and paramA ~= "npcID" and paramA ~= "encounterID" then
						-- Add the Zone name
						local field, id;
						for _,v in ipairs(tooltipSourceFields) do
							id = RecursiveParentField(entry, v, true);
							-- print("check",v,id)
							if id then
								field = v;
								break;
							end
						end
						local locationGroup, locationName;
						-- convert maps
						if field == "maps" then
							-- if only a few maps, list them all
							local count = #id;
							if count == 1 then
								id = id[1];
								locationGroup = C_Map_GetMapInfo(id);
								locationName = locationGroup and (locationGroup.name or locationGroup.text);
							else
								local mapsConcat, names, name = {}, {};
								for i=1,count,1 do
									name = C_Map_GetMapInfo(id[i]).name;
									if not names[name] then
										names[name] = true;
										tinsert(mapsConcat, name);
									end
								end
								-- up to 3 unqiue map names displayed
								if #mapsConcat < 4 then
									locationName = app.TableConcat(mapsConcat, nil, nil, "/");
								else
									mapsConcat[4] = "+++";
									locationName = app.TableConcat(mapsConcat, nil, nil, "/", 1, 4);
								end
							end
						else
							locationGroup = SearchForObject(field, id) or (id and field == "mapID" and C_Map_GetMapInfo(id));
							locationName = locationGroup and (locationGroup.name or locationGroup.text);
						end
						-- print("contains info",entry.itemID,field,id,locationGroup,locationName)
						if locationName then
							-- Add the immediate parent group Vendor name
							local rawParent, sParent = rawget(entry, "parent"), entry.sourceParent;
							-- the source entry is different from the raw parent and the search context, then show the source parent text for reference
							if sParent and sParent.text and not GroupMatchesParams(rawParent, sParent.key, sParent[sParent.key]) and not GroupMatchesParams(sParent, paramA, paramB) then
								right = locationName .. " > " .. sParent.text .. " " .. right;
							else
								right = locationName .. " " .. right;
							end
						-- else
							-- print("No Location name for item",entry.itemID,id,field)
						end
					end

					-- If this entry is an Achievement Criteria (whose raw parent is not the Achievement) then show the Achievement
					if entry.criteriaID and entry.achievementID then
						local rawParent = rawget(entry, "parent");
						if not rawParent or rawParent.achievementID ~= entry.achievementID then
							local critAch = SearchForObject("achievementID", entry.achievementID);
							left = left .. " > " .. critAch.text;
						end
					end

					tinsert(info, { left = item.prefix .. left, right = right });
				end

				if #entries - containCount > 0 then
					tinsert(info, { left = L["AND_"] .. (#entries - containCount) .. L["_MORE"] .. "..." });
				end

				if app.Settings:GetTooltipSetting("Currencies") then
					-- app.PrintDebug("Currencies",group.hash,#entries)
					local costCollectibles = group.costCollectibles;
					-- app.PrintDebug("costCollectibles",group.hash,costCollectibles and #costCollectibles)
					if costCollectibles and #costCollectibles > 0 then
						local costAmounts = app.BuildCostTable(costCollectibles, paramB);
						local currencyCount, CheckCollectible = 0, app.CheckCollectible;
						local entryGroup, collectible, collected;
						for _,costEntry in ipairs(entries) do
							entryGroup = costEntry.group;
							collectible, collected = CheckCollectible(entryGroup);
							-- anything shown in the tooltip which is not collected according to the user's settings should be considered for the cost
							if collectible and not collected then
								-- app.PrintDebug("Purchasable",entryGroup.hash,collectible,collected,entryGroup.total - entryGroup.progress,"x",costAmounts[entryGroup.hash])
								currencyCount = currencyCount + (costAmounts[entryGroup.hash] or 0);
							end
						end
						if currencyCount > 0 then
							tinsert(info, { left = L["CURRENCY_NEEDED_TO_BUY"], right = formatNumericWithCommas(currencyCount) });
						end
					end
				end
			end
		end

		-- If the item is a recipe, then show which characters know this recipe.
		-- app.PrintDebug(topLevelSearch,group.spellID,group.filterID,group.collectible)
		local groupSpellID = group.spellID;
		if groupSpellID and group.filterID ~= 100 and group.collectible and app.Settings:GetTooltipSetting("KnownBy") then
			local knownBy = {};
			for guid,character in pairs(ATTCharacterData) do
				if character.Spells and character.Spells[groupSpellID] then
					tinsert(knownBy, character);
				end
			end
			if #knownBy > 0 then
				app.Sort(knownBy, app.SortDefaults.Name);
				local desc = L["KNOWN_BY"] .. app.TableConcat(knownBy, "text", "??", ", ");
				tinsert(info, { left = string.gsub(desc, "-" .. GetRealmName(), ""), wrap = true, color = app.Colors.TooltipDescription });
			end
		end

		-- If the result has a QuestID, then show which characters have this QuestID.
		-- app.PrintDebug(topLevelSearch,group.spellID,group.filterID,group.collectible)
		local groupQuestID = group.questID;
		if groupQuestID and app.Settings:GetTooltipSetting("CompletedBy") then
			local knownBy = {};
			local charQuests;
			for guid,character in pairs(ATTCharacterData) do
				charQuests = character.Quests;
				if charQuests and charQuests[groupQuestID] then
					tinsert(knownBy, character);
				end
			end
			if #knownBy > 0 then
				app.Sort(knownBy, app.SortDefaults.Name);
				local desc = sformat(L["QUEST_ONCE_PER_ACCOUNT_FORMAT"],app.TableConcat(knownBy, "text", "??", ", "));
				tinsert(info, { left = string.gsub(desc, "-" .. GetRealmName(), ""), wrap = true, color = app.Colors.TooltipDescription });
			end
		end

		group.isBaseSearchResult = true;
		app.InitialCachedSearch = nil;

		-- app.PrintDebug("TopLevelSearch",working and "WORKING" or "DONE",search,group.text or (group.key and group.key .. group[group.key]),group)

		-- Track if the result is not finished processing
		group.working = working;

		-- cache the finished result if it's completely processed
		if not working then
			searchCache[search] = group;
		end

		-- If the user wants to show the progress of this search result, do so
		if app.Settings:GetTooltipSetting("Progress") and (group.key ~= "spellID" or group.collectible) then
			group.collectionText = GetProgressTextForTooltip(group, app.Settings:GetTooltipSetting("ShowIconOnly"));

			-- add the progress as a new line for encounter tooltips instead of using right text since it can overlap the NPC name
			if group.encounterID then tinsert(info, 1, { left = "Progress", right = group.collectionText }); end
		end

		-- If there was any informational text generated, then attach that info.
		if #info > 0 then
			group.tooltipInfo = info;
			for i,item in ipairs(info) do
				if item.color then item.a, item.r, item.g, item.b = HexToARGB(item.color); end
			end
		end
	end

	return group;
end
-- Builds a hash table of hashes of collectibles which use the specified costID (without regard to being an item or currency) and storing the quantity in the hash table
app.BuildCostTable = function(collectibles, costID)
	local costAmounts, cost = {};
	for _,collectible in ipairs(collectibles) do
		cost = collectible.cost;
		if cost then
			for _,eachCost in ipairs(cost) do
				if eachCost[2] == costID then
					costAmounts[collectible.hash] = eachCost[3];
				end
			end
		end
	end
	-- app.PrintDebug("Total Costs for",costID)
	-- if app.DEBUG_PRINT then app.PrintTable(costAmounts) end
	return costAmounts;
end

-- Auto-Expansion logic
do
local included = {};
local knownSkills, isInWindow;
-- ItemID's which should be skipped when filling purchases with certain levels of 'skippability'
local SkipPurchases = {
	[-1] = 0,	-- Whether to skip certain cost items
	[137642] = 2,	-- Mark of Honor
	[21100] = 1,	-- Coin of Ancestry
	[23247] = 1,	-- Burning Blossom
	[49927] = 1,	-- Love Token
}
-- Allows for toggling whether the SkipPurchases should be used or not; call with no value to return the current value
app.SetSkipPurchases = function(level)
	if level then
		-- print("SkipPurchases exclusion",level)
		SkipPurchases[-1] = level;
	else
		return SkipPurchases[-1];
	end
end
-- Determines searches required for costs using this group
local function DeterminePurchaseGroups(group, depth)
	-- do not fill purchases on certain items, can skip the skip though based on a level
	local itemID = group.itemID;
	local reqSkipLevel = itemID and SkipPurchases[itemID];
	if reqSkipLevel then
		local curSkipLevel = SkipPurchases[-1];
		if curSkipLevel and curSkipLevel < reqSkipLevel then return; end;
	end

	local collectibles = group.costCollectibles;
	if collectibles and #collectibles > 0 then
		-- app.PrintDebug("DeterminePurchaseGroups",group.hash,"-collectibles",collectibles and #collectibles);
		local groups = {};
		local groupHash = group.hash;
		local clone, hash, includeDepth;
		for _,o in ipairs(collectibles) do
			hash = o.hash;
			-- don't add copies of this group if it matches the 'cost' group, or has already been added at a lower depth
			-- technically this allows something to become nested at a high depth, and then multiple times at lower depths...
			-- but hopefully that's ok and is a bit better for visibility than to exclude things
			if hash ~= groupHash then
				includeDepth = included[hash];
				if not includeDepth or includeDepth >= depth then
					included[hash] = depth;
					clone = CreateObject(o);
					-- this logic shows the previous 'currency' icon next to Things which are nested as a cost... maybe too cluttered
					-- clone.indicatorIcon = "Interface_Vendor";
					tinsert(groups, clone);
				end
			end
		end
		-- app.PrintDebug("DeterminePurchaseGroups",group.hash,"-final",groups and #groups);
		-- mark this group as no-longer collectible as a cost since its cost collectibles have been determined
		if #groups > 0 then
			group.collectibleAsCost = false;
			group.filledCost = true;
		end
		return groups;
	end
end
local function DetermineCraftedGroups(group)
	local itemID = group.itemID;
	if not itemID then return; end
	local reagentCache = app.GetDataSubMember("Reagents", itemID);
	if not reagentCache then return; end

	-- check if the item is BoP and needs skill filtering for current character, or debug mode
	local filterSkill = not app.MODE_DEBUG and (app.IsBoP(group) or select(14, GetItemInfo(itemID)) == 1);

	local craftableItemIDs = {};
	-- item is BoP
	if filterSkill then
		local craftedItemID, searchRecipes, recipe, skillID;
		-- If needing to filter by skill due to BoP reagent, then check via recipe cache instead of by crafted item
		-- If the reagent itself is BOP, then only show things you can make.
		-- find recipe(s) which creates this item
		for recipeID,info in pairs(reagentCache[1]) do
			craftedItemID = info[1];
			-- print(itemID,"x",info[2],"=>",craftedItemID,"via",recipeID);
			-- TODO: review how this can be nil
			if craftedItemID and not craftableItemIDs[craftedItemID] and not included[craftedItemID] then
				-- print("recipeID",recipeID);
				searchRecipes = app.SearchForField("spellID", recipeID);
				if searchRecipes and #searchRecipes > 0 then
					recipe = searchRecipes[1];
					skillID = GetRelativeValue(recipe, "skillID");
					-- print(recipeID,"requires",skillID);

					-- ensure this character can craft the recipe
					if skillID then
						if knownSkills and knownSkills[skillID] then
							craftableItemIDs[craftedItemID] = true;
						end
					else
					-- recipe without any skill requirement? weird...
						craftableItemIDs[craftedItemID] = true;
					end
				end
			end
		end
	-- item is BoE
	else
		-- Can otherwise simply iterate over the set of crafted items and add them
		for craftedItemID,count in pairs(reagentCache[2]) do
			if craftedItemID then
				craftableItemIDs[craftedItemID] = true;
			end
		end
	end

	local groups = {};
	local search;
	for craftedItemID,_ in pairs(craftableItemIDs) do
		-- never include crafted multiple times
		if not included[craftedItemID] then
			included[craftedItemID] = true;
			-- Searches for a filter-matched crafted Item
			search = app.SearchForObject("itemID",craftedItemID);
			if search then
				search = CreateObject(search);
			end
			-- could do logic here to tack on the profession's spellID icon
			tinsert(groups, search or app.CreateItem(craftedItemID));
		end
	end
	-- app.PrintDebug("DetermineCraftedGroups",group.hash,groups and #groups);
	return groups;
end
local function DetermineSymlinkGroups(group)
	if group.sym then
		-- groups which are being filled in a Window can be done async
		if isInWindow then
			-- app.PrintDebug("DSG-Async",group.hash);
			app.FillSymlinkAsync(group);
		else
			-- app.PrintDebug("DSG-Now",group.hash);
			local groups = ResolveSymbolicLink(group);
			-- make sure this group doesn't waste time getting resolved again somehow
			group.sym = nil;
			-- app.PrintDebug("DetermineSymlinkGroups",group.hash,groups and #groups);
			return groups;
		end
	end
end
local NPCExpandHeaders = {
	[-1] = true,	-- COMMON_BOSS_DROPS
};
-- Pulls in Common drop content for specific NPCs if any exists (so we don't need to always symlink every NPC which is included in common boss drops somewhere)
local function DetermineNPCDrops(group)
	local npcID = group.npcID or group.creatureID;
	if npcID then
		-- app.PrintDebug("Found NPC Group",group.hash)
		-- search for groups of this NPC
		local npcGroups = app.SearchForField("npcID", npcID);
		if npcGroups then
			local headerID, groups;
			for _,npcGroup in pairs(npcGroups) do
				headerID = npcGroup.headerID;
				-- where headerID is allowed
				if headerID and NPCExpandHeaders[headerID] then
					-- copy the header under the NPC groups
					-- app.PrintDebug("Fill under",group.hash)
					if groups then tinsert(groups, CreateObject(npcGroup))
					else groups = { CreateObject(npcGroup) }; end
				end
			end
			return groups;
		end
	end
end
local function FillGroupsRecursive(group, depth)
	-- do not fill 'saved' groups in ATT windows
	-- or groups directly under saved groups unless in Acct or Debug mode
	if isInWindow and not app.MODE_DEBUG_OR_ACCOUNT then
		-- (unless they are actual Maps or Instances, or a Difficulty header. Also 'saved' Items usually means tied to a questID directly)
		if group.saved and not (group.instanceID or group.mapID or group.difficultyID or group.itemID) then return; end
		local parent = group.parent;
		-- parent is a saved quest, then do not fill with stuff
		if parent and parent.questID and parent.saved then return; end
	end

	-- increment depth if things are being nested
	depth = (depth or 0) + 1;
	local groups;
	-- Determine Cost/Crafted/Symlink groups
	groups = app.ArrayAppend(groups,
		DeterminePurchaseGroups(group, depth),
		DetermineCraftedGroups(group),
		DetermineSymlinkGroups(group),
		DetermineNPCDrops(group));

	-- app.PrintDebug("MergeResults",group.hash,groups and #groups)
	-- Adding the groups normally based on available-source priority
	PriorityNestObjects(group, groups, nil, app.RecursiveGroupRequirementsFilter);

	if group.g then
		-- app.PrintDebug(".g",group.hash,#group.g)
		-- local hash = group.hash;
		-- Then nest anything further
		for _,o in ipairs(group.g) do
			-- never nest the same Thing under itself
			-- (prospecting recipes list the input as the output)
			-- if o.hash ~= hash then
				FillGroupsRecursive(o, depth);
			-- end
		end
	end
end
-- Appends sub-groups into the item group based on what is required to have this item (cost, source sub-group, reagents, symlinks)
app.FillGroups = function(group)
	-- Clear search history -- never re-list the starting Thing
	included = { [group.hash or ""] = 0, [group.itemID or 0] = 0 };
	-- Get tradeskill cache
	knownSkills = app.CurrentCharacter.Professions;
	-- Check if this group is inside a Window or not
	isInWindow = app.RecursiveFirstDirectParentWithField(group, "window") and true;
	app.FunctionRunner.SetPerFrame(1);

	-- app.PrintDebug("FillGroups",group.hash,group.__type,"window?",isInWindow)

	-- Fill the group with all nestable content
	FillGroupsRecursive(group);

	-- if app.DEBUG_PRINT then app.PrintTable(included) end
	-- app.PrintDebug("FillGroups Complete",group.hash,group.__type)
end
end	-- Auto-Expansion Logic

-- build a 'Cost' group which matches the "cost" tag of this group
app.BuildCost = function(group)
	-- Pop out the cost objects into their own sub-groups for accessibility
	-- Gold cost currently ignored
	-- print("BuildCost",group.itemID)
	if group.cost and type(group.cost) == "table" then
		local costGroup = {
				["text"] = L["COST"],
				["description"] = L["COST_DESC"],
				["icon"] = "Interface\\Icons\\INV_Misc_Coin_02",
				["OnUpdate"] = app.AlwaysShowUpdate,
				["g"] = {},
			};
		local costItem;
		for i,c in ipairs(group.cost) do
			-- print("Cost",c[1],c[2],c[3]);
			costItem = nil;
			if c[1] == "c" then
				costItem = app.SearchForObject("currencyID", c[2]) or app.CreateCurrencyClass(c[2]);
			elseif c[1] == "i" then
				costItem = app.SearchForObject("itemID", c[2]) or app.CreateItem(c[2]);
			end
			if costItem then
				costItem = CloneData(costItem);
				costItem.g = nil;
				costItem.collectible = false;
				-- if c[3] then
				-- 	costItem.total = c[3];
				-- 	if group.collected then
				-- 		costItem.progress = c[3];
				-- 	end
				-- end
				costItem.OnUpdate = app.AlwaysShowUpdate;
				NestObject(costGroup, costItem);
			end
		end
		NestObject(group, costGroup, nil, 1);
	end
end
(function()
-- Keys for groups which are in-game 'Things'
app.ThingKeys = {
	-- ["filterID"] = true,
	-- ["flightPathID"] = true,
	-- ["professionID"] = true,
	-- ["categoryID"] = true,
	-- ["mapID"] = true,
	["npcID"] = true,
	["creatureID"] = true,
	["currencyID"] = true,
	["itemID"] = true,
	["s"] = true,
	["speciesID"] = true,
	["recipeID"] = true,
	["spellID"] = true,
	["illusionID"] = true,
	["questID"] = true,
	["objectID"] = true,
	["encounterID"] = true,
	["artifactID"] = true,
	["azeriteEssenceID"] = true,
	["followerID"] = true,
	["achievementID"] = true,	-- special handling
};
local SpecificSources = {
	["headerID"] = {
		[-1] = true,	-- COMMON_BOSS_DROPS
	},
};
-- Builds a 'Source' group from the parent of the group (or other listings of this group) and lists it under the group itself for
app.BuildSourceParent = function(group)
	-- only show sources for Things or specific of other types
	if not group or not group.key then return; end
	local groupKey, thingKeys = group.key, app.ThingKeys;
	local thingCheck = thingKeys[groupKey];
	local specificSource = SpecificSources[groupKey]
	if specificSource then
		 specificSource = specificSource[group[groupKey]];
	end
	-- group with some Source-able data can be treated as specific Source
	if not specificSource and (
		group.npcID or group.creatureID or group.crs or group.providers
	) then
		specificSource = true;
	end
	if not thingCheck and not specificSource then return; end

	-- pull all listings of this 'Thing'
	local keyValue = group[groupKey];
	local things = specificSource and { group } or app.CleanSourceIgnoredGroups(app.SearchForLink(groupKey .. ":" .. keyValue));
	if things then
		local groupHash = group.hash;
		local isAchievement = groupKey == "achievementID";
		-- app.PrintDebug("Found Source things",#things,groupHash)
		local parents, parentKey, parent;
		-- collect all possible parent groups for all instances of this Thing
		for _,thing in pairs(things) do
			if thing.hash == groupHash or isAchievement then
				parent = thing.parent;
				while parent do
					-- app.PrintDebug("parent",parent.text,parent.key)
					parentKey = parent.key;
					if parentKey and parent[parentKey] then
						-- only show certain types of parents as sources.. typically 'Game World Things'
						-- or if the parent is directly tied to an NPC
						if thingKeys[parentKey] or parent.npcID or parent.creatureID then
							-- keep the Criteria nested for Achievements, to show proper completion tracking under various Sources
							if isAchievement then
								-- app.PrintDebug("isAchieve:keepSource",keyValue)
								parent._keepSource = keyValue;
							end
							-- add the parent for display later
							if parents then tinsert(parents, parent);
							else parents = { parent }; end
							break;
						end
						-- TODO: maybe handle mapID/instanceID in a different way as a fallback for things nested under headers within a zone....?
					end
					-- move to the next parent if the current parent is not a valid 'Thing'
					parent = parent.parent;
				end
				-- Things tagged with an npcID should show that NPC as a Source
				if thing.key ~= "npcID" and (thing.npcID or thing.creatureID) then
					local parentNPC = app.SearchForObject("creatureID", thing.npcID or thing.creatureID) or {["npcID"] = thing.npcID or thing.creatureID};
					if parents then tinsert(parents, parentNPC);
					else parents = { parentNPC }; end
				end
				-- Things tagged with many npcIDs should show all those NPCs as a Source
				if thing.crs then
					-- app.PrintDebug("thing.crs",#thing.crs)
					if not parents then parents = {}; end
					local parentNPC;
					for _,npcID in ipairs(thing.crs) do
						parentNPC = app.SearchForObject("creatureID", npcID) or {["npcID"] = npcID};
						tinsert(parents, parentNPC);
					end
				end
				-- Things tagged with providers should show the providers as a Source
				if thing.providers then
					local type, id;
					for _,p in ipairs(thing.providers) do
						type, id = p[1], p[2];
						-- app.PrintDebug("Root Provider",type,id);
						local pRef = (type == "i" and app.SearchForObject("itemID", id))
								or   (type == "o" and app.SearchForObject("objectID", id))
								or   (type == "n" and app.SearchForObject("npcID", id));
						if pRef then
							pRef = CreateObject(pRef);
							if parents then tinsert(parents, pRef);
							else parents = { pRef }; end
						else
							pRef = (type == "i" and app.CreateItem(id))
								or   (type == "o" and app.CreateObject(id))
								or   (type == "n" and app.CreateNPC(id));
							if parents then tinsert(parents, pRef);
							else parents = { pRef }; end
						end
					end
				end
			end
		end
		-- if there are valid parent groups for sources, merge them into a 'Source(s)' group
		if parents then
			-- app.PrintDebug("Found parents",#parents)
			local sourceGroup = {
				["text"] = L["SOURCES"],
				["description"] = L["SOURCES_DESC"],
				["icon"] = "Interface\\Icons\\inv_misc_spyglass_02",
				["OnUpdate"] = app.AlwaysShowUpdate,
				["g"] = {},
			};
			local clonedParent, keepSource;
			local clones = {};
			for _,parent in ipairs(parents) do
				keepSource = parent._keepSource;
				-- clear the flag from the Source
				parent._keepSource = nil;
				-- if keepSource then print("Keeping Criteria under",parent.hash) end
				clonedParent = keepSource and CreateObject(parent) or CreateObject(parent, true);
				clonedParent.collectible = false;
				if keepSource and clonedParent.g then
					local replace = {};
					for _,o in ipairs(clonedParent.g) do
						if o[groupKey] == keepSource then
							-- print("keep Criteria",o.hash,"under",clonedParent.hash)
							tinsert(replace, o);
						end
					end
					clonedParent.g = replace;
				else
					clonedParent.OnUpdate = app.AlwaysShowUpdate;	-- TODO: filter actual unobtainable sources...
				end
				tinsert(clones, clonedParent);
			end
			PriorityNestObjects(sourceGroup, clones, nil, app.RecursiveGroupRequirementsFilter);
			NestObject(group, sourceGroup, nil, 1);
		end
	end
end
end)();
-- check if the group has a cost which includes the given parameters
app.HasCost = function(group, idType, id)
	if group.cost and type(group.cost) == "table" then
		if idType == "itemID" then
			for i,c in ipairs(group.cost) do
				if c[2] == id and c[1] == "i" then
					return true;
				end
			end
		elseif idType == "currencyID" then
			for i,c in ipairs(group.cost) do
				if c[2] == id and c[1] == "c" then
					return true;
				end
			end
		end
	end
	return false;
end

-- app.NestSourceQuests = function(root, addedQuests, depth)
-- 	-- root is already the cloned source of the new list, just add each sourceQuest cloned into sub-groups
-- 	-- setup tracking which quests have been added as a sub-group, so we can only add them once
-- 	if not addedQuests then addedQuests = {}; end
-- 	root.hideText = true;
-- 	root.depth = depth or 0;
-- 	if root.sourceQuests and #root.sourceQuests > 0 then
-- 		local qs;
-- 		-- we will ignore custom collect if the root quest is already out of scope
-- 		local checkCustomCollects = app.CheckCustomCollects(root);
-- 		local prereqs;
-- 		for _,sourceQuestID in ipairs(root.sourceQuests) do
-- 			if not addedQuests[sourceQuestID] then
-- 				addedQuests[sourceQuestID] = true;
-- 				qs = sourceQuestID < 1 and app.SearchForField("creatureID", math.abs(sourceQuestID)) or app.SearchForField("questID", sourceQuestID);
-- 				if qs and #qs > 0 then
-- 					local i, sq = #qs;
-- 					while not sq and i > 0 do
-- 						if qs[i].questID == sourceQuestID then sq = qs[i]; end
-- 						i = i - 1;
-- 					end
-- 					if sq and sq.questID then
-- 						if sq.parent and sq.parent.questID == sq.questID then
-- 							sq = sq.parent;
-- 						end
-- 						-- clone the object so as to not modify actual data
-- 						sq = CreateObject(sq);
-- 						sq.hideText = true;
-- 						-- clean anything out of it so that items don't show in the quest requirements
-- 						sq.g = nil;

-- 						-- force collectible for normally un-collectible things to make sure it shows in list if the quest needs to be completed to progess
-- 						if not sq.collectible and sq.missingSourceQuests then
-- 							sq.collectible = true;
-- 						end

-- 						-- If the user is in a Party Sync session, then force showing pre-req quests which are replayable if they are collected already
-- 						if app.IsInPartySync and sq.collected then
-- 							sq.OnUpdate = app.ShowIfReplayableQuest;
-- 						end

-- 						sq = (not checkCustomCollects or app.CheckCustomCollects(sq)) and app.RecursiveGroupRequirementsFilter(sq) and app.NestSourceQuests(sq, addedQuests, (depth or 0) + 1);
-- 					elseif sourceQuestID > 0 then
-- 						-- Create a Quest Object.
-- 						sq = app.CreateQuest(sourceQuestID, { ['hideText'] = true, });
-- 					else
-- 						-- Create a NPC Object.
-- 						sq = app.CreateNPC(math.abs(sourceQuestID), { ['hideText'] = true, });
-- 					end

-- 					if sq then
-- 						-- track how many quests levels are nested so it can be sorted in a decent-ish looking way
-- 						root.depth = math.max((root.depth or 0),(sq.depth or 1));
-- 						if prereqs then tinsert(prereqs, sq);
-- 						else prereqs = { sq }; end
-- 					else
-- 						addedQuests[sourceQuestID] = nil;
-- 					end
-- 				end
-- 			end
-- 		end
-- 		-- sort quests with less sub-quests to the top
-- 		if prereqs then
-- 			app.Sort(prereqs, function(a, b) return (a.depth or 0) < (b.depth or 0); end);
-- 			NestObjects(root, prereqs);
-- 		end
-- 	end
-- 	-- If the root quest is provided by an Item, then show that Item directly under the root Quest so it can easily show tooltip/Source information if desired
-- 	if root.providers then
-- 		for _,p in ipairs(root.providers) do
-- 			if p[1] == "i" then
-- 				-- print("Root Provider",p[1], p[2]);
-- 				local pRef = app.SearchForObject("itemID", p[2]);
-- 				if pRef then
-- 					NestObject(root, pRef, true, 1);
-- 				else
-- 					NestObject(root, app.CreateItem(p[2]), nil, 1);
-- 				end
-- 			end
-- 		end
-- 	end
-- 	return root;
-- end
local function SendGroupMessage(msg)
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) and IsInInstance() then
		C_ChatInfo.SendAddonMessage("ATT", msg, "INSTANCE_CHAT")
	elseif IsInRaid() then
		C_ChatInfo.SendAddonMessage("ATT", msg, "RAID")
	elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
		C_ChatInfo.SendAddonMessage("ATT", msg, "PARTY")
	end
end
local function SendGuildMessage(msg)
	if IsInGuild() then
		C_ChatInfo.SendAddonMessage("ATT", msg, "GUILD");
	else
		app.events.CHAT_MSG_ADDON("ATT", msg, "WHISPER", "player");
	end
end
local function SendResponseMessage(msg, player)
	if UnitInRaid(player) or UnitInParty(player) then
		SendGroupMessage("to\t" .. player .. "\t" .. msg);
	else
		C_ChatInfo.SendAddonMessage("ATT", msg, "WHISPER", player);
	end
end
local function SendSocialMessage(msg)
	SendGroupMessage(msg);
	SendGuildMessage(msg);
end

-- Synchronization Functions
(function()
local outgoing,incoming,queue,active = {},{},{};
local whiteListedFields = { --[["Achievements",]] "Buildings", --[["Exploration",]] "Factions", "FlightPaths", "Followers", "Spells", "Titles", "Quests" };
local function splittoarray(sep, inputstr)
	local t = {};
	for str in string.gmatch(inputstr, "([^" .. (sep or "%s") .. "]+)") do
		table.insert(t, str);
	end
	return t;
end
local function processQueue()
	if #queue > 0 and not active then
		local data = queue[1];
		table.remove(queue, 1);
		active = data[1];
		app.print("Updating " .. data[2] .. " from " .. data[3] .. "...");
		C_ChatInfo.SendAddonMessage("ATT", "!\tsyncsum\t" .. data[1], "WHISPER", data[3]);
	end
end

function app:AcknowledgeIncomingChunks(sender, uid, total)
	local incomingFromSender = incoming[sender];
	if not incomingFromSender then
		incomingFromSender = {};
		incoming[sender] = incomingFromSender;
	end
	incomingFromSender[uid] = { ["chunks"] = {}, ["total"] = total };
	C_ChatInfo.SendAddonMessage("ATT", "chksack\t" .. uid, "WHISPER", sender);
end
local function ProcessIncomingChunk(sender, uid, index, chunk)
	if not (chunk and index and uid and sender) then return false; end
	local incomingFromSender = incoming[sender];
	if not incomingFromSender then return false; end
	local incomingForUID = incomingFromSender[uid];
	if not incomingForUID then return false; end
	incomingForUID.chunks[index] = chunk;
	if index < incomingForUID.total then
		if index % 25 == 0 then app.print("Syncing " .. index .. " / " .. incomingForUID.total); end
		return true;
	end

	incomingFromSender[uid] = nil;

	local msg = "";
	for i=1,incomingForUID.total,1 do
		msg = msg .. incomingForUID.chunks[i];
	end
	-- app:ShowPopupDialogWithMultiLineEditBox(msg);
	local characters = splittoarray("\t", msg);
	for _,characterString in ipairs(characters) do
		local data = splittoarray(":", characterString);
		local guid = data[1];
		local character = ATTCharacterData[guid];
		if not character then
			character = {};
			character.guid = guid;
			ATTCharacterData[guid] = character;
		end
		character.name = data[2];
		character.lvl = tonumber(data[3]);
		character.text = data[4];
		if data[5] ~= "" and data[5] ~= " " then character.realm = data[5]; end
		if data[6] ~= "" and data[6] ~= " " then character.factionID = tonumber(data[6]); end
		if data[7] ~= "" and data[7] ~= " " then character.classID = tonumber(data[7]); end
		if data[8] ~= "" and data[8] ~= " " then character.raceID = tonumber(data[8]); end
		character.lastPlayed = tonumber(data[9]);
		character.Deaths = tonumber(data[10]);
		if character.classID then character.class = C_CreatureInfo.GetClassInfo(character.classID).classFile; end
		if character.raceID then character.race = C_CreatureInfo.GetRaceInfo(character.raceID).clientFileString; end
		for i=11,#data,1 do
			local piece = splittoarray("/", data[i]);
			local key = piece[1];
			local field = {};
			character[key] = field;
			for j=2,#piece,1 do
				local index = tonumber(piece[j]);
				if index then field[index] = 1; end
			end
		end
		app.print("Update complete for " .. character.text .. ".");
	end

	app:RecalculateAccountWideData();
	app.Settings:Refresh();
	active = nil;
	processQueue();
	return false;
end
function app:AcknowledgeIncomingChunk(sender, uid, index, chunk)
	if chunk and ProcessIncomingChunk(sender, uid, index, chunk) then
		C_ChatInfo.SendAddonMessage("ATT", "chkack\t" .. uid .. "\t" .. index .. "\t1", "WHISPER", sender);
	else
		C_ChatInfo.SendAddonMessage("ATT", "chkack\t" .. uid .. "\t" .. index .. "\t0", "WHISPER", sender);
	end
end
function app:SendChunk(sender, uid, index, success)
	local outgoingForSender = outgoing[sender];
	if outgoingForSender then
		local chunksForUID = outgoingForSender.uids[uid];
		if chunksForUID and success == 1 then
			local chunk = chunksForUID[index];
			if chunk then
				C_ChatInfo.SendAddonMessage("ATT", "chk\t" .. uid .. "\t" .. index .. "\t" .. chunk, "WHISPER", sender);
			end
		else
			outgoingForSender.uids[uid] = nil;
		end
	end
end

function app:IsAccountLinked(sender)
	return AllTheThingsAD.LinkedAccounts[sender] or AllTheThingsAD.LinkedAccounts[strsplit("-", sender)];
end
function app:RecalculateAccountWideData()
	for key,data in pairs(ATTAccountWideData) do
		if type(data) == "table" and contains(whiteListedFields, key) then
			data = {};
			for guid,character in pairs(ATTCharacterData) do
				local characterData = character[key];
				if characterData then
					for index,_ in pairs(characterData) do
						data[index] = 1;
					end
				end
			end
			ATTAccountWideData[key] = data;
		end
	end
	local deaths = 0;
	for guid,character in pairs(ATTCharacterData) do
		if character.Deaths then
			deaths = deaths + character.Deaths;
		end
	end
	ATTAccountWideData.Deaths = deaths;
end
function app:ReceiveSyncRequest(sender, battleTag)
	if battleTag ~= select(2, BNGetInfo()) then
		-- Check to see if the character/account is linked.
		if not (app:IsAccountLinked(sender) or AllTheThingsAD.LinkedAccounts[battleTag]) then
			return false;
		end
	end

	-- Whitelist the character name, if not already. (This is needed for future sync methods)
	AllTheThingsAD.LinkedAccounts[sender] = true;

	-- Generate the sync string (there may be several depending on how many alts there are)
	local msgs = {};
	local msg = "?\tsyncsum";
	for guid,character in pairs(ATTCharacterData) do
		if character.lastPlayed then
			local charsummary = "\t" .. guid .. ":" .. character.lastPlayed;
			if (string.len(msg) + string.len(charsummary)) < 255 then
				msg = msg .. charsummary;
			else
				C_ChatInfo.SendAddonMessage("ATT", msg, "WHISPER", sender);
				msg = "?\tsyncsum" .. charsummary;
			end
		end
	end
	C_ChatInfo.SendAddonMessage("ATT", msg, "WHISPER", sender);
end
function app:ReceiveSyncSummary(sender, summary)
	if app:IsAccountLinked(sender) then
		local first = #queue == 0;
		for i,data in ipairs(summary) do
			local guid,lastPlayed = strsplit(":", data);
			local character = ATTCharacterData[guid];
			if not character or not character.lastPlayed or (character.lastPlayed < tonumber(lastPlayed)) and guid ~= active then
				tinsert(queue, { guid, character and character.text or guid, sender });
			end
		end
		if first then processQueue(); end
	end
end
function app:ReceiveSyncSummaryResponse(sender, summary)
	if app:IsAccountLinked(sender) then
		local rawMsg;
		for i,guid in ipairs(summary) do
			local character = ATTCharacterData[guid];
			if character then
				-- Put easy character data into a raw data string
				local rawData = character.guid .. ":" .. character.name .. ":" .. character.lvl .. ":" .. character.text .. ":" .. (character.realm or " ") .. ":" .. (character.factionID or " ") .. ":" .. (character.classID or " ") .. ":" .. (character.raceID or " ") .. ":" .. character.lastPlayed .. ":" .. character.Deaths;

				for i,field in ipairs(whiteListedFields) do
					if character[field] then
						rawData = rawData .. ":" .. field;
						for index,value in pairs(character[field]) do
							if value then
								rawData = rawData .. "/" .. index;
							end
						end
					end
				end

				if not rawMsg then
					rawMsg = rawData;
				else
					rawMsg = rawMsg .. "\t" .. rawData;
				end
			end
		end

		if rawMsg then
			-- Send Addon Message Back
			local length = string.len(rawMsg);
			local chunks = {};
			for i=1,length,241 do
				tinsert(chunks, string.sub(rawMsg, i, math.min(length, i + 240)));
			end
			local outgoingForSender = outgoing[sender];
			if not outgoingForSender then
				outgoingForSender = { ["total"] = 0, ["uids"] = {}};
				outgoing[sender] = outgoingForSender;
			end
			local uid = outgoingForSender.total + 1;
			outgoingForSender.uids[uid] = chunks;
			outgoingForSender.total = uid;

			-- Send Addon Message Back
			C_ChatInfo.SendAddonMessage("ATT", "chks\t" .. uid .. "\t" .. #chunks, "WHISPER", sender);
		end
	end
end
function app:Synchronize(automatically)
	-- Update the last played timestamp. This ensures the sync process does NOT destroy unsaved progress on this character.
	local battleTag = select(2, BNGetInfo());
	if battleTag then
		app.CurrentCharacter.lastPlayed = time();
		local any, msg = false, "?\tsync\t" .. battleTag;
		for playerName,allowed in pairs(AllTheThingsAD.LinkedAccounts) do
			if allowed and not string.find(playerName, "#") then
				C_ChatInfo.SendAddonMessage("ATT", msg, "WHISPER", playerName);
				any = true;
			end
		end
		if not any and not automatically then
			app.print("You need to link a character or BNET account in the settings first before you can Sync accounts.");
		end
	end
end
function app:SynchronizeWithPlayer(playerName)
	-- Update the last played timestamp. This ensures the sync process does NOT destroy unsaved progress on this character.
	local battleTag = select(2, BNGetInfo());
	if battleTag then
		app.CurrentCharacter.lastPlayed = time();
		C_ChatInfo.SendAddonMessage("ATT", "?\tsync\t" .. battleTag, "WHISPER", playerName);
	end
end
end)();

-- Lua Constructor Lib
local fieldCache = {};
local CacheFields;
local _cache;
(function()
local currentMaps = {};
local currentInstance;
local delayedRawSets = {};
local wipe, type =
	  wipe, type;
local fieldCache_g,fieldCache_f, fieldConverters;
local function CacheField(group, field, value)
	fieldCache_g = rawget(fieldCache, field);
	fieldCache_f = rawget(fieldCache_g, value);
	if fieldCache_f then
		fieldCache_f[#fieldCache_f + 1] = group;
	else
		rawset(fieldCache_g, value, {group});
	end
end
-- Toggle being able to cache things inside maps
app.ToggleCacheMaps = function(skipCaching)
	currentMaps[-1] = skipCaching;
end
-- This is referenced by FlightPath objects when pulling their Info from the DB
app.CacheField = CacheField;
-- These are the fields we store.
fieldCache["achievementID"] = {};
fieldCache["achievementCategoryID"] = {};
fieldCache["artifactID"] = {};
fieldCache["azeriteEssenceID"] = {};
fieldCache["creatureID"] = {};
fieldCache["currencyID"] = {};
fieldCache["currencyIDAsCost"] = {};
fieldCache["encounterID"] = {};
fieldCache["factionID"] = {};
fieldCache["flightPathID"] = {};
fieldCache["followerID"] = {};
fieldCache["headerID"] = {};
fieldCache["illusionID"] = {};
fieldCache["instanceID"] = {};
fieldCache["itemID"] = {};
fieldCache["itemIDAsCost"] = {};
fieldCache["mapID"] = {};
fieldCache["mountID"] = {};
fieldCache["nextQuests"] = {};
-- identical cache as creatureID (probably deprecate creatureID use eventually)
fieldCache["npcID"] = rawget(fieldCache, "creatureID");
fieldCache["objectID"] = {};
fieldCache["professionID"] = {};
-- identical cache as professionID
fieldCache["requireSkill"] = rawget(fieldCache, "professionID");
fieldCache["questID"] = {};
fieldCache["runeforgePowerID"] = {};
fieldCache["rwp"] = {};
fieldCache["s"] = {};
fieldCache["speciesID"] = {};
fieldCache["spellID"] = {};
fieldCache["tierID"] = {};
fieldCache["titleID"] = {};
fieldCache["toyID"] = {};
local cacheAchievementID = function(group, value)
	-- achievements used on maps should not cache the location for the achievement
	if group.mapID then return; end
	CacheField(group, "achievementID", value);
end
local cacheCreatureID = function(group, npcID)
	if npcID > 0 then
		CacheField(group, "creatureID", npcID);
	end
end
-- special map cache function, will only cache a group for the mapID if the current hierarchy has not already been cached in this map
-- level doesn't matter and will be reported in chat for 'mapID' and 'maps' being multiply-nested
local cacheMapID = function(group, mapID, coords)
	-- use -1 as special key to NOT cache a group with a map
	if currentMaps[-1] then return; end
	if not currentMaps[mapID] then
		-- track the group which was first cached for this map within the hierarchy
		currentMaps[mapID] = group;
		CacheField(group, "mapID", mapID);
	elseif not coords then
		local mapgroup = currentMaps[mapID];
		print("Multi-nested map",mapID,"for",group.key,group.key and group[group.key],"under",mapgroup.key,mapgroup.key and mapgroup[mapgroup.key]);
	end
end
local cacheObjectID = function(group, objectID)
	-- WARNING: DEV ONLY START
	if not app.ObjectNames[objectID] then
		print("Object Missing Name ", objectID);
		app.ObjectNames[objectID] = "Object #" .. objectID;
	end
	-- WARNING: DEV ONLY END
	CacheField(group, "objectID", objectID);
end
local cacheQuestID = function(group, questID)
	CacheField(group, "questID", questID);
end
local cacheFactionID = function(group, id)
	CacheField(group, "factionID", id);
end

fieldConverters = {
	-- Simple Converters
	["achievementID"] = cacheAchievementID,
	["achievementCategoryID"] = function(group, value)
		CacheField(group, "achievementCategoryID", value);
	end,
	["achID"] = cacheAchievementID,
	["altAchID"] = cacheAchievementID,
	["artifactID"] = function(group, value)
		CacheField(group, "artifactID", value);
	end,
	["azeriteEssenceID"] = function(group, value)
		CacheField(group, "azeriteEssenceID", value);
	end,
	["creatureID"] = cacheCreatureID,
	["currencyID"] = function(group, value)
		CacheField(group, "currencyID", value);
	end,
	["encounterID"] = function(group, value)
		CacheField(group, "encounterID", value);
	end,
	["factionID"] = cacheFactionID,
	["flightPathID"] = function(group, value)
		CacheField(group, "flightPathID", value);
	end,
	["followerID"] = function(group, value)
		CacheField(group, "followerID", value);
	end,
	["headerID"] = function(group, value)
		-- WARNING: DEV ONLY START
		if not L["HEADER_NAMES"][value] then
			print("Header Missing Name ", value);
			L["HEADER_NAMES"][value] = "Header #" .. value;
		end
		-- WARNING: DEV ONLY END
		CacheField(group, "headerID", value);
	end,
	["illusionID"] = function(group, value)
		CacheField(group, "illusionID", value);
	end,
	["instanceID"] = function(group, value)
		CacheField(group, "instanceID", value);
	end,
	["itemID"] = function(group, value, raw)
		if group.isToy then CacheField(group, "toyID", value); end
		if not raw then
			-- only cache the modItemID if it is not the same as the itemID
			-- pulling .modItemID directly will cause a rawset on the group and break iteration while caching
			local modItemID = GetGroupItemIDWithModID(group);
			if (modItemID or value) ~= value then
				CacheField(group, "itemID", modItemID);
			end
		end
		-- always cache the plain ItemID as a fallback for items which generate in-game with unaccounted-for modIDs (M+, etc.)
		CacheField(group, "itemID", value);
	end,
	["mapID"] = cacheMapID,
	["npcID"] = cacheCreatureID,
	["objectID"] = cacheObjectID,
	["professionID"] = function(group, value)
		CacheField(group, "professionID", value);
	end,
	["questID"] = cacheQuestID,
	["questIDA"] = cacheQuestID,
	["questIDH"] = cacheQuestID,
	["otherQuestData"] = function(group, value)
		CacheFields(value);
	end,
	["requireSkill"] = function(group, value)
		CacheField(group, "professionID", value);
	end,
	["runeforgePowerID"] = function(group, value)
		CacheField(group, "runeforgePowerID", value);
	end,
	["rwp"] = function(group, value)
		CacheField(group, "rwp", value);
	end,
	["s"] = function(group, value)
		CacheField(group, "s", value);
	end,
	["speciesID"] = function(group, value)
		CacheField(group, "speciesID", value);
	end,
	["spellID"] = function(group, value)
		CacheField(group, "spellID", value);
		-- cache as a mount if it is
		local mountID = group.mountID;
		if mountID then
			CacheField(group, "mountID", mountID);
		end
	end,
	["tierID"] = function(group, value)
		CacheField(group, "tierID", value);
	end,
	["titleID"] = function(group, value)
		CacheField(group, "titleID", value);
	end,

	-- Complex Converters
	["crs"] = function(group, value)
		for _,creatureID in ipairs(value) do
			cacheCreatureID(group, creatureID);
		end
	end,
	["qgs"] = function(group, value)
		for _,questGiverID in ipairs(value) do
			cacheCreatureID(group, questGiverID);
		end
	end,
	["titleIDs"] = function(group, value)
		_cache = rawget(fieldConverters, "titleID");
		for _,titleID in ipairs(value) do
			_cache(group, titleID);
		end
	end,
	["providers"] = function(group, value)
		local t, p;
		for _,v in pairs(value) do
			p = v[2];
			if p > 0 then
				t = v[1];
				if t == "n" then
					cacheCreatureID(group, p);
				elseif t == "i" then
					CacheField(group, "itemIDAsCost", p);
				elseif t == "c" then
					CacheField(group, "currencyIDAsCost", p);
				elseif t == "o" then
					cacheObjectID(group, p);
				end
			end
		end
	end,
	["maps"] = function(group, value)
		for _,mapID in ipairs(value) do
			cacheMapID(group, mapID);
		end
	end,
	["maxReputation"] = function(group, value)
		cacheFactionID(group, value[1]);
	end,
	["minReputation"] = function(group, value)
		cacheFactionID(group, value[1]);
	end,
	["nextQuests"] = function(group, value)
		for _,questID in ipairs(value) do
			CacheField(group, "nextQuests", questID);
		end
	end,
	["coord"] = function(group, value)
		-- don't cache mapID from coord for anything which is itself an actual instance or a map
		if currentInstance ~= group and not rawget(group, "mapID") and not rawget(group, "difficultyID") then
			if value[3] then cacheMapID(group, value[3], true); end
		end
	end,
	["coords"] = function(group, value)
		-- don't cache mapID from coord for anything which is itself an actual instance or a map
		if currentInstance ~= group and not rawget(group, "mapID") and not rawget(group, "difficultyID") then
			for _,coord in ipairs(value) do
				if coord[3] then cacheMapID(group, coord[3], true); end
			end
		end
	end,
	["cost"] = function(group, value)
		if type(value) == "number" then
			return;
		else
			local t, p;
			for _,v in pairs(value) do
				p = v[2];
				if p > 0 then
					t = v[1];
					if t == "i" then
						CacheField(group, "itemIDAsCost", p);
					elseif t == "c" then
						CacheField(group, "currencyIDAsCost", p);
					elseif t == "o" then
						cacheObjectID(group, p);
					end
				end
			end
		end
	end,
	["c"] = function(group, value)
		if not containsValue(value, app.ClassIndex) then
			delayedRawSets["nmc"] = true; -- "Not My Class"
		end
	end,
	["r"] = function(group, value)
		if value ~= app.FactionID then
			delayedRawSets["nmr"] = true; -- "Not My Race"
		end
	end,
	["races"] = function(group, value)
		if not containsValue(value, app.RaceIndex) then
			delayedRawSets["nmr"] = true; -- "Not My Race"
		end
	end,
};

-- Performance Tracking for Caching
if app.__perf then
	local GetTimePreciseSec = GetTimePreciseSec;
	local type = "CacheFields";
	-- init table for this object type
	if type and not app.__perf[type] then
		app.__perf[type] = {};
	end
	local cacheConverters = {};
	for key,func in pairs(fieldConverters) do
		-- replace each function with itself wrapped in a perf update
		-- app.PrintDebug("Replaced Cache function",key)
		cacheConverters[key] = function(group, value)
			local now = GetTimePreciseSec();
			func(group, value);
			local typeData = rawget(app.__perf, type);
			rawset(typeData, key, (rawget(typeData, key) or 0) + 1);
			rawset(typeData, key.."_Time", (rawget(typeData, key.."_Time") or 0) + (GetTimePreciseSec() - now));
		end
	end
	fieldConverters = cacheConverters;
end

local uncacheMap = function(group, mapID)
	if mapID and currentMaps[mapID] == group then
		currentMaps[mapID] = nil;
	end
end
local mapKeyUncachers = {
	["mapID"] = uncacheMap,
	["coord"] = function(group, coord)
		uncacheMap(group, coord[3]);
	end,
	["maps"] = function(group, maps)
		for _,mapID in ipairs(maps) do
			uncacheMap(group, mapID);
		end
	end,
	["coords"] = function(group, coords)
		for _,coord in ipairs(coords) do
			uncacheMap(group, coord[3]);
		end
	end,
};
CacheFields = function(group)
	local mapKeys;
	local hasG = rawget(group, "g");
	-- track if this group is a 'real' instance (instanceID + mapID/maps)
	if not currentInstance and group.key == "instanceID" and (group.mapID or group.maps) then
		currentInstance = group;
	end
	-- cache any matching converter fields within the group
	for k,value in pairs(group) do
		_cache = rawget(fieldConverters, k);
		if _cache then
			_cache(group, value);
			if rawget(mapKeyUncachers, k) then
				if mapKeys then mapKeys[k] = value;
				else mapKeys = { [k] = value }; end
			end
		end
	end
	-- any delayed rawsets following the iteration across the group
	for k,value in pairs(delayedRawSets) do
		rawset(group, k, value);
	end
	wipe(delayedRawSets);
	-- do sub-groups last
	if hasG then
		for _,subgroup in ipairs(hasG) do
			CacheFields(subgroup);
		end
	end
	-- clear currentMapIDs used by this group
	if mapKeys then
		for key,value in pairs(mapKeys) do
			rawget(mapKeyUncachers, key)(group, value);
		end
	end
	-- clear the 'real' instance if this group was it
	if currentInstance and currentInstance == group then
		currentInstance = nil;
	end
end
app.CacheFields = CacheFields;
end)();

local function SearchForFieldRecursively(group, field, value)
	if group.g then
		-- Go through the sub groups and determine if any of them have a response.
		local first = nil;
		for i, subgroup in ipairs(group.g) do
			local g = SearchForFieldRecursively(subgroup, field, value);
			if g then
				if first then
					-- Merge!
					for j,data in ipairs(g) do
						tinsert(first, data);
					end
				else
					-- Cool! (This should be the most common occurance)
					first = g;
				end
			end
		end
		if group[field] == value then
			-- OH BOY, WE FOUND IT!
			if first then
				return tinsert(first, group);
			else
				return { group };
			end
		end
		return first;
	elseif group[field] == value then
		-- OH BOY, WE FOUND IT!
		return { group };
	end
end
local function SearchForFieldContainer(field)
	if field then return rawget(fieldCache, field); end
end
app.SearchForFieldContainer = SearchForFieldContainer;
-- This method returns a table containing all groups which contain the provided field with id value
local function SearchForField(field, id)
	if field and id then
		_cache = rawget(fieldCache, field);
		return (_cache and rawget(_cache, id)), field, id;
	end
end
app.SearchForField = SearchForField;
-- This method performs the SearchForField logic, but then verifies that ONLY a specific matching, filtered-priority object is returned
app.SearchForObject = function(field, id)
	local fcache = SearchForField(field, id);
	if fcache then
		local count = #fcache;
		-- quick escape for single cache results! hooray!
		if count == 1 then
			return fcache[1];
		end
		-- find a filter-match object first
		local fcacheObj, keyMatch, fieldMatch, match;
		local Filter = app.RecursiveGroupRequirementsFilter;
		for i=1,count,1 do
			fcacheObj = fcache[i];
			-- field matching id
			if fcacheObj[field] == id then
				if fcacheObj.key == field then
					-- with keyed-field matching key & current filters
					if Filter(fcacheObj) then
						return fcacheObj;
					end
					keyMatch = keyMatch or fcacheObj;
				else
					-- with field matching id
					fieldMatch = fieldMatch or fcacheObj;
				end
			-- basic group related to search
			else
				match = match or fcacheObj;
			end
		end
		-- otherwise just find the first matching object
		return keyMatch or fieldMatch or match or nil;
	end
end
-- This method performs the SearchForField logic and returns a single version of the specific object by merging together all sources of the object
-- NOTE: Don't use this for Items, because modIDs and bonusIDs are stupid
app.SearchForMergedObject = function(field, id)
	local fcache = SearchForField(field, id);
	if fcache and #fcache > 0 then
		-- find a filter-match object first
		local fcacheObj, merged;
		for i=1,#fcache,1 do
			fcacheObj = fcache[i];
			if fcacheObj.key == field then
				if not merged then
					merged = CreateObject(fcacheObj);
				else
					MergeProperties(merged, fcacheObj);
				end
			end
		end
		-- return the merged object
		return merged;
	end
end

-- Item Information Lib
local function SearchForRelativeItems(group, listing)
	if group and group.g then
		for i,subgroup in ipairs(group.g) do
			SearchForRelativeItems(subgroup, listing);
			if subgroup.itemID then
				tinsert(listing, subgroup);
			end
		end
	end
end
local function SearchForSpecificGroups(found, group, hashes)
	if group then
		if hashes[group.hash] then
			tinsert(found, group);
		end
		local g = group.g;
		if g then
			for _,o in ipairs(g) do
				SearchForSpecificGroups(found, o, hashes);
			end
		end
	end
end
-- Returns the first found cached group for a given SourceID
-- NOTE: Do not use this function when the results are being passed into an Update afterward
local function SearchForSourceIDQuickly(sourceID)
	if sourceID and sourceID > 0 and app:GetDataCache() then
		local group = rawget(rawget(fieldCache, "s"),sourceID);
		if group and #group > 0 then return group[1]; end
	end
end
local function SearchForLink(link)
	if string.match(link, "item") then
		-- Parse the link and get the itemID and bonus ids.
		local itemString = string.match(link, "item[%-?%d:]+") or link;
		if itemString then
			local _, itemID, enchantId, gemId1, gemId2, gemId3, gemId4, suffixId, uniqueId,
				linkLevel, specializationID, upgradeId, modID, bonusCount, bonusID1 = strsplit(":", link);
			if itemID then
				itemID = tonumber(itemID) or 0;
				-- Don't use SourceID for artifact searches since they contain many SourceIDs
				local sourceID = select(3, GetItemInfo(link)) ~= 6 and GetSourceID(link);
				local exactItemID = GetGroupItemIDWithModID(nil, itemID, modID, (tonumber(bonusCount) or 0) > 0 and bonusID1);
				local modItemID = GetGroupItemIDWithModID(nil, itemID, modID);
				if sourceID then
					-- Search for the Source ID. (an appearance)
					_ = SearchForField("s", sourceID);
					-- print("SEARCHING FOR ITEM LINK WITH S ", link, itemID, sourceID, _ and #_);
				else
					-- Search for the Item ID. (an item without an appearance)
					_ = ((exactItemID ~= itemID) and SearchForField("itemID", exactItemID)) or
						((modItemID ~= itemID) and SearchForField("itemID", modItemID)) or
						SearchForField("itemID", itemID);
					-- print("SEARCHING FOR ITEM LINK ", link, exactItemID, modItemID, itemID, _ and #_);
				end
				return _;
			end
		end
	else
		local kind, id = strsplit(":", link);
		kind = string_lower(kind);
		if string.sub(kind,1,2) == "|c" then
			kind = string.sub(kind,11);
		end
		if string.sub(kind,1,2) == "|h" then
			kind = string.sub(kind,3);
		end
		if id then id = tonumber(select(1, strsplit("|[", id)) or id); end
		--print(string.gsub(string.gsub(link, "|c", "c"), "|h", "h"));
		if kind == "itemid" or kind == "i" then
			return SearchForField("itemID", id);
		elseif kind == "sourceid" or kind == "s" then
			return SearchForField("s", id);
		elseif kind == "questid" or kind == "quest" or kind == "q" then
			return SearchForField("questID", id);
		elseif kind == "creatureid" or kind == "npcid" or kind == "n" then
			return SearchForField("creatureID", id);
		elseif kind == "achievementid" or kind == "achievement" or kind == "a" then
			return SearchForField("achievementID", id);
		elseif kind == "currencyid" or kind == "currency" or kind == "c" then
			return SearchForField("currencyID", id);
		elseif kind == "spellid" or kind == "spell" or kind == "enchant" or kind == "talent" or kind == "mount" or kind == "mountid" then
			return SearchForField("spellID", id);
		elseif kind == "speciesid" or kind == "species" or kind == "battlepet" then
			return SearchForField("speciesID", id);
		elseif kind == "follower" or kind == "followerid" or kind == "garrfollower" then
			return SearchForField("followerID", id);
		elseif kind == "azessence" or kind == "azeriteessenceid" then
			return SearchForField("azeriteEssenceID", id);
		elseif kind == "rfp" or kind == "runeforgepowerid" then
			return SearchForField("runeforgePowerID", id);
		else
			return SearchForField(string.gsub(kind, "id", "ID"), id);
		end
	end
end
local function SearchForMissingItemsRecursively(group, listing)
	if group.visible then
		if (group.collectible or (group.itemID and group.total and group.total > 0)) and (not app.IsBoP(group)) then
			tinsert(listing, group);
		end
		if group.g and group.expanded then
			-- Go through the sub groups and determine if any of them have a response.
			for i, subgroup in ipairs(group.g) do
				SearchForMissingItemsRecursively(subgroup, listing);
			end
		end
	end
end
local function SearchForMissingItems(group)
	local listing = {};
	SearchForMissingItemsRecursively(group, listing);
	return listing;
end
local function SearchForMissingItemNames(group)
	-- Auctionator needs unique Item Names. Nothing else.
	local uniqueNames = {};
	for i,group in ipairs(SearchForMissingItems(group)) do
		local name = group.name;
		if name then uniqueNames[name] = 1; end
	end

	-- Build the array of names.
	local arr = {};
	for key,value in pairs(uniqueNames) do
		tinsert(arr, key);
	end
	return arr;
end
-- Dynamically increments the progress for the parent heirarchy of each collectible search result
local function UpdateSearchResults(searchResults)
	-- app.PrintDebug("UpdateSearchResults",searchResults and #searchResults)
	if searchResults then
		-- Update all the results within visible windows
		local hashes = {};
		local found = {};
		-- Directly update the Source groups of the search results, and collect their hashes for updates in other windows
		for _,result in ipairs(searchResults) do
			hashes[result.hash] = true;
			tinsert(found, result);
		end

		-- loop through visible ATT windows and collect matching groups
		-- app.PrintDebug("Checking Windows...")
		for suffix,window in pairs(app.Windows) do
			-- Collect matching groups from the updating groups from visible windows other than Main list
			if window.Suffix ~= "Prime" and window:IsVisible() then
				-- app.PrintDebug(window.Suffix)
				for _,result in ipairs(searchResults) do
					SearchForSpecificGroups(found, window.data, hashes);
				end
			end
		end

		-- apply direct updates to all found groups
		local Update = app.DirectGroupUpdate;
		-- app.PrintDebug("Updating",#found,"groups")
		for _,o in ipairs(found) do
			Update(o, true);
		end
	end
	-- app.PrintDebug("UpdateSearchResults Done")
end
-- Pulls the field search results for the rawID's and passes the results into UpdateSearchResults
local function UpdateRawIDs(field, ids)
	-- print("UpdateRawIDs",field,ids and #ids)
	if ids and #ids > 0 then
		local groups, append, search = {}, app.ArrayAppend;
		for _,id in ipairs(ids) do
			search = SearchForField(field, id);
			append(groups, search);
		end
		UpdateSearchResults(groups);
	end
end
app.SearchForLink = SearchForLink;

-- Tooltip Functions
-- Consolidated logic for whether a tooltip should include ATT information based on combat & user settings
local function CanAttachTooltips()
	return (not InCombatLockdown() or app.Settings:GetTooltipSetting("DisplayInCombat")) and app.Settings:GetTooltipSettingWithMod("Enabled");
end
local function AttachTooltipRawSearchResults(self, lineNumber, group)
	if group then
		-- app.PrintDebug("Tooltip lines before search results",group.hash,group.tooltipInfo and #group.tooltipInfo)
		-- if app.DEBUG_PRINT then app.PrintTable(group.tooltipInfo) end
		-- If there was info text generated for this search result, then display that first.
		if group.tooltipInfo and #group.tooltipInfo > 0 then
			local left, right;
			for _,entry in ipairs(group.tooltipInfo) do
				left = entry.left;
				right = entry.right;
				if right then
					self:AddDoubleLine(left or " ", right);
				elseif entry.r then
					if entry.wrap then
						self:AddLine(left, entry.r / 255, entry.g / 255, entry.b / 255, 1);
					else
						self:AddLine(left, entry.r / 255, entry.g / 255, entry.b / 255);
					end
				else
					if entry.wrap then
						self:AddLine(left, nil, nil, nil, 1);
					else
						self:AddLine(left);
					end
				end
			end
		end

		-- If the user has Show Collection Progress turned on.
		if group.encounterID then
			self:Show();
		elseif group.collectionText and self:NumLines() > 0 then
			local rightSide = _G[self:GetName() .. "TextRight" .. (lineNumber or 1)];
			if rightSide then
				if self.CloseButton then
					-- dont think the region for the rightText can be modified within the tooltip, so pad instead
					rightSide:SetText(group.collectionText .. "     ");
				else
					rightSide:SetText(group.collectionText);
				end
				rightSide:Show();
			end
		end

		self.AttachComplete = not group.working;
	end
end
local function AttachTooltipSearchResults(self, lineNumber, search, method, ...)
	-- app.PrintDebug("AttachTooltipSearchResults",search,...)
	app.SetSkipPurchases(1);
	AttachTooltipRawSearchResults(self, lineNumber, GetCachedSearchResults(search, method, ...));
	app.SetSkipPurchases(0);
end

-- Map Information Lib
(function()
local math_floor, C_SuperTrack = math.floor, C_SuperTrack;
local __TomTomWaypointCacheIndexY = { __index = function(t, y)
	local o = {};
	rawset(t, y, o);
	return o;
end };
local __TomTomWaypointCacheIndexX = { __index = function(t, x)
	local o = setmetatable({}, __TomTomWaypointCacheIndexY);
	rawset(t, x, o);
	return o;
end };
local __TomTomWaypointCache = setmetatable({}, { __index = function(t, mapID)
	local o = setmetatable({}, __TomTomWaypointCacheIndexX);
	rawset(t, mapID, o);
	return o;
end });
local __TomTomWaypointFirst;
local function AddTomTomWaypointCache(coord, group)
	local mapID = coord[3];
	if mapID then
		__TomTomWaypointCache[mapID][math_floor(coord[1] * 10)][math_floor(coord[2] * 10)][group.key .. ":" .. group[group.key]] = group;
	else
		-- coord[3] not existing is checked by Parser and shouldn't ever happen
		print("Missing mapID for", group.text, coord[1], coord[2], mapID);
	end
end
local function AddTomTomWaypointInternal(group, depth)
	if group.visible then
		if group.plotting then return false; end
		group.plotting = true;
		if group.g then
			depth = depth + 1;
			for _,o in ipairs(group.g) do
				AddTomTomWaypointInternal(o, depth);
			end
			depth = depth - 1;
		end

		local searchResults = ResolveSymbolicLink(group);
		if searchResults then
			depth = depth + 1;
			for _,o in ipairs(searchResults) do
				AddTomTomWaypointInternal(o, depth);
			end
			depth = depth - 1;
		end
		group.plotting = nil;

		if TomTom then
			-- always plot directly clicked otherwise don't plot saved or inaccessible groups
			if depth == 0 or (not group.saved and not group.missingSourceQuests) then
				if group.coords or group.coord then
					if group.coords then
						for _,coord in ipairs(group.coords) do
							AddTomTomWaypointCache(coord, group);
						end
					end
					if group.coord then AddTomTomWaypointCache(group.coord, group); end
				end
			end
		elseif C_SuperTrack then
			-- always plot directly clicked or first available waypoint otherwise don't plot saved or inaccessible groups
			if depth == 0 or (__TomTomWaypointFirst and (not group.saved and not group.missingSourceQuests)) then
				local coord = group.coords and group.coords[1] or group.coord;
				if coord then
					__TomTomWaypointFirst = false;
					C_SuperTrack.SetSuperTrackedUserWaypoint(false);
					C_Map.ClearUserWaypoint();
					-- coord[3] not existing is checked by Parser and shouldn't ever happen
					C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(coord[3] or C_Map.GetBestMapForUnit("player") or 1, coord[1]/100, coord[2]/100));
					C_SuperTrack.SetSuperTrackedUserWaypoint(true);
				end
			end
		end
	end
end
AddTomTomWaypoint = function(group)
	if TomTom or C_SuperTrack then
		__TomTomWaypointFirst = true;
		wipe(__TomTomWaypointCache);
		AddTomTomWaypointInternal(group, 0);
		if TomTom then
			local xnormal;
			for mapID,c in pairs(__TomTomWaypointCache) do
				for x,d in pairs(c) do
					xnormal = x / 1000;
					for y,datas in pairs(d) do
						-- Determine the Root and simplify NPC/Object data.
						-- An NPC/Object can contain all of the other types by reference and don't need individual entries.
						local root,rootByCreatureID,rootByObjectID = {},{},{};
						for key,group in pairs(datas) do
							local creatureID, objectID;
							if group.npcID or group.creatureID then
								creatureID = group.npcID or group.creatureID;
							elseif group.objectID then
								objectID = group.objectID;
							else
								if group.providers then
									for i,provider in ipairs(group.providers) do
										if provider[1] == "n" then
											if provider[2] > 0 then
												creatureID = provider[2];
											end
										elseif provider[1] == "o" then
											if provider[2] > 0 then
												objectID = provider[2];
											end
										end
									end
								end
								if group.qgs then
									local count = #group.qgs;
									if count > 1 and group.coords and #group.coords == count then
										for i=count,1,-1 do
											local coord = group.coords[i];
											if coord[3] == mapID and math_floor(coord[1] * 10) == x and math_floor(coord[2] * 10) == y then
												creatureID = group.qgs[i];
												break;
											end
										end
										if not creatureID then
											creatureID = group.qgs[1];
										end
									else
										creatureID = group.qgs[1];
									end
								end
								if group.crs then
									local count = #group.crs;
									if count > 1 and group.coords and #group.coords == count then
										for i=count,1,-1 do
											local coord = group.coords[i];
											if coord[3] == mapID and math_floor(coord[1] * 10) == x and math_floor(coord[2] * 10) == y then
												creatureID = group.crs[i];
												break;
											end
										end
										if not creatureID then
											creatureID = group.crs[1];
										end
									else
										creatureID = group.crs[1];
									end
								end
							end
							if creatureID then
								if not rootByCreatureID[creatureID] then
									rootByCreatureID[creatureID] = group;
									tinsert(root, app.CreateNPC(creatureID));
								end
							elseif objectID then
								if not rootByObjectID[objectID] then
									rootByObjectID[objectID] = group;
									tinsert(root, app.CreateObject(objectID));
								end
							else
								tinsert(root, group);
							end
						end

						local first = root[1];
						if first then
							local opt = { from = "ATT", persistent = false };
							opt.title = first.text or RETRIEVING_DATA;
							local displayID = GetDisplayID(first);
							if displayID then
								opt.minimap_displayID = displayID;
								opt.worldmap_displayID = displayID;
							end
							if first.icon then
								opt.minimap_icon = first.icon;
								opt.worldmap_icon = first.icon;
							end

							if TomTom.DefaultCallbacks then
								local callbacks = TomTom:DefaultCallbacks();
								callbacks.minimap.tooltip_update = nil;
								callbacks.minimap.tooltip_show = function(event, tooltip, uid, dist)
									tooltip:ClearLines();
									for i,o in ipairs(root) do
										local lineNumber = tooltip:NumLines() + 1;
										tooltip:AddLine(o.text);
										if o.title and not o.explorationID then tooltip:AddLine(o.title); end
										local key = o.key;
										if key == "objectiveID" then
											if o.parent and o.parent.questID then tooltip:AddLine("Objective for " .. o.parent.text); end
										elseif key == "criteriaID" then
											tooltip:AddLine("Criteria for " .. GetAchievementLink(o.achievementID));
										else
											if key == "npcID" then key = "creatureID"; end
											AttachTooltipSearchResults(tooltip, lineNumber, key .. ":" .. o[o.key], SearchForField, key, o[o.key]);
										end
									end
									tooltip:Show();
								end
								callbacks.world.tooltip_update = nil;
								callbacks.world.tooltip_show = callbacks.minimap.tooltip_show;
								opt.callbacks = callbacks;
							end
							TomTom:AddWaypoint(mapID, xnormal, y / 1000, opt);
						end
					end
				end
			end
			TomTom:SetClosestWaypoint();
		end
		if C_SuperTrack and group.questID and C_QuestLog.IsOnQuest(group.questID) then
			C_SuperTrack.SetSuperTrackedQuestID(group.questID);
		end
	else
		app.print("You must have TomTom installed to plot coordinates.");
	end
end
end)();
-- Populates/replaces data within a questObject for displaying in a row
local function PopulateQuestObject(questObject)
	-- cannot do anything on a missing object or questID
	if not questObject or not questObject.questID then return; end

	local questID = questObject.questID;
	-- Check for a Task-specific icon
	local info = C_QuestLog.GetQuestTagInfo(questID);
	-- TODO: eventually handle the reward population async via QUEST_DATA_LOAD_RESULT event trigger somehow

	-- if info then
		-- print("WQ info:",questID);
		-- for k,v in pairs(info) do
			-- print(k,v);
		-- end
		-- print("---");
	-- end
	-- local tagID, tagName, worldQuestType, rarity, isElite, tradeskillLineIndex = ;
	local worldQuestType = info and info.worldQuestType;
	local tagID = info and info.tagID;
	if worldQuestType then
		-- all WQ's on map should be treated as repeatable
		questObject.repeatable = true;
		if worldQuestType == LE_QUEST_TAG_TYPE_PVP or worldQuestType == LE_QUEST_TAG_TYPE_BOUNTY then
			questObject.icon = "Interface\\Icons\\Achievement_PVP_P_09";
		elseif worldQuestType == LE_QUEST_TAG_TYPE_PET_BATTLE then
			questObject.icon = "Interface\\Icons\\PetJournalPortrait";
		elseif worldQuestType == LE_QUEST_TAG_TYPE_PROFESSION then
			questObject.icon = "Interface\\Icons\\Trade_BlackSmithing";
		elseif worldQuestType == LE_QUEST_TAG_TYPE_DUNGEON or tagID == 137 then
			-- questObject.icon = "Interface\\Icons\\Achievement_PVP_P_09";
			-- TODO: Add the relevent dungeon icon. (DONE! IN REWARDS!)
		elseif worldQuestType == LE_QUEST_TAG_TYPE_RAID then
			questObject.isRaid = true;
			-- questObject.icon = "Interface\\Icons\\Achievement_PVP_P_09";
			-- TODO: Add the relevent dungeon icon.
		elseif worldQuestType == LE_QUEST_TAG_TYPE_INVASION or worldQuestType == LE_QUEST_TAG_TYPE_INVASION_WRAPPER then
			questObject.icon = "Interface\\Icons\\achievements_zone_brokenshore";
		--elseif worldQuestType == LE_QUEST_TAG_TYPE_TAG then
			-- completely useless
			--questObject.icon = "Interface\\Icons\\INV_Misc_QuestionMark";
		--elseif worldQuestType == LE_QUEST_TAG_TYPE_NORMAL then
		--	questObject.icon = "Interface\\Icons\\INV_Misc_QuestionMark";
		end
	end

	-- Get time remaining info (only works for World Quests)
	local timeRemaining = C_TaskQuest.GetQuestTimeLeftMinutes(questID);
	if timeRemaining and timeRemaining > 0 then
		local description = BONUS_OBJECTIVE_TIME_LEFT:format(SecondsToTime(timeRemaining * 60));
		if timeRemaining < 30 then
			description = "|cFFFF0000" .. description .. "|r";
		elseif timeRemaining < 120 then
			description = "|cFFFFFF00" .. description .. "|r";
		else
			description = "|cFF008000" .. description .. "|r";
		end
		questObject.timeRemaining = description;
	end

	-- If this is not a metatable yet, create a raw repeatable value for use prior to that
	if not questObject.repeatable and
		(questObject.isDaily or questObject.isWeekly or questObject.isMonthly or questObject.isYearly) then
			questObject.repeatable = true;
	end

	-- Try populating quest rewards
	app.TryPopulateQuestRewards(questObject);
end
-- Returns an Object based on a QuestID a lot of Quest information for displaying in a row
local function GetPopulatedQuestObject(questID)
	local cachedVersion = app.SearchForObject("questID", questID);
	-- either want to duplicate the existing data for this quest, or create new data for a missing quest
	local data = cachedVersion or { questID = questID, _missing = true };
	local questObject = CreateObject(data, true);
	-- if this quest exists but is Sourced under a _missing group, then it is technically missing itself
	questObject._missing = GetRelativeValue(data, "_missing");
	PopulateQuestObject(questObject);
	return questObject;
end
local function ExportDataRecursively(group, indent)
	if group.itemID then return ""; end
	if group.g then
		if group.instanceID then
			EJ_SelectInstance(group.instanceID);
			EJ_SetLootFilter(0, 0);
			EJ_SetSlotFilter(0);
			local str = indent .. "c(" .. group.instanceID .. "--[[" .. select(1, EJ_GetInstanceInfo()) .. "]], {\n";
			for i,subgroup in ipairs(group.g) do
				str = str .. ExportDataRecursively(subgroup, indent .. "\t");
			end
			return str .. indent .. "}),\n"
		end
		if group.difficultyID then
			EJ_SetDifficulty(group.difficultyID);
			EJ_SetLootFilter(0, 0);
			EJ_SetSlotFilter(0);
			local str = indent .. "d(" .. group.difficultyID .. "--[[" .. select(1, GetDifficultyInfo(group.difficultyID)) .. "]], {\n";
			for i,subgroup in ipairs(group.g) do
				str = str .. ExportDataRecursively(subgroup, indent .. "\t");
			end
			return str .. indent .. "}),\n"
		end
		if group.encounterID then
			EJ_SelectEncounter(group.encounterID);
			EJ_SetLootFilter(0, 0);
			EJ_SetSlotFilter(0);
			local str = indent .. "e(" .. group.encounterID .. "--[[" .. select(1, EJ_GetEncounterInfo(group.encounterID)) .. "]], {\n";
			local numLoot = EJ_GetNumLoot();
			for i = 1,numLoot do
				local itemID = EJ_GetLootInfoByIndex(i);
				str = str .. indent .. "\ti(" .. itemID .. "--[[" .. select(1, GetItemInfo(itemID)) .. "]]),\n";
			end
			return str .. indent .. "}),\n"
		end
	end
	return "";
end
local function ExportData(group)
	if group.instanceID then
		EJ_SetLootFilter(0, 0);
		EJ_SetSlotFilter(0);
		SetDataMember("EXPORT_DATA", ExportDataRecursively(group, ""));
	end
end

-- Refresh Functions
do
local function RefreshSavesCallback()
	-- This can be attempted a few times incase data is slow, but not too many times since it's possible to not be saved to any instance
	app.refreshingSaves = app.refreshingSaves or 30;
	-- While the player is still logging in, wait.
	if not app.GUID then
		AfterCombatCallback(RefreshSavesCallback);
		return;
	end

	-- Make sure there's info available to check save data
	local saves = GetNumSavedInstances();
	-- While the player is still waiting for information, wait.
	if saves and saves < 1 and app.refreshingSaves > 0 then
		app.refreshingSaves = app.refreshingSaves - 1;
		AfterCombatCallback(RefreshSavesCallback);
		return;
	end

	-- Too many attempts, so give up
	if app.refreshingSaves <= 0 then
		app.refreshingSaves = nil;
		return;
	end

	-- Cache the lockouts across your account.
	local serverTime = GetServerTime();

	-- Check to make sure that the old instance data has expired
	for guid,character in pairs(ATTCharacterData) do
		local locks = character.Lockouts;
		if locks then
			for name,instance in pairs(locks) do
				local count = 0;
				for difficulty,lock in pairs(instance) do
					if serverTime >= lock.reset then
						-- Clean this up.
						instance[difficulty] = nil;
					else
						count = count + 1;
					end
				end
				if count == 0 then
					-- Clean this up.
					locks[name] = nil;
				end
			end
		end
	end

	-- Update Saved Instances
	local converter = L["SAVED_TO_DJ_INSTANCES"];
	local myLockouts = app.CurrentCharacter.Lockouts;
	for instanceIter=1,saves do
		local name, id, reset, difficulty, locked, _, _, isRaid, _, _, numEncounters = GetSavedInstanceInfo(instanceIter);
		if locked then
			-- Update the name of the instance and cache the locks for this instance
			name = converter[name] or name;
			reset = serverTime + reset;
			local locks = myLockouts[name];
			if not locks then
				locks = {};
				myLockouts[name] = locks;
			end

			-- Create the lock for this difficulty
			local lock = locks[difficulty];
			if not lock then
				lock = { ["id"] = id, ["reset"] = reset, ["encounters"] = {}};
				locks[difficulty] = lock;
			else
				lock.id = id;
				lock.reset = reset;
			end

			-- If this is LFR, then don't share.
			if difficulty == 7 or difficulty == 17 then
				if #lock.encounters == 0 then
					-- Check Encounter locks
					for encounterIter=1,numEncounters do
						local name, _, isKilled = GetSavedInstanceEncounterInfo(instanceIter, encounterIter);
						tinsert(lock.encounters, { ["name"] = name, ["isKilled"] = isKilled });
					end
				else
					-- Check Encounter locks
					for encounterIter=1,numEncounters do
						local name, _, isKilled = GetSavedInstanceEncounterInfo(instanceIter, encounterIter);
						if not lock.encounters[encounterIter] then
							tinsert(lock.encounters, { ["name"] = name, ["isKilled"] = isKilled });
						elseif isKilled then
							lock.encounters[encounterIter].isKilled = true;
						end
					end
				end
			else
				-- Create the pseudo "shared" lock
				local shared = locks["shared"];
				if not shared then
					shared = {};
					shared.id = id;
					shared.reset = reset;
					shared.encounters = {};
					locks["shared"] = shared;

					-- Check Encounter locks
					for encounterIter=1,numEncounters do
						local name, _, isKilled = GetSavedInstanceEncounterInfo(instanceIter, encounterIter);
						tinsert(lock.encounters, { ["name"] = name, ["isKilled"] = isKilled });

						-- Shared Encounter is always assigned if this is the first lock seen for this instance
						tinsert(shared.encounters, { ["name"] = name, ["isKilled"] = isKilled });
					end
				else
					-- Check Encounter locks
					for encounterIter=1,numEncounters do
						local name, _, isKilled = GetSavedInstanceEncounterInfo(instanceIter, encounterIter);
						if not lock.encounters[encounterIter] then
							tinsert(lock.encounters, { ["name"] = name, ["isKilled"] = isKilled });
						elseif isKilled then
							lock.encounters[encounterIter].isKilled = true;
						end
						if not shared.encounters[encounterIter] then
							tinsert(shared.encounters, { ["name"] = name, ["isKilled"] = isKilled });
						elseif isKilled then
							shared.encounters[encounterIter].isKilled = true;
						end
					end
				end
			end
		end
	end

	-- Mark that we're done now.
	app:UpdateWindows();
end
local function RefreshSaves()
	AfterCombatCallback(RefreshSavesCallback);
end
local function RefreshAppearanceSources()
	app.DoRefreshAppearanceSources = nil;
	local collectedSources, brokenUniqueSources = ATTAccountWideData.Sources, ATTAccountWideData.BrokenUniqueSources;
	wipe(collectedSources);
	-- TODO: test C_TransmogCollection.PlayerKnowsSource(sourceID) ?
	-- Simply determine the max known SourceID from ATT cached sources
	if not app.MaxSourceID then
		-- print("Initial Session Refresh")
		local maxSourceID = 0;
		for id,_ in pairs(fieldCache["s"]) do
			-- track the max sourceID so we can evaluate sources not in ATT as well
			if id > maxSourceID then maxSourceID = id; end
		end
		app.MaxSourceID = maxSourceID;
		-- print("MaxSourceID",maxSourceID)
	end
	-- Then evaluate all SourceIDs under the maximum which are known explicitly
	-- print("Completionist Refresh")
	for s=1,app.MaxSourceID do
		-- don't need to check for existing value... everything is cleared beforehand
		if C_TransmogCollection_PlayerHasTransmogItemModifiedAppearance(s) then
			rawset(collectedSources, s, 1);
		end
	end
	-- print("Completionist Refresh done")
	-- Additionally, for Unique Mode we can grant collection of Appearances which match the Visual of explicitly known SourceIDs if other criteria (Race/Faction/Class) match as well using ATT info
	if not app.Settings:Get("Completionist") then
		-- print("Unique Refresh")
		local currentCharacterOnly = app.Settings:Get("MainOnly");
		for s=1,app.MaxSourceID do
			-- for each known source
			if rawget(collectedSources, s) == 1 then
				-- collect shared visual sources
				app.MarkUniqueCollectedSourcesBySource(s, currentCharacterOnly);
			elseif brokenUniqueSources then
				-- special reverse-check-logic for unknown SourceID's whose VisualID does not return the SourceID from C_TransmogCollection_GetAllAppearanceSources(VisualID)
				-- and haven't already been marked as unique-collected
				if rawget(brokenUniqueSources, s) and not rawget(collectedSources, s) then
					local sInfo = C_TransmogCollection_GetSourceInfo(s);
					if app.ItemSourceFilter(sInfo) then
						-- print("Fixed Unique SourceID Collected",s)
						rawset(collectedSources, s, 2);
					end
				end
			end
		end
		-- print("Unique Refresh done")
	end
end
app.RefreshAppearanceSources = RefreshAppearanceSources;
local function RefreshCollections()
	app.print(L["REFRESHING_COLLECTION"]);
	while InCombatLockdown() do coroutine.yield(); end

	-- Harvest Illusion Collections
	local collectedIllusions = ATTAccountWideData.Illusions;
	for _,illusion in ipairs(C_TransmogCollection.GetIllusions()) do
		if rawget(illusion, "isCollected") then rawset(collectedIllusions, illusion.sourceID, 1); end
	end
	coroutine.yield();

	-- Harvest Title Collections
	local acctTitles, charTitles, charGuid = ATTAccountWideData.Titles, {}, app.GUID;
	for i=1,GetNumTitles(),1 do
		if IsTitleKnown(i) then
			if not acctTitles[i] then print("Added Title",app:Linkify(i,app.Colors.ChatLink,"search:titleID:"..i)) end
			rawset(charTitles, i, 1);
		end
	end
	app.CurrentCharacter.Titles = charTitles;
	coroutine.yield();

	-- Refresh Mounts / Pets
	local acctSpells, charSpells = ATTAccountWideData.Spells, app.CurrentCharacter.Spells;
	local C_MountJournal_GetMountInfoByID = C_MountJournal.GetMountInfoByID;
	for _,mountID in ipairs(C_MountJournal.GetMountIDs()) do
		local _, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal_GetMountInfoByID(mountID);
		if spellID then
			if isCollected then
				if not acctSpells[spellID] then print("Added Mount",app:Linkify(spellID,app.Colors.ChatLink,"search:spellID:"..spellID)) end
				rawset(charSpells, spellID, 1);
			else
				rawset(charSpells, spellID, nil);
			end
		end
	end
	coroutine.yield();

	-- Refresh Factions
	local Search = app.SearchForObject;
	local faction;
	wipe(app.CurrentCharacter.Factions);
	for factionID,_ in pairs(fieldCache["factionID"]) do
		faction = Search("factionID", factionID);
		-- simply reference the .saved property of each known Faction to re-calculate the character value
		if faction and faction.saved then end
	end
	coroutine.yield();

	-- Harvest Item Collections that are used by the addon.
	app:GetDataCache();
	coroutine.yield();

	-- Refresh Toys from Cache
	local acctToys = ATTAccountWideData.Toys;
	for id,_ in pairs(fieldCache["toyID"]) do
		if PlayerHasToy(id) then
			if not acctToys[id] then print("Added Toy",app:Linkify(id,app.Colors.ChatLink,"search:toyID:"..id)) end
			rawset(acctToys, id, 1);
		else
			-- remove Toys that the account doesnt actually have
			if acctToys[id] then print("Removed Toy",app:Linkify(id,app.Colors.ChatLink,"search:toyID:"..id)) end
			acctToys[id] = nil;
		end
	end
	coroutine.yield();

	-- Refresh RuneforgeLegendaries from Cache
	local acctRFLs = ATTAccountWideData.RuneforgeLegendaries;
	local C_LegendaryCrafting_GetRuneforgePowerInfo = C_LegendaryCrafting.GetRuneforgePowerInfo;
	local state;
	for id,_ in pairs(fieldCache["runeforgePowerID"]) do
		state = (C_LegendaryCrafting_GetRuneforgePowerInfo(id) or app.EmptyTable).state;
		if state == 0 then
			if not acctRFLs[id] then print("Added Runeforge Power",app:Linkify(id,app.Colors.ChatLink,"search:runeforgePowerID:"..id)) end
			rawset(acctRFLs, id, 1);
		else
			-- remove RFLs that the account doesnt actually have
			if acctRFLs[id] then print("Removed Runeforge Power",app:Linkify(id,app.Colors.ChatLink,"search:runeforgePowerID:"..id)) end
			acctRFLs[id] = nil;
		end
	end
	coroutine.yield();

	-- Refresh Achievements
	RefreshAchievementCollection();
	coroutine.yield();

	-- Double check if any once-per-account quests which haven't been detected as being completed are completed by this character
	local acctQuests, oneTimeQuests = ATTAccountWideData.Quests, ATTAccountWideData.OneTimeQuests;
	for questID,questGuid in pairs(oneTimeQuests) do
		-- If this Character has the Quest completed and it is not marked as completed for Account or not for specific Character
		if CompletedQuests[questID] then
			-- Throw up a warning to report if this was already completed by another character
			if questGuid and questGuid ~= charGuid then
				app.PrintDebug("One-Time-Quest ID " .. app:Linkify(questID,app.Colors.ChatLink,"search:questID:"..questID) .. " was previously marked as completed, but is also completed on the current character!");
			end
			-- Mark the quest as completed for the Account
			acctQuests[questID] = 1;
			-- Mark the character which completed the Quest
			oneTimeQuests[questID] = charGuid;
		end
	end
	coroutine.yield();

	app:RecalculateAccountWideData();

	-- Refresh Sources from Cache if tracking Transmog
	if app.DoRefreshAppearanceSources or app.Settings:Get("Thing:Transmog") then
		RefreshAppearanceSources();
	end
	coroutine.yield();

	-- Need to update the Settings window as well if User does not have auto-refresh for Settings
	if app.Settings:Get("Skip:AutoRefresh") or app.Settings.NeedsRefresh then
		app.Settings:UpdateMode("FORCE");
	else
		app:RefreshData(false, false, true);
	end

	-- Wait for refresh to actually finish
	while app.refreshDataQueued do coroutine.yield(); end

	-- Report success.
	app.print(L["DONE_REFRESHING"]);
end
app.ToggleMainList = function()
	app:GetWindow("Prime"):Toggle();
end
app.RefreshCollections = function()
	StartCoroutine("RefreshingCollections", RefreshCollections);
end
app.RefreshSaves = RefreshSaves;
end -- Refresh Functions


local npcQuestsCache = {}
function app.IsNPCQuestGiver(self, npcID)
	if not npcID then return false; end
	if npcQuestsCache[npcID] ~= nil then
		return npcQuestsCache[npcID];
	else
		local group = app.SearchForField("creatureID", npcID);
		if group then
			for _,v in pairs(group) do
				if v.visible and v.questID then
					npcQuestsCache[npcID] = true;
					return true;
				end
			end
		end

		npcQuestsCache[npcID] = false;
		return false;
	end
end

local function AttachTooltip(self)
	-- app.PrintDebug("AttachTooltip-Processing",self.AllTheThingsProcessing);
	local numLines = self:NumLines();
	-- app.PrintDebug("AttachTooltip",numLines,"i:",self:GetItem(),"u:",self:GetUnit(),"s:",self:GetSpell())
	if numLines < 1 then
		return false
	end

	-- Does the tooltip have an owner?
	local owner = self:GetOwner();
	if owner then
		if owner.SpellHighlightTexture then
			-- Actionbars, don't want that.
			return true;
		end
		if owner.cooldownWrapper then
			local parent = owner:GetParent();
			if parent then
				parent = parent:GetParent();
				if parent and parent.fanfareToys then
					-- Toy Box, don't want that.
					return true;
				end
			end
		end
		-- this is already covered by a default in-game tooltip line:
		-- AUCTION_HOUSE_BUCKET_VARIATION_EQUIPMENT_TOOLTIP = "Items in this group may vary in stats and appearance. Check the auction's tooltip before buying.";
		-- if owner.useCircularIconBorder and not self.AllTheThingsProcessing then
		-- 	-- print("AH General Item Tooltip")
		-- 	-- Generalized tooltip hover of a selected Auction Item -- not always accurate to the actual Items for sale
		-- 	self:AddLine(L["AUCTION_GENERALIZED_ITEM_WARNING"]);
		-- end
	end

	if CanAttachTooltips() then
		-- check what this tooltip is currently displaying, and keep that reference
		local link, target, spellID = select(2, self:GetItem());
		if link and not link:find("%[]") then
			if self.AllTheThingsProcessing and self.AllTheThingsProcessing == link then
				return true;
			else
				self.AllTheThingsProcessing = link;
			end
		else
			target = select(2, self:GetUnit());
			if target then
				if self.AllTheThingsProcessing and self.AllTheThingsProcessing == target then
					return true;
				else
					self.AllTheThingsProcessing = target;
				end
			else
				spellID = select(2, self:GetSpell());
				if spellID then
					if self.AllTheThingsProcessing and self.AllTheThingsProcessing == spellID then
						return true;
					else
						self.AllTheThingsProcessing = spellID;
					end
				end
			end
		end

		--[[--]
		-- Debug all of the available fields on the tooltip.
		app.PrintDebug("Tooltip Data")
		for i,j in pairs(self) do
			app.PrintDebug(i,type(j),j);
		end
		-- self:Show();
		-- self:AddDoubleLine("GetItem", tostring(select(2, self:GetItem()) or "nil"));
		-- self:AddDoubleLine("GetSpell", tostring(select(2, self:GetSpell()) or "nil"));
		-- self:AddDoubleLine("GetUnit", tostring(select(2, self:GetUnit()) or "nil"));
		--]]--

		-- Does the tooltip have a target?
		if self.AllTheThingsProcessing and target then
			-- Yes.
			target = UnitGUID(target);
			if target then
				local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-",target);
				-- print(target, type, npc_id);
				if type == "Player" then
					if target == "Player-76-0895E23B" then
						local leftSide = _G[self:GetName() .. "TextLeft1"];
						if leftSide then
							leftSide:SetText("|cffff8000" .. leftSide:GetText() .. "|r");
						end
						local rightSide = _G[self:GetName() .. "TextRight2"];
						leftSide = _G[self:GetName() .. "TextLeft2"];
						if leftSide and rightSide then
							leftSide:SetText(L["TITLE"]);
							leftSide:Show();
							rightSide:SetText("Author");
							rightSide:Show();
						else
							self:AddDoubleLine(L["TITLE"], "Author");
						end
					end
				elseif type == "Creature" or type == "Vehicle" then
					if app.Settings:GetTooltipSetting("creatureID") then self:AddDoubleLine(L["CREATURE_ID"], tostring(npc_id)); end
					AttachTooltipSearchResults(self, 1, "creatureID:" .. npc_id, SearchForField, "creatureID", tonumber(npc_id));
				end
			end
			return true;
		end

		-- Does the tooltip have a spell? [Mount Journal, Action Bars, etc]
		if self.AllTheThingsProcessing and spellID then
			AttachTooltipSearchResults(self, 1, "spellID:" .. spellID, SearchForField, "spellID", spellID);
			return true;
		end

		-- Does the tooltip have an itemlink?
		--local link = select(2, self:GetItem());
		if self.AllTheThingsProcessing and link then
			-- local _, _, Color, Ltype, Id, Enchant, Gem1, Gem2, Gem3, Gem4, Suffix, Unique, LinkLvl, reforging, Name = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?");
			-- local _, _, _, Ltype, Id = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*):?(%d*):?(%d*):?(%-?%d*):?(%-?%d*):?(%d*):?(%d*)|?h?%[?([^%[%]]*)%]?|?h?|?r?");
			-- local _, _, _, Ltype, Id = string.find(link, "|?c?f?f?(%x*)|?H?([^:]*):?(%d+):?(%d*):?(%d*):?(%d*)");
			-- print(Ltype,Id);
			--[[
			local itemString = string.match(link, "item[%-?%d:]+");
			-- mythic keystones have no itemID ... ?? so itemString is nil here
			local itemID = GetItemInfoInstant(itemString);
			if not AllTheThingsAuctionData then return end;
			if AllTheThingsAuctionData[itemID] then
				self:AddLine("ATT -> " .. BUTTON_LAG_AUCTIONHOUSE .. " -> " .. GetCoinTextureString(AllTheThingsAuctionData[itemID]["price"]));
			end--]]
			-- app.PrintDebug("Search Item",link);
			local mohIndex = link:find("item:137642");
			if mohIndex and mohIndex > 0 then -- skip Mark of Honor for now
				AttachTooltipSearchResults(self, 1, link, app.EmptyFunction, "itemID", 137642);
			else
				AttachTooltipSearchResults(self, 1, link, SearchForLink, link);
			end
			return true;
		end

		-- Does this tooltip have a 'shown Thing'
		-- if self.shownThing then
			-- -- local search, id = self.shownThing[1], self.shownThing[2];
			-- -- print("shown Thing", search, id);
			-- -- AttachTooltipSearchResults(self, 1, search .. ":" .. id, SearchForField, search, id);
			-- self.AllTheThingsProcessing = nil;
			-- self.shownThing = nil;
		-- end

		-- Does the tooltip have an owner?
		if owner then
			-- print("AttachTooltip-HasOwner");
			-- If the owner has a ref, it's an ATT row. Ignore it.
			if owner.ref then
				-- print("owner-ATT-row");
				return true; end

			--[[--
			-- Debug all of the available fields on the owner.
			self:AddDoubleLine("GetOwner", tostring(owner:GetName()));
			for i,j in pairs(owner) do
				self:AddDoubleLine(tostring(i), tostring(j));
			end
			self:Show();
			--]]--

			local encounterID = owner.encounterID;
			if encounterID and not owner.itemID then
				if app.Settings:GetTooltipSetting("encounterID") then self:AddDoubleLine(L["ENCOUNTER_ID"], tostring(encounterID)); end
				AttachTooltipSearchResults(self, 1, "encounterID:" .. encounterID, SearchForField, "encounterID", tonumber(encounterID));
				return true;
			end

			local gf;
			if owner.lastNumMountsNeedingFanfare then
				-- Collections
				gf = app:GetWindow("Prime").data;
			elseif owner.NewAdventureNotice then
				-- Adventure Guide
				gf = app:GetWindow("Prime").data.g[1];
			elseif owner.tooltipText then
				if type(owner.tooltipText) == "string" then
					if owner.tooltipText == DUNGEONS_BUTTON then
						-- Group Finder
						gf = app:GetWindow("Prime").data.g[4];
					elseif owner.tooltipText == BLIZZARD_STORE then
						-- Shop
						gf = app:GetWindow("Prime").data.g[16];
					elseif string.sub(owner.tooltipText, 1, string.len(ACHIEVEMENT_BUTTON)) == ACHIEVEMENT_BUTTON then
						-- Achievements
						gf = app:GetWindow("Prime").data.g[5];
					end
				end
			end
			if gf then
				app.noDepth = true;
				AttachTooltipSearchResults(self, 1, owner:GetName(), (function() return gf; end), owner:GetName(), 1);
				app.noDepth = nil;
				self:Show();
			end
		end

		-- Addons Menu?
		if numLines == 2 then
			local leftSide = _G[self:GetName() .. "TextLeft1"];
			if leftSide and leftSide:GetText() == "AllTheThings" then
				local reference = app:GetDataCache();
				self:ClearLines();
				self:AddDoubleLine(L["TITLE"], GetProgressColorText(reference.progress, reference.total), 1, 1, 1);
				self:AddDoubleLine(app.Settings:GetModeString(), app.GetNumberOfItemsUntilNextPercentage(reference.progress, reference.total), 1, 1, 1);
				self:AddLine(reference.description, 0.4, 0.8, 1, 1);
				return true;
			end
		end
		-- print("AttachTooltip-Return");
	end
end
local function AttachBattlePetTooltip(self, data, quantity, detail)
	if not data or data.att or not data.speciesID then return end
	data.att = 1;

	-- GameTooltip_ShowCompareItem
	local searchResults = SearchForField("speciesID", data.speciesID);
	local owned = C_PetJournal.GetOwnedBattlePetString(data.speciesID);
	self.Owned:SetText(owned);
	if owned == nil then
		if self.Delimiter then
			-- if .Delimiter is present it requires special handling (FloatingBattlePetTooltip)
			self:SetSize(260,150 + h)
			self.Delimiter:ClearAllPoints()
			self.Delimiter:SetPoint("TOPLEFT",self.SpeedTexture,"BOTTOMLEFT",-6,-5)
		else
			self:SetSize(260,122)
		end
	else
		local h = self.Owned:GetHeight() or 0;
		if self.Delimiter then
			self:SetSize(260,150 + h)
			self.Delimiter:ClearAllPoints()
			self.Delimiter:SetPoint("TOPLEFT",self.SpeedTexture,"BOTTOMLEFT",-6,-(5 + h))
		else
			self:SetSize(260,122 + h)
		end
	end
	self:Show()
	return true;
end
local function ClearTooltip(self)
	-- app.PrintDebug("Clear Tooltip");
	self.AllTheThingsProcessing = nil;
	self.AttachComplete = nil;
	self.MiscFieldsComplete = nil;
	self.UpdateTooltip = nil;
end

-- Tooltip Hooks
(function()
	local C_CurrencyInfo_GetCurrencyListInfo = C_CurrencyInfo.GetCurrencyListInfo;
	local C_CurrencyInfo_GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo;
	--[[
	for name,func in pairs(getmetatable(GameTooltip).__index) do
		print(name);
		if type(func) == "function" and name ~= "IsOwned" and name ~= "GetOwner" then
			(function(n,f) GameTooltip[n] = function(...)
					print("GameTooltip", n, ...);
					return f(...);
				end
			end)(name, func);
		end
	end
	]]--
	local GameTooltip_SetCurrencyByID = GameTooltip.SetCurrencyByID;
	GameTooltip.SetCurrencyByID = function(self, currencyID, count)
		-- print("set currency tooltip", currencyID, count)
		-- Make sure to call to base functionality
		GameTooltip_SetCurrencyByID(self, currencyID, count);
		if CanAttachTooltips() then
			AttachTooltipSearchResults(self, 1, "currencyID:" .. currencyID, SearchForField, "currencyID", currencyID);
			if app.Settings:GetTooltipSetting("currencyID") then self:AddDoubleLine(L["CURRENCY_ID"], tostring(currencyID)); end
			self:Show();
		end
	end
	local GameTooltip_SetCurrencyToken = GameTooltip.SetCurrencyToken;
	GameTooltip.SetCurrencyToken = function(self, tokenID)
		-- app.PrintDebug("GameTooltip.SetCurrencyToken", tokenID)
		-- this only runs once per tooltip show
		-- Make sure to call to base functionality
		GameTooltip_SetCurrencyToken(self, tokenID);
		if CanAttachTooltips() then
			-- Determine what kind of list data this is. (Blizzard is whack and using this API call for headers too...)
			local info = C_CurrencyInfo_GetCurrencyListInfo(tokenID);
			local name, isHeader = info.name, info.isHeader;
			-- print(tokenID, name, isHeader);
			-- app.PrintTable(info)
			if not isHeader then
				-- Determine which currencyID is the one that we're dealing with.
				-- TODO: also need to check 'currencyIDAsCost'
				local cache = SearchForFieldContainer("currencyID");
				if cache then
					-- We only care about currencies in the addon at the moment.
					for currencyID,_ in pairs(cache) do
						-- Compare the name of the currency vs the name of the token
						local currencyInfo = C_CurrencyInfo_GetCurrencyInfo(currencyID);
						if currencyInfo and currencyInfo.name == name then
							-- self.shownThing = { "currencyID", currencyID };
							-- make sure tooltip refreshes
							self.AllTheThingsProcessing = nil;
							AttachTooltipSearchResults(self, 1, "currencyID:" .. currencyID, SearchForField, "currencyID", currencyID);
							if app.Settings:GetTooltipSetting("currencyID") then self:AddDoubleLine(L["CURRENCY_ID"], tostring(currencyID)); end
							self:Show();
							return;
						end
					end
				end
				-- move on to currencyIDAsCost
				cache = SearchForFieldContainer("currencyIDAsCost");
				if cache then
					-- We only care about currencies in the addon at the moment.
					for currencyID,_ in pairs(cache) do
						-- Compare the name of the currency vs the name of the token
						local currencyInfo = C_CurrencyInfo_GetCurrencyInfo(currencyID);
						if currencyInfo and currencyInfo.name == name then
							-- self.shownThing = { "currencyID", currencyID };
							-- make sure tooltip refreshes
							self.AllTheThingsProcessing = nil;
							AttachTooltipSearchResults(self, 1, "currencyID:" .. currencyID, SearchForField, "currencyID", currencyID);
							if app.Settings:GetTooltipSetting("currencyID") then self:AddDoubleLine(L["CURRENCY_ID"], tostring(currencyID)); end
							self:Show();
						return;
						end
					end
				end
			end
		end
	end
	local GameTooltip_SetLFGDungeonReward = GameTooltip.SetLFGDungeonReward;
	GameTooltip.SetLFGDungeonReward = function(self, dungeonID, rewardID)
		-- Only call to the base functionality if it is unknown.
		GameTooltip_SetLFGDungeonReward(self, dungeonID, rewardID);
		if CanAttachTooltips() then
			local name, texturePath, quantity, isBonusReward, spec, itemID = GetLFGDungeonRewardInfo(dungeonID, rewardID);
			if itemID then
				if spec == "item" then
					AttachTooltipSearchResults(self, 1, "itemID:" .. itemID, SearchForField, "itemID", itemID);
					self:Show();
				elseif spec == "currency" then
					AttachTooltipSearchResults(self, 1, "currencyID:" .. itemID, SearchForField, "currencyID", itemID);
					self:Show();
				end
			end
		end
	end
	local GameTooltip_SetLFGDungeonShortageReward = GameTooltip.SetLFGDungeonShortageReward;
	GameTooltip.SetLFGDungeonShortageReward = function(self, dungeonID, shortageSeverity, lootIndex)
		-- Only call to the base functionality if it is unknown.
		GameTooltip_SetLFGDungeonShortageReward(self, dungeonID, shortageSeverity, lootIndex);
		if CanAttachTooltips() then
			local name, texturePath, quantity, isBonusReward, spec, itemID = GetLFGDungeonShortageRewardInfo(dungeonID, shortageSeverity, lootIndex);
			if itemID then
				if spec == "item" then
					AttachTooltipSearchResults(self, 1, "itemID:" .. itemID, SearchForField, "itemID", itemID);
					self:Show();
				elseif spec == "currency" then
					AttachTooltipSearchResults(self, 1, "currencyID:" .. itemID, SearchForField, "currencyID", itemID);
					self:Show();
				end
			end
		end
	end
	--[[
	local GameTooltip_SetToyByItemID = GameTooltip.SetToyByItemID;
	GameTooltip.SetToyByItemID = function(self, itemID)
		GameTooltip_SetToyByItemID(self, itemID);
		if CanAttachTooltips() then
			AttachTooltipSearchResults(self, 1, "itemID:" .. itemID, SearchForField, "itemID", itemID);
			self:Show();
		end
	end
	]]--

	-- Paragon Hook
	-- local paragonCacheID = {
		-- Paragon Cache Rewards
		-- [QuestID] = [ItemCacheID"]	-- Faction // Quest Title
		-- [54454] = 166300,	-- 7th Legion // Supplies from the 7th Legion
		-- [48976] = 152922,	-- Argussian Reach // Paragon of the Argussian Reach
		-- [46777] = 152108,	-- Armies of Legionfall // The Bounties of Legionfall
		-- [48977] = 152923,	-- Army of the Light // Paragon of the Army of the Light
		-- [54453] = 166298,	-- Champions of Azeroth // Supplies from Magni
		-- [46745] = 152102,	-- Court of Farondis // Supplies from the Court
		-- [46747] = 152103,	-- Dreamweavers // Supplies from the Dreamweavers
		-- [46743] = 152104,	-- Highmountain Tribes // Supplies from Highmountain
		-- [54455] = 166299,	-- Honorbound // Supplies from the Honorbound
		-- [54456] = 166297,	-- Order of Embers // Supplies from the Order of Embers
		-- [54458] = 166295,	-- Proudmoore Admiralty // Supplies from the Proudmoore Admiralty
		-- [54457] = 166294,	-- Storm's Wake // Supplies from Storm's Wake
		-- [54460] = 166282,	-- Talanji's Expedition // Supplies from Talanji's Expedition
		-- [46748] = 152105,	-- The Nightfallen // Supplies from the Nightfallen
		-- [46749] = 152107,	-- The Wardens // Supplies from the Wardens
		-- [54451] = 166245,	-- Tortollan Seekers // Baubles from the Seekers
		-- [46746] = 152106,	-- Valarjar // Supplies from the Valarjar
		-- [54461] = 166290,	-- Voldunai // Supplies from the Voldunai
		-- [54462] = 166292,	-- Zandalari Empire // Supplies from the Zandalari Empire
		-- [55976] = 169939,	-- Waveblade Ankoan // Supplies From the Waveblade Ankoan
		-- [53982] = 169940,	-- Unshackled // Supplies From The Unshackled
		-- [55348] = 170061,	-- Rustbolt // Supplies from the Rustbolt Resistance
		-- [58096] = 174483,	-- Rajani // Supplies from the Rajani
		-- [58097] = 174484,	-- Uldum Accord // Supplies from the Uldum Accord
		-- [61095] = 180646,	-- Undying Army // Supplies from The Undying Army
		-- [61098] = 180649,	-- Wild Hunt // Supplies from The Wild Hunt
		-- [61100] = 180648,	-- Court of Harvesters // Supplies from the Court of Harvesters
		-- [61097] = 180647,	-- The Ascended // Supplies from The Ascended
	-- };
	-- hooksecurefunc("ReputationParagonFrame_SetupParagonTooltip",function(frame)
		-- print("ReputationParagonFrame_SetupParagonTooltip")
		-- Let's make sure the user isn't in combat and if they are do they have In Combat turned on.  Finally check to see if Tootltips are turned on.
		-- if CanAttachTooltips() then
			-- Source: //Interface//FrameXML//ReputationFrame.lua Line 360
			-- Using hooksecurefunc because of how Blizzard coded the frame.  Couldn't get GameTooltip to work like the above ones.
			-- //Interface//FrameXML//ReputationFrame.lua Segment code
			--[[
				function ReputationParagonFrame_SetupParagonTooltip(frame)
					EmbeddedItemTooltip.owner = frame;
					EmbeddedItemTooltip.factionID = frame.factionID;

					local factionName, _, standingID = GetFactionInfoByID(frame.factionID);
					local gender = UnitSex("player");
					local factionStandingtext = GetText("FACTION_STANDING_LABEL"..standingID, gender);
					local currentValue, threshold, rewardQuestID, hasRewardPending, tooLowLevelForParagon = C_Reputation.GetFactionParagonInfo(frame.factionID);

					if ( tooLowLevelForParagon ) then
						EmbeddedItemTooltip:SetText(PARAGON_REPUTATION_TOOLTIP_TEXT_LOW_LEVEL);
					else
						EmbeddedItemTooltip:SetText(factionStandingtext);
						local description = PARAGON_REPUTATION_TOOLTIP_TEXT:format(factionName);
						if ( hasRewardPending ) then
							local questIndex = GetQuestLogIndexByID(rewardQuestID);
							local text = GetQuestLogCompletionText(questIndex);
							if ( text and text ~= "" ) then
								description = text;
							end
						end
						EmbeddedItemTooltip:AddLine(description, HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g, HIGHLIGHT_FONT_COLOR.b, 1);
						if ( not hasRewardPending ) then
							local value = mod(currentValue, threshold);
							-- show overflow if reward is pending
							if ( hasRewardPending ) then
								value = value + threshold;
							end
							GameTooltip_ShowProgressBar(EmbeddedItemTooltip, 0, threshold, value, REPUTATION_PROGRESS_FORMAT:format(value, threshold));
						end
						GameTooltip_AddQuestRewardsToTooltip(EmbeddedItemTooltip, rewardQuestID);
					end
					EmbeddedItemTooltip:Show();
				end
			--]]
			-- local paragonQuestID = select(3, C_Reputation.GetFactionParagonInfo(frame.factionID));
			-- print("info",frame.factionID,paragonQuestID,C_Reputation.GetFactionParagonInfo(frame.factionID))
			-- if paragonQuestID then
			-- 	local itemID = paragonCacheID[paragonQuestID];
			-- 	print("itemID",itemID)
			-- 	if itemID then
			-- 		local link = select(2, GetItemInfo(itemID));
			-- 		print("link",link)
			-- 		if link then
			-- 			-- Attach tooltip to the Paragon Frame
			-- 			-- GameTooltip:SetOwner(EmbeddedItemTooltip, "ANCHOR_NONE")
			-- 			-- GameTooltip:SetPoint("TOPLEFT", EmbeddedItemTooltip, "TOPRIGHT");
			-- 			GameTooltip:SetHyperlink(link);
			-- 		end
			-- 	end
			-- end
	-- 	end
	-- end);

	-- Hide Paragon Tooltip when cleared
	-- hooksecurefunc("ReputationParagonFrame_OnLeave",function(self)
	-- 	GameTooltip:Hide();
	-- end);
end)();

-- Lib Helpers
(function()
-- Represents non-nil default values which are valid for all Objects
local ObjectDefaults = {
	["progress"] = 0,
	["total"] = 0,
};
local GetTimePreciseSec = GetTimePreciseSec;
local ObjectFunctions = {
	-- cloned groups will not directly have a parent, but they will instead have a sourceParent, so fill in with that instead
	["parent"] = function(t)
		return t.sourceParent;
	end,
	-- way easier to just be able to dynamically reference a hash whenever instead of needing to ensure it is created first
	["hash"] = function(t)
		return app.CreateHash(t);
	end,
	-- modItemID doesn't exist for Items which NEVER use a modID or bonusID (illusions, music rolls, mounts, etc.)
	["modItemID"] = function(t)
		return t.itemID;
	end,
	-- default 'text' should be the colorized 'name'
	["text"] = function(t)
		return t.name and app.TryColorizeName(t, t.name) or t.link;
	end,
	-- the total cost of a Thing is based on it being collectible as a cost or not
	["costTotal"] = function(t)
		return t.collectibleAsCost and 1 or 0;
	end,
	-- the cost progress is currently always 0 since it is not considered a cost once it's no longer needed
	["costProgress"] = function(t)
		return 0;
	end,
};
local objFunc;
-- Creates a Base Object Table which will evaluate the provided set of 'fields' (each field value being a keyed function)
app.BaseObjectFields = not app.__perf and function(fields, type)
	-- if not type then app.PrintTable(fields); app.report("Every Object requires a Type!"); end
	if fields.__type then return fields; end

	fields.__type = function() return type; end;
	fields.__index = function(t, key)
		objFunc = rawget(fields, key) or rawget(ObjectFunctions, key);
		if objFunc then return objFunc(t); end
		-- use default key value if existing
		return rawget(ObjectDefaults, key);
	end;
	-- app.PrintDebug("BaseObjectFields",type,fields)
	return fields;
end
-- special performance tracking function for object properties
or
function(fields, type)
	if fields.__type then return fields; end

	-- init table for this object type
    if type and not app.__perf[type] then
        app.__perf[type] = {};
    end

	fields.__type = function() return type; end;
	fields.__index = function(t, key)
		local typeData, result = rawget(app.__perf, type);
		local now = GetTimePreciseSec();
		objFunc = rawget(fields, key) or rawget(ObjectFunctions, key);
		if objFunc then
			result = objFunc(t);
			key = tostring(key);
		else
			result = rawget(ObjectDefaults, key);
			key = tostring(key).."_miss";
		end
		if typeData then
			rawset(typeData, key, (rawget(typeData, key) or 0) + 1);
			rawset(typeData, key.."_Time", (rawget(typeData, key.."_Time") or 0) + (GetTimePreciseSec() - now));
		end
		return result;
	end;
	return fields;
end
-- Create a local cache table which can be used by a Type class of a Thing to easily store information based on a unique key field for any Thing object of that Type
app.CreateCache = function(idField)
	local cache = {};
	cache.GetCached = function(t)
		local id = t[idField];
		if id then
			if not rawget(cache, id) then rawset(cache, id, {}); end
			return rawget(cache, id), id;
		end
	end;
	cache.GetCachedField = function(t, field, default_function)
		--[[ -- Debug Prints
		local _t, id = cache.GetCached(t);
		if _t[field] then
			print("GetCachedField",id,field,_t[field]);
		end
		--]]
		local _t = cache.GetCached(t);
		if _t then
			-- set a default provided cache value if any default function was provided and evalutes to a value
			if not rawget(_t, field) and default_function then
				local defVal = default_function(t, field);
				if defVal then rawset(_t, field, defVal); end
			end
			return rawget(_t, field);
		end
	end;
	cache.SetCachedField = function(t, field, value)
		--[[ Debug Prints
		local _t, id = cache.GetCached(t);
		if _t[field] then
			print("SetCachedField",id,field,"Old",t[field],"New",value);
		else
			print("SetCachedField",id,field,"New",value);
		end
		--]]
		local _t = cache.GetCached(t);
		if _t then rawset(_t, field, value);
		else
			print("Failed to get cache table using",idField)
			print(t.__type,field,value)
			app.PrintTable(t)
		end
	end;
	return cache;
end
-- Function which returns both collectible/collected based on a given 'ref' Thing, which has been previously determined as a
-- possible collectible without regard to filtering
local function CheckCollectible(ref)
	-- don't include groups which do not meet the current filter requirements
	if app.RecursiveGroupRequirementsFilter(ref) then
		-- app.PrintDebug("CheckCollectible",ref.hash)
		local total = ref.total;
		-- Used as a cost for something which has an incomplete progress
		if total and total > 0 then
			-- app.PrintDebug("Cost Required via Total/Prog",ref.hash)
			return true,ref.progress == total;
		-- Used as a cost for something which is collectible itself and not collected
		elseif ref.collectible then
			-- app.PrintDebug("Cost Required via Collectible",ref.hash)
			return true,ref.collected;
		-- Used as a cost for something which is collectible as a cost itself and not collected
		elseif ref.collectibleAsCost then
			-- app.PrintDebug("Cost Required via collectibleAsCost",ref.hash)
			return true;	-- we never have 'collected costs'
		end
		-- If this group has sub-groups and not yet updated, then update this group and check the total to see if it has collectibles
		if ref.g and (total or 0) == 0 then
			-- checking last update time is needed for groups which have a cost but nothing actually collectible due to filters... total is 0
			local lastUpdate = ref._LastUpdateTime;
			-- app.PrintDebug("Updating sub-groups...",ref.hash)
			-- do an Update pass for the ref if necessary
			if not lastUpdate or lastUpdate < app._LastUpdateTime then
				ref._LastUpdateTime = app._LastUpdateTime;
				app.TopLevelUpdateGroup(ref);
				-- app.PrintDebug("Updated sub-groups",ref.hash,ref.progress,ref.total,ref._LastUpdateTime,"<=",app._LastUpdateTime)
				-- app.PrintTable(ref)
				-- raw sub-groups have something collectible, so return
				if total and ref.progress < total then
					return true,false;
				end
			end
		end
		-- If this group has a symlink, generate the symlink into a cached version of the ref and see if it has collectibles
		if ref.sym then
			-- app.PrintDebug("Checking symlink...",ref.hash)
			local refCache = ref._cache;
			if refCache then
				-- Already have a cached version of this reference with populated content
				local expItem = refCache.GetCachedField(ref, "_populated");
				if expItem then
					-- app.PrintDebug("Cached symlink",expItem.hash,expItem.progress,expItem.total)
					if expItem.total and expItem.total > 0 then
						return true,expItem.progress == expItem.total;
					end
					return;
				end
				-- app.PrintDebug("Filling symlink...",ref.hash)
				-- app.PrintTable(ref)
				-- create a cached copy of this ref if it is an Item
				expItem = CreateObject(ref);
				-- fill the copied Item's symlink if any
				FillSymLinks(expItem);
				-- Build the Item's groups if any
				BuildGroups(expItem, expItem.g);
				-- do an Update pass for the copied Item
				app.TopLevelUpdateGroup(expItem);
				-- app.PrintDebug("Fresh symlink",expItem.hash,expItem.progress,expItem.total)
				-- app.PrintTable(expItem)
				-- save it in the Item cache in case something else is able to purchase this reference
				refCache.SetCachedField(ref, "_populated", expItem);
				-- check if this expItem has been completed
				if expItem.total and expItem.total > 0 then
					return true,expItem.progress == expItem.total;
				end
			end
			-- print("cannot determine collectibility")
			-- print("cost",t.key,t.key and t[t.key])
			-- app.PrintTable(ref)
			-- print(ref.__type, ref._cache)
			-- return false,false;
		end
	end
end
app.CheckCollectible = CheckCollectible;
-- Returns whether 't' should be considered collectible based on the set of costCollectibles already assigned to this 't'
app.CollectibleAsCost = function(t)
	local collectibles = t.costCollectibles;
	-- literally nothing to collect with 't' as a cost, so don't process the logic anymore
	if not collectibles or #collectibles == 0 then
		rawset(t, "collectibleAsCost", false);
		return;
	end
	-- This instance of the Thing 't' is not actually collectible for this character if it is under a saved quest parent
	if not app.MODE_DEBUG_OR_ACCOUNT then
		local parent = rawget(t, "parent");
		if parent and parent.questID and parent.saved then
			-- app.PrintDebug("CollectibleAsCost:t.parent.saved",t.hash)
			return;
		end
	end
	-- mark this group as not collectible by cost while it is processing, in case it has sub-content which can be used to obtain this 't'
	rawset(t, "collectibleAsCost", false);
	-- check the collectibles if any are considered collectible currently
	local collectible, collected;
	for _,ref in ipairs(collectibles) do
		-- Use the common collectibility check logic
		collectible, collected = CheckCollectible(ref);
		if collectible and not collected then
			t.collectibleAsCost = nil;
			-- app.PrintDebug("CollectibleAsCost:true",t.hash,"from",ref.hash)
			-- Found something collectible for t, make sure t is actually obtainable as well
			-- Make sure this thing can actually be collectible via hierarchy
			-- if GetRelativeValue(t, "altcollected") then
			-- 	-- literally have not seen this message in months, maybe is pointless...
			-- 	app.PrintDebug("CollectibleAsCost:altcollected",t.hash)
			-- 	return;
			-- end
			return true;
		end
	end
	-- app.PrintDebug("CollectibleAsCost:false",t.hash)
	t.collectibleAsCost = nil;
end
end)();

-- Quest Lib
-- Quests first because a lot of other Thing libs use Quest logic
(function()
local C_QuestLog_GetQuestObjectives,C_QuestLog_IsOnQuest,C_QuestLog_IsQuestReplayable,C_QuestLog_IsQuestReplayedRecently,C_QuestLog_ReadyForTurnIn,C_QuestLog_GetAllCompletedQuestIDs,C_QuestLog_RequestLoadQuestByID,QuestUtils_GetQuestName,GetNumQuestLogRewards,GetQuestLogRewardInfo,GetNumQuestLogRewardCurrencies,GetQuestLogRewardCurrencyInfo,HaveQuestRewardData =
	  C_QuestLog.GetQuestObjectives,C_QuestLog.IsOnQuest,C_QuestLog.IsQuestReplayable,C_QuestLog.IsQuestReplayedRecently,C_QuestLog.ReadyForTurnIn,C_QuestLog.GetAllCompletedQuestIDs,C_QuestLog.RequestLoadQuestByID,QuestUtils_GetQuestName,GetNumQuestLogRewards,GetQuestLogRewardInfo,GetNumQuestLogRewardCurrencies,GetQuestLogRewardCurrencyInfo,HaveQuestRewardData;
local GetSpellInfo,math_floor =
	  GetSpellInfo,math.floor;

-- Quest Harvesting Lib (http://www.wowinterface.com/forums/showthread.php?t=46934)
local QuestHarvester = CreateFrame("GameTooltip", "AllTheThingsQuestHarvester", UIParent, "GameTooltipTemplate");
local QuestTitleFromID = setmetatable({}, { __index = function(t, id)
	if id then
		local title = QuestUtils_GetQuestName(id);
		if title and title ~= "" then
			rawset(t, id, title);
			return title
		end

		app.RequestLoadQuestByID(id);
		return RETRIEVING_DATA;
	end
end});
local QuestsRequested = {};
local QuestsToPopulate = {};
-- This event seems to fire synchronously from C_QuestLog.RequestLoadQuestByID if we already have the data
app.events.QUEST_DATA_LOAD_RESULT = function(questID, success)
	-- app.PrintDebug("QUEST_DATA_LOAD_RESULT",questID,success)
	QuestsRequested[questID] = nil;
	-- Store the Quest title
	if not rawget(QuestTitleFromID, questID) then
		if success then
			local title = QuestUtils_GetQuestName(questID);
			if title and title ~= "" then
				-- app.PrintDebug("Available QuestData",questID,title)
				rawset(QuestTitleFromID, questID, title);
				-- trigger a slight delayed refresh to visible ATT windows since a quest name was now populated
				app:RefreshWindows();
			end
		else
			-- this quest name cannot be populated by the server
			-- app.PrintDebug("No Server QuestData",questID)
			rawset(QuestTitleFromID, questID, "Quest #"..questID.."*");
		end
	end
	-- see if this Quest is awaiting Reward population & Updates
	local data = QuestsToPopulate[questID];
	if data then
		QuestsToPopulate[questID] = nil;
		app.TryPopulateQuestRewards(data);
	end
end
-- Checks if we need to request Quest data from the Server, and returns whether the request is pending
-- Passing in the data will cause the data to have quest rewards populated once the data is retrieved
app.RequestLoadQuestByID = function(questID, data)
	-- only allow requests once per frame until received
	if not QuestsRequested[questID] then
		-- there's some limit to quest data checking that causes d/c... not entirely sure what or how much
		app.FunctionRunner.SetPerFrame(10);
		-- app.PrintDebug("RequestLoadQuestByID",questID,"Data:",data)
		QuestsRequested[questID] = true;
		if data then
			QuestsToPopulate[questID] = data;
		end
		app.FunctionRunner.Run(C_QuestLog_RequestLoadQuestByID, questID);
	end
end
-- consolidated representation of whether a Thing can be collectible via QuestID
app.CollectibleAsQuest = function(t)
	local questID = t.questID;
	return
	-- must have a questID associated
	questID
	-- must not be repeatable, unless considering repeatable quests as collectible
	and (not t.repeatable or app.Settings:GetTooltipSetting("Repeatable"))
	and
	(
		(	-- Regular Quests
			app.CollectibleQuests
			and
			(
				(
					(
						-- debug/account mode
						app.MODE_DEBUG_OR_ACCOUNT
						-- or able to access quest on current character
						or not t.locked
					)
					-- account-wide quests (special case since quests are only available once per account, so can only consider them collectible if they've never been completed otherwise)
					and
					(
						app.AccountWideQuests
						-- otherwise must not be a once-per-account quest which has already been flagged as completed on a different character
						or (not ATTAccountWideData.OneTimeQuests[questID] or ATTAccountWideData.OneTimeQuests[questID] == app.GUID)
					)
				)
				-- If it is an item/cost and associated to an active quest.
				-- TODO: add t.requiredForQuestID
				or (not t.isWorldQuest and (t.cost or t.itemID) and C_QuestLog_IsOnQuest(questID))
			)
		)
		or
		(	-- Locked Quests
			app.CollectibleQuestsLocked
			and
			(
				-- not able to access quest on current character
				t.locked
				and
				(
					-- debug/account mode
					app.MODE_DEBUG_OR_ACCOUNT
					or
					-- available in party sync
					not t.DisablePartySync
				)
			)
		)
	)
end

local function QuestConsideredSaved(questID)
	if app.IsInPartySync then
		return C_QuestLog_IsQuestReplayedRecently(questID) or (not C_QuestLog_IsQuestReplayable(questID) and IsQuestFlaggedCompleted(questID));
	end
	return IsQuestFlaggedCompleted(questID);
end
-- Given an Object, will return the indicator (asset name) if this Object should show one based on it being tied to a QuestID
app.GetQuestIndicator = function(t)
	if t.questID then
		if C_QuestLog_IsOnQuest(t.questID) then
			return (C_QuestLog_ReadyForTurnIn(t.questID) and "Interface_Questin")
				or "Interface_Questin_grey";
		elseif ATTAccountWideData.OneTimeQuests[t.questID] ~= nil then
			return "Interface_Quest_Arrow";
		end
	end
end

local criteriaFuncs = {
    ["achID"] = function(v)
        return app.CurrentCharacter.Achievements[v] or select(4, GetAchievementInfo(v));
    end,
	["label_achID"] = L["LOCK_CRITERIA_ACHIEVEMENT_LABEL"],
    ["text_achID"] = function(v)
        return select(2, GetAchievementInfo(v));
    end,

    ["lvl"] = function(v)
        return app.Level >= v;
    end,
	["label_lvl"] = L["LOCK_CRITERIA_LEVEL_LABEL"],
    ["text_lvl"] = function(v)
        return v;
    end,

    ["questID"] = QuestConsideredSaved,
	["label_questID"] = L["LOCK_CRITERIA_QUEST_LABEL"],
    ["text_questID"] = function(v)
		local questObj = app.SearchForObject("questID", v);
        return sformat("[%d] %s", v, questObj and questObj.text or "???");
    end,

    ["spellID"] = function(v)
        return app.IsSpellKnownHelper(v) or app.CurrentCharacter.Spells[v];
    end,
	["label_spellID"] = L["LOCK_CRITERIA_SPELL_LABEL"],
    ["text_spellID"] = function(v)
        return GetSpellInfo(v);
    end,

    ["factionID"] = function(v)
		-- v = factionID.standingRequiredToLock
		local factionID = math_floor(v + 0.00001);
		local lockStanding = math_floor((v - factionID) * 10 + 0.00001);
        local standing = app.GetCurrentFactionStandings(factionID);
		-- app.PrintDebug(sformat("Check Faction %s Standing (%d) is locked @ (%d)", factionID, standing, lockStanding))
		return standing >= lockStanding;
    end,
	["label_factionID"] = L["LOCK_CRITERIA_FACTION_LABEL"],
    ["text_factionID"] = function(v)
		-- v = factionID.standingRequiredToLock
		local factionID = math_floor(v + 0.00001);
		local lockStanding = math_floor((v - factionID) * 10 + 0.00001);
		local name = GetFactionInfoByID(factionID);
        return sformat(L["LOCK_CRITERIA_FACTION_FORMAT"], app.GetCurrentFactionStandingText(factionID, lockStanding), name, app.GetCurrentFactionStandingText(factionID));
    end,
};
app.QuestLockCriteriaFunctions = criteriaFuncs;
local function IsGroupLocked(t)
	local lockCriteria = t.lc;
	if lockCriteria then
		local criteriaRequired = lockCriteria[1];
		local critKey, critFunc, nonQuestLock;
		local i, limit = 2, #lockCriteria;
		while i < limit do
			critKey = lockCriteria[i];
			critFunc = criteriaFuncs[critKey];
			i = i + 1;
			if critFunc then
				if critFunc(lockCriteria[i]) then
					criteriaRequired = criteriaRequired - 1;
					if not nonQuestLock and critKey ~= "questID" and critKey ~= "lvl" then
						nonQuestLock = true;
					end
				end
			else
				app.print("Unknown 'lockCriteria' key:",critKey,lockCriteria[i]);
			end
			-- enough criteria met to consider this quest locked
			if criteriaRequired <= 0 then
				-- we can rawset this since there's no real way for a player to 'remove' this lock during a session
				-- and this does not come into play during party sync
				rawset(t, "locked", true);
				-- if this was locked due to something other than a Quest/Level specifically, indicate it cannot be done in Party Sync
				if nonQuestLock then
					-- app.PrintDebug("Automatic DisablePartySync", app:Linkify(t.hash, app.Colors.ChatLink, "search:"..t.key..":"..t[t.key]))
					rawset(t, "DisablePartySync", true);
				end
				-- app.PrintDebug("Locked", app:Linkify(t.hash, app.Colors.ChatLink, "search:"..t.key..":"..t[t.key]))
				return true;
			end
			i = i + 1;
		end
	end
end
app.IsGroupLocked = IsGroupLocked;
local function LockedAsQuest(t)
	local questID = t.questID;
	if not IsQuestFlaggedCompleted(questID) then
		-- generic locked functionality based on lockCriteria
		if IsGroupLocked(t) then return true; end
		-- if an alt-quest is completed, then this quest is locked
		if t.altcollected then
			rawset(t, "locked", t.altcollected);
			return true;
		end
		-- determine if a 'nextQuest' exists and is completed specifically by this character, to remove availability of the breadcrumb
		if t.isBreadcrumb and t.nextQuests then
			local nq;
			for _,questID in ipairs(t.nextQuests) do
				if IsQuestFlaggedCompleted(questID) then
					rawset(t, "locked", questID);
					return questID;
				else
					-- this questID may not even be available to pick up, so try to find an object with this questID to determine if the object is complete
					nq = app.SearchForObject("questID", questID);
					if nq and (IsQuestFlaggedCompleted(nq.questID) or nq.altcollected or nq.locked) then
						rawset(t, "locked", questID);
						-- app.PrintDebug("Locked Quest", app:Linkify(t.hash, app.Colors.ChatLink, "search:"..t.key..":"..t[t.key]))
						return questID;
					end
				end
			end
		end
	end
	-- rawset means that this will persist as a non-locked quest until reload, so quests that become locked while playing will not immediately update
	-- maybe can revise that somehow without also having this entire logic be calculated billions of times when nothing changes....
	rawset(t, "locked", false);
end
app.LockedAsQuest = LockedAsQuest;

local Search = app.SearchForObject;
local BackTraceChecks = {};
-- Traces backwards in the sequence for 'questID' via parent relationships within 'parents' to see if 'checkQuestID' is reached and returns true if so
local function BackTraceForSelf(parents, questID, checkQuestID)
	-- app.PrintDebug("Backtrace",questID)
	wipe(BackTraceChecks);
	local next = parents[questID];
	while next and not BackTraceChecks[next] do
		-- app.PrintDebug("->",next)
		if next == checkQuestID then return true; end
		BackTraceChecks[next] = 1;
		next = parents[next];
	end

	-- looping quest sequence exists
	if next and BackTraceChecks[next] then
		app.report("Looping Quest Chain encountered!",next)
		return true;
	end
end
local function MapSourceQuestsRecursive(parentQuestID, questID, currentDepth, depths, parents, refs, inFilters)
	if not questID then return; end

	-- Compare current depth to existing depth in 'depths' if the current parent of the questID is already in filters
	local prevDepth = depths[questID];
	local currentParent = parents[questID];
	if prevDepth and prevDepth >= currentDepth and inFilters[currentParent] then
		-- app.PrintDebug("Ignore Depth Quest",questID,"@",currentDepth,"Previous",prevDepth)
		return;
	end

	-- Find the quest being added (either existing clone or new search)
	local questRef = refs[questID];
	if questRef then
		-- Verify this quest isn't in the current parent chain
		if BackTraceForSelf(parents, parentQuestID, questID) then
			-- app.PrintDebug("Ignore Backtrace Quest",questID)
			return;
		else
			-- maybe a better fix at some point? still possible to write really strange quest sequences that can trigger this
			if currentDepth > 1000 then
				if not app._reportedBadQuestSequence then
					app._reportedBadQuestSequence = true;
					app.report("Likely bad Quest chain sequence encountered @ 1000 depth for",questID);
				end
				return;
			end
			-- app.PrintDebug("Not in Backtrace",questID)
		end
	else
		questRef = Search("questID",questID);
		if not questRef then
			app.report("Failed to find Source Quest",questID)
			return;
		end

		-- Save this questRef (depth doesn't change the ref so only clone it once)
		questRef = CreateObject(questRef, true);

		-- force collectible for normally un-collectible but trackable things to make sure it shows in list if the quest needs to be completed to progess
		if not questRef.collectible and questRef.trackable then
			questRef.collectible = true;
		end

		-- don't consider locked quests which have been skipped if not tracking locked quests
		if not questRef.collected and questRef.locked and not app.Settings:Get("Thing:QuestsLocked") then
			questRef.collectible = false;
		end

		-- If the user is in a Party Sync session, then force showing pre-req quests which are replayable if they are collected already
		if app.IsInPartySync and questRef.collected then
			questRef.OnUpdate = app.ShowIfReplayableQuest;
		end

		-- If the quest is provided by an Item, then show that Item directly under the quest so it can easily show tooltip/Source information if desired
		if questRef.providers then
			local id;
			for _,p in ipairs(questRef.providers) do
				if p[1] == "i" then
					id = p[2];
					-- print("Quest Item Provider",p[1], id);
					local pRef = app.SearchForObject("itemID", id);
					if pRef then
						NestObject(questRef, pRef, true, 1);
					else
						pRef = app.CreateItem(id);
						NestObject(questRef, pRef, nil, 1);
					end
					-- Make sure to always show the Quest starting item
					pRef.OnUpdate = app.AlwaysShowUpdate;
					-- Quest started by this Item should be represented using any sourceQuests on the Item
					if pRef.sourceQuests then
						if not questRef.sourceQuests then questRef.sourceQuests = {}; end
						-- app.PrintDebug("Add Provider SQs to Quest")
						app.ArrayAppend(questRef.sourceQuests, pRef.sourceQuests);
					end
				end
			end
		end

		refs[questID] = questRef;
	end

	-- Save the new depth that this questID will be placed if it has a parent
	depths[questID] = currentDepth;
	-- Save the parentQuestID for this questID, but only if this quest has no parent yet, or specifically meets character filters for a different parent
	if not currentParent then
		parents[questID] = parentQuestID;
	elseif currentParent ~= parentQuestID and not inFilters[currentParent] then
		-- app.PrintDebug("Check Current Parent Filter",questID,"=>",currentParent)
		if app.CurrentCharacterFilters(refs[parentQuestID]) then
			-- app.PrintDebug("New Filter Parent",questID,"=>",parentQuestID)
			parents[questID] = parentQuestID;
			inFilters[parentQuestID] = true;
		-- else
		-- 	app.PrintDebug("New Parent, Filtered",questID,"=>",parentQuestID)
		end
	end

	-- Traverse recursive quests via 'sourceQuests'
	local sqs = questRef.sourceQuests;
	if not sqs then return; end

	-- Mark the new depth
	local nextDepth = currentDepth + 1;
	for _,sq in ipairs(sqs) do
		-- Recurse against sourceQuests of sq
		MapSourceQuestsRecursive(questID, sq, nextDepth, depths, parents, refs, inFilters);
	end
end
-- Will find, clone, and nest into 'root' all known source quests starting from the provided 'root', listing each quest once at the maximum depth that it has been encountered
app.NestSourceQuestsV2 = function(questChainRoot, questID)
	if not questID then
		if not questChainRoot.sourceQuests then return; end
		questID = 0;
	end

	-- Treat the starting questID as an extremely high depth so that it will not be replaced if it is encountered again due to a looping quest chain
	local depths = {[questID] = 9999};
	local parents = {};
	local refs = {[questID] = questChainRoot};
	-- represents quests that had to be confirmed for current character filters already
	local inFilters = {};

	-- Map out the relative positions of the entire quest sequence based on depth from the root quest
	-- Find the quest being added
	local questRef = questID > 0 and Search("questID",questID) or app.EmptyTable;
	-- Traverse recursive quests via 'sourceQuests'
	local sqs = questRef.sourceQuests or questChainRoot.sourceQuests;
	if not sqs then return; end

	app._reportedBadQuestSequence = nil;
	for _,sq in ipairs(sqs) do
		-- Recurse against sourceQuests of sq
		MapSourceQuestsRecursive(questID, sq, 1, depths, parents, refs, inFilters);
	end

	-- app.PrintDebug("depths")
	-- app.PrintTable(depths)
	-- app.PrintDebug("parents")
	-- app.PrintTable(parents)

	-- Perform a pass along the parents table to move clone references into the appropriate parent quest references
	for qID,pID in pairs(parents) do
		NestObject(refs[pID], refs[qID]);
	end
end

local questFields = {
	["key"] = function(t)
		return "questID";
	end,
	["name"] = function(t)
		return QuestTitleFromID[t.questID];
	end,
	["objectiveInfo"] = function(t)
		local questID = t.questID;
		if questID then
			local objectives = C_QuestLog_GetQuestObjectives(questID);
			if objectives then
				rawset(t, "objectiveInfo", objectives);
				return objectives;
			end
		end
		rawset(t, "objectiveInfo", app.EmptyTable)
	end,
	["description"] = function(t)
		-- Provide a fall-back description as to collectibility of a Quest due to granting reputation
		if app.CollectibleReputations and t.maxReputation then
			local factionID = t.maxReputation[1];
			return L["ITEM_GIVES_REP"] .. (select(1, GetFactionInfoByID(factionID)) or ("Faction #" .. tostring(factionID))) .. "'";
		end
	end,
	["icon"] = function(t)
		if t.providers then
			for k,v in ipairs(t.providers) do
				if v[2] > 0 then
					if v[1] == "o" then
						return app.ObjectIcons[v[2]] or "Interface\\Icons\\INV_Misc_Bag_10";
					elseif v[1] == "i" then
						return select(5, GetItemInfoInstant(v[2])) or "Interface\\Icons\\INV_Misc_Book_09";
					end
				end
			end
		end
		if t.isWorldQuest then
			return "Interface\\AddOns\\AllTheThings\\assets\\Interface_Questind";
		elseif t.repeatable then
			return "Interface\\AddOns\\AllTheThings\\assets\\Interface_Questd";
		elseif t._missing then
			return "Interface\\Icons\\INV_Misc_QuestionMark";
		else
			return "Interface\\AddOns\\AllTheThings\\assets\\Interface_Quest";
		end
	end,
	["model"] = function(t)
		if t.providers then
			for k,v in ipairs(t.providers) do
				if v[2] > 0 then
					if v[1] == "o" then
						return app.ObjectModels[v[2]];
					end
				end
			end
		end
	end,
	["link"] = function(t)
		return GetQuestLink(t.questID) or "quest:" .. t.questID;
	end,
	["repeatable"] = function(t)
		return rawget(t, "isDaily") or rawget(t, "isWeekly") or rawget(t, "isMonthly") or rawget(t, "isYearly") or rawget(t, "isWorldQuest");
	end,
	["collectible"] = app.CollectibleAsQuest,
	["collected"] = IsQuestFlaggedCompletedForObject,
	["trackable"] = app.ReturnTrue,
	["saved"] = function(t)
		return QuestConsideredSaved(t.questID);
	end,
	["indicatorIcon"] = app.GetQuestIndicator,
	["collectibleAsCost"] = function(t)
		-- If Collectible by providing reputation towards a Faction with which the character is below the rep-granting Standing
		-- and the Faction itself is Collectible & Not Collected
		-- and the Quest is not locked from being completed
		if app.CollectibleReputations and t.maxReputation and not t.locked then
			local factionID = t.maxReputation[1];
			local factionRef = app.SearchForObject("factionID", factionID);
			if factionRef and not factionRef.collected and (select(6, GetFactionInfoByID(factionID)) or 0) < t.maxReputation[2] then
				-- app.PrintDebug("Quest",t.questID,"collectible for Faction",factionID,factionRef.text)
				return true;
			end
		end
		-- If Collectible by being a Quest
		-- if app.CollectibleQuests or app.CollectibleQuestsLocked then
		-- 	return app.CollectibleAsQuest(t);
		-- end
	end,
	-- ["collectedAsReputation"] = function(t)
	-- 	-- If the Quest is completed on this character, then it doesn't matter about the faction
	-- 	if IsQuestFlaggedCompleted(t.questID) then
	-- 		return 1;
	-- 	end
	-- 	-- Check whether this Quest can provide Rep towards an incomplete Faction
	-- 	if app.CollectibleReputations and t.maxReputation then
	-- 		local factionID = t.maxReputation[1];
	-- 		local factionRef = app.SearchForObject("factionID", factionID);
	-- 		-- Completing the quest will increase the Faction, so it is incomplete
	-- 		if factionRef and not factionRef.collected and (select(6, GetFactionInfoByID(factionID)) or 0) < t.maxReputation[2] then
	-- 			return false;
	-- 		elseif not app.CollectibleQuests and not app.CollectibleQuestsLocked then
	-- 		-- Completing the quest will not increase the Faction, but User doesn't care about Quests, then consider it 'collected'
	-- 			return 2;
	-- 		end
	-- 	end
	-- 	-- Finally, check if the quest is otherwise considered 'collected' by normal logic
	-- 	return IsQuestFlaggedCompletedForObject(t);
	-- end,
	["altcollected"] = function(t)
		-- determine if an altQuest is considered completed for this quest for this character
		if t.altQuests then
			for _,questID in ipairs(t.altQuests) do
				if IsQuestFlaggedCompleted(questID) then
					-- if LOG then print(LOG,"altCollected by",questID) end
					rawset(t, "altcollected", questID);
					return questID;
				end
			end
		end
	end,
	["missingSourceQuests"] = function(t)
		if t.sourceQuests and #t.sourceQuests > 0 then
			local includeBreadcrumbs = app.Settings:Get("Thing:QuestsLocked");
			local sq;
			for _,sourceQuestID in ipairs(t.sourceQuests) do
				if not IsQuestFlaggedCompleted(sourceQuestID) then
					-- consider the breadcrumb as an actual sq since the user is tracking them
					if includeBreadcrumbs then
						return true;
					-- otherwise incomplete breadcrumbs will not prevent picking up a quest if they are ignored
					else
						sq = app.SearchForObject("questID", sourceQuestID);
						if sq and not sq.isBreadcrumb and not (sq.locked or sq.altcollected) then
							return true;
						end
					end
				end
			end
		end
	end,
	["missingPrequisites"] = function(t)
		local sourceQuests = t.sourceQuests;
		if sourceQuests and #sourceQuests > 0 then
			local sq, filter, onQuest;
			local prereqs = rawget(t, "prereqs") or {};
			local sqreq = rawget(t, "sqreq") or #sourceQuests;
			local missing = 0;
			rawset(t, "prereqs", prereqs);
			wipe(prereqs);
			for _,sourceQuestID in ipairs(sourceQuests) do
				if not IsQuestFlaggedCompletedForce(sourceQuestID) then
					sq = app.SearchForObject("questID", sourceQuestID);
					if sq then
						filter = app.CurrentCharacterFilters(sq);
						onQuest = C_QuestLog_IsOnQuest(sourceQuestID);
						prereqs[sourceQuestID] = "N"
							..(onQuest and "O" or "")
							..(sq.isBreadcrumb and "B" or "")
							..(sq.locked and "L" or "")
							..(sq.altcollected and "A" or "")
							..(not filter and "F" or "");
						-- missing: meets current character filters, non-breadcrumb, non-locked, not currently on the quest
						if filter and not onQuest and not sq.isBreadcrumb and not (sq.locked or sq.altcollected) then
							missing = missing + 1;
						end
					end
				else
					prereqs[sourceQuestID] = "C";
				end
			end
			return (#sourceQuests - missing) < sqreq;
		end
	end,
	["locked"] = LockedAsQuest,
};
app.BaseQuest = app.BaseObjectFields(questFields, "BaseQuest");

-- These are Items rewarded by WQs which are treated as currency
-- other Items which are 'costs' will not be excluded by the "WorldQuestsList:Currencies" setting
local WorldQuestCurrencyItems = {
	[190189] = true,	-- Sandworn Relic
	[163036] = true,	-- Polished Pet Charms
	[116415] = true,	-- Shiny Pet Charms
};
-- Will attempt to populate the rewards of the quest object into itself or request itself to be loaded
local function TryPopulateQuestRewards(questObject)
	local questID = questObject and questObject.questID;
	if not questID then
		-- Update the group directly immediately since there's no quest to retrieve
		-- app.PrintDebug("TPQR:No Quest")
		questObject.retries = nil;
		app.DirectGroupUpdate(questObject);
		return;
	end
	questObject.retries = (questObject.retries or 0) + 1;
	-- if we've already requested data for this quest a certain number of times, then ignore making another request
	if questObject.retries < 5 and not HaveQuestRewardData(questID) then
		app.RequestLoadQuestByID(questID, questObject);
		return;
	end

	questObject.retries = nil;
	-- if not HaveQuestRewardData(questID) then
	-- 	app.PrintDebug("TPQR",questID,"Data",HaveQuestData(questID),"RewardData",HaveQuestRewardData(questID),GetNumQuestLogRewards(questID),GetNumQuestLogRewardCurrencies(questID))
	-- end
	local numQuestRewards = GetNumQuestLogRewards(questID);
	local skipCollectibleCurrencies = not app.Settings:GetTooltipSetting("WorldQuestsList:Currencies");
	for j=1,numQuestRewards,1 do
		-- app.PrintDebug("TPQR:REWARDINFO",questID,j,HaveQuestData(questID),GetQuestLogRewardInfo(j, questID))
		local itemID = select(6, GetQuestLogRewardInfo(j, questID));
		if itemID then
			QuestHarvester.AllTheThingsProcessing = true;
			QuestHarvester:SetOwner(UIParent, "ANCHOR_NONE");
			QuestHarvester:SetQuestLogItem("reward", j, questID);
			local link = select(2, QuestHarvester:GetItem());
			QuestHarvester.AllTheThingsProcessing = false;
			QuestHarvester:Hide();
			if link then
				local item = {};
				app.ImportRawLink(item, link);
				if item.itemID then
					-- search will either match through bonusID, modID, or itemID in that priority
					local search = SearchForLink(link);
					-- block the group from being collectible as a cost if the option is not enabled for various 'currency' items
					if skipCollectibleCurrencies and WorldQuestCurrencyItems[item.itemID] then
						item.collectibleAsCost = false;
					end
					if search then
						-- find the specific item which the link represents (not sure all of this is necessary with improved search)
						local exactItemID = GetGroupItemIDWithModID(item);
						local subItems = {};
						local refinedMatches = app.GroupBestMatchingItems(search, exactItemID);
						if refinedMatches then
							-- move from depth 3 to depth 1 to find the set of items which best matches for the root
							for depth=3,1,-1 do
								if refinedMatches[depth] then
									for _,o in ipairs(refinedMatches[depth]) do
										MergeProperties(item, o, true);
										NestObjects(item, o.g);	-- no clone since item is cloned later
									end
								end
							end
							-- any matches with depth 0 will be nested
							if refinedMatches[0] then
								app.ArrayAppend(subItems, refinedMatches[0]);	-- no clone since item is cloned later
							end
						end
						-- then pull in any other sub-items which were not the item itself
						NestObjects(item, subItems);	-- no clone since item is cloned later
					end

					-- don't let cached groups pollute potentially inaccurate raw Data
					item.link = nil;
					NestObject(questObject, item, true);
				end
			end
		end
	end

	-- Add info for currency rewards as containers for their respective collectibles
	local numCurrencies = GetNumQuestLogRewardCurrencies(questID);
	local skipCollectibleCurrencies = not app.Settings:GetTooltipSetting("WorldQuestsList:Currencies");
	local currencyID, cachedCurrency;
	for j=1,numCurrencies,1 do
		currencyID = select(4, GetQuestLogRewardCurrencyInfo(j, questID));
		if currencyID then
			-- if app.DEBUG_PRINT then print("TryPopulateQuestRewards_currencies:found",questID,currencyID,questObject.missingCurr) end

			currencyID = tonumber(currencyID);
			local item = { ["currencyID"] = currencyID };
			-- block the group from being collectible as a cost if the option is not enabled
			if skipCollectibleCurrencies then
				item.collectibleAsCost = false;
			end
			cachedCurrency = SearchForField("currencyID", currencyID);
			if cachedCurrency then
				for _,data in ipairs(cachedCurrency) do
					-- cache record is the item itself
					if GroupMatchesParams(data, "currencyID", currencyID) then
						MergeProperties(item, data);
					-- cache record is associated with the item
					else
						NestObject(item, data);	-- no clone since item is cloned later
					end
				end
			end
			NestObject(questObject, item, true);
		end
	end

	-- Troublesome scenarios to test when changing this logic:
	-- BFA emissaries
	-- BFA Azerite armor caches
	-- Argus Rare WQ's + Rare Alt quest

	-- Finally ensure that any cached entries for the quest are copied into this version of the object
	-- Needs to be SearchForField as non-quests can be pulled too
	local cachedQuests = SearchForField("questID", questID);
	if cachedQuests then
		-- special care for API provided items
		local apiItems = {};
		if questObject.g then
			for _,item in ipairs(questObject.g) do
				if item.itemID then
					apiItems[item.itemID] = item;
				end
			end
		end
		local nonItemNested = {};
		-- merge in any DB data without replacing existing data
		for _,data in ipairs(cachedQuests) do
			-- only merge into the quest object properties from an object in cache with this questID
			if data.questID and data.questID == questID then
				MergeProperties(questObject, data, true);
				-- need to exclusively copy cached values for certain fields since normal merge logic will not copy them
				-- ref: quest 49675/58703
				if data.u then questObject.u = data.u; end
				-- merge in sourced things under this quest object
				if data.g then
					for _,o in ipairs(data.g) do
						-- nest cached non-items
						if not o.itemID then
							-- if app.DEBUG_PRINT then print("nested-nonItem",o.hash) end
							tinsert(nonItemNested, o);
						-- cached items need to merge with corresponding API item based on simple itemID
						elseif apiItems[o.itemID] then
							-- if app.DEBUG_PRINT then print("nested-merged",o.hash) end
							MergeProperties(apiItems[o.itemID], o, true);
						--  if it is not a WQ or is a 'raid' (world boss)
						elseif questObject.isRaid or not questObject.isWorldQuest then
							-- otherwise just get nested
							-- if app.DEBUG_PRINT then print("nested-item",o.hash) end
							tinsert(nonItemNested, o);
						end
					end
				end
			-- otherwise if this is a non-quest object flagged with this questID so it should be added under the quest
			elseif data.key ~= "questID" then
				tinsert(nonItemNested, data);
			end
		end
		-- Everything retrieved from API should not be related to another sourceParent
		-- i.e. Threads of Fate Quest rewards which show up later under regular World Quests
		for _,item in pairs(apiItems) do
			item.sourceParent = nil;
		end
		NestObjects(questObject, nonItemNested, true);
	end

	-- Resolve all symbolic links now that the quest contains items
	FillSymLinks(questObject, true);

	-- Special logic for Torn Invitation... maybe can clean up sometime
	if questObject.g and #questObject.g > 0 then
		for _,item in ipairs(questObject.g) do
			if item.g then
				for k,o in ipairs(item.g) do
					if o.itemID == 140495 then	-- Torn Invitation
						local searchResults = app.SearchForField("questID", 44058);	-- Volpin the Elusive
						NestObjects(o, searchResults, true);
					end
				end
			end
		end
	end

	BuildGroups(questObject, questObject.g);
	-- Update the group directly
	app.DirectGroupUpdate(questObject);
end
-- Will attempt to queue populating the rewards of the quest object into itself or request itself to be loaded
app.TryPopulateQuestRewards = function(questObject)
	app.FunctionRunner.Run(TryPopulateQuestRewards, questObject);
end
-- Will print a warning message and play a warning sound if the given QuestID being completed will prevent being able to complete a breadcrumb
-- (as far as ATT is capable of knowing)
app.CheckForBreadcrumbPrevention = function(title, questID)
	local nextQuests = app.SearchForField("nextQuests", questID);
	if nextQuests then
		local warning;
		for _,group in pairs(nextQuests) do
			if not group.collected and app.RecursiveGroupRequirementsFilter(group) then
				app.print(sformat(L["QUEST_PREVENTS_BREADCRUMB_COLLECTION_FORMAT"], title, app:Linkify(questID, app.Colors.ChatLink, "search:questID:"..questID), group.text or RETRIEVING_DATA, app:Linkify(group.questID, app.Colors.Locked, "search:questID:"..group.questID)));
				warning = true;
			end
		end
		if warning then app:PlayRemoveSound(); end
	end
end

-- Quest with Reputation
-- local fields = RawCloneData(questFields, {
-- 	["collectible"] = questFields.collectibleAsReputation,
-- 	["collected"] = questFields.collectedAsReputation,
-- });
-- app.BaseQuestWithReputation = app.BaseObjectFields(fields, "BaseQuestWithReputation");
app.CreateQuest = function(id, t)
	if t then
		-- extract specific faction data
		local aqd = rawget(t, "aqd");
		if aqd then
			-- Apply the faction specific quest data to this object.
			if app.FactionID == Enum.FlightPathFaction.Horde then
				for key,value in pairs(t.hqd) do t[key] = value; end
			else
				for key,value in pairs(aqd) do t[key] = value; end
			end
		end
		-- if rawget(t, "maxReputation") then
		-- 	return setmetatable(constructor(id, t, "questID"), app.BaseQuestWithReputation);
		-- end
	end
	return setmetatable(constructor(id, t, "questID"), app.BaseQuest);
end
--[[ Not used in Retail anymore
app.CreateQuestWithFactionData = function(t)
	local questData, otherQuestData, otherFaction;
	if app.FactionID == Enum.FlightPathFaction.Horde then
		questData = t.hqd;
		otherQuestData = t.aqd;
		otherFaction = Enum.FlightPathFaction.Alliance;
	else
		questData = t.aqd;
		otherQuestData = t.hqd;
		otherFaction = Enum.FlightPathFaction.Horde;
	end

	-- Apply the faction specific quest data to this object.
	for key,value in pairs(questData) do t[key] = value; end
	local original = setmetatable(t, app.BaseQuest);
	if not otherQuestData.questID or otherQuestData.questID == original.questID then
		-- Situations where a single quest has faction-specific data
		setmetatable(otherQuestData, { __index = t });
		rawset(t, "otherQuestData", otherQuestData);
		return original;
	else
		-- Situations where for some reason two different quests have been merged together as one quest and need to be split apart to be useful
		setmetatable(otherQuestData, app.BaseQuest);
		for key,value in pairs(t) do
			if not rawget(otherQuestData, key) then
				rawset(otherQuestData, key, value);
			end
		end
		rawset(t, "r", app.FactionID);
		rawset(otherQuestData, "r", otherFaction);
		local oldOnUpdate = original.OnUpdate;
		original.OnUpdate = function(t)
			CacheFields(otherQuestData);
			local parent = t.parent;
			-- not sure why the parent might not exist sometimes when the group does an OnUpdate...
			if parent then
				otherQuestData.parent = parent;
				local index = indexOf(parent.g, t);
				if index then
					tinsert(parent.g, index + 1, otherQuestData);
				else
					tinsert(parent.g, otherQuestData);
				end
			else app.PrintDebug("OnUpdate: No parent",t.hash)
			end
			if oldOnUpdate then
				t.OnUpdate = oldOnUpdate;
				return oldOnUpdate(t);
			else
				t.OnUpdate = nil;
			end
		end
		return original;
	end
end
--]]
-- Causes a group to remain visible if it is replayable, regardless of collection status
app.ShowIfReplayableQuest = function(data)
	data.visible = C_QuestLog_IsQuestReplayable(data.questID) or app.CollectedItemVisibilityFilter(data);
	return true;
end
local UpdateQuestIDs, CompletedKeys = {}, {};
local function QueryCompletedQuests()
	local freshCompletes = C_QuestLog_GetAllCompletedQuestIDs();
	-- sometimes Blizz pretends that 0 Quests are completed. How silly of them!
	if not freshCompletes or #freshCompletes == 0 then
		return;
	end
	-- print("total completed quests new/previous",#freshCompletes,TotalQuests)
	local oldReportSetting = app.Settings:GetTooltipSetting("Report:CompletedQuests");
	-- check if Blizzard is being dumb / should we print a summary instead of individual lines
	local questDiff = #freshCompletes - TotalQuests;
	local manyQuests;
	if app.IsReady and oldReportSetting then
		if questDiff > 50 then
			manyQuests = true;
			print(questDiff,"Quests Completed");
		elseif questDiff < -50 then
			manyQuests = true;
			print(questDiff,"Quests Unflagged");
		end
	end
	if manyQuests then
		app.Settings:SetTooltipSetting("Report:CompletedQuests", false);
	end
	wipe(CompletedKeys);
	-- allow individual prints
	for _,v in ipairs(freshCompletes) do
		CompletedQuests[v] = true;
		CompletedKeys[v] = true;
	end
	-- check for 'unflagged' questIDs (this seems to basically not impact lag at all... i hope)
	for q,_ in pairs(CompletedQuests) do
		if not CompletedKeys[q] then
			CompletedQuests[q] = nil;	-- delete the key
			CompletedQuests[q] = false;	-- trigger the metatable function
		end
	end
	if manyQuests then
		app.Settings:SetTooltipSetting("Report:CompletedQuests", oldReportSetting);
	end
end
app.QueryCompletedQuests = QueryCompletedQuests;
-- A set of quests which indicate a needed refresh to the Custom Collect status of the character
local CustomCollectQuests = {
	[56775] = 1,	-- New Player Experience Starting Quest
	[59926] = 1,	-- New Player Experience Starting Quest
	[58911] = 1,	-- New Player Experience Ending Quest
	[60359] = 1,	-- New Player Experience Ending Quest
	[62713] = 1,	-- Shadowlands - SL_SKIP (Threads of Fate)
	[65076] = 1,	-- Shadowlands - Covenant - Kyrian
	[65077] = 1,	-- Shadowlands - Covenant - Venthyr
	[65078] = 1,	-- Shadowlands - Covenant - Night Fae
	[65079] = 1,	-- Shadowlands - Covenant - Necrolord
};
local function RefreshQuestCompletionState(questID)
	-- app.PrintDebug("RefreshQuestCompletionState",questID)
	if questID then
		questID = tonumber(questID);
		CompletedQuests[questID] = true;
	else
		QueryCompletedQuests();
	end

	-- update if any quests were even completed to ensure visible changes occur
	if questID or DirtyQuests.DIRTY then
		DirtyQuests.DIRTY = nil;
		-- make sure to update the incoming questID if it isn't marked after the refresh, somehow
		if not DirtyQuests[questID] then
			tinsert(UpdateQuestIDs, questID);
		end
		for questID,_ in pairs(DirtyQuests) do
			tinsert(UpdateQuestIDs, questID);
			-- Certain quests being completed should trigger a refresh of the Custom Collect status of the character (i.e. Covenant Switches, Threads of Fate, etc.)
			if CustomCollectQuests[questID] then
				Callback(app.RefreshCustomCollectibility);
			end
		end
		-- if app.DEBUG_PRINT then
		-- 	app.PrintDebug("Update Quests")
		-- 	app.PrintTable(UpdateQuestIDs)
		-- end
		UpdateRawIDs("questID", UpdateQuestIDs);
		wipe(UpdateQuestIDs);
	end
	-- re-register the criteria update event
	app:RegisterEvent("CRITERIA_UPDATE");
	wipe(DirtyQuests);
	wipe(npcQuestsCache);
	-- app.PrintDebugPrior("RefreshedQuestCompletionState")
end
app.RefreshQuestInfo = function(questID)
	-- app.PrintDebug("RefreshQuestInfo",questID)
	-- unregister criteria update until the quest refresh actually completes
	app:UnregisterEvent("CRITERIA_UPDATE");
	if questID then
		RefreshQuestCompletionState(questID);
	else
		AfterCombatOrDelayedCallback(RefreshQuestCompletionState, 1);
	end
end

-- Quest Objective Lib
-- Not used in Retail anymore
-- local fields = {
-- 	["key"] = function(t)
-- 		return "objectiveID";
-- 	end,
-- 	["name"] = function(t)
-- 		local objInfo = t.parent.objectiveInfo;
-- 		if objInfo then
-- 			local objective = objInfo[t.objectiveID];
-- 			if objective then return objective.text; end
-- 		end
-- 		return L["QUEST_OBJECTIVE_INVALID"];
-- 	end,
-- 	["icon"] = function(t)
-- 		if t.providers then
-- 			for k,v in ipairs(t.providers) do
-- 				if v[2] > 0 then
-- 					if v[1] == "o" then
-- 						return app.ObjectIcons[v[2]] or "Interface\\Worldmap\\Gear_64Grey";
-- 					elseif v[1] == "i" then
-- 						return select(5, GetItemInfoInstant(v[2])) or "Interface\\Worldmap\\Gear_64Grey";
-- 					end
-- 				end
-- 			end
-- 		end
--		if t.spellID then return select(3, GetSpellInfo(t.spellID)); end
-- 		return t.parent.icon or "Interface\\Worldmap\\Gear_64Grey";
-- 	end,
-- 	["model"] = function(t)
-- 		if t.providers then
-- 			for k,v in ipairs(t.providers) do
-- 				if v[2] > 0 then
-- 					if v[1] == "o" then
-- 						return app.ObjectModels[v[2]];
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end,
-- 	["objectiveID"] = function(t)
-- 		return 1;
-- 	end,
-- 	["questID"] = function(t)
-- 		return t.parent.questID;
-- 	end,
-- 	["isDaily"] = function(t)
-- 		return t.parent.isDaily;
-- 	end,
-- 	["isWeekly"] = function(t)
-- 		return t.parent.isWeekly;
-- 	end,
-- 	["isMonthly"] = function(t)
-- 		return t.parent.isMonthly;
-- 	end,
-- 	["isYearly"] = function(t)
-- 		return t.parent.isYearly;
-- 	end,
-- 	["isWorldQuest"] = function(t)
-- 		return t.parent.isWorldQuest;
-- 	end,
-- 	["repeatable"] = function(t)
-- 		return t.parent.repeatable;
-- 	end,
-- 	["collectible"] = function(t)
-- 		return t.questID and C_QuestLog_IsOnQuest(t.questID);
-- 	end,
-- 	["trackable"] = app.ReturnTrue,
-- 	["collected"] = function(t)
-- 		-- If the parent is collected, return immediately.
-- 		local collected = t.parent.collected;
-- 		if collected then return collected; end

-- 		-- Check to see if the objective was completed.
-- 		local objInfo = t.parent.objectiveInfo;
-- 		if objInfo then
-- 			local objective = objInfo[t.objectiveID];
-- 			if objective then return objective.finished and 1; end
-- 		end
-- 	end,
-- 	["saved"] = function(t)
-- 		-- If the parent is saved, return immediately.
-- 		if t.parent.saved then return true; end

-- 		-- Check to see if the objective was completed.
-- 		local objInfo = t.parent.objectiveInfo;
-- 		if objInfo then
-- 			local objective = objInfo[t.objectiveID];
-- 			if objective then return objective.finished and 1; end
-- 		end
-- 	end,
-- };
-- app.BaseQuestObjective = app.BaseObjectFields(fields, "BaseQuestObjective");
-- app.CreateQuestObjective = function(id, t)
-- 	return setmetatable(constructor(id, t, "objectiveID"), app.BaseQuestObjective);
-- end
--]]

-- Vignette Lib
(function()
local function BuildTextFromNPCIDs(t, npcIDs)
	if not npcIDs or #npcIDs == 0 then app.report("Invalid Vignette! "..(t.hash or "[NOHASH]")) end
	local retry, name;
	local textTbl = {};
	for i,npcID in ipairs(npcIDs) do
		name = app.NPCNameFromID[npcID];
		retry = retry or not name or name == RETRIEVING_DATA;
		if not retry then
			textTbl[i * 2 - 1] = name;
			if i > 1 then
				textTbl[(i - 1) * 2] = ", ";
			end
		end
	end
	if retry then return RETRIEVING_DATA; end
	name = table.concat(textTbl);
	rawset(t, "name", name);
	return name;
end
local fields = RawCloneData(questFields, {
	["name"] = function(t)
		if t.qgs or t.crs then
			return BuildTextFromNPCIDs(t, t.qgs or t.crs);
		elseif t.qg or t.creatureID then
			return BuildTextFromNPCIDs(t, { t.qg or t.creatureID });
		end
		return BuildTextFromNPCIDs(t);
	end,
	["icon"] = function(t)
		return "Interface\\Icons\\INV_Misc_Head_Dragon_Black";
	end,
	["isVignette"] = app.ReturnTrue,
});
app.BaseVignette = app.BaseObjectFields(fields, "BaseVignette");
app.CreateVignette = function(id, t)
	return setmetatable(constructor(id, t, "questID"), app.BaseVignette);
end
end)();

app:RegisterEvent("QUEST_SESSION_JOINED");
end)();

-- Achievement Lib
(function()
local GetAchievementCategory, GetAchievementNumCriteria, GetCategoryInfo, GetStatistic = GetAchievementCategory, GetAchievementNumCriteria, GetCategoryInfo, GetStatistic;
local cache = app.CreateCache("achievementID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	--local IDNumber, Name, Points, Completed, Month, Day, Year, Description, Flags, Image, RewardText, isGuildAch = GetAchievementInfo(t.achievementID);
	local _, name, _, _, _, _, _, _, _, icon = GetAchievementInfo(id);
	_t.link = GetAchievementLink(id);
	_t.name = name or ("Achievement #"..id);
	_t.icon = icon or QUESTION_MARK_ICON;
	if field then return _t[field]; end
end
app.AchievementFilter = 4;
local fields = {
	["key"] = function(t)
		return "achievementID";
	end,
	["achievementID"] = function(t)
		local achievementID = t.altAchID and app.FactionID == Enum.FlightPathFaction.Horde and t.altAchID or t.achID;
		if achievementID then
			rawset(t, "achievementID", achievementID);
			return achievementID;
		end
	end,
	["text"] = function(t)
		return t.link or t.name;
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", CacheInfo);
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo);
	end,
	["collectible"] = function(t)
		return app.CollectibleAchievements;
	end,
	["collected"] = function(t)
		if t.saved then return 1; end
		if app.AccountWideAchievements then
			local id = t.achievementID;
			-- cached account-wide credit, or API account-wide credit
			if ATTAccountWideData.Achievements[id] then return 2; end
			local acctApiCredit = select(4, GetAchievementInfo(id));
			if acctApiCredit then
				return 2;
			end
		end
	end,
	["trackable"] = app.ReturnTrue,
	["saved"] = function(t)
		local id = t.achievementID;
		if app.CurrentCharacter.Achievements[id] then return true; end
		local earnedByMe = select(13, GetAchievementInfo(id));
		if earnedByMe then
			app.CurrentCharacter.Achievements[id] = 1;
			ATTAccountWideData.Achievements[id] = 1;
			return true;
		end
	end,
	["parentCategoryID"] = function(t)
		return GetAchievementCategory(t.achievementID) or -1;
	end,
	["statistic"] = function(t)
		if GetAchievementNumCriteria(t.achievementID) == 1 then
			local quantity, reqQuantity = select(4, GetAchievementCriteriaInfo(t.achievementID, 1));
			if quantity and reqQuantity and reqQuantity > 1 then
				return tostring(quantity) .. " / " .. tostring(reqQuantity);
			end
		end
		local statistic = GetStatistic(t.achievementID);
		if statistic and statistic ~= '0' then
			return statistic;
		end
	end,
	["sortProgress"] = function(t)
		if t.collected then
			return 1;
		end
		-- only calculate achievement progress using achievements where the single criteria is the 'progress bar'
		if GetAchievementNumCriteria(t.achievementID) == 1 then
			local quantity, reqQuantity = select(4, GetAchievementCriteriaInfo(t.achievementID, 1));
			if quantity and reqQuantity and reqQuantity > 1 then
				-- print("ach-prog",t.achievementID,quantity,reqQuantity);
				return (quantity / reqQuantity);
			end
		end
		return 0;
	end,
	-- ["OnUpdate"] = function(t) ResolveSymbolicLink(t); end,
};
app.BaseAchievement = app.BaseObjectFields(fields, "BaseAchievement");
app.CreateAchievement = function(id, t)
	return setmetatable(constructor(id, t, "achID"), app.BaseAchievement);
end

local categoryFields = {
	["key"] = function(t)
		return "achievementCategoryID";
	end,
	["name"] = function(t)
		return GetCategoryInfo(t.achievementCategoryID);
	end,
	["icon"] = function(t)
		return app.asset("Category_Achievements");
	end,
	["parentCategoryID"] = function(t)
		return select(2, GetCategoryInfo(t.achievementCategoryID)) or -1;
	end,
};
app.BaseAchievementCategory = app.BaseObjectFields(categoryFields, "BaseAchievementCategory");
app.CreateAchievementCategory = function(id, t)
	return setmetatable(constructor(id, t, "achievementCategoryID"), app.BaseAchievementCategory);
end

-- Achievement Criteria Lib
local function GetParentAchievementInfo(t, key)
	local achievement = app.SearchForObject("achievementID", t.achievementID);
	if achievement then
		rawset(t, "c", achievement["c"]);
		rawset(t, "classID", achievement["classID"]);
		rawset(t, "races", achievement["races"]);
		rawset(t, "r", achievement["r"]);
		return rawget(t, key);
	end
end
local criteriaFields = {
	["key"] = function(t)
		return "criteriaID";
	end,
	["achievementID"] = function(t)
		local achievementID = t.altAchID and app.FactionID == Enum.FlightPathFaction.Horde and t.altAchID or t.achID;
		if achievementID then
			rawset(t, "achievementID", achievementID);
			return achievementID;
		end
		local sourceAch = t.sourceParent or t.parent;
		achievementID = sourceAch and (sourceAch.achievementID or (sourceAch.parent and sourceAch.parent.achievementID));
		if achievementID then
			rawset(t, "achievementID", achievementID);
			return achievementID;
		end
	end,
	["name"] = function(t)
		if t.link then return t.link; end
		if t.encounterID then
			return EJ_GetEncounterInfo(t.encounterID);
		end
		local achievementID = t.achievementID;
		if achievementID then
			local criteriaID = t.criteriaID;
			if criteriaID then
				if criteriaID <= GetAchievementNumCriteria(achievementID) then
					return GetAchievementCriteriaInfo(achievementID, criteriaID, true);
				elseif criteriaID > 50 then
					return GetAchievementCriteriaInfoByID(achievementID, criteriaID);
				end
			end
		end
		return L["WRONG_FACTION"];
	end,
	["description"] = function(t)
		if t.encounterID then
			return select(2, EJ_GetEncounterInfo(t.encounterID));
		end
	end,
	["link"] = function(t)
		if t.itemID then
			local _, link, _, _, _, _, _, _, _, icon = GetItemInfo(t.itemID);
			if link then
				t.text = link;
				t.link = link;
				t.icon = icon;
				return link;
			end
		end
	end,
	["displayID"] = function(t)
		if t.encounterID then
			-- local id, name, description, displayInfo, iconImage = EJ_GetCreatureInfo(1, t.encounterID);
			return select(4, EJ_GetCreatureInfo(t.index, t.encounterID));
		end
	end,
	["displayInfo"] = function(t)
		if t.encounterID then
			local displayInfos, displayInfo = {};
			for i=1,MAX_CREATURES_PER_ENCOUNTER do
				displayInfo = select(4, EJ_GetCreatureInfo(i, t.encounterID));
				if displayInfo then
					tinsert(displayInfos, displayInfo);
				else
					break;
				end
			end
			return displayInfos;
		end
	end,
	["trackable"] = app.ReturnTrue,
	["collected"] = function(t)
		if t.saved then return 1; end
		if app.AccountWideAchievements then
			local achievementID = t.achievementID;
			-- cached account-wide credit, or API account-wide credit
			if achievementID then
				if ATTAccountWideData.Achievements[achievementID] then return 2; end
				local acctApiCredit = select(4, GetAchievementInfo(achievementID));
				if acctApiCredit then
					return 2;
				end
			end
		end
	end,
	["saved"] = function(t)
		local achievementID = t.achievementID;
		if achievementID then
			if app.CurrentCharacter.Achievements[achievementID] then return true; end
			local criteriaID = t.criteriaID;
			if criteriaID then
				if criteriaID <= GetAchievementNumCriteria(achievementID) then
					return select(3, GetAchievementCriteriaInfo(achievementID, criteriaID, true));
				elseif criteriaID > 50 then
					return select(3, GetAchievementCriteriaInfoByID(achievementID, criteriaID));
				end
			end
		end
	end,
	["index"] = function(t)
		return 1;
	end,
	-- Use parent achievement if info not listed directly in the criteria
	["c"] = function(t)
		return GetParentAchievementInfo(t, "c");
	end,
	["classID"] = function(t)
		return GetParentAchievementInfo(t, "classID");
	end,
	["races"] = function(t)
		return GetParentAchievementInfo(t, "races");
	end,
	["r"] = function(t)
		return GetParentAchievementInfo(t, "r");
	end,
};
criteriaFields.collectible = fields.collectible;
criteriaFields.icon = fields.icon;
app.BaseAchievementCriteria = app.BaseObjectFields(criteriaFields, "BaseAchievementCriteria");
app.CreateAchievementCriteria = function(id, t)
	return setmetatable(constructor(id, t, "criteriaID"), app.BaseAchievementCriteria);
end

local HarvestedAchievementDatabase = {};
local harvesterFields = RawCloneData(fields);
harvesterFields.visible = app.ReturnTrue;
harvesterFields.collectible = app.ReturnTrue;
harvesterFields.collected = app.ReturnFalse;
harvesterFields.text = function(t)
	local achievementID = t.achievementID;
	if achievementID then
		local IDNumber, Name, Points, Completed, Month, Day, Year, Description, Flags, Image, RewardText, isGuildAch = GetAchievementInfo(achievementID);
		if Name then
			local info = {
				["name"] = Name,
				["achievementID"] = IDNumber,
				["parentCategoryID"] = GetAchievementCategory(achievementID) or -1,
				["icon"] = Image,
			};
			if Description ~= nil and Description ~= "" then
				info.description = Description;
			end
			local totalCriteria = GetAchievementNumCriteria(achievementID);
			if totalCriteria > 0 then
				local criteria = {};
				for criteriaID=totalCriteria,1,-1 do
					local criteriaString, criteriaType, completed, quantity, reqQuantity, charName, flags, assetID, quantityString, criteriaUID = GetAchievementCriteriaInfo(achievementID, criteriaID);
					local crit = { ["criteriaID"] = criteriaID, ["criteriaUID"] = criteriaUID };
					if criteriaString ~= nil and criteriaString ~= "" then
						crit.name = criteriaString;
					end
					if assetID and assetID ~= 0 then
						crit.assetID = assetID;
					end
					if reqQuantity and reqQuantity > 0 then
						crit.rank = reqQuantity;
					end
					if criteriaType then
						-- Unknown type, not sure what to do with this.
						crit.criteriaType = criteriaType;
						if crit.assetID then
							if criteriaType == 27 then	-- Quest Completion
								crit.sourceQuest = assetID;
								crit.criteriaType = nil;
								crit.assetID = nil;
								if crit.rank and crit.rank == 1 then
									crit.rank = nil;
									break;
								end
							elseif criteriaType == 36 or criteriaType == 41 or criteriaType == 42 then
								-- 36: Items (Generic)
								-- 41: Items (Use/Eat)
								-- 42: Items (Loot)
								if crit.rank and crit.rank < 2 then
									crit.provider = { "i", crit.assetID };
								else
									crit.cost = { { "i", crit.assetID, crit.rank }};
								end
								crit.criteriaType = nil;
								crit.assetID = nil;
								crit.rank = nil;
							elseif criteriaType == 43 then	-- Exploration?!
								crit.explorationID = crit.assetID;
								crit.criteriaType = nil;
								crit.assetID = nil;
								crit.rank = nil;
							elseif criteriaType == 0 then	-- NPC Kills
								crit.provider = { "n", crit.assetID };
								if crit.rank and crit.rank < 2 then
									crit.rank = nil;
								end
								crit.criteriaType = nil;
								crit.assetID = nil;
							elseif criteriaType == 96 then	-- Collect Pets
								crit.provider = { "n", crit.assetID };
								if crit.rank and crit.rank < 2 then
									crit.rank = nil;
								end
								crit.criteriaType = nil;
								crit.assetID = nil;
							elseif criteriaType == 68 or criteriaType == 72 then	-- Interact with Object (68) / Fish from a School (72)
								crit.provider = { "o", crit.assetID };
								if crit.rank and crit.rank < 2 then
									crit.rank = nil;
								end
								crit.criteriaType = nil;
								crit.assetID = nil;
							elseif criteriaType == 7 then	-- Skill ID, Rank is Requirement
								crit.requireSkill = crit.assetID;
								crit.criteriaType = nil;
								crit.assetID = nil;
							elseif criteriaType == 40 then	-- Skill ID Learned
								crit.requireSkill = crit.assetID;
								crit.criteriaType = nil;
								crit.assetID = nil;
								crit.rank = nil;
							elseif criteriaType == 8 then	-- Achievements as Children
								crit.provider = { "a", crit.assetID };
								if crit.rank and crit.rank < 2 then
									crit.rank = nil;
								end
								crit.criteriaType = nil;
								crit.assetID = nil;
							elseif criteriaType == 12 then	-- Currencies (Collected Total)
								if crit.rank and crit.rank < 2 then
									crit.cost = { { "c", crit.assetID, 1 }};
								else
									crit.cost = { { "c", crit.assetID, crit.rank }};
								end
								crit.criteriaType = nil;
								crit.assetID = nil;
								crit.rank = nil;
							elseif criteriaType == 26 then
								-- 26: Environmental Deaths
								--  0: fatigue
								--  1: drowning
								--  2: falling
								--  3/5: fire/lava
								-- https://wowwiki-archive.fandom.com/wiki/API_GetAchievementCriteriaInfo
								if crit.rank and totalCriteria == 1 then
									info.rank = crit.rank;
									break;
								end
							elseif criteriaType == 29 or criteriaType == 69 then	-- Cast X Spell Y Times
								if crit.rank and totalCriteria == 1 then
									info.rank = crit.rank;
									break;
								else
									crit.spellID = crit.assetID;
									crit.criteriaType = nil;
									crit.assetID = nil;
								end
							elseif criteriaType == 46 then	-- Minimum Faction Requirement
								crit.minReputation = { crit.assetID, crit.rank };
								crit.criteriaType = nil;
								crit.assetID = nil;
								crit.rank = nil;
							end
							-- 28: Something to do with event-based encounters, not sure what assetID is.
							-- 49: Something to do with Equipment Slots, assetID is the equipSlotID. (useless maybe?)
							-- 52: Honorable kill on a specific Class, assetID is the ClassID. (useless maybe? might be able to use a class icon?)
							-- 53: Honorable kill on a specific Class at level 35+, assetID is the ClassID. (useless maybe? might be able to use a class icon?)
							-- 54: Show a critter you /love them, assetID is useless or not present.
							-- 70: Honorable Kill at a specific place.
							-- 71: Instance Clears, assetID is of an unknown type... might be Saved Instance ID?
							-- 73: Mal'Ganis? Complete Objective? (useless)
							-- 74: No idea, tracking of some kind
							-- 92: Encounter Kills, of non-NPC type. (Group of NPCs - IE: Lilian Voss)
						elseif criteriaType == 0 or criteriaType == 3 or criteriaType == 5 or criteriaType == 6 or criteriaType == 9 or criteriaType == 10 or criteriaType == 14 or criteriaType == 15 or criteriaType == 17 or criteriaType == 19 or criteriaType == 26 or criteriaType == 37 or criteriaType == 45 or criteriaType == 75 or criteriaType == 78 or criteriaType == 79 or criteriaType == 81 or criteriaType == 90 or criteriaType == 91 or criteriaType == 109 or criteriaType == 124 or criteriaType == 126 or criteriaType == 130 or criteriaType == 134 or criteriaType == 135 or criteriaType == 136 or criteriaType == 138 or criteriaType == 139 or criteriaType == 151 or criteriaType == 156 or criteriaType == 157 or criteriaType == 158 or criteriaType == 200 or criteriaType == 203 or criteriaType == 207 then
							-- 0: Some tracking statistic, generally X/Y format and simple enough to not justify a type if no assetID is present.
							-- 3: Collect X of something that's generic for Archeology
							-- 5: Level Requirement
							-- 6: Digsites (Archeology)
							-- 9: Total Quests Completed
							-- 10: Daily Quests, every day for X days.
							-- 14: Total Daily Quests Completed
							-- 15: Battleground battles
							-- 17: Total Deaths
							-- 19: Instances Run
							-- 26: Environmental Deaths
							-- 37: Ranked Arena Wins
							-- 45: Bank Slots Purchased
							-- 75: Mounts (Total - on one Character)
							-- 78: Kill NPCs
							-- 79: Cook Food
							-- 81: Pet battle achievement points
							-- 90: Gathering (Nodes)
							-- 91: Pet Charm Totals
							-- 109: Catch Fish
							-- 124: Guild Member Repairs
							-- 126: Guild Crafting
							-- 130: Rated Battleground Wins
							-- 134: Complete Quests
							-- 135: Honorable Kills (Total)
							-- 136: Kill Critters
							-- 138: Guild Scenario Challenges Completed
							-- 139: Guild Challenges Completed
							-- 151: Guild Scenario Completed
							-- 156: Collect Pets (Total)
							-- 157: Collect Pets (Rare)
							-- 158: Pet Battles
							-- 200: Recruit Troops
							-- 203: World Quests (Total Complete)
							-- 207: Honor Earned (Total)
							-- https://wowwiki-archive.fandom.com/wiki/API_GetAchievementCriteriaInfo
							if crit.rank and totalCriteria == 1 then
								info.rank = crit.rank;
								break;
							end
						elseif criteriaType == 38 or criteriaType == 39 or criteriaType == 58 or criteriaType == 63 or criteriaType == 65 or criteriaType == 66 or criteriaType == 76 or criteriaType == 77 or criteriaType == 82 or criteriaType == 83 or criteriaType == 84 or criteriaType == 85 or criteriaType == 86 or criteriaType == 107 or criteriaType == 128 or criteriaType == 152 or criteriaType == 153 or criteriaType == 163 then	-- Ignored
							-- 38: Team Rating, which is irrelevant.
							-- 39: Personal Rating, which is irrelevant.
							-- 58: Killing Blows, might specifically be PvP.
							-- 63: Total Gold (Spent on Travel)
							-- 65: Total Gold (Spent on Barber Shop)
							-- 66: Total Gold (Spent on Mail)
							-- 76: Duels Won
							-- 77: Duels Lost
							-- 82: Auctions (Total Posted)
							-- 83: Auctions (Highest Bid)
							-- 84: Auctions (Total Purchases)
							-- 85: Auctions (Highest Sold)]
							-- 86: Most Gold Ever Owned
							-- 107: Quests Abandoned
							-- 128: Guild Bank Tabs
							-- 152: Defeat Scenarios
							-- 153: Ride to Location?
							-- 163: Also ride to location
							break;
						elseif criteriaType == 59 or criteriaType == 62 or criteriaType == 67 or criteriaType == 80 then	-- Gold Cost, if available.
							-- 59: Total Gold (Vendors)
							-- 62: Total Gold (Quest Rewards)
							-- 67: Total Gold (Looted)
							-- 80: Total Gold (Auctions)
							if crit.rank and crit.rank > 1 then
								if totalCriteria == 1 then
									-- Generic, such as the Bread Winner
									info.rank = crit.rank;
									break;
								else
									crit.cost = { { "g", crit.assetID, crit.rank } };
									crit.criteriaType = nil;
									crit.assetID = nil;
									info.rank = nil;
								end
							else
								break;
							end
						end
						-- 155: Collect Battle Pets from a Raid, no assetID though RIP
						-- 158: Defeat Master Trainers
						-- 161: Capture a Battle Pet in a Zone
						-- 163: Defeat an Encounter of some kind? AssetID useless
						-- 169: Construct a building, assetID might be the buildingID.
					end
					tinsert(criteria, 1, crit);
				end
				if #criteria > 0 then info.criteria = criteria; end
			end

			HarvestedAchievementDatabase[achievementID] = info;
			setmetatable(t, app.BaseAchievement);
			rawset(t, "collected", true);
			return Name;
		end
	end

	AllTheThingsHarvestItems = HarvestedAchievementDatabase;
	local name = t.name;
	-- retries exceeded, so check the raw .name on the group (gets assigned when retries exceeded during cache attempt)
	if name then rawset(t, "collected", true); end
	return name;
end
app.BaseAchievementHarvester = app.BaseObjectFields(harvesterFields, "BaseAchievementHarvester");
app.CreateAchievementHarvester = function(id, t)
	return setmetatable(constructor(id, t, "achievementID"), app.BaseAchievementHarvester);
end

local function CheckAchievementCollectionStatus(achievementID)
	if ATTAccountWideData then
		achievementID = tonumber(achievementID);
		local _,_,_,acctCredit,_,_,_,_,_,_,_,isGuild,earnedByMe = GetAchievementInfo(achievementID);
		if earnedByMe then
			app.CurrentCharacter.Achievements[achievementID] = 1;
			ATTAccountWideData.Achievements[achievementID] = 1;
		elseif acctCredit and not isGuild then
			ATTAccountWideData.Achievements[achievementID] = 1;
		end
	end
end
RefreshAchievementCollection = function()
	if ATTAccountWideData then
		local maxid, achID = 0;
		for achievementID,_ in pairs(fieldCache["achievementID"]) do
			achID = tonumber(achievementID);
			if achID > maxid then maxid = achID; end
		end
		for achievementID=maxid,1,-1 do
			CheckAchievementCollectionStatus(achievementID);
		end
	end
end
app:RegisterEvent("ACHIEVEMENT_EARNED");
app.events.ACHIEVEMENT_EARNED = CheckAchievementCollectionStatus;
end)();

-- Artifact Lib
(function()
local artifactItemIDs = {
	[841] = 133755, -- Underlight Angler [Base Skin]
	[988] = 133755, -- Underlight Angler [Fisherfriend of the Isles]
	[989] = 133755, -- Underlight Angler [Fisherfriend of the Isles]
	[1] = {},		-- Off-Hand ItemIDs
};
local fields = {
	["key"] = function(t)
		return "artifactID";
	end,
	["artifactinfo"] = function(t)
		--[[
		local setID, appearanceID, appearanceName, displayIndex, appearanceUnlocked, unlockConditionText,
			uiCameraID, altHandUICameraID, swatchR, swatchG, swatchB,
			modelAlpha, modelDesaturation, suppressGlobalAnim = C_ArtifactUI_GetAppearanceInfoByID(t.artifactID);
		]]--
		local info = { C_ArtifactUI_GetAppearanceInfoByID(t.artifactID) };
		rawset(t, "artifactinfo", info);
		return info;
	end,
	["f"] = function(t)
		return 11;
	end,
	["collectible"] = function(t)
		return app.CollectibleTransmog;
	end,
	["collected"] = function(t)
		if ATTAccountWideData.Artifacts[t.artifactID] then return 1; end
		-- This artifact is listed for the current class
		if not GetRelativeField(t, "nmc", true) and select(5, C_ArtifactUI_GetAppearanceInfoByID(t.artifactID)) then
			ATTAccountWideData.Artifacts[t.artifactID] = 1;
			return 1;
		end
	end,
	["text"] = function(t)
		if not t.artifactinfo then return RETRIEVING_DATA; end
		-- Artifact listing in the Main item sets category just show 'Variant #' but elsewhere show the Item's name
		if t.parent and t.parent.headerID and (t.parent.headerID <= -5200 and t.parent.headerID >= -5205) then
			return t.variantText;
		end
		return t.appearanceText;
	end,
	["title"] = function(t)
		return t.variantText;
	end,
	["variantText"] = function(t)
		return Colorize("Variant " .. t.artifactinfo[4], RGBToHex(t.artifactinfo[9] * 255, t.artifactinfo[10] * 255, t.artifactinfo[11] * 255));
	end,
	["appearanceText"] = function(t)
		return "|cffe6cc80" .. (t.artifactinfo[3] or "???") .. "|r";
	end,
	["description"] = function(t)
		return t.artifactinfo[6] or L["ARTIFACT_INTRO_REWARD"];
	end,
	["atlas"] = function(t)
		return "Forge-ColorSwatchBorder";
	end,
	["atlas-background"] = function(t)
		return "Forge-ColorSwatchBackground";
	end,
	["atlas-border"] = function(t)
		return "Forge-ColorSwatch";
	end,
	["atlas-color"] = function(t)
		return { t.artifactinfo[9], t.artifactinfo[10], t.artifactinfo[11], 1.0 };
	end,
	["model"] = function(t)
		return t.parent and GetRelativeValue(t.parent, "model");
	end,
	["modelScale"] = function(t)
		return t.parent and GetRelativeValue(t.parent, "modelScale") or 0.95;
	end,
	["modelRotation"] = function(t)
		return t.parent and GetRelativeValue(t.parent, "modelRotation") or 45;
	end,
	["silentLink"] = function(t)
		local itemID = t.silentItemID;
		if itemID then
			-- 1 -> Off-Hand Appearance
			-- 2 -> Main-Hand Appearance
			-- return select(2, GetItemInfo(sformat("item:%d::::::::%d:::11:::8:%d:", itemID, app.Level, t.artifactID)));
			-- local link = sformat("item:%d::::::::%d:::11::%d:8:%d:", itemID, app.Level, t.isOffHand and 1 or 2, t.artifactID);
			-- print("Artifact link",t.artifactID,itemID,link);
			return select(2, GetItemInfo(sformat("item:%d:::::::::::11::%d:8:%d:", itemID, t.isOffHand and 1 or 2, t.artifactID)));
		end
	end,
	["silentItemID"] = function(t)
		local itemID;
		if t.isOffHand then
			itemID = artifactItemIDs[1][t.artifactID];
		else
			itemID = artifactItemIDs[t.artifactID];
		end
		if itemID then
			return itemID;
		elseif t.parent and t.parent.headerID and (t.parent.headerID <= -5200 and t.parent.headerID >= -5205) then
			itemID = GetRelativeValue(t.parent, "itemID");
			-- Store the relative ItemID in the artifactItemID cache so it can be referenced accurately by artifacts sourced in specific locations
			if itemID then
				if t.isOffHand then
					artifactItemIDs[1][t.artifactID] = itemID;
				else
					artifactItemIDs[t.artifactID] = itemID;
				end
				-- print("Artifact ItemID Cached",t.artifactID,t.isOffHand,itemID)
			end
			return itemID;
		end
	end,
	["s"] = function(t)
		-- Return the calculated 's' field if existing
		if t._s then return t._s; end
		local s = t.silentLink;
		if s then
			s = app.GetSourceID(s);
			-- print("Artifact Source",s,t.silentLink)
			if s and s > 0 then
				rawset(t, "_s", s);
				if ATTAccountWideData.Sources[s] ~= 1 and C_TransmogCollection_PlayerHasTransmogItemModifiedAppearance(s) then
					-- print("Saved Known Source",s)
					ATTAccountWideData.Sources[s] = 1;
				end
				return s;
			end
		end
	end,
};
app.BaseArtifact = app.BaseObjectFields(fields, "BaseArtifact");
app.CreateArtifact = function(id, t)
	return setmetatable(constructor(id, t, "artifactID"), app.BaseArtifact);
end
end)();

-- Azerite Essence Lib
(function()
local fields = {
	["key"] = function(t)
		return "azeriteEssenceID";
	end,
	["info"] = function(t)
		return C_AzeriteEssence.GetEssenceInfo(t.azeriteEssenceID) or {};
	end,
	["collectible"] = function(t)
		return app.CollectibleAzeriteEssences;
	end,
	["collected"] = function(t)
		if (app.CurrentCharacter.AzeriteEssenceRanks[t.azeriteEssenceID] or 0) >= t.rank then
			return 1;
		end

		local accountRank = ATTAccountWideData.AzeriteEssenceRanks[t.azeriteEssenceID] or 0;
		local info = t.info;
		if info and info.unlocked then
			if t.rank and info.rank then
				if info.rank >= t.rank then
					app.CurrentCharacter.AzeriteEssenceRanks[t.azeriteEssenceID] = info.rank;
					if info.rank > accountRank then ATTAccountWideData.AzeriteEssenceRanks[t.azeriteEssenceID] = info.rank; end
					return 1;
				end
			else
				return 1;
			end
		end

		if app.AccountWideAzeriteEssences and accountRank >= t.rank then
			return 2;
		end
	end,
	["text"] = function(t)
		return t.link;
	end,
	["lvl"] = function(t)
		return 50;
	end,
	["icon"] = function(t)
		return t.info.icon or "Interface/ICONS/INV_Glowing Azerite Spire";
	end,
	["name"] = function(t)
		return t.info.name;
	end,
	["link"] = function(t)
		return C_AzeriteEssence.GetEssenceHyperlink(t.azeriteEssenceID, t.rank);
	end,
	["rank"] = function(t)
		return t.info.rank or 0;
	end,
};
app.BaseAzeriteEssence = app.BaseObjectFields(fields, "BaseAzeriteEssence");
app.CreateAzeriteEssence = function(id, t)
	return setmetatable(constructor(id, t, "azeriteEssenceID"), app.BaseAzeriteEssence);
end
end)();

-- Battle Pet Lib
(function()
-- localized global APIs
local C_PetBattles_GetAbilityInfoByID = C_PetBattles.GetAbilityInfoByID;
local C_PetJournal_GetNumCollectedInfo = C_PetJournal.GetNumCollectedInfo;
local C_PetJournal_GetPetInfoByPetID = C_PetJournal.GetPetInfoByPetID;
local C_PetJournal_GetPetInfoBySpeciesID = C_PetJournal.GetPetInfoBySpeciesID;

local cache = app.CreateCache("speciesID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	-- speciesName, speciesIcon, petType, companionID, tooltipSource, tooltipDescription, isWild,
	-- canBattle, isTradeable, isUnique, obtainable, creatureDisplayID = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
	local speciesName, speciesIcon, petType, _, _, tooltipDescription, _, _, _, _, _, creatureDisplayID = C_PetJournal_GetPetInfoBySpeciesID(id);
	if speciesName then
		_t.name = speciesName;
		_t.icon = speciesIcon;
		_t.petTypeID = petType;
		_t.lore = tooltipDescription;
		_t.displayID = creatureDisplayID;
		if not t.itemID then
			_t.text = "|cff0070dd"..speciesName.."|r";
		end
		if field then return _t[field]; end
	end
end
local function default_link(t)
	if t.itemID then
		return select(2, GetItemInfo(t.itemID));
	end
end
local CollectedSpeciesHelper = setmetatable({}, {
	__index = function(t, key)
		if C_PetJournal_GetNumCollectedInfo(key) > 0 then
			rawset(t, key, 1);
			return 1;
		end
	end
});
local fields = {
	["key"] = function(t)
		return "speciesID";
	end,
	["filterID"] = function(t)
		return 101;
	end,
	["collectible"] = function(t)
		return app.CollectibleBattlePets;
	end,
	["collected"] = function(t)
		if CollectedSpeciesHelper[t.speciesID] then
			return 1;
		end
		local altSpeciesID = t.altSpeciesID;
		if altSpeciesID and CollectedSpeciesHelper[altSpeciesID]then
			return 2;
		end
	end,
	["text"] = function(t)
		return t.link or cache.GetCachedField(t, "text", CacheInfo);
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo);
	end,
	["lore"] = function(t)
		return cache.GetCachedField(t, "lore", CacheInfo);
	end,
	["displayID"] = function(t)
		return cache.GetCachedField(t, "displayID", CacheInfo);
	end,
	["petTypeID"] = function(t)
		return cache.GetCachedField(t, "petTypeID", CacheInfo);
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", default_link);
	end,
	["tsm"] = function(t)
		return sformat("p:%d:1:3", t.speciesID);
	end,
};
app.BaseSpecies = app.BaseObjectFields(fields, "BaseSpecies");
app.CreateSpecies = function(id, t)
	return setmetatable(constructor(id, t, "speciesID"), app.BaseSpecies);
end

app.events.NEW_PET_ADDED = function(petID)
	local speciesID = C_PetJournal_GetPetInfoByPetID(petID);
	-- app.PrintDebug("NEW_PET_ADDED", petID, speciesID);
	if speciesID and C_PetJournal_GetNumCollectedInfo(speciesID) > 0 and not rawget(CollectedSpeciesHelper, speciesID) then
		rawset(CollectedSpeciesHelper, speciesID, 1);
		UpdateSearchResults(SearchForField("speciesID", speciesID));
		app:PlayFanfare();
		app:TakeScreenShot("BattlePets");
		wipe(searchCache);
	end
end
app.events.PET_JOURNAL_PET_DELETED = function(petID)
	-- /dump C_PetJournal.GetPetInfoByPetID("BattlePet-0-00001006503D")
	-- local speciesID = C_PetJournal.GetPetInfoByPetID(petID);
	-- NOTE: Above APIs do not work in the DELETED API, THANKS BLIZZARD
	-- app.PrintDebug("PET_JOURNAL_PET_DELETED",petID);

	-- Check against all of the collected species for a species that is no longer 1/X
	local missing = {};
	for speciesID,_ in pairs(CollectedSpeciesHelper) do
		if C_PetJournal_GetNumCollectedInfo(speciesID) < 1 then
			-- app.PrintDebug("Pet Missing",speciesID);
			rawset(CollectedSpeciesHelper, speciesID, nil);
			tinsert(missing, speciesID);
		end
	end
	if #missing > 0 then
		app:PlayRemoveSound();
	end
	UpdateRawIDs("speciesID", missing);
end

local fields = {
	["key"] = function(t)
		return "petAbilityID";
	end,
	["text"] = function(t)
		return select(2, C_PetBattles_GetAbilityInfoByID(t.petAbilityID));
	end,
	["icon"] = function(t)
		return select(3, C_PetBattles_GetAbilityInfoByID(t.petAbilityID));
	end,
	["description"] = function(t)
		return select(5, C_PetBattles_GetAbilityInfoByID(t.petAbilityID));
	end,
};
app.BasePetAbility = app.BaseObjectFields(fields, "BasePetAbility");
app.CreatePetAbility = function(id, t)
	return setmetatable(constructor(id, t, "petAbilityID"), app.BasePetAbility);
end

local fields = {
	["key"] = function(t)
		return "petTypeID";
	end,
	["text"] = function(t)
		return _G["BATTLE_PET_NAME_" .. t.petTypeID];
	end,
	["icon"] = function(t)
		return "Interface\\Icons\\Icon_PetFamily_"..PET_TYPE_SUFFIX[t.petTypeID];
	end,
	["filterID"] = function(t)
		return 101;
	end,
};
app.BasePetType = app.BaseObjectFields(fields, "BasePetType");
app.CreatePetType = function(id, t)
	return setmetatable(constructor(id, t, "petTypeID"), app.BasePetType);
end
end)();

-- Category Lib
(function()
local fields = {
	["key"] = function(t)
		return "categoryID";
	end,
	["name"] = function(t)
		return AllTheThingsAD.LocalizedCategoryNames[t.categoryID] or ("Unknown Category #" .. t.categoryID);
	end,
	["icon"] = function(t)
		return AllTheThings.CategoryIcons[t.categoryID] or "Interface/ICONS/INV_Garrison_Blueprints1";
	end,
};
app.BaseCategory = app.BaseObjectFields(fields, "BaseCategory");
app.CreateCategory = function(id, t)
	return setmetatable(constructor(id, t, "categoryID"), app.BaseCategory);
end
end)();

-- Character Class Lib
(function()
local class_id_cache = {};
for i=1,GetNumClasses() do
	class_id_cache[select(2, GetClassInfo(i))] = i;
end
local classIcons = {
	[1] = "Interface\\Icons\\ClassIcon_Warrior",
	[2] = "Interface\\Icons\\ClassIcon_Paladin",
	[3] = "Interface\\Icons\\ClassIcon_Hunter",
	[4] = "Interface\\Icons\\ClassIcon_Rogue",
	[5] = "Interface\\Icons\\ClassIcon_Priest",
	[6] = "Interface\\Icons\\ClassIcon_DeathKnight",
	[7] = "Interface\\Icons\\ClassIcon_Shaman",
	[8] = "Interface\\Icons\\ClassIcon_Mage",
	[9] = "Interface\\Icons\\ClassIcon_Warlock",
	[10] = "Interface\\Icons\\ClassIcon_Monk",
	[11] = "Interface\\Icons\\ClassIcon_Druid",
	[12] = "Interface\\Icons\\ClassIcon_DemonHunter",
	[13] = "Interface\\Icons\\ClassIcon_Evoker",
};
local GetClassIDFromClassFile = function(classFile)
	for i,icon in pairs(classIcons) do
		local info = C_CreatureInfo.GetClassInfo(i);
		if info and info.classFile == classFile then
			return i;
		end
	end
end
app.ClassDB = setmetatable({}, { __index = function(t, className)
	for i,_ in pairs(classIcons) do
		local info = C_CreatureInfo.GetClassInfo(i);
		if info and info.className == className then
			rawset(t, className, i);
			return i;
		end
	end
end });
local math_floor = math.floor;
local cache = app.CreateCache("classID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	-- specc can be included in the id
	local classID = math_floor(id);
	rawset(t, "classKey", classID);
	local specc_decimal = 1000 * (id - classID);
	local specc = math_floor(specc_decimal + 0.00001);
	if specc > 0 then
		local _, text, _, icon = GetSpecializationInfoForSpecID(specc);
		text = "|c" .. t.classColors.colorStr .. text .. "|r";
		_t.text = text;
		_t.icon = icon;
	else
		local text = GetClassInfo(t.classID);
		text = "|c" .. t.classColors.colorStr .. text .. "|r";
		_t.text = text;
		_t.icon = classIcons[t.classID]
	end
	if field then return _t[field]; end
end
local fields = {
	["key"] = function(t)
		return "classID";
	end,
	["text"] = function(t)
		local text = cache.GetCachedField(t, "text", CacheInfo);
		if t.mapID then
			text = app.GetMapName(t.mapID) .. " (" .. text .. ")";
		elseif t.maps then
			text = app.GetMapName(t.maps[1]) .. " (" .. text .. ")";
		end
		text = "|c" .. t.classColors.colorStr .. text .. "|r";
		rawset(t, "text", text);
		return text;
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo);
		-- return classIcons[t.classID];
	end,
	["c"] = function(t)
		local c = { math_floor(t.classID) };
		rawset(t, "c", c);
		return c;
	end,
	["nmc"] = function(t)
		return math_floor(t.classID) ~= app.ClassIndex;
	end,
	["classColors"] = function(t)
		return RAID_CLASS_COLORS[select(2, GetClassInfo(math_floor(t.classID)))];
	end,
};
app.BaseCharacterClass = app.BaseObjectFields(fields, "BaseCharacterClass");
app.CreateCharacterClass = function(id, t)
	return setmetatable(constructor(id, t, "classID"), app.BaseCharacterClass);
end
local unitFields = {
	["key"] = function(t)
		return "unit";
	end,
	["text"] = function(t)
		for guid,character in pairs(ATTCharacterData) do
			if guid == t.unit or character.name == t.unit then
				rawset(t, "text", character.text);
				rawset(t, "level", character.lvl);
				if character.classID then
					rawset(t, "classID", character.classID);
					rawset(t, "class", C_CreatureInfo.GetClassInfo(character.classID).className);
				end
				if character.raceID then
					rawset(t, "raceID", character.raceID);
					rawset(t, "race", C_CreatureInfo.GetRaceInfo(character.raceID).raceName);
				end
				return character.text;
			end
		end

		local name, realm = UnitName(t.unit);
		if name then
			if realm and realm ~= "" then name = name .. "-" .. realm; end
			local _, classFile, classID = UnitClass(t.unit);
			if classFile then
				rawset(t, "classID", classID);
				name = "|c" .. RAID_CLASS_COLORS[classFile].colorStr .. name .. "|r";
			end
			return name;
		end
		return t.unit;
	end,
	["icon"] = function(t)
		if t.classID then return classIcons[t.classID]; end
	end,
	["name"] = function(t)
		return UnitName(t.unit);
	end,
	["guid"] = function(t)
		return UnitGUID(t.unit);
	end,
	["title"] = function(t)
		if IsInGroup() then
			if rawget(t, "isML") then return MASTER_LOOTER; end
			if UnitIsGroupLeader(t.unit) then return RAID_LEADER; end
		end
	end,
	["description"] = function(t)
		return LEVEL .. " " .. (t.level or RETRIEVING_DATA) .. " " .. (t.race or RETRIEVING_DATA) .. " " .. (t.class or RETRIEVING_DATA);
	end,
	["level"] = function(t)
		return UnitLevel(t.unit);
	end,
	["race"] = function(t)
		return UnitRace(t.unit);
	end,
	["class"] = function(t)
		return UnitClass(t.unit);
	end,
};
app.BaseUnit = app.BaseObjectFields(unitFields, "BaseUnit");
app.CreateUnit = function(unit, t)
	return setmetatable(constructor(unit, t, "unit"), app.BaseUnit);
end
end)();

-- Currency Lib
(function()
local C_CurrencyInfo_GetCurrencyInfo = C_CurrencyInfo.GetCurrencyInfo;
local C_CurrencyInfo_GetCurrencyLink = C_CurrencyInfo.GetCurrencyLink;
local cache = app.CreateCache("currencyID");
local function default_text(t)
	return t.link or t.name;
end
local function default_info(t)
	return C_CurrencyInfo_GetCurrencyInfo(t.currencyID);
end
local function default_link(t)
	return C_CurrencyInfo_GetCurrencyLink(t.currencyID, 1);
end
local function default_costCollectibles(t)
	local id = t.currencyID;
	if id then
		local results = app.SearchForField("currencyIDAsCost", id);
		if results and #results > 0 then
			-- app.PrintDebug("default_costCollectibles",t.hash,#results)
			return results;
		end
	end
	return app.EmptyTable;
end
local fields = {
	["key"] = function(t)
		return "currencyID";
	end,
	["_cache"] = function(t)
		return cache;
	end,
	["text"] = function(t)
		return cache.GetCachedField(t, "text", default_text);
	end,
	["info"] = function(t)
		return cache.GetCachedField(t, "info", default_info);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", default_link);
	end,
	["icon"] = function(t)
		local info = t.info;
		return info and info.iconFileID;
	end,
	["name"] = function(t)
		local info = t.info;
		return info and info.name or ("Currency #" .. t.currencyID);
	end,
	["costCollectibles"] = function(t)
		return cache.GetCachedField(t, "costCollectibles", default_costCollectibles);
	end,
	["collectibleAsCost"] = app.CollectibleAsCost,
};
app.BaseCurrencyClass = app.BaseObjectFields(fields, "BaseCurrencyClass");
app.CreateCurrencyClass = function(id, t)
	return setmetatable(constructor(id, t, "currencyID"), app.BaseCurrencyClass);
end
end)();

-- Death Tracker Lib
(function()
local OnUpdateForDeathTrackerLib = function(t)
	if app.MODE_DEBUG then -- app.Settings:Get("Thing:Deaths");
		t.visible = app.GroupVisibilityFilter(t);
		local stat = select(1, GetStatistic(60)) or "0";
		if stat == "--" then stat = "0"; end
		local deaths = tonumber(stat);
		if deaths > 0 and deaths > app.CurrentCharacter.Deaths then
			ATTAccountWideData.Deaths = ATTAccountWideData.Deaths + (deaths - app.CurrentCharacter.Deaths);
			app.CurrentCharacter.Deaths = deaths;
		end
		t.parent.progress = t.parent.progress + t.progress;
		t.parent.total = t.parent.total + t.total;
	else
		t.visible = false;
	end
	return false;
end
local fields = {
	["key"] = function(t)
		return "deaths";
	end,
	["text"] = function(t)
		return "Total Deaths";
	end,
	["icon"] = function(t)
		return app.asset("Category_Deaths");
	end,
	["progress"] = function(t)
		return math.min(1000, app.AccountWideDeaths and ATTAccountWideData.Deaths or app.CurrentCharacter.Deaths);
	end,
	["total"] = function(t)
		return 1000;
	end,
	["description"] = function(t)
		return "The ATT Gods must be sated. Go forth and attempt to level, mortal!\n\n 'Live! Die! Live Again!'\n";
	end,
	["OnTooltip"] = function(t)
		local c = {};
		for guid,character in pairs(ATTCharacterData) do
			if character and character.Deaths and character.Deaths > 0 then
				tinsert(c, character);
			end
		end
		if #c > 0 then
			GameTooltip:AddLine(" ");
			GameTooltip:AddLine("Deaths Per Character:");
			app.Sort(c, function(a, b)
				return a.Deaths > b.Deaths;
			end);
			for i,data in ipairs(c) do
				GameTooltip:AddDoubleLine("  " .. string.gsub(data.text, "-" .. GetRealmName(), ""), data.Deaths, 1, 1, 1);
			end
		end
	end,
	["OnUpdate"] = function(t)
		return OnUpdateForDeathTrackerLib;
	end,
};
app.BaseDeathClass = app.BaseObjectFields(fields, "BaseDeathClass");
app.CreateDeathClass = function()
	return setmetatable({}, app.BaseDeathClass);
end
end)();

-- Difficulty Lib
(function()
app.DifficultyColors = {
	[2] = "ff0070dd",
	[5] = "ff0070dd",
	[6] = "ff0070dd",
	[7] = "ff9d9d9d",
	[15] = "ff0070dd",
	[16] = "ffa335ee",
	[17] = "ff9d9d9d",
	[23] = "ffa335ee",
	[24] = "ffe6cc80",
	[33] = "ffe6cc80",
};
app.DifficultyIcons = {
	[-1] = app.asset("Difficulty_LFR"),
	[-2] = app.asset("Difficulty_Normal"),
	[-3] = app.asset("Difficulty_Heroic"),
	[-4] = app.asset("Difficulty_Mythic"),
	[1] = app.asset("Difficulty_Normal"),
	[2] = app.asset("Difficulty_Heroic"),
	[3] = app.asset("Difficulty_Normal"),
	[4] = app.asset("Difficulty_Normal"),
	[5] = app.asset("Difficulty_Heroic"),
	[6] = app.asset("Difficulty_Heroic"),
	[7] = app.asset("Difficulty_LFR"),
	[9] = app.asset("Difficulty_Mythic"),
	[11] = app.asset("Difficulty_Normal"),
	[12] = app.asset("Difficulty_Heroic"),
	[14] = app.asset("Difficulty_Normal"),
	[15] = app.asset("Difficulty_Heroic"),
	[16] = app.asset("Difficulty_Mythic"),
	[17] = app.asset("Difficulty_LFR"),
	[18] = app.asset("Category_Event"),
	[23] = app.asset("Difficulty_Mythic"),
	[24] = app.asset("Difficulty_Timewalking"),
	[33] = app.asset("Difficulty_Timewalking"),
};
local fields = {
	["key"] = function(t)
		return "difficultyID";
	end,
	["text"] = function(t)
		local text = L["CUSTOM_DIFFICULTIES"][t.difficultyID] or GetDifficultyInfo(t.difficultyID) or "Unknown Difficulty";
		-- don't follow sourceParent
		local parent = rawget(t, "parent");
		local parentInstance = parent and parent.instanceID;
		if parentInstance then
			return text;
		else
			-- append the name of the Source Instance which contains this diffculty group to help distinguish (LFR Queue NPCs)
			parentInstance = t.sourceParent;
			if parentInstance then
				text = sformat("%s [%s]", text, parentInstance and parentInstance.text or UNKNOWN);
			end
			return text;
		end
	end,
	["icon"] = function(t)
		return app.DifficultyIcons[t.difficultyID];
	end,
	["trackable"] = app.ReturnTrue,
	["saved"] = function(t)
		return t.locks;
	end,
	["locks"] = function(t)
		local locks = t.parent and t.parent.locks;
		if locks then
			if t.parent.isLockoutShared and not (t.difficultyID == 7 or t.difficultyID == 17) then
				rawset(t, "locks", locks.shared);
				return locks.shared;
			else
				-- Look for this difficulty's lockout.
				for difficultyKey, lock in pairs(locks) do
					if difficultyKey == "shared" then
						-- ignore this one
					elseif difficultyKey == t.difficultyID then
						rawset(t, "locks", lock);
						return lock;
					end
				end
			end
		end
	end,
	["u"] = function(t)
		if t.difficultyID == 24 or t.difficultyID == 33 then
			return 1016;
		end
	end,
	["description"] = function(t)
		if t.difficultyID == 24 or t.difficultyID == 33 then
			return L["WE_JUST_HATE_TIMEWALKING"];
		end
	end,
};
app.BaseDifficulty = app.BaseObjectFields(fields, "BaseDifficulty");
app.CreateDifficulty = function(id, t)
	return setmetatable(constructor(id, t, "difficultyID"), app.BaseDifficulty);
end
end)();

-- Encounter Lib
(function()
local cache = app.CreateCache("encounterID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	local name, lore, _, _, link = EJ_GetEncounterInfo(id);
	_t.name = name;
	_t.lore = lore;
	_t.link = link;
	_t.displayID = select(4, EJ_GetCreatureInfo(1, id));
	if field then return _t[field]; end
end
local function default_displayInfo(t)
	local displayInfos, id, displayInfo = {}, t.encounterID;
	for i=1,MAX_CREATURES_PER_ENCOUNTER do
		displayInfo = select(4, EJ_GetCreatureInfo(i, id));
		if displayInfo then
			tinsert(displayInfos, displayInfo);
		else
			break;
		end
	end
	return displayInfos;
end
local fields = {
	["key"] = function(t)
		return "encounterID";
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["lore"] = function(t)
		return cache.GetCachedField(t, "lore", CacheInfo);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", CacheInfo);
	end,
	["displayID"] = function(t)
		return cache.GetCachedField(t, "displayID", CacheInfo);
	end,
	["displayInfo"] = function(t)
		return cache.GetCachedField(t, "displayInfo", default_displayInfo);
	end,
	["icon"] = function(t)
		return app.DifficultyIcons[GetRelativeValue(t, "difficultyID") or 1];
	end,
	["trackable"] = function(t)
		return t.questID;
	end,
	["saved"] = function(t)
		-- only consider encounters saved if saved for the current character
		return IsQuestFlaggedCompleted(t.questID);
	end,
	["index"] = function(t)
		return 1;
	end,
};
app.BaseEncounter = app.BaseObjectFields(fields, "BaseEncounter");
app.CreateEncounter = function(id, t)
	return setmetatable(constructor(id, t, "encounterID"), app.BaseEncounter);
end
end)();

-- Faction Lib
(function()
local GetFriendshipReputation, GetFriendshipReputationRanks =
	GetFriendshipReputation, GetFriendshipReputationRanks;

-- 10.0 Blizz does some weird stuff with Friendship functions now, so let's try to wrap the functionality to work with what we expected before... at least for now
if C_GossipInfo then
	local GetBlizzFriendship = C_GossipInfo.GetFriendshipReputation;
	GetFriendshipReputation = function(factionID, field)
		local friendInfo = GetBlizzFriendship(factionID);
		local friendFactionID = friendInfo and friendInfo.friendshipFactionID or 0;
		if friendFactionID ~= 0 then
			return field and friendInfo[field] or true;
		end
	end
	local GetBlizzFriendshipRanks = C_GossipInfo.GetFriendshipReputationRanks;
	GetFriendshipReputationRanks = function(factionID)
		local rankInfo = GetBlizzFriendshipRanks(factionID);
		local maxLevel = rankInfo and rankInfo.maxLevel or 0;
		if maxLevel ~= 0 then
			return rankInfo.currentLevel, maxLevel;
		end
	end
end
local StandingByID = {
	[0] = {	-- 0: No Standing (Not in a Guild)
		["color"] = "00404040",
		["threshold"] = -99999,
	},
	{	-- 1: HATED
		["color"] = GetProgressColor(0),
		["threshold"] = -42000,
	},
	{	-- 2: HOSTILE
		["color"] = "00FF0000",
		["threshold"] = -6000,
	},
	{	-- 3: UNFRIENDLY
		["color"] = "00EE6622",
		["threshold"] = -3000,
	},
	{	-- 4: NEUTRAL
		["color"] = "00FFFF00",
		["threshold"] = 0,
	},
	{	-- 5: FRIENDLY
		["color"] = "0000FF00",
		["threshold"] = 3000,
	},
	{	-- 6: HONORED
		["color"] = "0000FF88",
		["threshold"] = 9000,
	},
	{	-- 7: REVERED
		["color"] = "0000FFCC",
		["threshold"] = 21000,
	},
	{	-- 8: EXALTED
		["color"] = GetProgressColor(1),
		["threshold"] = 42000,
	},
};
app.FactionNameByID = setmetatable({}, { __index = function(t, id)
	local name = select(1, GetFactionInfoByID(id)) or GetFriendshipReputation(id, "name");
	if name then
		rawset(t, id, name);
		rawset(app.FactionIDByName, name, id);
		return name;
	end
end });
app.FactionIDByName = setmetatable({}, { __index = function(t, name)
	for i=1,3000,1 do
		if app.FactionNameByID[i] == name then
			rawset(t, name, i);
			return i;
		end
	end
end });
app.FACTION_RACES = {
	[1] = {
		1,	-- Human
		3,	-- Dwarf
		4,	-- Night Elf
		7,	-- Gnome
		11,	-- Draenei
		22,	-- Worgen
		25,	-- Pandaren [Alliance]
		29,	-- Void Elf
		30,	-- Lightforged
		32,	-- Kul Tiran
		34,	-- Dark Iron
		37,	-- Mechagnome
	},
	[2] = {
		2,	-- Orc
		5,	-- Undead
		6,	-- Tauren
		8,	-- Troll
		9,	-- Goblin
		10,	-- Blood Elf
		26,	-- Pandaren [Horde]
		27,	-- Nightborne
		28,	-- Highmountain
		31,	-- Zandalari
		35,	-- Vulpera
		36,	-- Mag'har
	}
};
app.GetFactionIDByName = function(name)
	name = strtrim(name);
	return app.FactionIDByName[name] or name;
end
app.GetFactionStanding = function(reputationPoints)
	-- Total earned rep from GetFactionInfoByID is a value AWAY FROM ZERO, not a value within the standing bracket.
	if reputationPoints then
		if type(reputationPoints) == "table" then
			return app.GetReputationStanding(reputationPoints);
		end
		for i=#StandingByID,1,-1 do
			local threshold = StandingByID[i].threshold;
			if reputationPoints >= threshold then
				return i, threshold < 0 and (threshold - reputationPoints) or (reputationPoints - threshold);
			end
		end
	end
	return 1, 0
end
-- Given a maxReputation/minReputation table, will return the proper StandingID and Amount into that Standing associated with the data
app.GetReputationStanding = function(reputationInfo)
	local factionID, standingOrAmount = reputationInfo[1], reputationInfo[2];
	-- make it really easy to use threshold checks by directly providing the expected standing
	-- incoming value can also be negative for hostile standings, so check directly on the table
	if standingOrAmount > 0 and StandingByID[standingOrAmount] then
		return standingOrAmount, 0;
	else
		local friend = GetFriendshipReputation(factionID);
		if friend then
			-- don't think there's a good standard way to determine friendship rank from an arbitrary amount of reputation...
			print("Convert Friendship Reputation Threshold to StandingID",factionID,standingOrAmount)
			return 1, standingOrAmount;
		else
			-- Total earned rep from GetFactionInfoByID is a value AWAY FROM ZERO, not a value within the standing bracket.
			for i=#StandingByID,1,-1 do
				local threshold = StandingByID[i].threshold;
				if standingOrAmount >= threshold then
					return i, threshold < 0 and (threshold - standingOrAmount) or (standingOrAmount - threshold);
				end
			end
		end
	end
end
local function GetCurrentFactionStandings(factionID)
	local standing, maxStanding = 0, 8;
	local friend = GetFriendshipReputation(factionID);
	if friend then
		standing, maxStanding = GetFriendshipReputationRanks(factionID);
	else
		standing = select(3, GetFactionInfoByID(factionID));
	end
	return standing or 1, maxStanding;
end
app.GetCurrentFactionStandings = GetCurrentFactionStandings;
-- Returns the 'text' colorized to match a specific standard 'StandingID'
local function ColorizeStandingText(standingID, text)
	local standing = StandingByID[standingID];
	if standing then
		return Colorize(text, standing.color);
	else
		local rgb = FACTION_BAR_COLORS[standingID];
		return Colorize(text, RGBToHex(rgb.r * 255, rgb.g * 255, rgb.b * 255));
	end
end
-- Returns StandingText or Requested Standing colorzing the 'Standing' text for the Faction, or otherwise the provided 'textOverride'
app.GetCurrentFactionStandingText = function(factionID, requestedStanding, textOverride)
	local standing = requestedStanding or GetCurrentFactionStandings(factionID);
	local friendStandingText = GetFriendshipReputation(factionID, "reaction");
	if friendStandingText then
		local _, maxStanding = GetFriendshipReputationRanks(factionID);
		-- adjust relative to max based on the actual max ranks of the friendship faction
		-- prevent any weirdness of requesting a standing higher than the max for the friendship
		local progress = math.min(standing, maxStanding) / maxStanding;
		-- if we requested a specific standing, we can't rely on the friendship text to be accurate
		if requestedStanding then
			friendStandingText = "Rank "..requestedStanding;
		end
		-- friendships simply colored based on rank progress, some friendships have more ranks than faction standings... makes it weird to correlate them
		return Colorize(textOverride or friendStandingText, GetProgressColor(progress));
	end
	return ColorizeStandingText(standing, textOverride or friendStandingText or _G["FACTION_STANDING_LABEL" .. standing] or UNKNOWN);
end
app.GetFactionStandingThresholdFromString = function(replevel)
	replevel = strtrim(replevel);
	for standing=1,8,1 do
		if _G["FACTION_STANDING_LABEL" .. standing] == replevel then
			return StandingByID[standing].threshold;
		end
	end
end
app.IsFactionExclusive = function(factionID)
	return factionID == 934 or factionID == 932 or factionID == 1104 or factionID == 1105;
end
local cache = app.CreateCache("factionID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	-- do not attempt caching more than 1 time per factionID since not every cached field may have a cached value
	if _t.name then return end
	local factionInfo = { GetFactionInfoByID(id) };
	local friendshipName = GetFriendshipReputation(id, "name");
	local name = factionInfo[1] or friendshipName;
	local lore = factionInfo[2];
	_t.name = name or (t.creatureID and app.NPCNameFromID[t.creatureID]) or (FACTION .. " #" .. id);
	if lore then
		_t.lore = lore;
	elseif not name then
		_t.description = L["FACTION_SPECIFIC_REP"];
	end
	if friendshipName then
		rawset(t, "isFriend", true);
		local friendship = GetFriendshipReputation(id, "text");
		if friendship then
			if _t.lore then
		 		_t.lore = _t.lore.."\n\n"..friendship;
			else
		 		_t.lore = friendship;
			end
		 end
	end
	if field then return _t[field]; end
end
local fields = {
	["key"] = function(t)
		return "factionID";
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["description"] = function(t)
		return cache.GetCachedField(t, "description", CacheInfo);
	end,
	["lore"] = function(t)
		return cache.GetCachedField(t, "lore", CacheInfo);
	end,
	["icon"] = function(t)
		return t.achievementID and select(10, GetAchievementInfo(t.achievementID))
			or L["FACTION_ID_ICONS"][t.factionID]
			or t.isFriend and GetFriendshipReputation(t.factionID, "texture")
			or app.asset("Category_Factions");
	end,
	["link"] = function(t)
		return t.achievementID and GetAchievementLink(t.achievementID);
	end,
	["achievementID"] = function(t)
		local achievementID = t.altAchID and app.FactionID == Enum.FlightPathFaction.Horde and t.altAchID or t.achID;
		if achievementID then
			rawset(t, "achievementID", achievementID);
			return achievementID;
		end
	end,
	["filterID"] = function(t)
		return 112;
	end,
	["trackable"] = app.ReturnTrue,
	["collectible"] = function(t)
		if app.CollectibleReputations then
			-- If your reputation is higher than the maximum for a different faction, return partial completion.
			if not app.AccountWideReputations and t.maxReputation and t.maxReputation[1] ~= t.factionID and (select(3, GetFactionInfoByID(t.maxReputation[1])) or 4) >= app.GetFactionStanding(t.maxReputation[2]) then
				return false;
			end
			return true;
		end
		return false;
	end,
	["collected"] = function(t)
		if t.saved then return 1; end
		if app.AccountWideReputations and ATTAccountWideData.Factions[t.factionID] then return 2; end

		-- If there's an associated achievement, return partial completion.
		if t.achievementID and select(4, GetAchievementInfo(t.achievementID)) then
			return 2;
		end

		-- If this can be completed by completing a different achievement, return partial completion.
		if t.altAchievements then
			for i,achID in ipairs(t.altAchievements) do
				if select(4, GetAchievementInfo(achID)) then
					return 2;
				end
			end
		end
	end,
	["saved"] = function(t)
		local factionID = t.factionID;
		if app.CurrentCharacter.Factions[factionID] then return true; end
		if t.standing >= t.maxstanding then
			app.CurrentCharacter.Factions[factionID] = 1;
			ATTAccountWideData.Factions[factionID] = 1;
			return true;
		end
	end,
	["title"] = function(t)
		local title = app.GetCurrentFactionStandingText(t.factionID);
		if t.isFriend then
			local reputation = t.reputation;
			local amount, ceiling = select(2, app.GetFactionStanding(reputation)), t.ceiling;
			if ceiling then
				title = title .. DESCRIPTION_SEPARATOR .. amount .. " / " .. ceiling;
				if reputation < 42000 then
					return title .. " (" .. (42000 - reputation) .. ")";
				end
			end
			return title;
		else
			local reputation = t.reputation;
			local amount, ceiling = select(2, app.GetFactionStanding(reputation)), t.ceiling;
			if ceiling then
				title = title .. DESCRIPTION_SEPARATOR .. amount .. " / " .. ceiling;
				if reputation < 42000 then
					return title .. " (" .. (42000 - reputation) .. " to " .. _G["FACTION_STANDING_LABEL8"] .. ")";
				end
			end
			return title;
		end
	end,
	["isFriend"] = function(t)
		if GetFriendshipReputation(t.factionID) then
			rawset(t, "isFriend", true);
			return true;
		else
			rawset(t, "isFriend", false);
			return false;
		end
	end,
	["reputation"] = function(t)
		return select(6, GetFactionInfoByID(t.factionID)) or 0;
	end,
	["ceiling"] = function(t)
		local _, _, _, m, ma = GetFactionInfoByID(t.factionID);
		return ma and m and (ma - m);
	end,
	["standing"] = function(t)
		return GetCurrentFactionStandings(t.factionID);
	end,
	["maxstanding"] = function(t)
		if t.minReputation and t.minReputation[1] == t.factionID then
			app.PrintDebug("Faction with MinReputation??",t.factionID)
			return app.GetFactionStanding(t.minReputation[2]);
		end
		local _, maxStanding = GetCurrentFactionStandings(t.factionID);
		rawset(t, "maxStanding", maxStanding);
		return maxStanding;
	end,
	["sortProgress"] = function(t)
		return ((t.reputation or -42000) + 42000) / 84000;
	end,
};
app.BaseFaction = app.BaseObjectFields(fields, "BaseFaction");
app.CreateFaction = function(id, t)
	return setmetatable(constructor(id, t, "factionID"), app.BaseFaction);
end
app.OnUpdateReputationRequired = function(t)
	-- The only non-regular update processing this group should have
	-- is if the User is not in Debug/Account and should not see it due to the reputation requirement not being met
	if not app.MODE_DEBUG_OR_ACCOUNT and t.minReputation and (select(6, GetFactionInfoByID(t.minReputation[1])) or 0) < t.minReputation[2] then
		t.visible = false;
		return true;
	end
	-- Returns false since we need to just call the regular update group logic
	return false;
end
end)();

-- Filter Lib
(function()
local fields = {
	["key"] = function(t)
		return "filterID";
	end,
	["text"] = function(t)
		return L["FILTER_ID_TYPES"][t.filterID];
	end,
	["name"] = function(t)
		return t.text;
	end,
	["icon"] = function(t)
		return L["FILTER_ID_ICONS"][t.filterID];
	end,
};
app.BaseFilter = app.BaseObjectFields(fields, "BaseFilter");
app.CreateFilter = function(id, t)
	return setmetatable(constructor(id, t, "filterID"), app.BaseFilter);
end
end)();

-- Flight Path Lib
(function()
local arrOfNodes = {
	1,		-- Durotar (All of Kalimdor)
	36,		-- Burning Steppes (All of Eastern Kingdoms)
	94,		-- Eversong Woods (and Ghostlands + Isle of Quel'Danas)
	97,		-- Azuremyst Isle (and Bloodmyst)
	100,	-- Hellfire Peninsula (All of Outland)
	118,	-- Icecrown (All of Northrend)
	422,	-- Dread Wastes (All of Pandaria)
	525,	-- Frostfire Ridge (All of Draenor)
	630,	-- Azsuna (All of Broken Isles)
	-- Argus only returns specific Flight Points per map
	885,	-- Antoran Wastes
	830,	-- Krokuun
	882,	-- Eredath
	831,	-- Upper Deck [The Vindicaar: Krokuun]
	883,	-- Upper Deck [The Vindicaar: Eredath]
	886,	-- Upper Deck [The Vindicaar: Antoran Wastes]

	862,	-- Zuldazar
	896,	-- Drustvar
	1355,	-- Nazjatar
	1550,	-- The Shadowlands
	1409,	-- Exile's Reach
};
local C_TaxiMap_GetTaxiNodesForMap = C_TaxiMap.GetTaxiNodesForMap;
local C_TaxiMap_GetAllTaxiNodes = C_TaxiMap.GetAllTaxiNodes;
app.CacheFlightPathData = function()
	if not app.CacheFlightPathData_Ran then
		-- app.DEBUG_PRINT = true;
		local newNodes, node = {};
		for i,mapID in ipairs(arrOfNodes) do
			-- if mapID == 882 then app.DEBUG_PRINT = true; end
			local allNodeData = C_TaxiMap_GetTaxiNodesForMap(mapID);
			if allNodeData then
				for j,nodeData in ipairs(allNodeData) do
					-- if nodeData.nodeID == 63 then app.DEBUG_PRINT = true; end
					-- if app.DEBUG_PRINT then app.PrintTable(nodeData) end
					node = app.FlightPathDB[nodeData.nodeID];
					if node then
						-- if app.DEBUG_PRINT then print("DB node") end
						-- associate in-game or our own cached data with the Sourced FP
						-- can only apply in-game data when it exists...
						if nodeData.name then node.name = nodeData.name; end
						if nodeData.faction then
							node.faction = nodeData.faction;
						elseif nodeData.atlasName then
							if nodeData.atlasName == "TaxiNode_Alliance" then
								node.faction = 2;
							elseif nodeData.atlasName == "TaxiNode_Horde" then
								node.faction = 1;
							end
						end
						-- if app.DEBUG_PRINT then app.PrintTable(node) end
					elseif nodeData.name and true then	-- Turn this off when you're done harvesting.
						-- if app.DEBUG_PRINT then print("*NEW* Node") end
						node = {};
						node.name = "*NEW* " .. nodeData.name;
						if nodeData.faction then
							node.faction = nodeData.faction;
						elseif nodeData.atlasName then
							if nodeData.atlasName == "TaxiNode_Alliance" then
								node.faction = 2;
							elseif nodeData.atlasName == "TaxiNode_Horde" then
								node.faction = 1;
							end
						end
						-- app.PrintTable(node)
						app.FlightPathDB[nodeData.nodeID] = node;
						newNodes[nodeData.nodeID] = node;
					end
					-- app.DEBUG_PRINT = nil;
				end
			end
			-- app.DEBUG_PRINT = nil;
		end
		app.CacheFlightPathData_Ran = true;
		SetDataMember("NewFlightPathData", newNodes);
		-- return if some new flight path was found
		-- print("CacheFlightPathData Found new nodes?",foundNew)
		-- app.PrintTable(newNodes);
		-- app.DEBUG_PRINT = nil;
		return true;
	end
end
local fields = {
	["key"] = function(t)
		return "flightPathID";
	end,
	["info"] = function(t)
		local info = app.FlightPathDB[t.flightPathID];
		if info then
			rawset(t, "info", info);
			if info.mapID then app.CacheField(t, "mapID", info.mapID); end
			if info.qg then app.CacheField(t, "creatureID", info.qg); end
			return info;
		end
		return app.EmptyTable;
	end,
	["name"] = function(t)
		return t.info.name or L["VISIT_FLIGHT_MASTER"];
	end,
	["icon"] = function(t)
		local r = t.r;
		if r then
			if r == Enum.FlightPathFaction.Horde then
				return app.asset("fp_horde");
			else
				return app.asset("fp_alliance");
			end
		end
		return app.asset("fp_neutral");
	end,
	["altQuests"] = function(t)
		return t.info.altQuests;
	end,
	["description"] = function(t)
		local description = t.info.description;
		return (description and (description .."\n\n") or "") .. L["FLIGHT_PATHS_DESC"];
	end,
	["collectible"] = function(t)
		return app.CollectibleFlightPaths;
	end,
	["collected"] = function(t)
		if app.CurrentCharacter.FlightPaths[t.flightPathID] then return 1; end
		if app.AccountWideFlightPaths and ATTAccountWideData.FlightPaths[t.flightPathID] then return 2; end
		if app.MODE_DEBUG_OR_ACCOUNT then return false; end
		if t.altQuests then
			for i,questID in ipairs(t.altQuests) do
				if IsQuestFlaggedCompleted(questID) then
					return 2;
				end
			end
		end
	end,
	["trackable"] = app.ReturnTrue,
	["saved"] = function(t)
		return app.CurrentCharacter.FlightPaths[t.flightPathID];
	end,
	["coord"] = function(t)
		return t.info.coord;
	end,
	["c"] = function(t)
		return t.info.c;
	end,
	["r"] = function(t)
		local faction = t.info.faction;
		if faction and faction > 0 then
			return faction;
		end
	end,
	["u"] = function(t)
		return t.info.u;
	end,
	["crs"] = function(t)
		return t.info.qg and { t.info.qg };
	end,
	["mapID"] = function(t)
		return t.info.mapID;
	end,
	["nmc"] = function(t)
		local c = t.c;
		if c and not containsValue(c, app.ClassIndex) then
			rawset(t, "nmc", true); -- "Not My Class"
			return true;
		end
		rawset(t, "nmc", false); -- "My Class"
		return false;
	end,
	["nmr"] = function(t)
		local r = t.r;
		return r and r ~= app.FactionID;
	end,
	["sourceQuests"] = function(t)
		return t.info.sourceQuests;
	end,
};
app.BaseFlightPath = app.BaseObjectFields(fields, "BaseFlightPath");
app.CreateFlightPath = function(id, t)
	return setmetatable(constructor(id, t, "flightPathID"), app.BaseFlightPath);
end
app.events.TAXIMAP_OPENED = function()
	local allNodeData = C_TaxiMap_GetAllTaxiNodes(app.GetCurrentMapID());
	if allNodeData then
		local newFPs, nodeID;
		local currentCharFPs, acctFPs = app.CurrentCharacter.FlightPaths, ATTAccountWideData.FlightPaths;
		for j,nodeData in ipairs(allNodeData) do
			if nodeData.state and nodeData.state < 2 then
				nodeID = nodeData.nodeID;
				if not currentCharFPs[nodeID] then
					acctFPs[nodeID] = 1;
					currentCharFPs[nodeID] = 1;
					if not newFPs then newFPs = { nodeID }
					else tinsert(newFPs, nodeID); end
				end
			end
		end
		UpdateRawIDs("flightPathID", newFPs);
	end
end
end)();

-- Follower Lib
(function()
local C_Garrison_GetFollowerInfo,C_Garrison_GetFollowerLinkByID,C_Garrison_IsFollowerCollected =
	  C_Garrison.GetFollowerInfo,C_Garrison.GetFollowerLinkByID,C_Garrison.IsFollowerCollected;
local cache = app.CreateCache("followerID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	local info = C_Garrison_GetFollowerInfo(id);
	if info then
		_t.name = info.name;
		_t.text = info.name;
		_t.lvl = info.level;
		_t.icon = info.portraitIconID;
		_t.title = info.className;
		_t.displayID = info.displayIDs and info.displayIDs[1] and info.displayIDs[1].id;
	end
	_t.link = C_Garrison_GetFollowerLinkByID(id);
	if field then return _t[field]; end
end
local fields = {
	["key"] = function(t)
		return "followerID";
	end,
	["text"] = function(t)
		return cache.GetCachedField(t, "text", CacheInfo);
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo);
	end,
	["lvl"] = function(t)
		return cache.GetCachedField(t, "lvl", CacheInfo);
	end,
	["title"] = function(t)
		return cache.GetCachedField(t, "title", CacheInfo);
	end,
	["displayID"] = function(t)
		-- return cache.GetCachedField(t, "displayID", CacheInfo);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", CacheInfo);
	end,
	["description"] = function(t)
		return L["FOLLOWERS_COLLECTION_DESC"];
	end,
	["collectible"] = function(t)
		return app.CollectibleFollowers;
	end,
	["trackable"] = app.ReturnTrue,
	["collected"] = function(t)
		if t.saved then return 1; end
		if app.AccountWideFollowers and ATTAccountWideData.Followers[t.followerID] then return 2; end
	end,
	["saved"] = function(t)
		local followerID = t.followerID;
		if app.CurrentCharacter.Followers[followerID] then return true; end
		if C_Garrison_IsFollowerCollected(followerID) then
			app.CurrentCharacter.Followers[followerID] = 1;
			ATTAccountWideData.Followers[followerID] = 1;
			return true;
		end
	end,
};
app.BaseFollower = app.BaseObjectFields(fields, "BaseFollower");
app.CreateFollower = function(id, t)
	return setmetatable(constructor(id, t, "followerID"), app.BaseFollower);
end
end)();

-- Garrison Lib
(function()
local C_Garrison_GetBuildingInfo = C_Garrison.GetBuildingInfo;
local C_Garrison_GetMissionName = C_Garrison.GetMissionName;
local C_Garrison_GetTalentInfo = C_Garrison.GetTalentInfo;

local cache = app.CreateCache("buildingID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	local _, name, _, icon, lore, _, _, _, _, _, uncollected = C_Garrison_GetBuildingInfo(id);
	_t.name = name;
	_t.text = name;
	_t.lore = lore;
	_t.icon = _t.icon or icon;
	if not uncollected then
		app.CurrentCharacter.Buildings[t.buildingID] = 1;
		ATTAccountWideData.Buildings[t.buildingID] = 1;
	end
	-- item on a building can replace fields
	if t.itemID then
		local _, link, _, _, _, _, _, _, _, icon = GetItemInfo(t.itemID);
		if link then
			_t.icon = icon or _t.icon;
			_t.link = link;
		end
	end
	if field then return _t[field]; end
end

local fields = {
	["key"] = function(t)
		return "buildingID";
	end,
	["text"] = function(t)
		return t.link or cache.GetCachedField(t, "text", CacheInfo);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", CacheInfo);
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["lore"] = function(t)
		return cache.GetCachedField(t, "lore", CacheInfo);
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo);
	end,
	["filterID"] = function(t)
		return t.itemID and 200;
	end,
	["collectible"] = function(t)
		return t.itemID and app.CollectibleRecipes;
	end,
	["collected"] = function(t)
		local id = t.buildingID;
		if app.CurrentCharacter.Buildings[id] then return 1; end
		if not select(11, C_Garrison_GetBuildingInfo(id)) then
			app.CurrentCharacter.Buildings[id] = 1;
			ATTAccountWideData.Buildings[id] = 1;
			return 1;
		end
		if app.AccountWideRecipes and ATTAccountWideData.Buildings[id] then return 2; end
	end,
};
app.BaseGarrisonBuilding = app.BaseObjectFields(fields, "BaseGarrisonBuilding");
app.CreateGarrisonBuilding = function(id, t)
	return setmetatable(constructor(id, t, "buildingID"), app.BaseGarrisonBuilding);
end

local fields = {
	["key"] = function(t)
		return "missionID";
	end,
	["text"] = function(t)
		return C_Garrison_GetMissionName(t.missionID);
	end,
	["icon"] = function(t)
		return "Interface/ICONS/INV_Icon_Mission_Complete_Order";
	end,
};
app.BaseGarrisonMission = app.BaseObjectFields(fields, "BaseGarrisonMission");
app.CreateGarrisonMission = function(id, t)
	return setmetatable(constructor(id, t, "missionID"), app.BaseGarrisonMission);
end

local fields = {
	["key"] = function(t)
		return "talentID";
	end,
	["info"] = function(t)
		-- TODO: use cache
		return C_Garrison_GetTalentInfo(t.talentID) or {};
	end,
	["text"] = function(t)
		return t.info.name;
	end,
	["icon"] = function(t)
		return t.info.icon or "Interface/ICONS/INV_Icon_Mission_Complete_Order";
	end,
	["description"] = function(t)
		return t.info.description;
	end,
	["trackable"] = app.ReturnTrue,
	["saved"] = function(t)
		return IsQuestFlaggedCompleted(t.questID) or t.info.researched;
	end,
};
app.BaseGarrisonTalent = app.BaseObjectFields(fields, "BaseGarrisonTalent");
app.CreateGarrisonTalent = function(id, t)
	return setmetatable(constructor(id, t, "talentID"), app.BaseGarrisonTalent);
end
end)();

-- Gear Set Lib
(function()
local C_TransmogSets_GetSetInfo = C_TransmogSets.GetSetInfo;
--[[ 9.1 TEST
C_TransmogSets.GetSetSources = function(setID)
	local setAppearances = C_TransmogSets.GetSetPrimaryAppearances(setID);
	if not setAppearances then
		return nil;
	end
	local lookupTable = { };
	for i, appearanceInfo in ipairs(setAppearances) do
		lookupTable[appearanceInfo.appearanceID] = appearanceInfo.collected;
	end
	return lookupTable;
end
--]]
local C_TransmogSets_GetSetSources = C_TransmogSets.GetSetSources;
local fields = {
	["key"] = function(t)
		return "setID";
	end,
	["info"] = function(t)
		return C_TransmogSets_GetSetInfo(t.setID) or {};
	end,
	["text"] = function(t)
		return t.info.name;
	end,
	["icon"] = function(t)
		local sources = t.sources;
		if sources then
			for sourceID, value in pairs(sources) do
				local sourceInfo = C_TransmogCollection_GetSourceInfo(sourceID);
				if sourceInfo and sourceInfo.invType == 2 then
					local icon = select(5, GetItemInfoInstant(sourceInfo.itemID));
					if icon then rawset(t, "icon", icon); end
					return icon;
				end
			end
		end
		return QUESTION_MARK_ICON;
	end,
	["description"] = function(t)
		local info = t.info;
		if info.description then
			if info.label then return info.label .. " (" .. info.description .. ")"; end
			return info.description;
		end
		return info.label;
	end,
	["header"] = function(t)
		return t.info.label;
	end,
	["subheader"] = function(t)
		return t.info.description;
	end,
	["title"] = function(t)
		return t.info.requiredFaction;
	end,
	["sources"] = function(t)
		local sources = C_TransmogSets_GetSetSources(t.setID);
		if sources then
			rawset(t, "sources", sources);
			return sources;
		end
	end,
};
app.BaseGearSet = app.BaseObjectFields(fields, "BaseGearSet");
app.CreateGearSet = function(id, t)
	return setmetatable(constructor(id, t, "setID"), app.BaseGearSet);
end

local fields = {
	["key"] = function(t)
		return "s";
	end,
	["info"] = function(t)
		return C_TransmogCollection_GetSourceInfo(rawget(t, "s")) or {};
	end,
	["itemID"] = function(t)
		local itemID = t.info.itemID;
		if itemID then
			rawset(t, "itemID", itemID);
			return itemID;
		end
	end,
	["text"] = function(t)
		return t.link;
	end,
	["link"] = function(t)
		return t.itemID and select(2, GetItemInfo(t.itemID));
	end,
	["name"] = function(t)
		return t.itemID and GetItemInfo(t.itemID);
	end,
	["icon"] = function(t)
		return t.itemID and select(5, GetItemInfoInstant(t.itemID));
	end,
	["collectible"] = function(t)
		return rawget(t, "s") and app.CollectibleTransmog;
	end,
	["collected"] = function(t)
		return ATTAccountWideData.Sources[rawget(t, "s")];
	end,
	["modItemID"] = function(t)
		rawset(t, "modItemID", GetGroupItemIDWithModID(t) or t.itemID);
		return rawget(t, "modItemID");
	end,
	["specs"] = function(t)
		return t.itemID and GetFixedItemSpecInfo(t.itemID);
	end,
	["invType"] = function(t)
		return t.info.invType or 99;
	end,
};
app.BaseGearSource = app.BaseObjectFields(fields, "BaseGearSource");
app.CreateGearSource = function(id)
	return setmetatable({ s = id}, app.BaseGearSource);
end

local fields = {
	["key"] = function(t)
		return "setID";
	end,
	["info"] = function(t)
		return C_TransmogSets_GetSetInfo(t.setID) or {};
	end,
	["text"] = function(t)
		return t.info.label;
	end,
	["icon"] = function(t)
		return t.achievementID and select(10, GetAchievementInfo(t.achievementID));
	end,
	["link"] = function(t)
		return t.achievementID and GetAchievementLink(t.achievementID);
	end,
	["achievementID"] = function(t)
		local achievementID = t.altAchID and app.FactionID == Enum.FlightPathFaction.Horde and t.altAchID or t.achID;
		if achievementID then
			rawset(t, "achievementID", achievementID);
			return achievementID;
		end
	end,
};
app.BaseGearSetHeader = app.BaseObjectFields(fields, "BaseGearSetHeader");
app.CreateGearSetHeader = function(id, t)
	return setmetatable(constructor(id, t, "setID"), app.BaseGearSetHeader);
end

local fields = {
	["key"] = function(t)
		return "setID";
	end,
	["info"] = function(t)
		return C_TransmogSets_GetSetInfo(t.setID) or {};
	end,
	["text"] = function(t)
		return t.info.description;
	end,
	["icon"] = function(t)
		return t.achievementID and select(10, GetAchievementInfo(t.achievementID));
	end,
	["link"] = function(t)
		return t.achievementID and GetAchievementLink(t.achievementID);
	end,
	["achievementID"] = function(t)
		local achievementID = t.altAchID and app.FactionID == Enum.FlightPathFaction.Horde and t.altAchID or t.achID;
		if achievementID then
			rawset(t, "achievementID", achievementID);
			return achievementID;
		end
	end,
};
app.BaseGearSetSubHeader = app.BaseObjectFields(fields, "BaseGearSetSubHeader");
app.CreateGearSetSubHeader = function(id, t)
	return setmetatable(constructor(id, t, "setID"), app.BaseGearSetSubHeader);
end
end)();

-- Holiday Lib
(function()
local function GetHolidayCache()
	local cache = GetTempDataMember("HOLIDAY_CACHE");
	if not cache then
		cache = {};
		SetTempDataMember("HOLIDAY_CACHE", cache);
		SetDataMember("HOLIDAY_CACHE", cache);
		local date = C_DateAndTime.GetCurrentCalendarTime();
		if date.month > 8 then
			C_Calendar.SetAbsMonth(date.month - 8, date.year);
		else
			C_Calendar.SetAbsMonth(date.month + 4, date.year - 1);
		end
		--local date = C_Calendar.GetDate();
		for month=1,12,1 do
			-- We kick off the search from January 1 at the start of the year using SetAbsMonth/GetMonthInfo. All successive functions are built from the returns of these.
			local absMonth = C_Calendar.SetAbsMonth(month, date.year);
			local monthInfo = C_Calendar.GetMonthInfo(absMonth);
			for day=1,monthInfo.numDays,1 do
				local numEvents = C_Calendar.GetNumDayEvents(0, day);
				if numEvents > 0 then
					for index=1,numEvents,1 do
						local event = C_Calendar.GetDayEvent(0, day, index);
						if event then -- If this is nil, then attempting to index it on the same line will toss an error.
							if event.calendarType == "HOLIDAY" and (not event.sequenceType or event.sequenceType == "" or event.sequenceType == "START") then
								if event.iconTexture then
									local t = cache[event.iconTexture];
									if not t then
										t = {
											["name"] = event.title,
											["icon"] = event.iconTexture,
											["times"] = {},
										};
										cache[event.iconTexture] = t;
									elseif event.iconTexture == 235465 then
										-- Harvest Festival and Pilgrims Bounty use the same icon...
										t = {
											["name"] = event.title,
											["icon"] = event.iconTexture,
											["times"] = {},
										};
										cache[235466] = t;
									end
									tinsert(t.times,
									{
										["start"] = time({
											year=event.startTime.year,
											month=event.startTime.month,
											day=event.startTime.monthDay,
											hour=event.startTime.hour,
											minute=event.startTime.minute,
										}),
										["end"] = time({
											year=event.endTime.year,
											month=event.endTime.month,
											day=event.endTime.monthDay,
											hour=event.endTime.hour,
											minute=event.endTime.minute,
										}),
										["startTime"] = event.startTime,
										["endTime"] = event.endTime,
									});
								end
							end
						end
					end
				end
			end
		end
	end
	return cache;
end
local texcoord = { 0.0, 0.7109375, 0.0, 0.7109375 };
local fields = {
	["key"] = function(t)
		return "holidayID";
	end,
	["info"] = function(t)
		local info = GetHolidayCache()[t.holidayID];
		if info then
			rawset(t, "info", info);
			return info;
		end
		return {};
	end,
	["name"] = function(t)
		return t.info.name;
	end,
	["text"] = function(t)
		return t.info.name;
	end,
	["icon"] = function(t)
		-- Use the custom icon if defined
		if L["HOLIDAY_ID_ICONS"][t.holidayID] then
			rawset(t, "icon", L["HOLIDAY_ID_ICONS"][t.holidayID]);
			return rawget(t, "icon");
		end
		return t.holidayID == 235466 and 235465 or t.holidayID;
	end,
	["texcoord"] = function(t)
		return not rawget(t, "icon") and texcoord;
	end,
};
app.BaseHoliday = app.BaseObjectFields(fields, "BaseHoliday");
app.CreateHoliday = function(id, t)
	return setmetatable(constructor(id, t, "holidayID"), app.BaseHoliday);
end
end)();

-- Illusion Lib
-- TODO: add caching for consistency/move to sub-item lib?
(function()
local fields = {
	["key"] = function(t)
		return "illusionID";
	end,
	["filterID"] = function(t)
		return 103;
	end,
	["text"] = function(t)
		if t.itemID then
			local name, link = GetItemInfo(t.itemID);
			if link then
				rawset(t, "name", name);
				name = "|cffff80ff[" .. name .. "]|r";
				rawset(t, "link", link);
				rawset(t, "text", name);
				return name;
			end
		end
		return t.silentLink;
	end,
	["name"] = function(t)
		return t.text;
	end,
	["icon"] = function(t)
		return "Interface/ICONS/INV_Enchant_Disenchant";
	end,
	["link"] = function(t)
		if t.itemID then
			local name, link = GetItemInfo(t.itemID);
			if link then
				rawset(t, "name", name);
				name = "|cffff80ff[" .. name .. "]|r";
				rawset(t, "link", link);
				rawset(t, "text", name);
				return link;
			end
		end
	end,
	["collectible"] = function(t)
		return app.CollectibleIllusions;
	end,
	["collected"] = function(t)
		return ATTAccountWideData.Illusions[t.illusionID];
	end,
	["silentLink"] = function(t)
		--[[ 9.1 TEST
		local _, hyperlink = C_TransmogCollection.GetIllusionStrings(t.illusionID);
		return hyperlink;
		--]]
		return select(3, C_TransmogCollection_GetIllusionSourceInfo(t.illusionID));
	end,
};
app.BaseIllusion = app.BaseObjectFields(fields, "BaseIllusion");
app.CreateIllusion = function(id, t)
	return setmetatable(constructor(id, t, "illusionID"), app.BaseIllusion);
end
end)();

-- Instance Lib
(function()
local cache = app.CreateCache("instanceID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	local name, lore, _, _, _, icon, _, link = EJ_GetInstanceInfo(id);
	_t.name = name;
	_t.lore = lore;
	_t.icon = icon;
	_t.link = link;
	if field then return _t[field]; end
end
local fields = {
	["key"] = function(t)
		return "instanceID";
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo);
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["lore"] = function(t)
		return cache.GetCachedField(t, "lore", CacheInfo);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", CacheInfo);
	end,
	["back"] = function(t)
		if app.CurrentMapID == t.mapID or (t.maps and contains(t.maps, app.CurrentMapID)) then
			return 1;
		end
	end,
	["trackable"] = app.ReturnTrue,
	["saved"] = function(t)
		return t.locks;
	end,
	["locks"] = function(t)
		local locks = app.CurrentCharacter.Lockouts[t.name];
		if locks then
			rawset(t, "locks", locks);
			return locks;
		end
	end,
	["isLockoutShared"] = app.ReturnFalse,
};
app.BaseInstance = app.BaseObjectFields(fields, "BaseInstance");
app.CreateInstance = function(id, t)
	return setmetatable(constructor(id, t, "instanceID"), app.BaseInstance);
end
end)();

-- Item Lib
(function()
-- TODO: Once Item information is stored in a single source table, this mechanism can reference that instead of using a cache table here
local cache = app.CreateCache("modItemID");
-- Consolidated function to handle how many retries for information an Item may have
local function HandleItemRetries(t)
	local _t, id = cache.GetCached(t);
	local retries = rawget(_t, "retries");
	if retries then
		if retries > app.MaximumItemInfoRetries then
			local itemName = "Item #" .. tostring(id) .. "*";
			rawset(_t, "title", L["FAILED_ITEM_INFO"]);
			rawset(_t, "link", nil);
			rawset(_t, "s", nil);
			-- print("itemRetriesMax",itemName,rawget(t, "retries"))
			-- save the "name" field in the source group to prevent further requests to the cache
			rawset(t, "name", itemName);
			return itemName;
		else
			rawset(_t, "retries", retries + 1);
		end
	else
		rawset(_t, "retries", 1);
	end
end
-- Consolidated function to cache available Item information
local function RawSetItemInfoFromLink(t, link)
	local name, link, quality, _, _, _, _, _, _, icon, _, _, _, b = GetItemInfo(link);
	if link then
		--[[ -- Debug Prints
		local _t, id = cache.GetCached(t);
		print("rawset item info",id,link,name,quality,b)
		--]]
		t = cache.GetCached(t);
		rawset(t, "retries", nil);
		rawset(t, "name", name);
		rawset(t, "link", link);
		rawset(t, "icon", icon);
		rawset(t, "q", quality);
		if quality > 6 then
			-- heirlooms return as 1 but are technically BoE for our concern
			rawset(t, "b", 2);
		else
			rawset(t, "b", b);
		end
		return link;
	else
		HandleItemRetries(t);
	end
end
local function default_link(t)
	-- item already has a pre-determined itemLink so use that
	if t.rawlink then return RawSetItemInfoFromLink(t, t.rawlink); end
	-- need to 'create' a valid accurate link for this item
	local itemLink = t.itemID;
	if itemLink then
		local bonusID = t.bonusID;
		local modID = t.modID;
		if not bonusID or bonusID < 1 then
			bonusID = nil;
		end
		if not modID or modID < 1 then
			modID = nil;
		end
		if bonusID and modID then
			itemLink = sformat("item:%d:::::::::::%d:1:%d:", itemLink, modID, bonusID);
		elseif bonusID then
			itemLink = sformat("item:%d::::::::::::1:%d:", itemLink, bonusID);
		elseif modID then
			-- bonusID 3524 seems to imply "use ModID to determine SourceID" since without it, everything with ModID resolves as the base SourceID from links
			itemLink = sformat("item:%d:::::::::::%d:1:3524:", itemLink, modID);
		else
			itemLink = sformat("item:%d:::::::::::::", itemLink);
		end
		-- save this link so it doesn't need to be built again
		rawset(t, "rawlink", itemLink);
		return RawSetItemInfoFromLink(t, itemLink);
	end
end
local function default_icon(t)
	return t.itemID and select(5, GetItemInfoInstant(t.itemID)) or "Interface\\Icons\\INV_Misc_QuestionMark";
end
local function default_specs(t)
	return GetFixedItemSpecInfo(t.itemID);
end
local function default_costCollectibles(t)
	local results, id;
	local modItemID = t.modItemID;
	-- Search by modItemID if possible for accuracy
	if modItemID and modItemID ~= t.itemID then
		id = modItemID;
		results = app.SearchForField("itemIDAsCost", id);
		-- if app.DEBUG_PRINT then print("itemIDAsCost.modItemID",id,results and #results) end
	end
	-- If no results, search by itemID + modID only if different
	if not results then
		id = GetGroupItemIDWithModID(nil, t.itemID, t.modID);
		if id ~= modItemID then
			results = app.SearchForField("itemIDAsCost", id);
			-- if app.DEBUG_PRINT then print("itemIDAsCost.modID",id,results and #results) end
		end
	end
	-- If no results, search by plain itemID only
	if not results and t.itemID then
		id = t.itemID;
		results = app.SearchForField("itemIDAsCost", id);
	end
	if results and #results > 0 then
		-- not sure we need to copy these into another table
		-- app.PrintDebug("default_costCollectibles",t.hash,id,#results)
		return results;
	end
	return app.EmptyTable;
end
local itemFields = {
	["key"] = function(t)
		return "itemID";
	end,
	["_cache"] = function(t)
		return cache;
	end,
	["text"] = function(t)
		return t.link or t.name;
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", default_icon);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", default_link);
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name");
	end,
	["specs"] = function(t)
		return cache.GetCachedField(t, "specs", default_specs);
	end,
	["retries"] = function(t)
		return cache.GetCachedField(t, "retries");
	end,
	["q"] = function(t)
		return cache.GetCachedField(t, "q");
	end,
	["b"] = function(t)
		return cache.GetCachedField(t, "b") or 2;
	end,
	["title"] = function(t)
		return cache.GetCachedField(t, "title");
	end,
	["f"] = function(t)
		-- Unknown item type after Parser, so make sure we save the filter for later references
		rawset(t, "f", -1);
		return rawget(t, "f");
	end,
	["tsm"] = function(t)
		local itemLink = t.itemID;
		if itemLink then
			local bonusID = t.bonusID;
			if bonusID and bonusID > 0 then
				return sformat("i:%d:0:1:%d", itemLink, bonusID);
			--elseif t.modID then
				-- NOTE: At this time, TSM3 does not support modID. (RIP)
				--return sformat("i:%d:%d:1:3524", itemLink, t.modID);
			end
			return sformat("i:%d", itemLink);
		end
	end,
	["repeatable"] = function(t)
		return rawget(t, "isDaily") or rawget(t, "isWeekly") or rawget(t, "isMonthly") or rawget(t, "isYearly") or rawget(t, "isWorldQuest");
	end,
	["modItemID"] = function(t)
		rawset(t, "modItemID", GetGroupItemIDWithModID(t) or t.itemID);
		return rawget(t, "modItemID");
	end,
	["indicatorIcon"] = app.GetQuestIndicator,
	["trackableAsQuest"] = function(t)
		-- raw repeatable quests can't really be tracked since they immediately unflag
		return not rawget(t, "repeatable");
	end,
	["collectibleAsAchievement"] = function(t)
		return app.CollectibleAchievements;
	end,
	["costCollectibles"] = function(t)
		return cache.GetCachedField(t, "costCollectibles", default_costCollectibles);
	end,
	["collectibleAsCost"] = app.CollectibleAsCost,
	["costsCount"] = function(t)
		if t.costCollectibles then return #t.costCollectibles; end
	end,
	["collectibleAsFaction"] = function(t)
		return app.CollectibleReputations;
	end,
	["collectibleAsFactionOrQuest"] = function(t)
		return app.CollectibleReputations or t.collectibleAsQuest;
	end,
	["collectibleAsTransmog"] = function(t)
		return app.CollectibleTransmog;
	end,
	["collectibleAsQuest"] = app.CollectibleAsQuest,
	["collectedAsQuest"] = IsQuestFlaggedCompletedForObject,
	["lockedAsQuest"] = app.LockedAsQuest,
	["collectedAsFaction"] = function(t)
		if t.factionID then
			if t.repeatable then
				-- This is used by reputation tokens. (turn in items)
				-- quick cache checks
				if app.CurrentCharacter.Factions[t.factionID] then return 1; end
				if app.AccountWideReputations and ATTAccountWideData.Factions[t.factionID] then return 2; end

				-- use the extended faction logic from the associated Faction for consistency
				local cachedFaction = app.SearchForObject("factionID", t.factionID);
				if cachedFaction then return cachedFaction.collected; end

				-- otherwise move on to the basic logic
				if select(3, GetFactionInfoByID(t.factionID)) == 8 then
					app.CurrentCharacter.Factions[t.factionID] = 1;
					ATTAccountWideData.Factions[t.factionID] = 1;
					return 1;
				end
			else
				-- This is used for the Grand Commendations unlocking Bonus Reputation
				if ATTAccountWideData.FactionBonus[t.factionID] then return 1; end
				if select(15, GetFactionInfoByID(t.factionID)) then
					ATTAccountWideData.FactionBonus[t.factionID] = 1;
					return 1;
				end
			end
		end
	end,
	["collectedAsFactionOrQuest"] = function(t)
		return t.collectedAsFaction or t.collectedAsQuest;
	end,
	["collectedAsTransmog"] = function(t)
		return ATTAccountWideData.Sources[rawget(t, "s")];
	end,
	["savedAsQuest"] = function(t)
		return IsQuestFlaggedCompleted(t.questID);
	end,
};
app.BaseItem = app.BaseObjectFields(itemFields, "BaseItem");

local fields = RawCloneData(itemFields);
fields.collectible = itemFields.collectibleAsAchievement;
fields.collected = itemFields.collectedAsAchievement;
app.BaseItemWithAchievementID = app.BaseObjectFields(fields, "BaseItemWithAchievementID");

local fields = RawCloneData(itemFields);
fields.collectible = itemFields.collectibleAsFaction;
fields.collected = itemFields.collectedAsFaction;
app.BaseItemWithFactionID = app.BaseObjectFields(fields, "BaseItemWithFactionID");

local fields = RawCloneData(itemFields);
fields.collectible = itemFields.collectibleAsQuest;
fields.collected = itemFields.collectedAsQuest;
fields.trackable = itemFields.trackableAsQuest;
fields.saved = itemFields.savedAsQuest;
fields.locked = itemFields.lockedAsQuest;
app.BaseItemWithQuestID = app.BaseObjectFields(fields, "BaseItemWithQuestID");

local fields = RawCloneData(itemFields);
fields.collectible = itemFields.collectibleAsFactionOrQuest;
fields.collected = itemFields.collectedAsFactionOrQuest;
fields.trackable = itemFields.trackableAsQuest;
fields.saved = itemFields.savedAsQuest;
fields.locked = itemFields.lockedAsQuest;
app.BaseItemWithQuestIDAndFactionID = app.BaseObjectFields(fields, "BaseItemWithQuestIDAndFactionID");

local fields = RawCloneData(itemFields);
fields.collectible = function(t)
	return app.CollectibleTransmog;
end
fields.collected = function(t)
	if t.itemID then
		if GetItemCount(t.itemID, true) > 0 then
			app.CurrentCharacter.CommonItems[t.itemID] = 1;
			ATTAccountWideData.CommonItems[t.itemID] = 1;
			return 1;
		elseif app.CurrentCharacter.CommonItems[t.itemID] == 1 then
			app.CurrentCharacter.CommonItems[t.itemID] = nil;
			ATTAccountWideData.CommonItems[t.itemID] = nil;
			for guid,characterData in pairs(ATTCharacterData) do
				if characterData.CommonItems and characterData.CommonItems[t.itemID] then
					ATTAccountWideData.CommonItems[t.itemID] = 1;
				end
			end
		end
		if ATTAccountWideData.CommonItems[t.itemID] then
			return 2;
		end
	end
end
app.BaseCommonItem = app.BaseObjectFields(fields, "BaseCommonItem");

-- Appearance Lib (Item Source)
local fields = RawCloneData(itemFields);
fields.key = function(t) return "s"; end;
-- TODO: if PL filter is ever a thing investigate https://wowpedia.fandom.com/wiki/API_C_TransmogCollection.PlayerCanCollectSource
fields.collectible = itemFields.collectibleAsTransmog;
fields.collected = itemFields.collectedAsTransmog;
app.BaseItemSource = app.BaseObjectFields(fields, "BaseItemSource");

app.CreateItemSource = function(sourceID, itemID, t)
	t = setmetatable(constructor(sourceID, t, "s"), app.BaseItemSource);
	t.itemID = itemID;
	return t;
end
app.CreateItem = function(id, t)
	if t then
		if rawget(t, "s") then
			return setmetatable(constructor(id, t, "itemID"), app.BaseItemSource);
		elseif rawget(t, "factionID") then
			if rawget(t, "questID") then
				return setmetatable(constructor(id, t, "itemID"), app.BaseItemWithQuestIDAndFactionID);
			else
				return setmetatable(constructor(id, t, "itemID"), app.BaseItemWithFactionID);
			end
		elseif rawget(t, "questID") then
			return setmetatable(constructor(id, t, "itemID"), app.BaseItemWithQuestID);
		elseif rawget(t, "achID") then
			rawset(t, "achievementID", app.FactionID == Enum.FlightPathFaction.Horde and rawget(t, "altAchID") or rawget(t, "achID"));
			return setmetatable(constructor(id, t, "itemID"), app.BaseItemWithAchievementID);
		end
	end
	return setmetatable(constructor(id, t, "itemID"), app.BaseItem);
end

-- Runeforge Legendary Lib
(function()
-- copy base Item fields
local fields = RawCloneData(itemFields);
-- Runeforge Legendary differences
local C_LegendaryCrafting_GetRuneforgePowerInfo = C_LegendaryCrafting.GetRuneforgePowerInfo;
fields.key = function(t) return "runeforgePowerID"; end;
fields.collectible = function(t) return app.CollectibleRuneforgeLegendaries; end;
fields.collectibleAsCost = app.ReturnFalse;
fields.collected = function(t)
	local rfID = t.runeforgePowerID;
	-- account-wide collected
	if ATTAccountWideData.RuneforgeLegendaries[rfID] then return 1; end
	-- fresh collected
	local state = (C_LegendaryCrafting_GetRuneforgePowerInfo(rfID) or app.EmptyTable).state;
	if state == 0 then
		ATTAccountWideData.RuneforgeLegendaries[rfID] = 1;
		return 1;
	end
end;
fields.lvl = function(t) return 60; end;
app.BaseRuneforgeLegendary = app.BaseObjectFields(fields, "BaseRuneforgeLegendary");
app.CreateRuneforgeLegendary = function(id, t)
	return setmetatable(constructor(id, t, "runeforgePowerID"), app.BaseRuneforgeLegendary);
end
end)();

-- Conduit Lib
(function()
local C_Soulbinds_GetConduitCollectionData = C_Soulbinds.GetConduitCollectionData;
-- copy base Item fields
local fields = RawCloneData(itemFields);
-- Conduit differences
fields.key = function(t) return "conduitID"; end;
fields.collectible = function(t) return app.CollectibleConduits; end;
fields.collectibleAsCost = app.ReturnFalse;
fields.collected = function(t)
	local cID = t.conduitID;
	-- character collected
	if app.CurrentCharacter.Conduits[cID] then return 1; end
	-- account-wide collected
	if app.AccountWideConduits and ATTAccountWideData.Conduits[cID] then return 2; end
	-- fresh collected
	local state = C_Soulbinds_GetConduitCollectionData(cID);
	if state ~= nil then
		app.CurrentCharacter.Conduits[cID] = 1;
		ATTAccountWideData.Conduits[cID] = 1;
		return 1;
	end
end;
fields.lvl = function(t) return 60; end;
app.BaseConduit = app.BaseObjectFields(fields, "BaseConduit");
app.CreateConduit = function(id, t)
	return setmetatable(constructor(id, t, "conduitID"), app.BaseConduit);
end
end)();

-- Heirloom Lib
(function()
local C_Heirloom_GetHeirloomInfo = C_Heirloom.GetHeirloomInfo;
local C_Heirloom_GetHeirloomLink = C_Heirloom.GetHeirloomLink;
local C_Heirloom_PlayerHasHeirloom = C_Heirloom.PlayerHasHeirloom;
local C_Heirloom_GetHeirloomMaxUpgradeLevel = C_Heirloom.GetHeirloomMaxUpgradeLevel;
local heirloomIDs = {};
local fields = {
	["key"] = function(t)
		return "heirloomUnlockID";
	end,
	["text"] = function(t)
		return L["HEIRLOOM_TEXT"];
	end,
	["icon"] = function(t)
		return "Interface/ICONS/Achievement_GuildPerk_WorkingOvertime_Rank2";
	end,
	["description"] = function(t)
		return L["HEIRLOOM_TEXT_DESC"];
	end,
	["collectible"] = function(t)
		return app.CollectibleHeirlooms;
	end,
	["saved"] = function(t)
		return C_Heirloom_PlayerHasHeirloom(t.heirloomUnlockID);
	end,
	["trackable"] = app.ReturnTrue,
};
fields.collected = fields.saved;
app.BaseHeirloomUnlocked = app.BaseObjectFields(fields, "BaseHeirloomUnlocked");

local armorTextures = {
	"Interface/ICONS/INV_Icon_HeirloomToken_Armor01",
	"Interface/ICONS/INV_Icon_HeirloomToken_Armor02",
	"Interface/ICONS/Inv_leather_draenordungeon_c_01shoulder",
	"Interface/ICONS/inv_mail_draenorquest90_b_01shoulder",
	"Interface/ICONS/inv_leather_warfrontsalliance_c_01_shoulder"
};
local weaponTextures = {
	"Interface/ICONS/INV_Icon_HeirloomToken_Weapon01",
	"Interface/ICONS/INV_Icon_HeirloomToken_Weapon02",
	"Interface/ICONS/inv_weapon_shortblade_112",
	"Interface/ICONS/inv_weapon_shortblade_111",
	"Interface/ICONS/inv_weapon_shortblade_102",
};
local isWeapon = { 20, 29, 28, 21, 22, 23, 24, 25, 26, 50, 57, 34, 35, 27, 33, 32, 31 };
local fields = {
	["key"] = function(t)
		return "heirloomLevelID";
	end,
	["level"] = function(t)
		return 1;
	end,
	["text"] = function(t)
		return "Upgrade Level " .. t.level;
	end,
	["icon"] = function(t)
		return t.isWeapon and weaponTextures[t.level] or armorTextures[t.level];
	end,
	["description"] = function(t)
		return L["HEIRLOOMS_UPGRADES_DESC"];
	end,
	["collectible"] = function(t)
		return app.CollectibleHeirlooms and app.CollectibleHeirloomUpgrades;
	end,
	["saved"] = function(t)
		local itemID = t.heirloomLevelID;
		if itemID then
			if t.level <= (ATTAccountWideData.HeirloomRanks[itemID] or 0) then return true; end
			local level = select(5, C_Heirloom_GetHeirloomInfo(itemID));
			if level then
				ATTAccountWideData.HeirloomRanks[itemID] = level;
				if t.level <= level then return true; end
			end
		end
	end,
	["trackable"] = app.ReturnTrue,
	["isWeapon"] = function(t)
		if t.f and contains(isWeapon, t.f) then
			rawset(t, "isWeapon", true);
			return true;
		end
		rawset(t, "isWeapon", false);
		return false;
	end,
};
fields.collected = fields.saved;
app.BaseHeirloomLevel = app.BaseObjectFields(fields, "BaseHeirloomLevel");

-- copy base Item fields
-- TODO: heirlooms need to cache item information as well
local fields = RawCloneData(itemFields);
fields.icon = function(t) return select(4, C_Heirloom_GetHeirloomInfo(t.itemID)) or select(5, GetItemInfoInstant(t.itemID)); end
fields.link = function(t) return C_Heirloom_GetHeirloomLink(t.itemID) or select(2, GetItemInfo(t.itemID)); end
fields.collectibleAsCost = app.ReturnFalse;
fields.collectible = function(t)
		-- Heirloom Token for a Reputation
		if t.factionID and app.CollectibleReputations then return true; end
		-- Heirloom Appearance
		if t.s and app.CollectibleTransmog then return true; end
		-- Otherwise the Heirloom Item itself is not inherently collectible
	end
fields.collected = function(t)
		if t.factionID then
			if t.repeatable then
				return (app.CurrentCharacter.Factions[t.factionID] and 1)
					or (ATTAccountWideData.Factions[t.factionID] and 2);
			else
				-- This is used for the Grand Commendations unlocking Bonus Reputation
				if ATTAccountWideData.FactionBonus[t.factionID] then return 1; end
				if select(15, GetFactionInfoByID(t.factionID)) then
					ATTAccountWideData.FactionBonus[t.factionID] = 1;
					return 1;
				end
			end
		end
		if t.s and ATTAccountWideData.Sources[t.s] then return 1; end
		if t.itemID and C_Heirloom_PlayerHasHeirloom(t.itemID) then return 1; end
	end
fields.saved = function(t)
		return t.collected == 1;
	end
fields.isWeapon = function(t)
		local f = t.f;
		if f and contains(isWeapon, f) then
			rawset(t, "isWeapon", true);
			return true;
		end
		rawset(t, "isWeapon", false);
		return false;
	end
fields.g = function(t)
		-- unlocking the heirloom is the only thing contained in the heirloom
		if C_Heirloom_GetHeirloomMaxUpgradeLevel(t.itemID) then
			rawset(t, "g", { setmetatable({ ["heirloomUnlockID"] = t.itemID, ["u"] = t.u }, app.BaseHeirloomUnlocked) });
			return rawget(t, "g");
		end
	end

app.BaseHeirloom = app.BaseObjectFields(fields, "BaseHeirloom");
app.CreateHeirloom = function(id, t)
	tinsert(heirloomIDs, id);
	if t then
		-- Heirlooms are always BoA
		t.b = 2;
	end
	return setmetatable(constructor(id, t, "itemID"), app.BaseHeirloom);
end

-- Will retrieve all the cached entries by itemID for existing heirlooms and generate their
-- upgrade levels into the respective upgrade tokens
app.CacheHeirlooms = function()
	-- app.PrintDebug("CacheHeirlooms",#heirloomIDs)
	if #heirloomIDs < 1 then return; end

	-- setup the armor tokens which will contain the upgrades for the heirlooms
	local armorTokens = {
		app.CreateItem(187997),	-- Eternal Heirloom Armor Casing
		app.CreateItem(167731),	-- Battle-Hardened Heirloom Armor Casing
		app.CreateItem(151614),	-- Weathered Heirloom Armor Casing
		app.CreateItem(122340),	-- Timeworn Heirloom Armor Casing
		app.CreateItem(122338),	-- Ancient Heirloom Armor Casing
	};
	local weaponTokens = {
		app.CreateItem(187998),	-- Eternal Heirloom Scabbard
		app.CreateItem(167732),	-- Battle-Hardened Heirloom Scabbard
		app.CreateItem(151615),	-- Weathered Heirloom Scabbard
		app.CreateItem(122341),	-- Timeworn Heirloom Scabbard
		app.CreateItem(122339),	-- Ancient Heirloom Scabbard
	};

	-- cache the heirloom upgrade tokens
	for i,item in ipairs(armorTokens) do
		item.g = {};
	end
	for i,item in ipairs(weaponTokens) do
		item.g = {};
	end
	-- for each cached heirloom, push a copy of itself with respective upgrade level under the respective upgrade token
	local heirloom, upgrades, isWeapon;
	local uniques = {};
	for _,itemID in ipairs(heirloomIDs) do
		if not uniques[itemID] then
			uniques[itemID] = true;

			heirloom = app.SearchForObject("itemID", itemID);
			if heirloom then
				upgrades = C_Heirloom_GetHeirloomMaxUpgradeLevel(itemID);
				if upgrades then
					isWeapon = heirloom.isWeapon;

					local heirloomHeader;
					for i=1,upgrades,1 do
						-- Create a non-collectible version of the heirloom item itself to hold the upgrade within the token
						heirloomHeader = CloneData(heirloom);
						heirloomHeader.collectible = false;
						-- put the upgrade object into the header heirloom object
						heirloomHeader.g = { setmetatable({ ["level"] = i, ["heirloomLevelID"] = itemID, ["u"] = heirloom.u }, app.BaseHeirloomLevel) };

						-- add the header into the appropriate upgrade token
						if isWeapon then
							tinsert(weaponTokens[upgrades + 1 - i].g, heirloomHeader);
						else
							tinsert(armorTokens[upgrades + 1 - i].g, heirloomHeader);
						end
					end
				end
			end
		end
	end

	-- build groups for each upgrade token
	-- and copy the set of upgrades into the cached versions of the upgrade tokens so they therefore exist in the main list
	-- where the sources of the upgrade tokens exist
	local cachedTokenGroups;
	for i,item in ipairs(armorTokens) do
		cachedTokenGroups = app.SearchForField("itemID", item.itemID);
		for _,token in ipairs(cachedTokenGroups) do
			-- ensure the tokens do not have a modID attached
			token.modID = nil;
			if not token.sym then
				for _,heirloom in ipairs(item.g) do
					NestObject(token, heirloom, true);
				end
				BuildGroups(token, token.g);
			end
		end
	end
	for i,item in ipairs(weaponTokens) do
		cachedTokenGroups = app.SearchForField("itemID", item.itemID);
		for _,token in ipairs(cachedTokenGroups) do
			-- ensure the tokens do not have a modID attached
			token.modID = nil;
			if not token.sym then
				for _,heirloom in ipairs(item.g) do
					NestObject(token, heirloom, true);
				end
				BuildGroups(token, token.g);
			end
		end
	end

	wipe(heirloomIDs);
end
end)();

-- Toy Lib
(function()
-- copy base Item fields
local fields = RawCloneData(itemFields);
fields.filterID = function(t)
		return 102;
	end
fields.collectible = function(t)
		return app.CollectibleToys;
	end
fields.collected = function(t)
		return ATTAccountWideData.Toys[t.itemID];
	end
fields.tsm = function(t)
		return sformat("i:%d", t.itemID);
	end
fields.isToy = app.ReturnTrue;
fields.toyID = function(t)
		return t.itemID;
	end

app.BaseToy = app.BaseObjectFields(fields, "BaseToy");
app.CreateToy = function(id, t)
	return setmetatable(constructor(id, t, "itemID"), app.BaseToy);
end
end)();

local HarvestedItemDatabase;
local C_Item_GetItemInventoryTypeByID = C_Item.GetItemInventoryTypeByID;
local itemHarvesterFields = RawCloneData(itemFields);
itemHarvesterFields.visible = app.ReturnTrue;
itemHarvesterFields.collectible = app.ReturnTrue;
itemHarvesterFields.collected = app.ReturnFalse;
itemHarvesterFields.text = function(t)
	-- delayed localization since ATT's globals don't exist when this logic is processed on load
	if not HarvestedItemDatabase then
		HarvestedItemDatabase = LocalizeGlobal("AllTheThingsHarvestItems", true);
	end
	local link = t.link;
	if link then
		local itemName, itemLink, itemQuality, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
		itemEquipLoc, itemTexture, sellPrice, classID, subclassID, bindType, expacID, setID, isCraftingReagent
			= GetItemInfo(link);
		if itemName then
			local spellName, spellID;
			-- Recipe or Mount, grab the spellID if possible
			if classID == LE_ITEM_CLASS_RECIPE or (classID == LE_ITEM_CLASS_MISCELLANEOUS and subclassID == LE_ITEM_MISCELLANEOUS_MOUNT) then
				spellName, spellID = GetItemSpell(t.itemID);
				-- print("Recipe/Mount",classID,subclassID,spellName,spellID);
				if spellName == "Learning" then spellID = nil; end	-- RIP.
			end
			setmetatable(t, app.BaseItemTooltipHarvester);
			local info = {
				["name"] = itemName,
				["itemID"] = t.itemID,
				["equippable"] = itemEquipLoc and itemEquipLoc ~= "" and true or false,
				["class"] = classID,
				["subclass"] = subclassID,
				["inventoryType"] = C_Item_GetItemInventoryTypeByID(t.itemID),
				["b"] = bindType,
				["q"] = itemQuality,
				["iLvl"] = itemLevel,
				["spellID"] = spellID,
			};
			if itemMinLevel and itemMinLevel > 0 then
				info.lvl = itemMinLevel;
			end
			if info.inventoryType == 0 then
				info.inventoryType = nil;
			end
			if not app.IsBoP(info) then
				info.b = nil;
			end
			if info.q and info.q < 1 then
				info.q = nil;
			end
			if info.iLvl and info.iLvl < 2 then
				info.iLvl = nil;
			end
			-- can debug output for tooltip harvesting
			-- if t.itemID == 141038 then
			-- 	info._debug = true;
			-- end
			t.itemType = itemType;
			t.itemSubType = itemSubType;
			t.info = info;
			t.retries = nil;
			HarvestedItemDatabase[t.itemID] = info;
			return link;
		end
	end

	local name = t.name;
	-- retries exceeded, so check the raw .name on the group (gets assigned when retries exceeded during cache attempt)
	if name then rawset(t, "collected", true); end
	return name;
end
app.BaseItemHarvester = app.BaseObjectFields(itemHarvesterFields, "BaseItemHarvester");

local ItemHarvester = CreateFrame("GameTooltip", "ATTItemHarvester", UIParent, "GameTooltipTemplate");
local itemTooltipHarvesterFields = RawCloneData(itemHarvesterFields);
itemTooltipHarvesterFields.text = function(t)
	local link = t.link;
	if link then
		ItemHarvester:SetOwner(UIParent,"ANCHOR_NONE")
		ItemHarvester:SetHyperlink(link);
		-- a way to capture when the tooltip is giving information about something that is NOT the current ItemID
		local isSubItem, craftName;
		local lineCount = ItemHarvester:NumLines();
		if ATTItemHarvesterTextLeft1:GetText() and ATTItemHarvesterTextLeft1:GetText() ~= RETRIEVING_DATA and lineCount > 0 then
			-- local debugPrint = t.info._debug;
			-- if debugPrint then print("Item Info:",t.info.itemID) end
			for index=1,lineCount,1 do
				local line = _G["ATTItemHarvesterTextLeft" .. index] or _G["ATTItemHarvesterText" .. index];
				if line then
					local text = line:GetText();
					if text then
						-- sub items within recipe tooltips show this text, need to wait until it loads
						if text == RETRIEVING_ITEM_INFO then
							t.info.retries = (t.info.retries or 0) + 1;
							-- 30 attempts to load the sub-item, otherwise just continue parsing tooltip without it
							if t.info.retries < 30 then
								return RETRIEVING_DATA;
							end
							app.PrintDebug("Failed loading sub-item for",t.info.itemID)
						end
						-- pull the "Recipe Type: Recipe Name" out if it matches
						if index == 1 then
							-- if debugPrint then
							-- 	print("line match",text:match("^[^:]+:%s*([^:]+)$"))
							-- end
							craftName = text:match("^[^:]+:%s*([^:]+)$");
							if craftName then
								-- whitespace search... recipes have whitespace and then a sub-item
								craftName = "^%s+";
							end
						-- use this name to check that the Item it creates may be listed underneath, by finding whitespace after a matching recipe name
						elseif craftName and text:match(craftName) then
							-- if debugPrint then
								-- print("subitem",t.info.itemID,craftName)
							-- end
							isSubItem = true;
						-- leave the sub-item info when reaching the 'Requires' portion of the parent item tooltip
						elseif isSubItem and text:match("^Requires") then
							-- if debugPrint then
							-- 	print("leaving subitem",t.info.itemID,craftName)
							-- end
							-- leaving the sub-item tooltip when encountering 'Requires '
							isSubItem = nil;
						end

						if not isSubItem then
							-- if debugPrint then print(text) end
							if string.find(text, "Classes: ") then
								local classes = {};
								local _,list = strsplit(":", text);
								for i,s in ipairs({strsplit(",", list)}) do
									tinsert(classes, app.ClassDB[strtrim(s)]);
								end
								if #classes > 0 then
									t.info.classes = classes;
								end
							elseif string.find(text, "Races: ") then
								local _,list = strsplit(":", text);
								local raceNames = {strsplit(",", list)};
								if raceNames then
									local races = {};
									for _,s in ipairs(raceNames) do
										local race = app.RaceDB[strtrim(s)];
										if not race then
											print("Unknown Race",t.info.itemID,strtrim(s))
										elseif type(race) == "number" then
											tinsert(races, race);
										else -- Pandaren
											for _,panda in pairs(race) do
												tinsert(races, panda);
											end
										end
									end
									if #races > 0 then
										t.info.races = races;
									end
								else
									print("Empty Races",t.info.itemID)
								end
							elseif string.find(text, " Only") then
								local faction,list,c = strsplit(" ", text);
								if not c then
									faction = strtrim(faction);
									if faction == "Alliance" then
										t.info.races = app.FACTION_RACES[1];
									elseif faction == "Horde" then
										t.info.races = app.FACTION_RACES[2];
									else
										print("Unknown Faction",t.info.itemID,faction);
									end
								end
							elseif string.find(text, "Requires") and not string.find(text, "Level") and not string.find(text, "Riding") then
								local c = strsub(text, 1, 1);
								if c ~= " " and c ~= "\t" and c ~= "\n" and c ~= "\r" then
									text = strsub(strtrim(text), 9);
									if string.find(text, "-") then
										local faction,replevel = strsplit("-", text);
										t.info.minReputation = { app.GetFactionIDByName(faction), app.GetFactionStandingThresholdFromString(replevel) };
									else
										if string.find(text, "%(") then
											if t.info.requireSkill then
												-- If non-specialization skill is already assigned, skip this part.
												text = nil;
											else
												text = strsplit("(", text);
											end
										end
										if text then
											local spellName = strtrim(text);
											if string.find(spellName, "Outland ") then spellName = strsub(spellName, 9);
											elseif string.find(spellName, "Northrend ") then spellName = strsub(spellName, 11);
											elseif string.find(spellName, "Cataclysm ") then spellName = strsub(spellName, 11);
											elseif string.find(spellName, "Pandaria ") then spellName = strsub(spellName, 10);
											elseif string.find(spellName, "Draenor ") then spellName = strsub(spellName, 9);
											elseif string.find(spellName, "Legion ") then spellName = strsub(spellName, 8);
											elseif string.find(spellName, "Kul Tiran ") then spellName = strsub(spellName, 11);
											elseif string.find(spellName, "Zandalari ") then spellName = strsub(spellName, 11);
											elseif string.find(spellName, "Shadowlands ") then spellName = strsub(spellName, 13);
											elseif string.find(spellName, "Classic ") then spellName = strsub(spellName, 9); end
											if spellName == "Herbalism" then spellName = "Herb Gathering"; end
											spellName = strtrim(spellName);
											local spellID = app.SpellNameToSpellID[spellName];
											if spellID then
												local skillID = app.SpellIDToSkillID[spellID];
												if skillID then
													t.info.requireSkill = skillID;
												elseif spellName == "Pick Pocket" then
													-- Do nothing, for now.
												elseif spellName == "Warforged Nightmare" then
													-- Do nothing, for now.
												else
													print("Unknown Skill",t.info.itemID, text, "'" .. spellName .. "'");
												end
											elseif spellName == "Previous Rank" then
												-- Do nothing
											elseif spellName == "" then
												-- Do nothing
											elseif spellName == "Brewfest" then
												-- Do nothing, yet.
											elseif spellName == "Call of the Scarab" then
												-- Do nothing, yet.
											elseif spellName == "Children's Week" then
												-- Do nothing, yet.
											elseif spellName == "Darkmoon Faire" then
												-- Do nothing, yet.
											elseif spellName == "Day of the Dead" then
												-- Do nothing, yet.
											elseif spellName == "Feast of Winter Veil" then
												-- Do nothing, yet.
											elseif spellName == "Hallow's End" then
												-- Do nothing, yet.
											elseif spellName == "Love is in the Air" then
												-- Do nothing, yet.
											elseif spellName == "Lunar Festival" then
												-- Do nothing, yet.
											elseif spellName == "Midsummer Fire Festival" then
												-- Do nothing, yet.
											elseif spellName == "Moonkin Festival" then
												-- Do nothing, yet.
											elseif spellName == "Noblegarden" then
												-- Do nothing, yet.
											elseif spellName == "Pilgrim's Bounty" then
												-- Do nothing, yet.
											elseif spellName == "Un'Goro Madness" then
												-- Do nothing, yet.
											elseif spellName == "Thousand Boat Bash" then
												-- Do nothing, yet.
											elseif spellName == "Glowcap Festival" then
												-- Do nothing, yet.
											elseif spellName == "Battle Pet Training" then
												-- Do nothing.
											elseif spellName == "Lockpicking" then
												-- Do nothing.
											elseif spellName == "Luminous Luminaries" then
												-- Do nothing.
											elseif spellName == "Pick Pocket" then
												-- Do nothing.
											elseif spellName == "WoW's 14th Anniversary" then
												-- Do nothing.
											elseif spellName == "WoW's 13th Anniversary" then
												-- Do nothing.
											elseif spellName == "WoW's 12th Anniversary" then
												-- Do nothing.
											elseif spellName == "WoW's 11th Anniversary" then
												-- Do nothing.
											elseif spellName == "WoW's 10th Anniversary" then
												-- Do nothing.
											elseif spellName == "WoW's Anniversary" then
												-- Do nothing.
											elseif spellName == "level 1 to 29" then
												-- Do nothing.
											elseif spellName == "level 1 to 39" then
												-- Do nothing.
											elseif spellName == "level 1 to 44" then
												-- Do nothing.
											elseif spellName == "level 1 to 49" then
												-- Do nothing.
											elseif spellName == "Unknown" then
												-- Do nothing.
											elseif spellName == "Open" then
												-- Do nothing.
											elseif string.find(spellName, " specialization") then
												-- Do nothing.
											elseif string.find(spellName, ": ") then
												-- Do nothing.
											else
												print("Unknown Spell",t.info.itemID, text, "'" .. spellName .. "'");
											end
										end
									end
								end
							end
						end
					end
				end
			end
			-- if debugPrint then print("---") end
			t.info.retries = nil;
			rawset(t, "text", link);
			rawset(t, "collected", true);
		end
		ItemHarvester:Hide();
		return link;
	end
end
app.BaseItemTooltipHarvester = app.BaseObjectFields(itemTooltipHarvesterFields, "BaseItemTooltipHarvester");
app.CreateItemHarvester = function(id, t)
	return setmetatable(constructor(id, t, "itemID"), app.BaseItemHarvester);
end

-- Imports the raw information from the rawlink into the specified group
app.ImportRawLink = function(group, rawlink)
	rawlink = rawlink and string.match(rawlink, "item[%-?%d:]+");
	if rawlink and group then
		group.rawlink = rawlink;
		local _, linkItemID, enchantId, gemId1, gemId2, gemId3, gemId4, suffixId, uniqueId, linkLevel, specializationID, upgradeId, modID, bonusCount, bonusID1 = strsplit(":", rawlink);
		if linkItemID then
			-- app.PrintDebug("ImportRawLink",rawlink,linkItemID,modID,bonusCount,bonusID1);
			-- set raw fields in the group based on the link
			group.itemID = tonumber(linkItemID);
			group.modID = modID and tonumber(modID) or nil;
			-- only set the bonusID if there is actually bonusIDs indicated
			if (tonumber(bonusCount) or 0) > 0 then
				-- Don't use bonusID 3524 as an actual bonusID
				local b = bonusID1 and tonumber(bonusID1) or nil;
				if b ~= 3524 then
					group.bonusID = b;
				end
			end
			group.modItemID = nil;
			-- does this link also have a sourceID?
			local s = GetSourceID(rawlink);
			-- print("s",s)
			if s then group.s = s; end
			-- if app.DEBUG_PRINT then app.PrintTable(group) end
		end
	end
end
-- Adds necessary SourceID information for Item data into the Harvest variable
app.SaveHarvestSource = function(data)
	local s, itemID = data.s, data.itemID;
	if s and itemID then
		local item = AllTheThingsHarvestItems[itemID];
		if not item then
			item = {};
			-- print("NEW SOURCE ID!",data.text,s,itemID);
			AllTheThingsHarvestItems[itemID] = item;
		end
		local bonusID = data.bonusID;
		if bonusID then
			local bonuses = item.bonuses;
			if not bonuses then
				bonuses = {};
				item.bonuses = bonuses;
			end
			bonuses[bonusID] = s;
		else
			local mods = item.mods;
			if not mods then
				mods = {};
				item.mods = mods;
			end
			mods[data.modID or 0] = s;
		end
	end
end
-- Refines a set of items down to the most-accurate matches to the provided modItemID
-- The sets of items will be returned based on their respective match depth to the given modItemID
-- Ex: { [1] = { { ItemID }, { ItemID2 } }, [2] = { { ModID } }, [3] = { { BonusID } } }
app.GroupBestMatchingItems = function(items, modItemID)
	if not items or #items == 0 then return; end
	-- print("refining",#items,"by depth to",modItemID)
	-- local i, m, b = GetItemIDAndModID(modItemID);
	local refinedBuckets, GetDepth, depth = {}, app.ItemMatchDepth;
	for _,item in ipairs(items) do
		depth = GetDepth(item, modItemID);
		if depth then
			-- print("added refined item",depth,item.modItemID,item.key,item.key and item[item.key])
			if refinedBuckets[depth] then tinsert(refinedBuckets[depth], item)
			else refinedBuckets[depth] = { item }; end
		end
	end
	return refinedBuckets;
end
-- Returns the depth at which a given Item matches the provided modItemID
-- 1 = ItemID, 2 = ModID, 3 = BonusID
app.ItemMatchDepth = function(item, modItemID)
	if not item or not item.itemID then return; end
	local i, m, b = GetItemIDAndModID(modItemID);
	local depth = 0;
	if item.itemID == i then
		depth = depth + 1;
		if item.modID == m then
			depth = depth + 1;
			if item.bonusID == b then
				depth = depth + 1;
			end
		end
	end
	return depth;
end
end)();

-- Map Lib
(function()
local C_Map_GetMapLevels = C_Map.GetMapLevels;
local C_Map_GetBestMapForUnit = C_Map.GetBestMapForUnit;
app.GetCurrentMapID = function()
	local uiMapID = C_Map_GetBestMapForUnit("player");
	if uiMapID then
		local map = C_Map_GetMapInfo(uiMapID);
		if map then
			local ZONE_TEXT_TO_MAP_ID = app.L["ZONE_TEXT_TO_MAP_ID"];
			local real = GetRealZoneText();
			local otherMapID = real and ZONE_TEXT_TO_MAP_ID[real];
			if otherMapID then
				uiMapID = otherMapID;
			else
				local zone = GetSubZoneText();
				if zone then
					otherMapID = ZONE_TEXT_TO_MAP_ID[zone];
					if otherMapID then uiMapID = otherMapID; end
				end
			end
		end
		-- print("Current UI Map ID: ", uiMapID);
		-- if entering an instance, clear the search Cache so that proper difficulty tooltips are re-generated
		if IsInInstance() then wipe(searchCache); end
		app.CurrentMapID = uiMapID;
	end
	return uiMapID;
end
app.GetMapName = function(mapID)
	if mapID and mapID > 0 then
		local info = C_Map_GetMapInfo(mapID);
		return (info and info.name) or ("Map ID #" .. mapID);
	else
		return "Map ID #???";
	end
end
local mapFields = {
	["key"] = function(t)
		return "mapID";
	end,
	["name"] = function(t)
		return t.creatureID and app.NPCNameFromID[t.creatureID] or app.GetMapName(t.mapID);
	end,
	["icon"] = function(t)
		return t.creatureID and L["HEADER_ICONS"][t.creatureID] or app.asset("Category_Zones");
	end,
	["back"] = function(t)
		if app.CurrentMapID == t.mapID or (t.maps and contains(t.maps, app.CurrentMapID)) then
			return 1;
		end
	end,
	["lvl"] = function(t)
		return C_Map_GetMapLevels(t.mapID);
	end,
	["iconForAchievement"] = function(t)
		return t.achievementID and select(10, GetAchievementInfo(t.achievementID)) or app.asset("Category_Zones");
	end,
	["linkForAchievement"] = function(t)
		return GetAchievementLink(t.achievementID);
	end,
};
app.BaseMap = app.BaseObjectFields(mapFields, "BaseMap");

local fields = RawCloneData(mapFields);
fields.icon = mapFields.iconForAchievement;
fields.link = mapFields.linkForAchievement;
app.BaseMapWithAchievementID = app.BaseObjectFields(fields, "BaseMapWithAchievementID");
app.CreateMap = function(id, t)
	t = constructor(id, t, "mapID");
	if rawget(t, "achID") then
		rawset(t, "achievementID", app.FactionID == Enum.FlightPathFaction.Horde and rawget(t, "altAchID") or rawget(t, "achID"));
		t = setmetatable(t, app.BaseMapWithAchievementID);
	else
		t = setmetatable(t, app.BaseMap);
	end
	return t;
end
app.CreateMapWithStyle = function(id)
	local mapObject = app.CreateMap(id, { progress = 0, total = 0 });
	for _,data in ipairs(fieldCache["mapID"][id] or {}) do
		if data.mapID and data.icon then
			mapObject.text = data.text;
            mapObject.icon = data.icon;
            mapObject.lvl = data.lvl;
            mapObject.lore = data.lore;
            mapObject.description = data.description;
			break;
		end
	end

	if not mapObject.text then
		local mapInfo = C_Map_GetMapInfo(id);
		if mapInfo then
			mapObject.text = mapInfo.name;
		end
	end
	return mapObject;
end

app.events.ZONE_CHANGED_INDOORS = function()
	app.GetCurrentMapID();
end
app.events.ZONE_CHANGED_NEW_AREA = function()
	app.GetCurrentMapID();
end
app:RegisterEvent("ZONE_CHANGED_INDOORS");
app:RegisterEvent("ZONE_CHANGED_NEW_AREA");
end)();

-- Mount Lib
(function()
local C_MountJournal_GetMountInfoExtraByID = C_MountJournal.GetMountInfoExtraByID;
local C_MountJournal_GetMountInfoByID = C_MountJournal.GetMountInfoByID;
local C_MountJournal_GetMountIDs = C_MountJournal.GetMountIDs;
local GetSpellInfo = GetSpellInfo;
local GetSpellLink = GetSpellLink;
local SpellIDToMountID = setmetatable({}, { __index = function(t, id)
	local allMountIDs = C_MountJournal_GetMountIDs();
	if allMountIDs and #allMountIDs > 0 then
		local spellID;
		for i,mountID in ipairs(allMountIDs) do
			spellID = select(2, C_MountJournal_GetMountInfoByID(mountID));
			if spellID then rawset(t, spellID, mountID); end
		end
		setmetatable(t, nil);
		return rawget(t, id);
	end
end });
local cache = app.CreateCache("spellID");
local function CacheInfo(t, field)
	local itemID = t.itemID;
	local _t, id = cache.GetCached(t);
	local mountID = SpellIDToMountID[id];
	if mountID then
		local displayID, lore = C_MountJournal_GetMountInfoExtraByID(mountID);
		_t.displayID = displayID;
		_t.lore = lore;
		_t.name = C_MountJournal_GetMountInfoByID(mountID);
		_t.mountID = mountID;
	end
	local name, _, icon = GetSpellInfo(id);
	if name then
		_t.text = "|cffb19cd9"..name.."|r";
		_t.icon = icon;
	end
	if itemID then
		local itemName = select(2, GetItemInfo(itemID));
		-- item info might not be available on first request, so don't cache the data
		if itemName then
			_t.link = itemName;
		end
	else
		_t.link = GetSpellLink(id);
	end
	if field then return _t[field]; end
end
local function default_costCollectibles(t)
	local id = t.itemID;
	if id then
		local results = app.SearchForField("itemIDAsCost", id);
		if results and #results > 0 then
			-- app.PrintDebug("default_costCollectibles",t.hash,id,#results)
			return results;
		end
	end
	return app.EmptyTable;
end
local mountFields = {
	["key"] = function(t)
		return "spellID";
	end,
	["_cache"] = function(t)
		return cache;
	end,
	["text"] = function(t)
		return cache.GetCachedField(t, "text", CacheInfo);
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", CacheInfo);
	end,
	["filterID"] = function(t)
		return 100;
	end,
	["collectible"] = function(t)
		return app.CollectibleMounts;
	end,
	["costCollectibles"] = function(t)
		return cache.GetCachedField(t, "costCollectibles", default_costCollectibles);
	end,
	["collectibleAsCost"] = app.CollectibleAsCost,
	["collected"] = function(t)
		if ATTAccountWideData.Spells[t.spellID] then return 1; end
		if app.IsSpellKnownHelper(t.spellID) or (t.questID and IsQuestFlaggedCompleted(t.questID)) then
			ATTAccountWideData.Spells[t.spellID] = 1;
			return 1;
		end
	end,
	["b"] = function(t)
		return (t.parent and t.parent.b) or 1;
	end,
	["mountID"] = function(t)
		return cache.GetCachedField(t, "mountID", CacheInfo);
	end,
	["lore"] = function(t)
		return cache.GetCachedField(t, "lore", CacheInfo);
	end,
	["displayID"] = function(t)
		return cache.GetCachedField(t, "displayID", CacheInfo);
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["tsm"] = function(t)
		if t.itemID then return sformat("i:%d", t.itemID); end
		if t.parent and t.parent.itemID then return sformat("i:%d", t.parent.itemID); end
	end,
};
app.BaseMount = app.BaseObjectFields(mountFields, "BaseMount");

local fields = RawCloneData(mountFields);
app.BaseMountWithItemID = app.BaseObjectFields(fields, "BaseMountWithItemID");
app.CreateMount = function(id, t)
	-- if t and rawget(t, "itemID") then
		-- return setmetatable(constructor(id, t, "spellID"), app.BaseMountWithItemID);
	-- else
		return setmetatable(constructor(id, t, "spellID"), app.BaseMount);
	-- end
end

-- Refresh a specific Mount or all Mounts if not provided with a specific ID
local RefreshMounts = function(newMountID)
	local collectedSpells, newMounts = ATTAccountWideData.Spells;
	-- Think learning multiple mounts at once or multiple mounts without leaving combat
	-- would fail to update all the mounts, so probably just best to check all mounts if this is triggered
	-- plus it's not laggy now to do that so it should be fine

	for i,mountID in ipairs(C_MountJournal.GetMountIDs()) do
		local _, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal_GetMountInfoByID(mountID);
		if spellID and isCollected then
			if not collectedSpells[spellID] then
				collectedSpells[spellID] = 1;
				if not newMounts then newMounts = { spellID }
				else tinsert(newMounts, spellID); end
			end
		end
	end
	UpdateRawIDs("spellID", newMounts);
	if newMounts and #newMounts > 0 then
		app:PlayRareFindSound();
		app:TakeScreenShot("Mounts");
	end
end
app.events.NEW_MOUNT_ADDED = function(newMountID, ...)
	-- print("NEW_MOUNT_ADDED", newMountID, ...)
	AfterCombatCallback(RefreshMounts, newMountID);
end
app:RegisterEvent("NEW_MOUNT_ADDED");
end)();

-- Music Rolls & Selfie Filter Lib: Music Rolls
(function()
local GetSpellLink, GetSpellInfo = GetSpellLink, GetSpellInfo;
local fields = {
	["key"] = function(t)
		return "questID";
	end,
	["text"] = function(t)
		return t.link;
	end,
	["link"] = function(t)
		local _, link, _, _, _, _, _, _, _, icon = GetItemInfo(t.itemID);
		if link then
			rawset(t, "link", link);
			rawset(t, "icon", icon);
			return link;
		end
	end,
	["icon"] = function(t)
		local _, link, _, _, _, _, _, _, _, icon = GetItemInfo(t.itemID);
		if link then
			rawset(t, "link", link);
			rawset(t, "icon", icon);
			return icon;
		end
	end,
	["description"] = function(t)
		-- Check to make sure music rolls are unlocked for this character.
		if not IsQuestFlaggedCompleted(38356) or IsQuestFlaggedCompleted(37961) then
			return L["MUSIC_ROLLS_AND_SELFIE_DESC"] .. L["MUSIC_ROLLS_AND_SELFIE_DESC_2"];
		end
		return L["MUSIC_ROLLS_AND_SELFIE_DESC"];
	end,
	["filterID"] = function(t)
		return 108;
	end,
	["lvl"] = function(t)
		return 40;
	end,
	["collectible"] = function(t)
		return app.CollectibleMusicRollsAndSelfieFilters;
	end,
	["trackable"] = app.ReturnTrue,
	["collected"] = function(t)
		if IsQuestFlaggedCompleted(t.questID) then return 1; end
		if app.AccountWideMusicRollsAndSelfieFilters and ATTAccountWideData.Quests[t.questID] then return 2; end
	end,
	["saved"] = function(t)
		return IsQuestFlaggedCompleted(t.questID);
	end,
};
app.BaseMusicRoll = app.BaseObjectFields(fields, "BaseMusicRoll");
app.CreateMusicRoll = function(questID, t)
	return setmetatable(constructor(questID, t, "questID"), app.BaseMusicRoll);
end

local fields = {
	["key"] = function(t)
		return "questID";
	end,
	["text"] = function(t)
		return t.link;
	end,
	["icon"] = function(t)
		return select(3, GetSpellInfo(t.spellID));
	end,
	["link"] = function(t)
		return GetSpellLink(t.spellID);
	end,
	["description"] = function(t)
		if t.crs and #t.crs > 0 then
			for i,id in ipairs(t.crs) do
				return L["SELFIE_DESC"] .. (select(2, GetItemInfo(122674)) or "Selfie Camera MkII") .. L["SELFIE_DESC_2"] .. (app.NPCNameFromID[id] or "???")
				.. "|r" .. (t.maps and (" in |cffff8000" .. (app.GetMapName(t.maps[1]) or "???") .. "|r.") or ".");
			end
		end
	end,
	["collectible"] = function(t)
		return app.CollectibleMusicRollsAndSelfieFilters;
	end,
	["collected"] = function(t)
		if IsQuestFlaggedCompleted(t.questID) then return 1; end
		if app.AccountWideMusicRollsAndSelfieFilters and ATTAccountWideData.Quests[t.questID] then
			return 2;
		end
	end,
	["trackable"] = app.ReturnTrue,
	["saved"] = function(t)
		return IsQuestFlaggedCompleted(t.questID);
	end,
	["lvl"] = function(t)
		return 40;
	end,
};
app.BaseSelfieFilter = app.BaseObjectFields(fields, "BaseSelfieFilter");
app.CreateSelfieFilter = function(id, t)
	return setmetatable(constructor(id, t, "questID"), app.BaseSelfieFilter);
end
end)();

-- NPC Lib
(function()
-- NPC Model Harvester (also acquires the displayID)
local npcModelHarvester = CreateFrame("DressUpModel", nil, UIParent);
npcModelHarvester:SetPoint("TOPRIGHT", UIParent, "BOTTOMRIGHT", 0, 0);
npcModelHarvester:SetSize(1, 1);
npcModelHarvester:Hide();
app.NPCDisplayIDFromID = setmetatable({}, { __index = function(t, id)
	if id > 0 then
		npcModelHarvester:SetDisplayInfo(0);
		npcModelHarvester:SetUnit("none");
		npcModelHarvester:SetCreature(id);
		local displayID = npcModelHarvester:GetDisplayInfo();
		if displayID and displayID ~= 0 then
			rawset(t, id, displayID);
			return displayID;
		end
	end
end});
local npcFields = {
	["key"] = function(t)
		return "npcID";
	end,
	["name"] = function(t)
		return app.NPCNameFromID[t.npcID];
	end,
	["title"] = function(t)
		return app.NPCTitlesFromID[t.npcID];
	end,
	["displayID"] = function(t)
		return app.NPCDisplayIDFromID[t.npcID];
	end,
	["creatureID"] = function(t)	-- TODO: Do something about this, it's silly.
		return t.npcID;
	end,

	["iconAsDefault"] = function(t)
		return (t.parent and t.parent.headerID == -2 and "Interface\\Icons\\INV_Misc_Coin_01")
			or app.DifficultyIcons[GetRelativeValue(t, "difficultyID") or 1];
	end,
	["nameAsAchievement"] = function(t)
		return app.NPCNameFromID[t.npcID] or select(2, GetAchievementInfo(t.achievementID));
	end,
	["iconAsAchievement"] = function(t)
		return select(10, GetAchievementInfo(t.achievementID)) or t.iconAsDefault;
	end,
	["linkAsAchievement"] = function(t)
		return GetAchievementLink(t.achievementID);
	end,
	-- questID is sometimes a faction-based questID for a single NPC (i.e. BFA Warfront Rares), thanks Blizzard
	["questID"] = function(t)
		local qa = t.questIDA;
		local qh = t.questIDH;
		if qa then
			if app.FactionID == Enum.FlightPathFaction.Horde then
				rawset(t, "questID", qh);
				rawset(t, "otherFactionQuestID", qa);
				return qh;
			else
				rawset(t, "questID", qa);
				rawset(t, "otherFactionQuestID", qh);
				return qa;
			end
		end
	end,
	["otherFactionQuestID"] = function(t)
		local qa = t.questIDA;
		local qh = t.questIDH;
		if qa then
			if app.FactionID == Enum.FlightPathFaction.Horde then
				rawset(t, "questID", qh);
				rawset(t, "otherFactionQuestID", qa);
				return qa;
			else
				rawset(t, "questID", qa);
				rawset(t, "otherFactionQuestID", qh);
				return qh;
			end
		end
	end,
	["collectibleAsQuest"] = app.CollectibleAsQuest,
	["collectedAsQuest"] = IsQuestFlaggedCompletedForObject,
	["savedAsQuest"] = function(t)
		return IsQuestFlaggedCompleted(t.questID);
	end,
	["trackableAsQuest"] = app.ReturnTrue,
	["repeatableAsQuest"] = function(t)
		return rawget(t, "isDaily") or rawget(t, "isWeekly") or rawget(t, "isMonthly") or rawget(t, "isYearly") or rawget(t, "isWorldQuest");
	end,
	["altcollectedAsQuest"] = function(t)
		if t.altQuests then
			for i,questID in ipairs(t.altQuests) do
				if IsQuestFlaggedCompleted(questID) then
					rawset(t, "altcollected", questID);
					return questID;
				end
			end
		end
	end,
	["indicatorIcon"] = function(t)
		if app.CurrentVignettes["npcID"][t.npcID] then
			return "Category_Secrets";
		end
	end,
	-- use custom to track opposite faction questID collection in account/debug if the NPC is considered collectible
	["customTotal"] = function(t)
		if app.MODE_DEBUG_OR_ACCOUNT and t.questIDA and t.collectible then
			return 1;
		end
	end,
	["customProgress"] = function(t)
		return IsQuestFlaggedCompletedForObject(t, "otherFactionQuestID") and 1 or 0;
	end,
};
npcFields.icon = npcFields.iconAsDefault;
app.BaseNPC = app.BaseObjectFields(npcFields, "BaseNPC");

local fields = RawCloneData(npcFields);
fields.icon = npcFields.iconAsAchievement;
--fields.link = npcFields.linkAsAchievement;	-- Go to Broken Shore -> Command Center ->
app.BaseNPCWithAchievement = app.BaseObjectFields(fields, "BaseNPCWithAchievement");

local fields = RawCloneData(npcFields);
fields.altcollected = npcFields.altcollectedAsQuest;
fields.collectible = npcFields.collectibleAsQuest;
fields.collected = npcFields.collectedAsQuest;
fields.trackable = npcFields.trackableAsQuest;
fields.repeatable = npcFields.repeatableAsQuest;
fields.saved = fields.savedAsQuest;
app.BaseNPCWithQuest = app.BaseObjectFields(fields, "BaseNPCWithQuest");

local fields = RawCloneData(npcFields);
fields.icon = npcFields.iconAsAchievement;
--fields.link = npcFields.linkAsAchievement;
fields.altcollected = npcFields.altcollectedAsQuest;
fields.collectible = npcFields.collectibleAsQuest;
fields.collected = npcFields.collectedAsQuest;
fields.trackable = npcFields.trackableAsQuest;
fields.repeatable = npcFields.repeatableAsQuest;
fields.saved = fields.savedAsQuest;
app.BaseNPCWithAchievementAndQuest = app.BaseObjectFields(fields, "BaseNPCWithAchievementAndQuest");

-- Header Lib
local headerFields = {
	["key"] = function(t)
		return "headerID";
	end,
	["name"] = function(t)
		return L["HEADER_NAMES"][t.headerID];
	end,
	["icon"] = function(t)
		return L["HEADER_ICONS"][t.headerID];
	end,
	["description"] = function(t)
		return L["HEADER_DESCRIPTIONS"][t.headerID];
	end,
	["nameAsAchievement"] = function(t)
		return L["HEADER_NAMES"][t.headerID] or select(2, GetAchievementInfo(t.achievementID));
	end,
	["iconAsAchievement"] = function(t)
		return L["HEADER_ICONS"][t.headerID] or select(10, GetAchievementInfo(t.achievementID));
	end,
	["linkAsAchievement"] = function(t)
		return GetAchievementLink(t.achievementID);
	end,
	["savedAsQuest"] = function(t)
		return IsQuestFlaggedCompleted(t.questID);
	end,
	["trackableAsQuest"] = app.ReturnTrue,
};
app.BaseHeader = app.BaseObjectFields(headerFields, "BaseHeader");
local fields = RawCloneData(headerFields);
fields.name = headerFields.nameAsAchievement;
fields.icon = headerFields.iconAsAchievement;
--fields.link = headerFields.linkAsAchievement;
app.BaseHeaderWithAchievement = app.BaseObjectFields(fields, "BaseHeaderWithAchievement");
local fields = RawCloneData(headerFields);
fields.saved = headerFields.savedAsQuest;
fields.trackable = headerFields.trackableAsQuest;
app.BaseHeaderWithQuest = app.BaseObjectFields(fields, "BaseHeaderWithQuest");
local fields = RawCloneData(headerFields);
fields.name = headerFields.nameAsAchievement;
fields.icon = headerFields.iconAsAchievement;
--fields.link = headerFields.linkAsAchievement;
fields.saved = headerFields.savedAsQuest;
fields.trackable = headerFields.trackableAsQuest;
app.BaseHeaderWithAchievementAndQuest = app.BaseObjectFields(fields, "BaseHeaderWithAchievementAndQuest");
app.CreateNPC = function(id, t)
	if t then
		-- TEMP: clean MoH tagging from random Vendors
		if rawget(t, "itemID") == 137642 then
			rawset(t, "itemID", nil);
			-- print("ItemID",rawget(t, "itemID"),"used on NPC/Header group... Don't do that!",id);
		end
		if id < 1 then
			if rawget(t, "achID") then
				rawset(t, "achievementID", app.FactionID == Enum.FlightPathFaction.Horde and rawget(t, "altAchID") or rawget(t, "achID"));
				if rawget(t, "questID") then
					return setmetatable(constructor(id, t, "headerID"), app.BaseHeaderWithAchievementAndQuest);
				else
					return setmetatable(constructor(id, t, "headerID"), app.BaseHeaderWithAchievement);
				end
			else
				if rawget(t, "questID") then
					return setmetatable(constructor(id, t, "headerID"), app.BaseHeaderWithQuest);
				else
					return setmetatable(constructor(id, t, "headerID"), app.BaseHeader);
				end
			end
		else
			if rawget(t, "achID") then
				rawset(t, "achievementID", app.FactionID == Enum.FlightPathFaction.Horde and rawget(t, "altAchID") or rawget(t, "achID"));
				if rawget(t, "questID") then
					return setmetatable(constructor(id, t, "npcID"), app.BaseNPCWithAchievementAndQuest);
				else
					return setmetatable(constructor(id, t, "npcID"), app.BaseNPCWithAchievement);
				end
			else
				if rawget(t, "questID") or rawget(t, "questIDA") then
					return setmetatable(constructor(id, t, "npcID"), app.BaseNPCWithQuest);
				else
					return setmetatable(constructor(id, t, "npcID"), app.BaseNPC);
				end
			end
		end
	elseif id > 1 then
		return setmetatable(constructor(id, t, "npcID"), app.BaseNPC);
	else
		return setmetatable(constructor(id, t, "headerID"), app.BaseHeader);
	end
end
end)();

-- Object Lib (as in "World Object")
(function()
local objectFields = {
	["key"] = function(t)
		return "objectID";
	end,
	["name"] = function(t)
		return app.ObjectNames[t.objectID] or ("Object ID #" .. t.objectID);
	end,
	["icon"] = function(t)
		return app.ObjectIcons[t.objectID] or "Interface\\Icons\\INV_Misc_Bag_10";
	end,
	["model"] = function(t)
		return app.ObjectModels[t.objectID];
	end,

	["nameAsAchievement"] = function(t)
		return app.NPCNameFromID[t.npcID] or select(2, GetAchievementInfo(t.achievementID));
	end,
	["iconAsAchievement"] = function(t)
		return select(10, GetAchievementInfo(t.achievementID)) or t.iconAsDefault;
	end,
	["linkAsAchievement"] = function(t)
		return GetAchievementLink(t.achievementID);
	end,
	["collectibleAsQuest"] = app.CollectibleAsQuest,
	["collectedAsQuest"] = IsQuestFlaggedCompletedForObject,
	["savedAsQuest"] = function(t)
		return IsQuestFlaggedCompleted(t.questID);
	end,
	["trackableAsQuest"] = app.ReturnTrue,
	["repeatableAsQuest"] = function(t)
		return rawget(t, "isDaily") or rawget(t, "isWeekly") or rawget(t, "isMonthly") or rawget(t, "isYearly") or rawget(t, "isWorldQuest");
	end,
	["altcollectedAsQuest"] = function(t)
		if t.altQuests then
			for i,questID in ipairs(t.altQuests) do
				if IsQuestFlaggedCompleted(questID) then
					rawset(t, "altcollected", questID);
					return questID;
				end
			end
		end
	end,
	["lockedAsQuest"] = app.LockedAsQuest,
	["indicatorIcon"] = function(t)
		if app.CurrentVignettes["objectID"][t.objectID] then
			return "Category_Secrets";
		end
	end,

	-- Generic fields (potentially replaced by specific object types)
	["trackable"] = function(t)
		-- only used for generic objects with no other way of being considered trackable
		if not t.g then return; end
		for _,group in ipairs(t.g) do
			if group.objectID and group.trackable then return true; end
		end
	end,
	["repeatable"] = function(t)
		-- only used for generic objects with no other way of being tracked as repeatable
		if not t.g then return; end
		for _,group in ipairs(t.g) do
			if group.objectID and group.repeatable then return true; end
		end
		-- every contained sub-object is not repeatable, so the repeated object should also be marked as not repeatable
	end,
	["saved"] = function(t)
		-- only used for generic objects with no other way of being tracked as saved
		if not t.g then return; end
		local anySaved;
		for _,group in ipairs(t.g) do
			if group.objectID then
				if group.saved then
					anySaved = true;
				else
					return;
				end
			end
		end
		-- every contained sub-object is already saved, so the repeated object should also be marked as saved
		return anySaved;
	end,
	["coords"] = function(t)
		-- only used for generic objects with no other way of being tracked as saved
		if not t.g then return; end
		local unsavedCoords = {};
		for _,group in ipairs(t.g) do
			-- show collected coords of all sub-objects which are not saved
			if group.objectID and group.coords and not group.saved then
				app.ArrayAppend(unsavedCoords, group.coords);
			end
		end
		return unsavedCoords;
	end,
};
app.BaseObject = app.BaseObjectFields(objectFields, "BaseObject");

local fields = RawCloneData(objectFields);
fields.icon = objectFields.iconAsAchievement;
--fields.link = objectFields.linkAsAchievement;
app.BaseObjectWithAchievement = app.BaseObjectFields(fields, "BaseObjectWithAchievement");

local fields = RawCloneData(objectFields);
fields.altcollected = objectFields.altcollectedAsQuest;
fields.collectible = objectFields.collectibleAsQuest;
fields.collected = objectFields.collectedAsQuest;
fields.trackable = objectFields.trackableAsQuest;
fields.repeatable = objectFields.repeatableAsQuest;
fields.saved = objectFields.savedAsQuest;
fields.locked = objectFields.lockedAsQuest;
app.BaseObjectWithQuest = app.BaseObjectFields(fields, "BaseObjectWithQuest");

local fields = RawCloneData(objectFields);
fields.icon = objectFields.iconAsAchievement;
--fields.link = objectFields.linkAsAchievement;
fields.altcollected = objectFields.altcollectedAsQuest;
fields.collectible = objectFields.collectibleAsQuest;
fields.collected = objectFields.collectedAsQuest;
fields.trackable = objectFields.trackableAsQuest;
fields.repeatable = objectFields.repeatableAsQuest;
fields.saved = objectFields.savedAsQuest;
fields.locked = objectFields.lockedAsQuest;
app.BaseObjectWithAchievementAndQuest = app.BaseObjectFields(fields, "BaseObjectWithAchievementAndQuest");
app.CreateObject = function(id, t)
	if t then
		if rawget(t, "achID") then
			rawset(t, "achievementID", app.FactionID == Enum.FlightPathFaction.Horde and rawget(t, "altAchID") or rawget(t, "achID"));
			if rawget(t, "questID") then
				return setmetatable(constructor(id, t, "objectID"), app.BaseObjectWithAchievementAndQuest);
			else
				return setmetatable(constructor(id, t, "objectID"), app.BaseObjectWithAchievement);
			end
		else
			if rawget(t, "questID") then
				return setmetatable(constructor(id, t, "objectID"), app.BaseObjectWithQuest);
			end
		end
	end
	return setmetatable(constructor(id, t, "objectID"), app.BaseObject);
end
end)();

-- Profession Lib
(function()
app.SkillIDToSpellID = {
	[171] = 2259,	-- Alchemy
	[794] = 158762,	-- Arch
	[261] = 5149,	-- Beast Training
	[164] = 2018,	-- Blacksmithing
	[185] = 2550,	-- Cooking
	[333] = 7411,	-- Enchanting
	[202] = 4036,	-- Engineering
	[356] = 7620,	-- Fishing
	[129] = 3273,	-- First Aid
	[182] = 2366,	-- Herb Gathering
	[773] = 45357,	-- Inscription
	[755] = 25229,	-- Jewelcrafting
	--[2720] = 2720,	-- Junkyard Tinkering [Does not have a spellID]
	[165] = 2108,	-- Leatherworking
	[186] = 2575,	-- Mining
	[393] = 8613,	-- Skinning
	[197] = 3908,	-- Tailoring
	[960] = 53428,  -- Runeforging
	[40] = 2842,	-- Poisons
	[633] = 1809,	-- Lockpicking

	-- Specializations
	[20219] = 20219,	-- Gnomish Engineering
	[20222] = 20222,	-- Goblin Engineering
	[9788] = 9788,		-- Armorsmith
	[9787] = 9787,		-- Weaponsmith
	[17041] = 17041,	-- Master Axesmith
	[17040] = 17040,	-- Master Hammersmith
	[17039] = 17039,	-- Master Swordsmith
	[10656] = 10656,	-- Dragonscale Leatherworking
	[10658] = 10658,	-- Elemental Leatherworking
	[10660] = 10660,	-- Tribal Leatherworking
	[26801] = 26801,	-- Shadoweave Tailoring
	[26797] = 26797,	-- Spellfire Tailoring
	[26798] = 26798,	-- Mooncloth Tailoring
	[125589] = 125589,	-- Way of the Brew
	[124694] = 124694,	-- Way of the Grill
	[125588] = 125588,	-- Way of the Oven
	[125586] = 125586,	-- Way of the Pot
	[125587] = 125587,	-- Way of the Steamer
	[125584] = 125584,	-- Way of the Wok
};
app.SpellIDToSkillID = {};
for skillID,spellID in pairs(app.SkillIDToSpellID) do
	app.SpellIDToSkillID[spellID] = skillID;
end
app.SpecializationSpellIDs = setmetatable({
	[20219] = 4036,	-- Gnomish Engineering
	[20222] = 4036,	-- Goblin Engineering
	[9788] = 2018,	-- Armorsmith
	[9787] = 2018,	-- Weaponsmith
	[17041] = 2018,	-- Master Axesmith
	[17040] = 2018,	-- Master Hammersmith
	[17039] = 2018,	-- Master Swordsmith
	[10656] = 2108,	-- Dragonscale Leatherworking
	[10658] = 2108,	-- Elemental Leatherworking
	[10660] = 2108,	-- Tribal Leatherworking
	[26801] = 3908,	-- Shadoweave Tailoring
	[26797] = 3908,	-- Spellfire Tailoring
	[26798] = 3908,	-- Mooncloth Tailoring
	[125589] = 2550,-- Way of the Brew
	[124694] = 2550,-- Way of the Grill
	[125588] = 2550,-- Way of the Oven
	[125586] = 2550,-- Way of the Pot
	[125587] = 2550,-- Way of the Steamer
	[125584] = 2550,-- Way of the Wok
}, {__index = function(t,k) return k; end})

local fields = {
	["key"] = function(t)
		return "professionID";
	end,
	--[[
	["name"] = function(t)
		if app.GetSpecializationBaseTradeSkill(t.professionID) then return GetSpellInfo(t.professionID); end
		if t.professionID == 129 then return GetSpellInfo(t.spellID); end
		return C_TradeSkillUI.GetTradeSkillDisplayName(t.professionID);
	end,
	["icon"] = function(t)
		if app.GetSpecializationBaseTradeSkill(t.professionID) then return select(3, GetSpellInfo(t.professionID)); end
		if t.professionID == 129 then return select(3, GetSpellInfo(t.spellID)); end
		return C_TradeSkillUI.GetTradeSkillTexture(t.professionID);
	end,
	]]--
	["name"] = function(t)
		return t.spellID ~= 2366 and select(1, GetSpellInfo(t.spellID)) or C_TradeSkillUI.GetTradeSkillDisplayName(t.professionID);
	end,
	["icon"] = function(t)
		return select(3, GetSpellInfo(t.spellID)) or C_TradeSkillUI.GetTradeSkillTexture(t.professionID);
	end,
	["spellID"] = function(t)
		return app.SkillIDToSpellID[t.professionID];
	end,
	["skillID"] = function(t)
		return t.professionID;
	end,
	["requireSkill"] = function(t)
		return t.professionID;
	end,
	--[[
	["sym"] = function(t)
		return {{"selectprofession", t.professionID},
				{"not","headerID",-38}};	-- Ignore the Main Professions header that will get pulled in
	end,
	--]]--
};
app.BaseProfession = app.BaseObjectFields(fields, "BaseProfession");
app.CreateProfession = function(id, t)
	return setmetatable(constructor(id, t, "professionID"), app.BaseProfession);
end
end)();

-- PVP Ranks
(function()
local fields = {
	["key"] = function(t)
		return "pvpRankID";
	end,
	["text"] = function(t)
		return _G["PVP_RANK_" .. (t.pvpRankID + 4) .. "_" .. (t.inverseR or 0)];
	end,
	["icon"] = function(t)
		return format("%s%02d","Interface\\PvPRankBadges\\PvPRank", t.pvpRankID);
	end,
	["title"] = function(t)
		return RANK .. " " .. t.pvpRankID .. DESCRIPTION_SEPARATOR ..  _G["PVP_RANK_" .. (t.pvpRankID + 4) .. "_" .. ((t.inverseR == 1 and 0 or 1))] .. " (" .. (t.r == Enum.FlightPathFaction.Alliance and FACTION_HORDE or FACTION_ALLIANCE) .. ")";
	end,
	["description"] = function(t)
		return "There are a total of 14 ranks for both factions. Each rank requires a minimum amount of Rating Points to be calculated every week, then calculated in comparison to other players on your server.\n\nEach rank grants access to different rewards, from PvP consumables to Epic Mounts that do not require Epic Riding Skill and Epic pieces of gear at the highest ranks. Each rank is also applied to your character as a Title.";
	end,
	["r"] = function(t)
		return t.parent.r or app.FactionID;
	end,
	["inverseR"] = function(t)
		return t.r == Enum.FlightPathFaction.Alliance and 1 or 0;
	end,
	["lifetimeRank"] = function(t)
		return select(3, GetPVPLifetimeStats());
	end,
	["collectible"] = app.ReturnFalse,
	["collected"] = function(t)
		return t.lifetimeRank >= t.pvpRankID;
	end,
	["OnTooltip"] = function(t)
		GameTooltip:AddDoubleLine("Your lifetime highest rank: ", _G["PVP_RANK_" .. (t.lifetimeRank) .. "_" .. (app.FactionID == 2 and 1 or 0)], 1, 1, 1, 1, 1, 1);
	end
};
app.BasePVPRank = app.BaseObjectFields(fields, "BasePVPRank");
app.CreatePVPRank = function(id, t)
	return setmetatable(constructor(id, t, "pvpRankID"), app.BasePVPRank);
end
end)();

-- Race Lib
(function()
local cache = app.CreateCache("raceID");
local C_CreatureInfo_GetRaceInfo = C_CreatureInfo.GetRaceInfo;
local C_AlliedRaces_GetRaceInfoByID = C_AlliedRaces.GetRaceInfoByID;
local function default_name(t)
	local info = C_CreatureInfo_GetRaceInfo(t.raceID);
	return info and info.raceName;
end
local function default_text(t)
	return app.TryColorizeName(t, t.name);
end
local function default_icon(t)
	local icon;
	-- Allied Races are different
	local arInfo = C_AlliedRaces_GetRaceInfoByID(t.raceID);
	if arInfo then
		local race = string_lower(arInfo.raceFileString);
		-- blizzard being inconsistent
		if race == "kultiran" then race = "kultiranhuman"; end
		icon = "Interface\\Icons\\achievement_alliedrace_"..race;
	else
		local info = C_CreatureInfo_GetRaceInfo(t.raceID);
		local race = string_lower(info.clientFileString);
		-- blizzard being inconsistent
		if race == "scourge" then race = "undead"; end
		if race == "goblin" then
			-- goblinhead?
			local gender = app.Gender == 2 and "" or "female";
			icon = "Interface\\Icons\\achievement_"..gender.."goblinhead";
		elseif race == "worgen" then
			-- misspelled worgen?
			icon = "Interface\\Icons\\achievement_worganhead";
		elseif race == "pandaren" then
			-- no pandaren male icon?
			icon = "Interface\\Icons\\achievement_character_pandaren_female";
		else
			local gender = app.Gender == 2 and "male" or "female";
			icon = "Interface\\Icons\\achievement_character_"..race.."_"..gender;
		end
	end
	return icon;
end
local raceFields = {
	["key"] = function(t)
		return "raceID";
	end,
	["text"] = function(t)
		return cache.GetCachedField(t, "text", default_text);
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", default_icon);
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", default_name);
	end,
};
app.BaseRace = app.BaseObjectFields(raceFields, "BaseRace");
app.CreateRace = function(id, t)
	return setmetatable(constructor(id, t, "raceID"), app.BaseRace);
end
end)();

-- Spell Lib
(function()
local GetSpellInfo, GetSpellLink, IsSpellKnown, IsPlayerSpell, GetNumSpellTabs, GetSpellTabInfo =
	  GetSpellInfo, GetSpellLink, IsSpellKnown, IsPlayerSpell, GetNumSpellTabs, GetSpellTabInfo

-- Consolidates some spell checking
local IsSpellKnownHelper = function(spellID, rank, ignoreHigherRanks)
    if IsPlayerSpell(spellID) or IsSpellKnown(spellID) or IsSpellKnown(spellID, true)
        or IsSpellKnownOrOverridesKnown(spellID) or IsSpellKnownOrOverridesKnown(spellID, true) then
        return true;
    end
end
app.IsSpellKnownHelper = IsSpellKnownHelper;

local SpellIDToSpellName = {};
local SpellNameToSpellID;
local GetSpellName = function(spellID)
	local spellName = rawget(SpellIDToSpellName, spellID);
	if spellName then return spellName; end
	spellName = GetSpellInfo(spellID);
	if spellName and spellName ~= "" then
		rawset(SpellIDToSpellName, spellID, spellName);
		rawset(SpellNameToSpellID, spellName, spellID);
		return spellName;
	end
end
app.GetSpellName = GetSpellName;
SpellNameToSpellID = setmetatable({}, {
	__index = function(t, key)
		local cache = fieldCache["spellID"];
		for spellID,g in pairs(cache) do
			GetSpellName(spellID);
		end
		for _,spellID in pairs(app.SkillIDToSpellID) do
			GetSpellName(spellID);
		end
		for specID,spellID in pairs(app.SpecializationSpellIDs) do
			GetSpellName(spellID);
		end
		local numSpellTabs, offset, lastSpellName, currentSpellRank = GetNumSpellTabs(), select(4, GetSpellTabInfo(1)), "", 1;
		for spellTabIndex=2,numSpellTabs do
			local numSpells = select(4, GetSpellTabInfo(spellTabIndex));
			for spellIndex=1,numSpells do
				local spellName, _, _, _, _, _, spellID = GetSpellInfo(offset + spellIndex, BOOKTYPE_SPELL);
				if spellName then
					if lastSpellName == spellName then
						currentSpellRank = currentSpellRank + 1;
					else
						lastSpellName = spellName;
						currentSpellRank = 1;
					end
					GetSpellName(spellID, currentSpellRank);
					rawset(SpellNameToSpellID, spellName, spellID);
				-- else
				-- 	print("GetSpellInfo:Failed",offset + spellIndex);
				end
			end
			offset = offset + numSpells;
		end
		return rawget(t, key);
	end
});
app.SpellNameToSpellID = SpellNameToSpellID;
-- Represents a small lookup of a select set of Profession/Skill-related icons
local SkillIcons = setmetatable({
	[2720] = 2620862,	-- Junkyard Tinkering
	[2819] = 3747898,	-- Protoform Synthesis
}, { __index = function(t, key)
	if not key then return; end
	local skillSpellID = app.SkillIDToSpellID[key];
	if skillSpellID then
		local _, _, icon = GetSpellInfo(skillSpellID);
		return icon;
	end
end
});

local cache = app.CreateCache("_cachekey");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	if t.itemID then
		local name, link, _, _, _, _, _, _, _, icon = GetItemInfo(t.itemID);
		if link then
			_t.name = name;
			_t.link = link;
			_t.icon = icon;
		end
	else
		local name, _, icon = GetSpellInfo(id);
		_t.name = name;
		-- typically, the profession's spell icon will be a better representation of the spell if the spell is tied to a skill
		_t.icon = SkillIcons[t.skillID] or icon;
		local link = GetSpellLink(id);
		_t.link = link;
	end
	-- track number of attempts to cache data for fallback to default values
	local retries = (_t.retries or 0) + 1;
	if retries > app.MaximumItemInfoRetries then
		_t.name = t.itemID and "Item #"..t.itemID or "Spell #"..t.spellID;
		-- fallback to skill icon if possible
		_t.icon = SkillIcons[t.skillID] or 136243;	-- Trade_engineering
		_t.link = _t.name;
	end
	_t.retries = retries;
	if field then return _t[field]; end
end

local fields = {
	["key"] = function(t)
		return "spellID";
	end,
	["_cachekey"] = function(t)
		return t.itemID and t.spellID + (t.itemID / 1000000) or t.spellID;
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["link"] = function(t)
		return cache.GetCachedField(t, "link", CacheInfo);
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo) or 136243;	-- Trade_engineering
	end,
	["text"] = function(t)
		return t.link;
	end,
	["trackable"] = app.ReturnTrue,
	["saved"] = function(t)
		local spellID = t.spellID;
		if app.CurrentCharacter.Spells[spellID] then return true; end
		if IsSpellKnownHelper(spellID) then
			app.CurrentCharacter.Spells[spellID] = 1;
			ATTAccountWideData.Spells[spellID] = 1;
			return true;
		end
	end,
	["collectible"] = app.ReturnFalse,
	["collected"] = function(t)
		if t.saved then return 1; end
		if app.AccountWideRecipes and ATTAccountWideData.Spells[t.spellID] then return 2; end
	end,
	["specs"] = function(t)
		if t.itemID then
			return GetFixedItemSpecInfo(t.itemID);
		end
	end,
	["tsm"] = function(t)
		if t.itemID then
			return sformat("i:%d", t.itemID);
		end
	end,
	["skillID"] = function(t)
		return t.requireSkill;
	end,
};
app.BaseSpell = app.BaseObjectFields(fields, "BaseSpell");
app.CreateSpell = function(id, t)
	return setmetatable(constructor(id, t, "spellID"), app.BaseSpell);
end

-- Recipe Lib
local recipeFields = RawCloneData(fields, {
	["filterID"] = function(t)
		return 200;
	end,
	["collectible"] = function(t)
		return app.CollectibleRecipes;
	end,
	["collected"] = function(t)
		if t.saved then return 1; end
		if app.AccountWideRecipes and ATTAccountWideData.Spells[t.spellID] then return 2; end
	end,
	["b"] = function(t)
		-- If not tracking Recipes Account-Wide, then pretend that every Recipe is BoP
		return t.itemID and app.AccountWideRecipes and 2 or 1;
	end,
});
app.BaseRecipe = app.BaseObjectFields(recipeFields, "BaseRecipe");
app.CreateRecipe = function(id, t)
	return setmetatable(constructor(id, t, "spellID"), app.BaseRecipe);
end
end)();

-- Tier Lib
do
local EJ_GetTierInfo = EJ_GetTierInfo;
local math_floor = math.floor;
local cache = app.CreateCache("tierID");
local function CacheInfo(t, field)
	local _t, id = cache.GetCached(t);
	-- patch can be included in the id
	local tierID = math_floor(id);
	rawset(t, "tierKey", tierID);
	local info = rawget(L.TIER_DATA, tierID);
	-- assign the cached values from locale
	if info then
		-- app.PrintDebug("tier cache locale data",id,tierID,"via",field)
		for key,val in pairs(info) do
			-- app.PrintDebug("--",key,val)
			rawset(_t, key, val);
		end
	end
	if id > tierID then
		local patch_decimal = 100 * (id - tierID);
		local patch = math_floor(patch_decimal + 0.0001);
		local rev = math_floor(10 * (patch_decimal - patch) + 0.0001);
		-- app.PrintDebug("tier cache patch ID",id,tierID,patch_decimal,patch,rev)
		_t.name = tostring(tierID).."."..tostring(patch).."."..tostring(rev);
	else
		-- only use API for name if not set from locale
		_t.name = _t.name or EJ_GetTierInfo(tierID);
	end
	if field then return _t[field]; end
end
local fields = {
	["key"] = function(t)
		return "tierID";
	end,
	["name"] = function(t)
		return cache.GetCachedField(t, "name", CacheInfo);
	end,
	["icon"] = function(t)
		return cache.GetCachedField(t, "icon", CacheInfo);
	end,
	["lore"] = function(t)
		return cache.GetCachedField(t, "lore", CacheInfo);
	end,
	["lvl"] = function(t)
		return cache.GetCachedField(t, "lvl", CacheInfo);
	end,
};
app.BaseTier = app.BaseObjectFields(fields, "BaseTier");
app.CreateTier = function(id, t)
	return setmetatable(constructor(id, t, "tierID"), app.BaseTier);
end
end -- Tier Lib

-- Title Lib
(function()
local function StylizePlayerTitle(title, style, me)
	if style == 0 then
		-- Prefix
		return title .. me;
	elseif style == 1 then
		-- Player Name First
		return me .. title;
	elseif style == 2 then
		-- Player Name First (with space)
		return me .. " " .. title;
	elseif style == 3 then
		-- Comma Separated
		return me .. ", " .. title;
	end
end
local fields = {
	["key"] = function(t)
		return "titleID";
	end,
	["filterID"] = function(t)
		return 110;
	end,
	["icon"] = function(t)
		return app.asset("Category_Titles");
	end,
	["description"] = function(t)
		return L["TITLES_DESC"];
	end,
	["text"] = function(t)
		local name = t.name;
		if name then
			name = "|cff00ccff" .. name .. "|r";
			rawset(t, "text", name);
			return name;
		end
	end,
	["link"] = function(t)
		return t.text;
	end,
	["title"] = function(t)
		if t.titleIDs and app.MODE_DEBUG_OR_ACCOUNT then
			if rawget(t, "_title") then return rawget(t, "_title") end
			local ids = t.titleIDs;
			local m, f = ids[1], ids[2];
			local acctTitles = ATTAccountWideData.Titles;
			local player = "("..CALENDAR_PLAYER_NAME..")";
			local mt = StylizePlayerTitle(GetTitleName(m),t.style,player);
			local ft = StylizePlayerTitle(GetTitleName(f),t.style,player);
			local complete, missing = GetProgressColor(1), GetProgressColor(0);
			local acctTitleInfo = "|c"..
				(acctTitles[m] and complete or missing)..mt.."|r // |c"..
				(acctTitles[f] and complete or missing)..ft.."|r";
			rawset(t, "_title", acctTitleInfo);
			return rawget(t, "_title");
		end
	end,
	["style"] = function(t)
		local name = t.titleName;
		if name then
			local first = string.sub(name, 1, 1);
			if first == " " then
				-- Suffix
				first = string.sub(name, 2, 2);
				if first == string.upper(first) then
					-- Comma Separated
					rawset(t, "style", 3);
					return 3;
				end

				-- Player Name First
				rawset(t, "style", 1);
				return 1;
			else
				local last = string.sub(name, -1);
				if last == " " then
					-- Prefix
					rawset(t, "style", 0);
					return 0;
				end

				-- Suffix
				if first == string_lower(first) then
					-- Player Name First with a space
					rawset(t, "style", 2);
					return 2;
				end

				-- Comma Separated
				rawset(t, "style", 3);
				return 3;
			end
		end

		rawset(t, "style", 1);
		return 1;	-- Player Name First
	end,
	["name"] = function(t)
		-- return the gender-proper name for the title
		local name = t.titleName;
		if name then
			rawset(t, "name", StylizePlayerTitle(name, t.style, UnitName("player")));
		end
		return name;
	end,
	["titleName"] = function(t)
		if t.titleIDs then
			return GetTitleName(app.Gender == 2 and t.titleIDs[1] or t.titleIDs[2]);
		else
			return GetTitleName(t.titleID);
		end
	end,
	["collectible"] = function(t)
		return app.CollectibleTitles;
	end,
	["trackable"] = app.ReturnTrue,
	["collected"] = function(t)
		if t.saved then return 1; end
		if app.AccountWideTitles and ATTAccountWideData.Titles[t.titleID] then return 2; end
	end,
	["saved"] = function(t)
		local id, charTitles, acctTitles = t.titleID, app.CurrentCharacter.Titles, ATTAccountWideData.Titles;
		if t.titleIDs then
			local ids = t.titleIDs;
			local m, f = ids[1], ids[2];
			-- combo-id is already saved and m/f cached for the current character
			if acctTitles[id] and (charTitles[m] or charTitles[f]) then
				return true;
			-- otherwise verify both titles for players with one already saved
			elseif IsTitleKnown(m) then
				charTitles[m] = 1;
				acctTitles[m] = 1;
				-- the shared arbitrary ID can be used for account-wide checks
				charTitles[id] = 1;
				acctTitles[id] = 1;
				return true;
			elseif IsTitleKnown(f) then
				charTitles[f] = 1;
				acctTitles[f] = 1;
				-- the shared arbitrary ID can be used for account-wide checks
				charTitles[id] = 1;
				acctTitles[id] = 1;
				return true;
			end
		else
			if charTitles[id] then return true; end
			if IsTitleKnown(id) then
				charTitles[id] = 1;
				acctTitles[id] = 1;
				return true;
			end
		end
	end,
	-- use custom to track opposite gendered title in account/debug
	["customTotal"] = function(t)
		if app.CollectibleTitles and t.titleIDs and app.MODE_DEBUG_OR_ACCOUNT then
			return 1;
		end
	end,
	["customProgress"] = function(t)
		-- print("title.progress",t.titleID)
		local acctTitles, charTitles = ATTAccountWideData.Titles, app.CurrentCharacter.Titles;
		local ids = t.titleIDs;
		local m, f = ids[1], ids[2];
		local am, af = acctTitles[m], acctTitles[f];
		-- both titles account-collected
		if am and af then
			return 1;
		-- neither title collected
		elseif not am and not af then
			return 0;
		-- only the available title is collected
		elseif charTitles[m] or charTitles[f] then
			return 0;
		end
		-- otherwise, unavailable title is collected
		return 1;
	end,
};
app.BaseTitle = app.BaseObjectFields(fields, "BaseTitle");
app.CreateTitle = function(id, t)
	return setmetatable(constructor(id, t, "titleID"), app.BaseTitle);
end
end)();

-- Filtering
do
-- Meaning "Don't display." - Returns false
local Filter = app.ReturnFalse;
-- Meaning "Display as expected" - Returns true
local NoFilter = app.ReturnTrue;
-- Whether the group has a binding designation, which means it basically cannot be moved to another Character
local function IsBoP(group)
	-- 1 = BoP, 4 = Quest Item... probably don't need that?
	return group.b == 1;-- or group.b == 4;
end
local function FilterGroupsByLevel(group)
	-- after 9.0, transition to a req lvl range, either min, or min + max
	local lvl = group.lvl;
	if lvl then
		local minlvl;
		local maxlvl;
		if type(lvl) == "table" then
			minlvl = lvl[1];
			maxlvl = lvl[2];
		else
			minlvl = lvl;
		end

		if maxlvl then
			-- min and max provided
			return app.Level >= minlvl and app.Level <= maxlvl;
		elseif minlvl then
			-- only min provided
			return app.Level >= minlvl;
		end
	end
	-- no level requirement on the group, have to include it
	return true;
end
local function FilterGroupsByCompletion(group)
	return group.total and (group.progress or 0) < group.total;
end
-- returns whether this is a Character-transferable Thing/Item
local function FilterItemBind(item)
	return item.itemID and not IsBoP(item);
end
-- Represents filters which should be applied during Updates to groups
local function FilterItemClass(item)
	-- check Account trait filters
	if app.UnobtainableItemFilter(item)
		and app.SeasonalItemFilter(item)
		and app.PvPFilter(item)
		and app.PetBattleFilter(item)
		and app.RequireFactionFilter(item) then
		-- BoE can skip Character trait filters
		if app.ItemBindFilter(item) then return true; end
		-- check Character trait filters
		return app.ItemTypeFilter(item)
			and app.RequireBindingFilter(item)
			and app.RequiredSkillFilter(item)
			and app.ClassRequirementFilter(item)
			and app.RaceRequirementFilter(item)
			and app.RequireCustomCollectFilter(item);
	end
end
-- Represents filters which should be applied during Updates to groups, but skips the BoE filter
local function FilterItemClass_IgnoreBoEFilter(item)
	-- check Account trait filters
	if app.UnobtainableItemFilter(item)
		and app.SeasonalItemFilter(item)
		and app.PvPFilter(item)
		and app.PetBattleFilter(item)
		and app.RequireFactionFilter(item) then
		-- check Character trait filters
		return app.ItemTypeFilter(item)
			and app.RequireBindingFilter(item)
			and app.RequiredSkillFilter(item)
			and app.ClassRequirementFilter(item)
			and app.RaceRequirementFilter(item)
			and app.RequireCustomCollectFilter(item);
	end
end
local function FilterItemClass_RequireClasses(item)
	return not item.nmc;
end
local function FilterItemClass_RequireItemFilter(item)
	local f = item.f;
	if f then
		-- don't filter Heirlooms by their Type if they are collectible as Heirlooms
		if item.__type == "BaseHeirloom" and app.CollectibleHeirlooms then
			return true;
		end
		return app.Settings:GetFilter(f);	-- Filter applied via Settings (character-equippable or manually set)
	else
		return true;
	end
end
local function FilterItemClass_RequireRaces(item)
	return not item.nmr;
end
local function FilterItemClass_RequireRacesCurrentFaction(item)
	if item.nmr then
		local r = item.r;
		if r then
			if r == app.FactionID then
				return true;
			else
				return false;
			end
		end
		local races = item.races;
		if races then
			if app.FactionID == Enum.FlightPathFaction.Horde then
				return containsAny(races, HORDE_ONLY);
			else
				return containsAny(races, ALLIANCE_ONLY);
			end
		else
			return false;
		end
	else
		return true;
	end
end
local function FilterItemClass_SeasonalItem(item)
	-- specifically match on false for being disabled as a filter
	if item.u and app.Settings:GetValue("Seasonal", item.u) == false then
		return false;
	end
	return true;
end
local function ItemIsInGame(item)
	return not item.u or item.u > 2;
end
local function FilterItemClass_UnobtainableItem(item)
	-- specifically match on false for being disabled as a filter
	if item.u and app.Settings:GetValue("Unobtainable", item.u) == false then
		return false;
	end
	return true;
end
local function FilterItemClass_RequireBinding(item)
	return not item.itemID or IsBoP(item);
end
local function FilterItemClass_PvP(item)
	if item.pvp then
		return false;
	else
		return true;
	end
end
local function FilterItemClass_PetBattles(item)
	if item.pb then
		return false;
	else
		return true;
	end
end
local function FilterItemClass_RequiredSkill(item)
	local requireSkill = item.requireSkill;
	if requireSkill and (not item.professionID or not GetRelativeValue(item, "DontEnforceSkillRequirements") or IsBoP(item)) then
		return app.CurrentCharacter.Professions[requireSkill];
	else
		return true;
	end
end
local function FilterItemClass_RequireFaction(item)
	local minReputation = item.minReputation;
	if minReputation and app.IsFactionExclusive(minReputation[1]) then
		if minReputation[2] > (select(6, GetFactionInfoByID(minReputation[1])) or 0) then
			--print("Filtering Out", item.key, item[item.key], item.text, item.minReputation[1], app.CreateFaction(item.minReputation[1]).text);
			return false;
		else
			return true;
		end
	else
		return true;
	end
end
local function FilterItemClass_CustomCollect(item)
	local customCollect = item.customCollect;
	if customCollect then
		local customCollects = app.ActiveCustomCollects;
		for _,c in ipairs(customCollect) do
			if not customCollects[c] then
				return false;
			end
		end
	end
	return true;
end
-- Represents current Character filtering for the Item (regardless of user-enabled filters)
local function CurrentCharacterFilters(item)
	return FilterItemClass_RequiredSkill(item)
		and FilterItemClass_RequireClasses(item)
		and FilterItemClass_RequireRaces(item)
		and FilterItemClass_CustomCollect(item)
		and FilterItemClass_UnobtainableItem(item);
end
local function FilterItemSource(sourceInfo)
	return sourceInfo.isCollected;
end
local function FilterItemSourceUnique(sourceInfo, allSources)
	if sourceInfo.isCollected then
		-- NOTE: This makes it so that the loop isn't necessary.
		return true;
	else
		-- If at least one of the sources of this visual ID was collected, that means that we've collected the provided source
		local item = SearchForSourceIDQuickly(sourceInfo.sourceID);
		if item then
			local knownItem, knownSource, valid;
			for _,sourceID in ipairs(allSources or C_TransmogCollection_GetAllAppearanceSources(sourceInfo.visualID)) do
				-- only compare against other Sources of the VisualID which the Account knows
				if sourceID ~= sourceInfo.sourceID and rawget(ATTAccountWideData.Sources, sourceID) == 1 then
					knownItem = SearchForSourceIDQuickly(sourceID);
					if knownItem then
						-- filter matches or one item is Cosmetic
						if item.f == knownItem.f or item.f == 2 or knownItem.f == 2 then
							valid = true;
							-- verify all possible restrictions that the known source may have against restrictions on the source in question
							-- if known source has no equivalent restrictions, then restrictions on the source are irrelevant
							-- Races
							if knownItem.races then
								if item.races then
									-- the known source has a race restriction that is not shared by the source in question
									if not containsAny(item.races, knownItem.races) then valid = nil; end
								else
									valid = nil;
								end
							end
							-- Classes
							if valid and knownItem.c then
								if item.c then
									-- the known source has a class restriction that is not shared by the source in question
									if not containsAny(item.c, knownItem.c) then valid = nil; end
								else
									valid = nil;
								end
							end
							-- Faction
							if valid and knownItem.r then
								if item.r then
									-- the known source has a faction restriction that is not shared by the source or source races in question
									if knownItem.r ~= item.r or (item.races and not containsAny(app.FACTION_RACES[knownItem.r], item.races)) then valid = nil; end
								else
									valid = nil;
								end
							end

							-- found a known item which meets all the criteria to grant credit for the source in question
							if valid then
								knownSource = C_TransmogCollection_GetSourceInfo(sourceID);
								-- both sources are the same category (Equip-Type)
								if knownSource.categoryID == sourceInfo.categoryID
									-- and same Inventory Type
									and (knownSource.invType == sourceInfo.invType
										or sourceInfo.categoryID == 4 --[[CHEST: Robe vs Armor]]
										or app.SlotByInventoryType[knownSource.invType] == app.SlotByInventoryType[sourceInfo.invType])
								then
									return true;
								-- else print("sources share visual and filters but different equips",item.s,sourceID)
								end
							end
						end
					else
						-- OH NOES! It doesn't exist!
						knownSource = C_TransmogCollection_GetSourceInfo(sourceID);
						-- both sources are the same category (Equip-Type)
						if knownSource.categoryID == sourceInfo.categoryID
							-- and same Inventory Type
							and (knownSource.invType == sourceInfo.invType
								or sourceInfo.categoryID == 4 --[[CHEST: Robe vs Armor]]
								or app.SlotByInventoryType[knownSource.invType] == app.SlotByInventoryType[sourceInfo.invType])
						then
							-- print("OH NOES! MISSING SOURCE ID ", sourceID, " FOUND THAT YOU HAVE COLLECTED, BUT ATT DOESNT HAVE!!!!");
							return true;
						-- else print(knownSource.sourceID, sourceInfo.sourceID, "share appearances, but one is ", sourceInfo.invType, "and the other is", knownSource.invType, sourceInfo.categoryID);
						end
					end
				end
			end
		end
		return false;
	end
end
local function FilterItemSourceUniqueOnlyMain(sourceInfo, allSources)
	if sourceInfo.isCollected then
		-- NOTE: This makes it so that the loop isn't necessary.
		return true;
	else
		-- If at least one of the sources of this visual ID was collected, that means that we've acquired the base appearance.
		local item = SearchForSourceIDQuickly(sourceInfo.sourceID);
		if item and not item.nmc and not item.nmr then
			-- This item is for my race and class.
			for i, sourceID in ipairs(allSources or C_TransmogCollection_GetAllAppearanceSources(sourceInfo.visualID)) do
				if sourceID ~= sourceInfo.sourceID and C_TransmogCollection_PlayerHasTransmogItemModifiedAppearance(sourceID) then
					local otherItem = SearchForSourceIDQuickly(sourceID);
					if otherItem and (item.f == otherItem.f or item.f == 2 or otherItem.f == 2) and not otherItem.nmc and not otherItem.nmr then
						return true; -- Okay, fine. You are this class/race. Enjoy your +1, cheater. D:
					end
				end
			end
		end
		return false;
	end
end
-- Given a known SourceID, will mark all Shared Visual SourceID's which meet the filter criteria of the known SourceID as 'collected'
local function MarkUniqueCollectedSourcesBySource(knownSourceID, currentCharacterOnly)
	-- Find this source in ATT
	local knownItem = SearchForSourceIDQuickly(knownSourceID);
	if knownItem then
		local knownSource = C_TransmogCollection_GetSourceInfo(knownSourceID);
		local acctSources = ATTAccountWideData.Sources;
		local checkItem, checkSource, valid;
		local knownRaces, knownClasses, knownFaction, knownFilter = knownItem.races, knownItem.c, knownItem.r, knownItem.f;
		local checkFilter;
		-- this source unlocks a visual that the current character may tmog, so all shared visuals should be considered 'collected' regardless of restriction
		local currentCharacterUsable = currentCharacterOnly and not knownItem.nmc and not knownItem.nmr;
		-- For each shared Visual SourceID
		-- if knownSource.visualID == 322 then app.DEBUG_PRINT = true; app.PrintTable(knownSource); end
		-- account cannot collect sourceID? not available for transmog?
		-- local _, canCollect = C_TransmogCollection.AccountCanCollectSource(knownSourceID); -- pointless, always false if sourceID is known
		-- local unknown1 = select(8, C_TransmogCollection.GetAppearanceSourceInfo(knownSourceID)); -- pointless, returns nil for many valid transmogs
		-- Trust that Blizzard returns SourceID's which can actually be used as Transmog for the VisualID
		local visualIDs = C_TransmogCollection_GetAllAppearanceSources(knownSource.visualID);
		local canMog;
		for _,sourceID in ipairs(visualIDs) do
			if sourceID == knownSourceID then
				canMog = true;
				break;
			end
		end
		if not canMog then return; end
		for _,sourceID in ipairs(visualIDs) do
			-- if app.DEBUG_PRINT then print("visualID",knownSource.visualID,"s",sourceID,"known:",rawget(acctSources, sourceID)) end
			-- If it is not currently marked collected on the account
			if not rawget(acctSources, sourceID) then
				-- for current character only, all we care is that the knownItem is not exclusive to another
				-- race/class to consider all shared appearances as 'collected' for the current character
				if currentCharacterUsable then
					-- if app.DEBUG_PRINT then print("current character usable") end
					rawset(acctSources, sourceID, 2);
				else
					-- Find the check Source in ATT
					checkItem = SearchForSourceIDQuickly(sourceID);
					if checkItem then
						-- filter matches or one item is Cosmetic
						checkFilter = checkItem.f;
						if checkFilter == knownFilter or checkFilter == 2 or knownFilter == 2 then
							valid = true;
							-- verify all possible restrictions that the known source may have against restrictions on the source in question
							-- if known source has no equivalent restrictions, then restrictions on the source are irrelevant
							-- Races
							if knownRaces then
								if checkItem.races then
									-- the known source has a race restriction that is not shared by the source in question
									if not containsAny(checkItem.races, knownRaces) then valid = nil; end
								else
									valid = nil;
								end
							end
							-- Classes
							if valid and knownClasses then
								if checkItem.c then
									-- the known source has a class restriction that is not shared by the source in question
									if not containsAny(checkItem.c, knownClasses) then valid = nil; end
								else
									valid = nil;
								end
							end
							-- Faction
							if valid and knownFaction then
								if checkItem.r then
									-- the known source has a faction restriction that is not shared by the source or source races in question
									if knownFaction ~= checkItem.r or (checkItem.races and not containsAny(app.FACTION_RACES[knownFaction], checkItem.races)) then valid = nil; end
								else
									valid = nil;
								end
							end

							-- found a known item which meets all the criteria to grant credit for the source in question
							if valid then
								checkSource = C_TransmogCollection_GetSourceInfo(sourceID);
								-- both sources are the same category (Equip-Type)
								if knownSource.categoryID == checkSource.categoryID
									-- and same Inventory Type
									and (knownSource.invType == checkSource.invType
										or checkSource.categoryID == 4 --[[CHEST: Robe vs Armor]]
										or app.SlotByInventoryType[knownSource.invType] == app.SlotByInventoryType[checkSource.invType])
								then
									-- if app.DEBUG_PRINT then print("Unique Collected s:",sourceID); end
									rawset(acctSources, sourceID, 2);
								-- else print("sources share visual and filters but different equips",item.s,sourceID)
								end
							end
						end
					else
						-- OH NOES! It doesn't exist!
						checkSource = C_TransmogCollection_GetSourceInfo(sourceID);
						-- both sources are the same category (Equip-Type)
						if checkSource.categoryID == knownSource.categoryID
							-- and same Inventory Type
							and (checkSource.invType == knownSource.invType
								or knownSource.categoryID == 4 --[[CHEST: Robe vs Armor]]
								or app.SlotByInventoryType[checkSource.invType] == app.SlotByInventoryType[knownSource.invType])
						then
							-- print("OH NOES! MISSING SOURCE ID ", sourceID, " FOUND THAT YOU HAVE COLLECTED, BUT ATT DOESNT HAVE!!!!");
							rawset(acctSources, sourceID, 2);
						-- else print(knownSource.sourceID, sourceInfo.sourceID, "share appearances, but one is ", sourceInfo.invType, "and the other is", knownSource.invType, sourceInfo.categoryID);
						end
					end
				end
			end
		end
		-- app.DEBUG_PRINT = nil;
	end
end
local function FilterItemTrackable(group)
	return group.trackable;
end
local function ObjectVisibilityFilter(group)
	return group.visible;
end
app.CurrentCharacterFilters = CurrentCharacterFilters;
app.FilterItemSourceUnique = FilterItemSourceUnique;
app.FilterItemSourceUniqueOnlyMain = FilterItemSourceUniqueOnlyMain;
app.MarkUniqueCollectedSourcesBySource = MarkUniqueCollectedSourcesBySource;
app.FilterItemTrackable = FilterItemTrackable;
app.ObjectVisibilityFilter = ObjectVisibilityFilter;
app.FilterItemSource = FilterItemSource;
app.FilterItemClass_CustomCollect = FilterItemClass_CustomCollect;
app.FilterItemClass_RequireFaction = FilterItemClass_RequireFaction;
app.FilterItemClass_RequiredSkill = FilterItemClass_RequiredSkill;
app.FilterItemClass_PetBattles = FilterItemClass_PetBattles;
app.FilterItemClass_PvP = FilterItemClass_PvP;
app.FilterItemClass_RequireBinding = FilterItemClass_RequireBinding;
app.FilterItemClass_UnobtainableItem = FilterItemClass_UnobtainableItem;
app.ItemIsInGame = ItemIsInGame;
app.FilterItemClass_SeasonalItem = FilterItemClass_SeasonalItem;
app.FilterItemClass_RequireRacesCurrentFaction = FilterItemClass_RequireRacesCurrentFaction;
app.FilterItemClass_RequireRaces = FilterItemClass_RequireRaces;
app.FilterItemClass_RequireItemFilter = FilterItemClass_RequireItemFilter;
app.FilterItemClass_RequireClasses = FilterItemClass_RequireClasses;
app.FilterItemClass_IgnoreBoEFilter = FilterItemClass_IgnoreBoEFilter;
app.FilterItemClass = FilterItemClass;
app.FilterItemBind = FilterItemBind;
app.FilterGroupsByCompletion = FilterGroupsByCompletion;
app.FilterGroupsByLevel = FilterGroupsByLevel;
app.IsBoP = IsBoP;
app.NoFilter = NoFilter;
app.Filter = Filter;
end	-- Filtering

-- Default Filter Settings (changed in app.Startup and in the Options Menu)
app.VisibilityFilter = app.ObjectVisibilityFilter;
app.GroupFilter = app.FilterItemClass;
app.GroupRequirementsFilter = app.NoFilter;
app.GroupVisibilityFilter = app.NoFilter;
app.ItemBindFilter = app.FilterItemBind;
app.ItemSourceFilter = app.FilterItemSource;
app.ItemTypeFilter = app.NoFilter;
app.CollectedItemVisibilityFilter = app.NoFilter;
app.ClassRequirementFilter = app.NoFilter;
app.RaceRequirementFilter = app.NoFilter;
app.RequireBindingFilter = app.NoFilter;
app.PvPFilter = app.NoFilter;
app.PetBattleFilter = app.NoFilter;
app.SeasonalItemFilter = app.NoFilter;
app.RequireFactionFilter = app.FilterItemClass_RequireFaction;
app.RequireCustomCollectFilter = app.FilterItemClass_CustomCollect;
app.UnobtainableItemFilter = app.NoFilter;
app.RequiredSkillFilter = app.NoFilter;
app.ShowTrackableThings = app.Filter;
app.DefaultGroupFilter = app.Filter;
app.DefaultThingFilter = app.Filter;

-- Recursive Checks
app.VerifyCache = function()
	if not fieldCache then return false; end
	app.print("VerifyCache Starting...");
	for i,keyCache in pairs(fieldCache) do
		print("Cache",i);
		for k,valueCache in pairs(keyCache) do
			-- print("valueCache",k);
			for o,group in pairs(valueCache) do
				-- print("group",o);
				if not app.VerifyRecursion(group) then
					print("Caused infinite .parent recursion",group.key,group[group.key]);
				end
			end
		end
	end
	app.print("VerifyCache Completed");
end
-- Verify no infinite parent recursion exists for a given group
app.VerifyRecursion = function(group, checked)
	if type(group) ~= "table" then return; end
	if not checked then
		checked = { };
		-- print("test",group.key,group[group.key]);
	end
	for k,o in pairs(checked) do
		if o.key ~= nil and o.key == group.key and o[o.key] == group[group.key] then
			-- print("Infinite .parent Recursion Found:");
			-- print the parent chain to the loop point
			-- for a,b in pairs(checked) do
				-- print(b.key,b[b.key],b,"=>");
			-- end
			-- print(group.key,group[group.key],group);
			-- print("---");
			return;
		end
	end
	if group.parent then
		tinsert(checked, group);
		return app.VerifyRecursion(group.parent, checked);
	end
	return true;
end
-- Recursively check outwards to find if any parent group restricts the filter for this character
app.RecursiveGroupRequirementsFilter = function(group)
	if app.GroupRequirementsFilter(group) and app.GroupFilter(group) then
		local filterParent = group.sourceParent or group.parent;
		if filterParent then
			return app.RecursiveGroupRequirementsFilter(filterParent)
		end
		return true;
	end
	return false;
end
-- Recursively check outwards within the direct parent chain only to find if any parent group restricts the filter for this character
app.RecursiveDirectGroupRequirementsFilter = function(group)
	if app.GroupRequirementsFilter(group) and app.GroupFilter(group) then
		local filterParent = group.parent;
		if filterParent then
			return app.RecursiveGroupRequirementsFilter(filterParent)
		end
		return true;
	end
	return false;
end
app.RecursiveClassAndRaceFilter = function(group)
	if app.ClassRequirementFilter(group) and app.RaceRequirementFilter(group) then
		if group.parent then return app.RecursiveClassAndRaceFilter(group.parent); end
		return true;
	end
	return false;
end
app.RecursiveUnobtainableFilter = function(group)
	if app.UnobtainableItemFilter(group) then
		if group.parent then return app.RecursiveUnobtainableFilter(group.parent); end
		return true;
	end
	return false;
end
-- Returns the first encountered group tracing upwards in parent hierarchy which has a value for the provided field.
-- Specify 'followSource' to prioritize the Source Parent of a group over the direct Parent
app.RecursiveFirstParentWithField = function(group, field, followSource)
	if group then
		return group[field] or app.RecursiveFirstParentWithField(followSource and group.sourceParent or group.parent, field);
	end
end
-- Returns the first encountered group tracing upwards in direct parent hierarchy which has a value for the provided field
app.RecursiveFirstDirectParentWithField = function(group, field)
	if group then
		return group[field] or app.RecursiveFirstDirectParentWithField(rawget(group, "parent"), field);
	end
end
-- Returns the first found recursive Parent of the group which meets the provided field and value combination
app.RecursiveFirstParentWithFieldValue = function(group, field, value)
	if group and field then
		if group[field] == value then
			return group;
		else
			return app.RecursiveFirstParentWithFieldValue(group.parent, field, value);
		end
	end
end
-- Cleans any groups which are nested under 'Source Ignored' content
app.CleanSourceIgnoredGroups = function(groups)
	if groups then
		local parentCheck = app.RecursiveFirstParentWithField;
		local refined = {};
		for _,j in ipairs(groups) do
			if not parentCheck(j, "sourceIgnored") then
				tinsert(refined, j);
			-- else print("  ",j.hash)
			end
		end
		return refined;
	end
end

-- Processing Functions
do
local function SetGroupVisibility(parent, group)
	-- if app.DEBUG_PRINT then print("SetGroupVisibility",group.key,group[group.key]) end
	local forceShowParent;
	-- If this group is forced to be shown due to contained groups being shown
	if group.forceShow then
		group.visible = true;
		group.forceShow = nil;
		-- Continue the forceShow visibility outward
		forceShowParent = true;
		-- if app.DEBUG_PRINT then print("SetGroupVisibility.forceShow",group.progress,group.total,group.visible) end
	-- If this group contains Things, show based on visibility filter
	elseif group.total > 0 then
		group.visible = group.progress < group.total or app.GroupVisibilityFilter(group);
		-- if app.DEBUG_PRINT then print("SetGroupVisibility.total",group.progress,group.total,group.visible) end
		-- The group can still be trackable even if it isn't visible due to the total
		if not group.visible and app.ShowTrackableThings(group) then
			group.visible = not group.saved or app.GroupVisibilityFilter(group);
			forceShowParent = group.visible;
		end
	-- If this group is trackable, then we should show it.
	elseif app.ShowTrackableThings(group) then
		group.visible = not group.saved or app.GroupVisibilityFilter(group);
		forceShowParent = group.visible;
		-- if app.DEBUG_PRINT then print("SetGroupVisibility.trackable",group.progress,group.total,group.visible) end
	else
		group.visible = app.DefaultGroupFilter();
		-- if app.DEBUG_PRINT then print("SetGroupVisibility.default",group.progress,group.total,group.visible) end
	end
	if parent and forceShowParent then
		parent.forceShow = forceShowParent;
	end
end
local function SetThingVisibility(parent, group)
	-- if app.DEBUG_PRINT then print("SetThingVisibility",group.key,group[group.key]) end
	local forceShowParent;
	if group.total > 0 then
		-- If we've collected the item, use the "Show Collected Items" filter.
		group.visible = group.progress < group.total or app.CollectedItemVisibilityFilter(group);
		-- if app.DEBUG_PRINT then print("SetThingVisibility.total",group.progress,group.total,group.visible) end
	elseif app.ShowTrackableThings(group) then
		-- If this group is trackable, then we should show it.
		group.visible = not group.saved or app.CollectedItemVisibilityFilter(group);
		forceShowParent = group.visible;
		-- if app.DEBUG_PRINT then print("SetThingVisibility.trackable",group.progress,group.total,group.visible) end
	else
		group.visible = app.DefaultThingFilter();
		-- if app.DEBUG_PRINT then print("SetThingVisibility.default",group.progress,group.total,group.visible) end
	end
	if parent and forceShowParent then
		parent.forceShow = forceShowParent;
	end
end
local UpdateGroups;
local function UpdateGroup(parent, group)
	-- if group.key == "runeforgePowerID" and group[group.key] == 134 then app.DEBUG_PRINT = 134; end
	-- if not app.DEBUG_PRINT and shouldLog then
	-- 	app.DEBUG_PRINT = shouldLog;
	-- end

	-- -- Only update a group ONCE per update cycle...
	-- if not group._Updated or group._Updated ~= app._Updated then
	-- 	if LOG then print("First Update") end
	-- 	group._Updated = app._Updated;
	-- else
	-- 	-- group has already updated on this pass
	-- 	if LOG then print("Skip Update") end
	-- 	-- print("Skip Update",app._Updated,group.key,group.key and group[group.key],"t/p/v",group.total,group.progress,group.visible)
	-- 	-- Increment the parent group's totals.
	-- 	parent.total = (parent.total or 0) + (group.total or 0);
	-- 	parent.progress = (parent.progress or 0) + (group.progress or 0);
	-- 	return group.visible;
	-- end

	group.visible = nil;
	-- if app.DEBUG_PRINT then print("UpdateGroup",group.key,group.key and group[group.key],group.__type) end
	-- Determine if this user can enter the instance or acquire the item and item is equippable/usable
	local valid;
	-- A group with a source parent means it has a different 'real' heirarchy than in the current window
	-- so need to verify filtering based on that instead of only itself
	if group.sourceParent then
		valid = app.RecursiveGroupRequirementsFilter(group);
	else
		valid = app.GroupRequirementsFilter(group) and app.GroupFilter(group);
	end

	if valid then
		-- if app.DEBUG_PRINT then print("UpdateGroup.GroupRequirementsFilter",group.key,group.key and group[group.key],group.__type) end
		-- if app.DEBUG_PRINT then print("UpdateGroup.GroupFilter",group.key,group.key and group[group.key],group.__type) end
		-- Set total/progress for this object using its cost/custom information if any
		local costTotal = group.costTotal or 0;
		local costProgress = costTotal > 0 and group.costProgress or 0;
		local customTotal = group.customTotal or 0;
		local customProgress = customTotal > 0 and group.customProgress or 0;
		local total, progress = costTotal + customTotal, costProgress + customProgress;

		-- if app.DEBUG_PRINT then print("UpdateGroup.Initial",group.key,group.key and group[group.key],group.progress,group.total,group.__type) end

		-- If this item is collectible, then mark it as such.
		if group.collectible then
			total = total + 1;
			if group.collected then
				progress = progress + 1;
			end
		end

		-- Set the total/progress on the group
		group.progress = progress;
		group.total = total;

		-- Check if this is a group
		local g = group.g;
		if g then
			-- if app.DEBUG_PRINT then print("UpdateGroup.g",group.progress,group.total,group.__type) end

			-- skip Character filtering for sub-groups if this Item meets the Ignore BoE filter logic, since it can be moved to the designated character
			local ItemBindFilter, NoFilter = app.ItemBindFilter, app.NoFilter;
			if ItemBindFilter ~= NoFilter and ItemBindFilter(group) then
				app.ItemBindFilter = NoFilter;
				-- Update the subgroups recursively...
				UpdateGroups(group, g);
				-- reapply the previous BoE filter
				app.ItemBindFilter = ItemBindFilter;
			else
				UpdateGroups(group, g);
			end

			-- if app.DEBUG_PRINT then print("UpdateGroup.g.Updated",group.progress,group.total,group.__type) end
			SetGroupVisibility(parent, group);
		else
			SetThingVisibility(parent, group);
		end

		-- Increment the parent group's totals if the group is not ignored for sources
		if not group.sourceIgnored then
			parent.total = (parent.total or 0) + group.total;
			parent.progress = (parent.progress or 0) + group.progress;
		else
			-- source ignored group which is determined to be visible should ensure the parent is also visible
			if group.visible then
				parent.forceShow = true;
				-- app.PrintDebug("Force Show Parent",parent.text,"via incomplete Source Ignored",group.text)
			end
			-- print("Ignoring progress/total",group.progress,"/",group.total,"for group",group.text)
		end
	end

	-- if app.DEBUG_PRINT then print("UpdateGroup.Done",group.progress,group.total,group.visible,group.__type) end
	-- if app.DEBUG_PRINT == 134 then app.DEBUG_PRINT = nil; end
end
app.UpdateGroup = UpdateGroup;
UpdateGroups = function(parent, g)
	if g then
		for _,group in ipairs(g) do
			if group.OnUpdate then
				if not group:OnUpdate() then
					UpdateGroup(parent, group);
				elseif group.visible then
					group.total = nil;
					group.progress = nil;
					UpdateGroups(group, group.g);
				end
			else
				UpdateGroup(parent, group);
			end
		end
	end
end
app.UpdateGroups = UpdateGroups;
-- Adjusts the progress/total of the group's parent chain
local function AdjustParentProgress(group, progChange, totalChange)
	-- rawget, .parent will default to sourceParent in some cases
	local parent = group and not group.sourceIgnored and rawget(group, "parent");
	if parent then
		-- app.PrintDebug("APP:",parent.text)
		-- app.PrintDebug("CUR:",parent.progress,parent.total)
		-- app.PrintDebug("CHG:",progChange,totalChange)
		parent.total = (parent.total or 0) + totalChange;
		parent.progress = (parent.progress or 0) + progChange;
		-- app.PrintDebug("END:",parent.progress,parent.total)
		-- verify visibility of the group, always a 'group' since it is already a parent of another group, as long as it's not the root window data
		if not parent.window then
			SetGroupVisibility(rawget(parent, "parent"), parent);
		end
		AdjustParentProgress(parent, progChange, totalChange);
	end
end
-- For directly applying the full Update operation for the top-level data group within a window
local function TopLevelUpdateGroup(group)
	group.total = 0;
	group.progress = 0;
	local ItemBindFilter = app.ItemBindFilter;
	if ItemBindFilter ~= app.NoFilter and ItemBindFilter(group) then
		app.ItemBindFilter = app.NoFilter;
		UpdateGroups(group, group.g);
		-- reapply the previous BoE filter
		app.ItemBindFilter = ItemBindFilter;
	else
		UpdateGroups(group, group.g);
	end
	if group.collectible then
		group.total = group.total + 1;
		if group.collected then
			group.progress = group.progress + 1;
		end
	end
	if group.OnUpdate then group.OnUpdate(group); end
end
app.TopLevelUpdateGroup = TopLevelUpdateGroup;
-- For directly applying the full Update operation at the specified group, and propagating the difference upwards in the parent hierarchy,
-- then triggering a 1/2 second delayed soft-update of the Window containing the group if any. 'got' indicates that this group was 'gotten'
-- and was the cause for the update
local function DirectGroupUpdate(group, got)
	-- starting an update from a non-top-level group means we need to verify this group should even handle updates based on current filters first
	if not app.RecursiveDirectGroupRequirementsFilter(group) then
		-- app.PrintDebug("DGU:Filtered",group.hash,group.parent.text)
		return;
	end
	local prevTotal, prevProg = group.total or 0, group.progress or 0;
	group.total = 0;
	group.progress = 0;
	local ItemBindFilter = app.ItemBindFilter;
	if ItemBindFilter ~= app.NoFilter and ItemBindFilter(group) then
		app.ItemBindFilter = app.NoFilter;
		UpdateGroups(group, group.g);
		-- reapply the previous BoE filter
		app.ItemBindFilter = ItemBindFilter;
	else
		UpdateGroups(group, group.g);
	end
	if group.collectible then
		group.total = group.total + 1;
		if group.collected then
			group.progress = group.progress + 1;
		end
	end
	if group.OnUpdate then group.OnUpdate(group); end
	-- Set proper visibility for the updated group
	local parent = rawget(group, "parent");
	if group.g then
		SetGroupVisibility(parent, group);
	else
		SetThingVisibility(parent, group);
	end
	local progChange, totalChange = group.progress - prevProg, group.total - prevTotal;
	-- Something to change
	if progChange ~= 0 or totalChange ~= 0 then
		AdjustParentProgress(group, progChange, totalChange);
	end
	-- After completing the Direct Update, setup a soft-update on the affected Window, if any
	local window = app.RecursiveFirstDirectParentWithField(group, "window");
	if window then
		-- app.PrintDebug("DGU:Callback Update",group.hash,">",window.Suffix,window.Update,window.isQuestChain)
		DelayedCallback(window.Update, 0.5, window, window.isQuestChain, got);
	end
end
app.DirectGroupUpdate = DirectGroupUpdate;
end -- Processing Functions

-- Helper Methods
-- The following Helper Methods are used when you obtain a new appearance.
function app.CompletionistItemCollectionHelper(sourceID, oldState)
	-- Get the source info for this source ID.
	local sourceInfo = C_TransmogCollection_GetSourceInfo(sourceID);
	if sourceInfo then
		-- Search ATT for the related sources.
		local searchResults = SearchForField("s", sourceID);
		-- Show the collection message.
		if app.IsReady and app.Settings:GetTooltipSetting("Report:Collected") then
			if searchResults and #searchResults > 0 then
				local firstMatch = searchResults[1];
				print(format(L["ITEM_ID_ADDED"], firstMatch.text or ("|cffff80ff|Htransmogappearance:" .. sourceID .. "|h[Source " .. sourceID .. "]|h|r"), firstMatch.itemID));
			else
				-- Use the Blizzard API... We don't have this item in the addon.
				-- NOTE: The itemlink that gets passed is BASE ITEM LINK, not the full item link.
				-- So this may show green items where an epic was obtained. (particularly with Legion drops)
				-- This is okay since items of this type share their appearance regardless of the power of the item.
				local name, link = GetItemInfo(sourceInfo.itemID);

				print(format(L["ITEM_ID_ADDED_MISSING"], link or name or ("|cffff80ff|Htransmogappearance:" .. sourceID .. "|h[Source " .. sourceID .. "]|h|r"), sourceInfo.itemID));

				-- Play a sound when a reportable error is found, if any sound setting is enabled
				app:PlayReportSound();
			end
			Callback(app.PlayFanfare);
			Callback(app.TakeScreenShot, "Transmog");
		end

		-- Update the groups for the sourceID results
		UpdateSearchResults(searchResults);
	end
end
function app.UniqueModeItemCollectionHelperBase(sourceID, oldState, filter)
	-- Get the source info for this source ID.
	local sourceInfo = C_TransmogCollection_GetSourceInfo(sourceID);
	if sourceInfo then
		-- Go through all of the shared appearances and see if we've "unlocked" any of them.
		local unlockedSourceIDs, allSources = { sourceID }, C_TransmogCollection_GetAllAppearanceSources(sourceInfo.visualID);
		for _,otherSourceID in ipairs(allSources) do
			-- If this isn't the source we already did work on and we haven't already completed it
			if otherSourceID ~= sourceID and not ATTAccountWideData.Sources[otherSourceID] then
				local otherSourceInfo = C_TransmogCollection_GetSourceInfo(otherSourceID);
				if otherSourceInfo and filter(otherSourceInfo, allSources) then
					ATTAccountWideData.Sources[otherSourceID] = otherSourceInfo.isCollected and 1 or 2;
					tinsert(unlockedSourceIDs, otherSourceID);
				end
			end
		end

		-- only consider new SourceID as unlocking all shared appearances, otherwise it only unlocks additional appearances
		-- (i.e. current item was collected in Main Only due to alternate piece, but then learning the raw item itself or something... idk)
		local newAppearancesLearned = oldState == 0 and #unlockedSourceIDs or (#unlockedSourceIDs - 1);

		-- Show the collection message if learning this Source actually contributed as a new Unique appearance
		if app.IsReady and app.Settings:GetTooltipSetting("Report:Collected") then
			-- Search for the item that actually was unlocked.
			local searchResults = SearchForField("s", sourceID);
			if searchResults and #searchResults > 0 then
				local firstMatch = searchResults[1];
				print(format(L[newAppearancesLearned > 0 and "ITEM_ID_ADDED_SHARED" or "ITEM_ID_ADDED"],
					firstMatch.text or ("|cffff80ff|Htransmogappearance:" .. sourceID .. "|h[Source " .. sourceID .. "]|h|r"), firstMatch.itemID, newAppearancesLearned));
			else
				-- Use the Blizzard API... We don't have this item in the addon.
				-- NOTE: The itemlink that gets passed is BASE ITEM LINK, not the full item link.
				-- So this may show green items where an epic was obtained. (particularly with Legion drops)
				-- This is okay since items of this type share their appearance regardless of the power of the item.
				local name, link = GetItemInfo(sourceInfo.itemID);

				print(format(L[newAppearancesLearned > 0 and "ITEM_ID_ADDED_SHARED_MISSING" or "ITEM_ID_ADDED_MISSING"], link or name or ("|cffff80ff|Htransmogappearance:" .. sourceID .. "|h[Source " .. sourceID .. "]|h|r"), sourceInfo.itemID, newAppearancesLearned));

				-- Play a sound when a reportable error is found, if any sound setting is enabled
				app:PlayReportSound();
			end
			Callback(app.PlayFanfare);
			Callback(app.TakeScreenShot, "Transmog");
		end

		-- Update the groups for the sourceIDs
		UpdateRawIDs("s", unlockedSourceIDs);
	end
end
function app.UniqueModeItemCollectionHelper(sourceID, oldState)
	return app.UniqueModeItemCollectionHelperBase(sourceID, oldState, app.FilterItemSourceUnique);
end
function app.UniqueModeItemCollectionHelperOnlyMain(sourceID, oldState)
	return app.UniqueModeItemCollectionHelperBase(sourceID, oldState, app.FilterItemSourceUniqueOnlyMain);
end
app.ActiveItemCollectionHelper = app.CompletionistItemCollectionHelper;

function app.GetNumberOfItemsUntilNextPercentage(progress, total)
	if total <= progress then
		return "|c" .. GetProgressColor(1) .. L["YOU_DID_IT"];
	else
		local originalPercent = progress / total;
		local nextPercent = math.ceil(originalPercent * 100);
		local roundedPercent = nextPercent * 0.01;
		local diff = math.ceil(total * (roundedPercent - originalPercent));
		if diff < 1 or nextPercent == 100 then
			return "|c" .. GetProgressColor(1) .. (total - progress) .. L["THINGS_UNTIL"] .. "100%|r";
		elseif diff == 1 then
			return "|c" .. GetProgressColor(roundedPercent) .. diff .. L["THING_UNTIL"] .. nextPercent .. "%|r";
		else
			return "|c" .. GetProgressColor(roundedPercent) .. diff .. L["THINGS_UNTIL"] .. nextPercent .. "%|r";
		end
	end
end

-- Custom Collectibility
do
local SLCovenantId;
local CCFuncs = {
	["NPE"] = function()
		-- needs mapID to check this
		if not app.GetCurrentMapID() then return; end
		-- print("first check");
		-- check if the current MapID is in Exile's Reach
		local maps = { [1409] = 1, [1609] = 1, [1610] = 1, [1611] = 1, [1726] = 1, [1727] = 1 };
		-- print("map check",app.CurrentMapID);
		-- this is an NPE character, so flag the GUID
		if maps[app.CurrentMapID] then
			-- print("on map");
			return true;
		-- if character has completed the first NPE quest
		elseif ((IsQuestFlaggedCompleted(56775) or IsQuestFlaggedCompleted(59926))
				-- but not finished the NPE chain
				and not (IsQuestFlaggedCompleted(60359) or IsQuestFlaggedCompleted(58911))) then
			-- print("incomplete NPE chain");
			return true;
		end
		-- otherwise character is not NPE
		return false;
	end,
	["SL_SKIP"] = function()
		-- check if quest #62713 is completed. appears to be a HQT concerning whether the character has chosen to skip the SL Storyline
		return IsQuestFlaggedCompleted(62713) or false;
	end,
	["HOA"] = function()
		-- check if quest #51211 is completed. Rewards the HoA to the player and permanently switches all possible Azerite rewards
		local hoa = IsQuestFlaggedCompleted(51211) or false;
		-- also store the opposite of HOA for easy checks on Azewrong gear
		app.CurrentCharacter.CustomCollects["~HOA"] = not hoa;
		-- for now, always assume both HoA qualifications are true so they do not filter
		app.ActiveCustomCollects["~HOA"] = true; -- not hoa;
		return true; -- hoa;
	end,
	["SL_COV_KYR"] = function()
		return SLCovenantId == 1 or SLCovenantId == 0;
	end,
	["SL_COV_VEN"] = function()
		return SLCovenantId == 2 or SLCovenantId == 0;
	end,
	["SL_COV_NFA"] = function()
		return SLCovenantId == 3 or SLCovenantId == 0;
	end,
	["SL_COV_NEC"] = function()
		return SLCovenantId == 4 or SLCovenantId == 0;
	end,
};

-- receives a key and a function which returns the value to be set for
-- that key based on the current value and current character
local function SetCustomCollectibility(key, func)
	-- print("SetCustomCollectibility",key);
	func = func or CCFuncs[key];
	local result = func();
	if result ~= nil then
		-- app.PrintDebug("SetCustomCollectibility",key,result);
		app.CurrentCharacter.CustomCollects[key] = result;
		app.ActiveCustomCollects[key] = result or app.Settings:Get("CC:"..key);
	else
		-- failed attempt to set the CC, try next frame
		-- app.PrintDebug("SetCustomCollectibility-Fail",key);
		Callback(SetCustomCollectibility, key, func);
	end
end
-- determines whether an object may be considered collectible for the current character based on the 'customCollect' value(s)
app.CheckCustomCollects = function(t)
	-- no customCollect, or Account/Debug mode then disregard
	if app.MODE_DEBUG_OR_ACCOUNT or not t.customCollect then return true; end
	local cc = app.ActiveCustomCollects;
	for _,c in ipairs(t.customCollect) do
		if not cc[c] then
			return false;
		end
	end
	return true;
end
-- Performs the necessary checks to determine any 'customCollect' settings the current character should have applied
app.RefreshCustomCollectibility = function()
	-- print("RefreshCustomCollectibility",app.IsReady)
	if not app.IsReady then
		Callback(app.RefreshCustomCollectibility);
		return;
	end

	-- clear existing custom collects
	wipe(app.ActiveCustomCollects);

	-- do one-time per character custom visibility check(s)
	-- Exile's Reach (New Player Experience)
	SetCustomCollectibility("NPE");
	-- Shadowlands Skip
	SetCustomCollectibility("SL_SKIP");
	-- Heart of Azeroth
	SetCustomCollectibility("HOA");

	-- print("Current Covenant",SLCovenantId);
	-- Show all Covenants if not yet selected
	SLCovenantId = C_Covenants.GetActiveCovenantID();
	-- Shadowlands Covenant: Kyrian
	SetCustomCollectibility("SL_COV_KYR");
	-- Shadowlands Covenant: Venthyr
	SetCustomCollectibility("SL_COV_VEN");
	-- Shadowlands Covenant: Night Fae
	SetCustomCollectibility("SL_COV_NFA");
	-- Shadowlands Covenant: Necrolord
	SetCustomCollectibility("SL_COV_NEC");
end
end	-- Custom Collectibility

local function MinimapButtonOnClick(self, button)
	if button == "RightButton" then
		app.Settings:Open();
	else
		-- Left Button
		if IsShiftKeyDown() then
			app.RefreshCollections();
		elseif IsAltKeyDown() or IsControlKeyDown() then
			app.ToggleMiniListForCurrentZone();
		else
			app.ToggleMainList();
		end
	end
end
local function MinimapButtonOnEnter(self)
	local reference = app:GetDataCache();
	GameTooltip:SetOwner(self, "ANCHOR_LEFT");
	GameTooltip:ClearLines();
	GameTooltip:AddDoubleLine(reference.text, GetProgressColorText(reference.progress, reference.total));
	GameTooltip:AddDoubleLine(reference.mb_title1, reference.mb_title2, 1, 1, 1);
	GameTooltip:AddLine(L["DESCRIPTION"], 0.4, 0.8, 1, 1);
	GameTooltip:AddLine(L["MINIMAP_MOUSEOVER_TEXT"], 1, 1, 1);
	GameTooltip:Show();
	GameTooltipIcon:SetSize(72,72);
	GameTooltipIcon:ClearAllPoints();
	GameTooltipIcon:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", 0, 0);
	GameTooltipIcon.icon:SetTexture(reference.preview or reference.icon);
	local texcoord = reference.previewtexcoord or reference.texcoord;
	if texcoord then
		GameTooltipIcon.icon:SetTexCoord(texcoord[1], texcoord[2], texcoord[3], texcoord[4]);
	else
		GameTooltipIcon.icon:SetTexCoord(0, 1, 0, 1);
	end
	GameTooltipIcon:Show();
end
local function MinimapButtonOnLeave()
	GameTooltip:Hide();
	GameTooltipIcon.icon.Background:Hide();
	GameTooltipIcon.icon.Border:Hide();
	GameTooltipIcon:Hide();
	GameTooltipModel:Hide();
end
local function CreateMinimapButton()
	-- Create the Button for the Minimap frame. Create a local and non-local copy.
	local size = app.Settings:GetTooltipSetting("MinimapSize");
	local button = CreateFrame("BUTTON", app:GetName() .. "-Minimap", Minimap);
	button:SetPoint("CENTER", 0, 0);
	button:SetFrameStrata("HIGH");
	button:SetMovable(true);
	button:EnableMouse(true);
	button:RegisterForDrag("LeftButton", "RightButton");
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp");
	button:SetSize(size, size);

	-- Create the Button Texture
	local texture = button:CreateTexture(nil, "BACKGROUND");
	texture:SetATTSprite("base_36x36", 429, 217, 36, 36, 512, 256);
	--texture:SetATTSprite("in_game_logo", 430, 75, 53, 59, 512, 256);
	--texture:SetScale(53 / 64, 59 / 64);
	texture:SetPoint("CENTER", 0, 0);
	texture:SetAllPoints();
	button.texture = texture;

	-- Create the Button Texture
	local oldtexture = button:CreateTexture(nil, "BACKGROUND");
	oldtexture:SetPoint("CENTER", 0, 0);
	oldtexture:SetTexture(L["LOGO_SMALL"]);
	oldtexture:SetSize(21, 21);
	oldtexture:SetTexCoord(0,1,0,1);
	button.oldtexture = oldtexture;

	-- Create the Button Tracking Border
	local border = button:CreateTexture(nil, "BORDER");
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder");
	border:SetPoint("CENTER", 12, -12);
	border:SetSize(56, 56);
	button.border = border;
	button.UpdateStyle = function(self)
		if app.Settings:GetTooltipSetting("MinimapStyle") then
			self:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD");
			self:GetHighlightTexture():SetTexCoord(0,1,0,1);
			self:GetHighlightTexture():SetAlpha(1);
			self.texture:Hide();
			self.oldtexture:Show();
			self.border:Show();
		else
			self:SetATTHighlightSprite("epic_36x36", 297, 215, 36, 36, 512, 256):SetAlpha(0.2);
			self.texture:Show();
			self.oldtexture:Hide();
			self.border:Hide();
		end
	end
	button:UpdateStyle();

	-- Button Configuration
	local radius = 100;
	local rounding = 10;
	local MinimapShapes = {
		-- quadrant booleans (same order as SetTexCoord)
		-- {bottom-right, bottom-left, top-right, top-left}
		-- true = rounded, false = squared
		["ROUND"] 			= {true,  true,  true,  true },
		["SQUARE"] 			= {false, false, false, false},
		["CORNER-TOPLEFT"] 		= {false, false, false, true },
		["CORNER-TOPRIGHT"] 		= {false, false, true,  false},
		["CORNER-BOTTOMLEFT"] 		= {false, true,  false, false},
		["CORNER-BOTTOMRIGHT"]	 	= {true,  false, false, false},
		["SIDE-LEFT"] 			= {false, true,  false, true },
		["SIDE-RIGHT"] 			= {true,  false, true,  false},
		["SIDE-TOP"] 			= {false, false, true,  true },
		["SIDE-BOTTOM"] 		= {true,  true,  false, false},
		["TRICORNER-TOPLEFT"] 		= {false, true,  true,  true },
		["TRICORNER-TOPRIGHT"] 		= {true,  false, true,  true },
		["TRICORNER-BOTTOMLEFT"] 	= {true,  true,  false, true },
		["TRICORNER-BOTTOMRIGHT"] 	= {true,  true,  true,  false},
	};
	button.update = function(self)
		local position = GetDataMember("Position", -10.31);
		local angle = math.rad(position) -- determine position on your own
		local x, y
		local cos = math.cos(angle)
		local sin = math.sin(angle)
		local q = 1;
		if cos < 0 then
			q = q + 1;	-- lower
		end
		if sin > 0 then
			q = q + 2;	-- right
		end
		if MinimapShapes[GetMinimapShape and GetMinimapShape() or "ROUND"][q] then
			x = cos*radius;
			y = sin*radius;
		else
			local diagRadius = math.sqrt(2*(radius)^2)-rounding
			x = math.max(-radius, math.min(cos*diagRadius, radius))
			y = math.max(-radius, math.min(sin*diagRadius, radius))
		end
		self:SetPoint("CENTER", "Minimap", "CENTER", -x, y);
	end
	local update = function(self)
		local w, x = GetCursorPosition();
		local y, z = Minimap:GetLeft(), Minimap:GetBottom();
		local s = UIParent:GetScale();
		w = y - w / s + 70; x = x / s - z - 70;
		SetDataMember("Position", math.deg(math.atan2(x, w)));
		self:Raise();
		self:update();
	end

	-- Register for Frame Events
	button:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", update);
	end);
	button:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil);
	end);
	button:SetScript("OnEnter", MinimapButtonOnEnter);
	button:SetScript("OnLeave", MinimapButtonOnLeave);
	button:SetScript("OnClick", MinimapButtonOnClick);
	button:update();
	button:Show();
	return button;
end
app.CreateMinimapButton = CreateMinimapButton;
function app:CreateMiniListForGroup(group)
	-- Pop Out Functionality! :O
	local suffix = BuildSourceTextForChat(group, 1)
		-- this portion is to ensure that custom slash command popouts have a unique name based on the stand-alone group (no parent)
		.. " > " .. (group.text or "") .. (group.key or "NO_KEY") .. (group.key and group[group.key] or "NO_KEY_VAL")
		..(app.RecursiveFirstParentWithField(group, "dynamic") or "");
	local popout = app.Windows[suffix];
	local showing = not popout or not popout:IsVisible();
	-- force data to be re-collected if this is a quest chain since its logic is affected by settings
	if group.questID or group.sourceQuests then popout = nil; end
	-- app.PrintDebug("Popout for",suffix,"showing?",showing)
	if not popout then
		popout = app:GetWindow(suffix);
		-- make a search for this group if it is an item/currency/achievement and not already a container for things
		if not group.g and not group.criteriaID and (group.itemID or group.currencyID or group.achievementID) then
			local cmd = group.link or group.key .. ":" .. group[group.key];
			app.SetSkipPurchases(2);
			group = GetCachedSearchResults(cmd, SearchForLink, cmd);
			app.SetSkipPurchases(0);
		end

		-- clone/search initially so as to not let popout operations modify the source data
		group = CreateObject(group);
		-- Insert the data group into the Raw Data table.
		popout:SetData(group);

		-- being a search result means it has already received certain processing
		if not group.isBaseSearchResult then
			app.SetSkipPurchases(2);
			app.FillGroups(group);
			app.SetSkipPurchases(0);
		end
		-- This logic allows for nested searches of groups within a popout to be returned as the root search which resets the parent
		-- if not group.isBaseSearchResult then
		-- 	-- make a search for this group if it is an item/currency and not already a container for things
		-- 	if not group.g and (group.itemID or group.currencyID) then
		-- 		local cmd = group.key .. ":" .. group[group.key];
		-- 		group = GetCachedSearchResults(cmd, SearchForLink, cmd);
		-- 	else
		-- 		group = CloneData(group);
		-- 	end
		-- end
		-- if popping out a thing with a sourced parent, generate a Source group to allow referencing the Source of the thing directly
		app.BuildSourceParent(group);
		-- if popping out a thing with a Cost, generate a Cost group to allow referencing the Cost things directly
		app.BuildCost(group);

		-- TODO: Crafting Information
		-- TODO: Lock Criteria

		-- custom Update method for the popout so we don't have to force refresh
		popout.Update = function(self, force, got)
			-- app.PrintDebug("Update.ExpireTime", self.Suffix, force, got)
			-- mark the popout to expire after 5 min from now if it is visible
			if self:IsVisible() then
				self.ExpireTime = time() + 300;
				-- app.PrintDebug("Expire Refreshed",popout.Suffix)
			end
			self:BaseUpdate(force or got, got);
		end
		-- popping out something without a source, try to determine it on-the-fly using same logic as harvester
		-- TODO: modify parser to include known sources for unsorted before commenting this back in
		-- if not group.s or group.s == 0 then
		-- 	local s, dressable = GetSourceID(group.text, group.itemID);
		-- 	if dressable and s and s > 0 then
		-- 		app.report("Item",group.itemID,group.modID,"is missing SourceID",s);
		-- 		group.s = s;
		-- 	end
		-- end
		-- Create groups showing Appearance information
		if group.s then
			-- print(group.__type)
			-- app.PrintGroup(group)
			-- source without an item, try to generate the valid item link for it
			if not group.itemID and not group.artifactID then
				app.ImportRawLink(group, app.DetermineItemLink(group.s));
				-- if we found a Item link, save it into ATTHarvestItems for ease of use (don't need to add Item, parse, Havrest, add harvest, parse)
				app.SaveHarvestSource(group);
			end
			-- Attempt to get information about the source ID.
			local sourceInfo = C_TransmogCollection_GetSourceInfo(group.s);
			if sourceInfo then
				-- print("Source Info on popout")
				-- app.PrintTable(sourceInfo)
				-- Show a list of all of the Shared Appearances.
				local g = {};
				-- Go through all of the shared appearances and see if we've "unlocked" any of them.
				for _,otherSourceID in ipairs(C_TransmogCollection_GetAllAppearanceSources(sourceInfo.visualID)) do
					-- If this isn't the source we already did work on and we haven't already completed it
					if otherSourceID ~= group.s then
						local shared = app.SearchForMergedObject("s", otherSourceID);
						if shared then
							shared = CreateObject(shared, true);
							shared.hideText = true;
							tinsert(g, shared);
							-- print("ATT Appearance:",shared.hash,shared.modItemID)
						else
							local otherSourceInfo = C_TransmogCollection_GetSourceInfo(otherSourceID);
							-- print("Missing Appearance")
							-- app.PrintTable(otherSourceInfo)
							if otherSourceInfo then
								-- TODO: this can create an item link whose appearance is actually different than the SourceID's Visual
								local newItem = app.CreateItemSource(otherSourceID, otherSourceInfo.itemID);
								newItem.collectible = (otherSourceInfo.quality or 0) > 1;
								if otherSourceInfo.isCollected then
									ATTAccountWideData.Sources[otherSourceID] = 1;
									newItem.collected = true;
								end
								tinsert(g, newItem);
							end
						end
					end
				end
				local appearanceGroup;
				if #g > 0 then
					appearanceGroup = {
						["text"] = L["SHARED_APPEARANCES_LABEL"],
						["description"] = L["SHARED_APPEARANCES_LABEL_DESC"],
						["icon"] = "Interface\\Icons\\Achievement_GarrisonFollower_ItemLevel650.blp",
						["g"] = g,
						["OnUpdate"] = app.AlwaysShowUpdate,
						["sourceIgnored"] = true,
					};
				else
					appearanceGroup = {
						["text"] = L["UNIQUE_APPEARANCE_LABEL"],
						["description"] = L["UNIQUE_APPEARANCE_LABEL_DESC"],
						["icon"] = "Interface\\Icons\\ACHIEVEMENT_GUILDPERK_EVERYONES A HERO.blp",
						["OnUpdate"] = app.AlwaysShowUpdate,
						["sourceIgnored"] = true,
					};
				end
				-- add the group showing the Appearance information for this popout
				if group.g then tinsert(group.g, appearanceGroup)
				else group.g = { appearanceGroup } end
			end

			-- Determine if this source is part of a set or two.
			local allSets = {};
			local sourceSets = {};
			local GetVariantSets = C_TransmogSets.GetVariantSets;
			local GetAllSourceIDs = C_TransmogSets.GetAllSourceIDs;
			for i,data in ipairs(C_TransmogSets.GetAllSets()) do
				local sources = GetAllSourceIDs(data.setID);
				if #sources > 0 then allSets[data.setID] = sources; end
				for j,sourceID in ipairs(sources) do
					local s = sourceSets[sourceID];
					if not s then
						s = {};
						sourceSets[sourceID] = s;
					end
					s[data.setID] = 1;
				end
				local variants = GetVariantSets(data.setID);
				if type(variants) == "table" then
					for j,data in ipairs(variants) do
						local sources = GetAllSourceIDs(data.setID);
						if #sources > 0 then allSets[data.setID] = sources; end
						for k, sourceID in ipairs(sources) do
							local s = sourceSets[sourceID];
							if not s then
								s = {};
								sourceSets[sourceID] = s;
							end
							s[data.setID] = 1;
						end
					end
				end
			end
			local data, g = sourceSets[group.s];
			if data then
				for setID,value in pairs(data) do
					g = {};
					setID = tonumber(setID);
					for _,sourceID in ipairs(allSets[setID]) do
						local search = app.SearchForMergedObject("s", sourceID);
						if search then
							search = CreateObject(search, true);
							search.hideText = true;
							tinsert(g, search);
						else
							local otherSourceInfo = C_TransmogCollection_GetSourceInfo(sourceID);
							if otherSourceInfo and (otherSourceInfo.quality or 0) > 1 then
								-- TODO: this can create an item link whose appearance is actually different than the SourceID's Visual
								local newItem = app.CreateItemSource(sourceID, otherSourceInfo.itemID);
								if otherSourceInfo.isCollected then
									ATTAccountWideData.Sources[sourceID] = 1;
									newItem.collected = true;
								end
								tinsert(g, newItem);
							end
						end
					end
					-- add the group showing the related Set information for this popout
					if not group.g then group.g = { app.CreateGearSet(setID, { ["OnUpdate"] = app.AlwaysShowUpdate, ["sourceIgnored"] = true, ["g"] = g }) }
					else tinsert(group.g, app.CreateGearSet(setID, { ["OnUpdate"] = app.AlwaysShowUpdate, ["sourceIgnored"] = true, ["g"] = g })) end
				end
			end
		end
		if showing and ((group.key == "questID" and group.questID) or group.sourceQuests) then
			-- if the group was created from a popout and thus contains its own pre-req quests already, then clean out direct quest entries from the group
			if group.g then
				local noQuests = {};
				for _,g in pairs(group.g) do
					if g.key ~= "questID" then
						tinsert(noQuests, g);
					end
				end
				group.g = noQuests;
			end
			-- Create a copy of the root group
			local root = CreateObject(group);
			local g = { root };
			popout.isQuestChain = true;

			-- Check to see if Source Quests are listed elsewhere.
			if group.questID and not group.sourceQuests then
				local questID = group.questID;
				local qs = SearchForField("questID", group.questID);
				if qs and #qs > 1 then
					local i, sq = #qs;
					while not sq and i > 0 do
						-- found another group with this questID that has sourceQuests listed
						if qs[i].questID == questID and qs[i].sourceQuests then sq = qs[i]; end
						i = i - 1;
					end
					if sq then
						root = CloneData(sq);
						root.g = g;
						g = { root };
					end
				end
			end

			-- Show Quest Prereqs
			if root.sourceQuests then
				-- local gTop;
				local useNested = app.Settings:GetTooltipSetting("QuestChain:Nested");
				if useNested then
					-- clean out the sub-groups of the root since it will be listed at the top of the popout
					-- root.g = nil;
					-- gTop = app.NestSourceQuests(root).g or {};
				else
					local sourceQuests, sourceQuest, subSourceQuests, prereqs = root.sourceQuests;
					local addedQuests = {};
					while sourceQuests and #sourceQuests > 0 do
						subSourceQuests = {}; prereqs = {};
						for i,sourceQuestID in ipairs(sourceQuests) do
							if not addedQuests[sourceQuestID] then
								addedQuests[sourceQuestID] = true;
								local qs = sourceQuestID < 1 and SearchForField("creatureID", math.abs(sourceQuestID)) or SearchForField("questID", sourceQuestID);
								if qs and #qs > 0 then
									local i, sq = #qs;
									while not sq and i > 0 do
										if qs[i].questID == sourceQuestID then sq = qs[i]; end
										i = i - 1;
									end
									-- just throw every sourceQuest into groups since it's specific questID?
									-- continue to force collectible though even without quest tracking since it's a temp window
									-- only reason to include altQuests in search was because of A/H questID usage, which is now cleaned up for quest objects
									local found = nil;
									if sq and sq.questID then
										if sq.parent and sq.parent.questID == sq.questID then
											sq = sq.parent;
										end
										found = sq;
									end
									if found
										-- ensure the character meets the custom collect for the quest
										and app.CheckCustomCollects(found)
										-- ensure the current settings do not filter the quest
										and app.RecursiveGroupRequirementsFilter(found) then
										sourceQuest = CloneData(found);
										sourceQuest.visible = true;
										sourceQuest.hideText = true;
										if found.sourceQuests and #found.sourceQuests > 0 and
											(not found.saved or app.CollectedItemVisibilityFilter(sourceQuest)) then
											-- Mark the sub source quest IDs as marked (as the same sub quest might point to 1 source quest ID)
											for j, subsourceQuests in ipairs(found.sourceQuests) do
												subSourceQuests[subsourceQuests] = true;
											end
										end
									else
										sourceQuest = nil;
									end
								elseif sourceQuestID > 0 then
									-- Create a Quest Object.
									sourceQuest = app.CreateQuest(sourceQuestID, { ['visible'] = true, ['collectible'] = true, ['hideText'] = true });
								else
									-- Create a NPC Object.
									sourceQuest = app.CreateNPC(math.abs(sourceQuestID), { ['visible'] = true, ['hideText'] = true });
								end

								-- If the quest was valid, attach it.
								if sourceQuest then tinsert(prereqs, sourceQuest); end
							end
						end

						-- Convert the subSourceQuests table into an array
						sourceQuests = {};
						if #prereqs > 0 then
							for sourceQuestID,i in pairs(subSourceQuests) do
								tinsert(sourceQuests, tonumber(sourceQuestID));
							end
							-- print("Shifted pre-reqs down & next sq layer",#prereqs)
							-- app.PrintTable(sourceQuests)
							-- print("---")
							tinsert(prereqs, {
								["text"] = L["UPON_COMPLETION"],
								["description"] = L["UPON_COMPLETION_DESC"],
								["icon"] = "Interface\\Icons\\Spell_Holy_MagicalSentry.blp",
								["visible"] = true,
								["expanded"] = true,
								["g"] = g,
								["hideText"] = true
							});
							g = prereqs;
						end
					end

					-- Clean up the recursive hierarchy. (this removed duplicates)
					sourceQuests = {};
					prereqs = g;
					while prereqs and #prereqs > 0 do
						for i=#prereqs,1,-1 do
							local o = prereqs[i];
							if o.key then
								sourceQuest = o.key .. o[o.key];
								if sourceQuests[sourceQuest] then
									-- Already exists in the hierarchy. Uh oh.
									table.remove(prereqs, i);
								else
									sourceQuests[sourceQuest] = true;
								end
							end
						end

						if #prereqs > 1 then
							prereqs = prereqs[#prereqs];
							if prereqs then prereqs = prereqs.g; end
						else
							prereqs = prereqs[#prereqs];
							if prereqs then prereqs = prereqs.g; end
						end
					end

					-- Clean up standalone "Upon Completion" headers.
					prereqs = g;
					repeat
						local n = #prereqs;
						local lastprereq = prereqs[n];
						if lastprereq.text == "Upon Completion" and n > 1 then
							table.remove(prereqs, n);
							local g = prereqs[n-1].g;
							if not g then
								g = {};
								prereqs[n-1].g = g;
							end
							if lastprereq.g then
								for i,data in ipairs(lastprereq.g) do
									tinsert(g, data);
								end
							end
							prereqs = g;
						else
							prereqs = lastprereq.g;
						end
					until not prereqs or #prereqs < 1;
				end

				local questChainHeader = {
					["text"] = useNested and L["NESTED_QUEST_REQUIREMENTS"] or L["QUEST_CHAIN_REQ"],
					["description"] = L["QUEST_CHAIN_REQ_DESC"],
					["icon"] = "Interface\\Icons\\Spell_Holy_MagicalSentry.blp",
					["OnUpdate"] = app.AlwaysShowUpdate,
					["sourceIgnored"] = true,
					-- copy any sourceQuests into the header incase the root is not actually a quest
					["sourceQuests"] = root.sourceQuests,
				};
				NestObject(group, questChainHeader);
				if useNested then
					app.NestSourceQuestsV2(questChainHeader, group.questID);
					-- Sort by the totals of the quest chain on the next game frame
					Callback(app.Sort, questChainHeader.g, app.SortDefaults.Total, true);
				else
					questChainHeader.g = g;
				end
				questChainHeader.sourceQuests = nil;
			end
		end

		popout.data.hideText = true;
		popout.data.visible = true;
		popout:BuildData();
		-- always expand all groups on initial creation
		ExpandGroupsRecursively(popout.data, true, true);
		-- Adjust some update/refresh logic if this is a Quest Chain window
		if popout.isQuestChain then
			local oldUpdate = popout.Update;
			popout.Update = function(self, ...)
				-- app.PrintDebug("Update.isQuestChain", self.Suffix, ...)
				local oldQuestAccountWide = app.AccountWideQuests;
				local oldQuestCollection = app.CollectibleQuests;
				app.CollectibleQuests = true;
				app.AccountWideQuests = false;
				oldUpdate(self, ...);
				app.CollectibleQuests = oldQuestCollection;
				app.AccountWideQuests = oldQuestAccountWide;
			end;
			local oldRefresh = popout.Refresh;
			popout.Refresh = function(self, ...)
				-- app.PrintDebug("Refresh.isQuestChain", self.Suffix, ...)
				local oldQuestAccountWide = app.AccountWideQuests;
				local oldQuestCollection = app.CollectibleQuests;
				app.CollectibleQuests = true;
				app.AccountWideQuests = false;
				oldRefresh(self, ...);
				app.CollectibleQuests = oldQuestCollection;
				app.AccountWideQuests = oldQuestAccountWide;
			end;
			-- Populate the Quest Rewards
			-- think this causes quest popouts to somehow break...
			-- app.TryPopulateQuestRewards(group)

			-- Then trigger a soft update of the window afterwards
			DelayedCallback(popout.Update, 0.25, popout);
		end
	end
	popout:Toggle(true);
	return popout;
end

-- Panel Class Library
(function()
-- Shared Panel Functions
local function OnCloseButtonPressed(self)
	self:GetParent():Hide();
end
local function SetVisible(self, show, forceUpdate)
	if show then
		self:Show();
		-- apply window position from profile
		app.Settings.SetWindowFromProfile(self.Suffix);
		self:Update(forceUpdate);
	else
		self:Hide();
	end
end
local function Toggle(self, forceUpdate)
	return SetVisible(self, not self:IsVisible(), forceUpdate);
end

app.Windows = {};
app._UpdateWindows = function(force, got)
	-- app.PrintDebug("_UpdateWindows",force,got)
	app._LastUpdateTime = GetTimePreciseSec();
	app.FunctionRunner.SetPerFrame(1);
	local Run = app.FunctionRunner.Run;
	for _,window in pairs(app.Windows) do
		Run(window.Update, window, force, got);
	end
end
function app:UpdateWindows(force, got)
	-- no need to update windows when a refresh is pending
	if app.refreshDataQueued then return; end
	AfterCombatOrDelayedCallback(app._UpdateWindows, 0.1, force, got);
end
app._RefreshWindows = function()
	-- app.PrintDebug("_RefreshWindows")
	for _,window in pairs(app.Windows) do
		window:Refresh();
	end
	-- app.PrintDebugPrior("_RefreshWindows")
end
function app:RefreshWindows()
	-- no need to update windows when a refresh is pending
	if app.refreshDataQueued then return; end
	AfterCombatOrDelayedCallback(app._RefreshWindows, 0.1);
end
local function ClearRowData(self)
	self.ref = nil;
	self.Background:Hide();
	self.Texture:Hide();
	self.Texture.Background:Hide();
	self.Texture.Border:Hide();
	self.Indicator:Hide();
	self.Summary:Hide();
	self.Label:Hide();
end
local function CalculateRowBack(data)
	if data.back then return data.back; end
	if data.parent then
		return CalculateRowBack(data.parent) * 0.5;
	else
		return 0;
	end
end
local function CalculateRowIndent(data)
	if data.indent then return data.indent; end
	if data.parent then
		return CalculateRowIndent(data.parent) + 1;
	else
		return 0;
	end
end
local function AdjustRowIndent(row, indentAdjust)
	if row.Indicator then
		local _, _, _, x = row.Indicator:GetPoint(2);
		row.Indicator:SetPoint("LEFT", row, "LEFT", x - indentAdjust, 0);
	end
	if row.Texture then
		-- only ever LEFT point set
		local _, _, _, x = row.Texture:GetPoint(2);
		-- print("row texture at",x)
		row.Texture:SetPoint("LEFT", row, "LEFT", x - indentAdjust, 0);
	else
		-- only ever LEFT point set
		local _, _, _, x = row.Label:GetPoint(1);
		-- print("row label at",x)
		row.Label:SetPoint("LEFT", row, "LEFT", x - indentAdjust, 0);
	end
end
local function SetRowData(self, row, data)
	ClearRowData(row);
	if data then
		local text = data.text;
		if not text or text == RETRIEVING_DATA then
			text = RETRIEVING_DATA;
			self.processingLinks = true;
		elseif string.find(text, "%[%]") then
			-- This means the link is still rendering
			text = RETRIEVING_DATA;
			self.processingLinks = true;
		-- WARNING: DEV ONLY START
		-- no or bad sourceID or requested to reSource and is of a proper source-able quality
		elseif data.reSource then
			if not data.q or data.q > 1 then
				-- If it doesn't, the source ID will need to be harvested.
				local s, success = GetSourceID(text) or (data.artifactID and data.s);
				if s and s > 0 then
					-- only save the source if it is different than what we already have
					if not data.s or data.s < 1 or data.s ~= s or (data.artifactID and data.s) then
						print("SourceID Update",data.text,data.s,"=>",s);
						-- print(GetItemInfo(text))
						data.s = s;
						if data.collected then
							data.parent.progress = data.parent.progress + 1;
						end
						if data.artifactID then
							local artifact = AllTheThingsArtifactsItems[data.artifactID];
							if not artifact then
								artifact = {};
							end
							artifact[data.isOffHand and 1 or 2] = s;
							AllTheThingsArtifactsItems[data.artifactID] = artifact;
						else
							app.SaveHarvestSource(data);
						end
					end
				elseif success then
					print("Success without a SourceID", text);
				else
					-- print("NARP", text);
					data.s = nil;
					data.parent.total = data.parent.total - 1;
				end
			end
			data.reSource = nil;
		end
		-- WARNING: DEV ONLY END
		local leftmost, relative, iconSize, rowPad = row, "LEFT", 16, 8;
		local x = CalculateRowIndent(data) * rowPad + rowPad;
		row.indent = x;
		local back = CalculateRowBack(data);
		row.ref = data;
		if back then
			row.Background:SetAlpha(back or 0.2);
			row.Background:Show();
		end
		local rowIndicator = row.Indicator;
		if SetIndicatorIcon(rowIndicator, data) then
			rowIndicator:SetPoint("LEFT", leftmost, relative, x - iconSize, 0);
			rowIndicator:Show();
			-- row.indent = row.indent - iconSize;
		end
		local rowTexture = row.Texture;
		if SetPortraitIcon(rowTexture, data) then
			rowTexture.Background:SetPoint("TOPLEFT", rowTexture);
			rowTexture.Border:SetPoint("TOPLEFT", rowTexture);
			rowTexture:SetPoint("LEFT", leftmost, relative, x, 0);
			rowTexture:SetWidth(rowTexture:GetHeight());
			rowTexture:Show();
			leftmost = rowTexture;
			relative = "RIGHT";
			x = rowPad / 2;
		end
		local summary = GetProgressTextForRow(data) or "---";
		-- local iconAdjust = summary and string.find(summary, "|T") and -1 or 0;
		local specs = data.specs;
		if specs and #specs > 0 then
			summary = GetSpecsString(specs, false, false) .. summary;
			-- iconAdjust = iconAdjust - #specs;
		end
		local rowSummary = row.Summary;
		local rowLabel = row.Label;
		rowSummary:SetText(summary);
		-- for whatever reason, the Client does not properly align the Points when textures are used within the 'text' of the object, with each texture added causing a 1px offset on alignment
		-- 2022-03-15 It seems as of recently that text with textures now render properly without the need for a manual adjustment. Will leave the logic in here until confirmed for others as well
		-- rowSummary:SetPoint("RIGHT", iconAdjust, 0);
		rowSummary:SetPoint("RIGHT");
		rowSummary:Show();
		rowLabel:SetPoint("LEFT", leftmost, relative, x, 0);
		if rowSummary and rowSummary:IsShown() then
			rowLabel:SetPoint("RIGHT", rowSummary, "LEFT", 0, 0);
		else
			rowLabel:SetPoint("RIGHT");
		end
		rowLabel:SetText(text);
		if data.font then
			rowLabel:SetFontObject(data.font);
			rowSummary:SetFontObject(data.font);
		else
			rowLabel:SetFontObject("GameFontNormal");
			rowSummary:SetFontObject("GameFontNormal");
		end
		row:SetHeight(select(2, rowLabel:GetFont()) + 4);
		rowLabel:Show();
		row:Show();
	else
		row:Hide();
	end
end
local CreateRow;
local function Refresh(self)
	if not app.IsReady or not self:IsVisible() then return; end
	-- app.PrintDebug("Refresh:",self.Suffix)
	if self:GetHeight() > 64 then self.ScrollBar:Show(); else self.ScrollBar:Hide(); end
	if self:GetHeight() < 40 then
		self.CloseButton:Hide();
		self.Grip:Hide();
	else
		self.CloseButton:Show();
		self.Grip:Show();
	end

	-- If there is no raw data, then return immediately.
	local rowData = rawget(self, "rowData");
	if not rowData then return; end

	-- Make it so that if you scroll all the way down, you have the ability to see all of the text every time.
	local totalRowCount = #rowData;
	if totalRowCount <= 0 then return; end

	-- Fill the remaining rows up to the (visible) row count.
	local container, rowCount, totalHeight, windowPad, minIndent = self.Container, 0, 0, 8;
	local current = math.max(1, math.min(self.ScrollBar.CurrentValue, totalRowCount));

	-- Ensure that the first row doesn't move out of position.
	local row = rawget(container.rows, 1) or CreateRow(container);
	SetRowData(self, row, rawget(rowData, 1));
	local containerHeight = container:GetHeight();
	totalHeight = totalHeight + row:GetHeight();
	current = current + 1;
	rowCount = rowCount + 1;

	for i=2,totalRowCount do
		row = rawget(container.rows, i) or CreateRow(container);
		SetRowData(self, row, rawget(rowData, current));
		-- track the minimum indentation within the set of rows so they can be adjusted later
		if row.indent and (not minIndent or row.indent < minIndent) then
			minIndent = row.indent;
			-- print("new minIndent",minIndent)
		end
		totalHeight = totalHeight + row:GetHeight();
		if totalHeight > containerHeight then
			break;
		else
			current = current + 1;
			rowCount = rowCount + 1;
		end
	end

	-- Readjust the indent of visible rows
	-- if there's actually an indent to adjust on top row (due to possible indicator)
	row = rawget(container.rows, 1);
	if row.indent ~= windowPad then
		AdjustRowIndent(row, row.indent - windowPad);
		-- increase the window pad extra for sub-rows so they will indent slightly more than the header row with indicator
		windowPad = windowPad + 8;
	else
		windowPad = windowPad + 4;
	end
	-- local headerAdjust = 0;
	-- if startIndent ~= 8 then
	-- 	-- header only adjust
	-- 	headerAdjust = startIndent - 8;
	-- 	print("header adjust",headerAdjust)
	-- 	row = rawget(container.rows, 1);
	-- 	AdjustRowIndent(row, headerAdjust);
	-- end
	-- adjust remaining rows to align on the left
	if minIndent and minIndent ~= windowPad then
		-- print("minIndent",minIndent,windowPad)
		local adjust = minIndent - windowPad;
		for i=2,rowCount do
			row = rawget(container.rows, i);
			AdjustRowIndent(row, adjust);
		end
	end

	-- Hide the extra rows if any exist
	for i=math.max(2, rowCount + 1),#container.rows do
		row = rawget(container.rows, i);
		ClearRowData(row);
		row:Hide();
	end

	-- Every possible row is visible
	if totalRowCount - rowCount < 1 then
		-- app.PrintDebug("Hide scrollbar")
		self.ScrollBar:SetMinMaxValues(1, 1);
		self.ScrollBar:SetStepsPerPage(0);
		self.ScrollBar:Hide();
	else
		-- self.ScrollBar:Show();
		totalRowCount = totalRowCount + 1;
		self.ScrollBar:SetMinMaxValues(1, totalRowCount - rowCount);
		self.ScrollBar:SetStepsPerPage(rowCount - 1);
	end

	-- If this window has an UpdateDone method which should process after the Refresh is complete
	if self.UpdateDone then
		-- print("Refresh-UpdateDone",self.Suffix)
		Callback(self.UpdateDone, self);
	-- If the rows need to be processed again, do so next update.
	elseif self.processingLinks then
		-- print("Refresh-processingLinks",self.Suffix)
		Callback(self.Refresh, self);
		self.processingLinks = nil;
	end
	-- app.PrintDebugPrior("Refreshed:",self.Suffix)
end
local function IsSelfOrChild(self, focus)
	-- This function helps validate that the focus is within the local hierarchy.
	return focus and (self == focus or IsSelfOrChild(self, focus:GetParent()));
end
local function StopMovingOrSizing(self)
	self:StopMovingOrSizing();
	self.isMoving = nil;
	-- store the window position if the window is visible (this is called on new popouts prior to becoming visible for some reason)
	if self:IsVisible() then
		self:StorePosition();
	end
end
local function StartMovingOrSizing(self, fromChild)
	if not self:IsMovable() and not self:IsResizable() or self.isLocked then
		return
	end
	if self.isMoving then
		StopMovingOrSizing(self);
	else
		self.isMoving = true;
		if ((select(2, GetCursorPosition()) / self:GetEffectiveScale()) < math.max(self:GetTop() - 40, self:GetBottom() + 10)) then
			self:StartSizing();
			Push(self, "StartMovingOrSizing (Sizing)", function()
				if self.isMoving then
					-- keeps the rows within the window fitting to the window as it resizes
					self:Refresh();
					return true;
				end
			end);
		elseif self:IsMovable() then
			self:StartMoving();
		end
	end
end
local StoreWindowPosition = function(self)
	if AllTheThingsProfiles then
		if self.isLocked or self.lockPersistable then
			local key = app.Settings:GetProfile();
			local profile = AllTheThingsProfiles.Profiles[key];
			if not profile.Windows then profile.Windows = {}; end
			-- re-save the window position by point anchors
			local points = {};
			profile.Windows[self.Suffix] = points;
			for i=1,self:GetNumPoints() do
				local point, _, refPoint, x, y = self:GetPoint(i);
				points[i] = { Point = point, PointRef = refPoint, X = math.floor(x), Y = math.floor(y) };
			end
			points.Width = math.floor(self:GetWidth());
			points.Height = math.floor(self:GetHeight());
			points.Locked = self.isLocked or nil;
			-- print("saved window",self.Suffix)
			-- app.PrintTable(points)
		else
			-- a window which was potentially saved due to being locked, but is now being unlocked (unsaved)
			-- print("removing stored window",self.Suffix)
			local key = app.Settings:GetProfile();
			local profile = AllTheThingsProfiles.Profiles[key];
			if profile and profile.Windows then
				profile.Windows[self.Suffix] = nil;
			end
		end
	end
end
-- Adds ATT information about the list of Quests into the provided tooltip
local function AddQuestInfoToTooltip(tooltip, quests)
	if quests and tooltip.AddLine then
		local text, mapID;
		for _,q in ipairs(quests) do
			text = GetCompletionIcon(q.saved) .. " [" .. q.questID .. "] " .. (q.text or RETRIEVING_DATA);
			mapID = q.mapID
				or (q.maps and q.maps[1])
				or (q.coord and q.coord[3])
				or (q.coords and q.coords[1] and q.coords[1][3]);
			if mapID then
				text = text .. " (" .. (app.GetMapName(mapID) or RETRIEVING_DATA) .. ")";
			end
			tooltip:AddLine(text);
		end
	end
end
-- Returns true if any subgroup of the provided group is currently expanded, otherwise nil
local function HasExpandedSubgroup(group)
	if group and group.g then
		for _,subgroup in ipairs(group.g) do
			-- dont need recursion since a group has to be expanded for a subgroup to be visible within it
			if subgroup.expanded then
				return true;
			end
		end
	end
end
local RowOnEnter, RowOnLeave;
local function RowOnClick(self, button)
	local reference = self.ref;
	if reference then
		-- If the row data itself has an OnClick handler... execute that first.
		if reference.OnClick and reference.OnClick(self, button) then
			return true;
		end

		local window = self:GetParent():GetParent();
		-- All non-Shift Right Clicks open a mini list or the settings.
		if button == "RightButton" then
			-- Plot waypoints, not from window header unless a popout window
			if IsAltKeyDown() and (self.index > 0 or window.ExpireTime) then
				AddTomTomWaypoint(reference);
			elseif IsShiftKeyDown() then
				if app.Settings:GetTooltipSetting("Sort:Progress") then
					app.print("Sorting selection by total progress...");
					StartCoroutine("Sorting", function() app.SortGroup(reference, "progress", self, false) end);
				else
					app.print("Sorting selection alphabetically...");
					StartCoroutine("Sorting", function() app.SortGroup(reference, "name", self, false) end);
				end
			else
				if self.index > 0 then
					if reference.__dlo then
						-- clone the underlying object of the DLO and create a popout of that instead of the DLO itself
						app:CreateMiniListForGroup(reference.__o);
						return;
					end
					app:CreateMiniListForGroup(reference);
				else
					app.Settings:Open();
				end
			end
		else
			if IsShiftKeyDown() then
				-- If we're at the Auction House
				if AuctionFrame and AuctionFrame:IsShown() then
					-- Auctionator Support
					if Atr_SearchAH then
						if reference.g and #reference.g > 0 then
							local missingItems = SearchForMissingItemNames(reference);
							if #missingItems > 0 then
								Atr_SelectPane(3);
								Atr_SearchAH(L["TITLE"], missingItems, LE_ITEM_CLASS_ARMOR);
								return true;
							end
							app.print(L["AH_SEARCH_NO_ITEMS_FOUND"]);
						else
							local name = reference.name;
							if name then
								Atr_SelectPane(3);
								--Atr_SearchAH(name, { name });
								Atr_SetSearchText (name);
								Atr_Search_Onclick ();
								return true;
							end
							app.print(L["AH_SEARCH_BOE_ONLY"]);
						end
						return true;
					elseif TSMAPI and TSMAPI.Auction then
						if reference.g and #reference.g > 0 then
							local missingItems = SearchForMissingItems(reference);
							if #missingItems > 0 then
								local itemList, search = {};
								for i,group in ipairs(missingItems) do
									search = group.tsm or TSMAPI.Item:ToItemString(group.link or group.itemID);
									if search then itemList[search] = BuildSourceTextForTSM(group, 0); end
								end
								app:ShowPopupDialog(L["TSM_WARNING_1"] .. L["TITLE"] .. L["TSM_WARNING_2"],
								function()
									TSMAPI.Groups:CreatePreset(itemList);
									app.print(L["PRESET_UPDATE_SUCCESS"]);
									if not TSMAPI.Operations:GetFirstByItem(search, "Shopping") then
										print(L["SHOPPING_OP_MISSING_1"]);
										print(L["SHOPPING_OP_MISSING_2"]);
									end
								end);
								return true;
							end
							app.print(L["AH_SEARCH_NO_ITEMS_FOUND"]);
						else
							-- Attempt to search manually with the link.
							local link = reference.link or reference.silentLink;
							if link and HandleModifiedItemClick(link) then
								AuctionFrameBrowse_Search();
								return true;
							end
						end
						return true;
					else
						if reference.g and #reference.g > 0 and not reference.link then
							app.print(L["AUCTIONATOR_GROUPS"]);
							return true;
						else
							-- Attempt to search manually with the link.
							local link = reference.link or reference.silentLink;
							if link and HandleModifiedItemClick(link) then
								AuctionFrameBrowse_Search();
								return true;
							end
						end
					end
				elseif TSMAPI_FOUR and false then
					if reference.g and #reference.g > 0 then
						if true then
							app.print(L["TSM4_ERROR"]);
							return true;
						end
						local missingItems = SearchForMissingItems(reference);
						if #missingItems > 0 then
							app:ShowPopupDialog(L["TSM_WARNING_1"] .. L["TITLE"] .. L["TSM_WARNING_2"],
							function()
								local itemString, groupPath;
								groupPath = BuildSourceTextForTSM(app:GetWindow("Prime").data, 0);
								if TSMAPI_FOUR.Groups.Exists(groupPath) then
									TSMAPI_FOUR.Groups.Remove(groupPath);
								end
								TSMAPI_FOUR.Groups.AppendOperation(groupPath, "Shopping", operation)
								for i,group in ipairs(missingItems) do
									if (not group.spellID and not group.achID) or group.itemID then
										itemString = group.tsm;
										if itemString then
											groupPath = BuildSourceTextForTSM(group, 0);
											TSMAPI_FOUR.Groups.Create(groupPath);
											if TSMAPI_FOUR.Groups.IsItemInGroup(itemString) then
												TSMAPI_FOUR.Groups.MoveItem(itemString, groupPath)
											else
												TSMAPI_FOUR.Groups.AddItem(itemString, groupPath)
											end
											if i > 10 then break; end
										end
									end
								end
								app.print("Updated the preset successfully.");
							end);
							return true;
						end
						app.print(L["AH_SEARCH_NO_ITEMS_FOUND"]);
					else
						-- Attempt to search manually with the link.
						local link = reference.link or reference.silentLink;
						if link and HandleModifiedItemClick(link) then
							AuctionFrameBrowse_Search();
							return true;
						end
					end
					return true;
				else

					-- Not at the Auction House
					-- If this reference has a link, then attempt to preview the appearance or write to the chat window.
					local link = reference.link or reference.silentLink;
					if (link and HandleModifiedItemClick(link)) or ChatEdit_InsertLink(link or BuildSourceTextForChat(reference, 0)) then return true; end

					if button == "LeftButton" then
						-- Default behavior is to Refresh Collections.
						app.RefreshCollections();
					end
					return true;
				end
			end

			-- Control Click Expands the Groups
			if IsControlKeyDown() then
				-- Illusions are a nasty animal that need to be displayed a special way.
				if reference.illusionID then
					local mainHandSourceID = TransmogUtil.GetInfoForEquippedSlot(TransmogUtil.GetTransmogLocation("MAINHANDSLOT", 0, 0));
					DressUpVisual(mainHandSourceID, 16, reference.illusionID);
				else
					-- If this reference has a link, then attempt to preview the appearance.
					local link = reference.link or reference.silentLink;
					if link and HandleModifiedItemClick(link) then
						return true;
					end
				end

				-- If this reference is anything else, expand the groups.
				if reference.g then
					-- mark the window if it is being fully-collapsed
					if self.index < 1 then
						window.fullCollapsed = HasExpandedSubgroup(reference);
					end
					-- always expand if collapsed or if clicked the header and all immediate subgroups are collapsed, otherwise collapse
					ExpandGroupsRecursively(reference, not reference.expanded or (self.index < 1 and not window.fullCollapsed), true);
					window:Update();
					return true;
				end
			end
			if self.index > 0 then
				reference.expanded = not reference.expanded;
				window:Update();
			elseif not reference.expanded then
				reference.expanded = true;
				window:Update();
			else
				-- Allow the First Frame to move the parent.
				-- Toggle lock/unlock by holding Alt when clicking the header of a Window if it is movable
				if IsAltKeyDown() and window:IsMovable() then
					local locked = not window.isLocked;
					window.isLocked = locked;
					window:StorePosition();
					-- force tooltip to refresh since locked state drives tooltip content
					if GameTooltip then
						RowOnLeave(self);
						RowOnEnter(self);
					end
				else
					self:SetScript("OnMouseUp", function(self)
						self:SetScript("OnMouseUp", nil);
						StopMovingOrSizing(window);
					end);
					StartMovingOrSizing(window, true);
				end
			end
		end
	end
end
RowOnEnter = function (self)
	local reference = self.ref; -- NOTE: This is the good ref value, not the parasitic one.
	if reference and GameTooltip then
		local GameTooltip = GameTooltip;
		local initialBuild = not GameTooltip.IsRefreshing;
		GameTooltip.IsRefreshing = true;

		if initialBuild then
			-- app.PrintDebug("RowOnEnter-Initial");
			GameTooltipIcon.icon.Background:Hide();
			GameTooltipIcon.icon.Border:Hide();
			GameTooltipIcon:Hide();
			GameTooltipIcon:ClearAllPoints();
			GameTooltipModel:Hide();
			GameTooltipModel:ClearAllPoints();

			if self:GetCenter() > (UIParent:GetWidth() / 2) and (not AuctionFrame or not AuctionFrame:IsVisible()) then
				GameTooltip:SetOwner(self, "ANCHOR_LEFT");
				GameTooltipIcon:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", 0, 0);
				GameTooltipModel:SetPoint("TOPRIGHT", GameTooltip, "TOPLEFT", 0, 0);
			else
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
				GameTooltipIcon:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 0, 0);
				GameTooltipModel:SetPoint("TOPLEFT", GameTooltip, "TOPRIGHT", 0, 0);
			end
		else
			-- app.PrintDebug("RowOnEnter-IsRefreshing",GameTooltip.AttachComplete,GameTooltip.MiscFieldsComplete,GameTooltip:NumLines());
			-- complete tooltip already exists and hasn't been cleared elsewhere, don't touch it
			if GameTooltip.AttachComplete and GameTooltip.MiscFieldsComplete and GameTooltip:NumLines() > 0 then
				-- app.PrintDebug("RowOnEnter, complete");
				return;
			end
			-- need to clear the tooltip if it is being refreshed, setting the same link again will hide it instead
			GameTooltip:ClearLines();
		end

		local link = reference.link;
		if link then
			-- app.PrintDebug("OnRowEnter-SetDirectlink",link);
			-- Safely attempt setting the tooltip link from the data
			pcall(GameTooltip.SetHyperlink, GameTooltip, link);
		end

		local doSearch;
		-- Nothing generated into tooltip based on the link, or no link exists
		if GameTooltip:NumLines() < 1 then
			-- Mark the tooltip as being complete, and insert the same text from the row itself
			GameTooltip:AddLine(reference.text);
			doSearch = true;
		end

		-- Determine search results to add if nothing was added from being searched
		-- AttachComplete will be true or false if ATT has processed the tooltip/search results already
		-- nil means no search results were attached, so we can manually add it below
		local refQuestID = reference.questID;
		if doSearch or GameTooltip.AttachComplete == nil then
			if reference.creatureID or reference.encounterID or reference.objectID then
				-- rows with these fields should not include the extra search info
			elseif reference.currencyID then
				GameTooltip:SetCurrencyByID(reference.currencyID, 1);
			elseif reference.azeriteEssenceID then
				AttachTooltipSearchResults(GameTooltip, 1, "azeriteEssenceID:" .. reference.azeriteEssenceID .. (reference.rank or 0), SearchForField, "azeriteEssenceID", reference.azeriteEssenceID, reference.rank);
			elseif reference.speciesID then
				AttachTooltipSearchResults(GameTooltip, 1, "speciesID:" .. reference.speciesID, SearchForField, "speciesID", reference.speciesID);
			elseif reference.titleID then
				AttachTooltipSearchResults(GameTooltip, 1, "titleID:" .. reference.titleID, SearchForField, "titleID", reference.titleID);
			elseif refQuestID then
				AttachTooltipSearchResults(GameTooltip, 1, "quest:"..refQuestID, SearchForField, "questID", refQuestID);
			elseif reference.flightPathID then
				AttachTooltipSearchResults(GameTooltip, 1, "fp:"..reference.flightPathID, SearchForField, "flightPathID", reference.flightPathID);
			elseif reference.achievementID then
				if reference.criteriaID then
					-- AttachTooltipSearchResults(GameTooltip, 1, "achievementID:" .. reference.achievementID .. ":" .. reference.criteriaID, SearchForField, "achievementID", reference.achievementID, reference.criteriaID);
				else
					AttachTooltipSearchResults(GameTooltip, 1, "achievementID:" .. reference.achievementID, SearchForField, "achievementID", reference.achievementID);
				end
			else
				-- app.PrintDebug("No Search Data",reference.hash)
			end
		end

		-- Miscellaneous fields
		-- app.PrintDebug("Adding misc fields");
		if app.Settings:GetTooltipSetting("Progress") then
			if reference.total and reference.total >= 2 then
				-- if collecting this reference type, then show Collection State
				if reference.collectible then
					GameTooltip:AddDoubleLine(L["COLLECTION_PROGRESS"], GetCollectionText(reference.collected or reference.saved));
				-- if completion/tracking is available, show Completion State
				elseif reference.trackable then
					GameTooltip:AddDoubleLine(L["TRACKING_PROGRESS"], GetCompletionText(reference.saved));
				end
			end
		end

		-- achievement progress. If it has a measurable statistic, show it under the achievement description
		if reference.achievementID then
			if reference.statistic then
				GameTooltip:AddDoubleLine(L["PROGRESS"], reference.statistic)
			end
		end

		-- Relative ATT location
		if reference.parent and not reference.itemID then
			if reference.parent.parent then
				GameTooltip:AddDoubleLine(reference.parent.parent.text or RETRIEVING_DATA, reference.parent.text or RETRIEVING_DATA);
			else
				--GameTooltip:AddLine(reference.parent.text or RETRIEVING_DATA, 1, 1, 1);
			end
		end

		local title = reference.title;
		if title then
			local left, right = strsplit(DESCRIPTION_SEPARATOR, title);
			if right then
				GameTooltip:AddDoubleLine(left, right);
			else
				GameTooltip:AddLine(title, 1, 1, 1);
			end
		-- elseif refQuestID and reference.retries and not reference.itemID then
		-- 	GameTooltip:AddLine(L["QUEST_MAY_BE_REMOVED"] .. tostring(reference.retries), 1, 1, 1);
		end
		if reference.lvl then
			local minlvl;
			local maxlvl;
			if type(reference.lvl) == "table" then
				minlvl = reference.lvl[1] or 0;
				maxlvl = reference.lvl[2] or 0;
			else
				minlvl = reference.lvl;
			end
			if app.Settings:GetTooltipSetting("Enabled") and app.Settings:GetTooltipSetting("LevelRequirements") then
				-- i suppose a maxlvl of 1 might exist?
				if maxlvl and maxlvl > 0 then
					GameTooltip:AddDoubleLine(L["REQUIRES_LEVEL"], tostring(minlvl) .. " to " .. tostring(maxlvl));
				-- no point to show 'requires lvl 1'
				elseif minlvl and minlvl > 1 then
					GameTooltip:AddDoubleLine(L["REQUIRES_LEVEL"], tostring(minlvl));
				end
			end
		end
		if reference.b and app.Settings:GetTooltipSetting("binding") then GameTooltip:AddDoubleLine("Binding", tostring(reference.b)); end
		if reference.requireSkill and app.Settings:GetTooltipSetting("Enabled") and app.Settings:GetTooltipSetting("ProfessionRequirements") then GameTooltip:AddDoubleLine(L["REQUIRES"], tostring(GetSpellInfo(app.SkillIDToSpellID[reference.requireSkill] or 0) or C_TradeSkillUI.GetTradeSkillDisplayName(reference.requireSkill))); end
		if reference.f and reference.f > 0 and app.Settings:GetTooltipSetting("filterID") then GameTooltip:AddDoubleLine(L["FILTER_ID"], tostring(L["FILTER_ID_TYPES"][reference.f])); end
		if reference.achievementID and app.Settings:GetTooltipSetting("achievementID") then GameTooltip:AddDoubleLine(L["ACHIEVEMENT_ID"], tostring(reference.achievementID)); end
		if reference.achievementCategoryID and app.Settings:GetTooltipSetting("achievementCategoryID") then GameTooltip:AddDoubleLine(L["ACHIEVEMENT_CATEGORY_ID"], tostring(reference.achievementCategoryID)); end
		if reference.artifactID and app.Settings:GetTooltipSetting("artifactID") then GameTooltip:AddDoubleLine(L["ARTIFACT_ID"], tostring(reference.artifactID)); end
		if reference.s and not reference.link and app.Settings:GetTooltipSetting("sourceID") then GameTooltip:AddDoubleLine(L["SOURCE_ID"], tostring(reference.s)); end
		if reference.azeriteEssenceID then
			if app.Settings:GetTooltipSetting("azeriteEssenceID") then GameTooltip:AddDoubleLine(L["AZERITE_ESSENCE_ID"], tostring(reference.azeriteEssenceID)); end
		end
		if reference.difficultyID and app.Settings:GetTooltipSetting("difficultyID") then GameTooltip:AddDoubleLine(L["DIFFICULTY_ID"], tostring(reference.difficultyID)); end
		if app.Settings:GetTooltipSetting("creatureID") then
			if reference.creatureID then
				GameTooltip:AddDoubleLine(L["CREATURE_ID"], tostring(reference.creatureID));
			elseif reference.npcID then
				GameTooltip:AddDoubleLine(L["NPC_ID"], tostring(reference.npcID));
			end
		end
		if reference.crs and app.Settings:GetTooltipSetting("creatures") then
			-- extreme amounts of creatures tagged, then only list a summary of how many...
			if #reference.crs > 25 then
				GameTooltip:AddDoubleLine(CREATURE, "[" .. tostring(#reference.crs) .. " Creatures]");
			elseif app.Settings:GetTooltipSetting("creatureID") then
				for i,cr in ipairs(reference.crs) do
					GameTooltip:AddDoubleLine(i == 1 and CREATURE or " ", tostring(app.NPCNameFromID[cr]) .. " (" .. cr .. ")");
				end
			else
				for i,cr in ipairs(reference.crs) do
					GameTooltip:AddDoubleLine(i == 1 and CREATURE or " ", tostring(app.NPCNameFromID[cr]));
				end
			end
		end
		if reference.encounterID and app.Settings:GetTooltipSetting("encounterID") then GameTooltip:AddDoubleLine(L["ENCOUNTER_ID"], tostring(reference.encounterID)); end
		if reference.factionID and app.Settings:GetTooltipSetting("factionID") then GameTooltip:AddDoubleLine(L["FACTION_ID"], tostring(reference.factionID)); end
		if reference.headerID and app.Settings:GetTooltipSetting("headerID") then GameTooltip:AddDoubleLine(L["HEADER_ID"], tostring(reference.headerID)); end
		if reference.minReputation and not reference.maxReputation then
			local standingId, offset = app.GetReputationStanding(reference.minReputation)
			local factionID = reference.minReputation[1];
			local factionName = GetFactionInfoByID(factionID) or "the opposite faction";
			local msg = L["MINUMUM_STANDING"]
			if offset ~= 0 then msg = msg .. " " .. offset end
			msg = msg .. " " .. app.GetCurrentFactionStandingText(factionID, standingId) .. L["_WITH_"] .. factionName .. "."
			GameTooltip:AddLine(msg);
		end
		if reference.maxReputation and not reference.minReputation then
			local standingId, offset = app.GetReputationStanding(reference.maxReputation)
			local factionID = reference.maxReputation[1];
			local factionName = GetFactionInfoByID(factionID) or "the opposite faction";
			local msg = L["MAXIMUM_STANDING"]
			if offset ~= 0 then msg = msg .. " " .. offset end
			msg = msg .. " " .. app.GetCurrentFactionStandingText(factionID, standingId) .. L["_WITH_"] .. factionName .. "."
			GameTooltip:AddLine(msg);
		end
		if reference.minReputation and reference.maxReputation then
			local minStandingId, minOffset = app.GetReputationStanding(reference.minReputation)
			local maxStandingId, maxOffset = app.GetReputationStanding(reference.maxReputation)
			local factionID = reference.minReputation[1];
			local factionName = GetFactionInfoByID(factionID) or "the opposite faction";
			local msg = L["MIN_MAX_STANDING"]
			if minOffset ~= 0 then msg = msg .. " " .. minOffset end
			msg = msg .. " " .. app.GetCurrentFactionStandingText(factionID, minStandingId) .. L["_AND"]
			if maxOffset ~= 0 then msg = msg .. " " .. maxOffset end
			msg = msg .. " " .. app.GetCurrentFactionStandingText(factionID, maxStandingId) .. L["_WITH_"] .. factionName .. ".";
			GameTooltip:AddLine(msg);
		end
		if reference.followerID and app.Settings:GetTooltipSetting("followerID") then GameTooltip:AddDoubleLine(L["FOLLOWER_ID"], tostring(reference.followerID)); end
		if reference.illusionID and app.Settings:GetTooltipSetting("illusionID") then GameTooltip:AddDoubleLine(L["ILLUSION_ID"], tostring(reference.illusionID)); end
		if reference.instanceID then
			if app.Settings:GetTooltipSetting("instanceID") then GameTooltip:AddDoubleLine(L["INSTANCE_ID"], tostring(reference.instanceID)); end
			GameTooltip:AddDoubleLine(L["LOCKOUT"], L[reference.isLockoutShared and "SHARED" or "SPLIT"]);
		end
		if reference.objectID and app.Settings:GetTooltipSetting("objectID") then GameTooltip:AddDoubleLine(L["OBJECT_ID"], tostring(reference.objectID)); end
		if reference.speciesID and app.Settings:GetTooltipSetting("speciesID") then GameTooltip:AddDoubleLine(L["SPECIES_ID"], tostring(reference.speciesID)); end
		if reference.spellID and app.Settings:GetTooltipSetting("spellID") then GameTooltip:AddDoubleLine(L["SPELL_ID"], tostring(reference.spellID)); end
		if reference.tierID and app.Settings:GetTooltipSetting("tierID") then GameTooltip:AddDoubleLine(L["EXPANSION_ID"], tostring(reference.tierID)); end
		if reference.setID then GameTooltip:AddDoubleLine(L["SET_ID"], tostring(reference.setID)); end
		if reference.flightPathID and app.Settings:GetTooltipSetting("flightPathID")  then GameTooltip:AddDoubleLine(L["FLIGHT_PATH_ID"], tostring(reference.flightPathID)); end
		if reference.mapID and app.Settings:GetTooltipSetting("mapID") then GameTooltip:AddDoubleLine(L["MAP_ID"], tostring(reference.mapID)); end
		if reference.coords and app.Settings:GetTooltipSetting("Coordinates") then
			local currentMapID, str = app.GetCurrentMapID();
			local coords = reference.coords;
			-- more than 10 coords, put into an additional line
			local coordLimit, coordCount = 11, #coords;
			local additionaLine, coord;
			if coordCount > coordLimit then
				coordLimit = coordLimit - 1;
				additionaLine = "+ "..(coordCount - coordLimit)..L["_MORE"];
				coordCount = coordLimit;
			end
			for i=1,coordCount do
				coord = coords[i];
				local x, y = coord[1], coord[2];
				local mapID = coord[3] or currentMapID;
				if mapID ~= currentMapID then
					str = app.GetMapName(mapID) or "??";
					if app.Settings:GetTooltipSetting("mapID") then
						str = str .. " (" .. mapID .. ")";
					end
					str = str .. ": ";
				else
					str = "";
				end
				GameTooltip:AddDoubleLine(i == 1 and L["COORDINATES_STRING"] or " ",
					str.. GetNumberWithZeros(math.floor(x * 10) * 0.1, 1) .. ", " .. GetNumberWithZeros(math.floor(y * 10) * 0.1, 1), 1, 1, 1, 1, 1, 1);
			end
			if additionaLine then
				GameTooltip:AddDoubleLine(" ", additionaLine, 1, 1, 1, 1, 1, 1);
			end
		end
		if reference.providers then
			local counter = 0;
			for i,provider in pairs(reference.providers) do
				local providerType = provider[1];
				local providerID = provider[2] or 0;
				local providerString = UNKNOWN;
				if providerType == "o" then
					providerString = app.ObjectNames[providerID] or reference.text or ("Object: " .. RETRIEVING_DATA)
					if app.Settings:GetTooltipSetting("objectID") then
						providerString = providerString .. ' (' .. providerID .. ')';
					end
				elseif providerType == "n" then
					providerString = (providerID > 0 and app.NPCNameFromID[providerID]) or ("Creature: " .. RETRIEVING_DATA)
					if app.Settings:GetTooltipSetting("creatureID") then
						providerString = providerString .. ' (' .. providerID .. ')';
					end
				elseif providerType == "i" then
					local _,name,_,_,_,_,_,_,_,icon = GetItemInfo(providerID);
					providerString = (icon and ("|T" .. icon .. ":0|t") or "") .. (name or ("Item: " .. RETRIEVING_DATA));
					if app.Settings:GetTooltipSetting("itemID") then
						providerString = providerString .. ' (' .. providerID .. ')';
					end
				end
				GameTooltip:AddDoubleLine(counter == 0 and L.PROVIDERS or " ", providerString);
				counter = counter + 1;
			end
		end
		if reference.coord and app.Settings:GetTooltipSetting("Coordinates") then
			GameTooltip:AddDoubleLine("Coordinate",
				GetNumberWithZeros(math.floor(reference.coord[1] * 10) * 0.1, 1) .. ", " ..
				GetNumberWithZeros(math.floor(reference.coord[2] * 10) * 0.1, 1), 1, 1, 1, 1, 1, 1);
		end
		if reference.speciesID then
			local progress, total = C_PetJournal.GetNumCollectedInfo(reference.speciesID);
			if total then GameTooltip:AddLine(tostring(progress) .. " / " .. tostring(total) .. L["COLLECTED_STRING"]); end
		end
		if reference.titleID then
			if app.Settings:GetTooltipSetting("titleID") then GameTooltip:AddDoubleLine(L["TITLE_ID"], tostring(reference.titleID)); end
			GameTooltip:AddDoubleLine(" ", L[reference.saved and "KNOWN_ON_CHARACTER" or "UNKNOWN_ON_CHARACTER"]);
		end
		if refQuestID then
			if app.Settings:GetTooltipSetting("questID") then
				GameTooltip:AddDoubleLine(L["QUEST_ID"], tostring(refQuestID));
				local otherFactionQuestID = reference.otherFactionQuestID;
				if otherFactionQuestID then
					GameTooltip:AddDoubleLine(L["QUEST_ID"].. " ["..(app.FactionID == Enum.FlightPathFaction.Alliance and FACTION_HORDE or FACTION_ALLIANCE).."]", tostring(otherFactionQuestID));
				end
			end
			if ATTAccountWideData.OneTimeQuests[refQuestID] then
				GameTooltip:AddDoubleLine(L["QUEST_ONCE_PER_ACCOUNT"], sformat(L["QUEST_ONCE_PER_ACCOUNT_FORMAT"], ATTCharacterData[ATTAccountWideData.OneTimeQuests[refQuestID]].text));
			elseif ATTAccountWideData.OneTimeQuests[refQuestID] == false then
				GameTooltip:AddLine("|cffcf271b" .. L["QUEST_ONCE_PER_ACCOUNT"] .. "|r");
			end
		end
		if reference.qgs and app.Settings:GetTooltipSetting("QuestGivers") then
			if app.Settings:GetTooltipSetting("creatureID") then
				for i,qg in ipairs(reference.qgs) do
					GameTooltip:AddDoubleLine(i == 1 and L["QUEST_GIVER"] or " ", tostring(app.NPCNameFromID[qg]) .. " (" .. qg .. ")");
				end
			else
				for i,qg in ipairs(reference.qgs) do
					GameTooltip:AddDoubleLine(i == 1 and L["QUEST_GIVER"] or " ", tostring(app.NPCNameFromID[qg]));
				end
			end
		end
		if reference.c and app.Settings:GetTooltipSetting("Enabled") and app.Settings:GetTooltipSetting("ClassRequirements") then
			local str,colors = "",app.Settings:GetTooltipSetting("UseMoreColors");
			for i,cl in ipairs(reference.c) do
				if i > 1 then str = str .. ", "; end
				if colors then
					str = str .. Colorize(C_CreatureInfo.GetClassInfo(cl).className, RAID_CLASS_COLORS[select(2, GetClassInfo(cl))].colorStr);
				else
					str = str .. C_CreatureInfo.GetClassInfo(cl).className;
				end
			end
			GameTooltip:AddDoubleLine(L["CLASSES_CHECKBOX"], str);
		end
		if app.Settings:GetTooltipSetting("Enabled") and app.Settings:GetTooltipSetting("RaceRequirements") then
			if reference.races then
				local str = "";
				for i,race in ipairs(reference.races) do
					if i > 1 then str = str .. ", "; end
					str = str .. C_CreatureInfo.GetRaceInfo(race).raceName;
				end
				if #reference.races > 4 then
					GameTooltip:AddLine(L["RACES_CHECKBOX"] .. " " .. str, nil, nil, nil, 1);
				else
					GameTooltip:AddDoubleLine(L["RACES_CHECKBOX"], str);
				end
			elseif reference.r and reference.r > 0 then
				if reference.r == 2 then
					GameTooltip:AddDoubleLine(L["RACES_CHECKBOX"], app.Settings:GetTooltipSetting("UseMoreColors") and Colorize(ITEM_REQ_ALLIANCE, app.Colors.Alliance) or ITEM_REQ_ALLIANCE);
				elseif reference.r == 1 then
					GameTooltip:AddDoubleLine(L["RACES_CHECKBOX"], app.Settings:GetTooltipSetting("UseMoreColors") and Colorize(ITEM_REQ_HORDE, app.Colors.Horde) or ITEM_REQ_HORDE);
				else
					GameTooltip:AddDoubleLine(L["RACES_CHECKBOX"], "Unknown");
				end
			end
		end
		if reference.isWorldQuest then GameTooltip:AddLine(L["DURING_WQ_ONLY"]); end
		if reference.isDaily then GameTooltip:AddLine(L["COMPLETED_DAILY"]);
		elseif reference.isWeekly then GameTooltip:AddLine(L["COMPLETED_WEEKLY"]);
		elseif reference.isMontly then GameTooltip:AddLine(L["COMPLETED_MONTHLY"]);
		elseif reference.isYearly then GameTooltip:AddLine(L["COMPLETED_YEARLY"]);
		elseif reference.repeatable then GameTooltip:AddLine(L["COMPLETED_MULTIPLE"]); end
		if initialBuild and not GameTooltipModel:TrySetModel(reference) and reference.icon then
			if app.Settings:GetTooltipSetting("iconPath") then
				GameTooltip:AddDoubleLine("Icon", reference.icon);
			end
			GameTooltipIcon:SetSize(72,72);
			GameTooltipIcon.icon:SetTexture(reference.preview or reference.icon);
			local texcoord = reference.previewtexcoord or reference.texcoord;
			if texcoord then
				GameTooltipIcon.icon:SetTexCoord(texcoord[1], texcoord[2], texcoord[3], texcoord[4]);
			else
				GameTooltipIcon.icon:SetTexCoord(0, 1, 0, 1);
			end
			GameTooltipIcon:Show();
		end
		if reference.displayID and app.Settings:GetTooltipSetting("displayID") then
			GameTooltip:AddDoubleLine("Display ID", reference.displayID);
		end
		if reference.modelID and app.Settings:GetTooltipSetting("displayID") then
			GameTooltip:AddDoubleLine("Model ID", reference.modelID);
		end
		if reference.cost then
			if type(reference.cost) == "table" then
				local _, name, icon, amount;
				for k,v in pairs(reference.cost) do
					_ = v[1];
					if _ == "i" then
						_,name,_,_,_,_,_,_,_,icon = GetItemInfo(v[2]);
						amount = v[3];
						if amount > 1 then
							amount = formatNumericWithCommas(amount) .. "x ";
						else
							amount = "";
						end
					elseif _ == "c" then
						amount = v[3];
						local currencyData = C_CurrencyInfo.GetCurrencyInfo(v[2]);
						name = C_CurrencyInfo.GetCurrencyLink(v[2], amount) or currencyData.name or "Unknown";
						icon = currencyData.iconFileID or nil;
						if amount > 1 then
							amount = formatNumericWithCommas(amount) .. "x ";
						else
							amount = "";
						end
					elseif _ == "g" then
						name = "";
						icon = nil;
						amount = GetMoneyString(v[2]);
					end
					GameTooltip:AddDoubleLine(k == 1 and L["COST"] or " ", amount .. (icon and ("|T" .. icon .. ":0|t") or "") .. (name or RETRIEVING_DATA));
				end
			else
				local amount = GetMoneyString(reference.cost);
				GameTooltip:AddDoubleLine(L["COST"], amount);
			end
		end
		if reference.achievementID and reference.criteriaID then
			GameTooltip:AddDoubleLine(L["CRITERIA_FOR"], GetAchievementLink(reference.achievementID));
		end
		if app.Settings:GetTooltipSetting("Progress") then
			local right = GetProgressTextForTooltip(reference, app.Settings:GetTooltipSetting("ShowIconOnly"));
			if right and right ~= "" and right ~= "---" then
				GameTooltipTextRight1:SetText(right);
				GameTooltipTextRight1:Show();
			end
		end

		-- Various Settings IDs/Raw Values
		-- TODO: maybe eventually a nice clean way of doing this instead of having to manually add every ID to tooltip
		-- local settings = app.Settings;
		-- local val;
		-- for key,name in pairs(app.Settings.DataKeys) do
		-- 	val = reference[key];
		-- 	if val and type(val) ~= "table" and settings:GetTooltipSetting(key) then
		-- 		GameTooltip:AddDoubleLine(name, val);
		-- 	end
		-- end

		-- Additional information (search will insert this information if found in search)
		if GameTooltip.AttachComplete == nil then
			-- Lore
			if app.Settings:GetTooltipSetting("Lore") and reference.lore then
				GameTooltip:AddLine(reference.lore, 0.4, 0.8, 1, 1);
			end
			-- Description
			if app.Settings:GetTooltipSetting("Descriptions") and reference.description then
				GameTooltip:AddLine(reference.description, 0.4, 0.8, 1, 1);
			end
			if reference.rwp then
				local rwp = GetRemovedWithPatchString(reference.rwp);
				local _,r,g,b = HexToARGB(app.Colors.RemovedWithPatch);
				GameTooltip:AddLine(rwp, r / 255, g / 255, b / 255, 1);
			end
			if reference.awp then
				local rwp = GetAddedWithPatchString(reference.awp);
				local _,r,g,b = HexToARGB(app.Colors.AddedWithPatch);
				GameTooltip:AddLine(rwp, r / 255, g / 255, b / 255, 1);
			end
			-- an item used for a faction which is repeatable
			if reference.itemID and reference.factionID and reference.repeatable then
				GameTooltip:AddLine(L["ITEM_GIVES_REP"] .. (select(1, GetFactionInfoByID(reference.factionID)) or ("Faction #" .. tostring(reference.factionID))) .. "'", 0.4, 0.8, 1, 1, true);
			end
			-- Unobtainable
			if reference.u then
				GameTooltip:AddLine(L["UNOBTAINABLE_ITEM_REASONS"][reference.u][2], 1, 1, 1, 1, true);
			end
			-- Pet Battles
			if reference.pb then
				GameTooltip:AddLine(L["REQUIRES_PETBATTLES"], 1, 1, 1, 1, true);
			end
			-- PvP
			if reference.pvp then
				GameTooltip:AddLine(L["REQUIRES_PVP"], 1, 1, 1, 1, true);
			end
			-- Has a symlink for additonal information
			if reference.sym then
				GameTooltip:AddLine(L["SYM_ROW_INFORMATION"], 1, 1, 1, 1, true);
			end
			-- Tooltip for something which was not attached via search, so mark it as complete here
			GameTooltip.AttachComplete = true;
		end

		-- Ignored for Source/Progress
		if reference.sourceIgnored then
			GameTooltip:AddLine(L["DOES_NOT_CONTRIBUTE_TO_PROGRESS"], 1, 1, 1, 1, true);
		end
		-- Further conditional texts that can be displayed
		if reference.timeRemaining then
			GameTooltip:AddLine(reference.timeRemaining);
		end

		-- Calculate Best Drop Percentage. (Legacy Loot Mode)
		if reference.itemID and not reference.speciesID and not reference.spellID and app.Settings:GetTooltipSetting("DropChances") then
			local numSpecializations = GetNumSpecializations();
			if numSpecializations and numSpecializations > 0 then
				local encounterID = GetRelativeValue(reference.parent, "encounterID");
				if encounterID then
					-- TODO: revise in 9.1.5 when 'bonus drops' might be able to be identified via API calls (don't attribute to drop chance)
					-- Why is Encounter Journal so weird? none of the API calls work unless the EJ is actually open... something is missing...

					-- difficulty 0 seems to default to the lowest valid difficulty in the EJ
					-- local tierID = GetRelativeValue(reference.parent, "tierID") or 0;
					-- local instanceID = GetRelativeValue(reference.parent, "instanceID") or 0;
					local difficultyID = GetRelativeValue(reference.parent, "difficultyID");
					-- -- local funcs
					-- local EJ_SetLootFilter, EJ_GetNumLoot = EJ_SetLootFilter, EJ_GetNumLoot;
					-- local legacyLoot = C_Loot.IsLegacyLootModeEnabled();
					-- print("tier/instance/encounter/difficulty",tierID,instanceID,encounterID,difficultyID)
					-- EJ_SelectTier(tierID);
					-- EJ_SelectInstance(instanceID);
					-- EJ_SelectEncounter(encounterID);
					-- EJ_SetDifficulty(difficultyID);
					-- -- get total items
					-- EJ_SetLootFilter(0, 0);
					-- local totalItems = EJ_GetNumLoot() or 0;
					-- print("diff/filter/items",EJ_GetDifficulty(),"/",EJ_GetLootFilter(),"/",totalItems)
					-- -- Legacy Loot is simply 1 / total items chance since spec has no relevance to drops, i.e. this one item / total items in drop table
					-- if totalItems > 0 then
					-- 	GameTooltip:AddDoubleLine(L["LOOT_TABLE_CHANCE"], GetNumberWithZeros(100 / totalItems, 2) .. "%");
					-- else
					-- 	GameTooltip:AddDoubleLine(L["LOOT_TABLE_CHANCE"], "N/A");
					-- end

					-- -- see what specs this reference item will drop for
					-- local specs = reference.specs;
					-- if specs then
					-- 	local class, specItems, min, count = app.ClassIndex, {}, 100;
					-- 	-- get items per spec and min items
					-- 	for _,specID in pairs(specs) do
					-- 		EJ_SetLootFilter(class, specID);
					-- 		-- items for this spec
					-- 		count = EJ_GetNumLoot() or 100;
					-- 		print("class/spec/diff/filter/items",class,"/",specID,"/",EJ_GetDifficulty(),"/",EJ_GetLootFilter(),"/",count)
					-- 		if count < min and count > 0 then
					-- 			min = count;
					-- 		end
					-- 		specItems[specID] = count;
					-- 	end
					-- 	local chance = 100 / min;
					-- 	local bestSpecs = {};
					-- 	-- define the best specs based on min
					-- 	for specID,count in pairs(specItems) do
					-- 		if count == min then
					-- 			tinsert(bestSpecs, specID);
					-- 		end
					-- 	end
					-- 	-- print out the specs with min items
					-- 	local specString = GetSpecsString(bestSpecs, true, true) or "???";
					-- 	GameTooltip:AddDoubleLine(legacyLoot and L["BEST_BONUS_ROLL_CHANCE"] or L["BEST_PERSONAL_LOOT_CHANCE"],  GetNumberWithZeros(chance, 2).."% ("..GetNumberWithZeros(chance / 5, 2).."%) "..specString);
					-- elseif legacyLoot then
					-- 	-- Not available at all, best loot spec is the one with the most number of items in it.
					-- 	print("legacy loot?")
					-- 	-- local most, bestSpecID = 0;
					-- 	-- for i=1,numSpecializations,1 do
					-- 	-- 	local id = GetSpecializationInfo(i);
					-- 	-- 	local specHit = specHits[id] or 0;
					-- 	-- 	if specHit > most then
					-- 	-- 		most = specHit;
					-- 	-- 		bestSpecID = i;
					-- 	-- 	end
					-- 	-- end
					-- 	-- if bestSpecID then
					-- 	-- 	local id, name, description, icon = GetSpecializationInfo(bestSpecID);
					-- 	-- 	if totalItems > 0 then
					-- 	-- 		GameTooltip:AddDoubleLine(L["BONUS_ROLL"], GetNumberWithZeros((1 / (totalItems - specHits[id])) * 100, 2) .. "% |T" .. icon .. ":0|t " .. name);
					-- 	-- 	else
					-- 	-- 		GameTooltip:AddDoubleLine(L["BONUS_ROLL"], "N/A");
					-- 	-- 	end
					-- 	-- end
					-- end


					local encounterCache = fieldCache["encounterID"][encounterID];
					if encounterCache then
						local itemList = {};
						for i,encounter in ipairs(encounterCache) do
							if encounter.g and GetRelativeValue(encounter.parent, "difficultyID") == difficultyID then
								SearchForRelativeItems(encounter, itemList);
							end
						end
						local specHits = {};
						for _,item in ipairs(itemList) do
							local specs = item.specs;
							if specs then
								for j,spec in ipairs(specs) do
									specHits[spec] = (specHits[spec] or 0) + 1;
								end
							end
						end

						local totalItems = #itemList; -- if somehow encounter drops 0 items but an item still references the encounter
						local chance, color;
						local legacyLoot = C_Loot.IsLegacyLootModeEnabled();

						-- Legacy Loot is simply 1 / total items chance since spec has no relevance to drops, i.e. this one item / total items in drop table
						if totalItems > 0 then
							chance = 100 / totalItems;
							color = GetProgressColor(chance / 100);
							GameTooltip:AddDoubleLine(L["LOOT_TABLE_CHANCE"], "|c"..color..GetNumberWithZeros(chance, 1) .. "%|r");
						else
							GameTooltip:AddDoubleLine(L["LOOT_TABLE_CHANCE"], "N/A");
						end

						local specs = reference.specs;
						if specs and #specs > 0 then
							-- Available for one or more loot specialization.
							local least, bestSpecs = 999, {};
							for _,spec in ipairs(specs) do
								local specHit = specHits[spec] or 0;
								-- For Personal Loot!
								if specHit > 0 and specHit <= least then
									least = specHit;
									bestSpecs[spec] = specHit;
								end
							end
							-- something has a best spec
							if least < 999 then
								-- define the best specs based on min
								local rollSpec = {};
								for specID,count in pairs(bestSpecs) do
									if count == least then
										tinsert(rollSpec, specID);
									end
								end
								chance = 100 / least;
								color = GetProgressColor(chance / 100);
								-- print out the specs with min items
								local specString = GetSpecsString(rollSpec, true, true) or "???";
								GameTooltip:AddDoubleLine(legacyLoot and L["BEST_BONUS_ROLL_CHANCE"] or L["BEST_PERSONAL_LOOT_CHANCE"],  specString.."  |c"..color..GetNumberWithZeros(chance, 1).."%|r");
							end
						elseif legacyLoot then
							-- Not available at all, best loot spec is the one with the most number of items in it.
							local most, bestSpecID = 0;
							for i=1,numSpecializations,1 do
								local id = GetSpecializationInfo(i);
								local specHit = specHits[id] or 0;
								if specHit > most then
									most = specHit;
									bestSpecID = i;
								end
							end
							if bestSpecID then
								local id, name, description, icon = GetSpecializationInfo(bestSpecID);
								if totalItems > 0 then
									chance = 100 / (totalItems - specHits[id]);
									color = GetProgressColor(chance / 100);
									GameTooltip:AddDoubleLine(L["BONUS_ROLL"], "|T" .. icon .. ":0|t " .. name .. " |c"..color..GetNumberWithZeros(chance, 1) .. "%|r");
								else
									GameTooltip:AddDoubleLine(L["BONUS_ROLL"], "N/A");
								end
							end
						end
					end
				end
			end
		end

		-- Show info about if this Thing cannot be collected due to a custom collectibility
		-- restriction on the Thing which this character does not meet
		if reference.customCollect then
			local customCollectEx;
			local requires = L["REQUIRES"];
			for i,c in ipairs(reference.customCollect) do
				customCollectEx = L["CUSTOM_COLLECTS_REASONS"][c];
				local icon_color_str = (customCollectEx["icon"].." |c"..customCollectEx["color"]..customCollectEx["text"] or "[MISSING_LOCALE_KEY]");
				if not app.CurrentCharacter.CustomCollects[c] then
					GameTooltip:AddDoubleLine("|cffc20000" .. requires .. ":|r " .. icon_color_str, customCollectEx["desc"] or "");
				else
					GameTooltip:AddDoubleLine(requires .. ": " .. icon_color_str, customCollectEx["desc"] or "");
				end
			end
		end

		-- Show Quest Prereqs
		local isDebugMode, sqs, bestMatch = app.MODE_DEBUG;
		if reference.sourceQuests and (not reference.saved or isDebugMode) then
			local prereqs, bc = {}, {};
			for i,sourceQuestID in ipairs(reference.sourceQuests) do
				if sourceQuestID > 0 and (isDebugMode or not IsQuestFlaggedCompleted(sourceQuestID)) then
					sqs = SearchForField("questID", sourceQuestID);
					if sqs and #sqs > 0 then
						bestMatch = nil;
						for j,sq in ipairs(sqs) do
							if sq.questID == sourceQuestID then
								if isDebugMode or (not IsQuestFlaggedCompleted(sourceQuestID) and app.GroupFilter(sq)) then
									if sq.sourceQuests then
										-- Always prefer the source quest with additional source quest data.
										bestMatch = sq;
									elseif not sq.itemID and (not bestMatch or not bestMatch.sourceQuests) then
										-- Otherwise try to find the version of the quest that isn't an item.
										bestMatch = sq;
									end
								end
							end
						end
						if bestMatch then
							if bestMatch.isBreadcrumb then
								tinsert(bc, bestMatch);
							else
								tinsert(prereqs, bestMatch);
							end
						end
					else
						tinsert(prereqs, app.CreateQuest(sourceQuestID));
					end
				end
			end
			if prereqs and #prereqs > 0 then
				GameTooltip:AddLine(L["PREREQUISITE_QUESTS"]);
				AddQuestInfoToTooltip(GameTooltip, prereqs);
			end
			if bc and #bc > 0 then
				GameTooltip:AddLine(L["BREADCRUMBS_WARNING"]);
				AddQuestInfoToTooltip(GameTooltip, bc);
			end
		end

		-- Show Breadcrumb information
		local lockedWarning;
		if reference.isBreadcrumb then
			GameTooltip:AddLine(sformat("|c%s%s|r", app.Colors.Locked, L["THIS_IS_BREADCRUMB"]));
			if reference.nextQuests then
				local isBreadcrumbAvailable = true;
				local nextq, nq = {};
				for _,nextQuestID in ipairs(reference.nextQuests) do
					if nextQuestID > 0 then
						nq = app.SearchForObject("questID", nextQuestID);
						-- existing quest group
						if nq then
							tinsert(nextq, nq);
						else
							tinsert(nextq, app.CreateQuest(nextQuestID));
						end
						if IsQuestFlaggedCompleted(nextQuestID) then
							isBreadcrumbAvailable = false;
						end
					end
				end
				if isBreadcrumbAvailable then
					-- The character is able to accept the breadcrumb quest without Party Sync
					GameTooltip:AddLine(L["BREADCRUMB_PARTYSYNC"]);
					AddQuestInfoToTooltip(GameTooltip, nextq);
				elseif reference.DisablePartySync == false then
					-- unknown if party sync will function for this Thing
					GameTooltip:AddLine(sformat("|c%s%s|r", app.Colors.LockedWarning, L["BREADCRUMB_PARTYSYNC_4"]));
					AddQuestInfoToTooltip(GameTooltip, nextq);
				elseif not reference.DisablePartySync then
					-- The character wont be able to accept this quest without the help of a lower level character using Party Sync
					GameTooltip:AddLine(sformat("|c%s%s|r", app.Colors.LockedWarning, L["BREADCRUMB_PARTYSYNC_2"]));
					AddQuestInfoToTooltip(GameTooltip, nextq);
				else
					-- known to not be possible in party sync
					GameTooltip:AddLine(L["DISABLE_PARTYSYNC"]);
				end
				lockedWarning = true;
			end
		end

		-- Show information about it becoming locked due to some criteira
		local lockCriteria = reference.lc;
		if lockCriteria then
			-- list the reasons this may become locked due to lock criteria
			local critKey, critValue;
			local critFuncs = app.QuestLockCriteriaFunctions;
			local critFunc;
			GameTooltip:AddLine(sformat(L["UNAVAILABLE_WARNING_FORMAT"], app.Colors.LockedWarning, lockCriteria[1]));
			for i=2,#lockCriteria,1 do
				critKey = lockCriteria[i];
				i = i + 1;
				critValue = lockCriteria[i];
				critFunc = critFuncs[critKey];
				if critFunc then
					local label = critFuncs["label_"..critKey];
					local text = critFuncs["text_"..critKey](critValue);
					GameTooltip:AddLine(GetCompletionIcon(critFunc(critValue)).." "..label..": "..text);
				end
			end
		end
		local altQuests = reference.altQuests;
		if altQuests then
			-- list the reasons this may become locked due to altQuests specifically
			local critValue;
			local critFuncs = app.QuestLockCriteriaFunctions;
			local critFunc = critFuncs["questID"];
			local label = critFuncs["label_questID"];
			local text;
			GameTooltip:AddLine(sformat(L["UNAVAILABLE_WARNING_FORMAT"], app.Colors.LockedWarning, 1));
			for i=1,#altQuests,1 do
				critValue = altQuests[i];
				if critFunc then
					text = critFuncs["text_questID"](critValue);
					GameTooltip:AddLine(GetCompletionIcon(critFunc(critValue)).." "..label..": "..text);
				end
			end
		end

		-- it is locked and no warning has been added to the tooltip
		if not lockedWarning and reference.locked then
			if reference.DisablePartySync == false then
				-- unknown if party sync will function for this Thing
				GameTooltip:AddLine(sformat("|c%s%s|r", app.Colors.LockedWarning, L["BREADCRUMB_PARTYSYNC_4"]));
			elseif not reference.DisablePartySync then
				-- should be possible in party sync
				GameTooltip:AddLine(sformat("|c%s%s|r", app.Colors.LockedWarning, L["BREADCRUMB_PARTYSYNC_3"]));
			else
				-- known to not be possible in party sync
				GameTooltip:AddLine(L["DISABLE_PARTYSYNC"]);
			end
		end

		-- Show lockout information about an Instance (Raid or Dungeon)
		local locks = reference.locks;
		if locks then
			if locks.encounters then
				GameTooltip:AddDoubleLine("Resets", date("%c", locks.reset));	-- TODO: localize this with format string, not just single word
				for encounterIter,encounter in pairs(locks.encounters) do
					GameTooltip:AddDoubleLine(" " .. encounter.name, GetCompletionIcon(encounter.isKilled));
				end
			else
				if reference.isLockoutShared and locks.shared then
					GameTooltip:AddDoubleLine("Shared", date("%c", locks.shared.reset));	-- TODO: localize this with format string, not just single word
					for encounterIter,encounter in pairs(locks.shared.encounters) do
						GameTooltip:AddDoubleLine(" " .. encounter.name, GetCompletionIcon(encounter.isKilled));
					end
				else
					for key,value in pairs(locks) do
						if key == "shared" then
							-- Skip
						else
							GameTooltip:AddDoubleLine(Colorize(GetDifficultyInfo(key), app.DifficultyColors[key] or app.Colors.DefaultDifficulty), date("%c", value.reset));
							for encounterIter,encounter in pairs(value.encounters) do
								GameTooltip:AddDoubleLine(" " .. encounter.name, GetCompletionIcon(encounter.isKilled));
							end
						end
					end
				end
			end
		end

		if reference.OnTooltip then reference:OnTooltip(GameTooltip); end

		if app.Settings:GetTooltipSetting("Show:TooltipHelp") then
			if reference.g then
				-- If we're at the Auction House
				if AuctionFrame and AuctionFrame:IsShown() then
					GameTooltip:AddLine(L[(self.index > 0 and "OTHER_ROW_INSTRUCTIONS_AH") or "TOP_ROW_INSTRUCTIONS_AH"], 1, 1, 1);
				else
					GameTooltip:AddLine(L[(self.index > 0 and "OTHER_ROW_INSTRUCTIONS") or "TOP_ROW_INSTRUCTIONS"], 1, 1, 1);
				end
			end
			if refQuestID then
				GameTooltip:AddLine(L["QUEST_ROW_INSTRUCTIONS"], 1, 1, 1);
			end
		end
		-- Add info in tooltip for the header of a Window for whether it is locked or not
		if self.index == 0 then
			local owner = self:GetParent():GetParent();
			if owner and owner.isLocked then
				GameTooltip:AddLine(L["TOP_ROW_TO_UNLOCK"], 1, 1, 1);
			elseif app.Settings:GetTooltipSetting("Show:TooltipHelp") then
				GameTooltip:AddLine(L["TOP_ROW_TO_LOCK"], 1, 1, 1);
			end
		end

		--[[ ROW DEBUGGING ]
		GameTooltip:AddDoubleLine("Self",tostring(reference));
		GameTooltip:AddDoubleLine("Base",tostring(getmetatable(reference)));
		GameTooltip:AddLine("-- Ref Fields:");
		for key,val in pairs(reference) do
			GameTooltip:AddDoubleLine(key,tostring(val));
		end
		local fields = {
			"__type",
			"name",
			"key",
			"hash",
			"link",
			"sourceParent",
			"sourceIgnored",
			"collectible",
			"collected",
			"trackable",
			"saved",
		};
		GameTooltip:AddLine("-- Extra Fields:");
		for _,key in ipairs(fields) do
			GameTooltip:AddDoubleLine(key,tostring(reference[key]));
		end
		GameTooltip:AddDoubleLine("Row Indent",tostring(CalculateRowIndent(reference)));
		-- END DEBUGGING]]

		-- app.PrintDebug("OnRowEnter-Show");
		GameTooltip.MiscFieldsComplete = true;
		GameTooltip:Show();
		-- app.PrintDebug("OnRowEnter-Return");
	end
end
RowOnLeave = function (self)
	if GameTooltip then
		GameTooltip:ClearLines();
		GameTooltip:Hide();
		GameTooltipIcon.icon.Background:Hide();
		GameTooltipIcon.icon.Border:Hide();
		GameTooltipIcon:Hide();
		GameTooltipModel:Hide();
		GameTooltip.IsRefreshing = nil;
	end
end
CreateRow = function(self)
	local row = CreateFrame("Button", nil, self);
	row.index = #self.rows;
	if row.index == 0 then
		-- This means relative to the parent.
		row:SetPoint("TOPLEFT");
		row:SetPoint("TOPRIGHT");
	else
		-- This means relative to the row above this one.
		row:SetPoint("TOPLEFT", self.rows[row.index], "BOTTOMLEFT");
		row:SetPoint("TOPRIGHT", self.rows[row.index], "BOTTOMRIGHT");
	end
	tinsert(self.rows, row);

	-- Setup highlighting and event handling
	row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD");
	row:RegisterForClicks("LeftButtonDown","RightButtonDown");
	row:SetScript("OnClick", RowOnClick);
	row:SetScript("OnEnter", RowOnEnter);
	row:SetScript("OnLeave", RowOnLeave);
	row:EnableMouse(true);

	-- Label is the text information you read.
	row.Label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	row.Label:SetJustifyH("LEFT");
	row.Label:SetPoint("BOTTOM");
	row.Label:SetPoint("TOP");
	row:SetHeight(select(2, row.Label:GetFont()) + 4);

	-- Summary is the completion summary information. (percentage text)
	row.Summary = row:CreateFontString(nil, "ARTWORK", "GameFontNormal");
	row.Summary:SetJustifyH("RIGHT");
	row.Summary:SetPoint("BOTTOM");
	row.Summary:SetPoint("RIGHT");
	row.Summary:SetPoint("TOP");

	-- Background is used by the Map Highlight functionality.
	row.Background = row:CreateTexture(nil, "BACKGROUND");
	row.Background:SetPoint("LEFT", 4, 0);
	row.Background:SetPoint("BOTTOM");
	row.Background:SetPoint("RIGHT");
	row.Background:SetPoint("TOP");
	row.Background:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight");

	-- Indicator is used by the Instance Saves functionality.
	row.Indicator = row:CreateTexture(nil, "ARTWORK");
	row.Indicator:SetPoint("BOTTOM");
	row.Indicator:SetPoint("TOP");
	row.Indicator:SetWidth(row:GetHeight());

	-- Texture is the icon.
	row.Texture = row:CreateTexture(nil, "ARTWORK");
	row.Texture:SetPoint("BOTTOM");
	row.Texture:SetPoint("TOP");
	row.Texture:SetWidth(row:GetHeight());
	row.Texture.Background = row:CreateTexture(nil, "BACKGROUND");
	row.Texture.Background:SetPoint("BOTTOM");
	row.Texture.Background:SetPoint("TOP");
	row.Texture.Background:SetWidth(row:GetHeight());
	row.Texture.Border = row:CreateTexture(nil, "BORDER");
	row.Texture.Border:SetPoint("BOTTOM");
	row.Texture.Border:SetPoint("TOP");
	row.Texture.Border:SetWidth(row:GetHeight());

	-- Forced/External Update of a Tooltip produced by an ATT row to use the same function which created it
	row.UpdateTooltip = RowOnEnter;

	-- Clear the Row Data Initially
	ClearRowData(row);
	return row;
end
local function OnScrollBarMouseWheel(self, delta)
	self.ScrollBar:SetValue(self.ScrollBar.CurrentValue - delta);
end
local function OnScrollBarValueChanged(self, value)
	if self.CurrentValue ~= value then
		self.CurrentValue = value;
		self:GetParent():Refresh();
	end
end
local function ProcessGroup(data, object)
	if app.VisibilityFilter(object) then
		tinsert(data, object);
		if object.g and object.expanded then
			-- Delayed sort operation for this group prior to being shown
			local sortInfo = object.SortInfo;
			if sortInfo then
				app.SortGroup(object, sortInfo[1], sortInfo[2], sortInfo[3], sortInfo[4]);
			end
			for _,group in ipairs(object.g) do
				ProcessGroup(data, group);
			end
		end
	end
end
local function UpdateWindow(self, force, got)
	if self.data and app.IsReady then
		if app.Settings:GetTooltipSetting("Updates:AdHoc") then
			if force then
				self.HasPendingUpdate = true;
			end
			force = (force or self.HasPendingUpdate) and self:IsVisible();
		end
		-- app.PrintDebug("Update:",self.Suffix, force and "FORCE", self:IsVisible() and "VISIBLE");
		if force or self:IsVisible() then
			if self.rowData then wipe(self.rowData);
			else self.rowData = {}; end
			self.data.expanded = true;
			if not self.doesOwnUpdate and
				(force or (self.shouldFullRefresh and self:IsVisible())) then
				-- app.PrintDebug("TopLevelUpdateGroup",self.Suffix)
				app.TopLevelUpdateGroup(self.data, self);
				self.HasPendingUpdate = nil;
				-- app.PrintDebugPrior("Done")
			end

			-- Should the groups in this window be expanded prior to processing the rows for display
			if self.ExpandInfo then
				-- print("ExpandInfo",self.Suffix,self.ExpandInfo.Expand,self.ExpandInfo.Manual)
				ExpandGroupsRecursively(self.data, self.ExpandInfo.Expand, self.ExpandInfo.Manual);
				self.ExpandInfo = nil;
			end

			ProcessGroup(self.rowData, self.data);

			-- Does this user have everything?
			if self.data.total then
				if self.data.total <= self.data.progress then
					if #self.rowData < 1 then
						self.data.back = 1;
						tinsert(self.rowData, self.data);
					end
					if self.missingData then
						if got and self:IsVisible() then app:PlayCompleteSound(); end
						self.missingData = nil;
					end
					-- only add this info row if there is actually nothing visible in the list
					-- always a header row
					-- print("any data",#self.Container,#self.rowData,#self.data)
					if #self.rowData < 2 then
						tinsert(self.rowData, {
							["text"] = L["NO_ENTRIES"],
							["description"] = L["NO_ENTRIES_DESC"],
							["collectible"] = 1,
							["collected"] = 1,
							["back"] = 0.7
						});
					end
				else
					self.missingData = true;
				end
			else
				self.missingData = nil;
			end

			self:Refresh();
			-- app.PrintDebugPrior("Update:Done")
			return true;
		else
			local expireTime = self.ExpireTime;
			-- print("check ExpireTime",self.Suffix,expireTime)
			if expireTime and expireTime > 0 and expireTime < time() then
				-- app.PrintDebug(self.Suffix,"window is expired, removing from window cache")
				app.Windows[self.Suffix] = nil;
			end
		end
		-- app.PrintDebugPrior("Update:None")
	end
end
-- Allows a Window to set the root data object to itself and link the Window to the root data, if data exists
local function SetData(self, data)
	-- app.PrintDebug("Window:SetData",self.Suffix,data.text)
	self.data = data;
	if data then
		data.window = self;
	end
end
-- Allows a Window to build the groups hierarcy if it has .data
local function BuildData(self)
	local data = self.data;
	if data then
		-- app.PrintDebug("Window:BuildData",self.Suffix,data.text)
		BuildGroups(data);
	end
end
local backdrop = {
	bgFile = "Interface/Tooltips/UI-Tooltip-Background",
	edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
};
-- allows resetting a given ATT window
local function ResetWindow(suffix)
	app.Windows[suffix] = nil;
	app.print("Reset Window",suffix);
end
function app:GetWindow(suffix, parent, onUpdate)
	if app.GetCustomWindowParam(suffix, "reset") then
		ResetWindow(suffix);
	end
	local window = app.Windows[suffix];
	if not window then
		-- Create the window instance.
		-- print("Creating new Window Frame for",suffix)
		window = CreateFrame("FRAME", app:GetName() .. "-Window-" .. suffix, parent or UIParent, BackdropTemplateMixin and "BackdropTemplate");
		app.Windows[suffix] = window;
		window.Suffix = suffix;
		window.Refresh = Refresh;
		window.Toggle = Toggle;
		window.BaseUpdate = UpdateWindow;
		window.Update = onUpdate or app:CustomWindowUpdate(suffix) or UpdateWindow;
		window.SetVisible = SetVisible;
		window.StorePosition = StoreWindowPosition;
		window.SetData = SetData;
		window.BuildData = BuildData;

		window:SetScript("OnMouseWheel", OnScrollBarMouseWheel);
		window:SetScript("OnMouseDown", StartMovingOrSizing);
		window:SetScript("OnMouseUp", StopMovingOrSizing);
		window:SetScript("OnHide", StopMovingOrSizing);
		window:SetBackdrop(backdrop);
		window:SetBackdropBorderColor(1, 1, 1, 1);
		window:SetBackdropColor(0, 0, 0, 1);
		window:SetClampedToScreen(true);
		window:SetToplevel(true);
		window:EnableMouse(true);
		window:SetMovable(true);
		window:SetResizable(true);
		window:SetPoint("CENTER");
		--window:SetMinResize(96, 32);
		window:SetSize(300, 300);

		-- set the scaling for the new window if settings have been initialized
		local scale = app.Settings and app.Settings._Initialize and (suffix == "Prime" and app.Settings:GetTooltipSetting("MainListScale") or app.Settings:GetTooltipSetting("MiniListScale")) or 1;
		window:SetScale(scale);

		window:SetUserPlaced(true);
		window.data = {
			['text'] = suffix,
			['icon'] = "Interface\\Icons\\Ability_Spy.blp",
			['visible'] = true,
			['expanded'] = true,
			['g'] = {
				{
					['text'] = "No data linked to listing.",
					['visible'] = true
				}
			}
		};

		-- set whether this window lock is persistable between sessions
		if suffix == "Prime" or suffix == "CurrentInstance" or suffix == "RaidAssistant" or suffix == "WorldQuests" then
			window.lockPersistable = true;
		end

		window:Hide();

		-- The Close Button. It's assigned as a local variable so you can change how it behaves.
		window.CloseButton = CreateFrame("Button", nil, window, "UIPanelCloseButton");
		window.CloseButton:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1);
		window.CloseButton:SetSize(20, 20);
		window.CloseButton:SetScript("OnClick", OnCloseButtonPressed);

		-- The Scroll Bar.
		local scrollbar = CreateFrame("Slider", nil, window, "UIPanelScrollBarTemplate");
		scrollbar:SetPoint("TOP", window.CloseButton, "BOTTOM", 0, -15);
		scrollbar:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -4, 36);
		scrollbar:SetScript("OnValueChanged", OnScrollBarValueChanged);
		scrollbar.back = scrollbar:CreateTexture(nil, "BACKGROUND");
		scrollbar.back:SetColorTexture(0.1,0.1,0.1,1);
		scrollbar.back:SetAllPoints(scrollbar);
		scrollbar:SetMinMaxValues(1, 1);
		scrollbar:SetValueStep(1);
		scrollbar:SetObeyStepOnDrag(true);
		scrollbar.CurrentValue = 1;
		scrollbar:SetWidth(16);
		scrollbar:EnableMouseWheel(true);
		window:EnableMouseWheel(true);
		window.ScrollBar = scrollbar;

		-- The Corner Grip. (this isn't actually used, but it helps indicate to players that they can do something)
		local grip = window:CreateTexture(nil, "ARTWORK");
		grip:SetTexture(app.asset("grip"));
		grip:SetSize(16, 16);
		grip:SetTexCoord(0,1,0,1);
		grip:SetPoint("BOTTOMRIGHT", -5, 5);
		window.Grip = grip;

		-- The Row Container. This contains all of the row frames.
		local container = CreateFrame("FRAME", nil, window);
		container:SetPoint("TOPLEFT", window, "TOPLEFT", 0, -6);
		container:SetPoint("RIGHT", scrollbar, "LEFT", 0, 0);
		container:SetPoint("BOTTOM", window, "BOTTOM", 0, 6);
		window.Container = container;
		container.rows = {};
		scrollbar:SetValue(1);
		container:Show();
		window:Update();
		app.ResetCustomWindowParam(suffix);
	end
	return window;
end
end)();

do	-- Dynamic/Main Data
local RecursiveParentMapping = {};
-- Recurses upwards in the group hierarchy until finding the group with the specified value in the specified field. The
-- set of groups crossed while searching will all have their mapping value set to the found group.
-- While recursing, the mapping will be checked first if the current group has already been mapped, and return that mapping instead
local function RecursiveParentMapper(group, field, value)
	if not group then return; end
	-- is this group already mapped?
	local mapped = RecursiveParentMapping[group];
	if mapped then return mapped; end
	-- is this group the one for the mapping, or recurse to the parent
	mapped = (group[field] == value and group) or RecursiveParentMapper(group.parent, field, value);
	if mapped then
		RecursiveParentMapping[group] = mapped;
		return mapped;
	end
end

-- Common function set as the OnUpdate for a group which will build itself a 'simple' version of the
-- content which matches the specified .dynamic 'field' of the group
-- NOTE: Content must be cached using the dynamic 'field'
local DynamicCategory_Simple = function(self)
	local dynamicCache = fieldCache[self.dynamic];
	if dynamicCache then
		local rootATT = app:GetWindow("Prime").data;
		local top, topText, thing;
		local topHeaders, dynamicValue, clearSubgroups = {}, self.dynamic_value, not self.dynamic_withsubgroups;
		if dynamicValue then
			local dynamicValueCache, thingKeys = dynamicCache[dynamicValue], app.ThingKeys;
			if dynamicValueCache then
				-- app.PrintDebug("Build Dynamic Group",self.dynamic,self.dynamic_value)
				for _,source in pairs(dynamicValueCache) do
					-- only pull in actual 'Things' to the simple dynamic group
					if thingKeys[source.key] then
						-- find the top-level parent of the Thing
						top = RecursiveParentMapper(source, "parent", rootATT);
						-- create/match the expected top header
						topText = top and top.text;
						if topText then
							-- store a copy of this top header if we dont have it
							if not topHeaders[topText] then
								-- app.PrintDebug("New Dynamic Top",self.dynamic,":",dynamicValue,"==>",topText)
								-- app.PrintTable(topHeaders[topText])
								topHeaders[topText] = CreateObject(top, true);
							end
							-- put a copy of the Thing into the matching top category (no uniques since only 1 per cached Thing)
							-- remove it from being considered a cost within the dynamic category
							thing = CreateObject(source, clearSubgroups);
							thing.collectibleAsCost = false;
							NestObject(topHeaders[topText], thing);
						end
					end
				end
				-- app.PrintDebugPrior("Complete")
				-- dynamic groups for Things within a specific Value of a Type are expected to be collected under a Header of the Type itself
			else app.print("Failed to build Simple Dynamic Category: No data cached for key & value",self.dynamic,self.dynamic_value); end
		else
			for id,sources in pairs(dynamicCache) do
				for _,source in pairs(sources) do
					-- find the top-level parent of the Thing
					top = RecursiveParentMapper(source, "parent", rootATT);
					-- create/match the expected top header
					topText = top and top.text;
					if topText then
						-- store a copy of this top header if we dont have it
						if not topHeaders[topText] then
							-- app.PrintDebug("New Dynamic Top",self.dynamic,":",dynamicValue,"==>",topText)
							-- app.PrintTable(topHeaders[topText])
							topHeaders[topText] = CreateObject(top, true);
						end
						-- put a copy of the Thing into the matching top category (no uniques since only 1 per cached Thing)
						-- remove it from being considered a cost within the dynamic category
						thing = CreateObject(source, clearSubgroups);
						thing.collectibleAsCost = false;
						NestObject(topHeaders[topText], thing);
					end
				end
			end
			-- dynamic groups for general Types are ignored for the source tooltips
			self.sourceIgnored = true;
		end
		-- change the text color of the dynamic group to help indicate it is not included in the window total, if it's ignored
		if self.sourceIgnored then
			self.text = Colorize(self.text, app.Colors.SourceIgnored);
		end
		-- sort all of the Things by name in each top header and put it under the dynamic group
		for _,header in pairs(topHeaders) do
			-- delay-sort the groups in each categorized header
			app.SortGroupDelayed(header, "name");
			NestObject(self, header);
		end
		-- reset indents and such
		BuildGroups(self, self.g);
		-- delay-sort the top level groups
		app.SortGroupDelayed(self, "name");
		-- make sure these things are cached so they can be updated when collected, but run the caching after other dynamic groups are filled
		app.FunctionRunner.Run(app.CacheFields, self);
		-- run a direct update on itself after being populated
		app.DirectGroupUpdate(self);
	else app.print("Failed to build Simple Dynamic Category: No cached data for key",self.dynamic) end
end

-- Common function set as the OnUpdate for a group which will build itself a 'nested' version of the
-- content which matches the specified .dynamic 'field' and .dynamic_value of the group
local DynamicCategory_Nested = function(self)
	-- dynamic groups are ignored for the source tooltips if they aren't constrained to a specific value
	self.sourceIgnored = not self.dynamic_value;
	-- change the text color of the dynamic group to help indicate it is not included in the window total, if it's ignored
	if self.sourceIgnored then
		self.text = Colorize(self.text, app.Colors.SourceIgnored);
	end
	-- pull out all Things which should go into this category based on field & value
	NestObjects(self, app:BuildSearchResponse(app:GetDataCache().g, self.dynamic, self.dynamic_value, not self.dynamic_withsubgroups));
	-- reset indents and such
	BuildGroups(self, self.g);
	-- delay-sort the top level groups
	app.SortGroupDelayed(self, "name");
	-- make sure these things are cached so they can be updated when collected, but run the caching after other dynamic groups are filled
	app.FunctionRunner.Run(app.CacheFields, self);
	-- run a direct update on itself after being populated
	app.DirectGroupUpdate(self);
end

function app:GetDataCache()
	-- app.PrintDebug("Start app.GetDataCache")
	-- app.PrintMemoryUsage()
	local dynamicSetting = app.Settings:Get("Dynamic:Style") or 0;
	local Filler = (dynamicSetting == 2 and DynamicCategory_Nested) or
					(dynamicSetting == 1 and DynamicCategory_Simple) or nil;

	-- Adds a Dynamic Category Filler function to the Function Runner which will fill the provided group using the field and value
	local function DynamicCategory(group, field, value)
		-- mark the top group as dynamic for the field which it used (so popouts under the dynamic header are considered unique from other dynamic popouts)
		group.dynamic = field;
		group.dynamic_value = value;
		-- only perform dynamic update logic on 1 group per frame to reduce unnecessary lag
		app.FunctionRunner.SetPerFrame(1);
		-- run a direct update on itself after being populated if the Filler exists
		if Filler then
			app.FunctionRunner.Run(Filler, group);
		end
		return group;
	end

	-- Nests Dynamic categories created based on the field used to cache groups.
	-- Can indicate to keep sub-group Things if desired.
	local function NestDynamicValueCategories(dynamicCategory, field, keepSubGroups)
		local cat;
		local SearchForObject = app.SearchForObject;
		local cache = fieldCache[field];
		for id,_ in pairs(cache) do
			-- create a cloned version of the cached object, or create a new object from the Creator
			cat = CreateObject(SearchForObject(field, id) or { [field] = id }, true);
			cat.parent = dynamicCategory;
			cat.dynamic_withsubgroups = keepSubGroups;
			-- don't copy maps into dynamic headers, since when the dynamic content is cached it can be weird
			cat.maps = nil;
			cat.sourceParent = nil;
			cat.symlink = nil;
			-- if the Dynamic Value category itself is not collectible, then make sure it isn't filtered
			if not cat.collectible then
				cat.u = nil;
			end
			NestObject(dynamicCategory, DynamicCategory(cat, field, id));
		end
		-- Make sure the Dynamic Category group is sorted when opened since order isn't guaranteed by the table
		app.SortGroupDelayed(dynamicCategory, "name");
	end

	-- Adds all the Dynamic groups into the provided groups (g)
	local function AddDynamicGroups(primeData)
		local g = primeData.g;
		-- don't cache maps for dynamic content because it's already source-cached for the respective maps
		app.ToggleCacheMaps(true);
		app.print(sformat(L["LOADING_FORMAT"], L["DYNAMIC_CATEGORY_LABEL"]));

		-- Future Unobtainable
		local db = {}; -- temp
		db.parent = primeData;
		db.back = 1;
		db.name = L["FUTURE_UNOBTAINABLE"];
		db.text = db.name;
		db.description = L["FUTURE_UNOBTAINABLE_TOOLTIP"];
		db.icon = 134399; -- inv_misc_qirajicrystal_05
		db.dynamic_withsubgroups = true;
		tinsert(g, DynamicCategory(db, "rwp"));

		-- Artifacts (Dynamic)
		local db = app.CreateNPC(-10067);
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "artifactID"));

		-- Azerite Essences (Dynamic)
		local db = app.CreateNPC(-852);
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "azeriteEssenceID"));

		-- Battle Pets - Dynamic
		local db = {};
		db.text = AUCTION_CATEGORY_BATTLE_PETS;
		db.name = db.text;
		db.icon = app.asset("Category_PetJournal");
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "speciesID"));

		-- Conduits - Dynamic
		-- local db = app.CreateNPC(-981);
		-- db.name = db.name .. " (" .. EXPANSION_NAME8 .. ")";
		-- db.parent = primeData;
		-- tinsert(g, DynamicCategory(db, "conduitID"));

		-- Factions (Dynamic)
		db = {};
		db.name = L["FACTIONS"];
		db.text = Colorize(db.name, app.Colors.SourceIgnored);
		db.icon = app.asset("Category_Factions");
		db.parent = primeData;
		db.sourceIgnored = true;
		tinsert(g, db);
		NestDynamicValueCategories(db, "factionID", true);

		-- Flight Paths (Dynamic)
		db = {};
		db.text = L["FLIGHT_PATHS"];
		db.name = db.text;
		db.icon = app.asset("Category_FlightPaths");
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "flightPathID"));

		-- Followers (Dynamic)
		local db = app.CreateNPC(-101);
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "followerID"));

		-- Illusions - Dynamic
		db = {};
		db.text = L["FILTER_ID_TYPES"][103];
		db.name = db.text;
		db.icon = 132853;
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "illusionID"));

		-- Mounts - Dynamic
		db = {};
		db.text = MOUNTS;
		db.name = db.text;
		db.icon = app.asset("Category_Mounts");
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "mountID"));

		-- Professions - Dynamic
		db = {};
		db.name = TRADE_SKILLS;
		db.text = Colorize(db.name, app.Colors.SourceIgnored);
		db.icon = app.asset("Category_Professions");
		db.parent = primeData;
		db.sourceIgnored = true;
		tinsert(g, db);
		NestDynamicValueCategories(db, "professionID");

		-- Runeforge Powers - Dynamic
		-- local db = app.CreateNPC(-364);
		-- db.name = db.name .. " (" .. EXPANSION_NAME8 .. ")";
		-- db.parent = primeData;
		-- tinsert(g, DynamicCategory(db, "runeforgePowerID"));

		-- Titles - Dynamic
		db = {};
		db.icon = app.asset("Category_Titles");
		db.text = PAPERDOLL_SIDEBAR_TITLES;
		db.name = db.text;
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "titleID"));

		-- Toys - Dynamic
		db = {};
		db.icon = app.asset("Category_ToyBox");
		db.f = 102;
		db.text = TOY_BOX;
		db.name = db.text;
		db.parent = primeData;
		tinsert(g, DynamicCategory(db, "toyID"));

		-- add an OnEnd function for the FunctionRunner to print being done
		app.FunctionRunner.OnEnd(function()
			app.ToggleCacheMaps();
			app.print(sformat(L["READY_FORMAT"], L["DYNAMIC_CATEGORY_LABEL"]));
		end);
	end

	-- Update the Row Data by filtering raw data (this function only runs once)
	local allData = setmetatable({}, {
		__index = function(t, key)
			-- app.PrintDebug("Top-Root-Get",key)
			if key == "title" then
				return t.mb_title1..DESCRIPTION_SEPARATOR..t.mb_title2;
			end
			if key == "mb_title1" then return app.Settings:GetModeString(); end
			if key == "mb_title2" then return t.total == 0 and L["MAIN_LIST_REQUIRES_REFRESH"] or app.GetNumberOfItemsUntilNextPercentage(t.progress, t.total); end
			if key == "visible" then return true; end
		end,
		__newindex = function(t, key, val)
			-- app.PrintDebug("Top-Root-Set",key,val)
			if key == "visible" then
				return;
			end
			rawset(t, key, val);
		end
	});
	allData.expanded = true;
	allData.icon = app.asset("content");
	allData.texcoord = {429 / 512, (429 + 36) / 512, 217 / 256, (217 + 36) / 256};
	allData.previewtexcoord = {1 / 512, (1 + 72) / 512, 75 / 256, (75 + 72) / 256};
	allData.text = L["TITLE"];
	allData.description = L["DESCRIPTION"];
	allData.font = "GameFontNormalLarge";
	allData.progress = 0;
	allData.total = 0;
	local g, db = {};
	allData.g = g;

	-- Dungeons & Raids
	db = {};
	db.g = app.Categories.Instances;
	db.expanded = false;
	db.text = GROUP_FINDER;
	db.name = db.text;
	db.icon = app.asset("Category_D&R");
	tinsert(g, db);

	-- Zones
	if app.Categories.Zones then
		db = {};
		db.g = app.Categories.Zones;
		db.expanded = false;
		db.text = BUG_CATEGORY2;
		db.name = db.text;
		db.icon = app.asset("Category_Zones")
		tinsert(g, db);
	end

	-- World Drops
	if app.Categories.WorldDrops then
		db = {};
		db.g = app.Categories.WorldDrops;
		db.isWorldDropCategory = true;
		db.expanded = false;
		db.text = TRANSMOG_SOURCE_4;
		db.name = db.text;
		db.icon = app.asset("Category_WorldDrops");
		tinsert(g, db);
	end

	-- Group Finder
	if app.Categories.GroupFinder then
		db = {};
		db.g = app.Categories.GroupFinder;
		db.expanded = false;
		db.text = DUNGEONS_BUTTON;
		db.name = db.text;
		db.icon = app.asset("Category_GroupFinder")
		tinsert(g, db);
	end

	-- Achievements
	if app.Categories.Achievements then
		db = app.CreateNPC(-4);
		db.g = app.Categories.Achievements;
		db.expanded = false;
		db.text = TRACKER_HEADER_ACHIEVEMENTS;
		db.icon = app.asset("Category_Achievements")
		tinsert(g, db);
	end

	-- Expansion Features
	if app.Categories.ExpansionFeatures then
		db = {};
		db.g = app.Categories.ExpansionFeatures;
		db.lvl = 10;
		db.expanded = false;
		db.text = GetCategoryInfo(15301);
		db.name = db.text;
		db.icon = app.asset("Category_ExpansionFeatures");
		tinsert(g, db);
	end

	-- Holidays
	if app.Categories.Holidays then
		db = app.CreateNPC(-3);
		db.g = app.Categories.Holidays;
		db.icon = app.asset("Category_Holidays");
		db.isHolidayCategory = true;
		db.expanded = false;
		db.text = GetItemSubClassInfo(15,3);
		tinsert(g, db);
	end

	-- Events
	if app.Categories.WorldEvents then
		db = {};
		db.text = BATTLE_PET_SOURCE_7;
		db.name = db.text;
		db.description = "These events occur at different times in the game's timeline, typically as one time server wide events. Special celebrations such as Anniversary events and such may be found within this category.";
		db.icon = app.asset("Category_Event");
		db.g = app.Categories.WorldEvents;
		db.expanded = false;
		tinsert(g, db);
	end

	-- Promotions
	if app.Categories.Promotions then
		db = {};
		db.text = BATTLE_PET_SOURCE_8;
		db.name = db.text;
		db.description = "This section is for real world promotions that seeped extremely rare content into the game prior to some of them appearing within the In-Game Shop.";
		db.icon = app.asset("Category_Promo");
		db.g = app.Categories.Promotions;
		db.isPromotionCategory = true;
		db.expanded = false;
		tinsert(g, db);
	end

	-- Pet Battles
	if app.Categories.PetBattles then
		db = app.CreateNPC(-796);
		db.g = app.Categories.PetBattles;
		db.lvl = 3; -- Must be 3 to train (used to be 5 pre-scale)
		db.expanded = false;
		db.text = SHOW_PET_BATTLES_ON_MAP_TEXT; -- Pet Battles
		db.icon = app.asset("Category_PetBattles");
		tinsert(g, db);
	end

	-- PvP
	if app.Categories.PVP then
		db = {};
		db.g = app.Categories.PVP;
		db.isPVPCategory = true;
		db.expanded = false;
		db.text = STAT_CATEGORY_PVP;
		db.name = db.text;
		db.icon = app.asset("Category_PvP");
		tinsert(g, db);
	end

	-- Craftables
	if app.Categories.Craftables then
		db = {};
		db.g = app.Categories.Craftables;
		db.DontEnforceSkillRequirements = true;
		db.expanded = false;
		db.text = LOOT_JOURNAL_LEGENDARIES_SOURCE_CRAFTED_ITEM;
		db.name = db.text;
		db.icon = app.asset("Category_Crafting");
		tinsert(g, db);
	end

	-- Professions
	if app.Categories.Professions then
		db = app.CreateNPC(-38);
		db.g = app.Categories.Professions;
		db.expanded = false;
		db.text = TRADE_SKILLS;
		db.icon = app.asset("Category_Professions");
		db.description = "This section will only show your character's professions outside of Account and Debug Mode.";
		tinsert(g, db);
	end

	-- Secrets
	if app.Categories.Secrets then
		db = app.CreateNPC(-22);
		db.g = app.Categories.Secrets;
		db.expanded = false;
		tinsert(g, db);
	end

	-- Gear Sets
	if app.Categories.GearSets then
		db = {};
		db.g = app.Categories.GearSets;
		db.expanded = false;
		db.text = LOOT_JOURNAL_ITEM_SETS;
		db.name = db.text;
		db.icon = app.asset("Category_ItemSets");
		tinsert(g, db);
	end

	-- In-Game Store
	if app.Categories.InGameShop then
		db = {};
		db.g = app.Categories.InGameShop;
		db.expanded = false;
		db.text = BATTLE_PET_SOURCE_10;
		db.name = db.text;
		db.icon = app.asset("Category_InGameShop");
		tinsert(g, db);
	end

	-- Black Market
	if app.Categories.BlackMarket then
		db = app.CreateNPC(-94);
		db.g = app.Categories.BlackMarket;
		db.expanded = false;
		db.text = BLACK_MARKET_AUCTION_HOUSE;
		db.icon = app.asset("Category_Blackmarket");
		tinsert(g, db);
	end

	-- Factions
	if app.Categories.Factions then
		db = app.CreateNPC(-6013);
		db.g = app.Categories.Factions;
		db.expanded = false;
		db.text = L["FACTIONS"];
		db.icon = app.asset("Category_Factions");
		tinsert(g, db);
	end

	--[[
	-- Never Implemented
	if app.Categories.NeverImplemented then
		db = {};
		db.expanded = false;
		db.g = app.Categories.NeverImplemented;
		db.text = "Never Implemented";
		tinsert(g, db);
	end

	-- Unsorted
	if app.Categories.Unsorted then
		db = {};
		db.g = app.Categories.Unsorted;
		db.expanded = false;
		db.text = "Unsorted";
		tinsert(g, db);
	end

	-- Models (Dynamic)
	db = app.CreateAchievement(9924, (function()
		local cache = GetTempDataMember("MODEL_CACHE");
		if not cache then
			cache = {};
			SetTempDataMember("MODEL_CACHE", cache);
			for i=1,78092,1 do
				tinsert(cache, {["displayID"] = i,["text"] = "Model #" .. i});
			end
		end
		return cache;
	end)());
	db.expanded = false;
	db.text = "Models (Dynamic)";
	tinsert(g, db);
	--]]

	-- Items (Dynamic)
	--[[
	db = {};
	db.g = (function()
		local cache = GetTempDataMember("ITEM_CACHE");
		if not cache then
			cache = {};
			SetTempDataMember("ITEM_CACHE", cache);
			for i=166000,1,-1 do
				tinsert(cache, app.CreateItem(i));
			end
		end
		return cache;
	end)();
	db.expanded = false;
	db.text = "All Items (Dynamic)";
	tinsert(g, db);
	]]--

	--[[
	-- SUPER SECRETTTT!
	-- Artifacts (Dynamic)
	db = app.CreateAchievement(11171, (function()
		local cache = GetTempDataMember("ARTIFACT_CACHE");
		if not cache then
			cache = {};
			SetTempDataMember("ARTIFACT_CACHE", cache);
			for i=1,10000,1 do
				if C_ArtifactUI_GetAppearanceInfoByID(i) then
					tinsert(cache, app.CreateArtifact(i));
				end
			end
		end
		return cache;
	end)());
	db.expanded = false;
	db.text = "Artifacts (Dynamic)";
	tinsert(g, db);

	-- Factions (Dynamic)
	db = app.CreateAchievement(11177, (function()
		local cache = GetTempDataMember("FACTION_CACHE");
		if not cache then
			cache = {};
			SetTempDataMember("FACTION_CACHE", cache);
			for i=1,5000,1 do
				tinsert(cache, app.CreateFaction(i));
			end
		end
		return cache;
	end)());
	db.expanded = false;
	db.text = "Factions (Dynamic)";
	tinsert(g, db);
	--]]



	--[[

	-- Gear Sets
	function SortGearSetInformation(a,b)
		local first = a.uiOrder - b.uiOrder;
		if first == 0 then return a.setID < b.setID; end
		return first < 0;
	end
	function SortGearSetSources(a,b)
		local first = a.invType - b.invType;
		if first == 0 then return a.invType < b.invType; end
		return first < 0;
	end
	tinsert(g, (function()
		--if true then return nil; end
		local db = GetTempDataMember("GEAR_SET_CACHE", nil);
		if not db then
			db = {};
			db.expanded = false;
			db.text = "Item Sets";
			SetTempDataMember("GEAR_SET_CACHE", db);
		end

		-- Rebuild the cache every time.
		cache = {};
		db.g = cache;
		--SetDataMember("GEAR_SET_CACHE", cache);
		local sets = C_TransmogSets.GetAllSets();
		if sets then
			local gearSets = {};
			for index = 1,#sets do
				local s = sets[index];
				if s then
					local sources = {};
					tinsert(gearSets, setmetatable({ ["setID"] = s.setID, ["uiOrder"] = s.uiOrder, ["g"] = sources }, app.BaseGearSet));
					for sourceID, value in pairs(C_TransmogSets.GetSetSources(s.setID)) do
						local _, appearanceID = C_TransmogCollection_GetAppearanceSourceInfo(sourceID);
						if appearanceID then
							for i, otherSourceID in ipairs(C_TransmogCollection_GetAllAppearanceSources(appearanceID)) do
								tinsert(sources, setmetatable({ s = otherSourceID }, app.BaseGearSource));
							end
						else
							tinsert(sources, setmetatable({ s = sourceID }, app.BaseGearSource));
						end
					end
					app.Sort(sources, SortGearSetSources);
				end
			end
			app.Sort(gearSets, SortGearSetInformation);

			-- Let's build some headers!
			local headers = {};
			local header, subheader, lastHeader, lastSubHeader, lastHeaderText, lastSubHeaderText;
			for i, gearSet in ipairs(gearSets) do
				header = gearSet.header;
				if header then
					if header ~= lastHeaderText then
						if headers[header] then
							lastHeader = headers[header];
						else
							lastHeader = setmetatable({ ["setID"] = gearSet.setID, ["subheaders"] = {}, ["g"] = {} }, app.BaseGearSetHeader);
							tinsert(cache, lastHeader);
							lastHeader = lastHeader;
							headers[header] = lastHeader;
						end
						lastHeaderText = header;
						lastSubHeaderText = nil;
					end
				else
					lastHeader = cache;
					lastHeaderText = header;
				end
				subheader = gearSet.subheader;
				if subheader then
					if subheader ~= lastSubHeaderText then
						if lastHeader and lastHeader.subheaders then
							if lastHeader.subheaders[subheader] then
								lastSubHeader = lastHeader.subheaders[subheader];
							else
								lastSubHeader = setmetatable({ ["setID"] = gearSet.setID, ["g"] = { } }, app.BaseGearSetSubHeader);
								tinsert(lastHeader and lastHeader.g or lastHeader, lastSubHeader);
								lastSubHeader = lastSubHeader;
								lastHeader.subheaders[subheader] = lastSubHeader;
							end
						else
							lastSubHeader = setmetatable({ ["setID"] = gearSet.setID, ["g"] = { } }, app.BaseGearSetSubHeader);
							tinsert(lastHeader and lastHeader.g or lastHeader, lastSubHeader);
							lastSubHeader = lastSubHeader;
						end
						lastSubHeaderText = subheader;
					end
				else
					lastSubHeader = lastHeader;
					lastSubHeaderText = subheader;
				end
				gearSet.uiOrder = nil;
				tinsert(lastSubHeader and lastSubHeader.g or lastSubHeader, gearSet);
			end
		end
		return db;
	end)());
	--]]


	-- Achievements (Dynamic!)
	--[[
	local achievementsCategory = app.CreateNPC(-4, {});
	achievementsCategory.expanded = false;
	achievementsCategory.achievements = {};
	table.insert(g, achievementsCategory);
	]]--

	-- Track Deaths!
	tinsert(g, app:CreateDeathClass());

	-- Yourself.
	tinsert(g, app.CreateUnit("player", {
		["description"] = L["DEBUG_LOGIN"],
		["races"] = { app.RaceIndex },
		["c"] = { app.ClassIndex },
		["r"] = app.FactionID,
		["collected"] = 1,
		["nmr"] = false,
		["OnUpdate"] = function(self)
			self.lvl = app.Level;
			if app.MODE_DEBUG then
				self.collectible = true;
			else
				self.collectible = false;
			end
		end
	}));

	-- Create Dynamic Groups Button
	if dynamicSetting > 0 then
		tinsert(g, {
			["text"] = sformat(L["CLICK_TO_CREATE_FORMAT"], L["DYNAMIC_CATEGORY_LABEL"]);
			["description"] = dynamicSetting == 1 and L["DYNAMIC_CATEGORY_SIMPLE_TOOLTIP"] or L["DYNAMIC_CATEGORY_NESTED_TOOLTIP"],
			["icon"] = 4200123,	-- misc-rnrgreengobutton
			["OnUpdate"] = app.AlwaysShowUpdate,
			["OnClick"] = function(row, button)
				local ref = row.ref;
				ref.OnClick = nil;
				ref.OnUpdate = nil;
				ref.visible = nil;
				local primeData = ref.parent;
				if primeData then
					AddDynamicGroups(primeData);
				end
			end,
		});
	end

	-- The Main Window's Data
	app.refreshDataForce = true;
	-- app.PrintMemoryUsage("Prime.Data Ready")
	local primeWindow = app:GetWindow("Prime");
	primeWindow:SetData(allData);
	-- app.PrintMemoryUsage("Prime Window Data Set")
	primeWindow:BuildData();
	-- app.PrintMemoryUsage()
	-- app.PrintDebug("Begin Cache Prime")
	CacheFields(allData);
	-- app.PrintDebugPrior("Ended Cache Prime")
	-- app.PrintMemoryUsage()

	-- Now build the hidden "Unsorted" Window's Data
	allData = {};
	allData.expanded = true;
	allData.icon = app.asset("content");
	allData.texcoord = {429 / 512, (429 + 36) / 512, 217 / 256, (217 + 36) / 256};
	allData.previewtexcoord = {1 / 512, (1 + 72) / 512, 75 / 256, (75 + 72) / 256};
	allData.font = "GameFontNormalLarge";
	allData.text = L["TITLE"] .. " (Unsorted) " .. app.Version;
	allData.title = L["UNSORTED_1"];
	allData.description = L["UNSORTED_DESC"];
	allData.visible = true;
	allData.progress = 0;
	allData.total = 0;
	local g, db = {};
	allData.g = g;

	-- Never Implemented Flight Paths (Dynamic)
	local flightPathsCategory_NYI = {};
	flightPathsCategory_NYI.g = {};
	flightPathsCategory_NYI.fps = {};
	flightPathsCategory_NYI.expanded = false;
	flightPathsCategory_NYI.icon = app.asset("Category_FlightPaths");
	flightPathsCategory_NYI.text = L["FLIGHT_PATHS"];

	-- Never Implemented
	if app.Categories.NeverImplemented then
		db = {};
		db.expanded = false;
		db.g = app.Categories.NeverImplemented;
		db.name = L["NEVER_IMPLEMENTED"];
		db.text = db.name;
		db.description = L["NEVER_IMPLEMENTED_DESC"];
		tinsert(g, db);
		--tinsert(db.g, 1, flightPathsCategory_NYI);
		CacheFields(db);
	end
	-- Hidden Achievement Triggers
	if app.Categories.HiddenAchievementTriggers then
		db = {};
		db.expanded = false;
		db.g = app.Categories.HiddenAchievementTriggers;
		db.name = "Hidden Achievement Triggers";
		db.text = db.name;
		db.description = "Hidden Achievement Triggers";
		tinsert(g, db);
		--app.ToggleCacheMaps(true);
		--CacheFields(db);
		--app.ToggleCacheMaps();
	end

	-- Hidden Quest Triggers
	if app.Categories.HiddenQuestTriggers then
		db = {};
		db.expanded = false;
		db.g = app.Categories.HiddenQuestTriggers;
		db.name = L["HIDDEN_QUEST_TRIGGERS"];
		db.text = db.name;
		db.description = L["HIDDEN_QUEST_TRIGGERS_DESC"];
		tinsert(g, db);
		app.ToggleCacheMaps(true);
		CacheFields(db);
		app.ToggleCacheMaps();
	end

	-- Poor Quality Items
	if app.Categories.PoorQualityItems then
		db = {};
		db.expanded = false;
		db.g = app.Categories.PoorQualityItems;
		db.name = "Poor Quality Items";
		db.text = db.name;
		db.description = "Poor Quality Items";
		tinsert(g, db);
		--app.ToggleCacheMaps(true);
		--CacheFields(db);
		--app.ToggleCacheMaps();
	end

	-- Common Quality Items
	if app.Categories.CommonQualityItems then
		db = {};
		db.expanded = false;
		db.g = app.Categories.CommonQualityItems;
		db.name = "Common Quality Items";
		db.text = db.name;
		db.description = "Common Quality Items";
		tinsert(g, db);
		--app.ToggleCacheMaps(true);
		--CacheFields(db);
		--app.ToggleCacheMaps();
	end

	-- Unsorted
	if app.Categories.Unsorted then
		db = {};
		db.g = app.Categories.Unsorted;
		db.expanded = false;
		db.name = L["UNSORTED_1"];
		db.text = db.name;
		db.description = L["UNSORTED_DESC_2"];
		-- since unsorted is technically auto-populated, anything nested under it is considered 'missing' in ATT
		db._missing = true;
		tinsert(g, db);
		app.ToggleCacheMaps(true);
		CacheFields(db);
		app.ToggleCacheMaps();
	end
	local unsorted = app:GetWindow("Unsorted");
	unsorted:SetData(allData);
	unsorted:BuildData();

	--[[
	local buildCategoryEntry = function(self, headers, searchResults, inst)
		local header = self;
		for j,o in ipairs(searchResults) do
			if o.u and o.u == 1 then
				return nil;
			else
				for key,value in pairs(o) do rawset(inst, key, value); end
				if o.parent then
					if not o.sourceQuests then
						local questID = GetRelativeValue(o, "questID");
						if questID then
							if not inst.sourceQuests then
								inst.sourceQuests = {};
							end
							if not contains(inst.sourceQuests, questID) then
								tinsert(inst.sourceQuests, questID);
							end
						else
							local sourceQuests = GetRelativeValue(o, "sourceQuests");
							if sourceQuests then
								if not inst.sourceQuests then
									inst.sourceQuests = {};
									for k,questID in ipairs(sourceQuests) do
										tinsert(inst.sourceQuests, questID);
									end
								else
									for k,questID in ipairs(sourceQuests) do
										if not contains(inst.sourceQuests, questID) then
											tinsert(inst.sourceQuests, questID);
										end
									end
								end
							end
						end
					end

					if GetRelativeValue(o, "isHolidayCategory") then
						header = headers[-3];
						if not header then
							header = app.CreateNPC(-3);
							headers[-3] = header;
							tinsert(self.g, header);
							header.parent = self;
							header.g = {};
						end
					elseif GetRelativeValue(o, "isPromotionCategory") then
						header = headers["promo"];
						if not header then
							header = {};
							header.text = BATTLE_PET_SOURCE_8;
							header.icon = app.asset("Category_Promo");
							headers["promo"] = header;
							tinsert(self.g, header);
							header.parent = self;
							header.g = {};
						end
					elseif GetRelativeValue(o, "isPVPCategory") then
						header = headers["pvp"];
						if not header then
							header = {};
							header.text = PVP;
							header.icon = app.asset("Category_PvP");
							headers["pvp"] = header;
							tinsert(self.g, header);
							header.parent = self;
							header.g = {};
						end
					elseif o.parent.headerID == 0 or o.parent.headerID == -1 or o.parent.headerID == -82 or GetRelativeValue(o, "isWorldDropCategory") then
						header = headers["drop"];
						if not header then
							header = {};
							header.text = BATTLE_PET_SOURCE_1;
							header.icon = app.asset("Category_WorldDrops");
							headers["drop"] = header;
							tinsert(self.g, header);
							header.parent = self;
							header.g = {};
						end
					elseif o.parent.key == "npcID" then
						if GetRelativeValue(o, "headerID") == -2 then
							header = headers[-2];
							if not header then
								header = app.CreateNPC(-2);
								headers[-2] = header;
								tinsert(self.g, header);
								header.parent = self;
								header.g = {};
							end
						else
							header = headers["drop"];
							if not header then
								header = {};
								header.text = BATTLE_PET_SOURCE_1;
								header.icon = app.asset("Category_WorldDrops");
								headers["drop"] = header;
								tinsert(self.g, header);
								header.parent = self;
								header.g = {};
							end
						end
					elseif o.parent.key == "categoryID" then
						header = headers["crafted"];
						if not header then
							header = {};
							header.text = LOOT_JOURNAL_LEGENDARIES_SOURCE_CRAFTED_ITEM;
							header.icon = app.asset("Category_Crafting");
							headers["crafted"] = header;
							tinsert(self.g, header);
							header.parent = self;
							header.g = {};
						end
					else
						local headerID = GetDeepestRelativeValue(o, "headerID");
						if headerID then
							header = headers[headerID];
							if not header then
								header = app.CreateNPC(headerID);
								headers[headerID] = header;
								tinsert(self.g, header);
								header.parent = self;
								header.g = {};
							end
						end
					end
				end
			end
		end
		inst.parent = header;
		inst.progress = nil;
		inst.total = nil;
		inst.g = nil;
		tinsert(inst.parent.g, inst);
		return inst;
	end
	-- ]]

	-- Update Achievement data.
	--[[
	local function cacheAchievementData(self, categories, g)
		if g then
			for i,o in ipairs(g) do
				if o.achievementCategoryID then
					categories[o.achievementCategoryID] = o;
					if not o.g then
						o.g = {};
					else
						cacheAchievementData(self, categories, o.g);
					end
				elseif o.achievementID then
					self.achievements[o.achievementID] = o;
				end
			end
		end
	end
	local function getAchievementCategory(categories, achievementCategoryID)
		local c = categories[achievementCategoryID];
		if not c then
			c = app.CreateAchievementCategory(achievementCategoryID);
			categories[achievementCategoryID] = c;
			c.g = {};

			local p = getAchievementCategory(categories, c.parentCategoryID);
			if not p.g then p.g = {}; end
			table.insert(p.g, c);
			c.parent = p;
		end
		return c;
	end
	local function achievementSort(a, b)
		if a.achievementCategoryID then
			if b.achievementCategoryID then
				return a.achievementCategoryID < b.achievementCategoryID;
			end
			return true;
		elseif b.achievementCategoryID then
			return false;
		end
		return sortByNameSafely(a, b);
	end;
	achievementsCategory.OnUpdate = function(self)
		local categories = {};
		categories[-1] = self;
		cacheAchievementData(self, categories, self.g);
		for i,_ in pairs(fieldCache["achievementID"]) do
			if not self.achievements[i] then
				local achievement = app.CreateAchievement(tonumber(i));
				for j,o in ipairs(_) do
					for key,value in pairs(o) do rawset(achievement, key, value); end
					if o.parent and not o.sourceQuests then
						local questID = GetRelativeValue(o, "questID");
						if questID then
							if not achievement.sourceQuests then
								achievement.sourceQuests = {};
							end
							if not contains(achievement.sourceQuests, questID) then
								tinsert(achievement.sourceQuests, questID);
							end
						else
							local sourceQuests = GetRelativeValue(o, "sourceQuests");
							if sourceQuests then
								if not achievement.sourceQuests then
									achievement.sourceQuests = {};
									for k,questID in ipairs(sourceQuests) do
										tinsert(achievement.sourceQuests, questID);
									end
								else
									for k,questID in ipairs(sourceQuests) do
										if not contains(achievement.sourceQuests, questID) then
											tinsert(achievement.sourceQuests, questID);
										end
									end
								end
							end
						end
					end
				end
				self.achievements[i] = achievement;
				achievement.progress = nil;
				achievement.total = nil;
				achievement.g = nil;
				achievement.parent = getAchievementCategory(categories, achievement.parentCategoryID);
				if not achievement.u or achievement.u ~= 1 then
					tinsert(achievement.parent.g, achievement);
				end
			end
		end
		app.Sort(self.g, achievementSort, true);
	end
	achievementsCategory:OnUpdate();
	]]--

	-- Update Faction data.
	--[[
	-- TODO: Make a dynamic Factions section. It works, but we have one already, so we don't need it.
	factionsCategory.OnUpdate = function(self)
		for i,_ in pairs(fieldCache["factionID"]) do
			if not self.factions[i] then
				local faction = app.CreateFaction(tonumber(i));
				for j,o in ipairs(_) do
					if o.key == "factionID" then
						for key,value in pairs(o) do rawset(faction, key, value); end
					end
				end
				faction.progress = nil;
				faction.total = nil;
				faction.g = nil;
				self.factions[i] = faction;
				if not faction.u or faction.u ~= 1 then
					faction.parent = self;
					tinsert(self.g, faction);
				end
				CacheFields(faction);
			end
		end
		app.Sort(self.g);
	end
	factionsCategory:OnUpdate();
	]]--

	-- Update Flight Path data.
	-- if flightPathsCategory and dynamicSetting > 0 then
	-- 	flightPathsCategory.OnUpdate = function(self)
	-- 		-- no longer need to run this logic once the dynamic group has been filled
	-- 		self.OnUpdate = nil;
	-- 		for i,_ in pairs(fieldCache["flightPathID"]) do
	-- 			if not self.fps[i] then
	-- 				local fp = app.CreateFlightPath(tonumber(i));
	-- 				for j,o in ipairs(_) do
	-- 					for key,value in pairs(o) do rawset(fp, key, value); end
	-- 				end
	-- 				self.fps[i] = fp;
	-- 				fp.g = nil;
	-- 				fp.maps = nil;
	-- 				if not fp.u or fp.u ~= 1 then
	-- 					fp.parent = self;
	-- 					tinsert(self.g, fp);
	-- 				else
	-- 					fp.parent = flightPathsCategory_NYI;
	-- 					tinsert(flightPathsCategory_NYI.g, fp);
	-- 				end
	-- 				-- Make sure the sourced FP data exists in the cache DB so it doesn't show *NEW*
	-- 				if not app.FlightPathDB[i] then app.FlightPathDB[i] = _; end
	-- 			end
	-- 		end
	-- 		-- will only run once per session and return true the first time it is called
	-- 		if app.CacheFlightPathData() then
	-- 			for i,_ in pairs(app.FlightPathDB) do
	-- 				if not self.fps[i] then
	-- 					local fp = app.CreateFlightPath(tonumber(i));
	-- 					self.fps[i] = fp;
	-- 					if not fp.u or fp.u ~= 1 then
	-- 						app.print("Flight Path needs Source!",i,fp.name)
	-- 						fp.parent = self;
	-- 						tinsert(self.g, fp);
	-- 					else
	-- 						fp.parent = flightPathsCategory_NYI;
	-- 						tinsert(flightPathsCategory_NYI.g, fp);
	-- 					end
	-- 				end
	-- 			end
	-- 		end
	-- 		-- reset indents and such
	-- 		BuildGroups(flightPathsCategory, flightPathsCategory.g);
	-- 		-- delay-sort the top level groups
	-- 		flightPathsCategory.sort = true;
	-- 		app.SortGroupDelayed(flightPathsCategory, "name");
	-- 		flightPathsCategory.sort = nil;
	-- 		-- dynamic groups are ignored for the source tooltips
	-- 		flightPathsCategory.sourceIgnored = true;
	-- 		-- make sure these things are cached so they can be updated when collected
	-- 		CacheFields(flightPathsCategory);
	-- 	end;
	-- end

	-- Perform Heirloom caching/upgrade generation
	app.CacheHeirlooms();

	-- StartCoroutine("VerifyRecursionUnsorted", function() app.VerifyCache(); end, 5);
	-- app.PrintDebug("Finished app.GetDataCache")
	-- app.PrintMemoryUsage()
	app.GetDataCache = function()
		-- app.PrintDebug("Cached GetDataCache")
		return app:GetWindow("Prime").data;
	end
	return allData;
end
end	-- Dynamic/Main Data

-- Collection Window Creation
app._RefreshData = function()
	-- app.PrintDebug("_RefreshData",app.refreshDataForce and "FORCE", app.refreshDataGot and "COLLECTED")
	-- Send an Update to the Windows to Rebuild their Row Data
	if app.refreshDataForce then
		app.refreshDataForce = nil;
		app:GetDataCache();

		-- Refresh all Quests without callback
		app.QueryCompletedQuests();

		-- Reapply custom collects
		app.RefreshCustomCollectibility();

		-- Forcibly update the windows.
		app._UpdateWindows(true, app.refreshDataGot);
	else
		app._UpdateWindows(nil, app.refreshDataGot);
	end
	app.refreshDataQueued = nil;
	app.refreshDataGot = nil;

	-- Send a message to your party members.
	local data = app:GetWindow("Prime").data;
	local msg = "A\t" .. app.Version .. "\t" .. (data.progress or 0) .. "\t" .. (data.total or 0);
	if app.lastMsg ~= msg then
		SendSocialMessage(msg);
		app.lastMsg = msg;
	end
	wipe(searchCache);
end
function app:RefreshData(lazy, got, manual)
	-- app.PrintDebug("RefreshData",lazy and "LAZY", got and "COLLECTED", manual and "MANUAL")
	app.refreshDataForce = app.refreshDataForce or not lazy;
	app.refreshDataGot = app.refreshDataGot or got;
	app.refreshDataQueued = true;

	-- Don't refresh if not ready
	if not app.IsReady then
		-- print("Not ready, .1sec self callback")
		DelayedCallback(app.RefreshData, 0.1, self, lazy);
	elseif manual then
		-- print("manual refresh after combat")
		AfterCombatCallback(app._RefreshData);
	else
		-- print(".5sec delay callback")
		AfterCombatOrDelayedCallback(app._RefreshData, 0.5);
	end
end

do -- Search Response Logic
local IncludeUnavailableRecipes, IgnoreBoEFilter;
-- Set some logic which is used during recursion without needing to set it on every recurse
local function SetRescursiveFilters()
	IncludeUnavailableRecipes = not app.BuildSearchResponse_IgnoreUnavailableRecipes;
	IgnoreBoEFilter = app.FilterItemClass_IgnoreBoEFilter;
end
-- Collects a cloned hierarchy of groups which simply have the field defined
local function BuildSearchResponseByField(groups, field, clear)
	if groups then
		local t, response, clone;
		for _,group in ipairs(groups) do
			if group[field] then
				-- some recipes are faction locked and cannot be learned by the current character, so don't include them if specified
				if IncludeUnavailableRecipes or not group.spellID or IgnoreBoEFilter(group) then
					clone = clear and CreateObject(group, true) or CreateObject(group);
					if t then tinsert(t, clone);
					else t = { clone }; end
				end
			else
				response = BuildSearchResponseByField(group.g, field, clear);
				if response then
					local groupCopy = {};
					-- copy direct group values only
					MergeProperties(groupCopy, group);
					-- no need to clone response, since it is already cloned above
					groupCopy.g = response;
					-- the group itself does not meet the field/value expectation, so force it to be uncollectible
					groupCopy.collectible = false;
					-- don't copy in any extra data for the header group which can pull things into groups, or reference other groups
					groupCopy.sym = nil;
					groupCopy.sourceParent = nil;
					if t then tinsert(t, groupCopy);
					else t = { groupCopy }; end
				end
			end
		end
		return t;
	end
end
-- Collects a cloned hierarchy of groups which have the field defined with the required value
local function BuildSearchResponseByFieldValue(groups, field, value, clear)
	if groups then
		local t, response, v, clone;
		for _,group in ipairs(groups) do
			v = group[field];
			if v and (v == value or
					(field == "requireSkill" and app.SpellIDToSkillID[app.SpecializationSpellIDs[v] or 0] == value)) then
				-- some recipes are faction locked and cannot be learned by the current character, so don't include them if specified
				if IncludeUnavailableRecipes or not group.spellID or IgnoreBoEFilter(group) then
					clone = clear and CreateObject(group, true) or CreateObject(group);
					if t then tinsert(t, clone);
					else t = { clone }; end
				end
			else
				response = BuildSearchResponseByFieldValue(group.g, field, value, clear);
				if response then
					local groupCopy = {};
					-- copy direct group values only
					MergeProperties(groupCopy, group);
					-- no need to clone response, since it is already cloned above
					groupCopy.g = response;
					-- the group itself does not meet the field/value expectation, so force it to be uncollectible
					groupCopy.collectible = false;
					-- don't copy in any extra data for the header group which can pull things into groups, or reference other groups
					groupCopy.sym = nil;
					groupCopy.sourceParent = nil;
					if t then tinsert(t, groupCopy);
					else t = { groupCopy }; end
				end
			end
		end
		return t;
	end
end
local MainRoot, UnsortedRoot;
local ClonedHierarchyGroups = {};
local ClonedHierarachyMapping = {};
-- Finds existing clone of the parent group, or clones the group into the proper clone hierarchy
local function MatchOrCloneParentInHierarchy(group)
	if group then
		-- already cloned group, return the clone
		local groupCopy = ClonedHierarachyMapping[group];
		if groupCopy then return groupCopy; end

		-- new cloned parent
		groupCopy = {};
		-- copy direct group values only
		MergeProperties(groupCopy, group);
		-- the group itself does not meet the field/value expectation, so force it to be uncollectible
		groupCopy.collectible = false;
		-- don't copy in any extra data for the header group which can pull things into groups, or reference other groups
		groupCopy.sym = nil;
		groupCopy.sourceParent = nil;
		-- always a parent, so it will have a .g
		groupCopy.g = {};
		ClonedHierarachyMapping[group] = groupCopy;

		-- is this a top-level group?
		local parent = group.parent;
		if parent == MainRoot then
			-- app.PrintDebug("Added top cloned parent",groupCopy.text)
			tinsert(ClonedHierarchyGroups, groupCopy);
			return groupCopy;
		elseif parent == UnsortedRoot then
			-- app.PrintDebug("Don't capture Unsorted",groupCopy.text)
			-- don't collect the unsorted content into the cloned groups
			return groupCopy;
		else
			-- need to clone and attach this group to its cloned parent
			local clonedParent = MatchOrCloneParentInHierarchy(parent);
			-- if not clonedParent then
			-- 	app.PrintDebug("Null Cloned Parent?",group.text,group.parent and group.parent.text)
			-- end
			NestObject(clonedParent, groupCopy);
			-- tinsert(clonedParent.g, groupCopy);
			return groupCopy;
		end
	end
end
-- Creates a cloned hierarchy of the cached groups which match a particular key and value
local function BuildSearchResponseViaCachedGroups(cacheContainer, field, value, clear)
	if cacheContainer then
		MainRoot = app:GetDataCache();
		UnsortedRoot = app:GetWindow("Unsorted").data;
		wipe(ClonedHierarchyGroups);
		wipe(ClonedHierarachyMapping);
		local parent, thing;
		if value then
			local sources = cacheContainer[value];
			if not sources then return ClonedHierarchyGroups; end
			-- for each source of each Thing with the value
			for _,source in ipairs(sources) do
				-- some recipes are faction locked and cannot be learned by the current character, so don't include them if specified
				if IncludeUnavailableRecipes or not source.spellID or IgnoreBoEFilter(source) then
					-- find/clone the expected parent group in hierachy
					parent = MatchOrCloneParentInHierarchy(source.parent);
					-- clone the Thing into the cloned parent
					thing = clear and CreateObject(source, true) or CreateObject(source);
					-- don't copy in any extra data for the thing which can pull things into groups, or reference other groups
					thing.sym = nil;
					thing.sourceParent = nil;
					-- need to map the cloned Thing also since it may end up being a parent of another Thing
					ClonedHierarachyMapping[source] = thing;
					NestObject(parent, thing);
				end
			end
		else
			for id,sources in pairs(cacheContainer) do
				-- for each source of each Thing
				for _,source in ipairs(sources) do
					-- some recipes are faction locked and cannot be learned by the current character, so don't include them if specified
					if IncludeUnavailableRecipes or not source.spellID or IgnoreBoEFilter(source) then
						-- find/clone the expected parent group in hierachy
						parent = MatchOrCloneParentInHierarchy(source.parent);
						-- clone the Thing into the cloned parent
						thing = clear and CreateObject(source, true) or CreateObject(source);
						-- don't copy in any extra data for the thing which can pull things into groups, or reference other groups
						thing.sym = nil;
						thing.sourceParent = nil;
						-- need to map the cloned Thing also since it may end up being a parent of another Thing
						ClonedHierarachyMapping[source] = thing;
						NestObject(parent, thing);
					end
				end
			end
		end
		return ClonedHierarchyGroups;
	end
end
-- Collects a cloned hierarchy of groups which have the field and/or value within the given field. Specify 'clear' if found groups which match
-- should additionally clear their contents when being cloned
function app:BuildSearchResponse(groups, field, value, clear)
	if groups then
		-- app.PrintDebug("BSR:",field,value,clear)
		SetRescursiveFilters();
		local cacheContainer = SearchForFieldContainer(field);
		if cacheContainer then
			return BuildSearchResponseViaCachedGroups(cacheContainer, field, value, clear);
		end
		if value then
			return BuildSearchResponseByFieldValue(groups, field, value, clear);
		else
			return BuildSearchResponseByField(groups, field, clear);
		end
	end
end
end -- Search Response Logic

-- Store the Custom Windows Update functions which are required by specific Windows
(function()
local customWindowUpdates = { params = {} };
-- Returns the Custom Update function based on the Window suffix if existing
function app:CustomWindowUpdate(suffix)
	return customWindowUpdates[suffix];
end
-- Retrieves the value of the specific attribute for the given window suffix
app.GetCustomWindowParam = function(suffix, name)
	local params = customWindowUpdates.params;
	if params[suffix] then return params[suffix][name] end
end
-- Defines the value of the specific attribute for the given window suffix
app.SetCustomWindowParam = function(suffix, name, value)
	local params = customWindowUpdates.params;
	if params[suffix] then params[suffix][name] = value;
	else params[suffix] = { [name] = value } end
end
-- Removes the custom attributes for a given window suffix
app.ResetCustomWindowParam = function(suffix)
	customWindowUpdates.params[suffix] = nil;
end
customWindowUpdates["AchievementHarvester"] = function(self, ...)
	-- /script AllTheThings:GetWindow("AchievementHarvester"):Toggle();
	if self:IsVisible() then
		if not self.initialized then
			self.doesOwnUpdate = true;
			self.initialized = true;
			self.Limit = 15596;	-- MissingAchievements:9.2.5.42850
			self.PartitionSize = 2000;
			local db = {};
			local CleanUpHarvests = function()
				local g, partition, pg, pgcount, refresh = self.data.g;
				local count = g and #g or 0;
				if count > 0 then
					for p=count,1,-1 do
						partition = g[p];
						if partition.g and partition.expanded then
							refresh = true;
							pg = partition.g;
							pgcount = #pg;
							-- print("UpdateDone.Partition",partition.text,pgcount)
							if pgcount > 0 then
								for i=pgcount,1,-1 do
									if pg[i].collected then
										-- item harvested, so remove it
										-- print("remove",pg[i].text)
										table.remove(pg, i);
									end
								end
							else
								-- empty partition, so remove it
								table.remove(g, p);
							end
						end
					end
					if refresh then
						-- refresh the window again
						self:BaseUpdate();
					else
						-- otherwise stop until a group is expanded again
						self.UpdateDone = nil;
					end
				end
			end;
			-- add a bunch of raw, delay-loaded items in order into the window
			local groupCount = math.ceil(self.Limit / self.PartitionSize);
			local g, overrides = {}, {visible=true};
			local partition, partitionStart, partitionGroups;
			local dlo, obj = app.DelayLoadedObject, app.CreateAchievementHarvester;
			for j=0,groupCount,1 do
				partitionStart = j * self.PartitionSize;
				partitionGroups = {};
				-- define a sub-group for a range of quests
				partition = {
					["text"] = tostring(partitionStart + 1).."+",
					["icon"] = app.asset("Interface_Quest_header"),
					["visible"] = true,
					["OnClick"] = function(row, button)
						-- assign the clean up method now that the group was clicked
						self.UpdateDone = CleanUpHarvests;
						-- no return so that it acts like a normal row
					end,
					["g"] = partitionGroups,
				};
				for i=1,self.PartitionSize,1 do
					tinsert(partitionGroups, dlo(obj, "text", overrides, partitionStart + i));
				end
				tinsert(g, partition);
			end
			db.g = g;
			db.text = "Achievement Harvester";
			db.icon = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider";
			db.description = "This is a contribution debug tool. NOT intended to be used by the majority of the player base.\n\nExpand a group to harvest the 1,000 Achievements within that range.";
			db.visible = true;
			db.expanded = true;
			db.back = 1;
			self:SetData(db);
		end
		self:BaseUpdate(true);
	end
end;
customWindowUpdates["AuctionData"] = function(self)
	if not self.initialized then
		local C_AuctionHouse_ReplicateItems = C_AuctionHouse.ReplicateItems;
		self.shouldFullRefresh = false;
		self.initialized = true;
		self:SetData({
			["text"] = "Auction Module",
			["visible"] = true,
			["back"] = 1,
			["icon"] = "INTERFACE/ICONS/INV_Misc_Coin_01",
			["description"] = "This is a debug window for all of the auction data that was returned. Turn on 'Account Mode' to show items usable on any character on your account!",
			["options"] = {
				{
					["text"] = "Wipe Scan Data",
					["icon"] = "INTERFACE/ICONS/INV_FIRSTAID_SUN-BLEACHED LINEN",
					["description"] = "Click this button to wipe out all of the previous scan data.",
					["visible"] = true,
					["priority"] = -4,
					["OnClick"] = function()
						if AllTheThingsAuctionData then
							local window = app:GetWindow("AuctionData");
							wipe(AllTheThingsAuctionData);
							wipe(window.data.g);
							for i,option in ipairs(window.data.options) do
								tinsert(window.data.g, option);
							end
							window:Update();
						end
					end,
					['OnUpdate'] = function(data)
						local window = app:GetWindow("AuctionData");
						data.visible = #window.data.g > #window.data.options;
						return true;
					end,
				},
				{
					["text"] = "Scan or Load Last Save",
					["icon"] = "INTERFACE/ICONS/INV_DARKMOON_EYE",
					["description"] = "Click this button to perform a full scan of the auction house or load the last scan conducted within 15 minutes. The game may or may not freeze depending on the size of your auction house.\n\nData should populate automatically.",
					["visible"] = true,
					["priority"] = -3,
					["OnClick"] = function()
						if AucAdvanced and AucAdvanced.API then AucAdvanced.API.CompatibilityMode(1, ""); end

						-- Only allow a scan once every 15 minutes.
						local cooldown, now = GetDataMember("AuctionScanCooldownTime", 0), time();
						if cooldown - now < 0 then
							SetDataMember("AuctionScanCooldownTime", time() + 900);
							app.AuctionFrame:RegisterEvent("REPLICATE_ITEM_LIST_UPDATE");
							C_AuctionHouse_ReplicateItems();
						else
							app.print(": Throttled scan! Please wait " .. RoundNumber(cooldown - now, 0) .. " before running another. Loading last save instead...");
							StartCoroutine("ProcessAuctionData", app.ProcessAuctionData, 1);
						end
					end,
					['OnUpdate'] = app.AlwaysShowUpdate,
				},
				{
					["text"] = "Toggle Debug Mode",
					["icon"] = "INTERFACE/ICONS/INV_MISC_WRENCH_02",
					["description"] = "Click this button to toggle debug mode to show everything regardless of filters!",
					["visible"] = true,
					["priority"] = -2,
					["OnClick"] = function()
						app.Settings:ToggleDebugMode();
					end,
					['OnUpdate'] = function(data)
						data.visible = true;
						if app.MODE_DEBUG then
							-- Novaplane made me do it
							data.trackable = true;
							data.saved = true;
						else
							data.trackable = nil;
							data.saved = nil;
						end
						return true;
					end,
				},
				{
					["text"] = "Toggle Account Mode",
					["icon"] = "INTERFACE/ICONS/ACHIEVEMENT_GUILDPERK_HAVEGROUP WILLTRAVEL",
					["description"] = "Turn this setting on if you want to track all of the Things for all of your characters regardless of class and race filters.\n\nUnobtainable filters still apply.",
					["visible"] = true,
					["priority"] = -1,
					["OnClick"] = function()
						app.Settings:ToggleAccountMode();
					end,
					['OnUpdate'] = function(data)
						data.visible = true;
						if app.MODE_ACCOUNT then
							data.trackable = true;
							data.saved = true;
						else
							data.trackable = nil;
							data.saved = nil;
						end
						return true;
					end,
				},
				{
					["text"] = "Toggle Faction Mode",
					["icon"] = "INTERFACE/ICONS/INV_Scarab_Crystal",
					["description"] = "Click this button to toggle faction mode to show everything for your faction!",
					["visible"] = true,
					["OnClick"] = function()
						app.Settings:ToggleFactionMode();
					end,
					['OnUpdate'] = function(data)
						if app.MODE_DEBUG or not app.MODE_ACCOUNT then
							data.visible = false;
						else
							data.visible = true;
							if app.Settings:Get("FactionMode") then
								data.trackable = true;
								data.saved = true;
							else
								data.trackable = nil;
								data.saved = nil;
							end
						end
						return true;
					end,
				},
				{
					["text"] = "Toggle Unobtainable Items",
					["icon"] = "INTERFACE/ICONS/SPELL_BROKENHEART",
					["description"] = "Click this button to see currently unobtainable items in the auction data.",
					["visible"] = true,
					["priority"] = 0,
					["OnClick"] = function()
						local show = not app.Settings:GetValue("Unobtainable", 7);
						app.Settings:SetValue("Unobtainable", 7, show);
						for k,v in pairs(L["UNOBTAINABLE_ITEM_REASONS"]) do
							if v[1] == 1 or v[1] == 2 or v[1] == 3 then
								if k ~= 7 then
									app.Settings:SetValue("Unobtainable", k, show);
								end
							end
						end
						app.Settings:Refresh();
						app:RefreshData();
					end,
					['OnUpdate'] = function(data)
						data.visible = true;
						if app.Settings:GetValue("Unobtainable", 7) then
							data.trackable = true;
							data.saved = true;
						else
							data.trackable = nil;
							data.saved = nil;
						end
						return true;
					end,
				},
			},
			["g"] = {}
		});
		for i,option in ipairs(self.data.options) do
			tinsert(self.data.g, option);
		end
	end

	-- Update the window and all of its row data
	self.data.progress = 0;
	self.data.total = 0;
	self.data.indent = 0;
	self.data.back = 1;
	BuildGroups(self.data, self.data.g);
	app.TopLevelUpdateGroup(self.data, self);
	self.data.visible = true;
	self:BaseUpdate(true);
end;
customWindowUpdates["Bounty"] = function(self, force, got)
	if not self.initialized then
		self.initialized = true;
		self:SetData({
			['text'] = L["BOUNTY"],
			['icon'] = "Interface\\Icons\\INV_BountyHunting.blp",
			["description"] = L["BOUNTY_DESC"],
			['visible'] = true,
			['expanded'] = true,
			['indent'] = 0,
			['g'] = {
				{
					['text'] = L["OPEN_AUTOMATICALLY"],
					['icon'] = "Interface\\Icons\\INV_Misc_Note_01",
					['description'] = L["OPEN_AUTOMATICALLY_DESC"],
					['visible'] = true,
					['OnUpdate'] = app.AlwaysShowUpdate,
					['OnClick'] = function(row, button)
						if app.Settings:GetTooltipSetting("Auto:BountyList") then
							app.Settings:SetTooltipSetting("Auto:BountyList", false);
							row.ref.saved = false;
							self:BaseUpdate(true, got);
						else
							app.Settings:SetTooltipSetting("Auto:BountyList", true);
							row.ref.saved = true;
							self:BaseUpdate(true, got);
						end
						return true;
					end,
				},
				app.CreateNPC(-34, {
					['description'] = L["TWO_CLOAKS"],
					['g'] = {
						app.CreateItemSource(102106, 165685),	-- House of Nobles Cape
						app.CreateItemSource(102105, 165684),	-- Gurubashi Empire Greatcloak
					},
				}),
				app.CreateNPC(-16, {	-- Rares
					app.CreateNPC(87622, {	-- Ogom the Mangler
						['description'] = L["OGOM_THE_MANGLER_DESC"],
						['g'] = {
							app.CreateItemSource(67041, 119366),
						},
					}),
				}),
			},
		});
		BuildGroups(self.data, self.data.g);
		self.rawData = {};
		local function RefreshBounties()
			if #self.data.g > 1 and app.Settings:GetTooltipSetting("Auto:BountyList") then
				self.data.g[1].saved = true;
				self:SetVisible(true);
			end
		end
		self:SetScript("OnEvent", function(self, e, ...)
			if select(1, ...) == "AllTheThings" then
				self:UnregisterEvent("ADDON_LOADED");
				Callback(RefreshBounties);
			end
		end);
		self:RegisterEvent("ADDON_LOADED");
	end
	if self:IsVisible() then
		-- Update the window and all of its row data
		self.data.progress = 0;
		self.data.total = 0;
		self.data.back = 1;
		self.data.indent = 0;
		self.data.visible = true;
		self:BaseUpdate(true, got);
	end
end;
customWindowUpdates["CosmicInfuser"] = function(self, force)
	if self:IsVisible() then
		if not self.initialized then
			self.initialized = true;
			force = true;
			self:SetData({
				['text'] = "Cosmic Infuser",
				['icon'] = "Interface\\Icons\\INV_Misc_Celestial Map.blp",
				["description"] = "This window helps debug when we're missing map IDs in the addon.",
				['visible'] = true,
				['expanded'] = true,
				['OnUpdate'] = app.AlwaysShowUpdate,
				['g'] = {
					{
						['text'] = "Check for missing maps now!",
						['icon'] = "Interface\\Icons\\INV_Misc_Map_01",
						['description'] = "This function will check for missing mapIDs in ATT.",
						['OnClick'] = function(data, button)
							Push(self, "Rebuild", self.Rebuild);
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
				},
			});
			local openMinilist = function(row, button)
				-- logic to right-click to set the minilist to this mapID, for testing
				if button == "RightButton" then
					app.OpenMiniList(row.ref.mapID, true);
					return true;
				end
			end
			local meta = {
				["collected"] = function(t)
					local results = SearchForField("mapID", t.mapID);
					rawset(t, "collected", results and true or false);
					rawset(t, "title", results and #results or 0);
					return rawget(t, "collected");
				end,
			};
			-- an override base table for the normal map base table...
			local baseMap = { __index = function(t, key) return meta[key] and meta[key](t) or app.BaseMap.__index(t, key); end };

			self.Rebuild = function(self)
				-- Rebuild all the datas
				local temp = self.data.g[1];
				wipe(self.data.g);
				tinsert(self.data.g, temp);

				-- Go through all of the possible maps
				local allmapchains = {};
				for mapID=1,3000,1 do
					local mapInfo = C_Map_GetMapInfo(mapID);
					if mapInfo then
						local mapObject = setmetatable({ ["mapID"] = mapID, ["collectible"] = true, ["OnClick"] = openMinilist }, baseMap);

						-- Recurse up the map chain and build the full hierarchy
						local parentMapID = mapInfo.parentMapID;
						while parentMapID do
							mapInfo = C_Map_GetMapInfo(parentMapID);
							if mapInfo then
								mapObject = setmetatable({ ["mapID"] = parentMapID, ["collectible"] = true, ["OnClick"] = openMinilist, ["g"] = { mapObject } }, baseMap);
								parentMapID = mapInfo.parentMapID;
							else
								break;
							end
						end

						-- Merge it into the listing.
						tinsert(allmapchains, mapObject);
					end
				end
				NestObjects(self.data, allmapchains);
				BuildGroups(self.data, self.data.g);
				self:Update(true);
			end
		end

		-- Update the window and all of its row data
		self:BaseUpdate(force);
	end
end;
customWindowUpdates["CurrentInstance"] = function(self, force, got)
	-- app.PrintDebug("CurrentInstance:Update",force,got)
	if not self.initialized then
		force = true;
		self.initialized = true;
		self.openedOnLogin = false;
		self.CurrentMaps = {};
		self.IsSameMapData = function(self)
			if not self.mapID or self.CurrentMaps[self.mapID] then return true; end
		end
		self.SetMapID = function(self, mapID)
			-- print("SetMapID",mapID)
			self.mapID = mapID;
			self:SetVisible(true);
			self:Update();
		end
		local function IsNotComplete(group) return not app.IsComplete(group) and app.RecursiveGroupRequirementsFilter(group); end
		local function CheckGroup(group, func)
			if func(group) then
				return true;
			end
			if group.g then
				for _,o in ipairs(group.g) do
					if CheckGroup(o, func) then return true; end
				end
			end
		end
		-- Returns the consolidated data format for the next header level
		-- Headers are forced not collectible, and will have their content sorted, and can be copied from the existing Source header
		local function CreateHeaderData(group, header)
			-- copy an uncollectible version of the existing header
			if header then
				header = CreateObject(header, true);
				header.g = { group };
				header.sort = true;
				header.collectible = false;
				-- header groups in minilist shouldn't be attached to some random other source location/data/info
				-- since they will be comprised of groups from many different source locations
				header.sourceParent = nil;
				header.customCollect = nil;
				header.u = nil;
				header.races = nil;
				header.r = nil;
				header.c = nil;
				header.nmc = nil;
				header.nmr = nil;
				return header;
			else
				return { g = { group }, ["sort"] = true, ["collectible"] = false, };
			end
		end
		-- set of keys for headers which can be nested in the minilist automatically, but not confined to a direct top header
		local subGroupKeys = {
			"filterID",
			"professionID",
			"raceID",
			"holidayID",
			"instanceID",
		};
		-- set of keys for headers which can be nested in the minilist within an Instance automatically, but not confined to a direct top header
		local subGroupInstanceKeys = {
			"filterID",
			"professionID",
			"raceID",
			"holidayID",
		};
		-- Keep a static collection of top-level groups in the list so they can just be referenced for adding new
		local topHeaders = {
		-- ACHIEVEMENTS = -4
			[-4] = "achievementID",
		-- BUILDINGS = -99;
			[-99] = true,
		-- COMMON_BOSS_DROPS = -1;
			[-1] = true,
		-- FACTIONS = -6013;
			[-6013] = "factionID",
		-- FLIGHT_PATHS = -228;
			[-228] = "flightPathID",
		-- HOLIDAY = -3;
			[-3] = "holidayID",
		-- PROFESSIONS = -38;
			[-38] = "professionID",
		-- QUESTS = -17;
			[-17] = "questID",
		-- RARES = -16;
			[-16] = true,
		-- SECRETS = -22;
			[-22] = true,
		-- TREASURES = -212;
			[-212] = "objectID",
		-- VENDORS = -2;
			[-2] = true,
		-- ZONE_DROPS = 0;
			[0] = true,
		};
		-- Headers possible in a hierarchy that should just be ignored
		local ignoredHeaders = {
		-- GARRISONS
			[-9966] = true,
		};
		-- self.Rebuild
		(function()
		local results, groups, nested, header, headerKeys, difficultyID, topHeader, nextParent, headerID, groupKey, typeHeaderID, isInInstance;
		self.Rebuild = function(self)
			-- print("Rebuild",self.mapID);
			-- check if this is the same 'map' for data purposes
			if self:IsSameMapData() then
				self.data.mapID = self.mapID;
				return;
			end
			wipe(self.CurrentMaps);
			-- Get all results for this map, without any results that have been cloned into Source Ignored groups
			results = app.CleanSourceIgnoredGroups(SearchForField("mapID", self.mapID));
			if results then
				-- print(#results,"Minilist Results for mapID",self.mapID)
				-- Simplify the returned groups
				groups = {};
				header = app.CreateMap(self.mapID, { g = groups });
				self.CurrentMaps[self.mapID] = true;
				isInInstance = IsInInstance();
				headerKeys = isInInstance and subGroupInstanceKeys or subGroupKeys;
				for _,group in ipairs(results) do
					-- do not use any raw Source groups in the final list
					-- app.PrintDebug("Clone",group.hash)
					group = CreateObject(group);
					-- app.PrintDebug("Done")
					-- print(group.key,group.key and group[group.key],group.text)
					nested = nil;

					-- Cache the difficultyID, if there is one and we are in an actual instance where the group is being mapped
					difficultyID = isInInstance and GetRelativeValue(group, "difficultyID");

					-- groups which 'should' be a root of the minilist
					if (group.instanceID or group.mapID or group.key == "classID")
					-- and actually match this minilist...
					-- only if this group mapID matches the minilist mapID directly or by maps
					and (group.mapID == self.mapID or (group.maps and contains(group.maps, self.mapID))) then
						if group.maps then
							for _,m in ipairs(group.maps) do
								self.CurrentMaps[m] = true;
							end
						end
						MergeProperties(header, group, true);
						NestObjects(header, group.g);
						group = nil;
					else
						-- Get the header chain for the group
						nextParent = group.parent;

						-- Pre-nest some groups based on their type after grabbing the parent
						-- Achievements / Achievement / Criteria
						if group.key == "criteriaID" and group.achievementID then
							-- print("pre-nest achieve",group.criteriaID, group.achievementID)
							group = app.CreateAchievement(group.achievementID, CreateHeaderData(group));
						end

						-- Building the header chain for each mapped Thing
						topHeader = nil;
						while nextParent do
							headerID = nextParent.headerID;
							if headerID then
								-- This matches a top-level header, track that top-level header at the highest point
								if topHeaders[headerID] then
									-- already found a matching header, then nest it before switching
									if topHeader then
										group = CreateHeaderData(group, topHeader);
									end
									topHeader = nextParent;
								elseif not ignoredHeaders[headerID] then
									group = CreateHeaderData(group, nextParent);
									nested = true;
								end
							else
								for _,hkey in ipairs(headerKeys) do
									if nextParent[hkey] then
										-- create the specified group Type header
										group = CreateHeaderData(group, nextParent);
										nested = true;
										break;
									end
								end
							end
							nextParent = nextParent.parent;
						end
						-- Create/match the header chain for the zone list assuming it matches one of the allowed top headers
						if topHeader then
							group = CreateHeaderData(group, topHeader);
							nested = true;
						end
					end

					-- couldn't nest this thing using a topheader header, try to use the key of the last nested group to figure out the topheader
					if not topHeader and group then
						groupKey = group.key;
						typeHeaderID = nil;
						-- determine the expected top header for this 'thing' based on its key
						for headerID,key in pairs(topHeaders) do
							if groupKey == key then
								typeHeaderID = headerID;
								break;
							end
						end
						-- and based on the Type of the original Thing if it was never listed under any matching top headers
						if typeHeaderID then
							group = app.CreateNPC(typeHeaderID, CreateHeaderData(group));
							nested = true;
						end
						-- really really special cases...
						-- Battle Pets get a raw Filter group
						if not nested and groupKey == "speciesID" then
							group = app.CreateFilter(101, CreateHeaderData(group));
						end
						-- otherwise the group itself will be the topHeader in the minilist, and its content will be sorted since it may be merging with an existing group
						group.sort = true;
						nested = true;
					end

					-- If relative to a difficultyID, then merge it into one.
					if difficultyID then group = app.CreateDifficulty(difficultyID, { g = { group } }); end
					if group then
						MergeObject(groups, group);
					end
				end

				-- Check for difficulty groups
				-- local cbd, zd = -1, -1;
				-- local groupHeaderID, g;
				-- for _,group in ipairs(groups) do
				-- 	g = group.g;
				-- 	if g and group.difficultyID then
				-- 		cbd, zd = -1, -1;
				-- 		-- Look for special headers
				-- 		for j,subgroup in ipairs(g) do
				-- 			groupHeaderID = subgroup.headerID;
				-- 			-- Common Boss Drops
				-- 			if groupHeaderID == -1 then
				-- 				cbd = j;
				-- 			end
				-- 			-- Zone Drops
				-- 			if groupHeaderID == 0 then
				-- 				zd = j;
				-- 			end
				-- 		end

				-- 		-- Push the Common Boss Drop header to the top
				-- 		if cbd > -1 then
				-- 			tinsert(g, 1, table.remove(g, cbd));
				-- 		end

				-- 		-- Push the Zone Drop header to the bottom
				-- 		if zd > -1 then
				-- 			tinsert(g, table.remove(g, zd));
				-- 		end
				-- 	end
				-- end

				header.u = nil;
				header.mapID = self.mapID;
				header.visible = true;
				setmetatable(header,
					header.instanceID and app.BaseInstance
					or header.classID and app.BaseCharacterClass
					or header.achID and app.BaseMapWithAchievementID or app.BaseMap);

				-- Swap out the map data for the header.
				self:SetData(header);
				-- Fill up the groups that need to be filled!
				app.FillGroups(header);

				-- sort top level by name if not in an instance
				if not GetRelativeValue(header, "instanceID") then
					app.SortGroup(header, "name");
				end
				-- and conditionally sort the entire list (sort groups which contain 'mapped' content)
				app.SortGroup(header, "name", nil, true, "sort");

				local expanded;
				-- if enabled, minimize rows based on difficulty
				local difficultyID = select(3, GetInstanceInfo());
				if app.Settings:GetTooltipSetting("Expand:Difficulty") then
					if difficultyID and difficultyID > 0 and header.g then
						for _,row in ipairs(header.g) do
							if row.difficultyID or row.difficulties then
								if (row.difficultyID or -1) == difficultyID or (row.difficulties and containsValue(row.difficulties, difficultyID)) then
									if not row.expanded then ExpandGroupsRecursively(row, true, true); expanded = true; end
								elseif row.expanded then
									ExpandGroupsRecursively(row, false, true);
								end
							-- Zone Drops/Common Boss Drops should also be expanded within instances
							-- elseif row.headerID == 0 or row.headerID == -1 then
							-- 	if not row.expanded then ExpandGroupsRecursively(row, true); expanded = true; end
							end
						end
						-- No difficulty found to expand, so just expand everything in the list
						if not expanded then
							ExpandGroupsRecursively(header, true);
							expanded = true;
						end
					end
				end
				-- app.PrintDebug("Warn:Difficulty")
				if app.Settings:GetTooltipSetting("Warn:Difficulty") then
					if difficultyID and difficultyID > 0 and header.g then
						local missing, found, other;
						for _,row in ipairs(header.g) do
							-- app.PrintDebug("Check Minilist Header for Progress for Difficulty",difficultyID,row.difficultyID,row.difficulties)
							if not found and not missing then
								-- check group for the current difficulty for incomplete content
								if (row.difficultyID == difficultyID) or (row.difficulties and containsValue(row.difficulties, difficultyID)) then
									found = true;
									-- app.PrintDebug("Found current")
									if CheckGroup(row, IsNotComplete) then
										-- app.PrintDebug("Current Difficulty is NOT complete")
										missing = true;
									end
								-- grab another difficulty with incomplete groups in case current difficulty is complete
								elseif not other and row.difficultyID then
									if CheckGroup(row, IsNotComplete) then
										-- app.PrintDebug("Found another incomplete",row.text)
										other = row.text;
									end
								end
							end
						end
						-- current matching difficulty is not missing anything, and we have another difficulty text to announce
						if found and not missing and other then
							print(L["DIFF_COMPLETED_1"] .. other .. L["DIFF_COMPLETED_2"]);
						end
					end
				end

				self:BuildData();

				-- check to expand groups after they have been built and updated
				-- dont re-expand if the user has previously full-collapsed the minilist
				-- need to force expand if so since the groups haven't been updated yet
				if not expanded and not self.fullCollapsed then
					self.ExpandInfo = { Expand = true };
				end
			else
				-- If we don't have any data cached for this mapID and it exists in game, report it to the chat window.
				local mapID = self.mapID;
				local mapInfo = C_Map_GetMapInfo(mapID);
				if mapInfo then
					local mapPath = mapInfo.name or ("Map ID #" .. mapID);
					mapID = mapInfo.parentMapID;
					while mapID do
						mapInfo = C_Map_GetMapInfo(mapID);
						if mapInfo then
							mapPath = (mapInfo.name or ("Map ID #" .. mapID)) .. " -> " .. mapPath;
							mapID = mapInfo.parentMapID;
						else
							break;
						end
					end
					-- only report for mapIDs which actually exist
					print("No map found for this location ", app.GetMapName(self.mapID), " [", self.mapID, "]");
					print("Path: ", mapPath);
					app.report();
				end
				self:SetData(app.CreateMap(self.mapID, {
					["text"] = L["MINI_LIST"] .. " [" .. self.mapID .. "]",
					["icon"] = "Interface\\Icons\\INV_Misc_Map06.blp",
					["description"] = L["MINI_LIST_DESC"],
					["visible"] = true,
					["expanded"] = true,
					["g"] = {
						{
							["text"] = L["UPDATE_LOCATION_NOW"],
							["icon"] = "Interface\\Icons\\INV_Misc_Map_01",
							["description"] = L["UPDATE_LOCATION_NOW_DESC"],
							["OnClick"] = function(row, button)
								Push(self, "ResetMapID", function() self.displayedMapID = -1; self:SetMapID(app.GetCurrentMapID()) end);
								return true;
							end,
							["OnUpdate"] = app.AlwaysShowUpdate,
						},
					},
				}));
				self:BuildData();
			end
			-- Make sure to scroll to the top when being rebuilt
			self.ScrollBar:SetValue(1);
			return true;
		end
		end)();
		local function OpenMiniList(id, show)
			-- print("OpenMiniList",id,show);
			-- Determine whether or not to forcibly reshow the mini list.
			local self = app:GetWindow("CurrentInstance");
			if not self:IsVisible() then
				if app.Settings:GetTooltipSetting("Auto:MiniList") then
					if not self.openedOnLogin and not show then
						self.openedOnLogin = true;
						show = true;
					end
				else
					self.openedOnLogin = false;
				end
				if show then self:Show(); end
			end
			-- ignore refreshing the minilist if it is already being shown and is the same zone
			if self.mapID == id and not show then
				-- print("exact map")
				return; -- Haha JK BRO
			end

			-- Cache that we're in the current map ID.
			-- print("new map");
			self.mapID = id;
			-- force update when showing the minilist
			Callback(self.Update, self, true);
		end
		local function OpenMiniListForCurrentZone()
			OpenMiniList(app.GetCurrentMapID(), true);
		end
		local function RefreshLocation()
			-- Acquire the new map ID.
			local mapID = app.GetCurrentMapID();
			-- print("RefreshLocation",mapID)
			if not mapID or mapID < 0 then
				AfterCombatCallback(RefreshLocation);
				return;
			end
			OpenMiniList(mapID);
		end
		local function ToggleMiniListForCurrentZone()
			local self = app:GetWindow("CurrentInstance");
			if self:IsVisible() then
				self:Hide();
			else
				OpenMiniListForCurrentZone();
			end
		end
		local function LocationTrigger()
			if app.InWorld and app.IsReady and (app.Settings:GetTooltipSetting("Auto:MiniList") or app:GetWindow("CurrentInstance"):IsVisible()) then
				-- print("LocationTrigger-Callback")
				AfterCombatOrDelayedCallback(RefreshLocation, 0.25);
			end
		end
		app.OpenMiniList = OpenMiniList;
		app.OpenMiniListForCurrentZone = OpenMiniListForCurrentZone;
		app.ToggleMiniListForCurrentZone = ToggleMiniListForCurrentZone;
		app.LocationTrigger = LocationTrigger;
		self:SetScript("OnEvent", function(self, e, ...)
			-- print("LocationTrigger",e,...);
			LocationTrigger();
		end);
		self:RegisterEvent("NEW_WMO_CHUNK");
		self:RegisterEvent("WAYPOINT_UPDATE");
		self:RegisterEvent("SCENARIO_UPDATE");
		self:RegisterEvent("ZONE_CHANGED_INDOORS");
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	end
	if self:IsVisible() then
		-- Update the window and all of its row data
		if self.mapID ~= self.displayedMapID then
			self.displayedMapID = self.mapID;
			force = self:Rebuild();
		end
		self.data.back = 1;
		self.data.indent = 0;
		self.data.visible = true;
		self:BaseUpdate(force or got, got);
	end
end;
customWindowUpdates["ItemFilter"] = function(self, force)
	if self:IsVisible() then
		if not self.initialized then
			self.initialized = true;
			-- self.dirty = true;

			self.Clear = function(self)
				local temp = self.data.g[1];
				wipe(self.data.g);
				tinsert(self.data.g, temp);
			end

			-- Item Filter
			local data = {
				['text'] = L["ITEM_FILTER_TEXT"],
				['icon'] = "Interface\\Icons\\Achievement_Dungeon_HEROIC_GloryoftheRaider",
				["description"] = L["ITEM_FILTER_DESCRIPTION"],
				['visible'] = true,
				['expanded'] = true,
				['back'] = 1,
				['g'] = {
					{
						['text'] = L["ITEM_FILTER_BUTTON_TEXT"],
						['icon'] = "Interface\\Icons\\INV_MISC_KEY_12",
						['description'] = L["ITEM_FILTER_BUTTON_DESCRIPTION"],
						['visible'] = true,
						['OnUpdate'] = app.AlwaysShowUpdate,
						['OnClick'] = function(row, button)
							app:ShowPopupDialogWithEditBox(L["ITEM_FILTER_POPUP_TEXT"], "", function(text)
								text = string_lower(text);
								local f = tonumber(text);
								if text ~= "" and tostring(f) ~= text then
									-- The string form did not match, the filter must have been by name.
									for id,filter in pairs(L["FILTER_ID_TYPES"]) do
										if string.match(string_lower(filter), text) then
											f = tonumber(id);
											break;
										end
									end
								end

								self:Clear();

								if f then
									local g = self.data.g;
									app.ArrayAppend(g, app:BuildSearchResponse(app:GetDataCache().g, "f", f));
								end

								self:BuildData();
								self:Update(true);
							end);
							return true;
						end,
					},
				},
			};

			self:SetData(data);
			self:BuildData();
		end

		self:BaseUpdate(force);
	end
end;
customWindowUpdates["ItemFinder"] = function(self, ...)
	if self:IsVisible() then
		if not self.initialized then
			local partition = app.GetCustomWindowParam("finder", "partition");
			local limit = app.GetCustomWindowParam("finder", "limit");

			app.MaximumItemInfoRetries = 10;
			self.doesOwnUpdate = true;
			self.initialized = true;
			self.Limit = tonumber(limit) or 200000;
			self.PartitionSize = tonumber(partition) or 1000;
			self.ScrollCount = 2;
			local db = {};
			local CleanUpHarvests = function()
				local scrollCount = self.ScrollCount;
				local windowRows = self.rowData;
				local completed = true;
				local currentRow;
				local text;
				-- check each row in order to see if it is completed
				while completed do
					currentRow = windowRows[scrollCount];
					-- i don't know why calling the .text field on the row an extra time is necessary. but otherwise this logic doesn't work.
					text = currentRow and currentRow.text;
					completed = currentRow and currentRow.collected;
					if completed then
						scrollCount = scrollCount + 1;
					end
				end
				-- set the scroll position of the window based on how many completed rows have been encountered
				-- every row has been completed
				if scrollCount >= #windowRows then
					self.ScrollCount = 2;
					self.ScrollBar:SetValue(1);
					self.UpdateDone = nil;
					-- update the window since we've cleared everything available
					-- app.PrintDebug("UpdateWindow - done processing")
					-- self:Update();
				else
					self.ScrollCount = scrollCount;
					self.ScrollBar:SetValue(scrollCount);
				end
				self:Refresh();
			end
			-- processes the content of the partition and makes the partition hidden if everything within is completed
			-- local RemoveHarvests = function(self)
			-- 	app.PrintDebug("OnUpdate",self.text)
			-- 	if self.visible and self.g then
			-- 		local completed, i, g = true, 1, self.g;
			-- 		local o;
			-- 		-- check each item in order to see if it is completed
			-- 		while completed and i < #g do
			-- 			o = g[i];
			-- 			completed = o and o.collected;
			-- 			if completed then
			-- 				i = i + 1;
			-- 			end
			-- 		end
			-- 		if completed then
			-- 			app.PrintDebug("Hide Partition",self.text)
			-- 			self.visible = false;
			-- 			self.OnUpdate = nil;
			-- 		end
			-- 	end
			-- 	return true;
			-- end
			-- add a bunch of raw, delay-loaded items in order into the window
			local groupCount, id = math.floor(self.Limit / self.PartitionSize);
			local g, overrides = {}, {visible=true};
			local partition, partitionStart, partitionGroups;
			local dlo, obj = app.DelayLoadedObject, app.CreateItemHarvester;
			for j=0,groupCount,1 do
				partitionStart = j * self.PartitionSize;
				partitionGroups = {};
				-- define a sub-group for a range of quests
				partition = {
					["text"] = tostring(partitionStart + 1).."+",
					["icon"] = app.asset("Interface_Quest_header"),
					["visible"] = true,
					["collected"] = true,
					["OnClick"] = function(row, button)
						-- assign the clean up method now that the group was clicked
						self.UpdateDone = CleanUpHarvests;
						-- no return so that it acts like a normal row
					end,
					-- ["OnUpdate"] = RemoveHarvests,
					["g"] = partitionGroups,
				};
				if partitionStart + 1 < self.Limit then
					for i=1,self.PartitionSize,1 do
						id = partitionStart + i;
						if id <= self.Limit then
							tinsert(partitionGroups, dlo(obj, "text", overrides, id));
						end
					end
				end
				tinsert(g, partition);
			end
			db.g = g;
			db.text = "Item Harvester";
			db.icon = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider";
			db.description = "This is a contribution debug tool. NOT intended to be used by the majority of the player base.\n\nExpand a group to harvest the 1,000 Items within that range.";
			db.visible = true;
			db.expanded = true;
			db.back = 1;
			self:SetData(db);
		end
		self:BaseUpdate(true);
	end
end;
customWindowUpdates["Harvester"] = function(self, force)
	if self:IsVisible() then
		if not self.initialized then
			self.initialized = true;
			self.doesOwnUpdate = true;
			force = true;
			-- ensure Debug is enabled to fully capture all information
			if not app.MODE_DEBUG then
				app.print("Enabled Debug Mode");
				self.forcedDebug = true;
				app.Settings:ToggleDebugMode();
			end

			local db = {};
			db.g = {};
			db.text = "Harvesting All Item SourceIDs";
			db.icon = "Interface\\Icons\\Spell_Warlock_HarvestofLife";
			db.description = "This is a contribution debug tool. NOT intended to be used by the majority of the player base.\n\nUsing this tool will lag your WoW a lot!";
			db.visible = true;
			db.expanded = true;
			db.progress = 0;
			db.total = 0;
			db.back = 1;

			local harvested = {};
			local minID,maxID,oldRetries = app.customHarvestMin or self.min,app.customHarvestMax or self.max,app.MaximumItemInfoRetries;
			self.min = minID;
			self.max = maxID;
			app.MaximumItemInfoRetries = 10;
			-- Put all known Items which do not have a valid SourceID into the Window to be Harvested
			for itemID,groups in pairs(fieldCache["itemID"]) do
				-- ignore items that dont meet the customHarvest range if specified
				if (not minID or minID <= itemID) and (not maxID or itemID <= maxID) then
					-- clean any cached modID from the itemID
					itemID = GetItemIDAndModID(itemID);
					-- print("Checking for Source",itemID)
					for i,group in ipairs(groups) do
						-- only use the matching cached Item
						if group.itemID == itemID and not harvested[group.modItemID or itemID] then
							harvested[group.modItemID or itemID] = true;
							-- print("sourceID harvest",group.modItemID)
							if group.bonusID then
								-- Harvest using a BonusID?
								-- print("Check w/ Bonus",itemID,group.bonusID)
								if (not VerifySourceID(group)) then
									-- print("Harvest w/ Bonus",itemID,group.bonusID)
									tinsert(db.g, app.CreateItem(tonumber(itemID), {visible = true, reSource = true, s = group.s, itemID = tonumber(itemID), modID = group.modID, bonusID = group.bonusID}));
								end
							elseif group.modID then
								-- Harvest using a ModID?
								-- print("Check w/ Mod",itemID,group.modID)
								if (not VerifySourceID(group)) then
									-- print("Harvest w/ Mod",itemID,group.modID)
									tinsert(db.g, app.CreateItem(tonumber(itemID), {visible = true, reSource = true, s = group.s, itemID = tonumber(itemID), modID = group.modID}));
								end
							else
								-- Harvest with no special ID?
								-- print("Check Base",itemID)
								if (not VerifySourceID(group)) then
									-- print("Harvest",itemID)
									tinsert(db.g, app.CreateItem(tonumber(itemID), {visible = true, reSource = true, s = group.s, itemID = tonumber(itemID)}));
								end
							end
						-- else print("Cached skip",group.key,group[group.key]);
						end
					end
				end
			end
			wipe(harvested);
			-- remove the custom harvest flags
			app.customHarvestMin = nil;
			app.customHarvestMax = nil;
			-- add artifacts
			for artifactID,groups in pairs(fieldCache["artifactID"]) do
				for _,group in pairs(groups) do
					if not rawget(group, "s") then
						tinsert(db.g, setmetatable({
							visible = true,
							artifactID = tonumber(artifactID),
							silentItemID = group.silentItemID,
							isOffHand = group.isOffHand,
							reSource = true,
						}, app.BaseArtifact));
					end
				end
			end
			-- total doesnt change
			local total = #db.g;
			db.total = total;
			db.progress = 0;
			self:SetData(db);
			self:BuildData();
			self.ScrollBar:SetValue(1);
			self.UpdateDone = function(self)
				-- rowdata = set of visible groups which can show in the window
				local rowData = self.rowData;
				-- Remove up to 100 completed rows each frame (no need to process through thousands of rows when only a few update each frame)
				local progress = rowData[1].progress;
				-- Adjust progress of first chunk of completed harvests
				local group, rowSourced;
				for i=2,100 do
					group = rowData[i];
					-- count how many visible & processed groups we find to increment the progress
					if group and group.visible and not group.reSource then
						group.visible = nil;
						progress = progress + 1;
						rowSourced = true;
					end
				end
				-- for some reason the total changes outside of this function... so make sure it stays constant
				rowData[1].total = total;
				rowData[1].progress = progress;
				if progress >= total then
					app.Sort(AllTheThingsHarvestItems);
					app.Sort(AllTheThingsArtifactsItems);
					-- revert Debug if it was enabled by the harvester
					if self.forcedDebug then
						app.print("Reverted Debug Mode");
						app.Settings:ToggleDebugMode();
						self.forcedDebug = nil;
					end
					app.print("Source Harvest Complete! ItemIDs:",self.min,"->",self.max);
					-- revert the number of retries to retrieve item information
					app.MaximumItemInfoRetries = oldRetries or 400;
					-- TODO: reset the window so it can be used to harvest again without reloading, only via the command, not another update
					self.UpdateDone = nil;
					-- self.initialized = nil;
					-- self:SetData(nil);
					self:BaseUpdate();
					return;
				end
				if not rowSourced then
					-- Soft-Update if needed to remove processed items
					self:BaseUpdate();
				else
					-- Otherwise refresh the Harvester Window to harvest current row data for next refresh
					self:Refresh();
				end
			end
		end
		self:BaseUpdate(force);
	end
end;
customWindowUpdates["SourceFinder"] = function(self)
	if self:IsVisible() then
		if not self.initialized then
			self.initialized = true;
			local db = {};
			db.g = {
				{
					["text"] = "Update Now",
					["icon"] = "Interface\\Icons\\ability_monk_roll",
					["description"] = "Click this to update the listing. Doing so shall remove all invalid, grey, or white items.",
					["visible"] = true,
					["fails"] = 0,
					["OnClick"] = function(row, button)
						self:Update(true);
						return true;
					end,
					["OnUpdate"] = app.AlwaysShowUpdate,
				},
			};
			db.OnUpdate = function(db)
				if self:IsVisible() then
					local iCache = fieldCache["itemID"];
					local sCache = fieldCache["s"];
					for s=1,103000 do
						if not sCache[s] then
							local t = app.CreateGearSource(s);
							if t.info then
								t.fails = 0;
								t.OnUpdate = function(source)
									local text = source.text;
									if text and text ~= RETRIEVING_DATA then
										source.OnUpdate = function(source)
											local itemID = source.itemID;
											if itemID then
												local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount,
												itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID,
												isCraftingReagent = GetItemInfo(itemID);
												if itemRarity and itemRarity < 2 then
													source.fails = source.fails + 1;
													self.shouldFullRefresh = true;
												else
													local searchResults = iCache[itemID];
													if searchResults and #searchResults > 0 then
														if not searchResults[1].collectible then
															source.fails = source.fails + 1;
															self.shouldFullRefresh = true;
														end
													end
												end
											else
												source.fails = source.fails + 1;
											end
										end;
									else
										source.fails = source.fails + 1;
										self.shouldFullRefresh = true;
									end
								end
								tinsert(db.g, t);
							end
						end
					end
					db.OnUpdate = function(self)
						local g = self.g;
						if g then
							local count = #g;
							if count > 0 then
								for i=count,1,-1 do
									if g[i].fails > 2 then
										table.remove(g, i);
									end
								end
							end
						end
					end;

				end
			end
			db.text = "Source Finder";
			db.icon = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider.blp";
			db.description = "This is a contribution debug tool. NOT intended to be used by the majority of the player base.\n\nUsing this tool will lag your WoW every 5 seconds. Not sure why - likely a bad Blizzard Database thing.";
			db.visible = true;
			db.expanded = true;
			db.back = 1;
			self:SetData(db);
		end
		self:BuildData();
		app.TopLevelUpdateGroup(self.data, self);
		self:BaseUpdate(true);
	end
end;
customWindowUpdates["RaidAssistant"] = function(self)
	if self:IsVisible() then
		if not self.initialized then
			self.initialized = true;
			self.doesOwnUpdate = true;

			-- Define the different window configurations that the mini list will switch to based on context.
			local raidassistant, lootspecialization, dungeondifficulty, raiddifficulty, legacyraiddifficulty;

			-- Raid Assistant
			local difficultyLookup = {
				personalloot = "Personal Loot",
				group = "Group Loot",
				master = "Master Loot",
			};
			local difficultyDescriptions = {
				personalloot = L["PERSONAL_LOOT_DESC"],
				group = "Group loot, round-robin for normal items, rolling for special ones.\n\nClick twice to create a group automatically if you're by yourself.",
				master = "Master looter, designated player distributes loot.\n\nClick twice to create a group automatically if you're by yourself.",
			};
			local switchDungeonDifficulty = function(row, button)
				self:SetData(raidassistant);
				SetDungeonDifficultyID(row.ref.difficultyID);
				Callback(self.Update, self);
				return true;
			end
			local switchRaidDifficulty = function(row, button)
				self:SetData(raidassistant);
				local myself = self;
				local difficultyID = row.ref.difficultyID;
				if not self.running then
					self.running = true;
				else
					self.running = false;
				end

				SetRaidDifficultyID(difficultyID);
				StartCoroutine("RaidDifficulty", function()
					while InCombatLockdown() do coroutine.yield(); end
					while myself.running do
						for i=0,150,1 do
							if myself.running then
								coroutine.yield();
							else
								break;
							end
						end
						if app.RaidDifficulty == difficultyID then
							myself.running = false;
							break;
						else
							SetRaidDifficultyID(difficultyID);
						end
					end
					Callback(self.Update, self);
				end);
				return true;
			end
			local switchLegacyRaidDifficulty = function(row, button)
				self:SetData(raidassistant);
				local myself = self;
				local difficultyID = row.ref.difficultyID;
				if not self.legacyrunning then
					self.legacyrunning = true;
				else
					self.legacyrunning = false;
				end
				SetLegacyRaidDifficultyID(difficultyID);
				StartCoroutine("LegacyRaidDifficulty", function()
					while InCombatLockdown() do coroutine.yield(); end
					while myself.legacyrunning do
						for i=0,150,1 do
							if myself.legacyrunning then
								coroutine.yield();
							else
								break;
							end
						end
						if app.LegacyRaidDifficulty == difficultyID then
							myself.legacyrunning = false;
							break;
						else
							SetLegacyRaidDifficultyID(difficultyID);
						end
					end
					Callback(self.Update, self);
				end);
				return true;
			end
			local function AttemptResetInstances()
				ResetInstances();
			end
			raidassistant = {
				['text'] = L["RAID_ASSISTANT"],
				['icon'] = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider.blp",
				["description"] = L["RAID_ASSISTANT_DESC"],
				['visible'] = true,
				['expanded'] = true,
				['back'] = 1,
				['g'] = {
					{
						['text'] = L["LOOT_SPEC_UNKNOWN"],
						['title'] = L["LOOT_SPEC"],
						["description"] = L["LOOT_SPEC_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							self:SetData(lootspecialization);
							Callback(self.Update, self);
							return true;
						end,
						['OnUpdate'] = function(data)
							if self.Spec then
								local id, name, description, icon, role, class = GetSpecializationInfoByID(self.Spec);
								if name then
									if GetLootSpecialization() == 0 then name = name .. " (Automatic)"; end
									data.text = name;
									data.icon = icon;
								end
							end
						end,
					},
					app.CreateDifficulty(1, {
						['title'] = L["DUNGEON_DIFF"],
						["description"] = L["DUNGEON_DIFF_DESC"],
						['visible'] = true,
						["trackable"] = false,
						['OnClick'] = function(row, button)
							self:SetData(dungeondifficulty);
							Callback(self.Update, self);
							return true;
						end,
						['OnUpdate'] = function(data)
							if app.DungeonDifficulty then
								data.difficultyID = app.DungeonDifficulty;
								data.name = GetDifficultyInfo(data.difficultyID) or "???";
								local name, instanceType, instanceDifficulty, difficultyName = GetInstanceInfo();
								if instanceDifficulty and data.difficultyID ~= instanceDifficulty and instanceType == 'party' then
									data.name = data.name .. " (" .. (difficultyName or "???") .. ")";
								end
							end
						end,
					}),
					app.CreateDifficulty(14, {
						['title'] = L["RAID_DIFF"],
						["description"] = L["RAID_DIFF_DESC"],
						['visible'] = true,
						["trackable"] = false,
						['OnClick'] = function(row, button)
							-- Don't allow you to change difficulties when you're in LFR / Raid Finder
							if app.RaidDifficulty == 7 or app.RaidDifficulty == 17 then return true; end
							self:SetData(raiddifficulty);
							Callback(self.Update, self);
							return true;
						end,
						['OnUpdate'] = function(data)
							if app.RaidDifficulty then
								data.difficultyID = app.RaidDifficulty;
								local name, instanceType, instanceDifficulty, difficultyName = GetInstanceInfo();
								if instanceDifficulty and data.difficultyID ~= instanceDifficulty and instanceType == 'raid' then
									data.name = (GetDifficultyInfo(data.difficultyID) or "???") .. " (" .. (difficultyName or "???") .. ")";
								else
									data.name = GetDifficultyInfo(data.difficultyID);
								end
							end
						end,
					}),
					app.CreateDifficulty(5, {
						['title'] = L["LEGACY_RAID_DIFF"],
						["description"] = L["LEGACY_RAID_DIFF_DESC"],
						['visible'] = true,
						["trackable"] = false,
						['OnClick'] = function(row, button)
							-- Don't allow you to change difficulties when you're in LFR / Raid Finder
							if app.RaidDifficulty == 7 or app.RaidDifficulty == 17 then return true; end
							self:SetData(legacyraiddifficulty);
							Callback(self.Update, self);
							return true;
						end,
						['OnUpdate'] = function(data)
							if app.LegacyRaidDifficulty then
								data.difficultyID = app.LegacyRaidDifficulty;
							end
						end,
					}),
					{
						['text'] = L["TELEPORT_TO_FROM_DUNGEON"],
						['icon'] = "Interface\\Icons\\Spell_Shadow_Teleport",
						['description'] = L["TELEPORT_TO_FROM_DUNGEON_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							LFGTeleport(IsInLFGDungeon());
							return true;
						end,
						['OnUpdate'] = function(data)
							data.visible = IsAllowedToUserTeleport();
						end,
					},
					{
						['text'] = L["RESET_INSTANCES"],
						['icon'] = "Interface\\Icons\\Ability_Priest_VoidShift",
						['description'] = L["RESET_INSTANCES_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							-- make sure the indicator icon is allowed to show
							if IsAltKeyDown() then
								row.ref.saved = not row.ref.saved;
								Callback(self.Update, self);
							else
								ResetInstances();
							end
							return true;
						end,
						['OnUpdate'] = function(data)
							data.trackable = data.saved;
							data.visible = not IsInGroup() or UnitIsGroupLeader("player");
							if data.visible and data.saved then
								if IsInInstance() or C_Scenario.IsInScenario() then
									data.shouldReset = true;
								elseif data.shouldReset then
									data.shouldReset = nil;
									C_Timer.After(0.5, AttemptResetInstances);
								end
							end
						end,
					},
					{
						['text'] = L["DELIST_GROUP"],
						['icon'] = "Interface\\Icons\\Ability_Vehicle_LaunchPlayer",
						['description'] = L["DELIST_GROUP_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							C_LFGList.RemoveListing();
							if GroupFinderFrame:IsVisible() then
								PVEFrame_ToggleFrame("GroupFinderFrame")
							end
							self:SetData(raidassistant);
							Callback(self.BaseUpdate, self, true);
							return true;
						end,
						['OnUpdate'] = function(data)
							data.visible = C_LFGList.GetActiveEntryInfo();
						end,
					},
					{
						['text'] = L["LEAVE_GROUP"],
						['icon'] = "Interface\\Icons\\Ability_Vanish",
						['description'] = L["LEAVE_GROUP_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							C_PartyInfo.LeaveParty();
							if GroupFinderFrame:IsVisible() then
								PVEFrame_ToggleFrame("GroupFinderFrame")
							end
							self:SetData(raidassistant);
							Callback(self.BaseUpdate, self, true);
							return true;
						end,
						['OnUpdate'] = function(data)
							data.visible = IsInGroup();
						end,
					},
				}
			};
			lootspecialization = {
				['text'] = L["LOOT_SPEC"],
				['icon'] = "Interface\\Icons\\INV_7XP_Inscription_TalentTome02.blp",
				["description"] = L["LOOT_SPEC_DESC_2"],
				['OnClick'] = function(row, button)
					self:SetData(raidassistant);
					Callback(self.Update, self);
					return true;
				end,
				['OnUpdate'] = function(data)
					data.g = {};
					local numSpecializations = GetNumSpecializations();
					if numSpecializations and numSpecializations > 0 then
						tinsert(data.g, {
							['text'] = L["CURRENT_SPEC"],
							['title'] = select(2, GetSpecializationInfo(GetSpecialization())),
							['icon'] = "Interface\\Icons\\INV_7XP_Inscription_TalentTome01.blp",
							['id'] = 0,
							["description"] = L["CURRENT_SPEC_DESC"],
							['visible'] = true,
							['OnClick'] = function(row, button)
								self:SetData(raidassistant);
								SetLootSpecialization(row.ref.id);
								Callback(self.Update, self);
								return true;
							end,
						});
						for i=1,numSpecializations,1 do
							local id, name, description, icon, background, role, primaryStat = GetSpecializationInfo(i);
							tinsert(data.g, {
								['text'] = name,
								['icon'] = icon,
								['id'] = id,
								["description"] = description,
								['visible'] = true,
								['OnClick'] = function(row, button)
									self:SetData(raidassistant);
									SetLootSpecialization(row.ref.id);
									Callback(self.Update, self);
									return true;
								end,
							});
						end
					end
				end,
				['visible'] = true,
				['expanded'] = true,
				['back'] = 1,
				['g'] = {},
			};
			dungeondifficulty = {
				['text'] = L["DUNGEON_DIFF"],
				['icon'] = "Interface\\Icons\\Achievement_Dungeon_UtgardePinnacle_10man.blp",
				["description"] = L["DUNGEON_DIFF_DESC_2"],
				['OnClick'] = function(row, button)
					self:SetData(raidassistant);
					Callback(self.Update, self);
					return true;
				end,
				['visible'] = true,
				["trackable"] = false,
				['expanded'] = true,
				['back'] = 1,
				['g'] = {
					app.CreateDifficulty(1, {
						['OnClick'] = switchDungeonDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					}),
					app.CreateDifficulty(2, {
						['OnClick'] = switchDungeonDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					}),
					app.CreateDifficulty(23, {
						['OnClick'] = switchDungeonDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					})
				},
			};
			raiddifficulty = {
				['text'] = L["RAID_DIFF"],
				['icon'] = "Interface\\Icons\\Achievement_Dungeon_UtgardePinnacle_10man.blp",
				["description"] = L["RAID_DIFF_DESC_2"],
				['OnClick'] = function(row, button)
					self:SetData(raidassistant);
					Callback(self.Update, self);
					return true;
				end,
				['visible'] = true,
				["trackable"] = false,
				['expanded'] = true,
				['back'] = 1,
				['g'] = {
					app.CreateDifficulty(14, {
						['OnClick'] = switchRaidDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					}),
					app.CreateDifficulty(15, {
						['OnClick'] = switchRaidDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					}),
					app.CreateDifficulty(16, {
						['OnClick'] = switchRaidDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					})
				},
			};
			legacyraiddifficulty = {
				['text'] = L["LEGACY_RAID_DIFF"],
				['icon'] = "Interface\\Icons\\Achievement_Dungeon_UtgardePinnacle_10man.blp",
				["description"] = L["LEGACY_RAID_DIFF_DESC_2"],
				['OnClick'] = function(row, button)
					self:SetData(raidassistant);
					Callback(self.Update, self);
					return true;
				end,
				['visible'] = true,
				["trackable"] = false,
				['expanded'] = true,
				['back'] = 1,
				['g'] = {
					app.CreateDifficulty(3, {
						['OnClick'] = switchLegacyRaidDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					}),
					app.CreateDifficulty(5, {
						['OnClick'] = switchLegacyRaidDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					}),
					app.CreateDifficulty(4, {
						['OnClick'] = switchLegacyRaidDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					}),
					app.CreateDifficulty(6, {
						['OnClick'] = switchLegacyRaidDifficulty,
						["description"] = L["CLICK_TO_CHANGE"],
						['visible'] = true,
						["trackable"] = false,
					}),
				},
			};
			self:SetData(raidassistant);

			-- Setup Event Handlers and register for events
			self:SetScript("OnEvent", function(self, e, ...) Callback(self.Update, self, true); end);
			self:RegisterEvent("PLAYER_LOOT_SPEC_UPDATED");
			self:RegisterEvent("PLAYER_DIFFICULTY_CHANGED");
			self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
			self:RegisterEvent("CHAT_MSG_SYSTEM");
			self:RegisterEvent("SCENARIO_UPDATE");
			self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
			self:RegisterEvent("GROUP_ROSTER_UPDATE");
		end

		-- Update the window and all of its row data
		app.LegacyRaidDifficulty = GetLegacyRaidDifficultyID() or 1;
		app.DungeonDifficulty = GetDungeonDifficultyID() or 1;
		app.RaidDifficulty = GetRaidDifficultyID() or 14;
		self.Spec = GetLootSpecialization();
		if not self.Spec or self.Spec == 0 then
			local s = GetSpecialization();
			if s then self.Spec = GetSpecializationInfo(s); end
		end

		-- Update the window and all of its row data
		if self.data.OnUpdate then self.data.OnUpdate(self.data); end
		for i,g in ipairs(self.data.g) do
			if g.OnUpdate then g.OnUpdate(g, self); end
		end

		-- Update the groups without forcing Debug Mode.
		local visibilityFilter = app.VisibilityFilter;
		app.VisibilityFilter = app.ObjectVisibilityFilter;
		self:BuildData();
		self:BaseUpdate(true);
		app.VisibilityFilter = visibilityFilter;
	end
end;
customWindowUpdates["Random"] = function(self)
	if self:IsVisible() then
		if not self.initialized then
			self.initialized = true;
			local function SearchRecursively(group, field, temp, func)
				if group.visible and not (group.saved or group.collected) then
					if group.g then
						for i, subgroup in ipairs(group.g) do
							SearchRecursively(subgroup, field, temp, func);
						end
					end
					if group[field] and (not func or func(group)) then
						tinsert(temp, group);
					end
				end
			end
			local function SearchRecursivelyForEverything(group, temp)
				if group.visible and not (group.saved or group.collected) then
					if group.g then
						for i, subgroup in ipairs(group.g) do
							SearchRecursivelyForEverything(subgroup, temp);
						end
					end
					if group.collectible then
						tinsert(temp, group);
					end
				end
			end
			local function SearchRecursivelyForValue(group, field, value, temp, func)
				if group.visible and not (group.saved or group.collected) then
					if group.g then
						for i, subgroup in ipairs(group.g) do
							SearchRecursivelyForValue(subgroup, field, value, temp, func);
						end
					end
					if group[field] and group[field] == value and (not func or func(group)) then
						tinsert(temp, group);
					end
				end
			end
			function self:SelectAllTheThings()
				if searchCache["randomatt"] then
					return searchCache["randomatt"];
				else
					local searchResults = {};
					for i, subgroup in ipairs(app:GetWindow("Prime").data.g) do
						SearchRecursivelyForEverything(subgroup, searchResults);
					end
					if #searchResults > 0 then
						searchCache["randomatt"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectAchievement()
				if searchCache["randomachievement"] then
					return searchCache["randomachievement"];
				else
					local searchResults = {};
					local func = function(o)
						return o.collectible and not o.mapID;
					end
					SearchRecursively(app:GetWindow("Prime").data, "achievementID", searchResults, func);
					if #searchResults > 0 then
						searchCache["randomachievement"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectItem()
				if searchCache["randomitem"] then
					return searchCache["randomitem"];
				else
					local searchResults = {};
					local func = function(o)
						return o.collectible;
					end
					SearchRecursively(app:GetWindow("Prime").data, "itemID", searchResults, func);
					if #searchResults > 0 then
						searchCache["randomitem"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectInstance()
				if searchCache["randominstance"] then
					return searchCache["randominstance"];
				else
					local searchResults = {};
					local func = function(o)
						return ((o.total or 0) - (o.progress or 0)) > 0;
					end
					SearchRecursively(app:GetWindow("Prime").data, "instanceID", searchResults, func);
					if #searchResults > 0 then
						searchCache["randominstance"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectDungeon()
				if searchCache["randomdungeon"] then
					return searchCache["randomdungeon"];
				else
					local searchResults = {};
					local func = function(o)
						return not o.isRaid and (((o.total or 0) - (o.progress or 0)) > 0);
					end
					SearchRecursively(app:GetWindow("Prime").data, "instanceID", searchResults, func);
					if #searchResults > 0 then
						searchCache["randomdungeon"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectQuest()
				if searchCache["quests"] then
					return searchCache["quests"];
				else
					local searchResults = {};
					local func = function(o)
						return o.collectible;
					end
					SearchRecursively(app:GetWindow("Prime").data, "questID", searchResults, func);
					if #searchResults > 0 then
						searchCache["quests"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectRaid()
				if searchCache["randomraid"] then
					return searchCache["randomraid"];
				else
					local searchResults = {};
					local func = function(o)
						return o.isRaid and (((o.total or 0) - (o.progress or 0)) > 0);
					end
					SearchRecursively(app:GetWindow("Prime").data, "instanceID", searchResults, func);
					if #searchResults > 0 then
						searchCache["randomraid"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectMount()
				if searchCache["randommount"] then
					return searchCache["randommount"];
				else
					local searchResults = {};
					local func = function(o)
						return o.collectible and (not o.achievementID or o.itemID);
					end
					SearchRecursivelyForValue(app:GetWindow("Prime").data, "filterID", 100, searchResults, func);
					if #searchResults > 0 then
						searchCache["randommount"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectPet()
				if searchCache["randompet"] then
					return searchCache["randompet"];
				else
					local searchResults = {};
					local func = function(o)
						return o.collectible;
					end
					SearchRecursively(app:GetWindow("Prime").data, "speciesID", searchResults, func);
					if #searchResults > 0 then
						searchCache["randompet"] = searchResults;
						return searchResults;
					end
				end
			end
			function self:SelectToy()
				if searchCache["randomtoy"] then
					return searchCache["randomtoy"];
				else
					local searchResults = {};
					local func = function(o)
						return o.collectible;
					end
					SearchRecursively(app:GetWindow("Prime").data, "isToy", searchResults, func);
					if #searchResults > 0 then
						searchCache["randomtoy"] = searchResults;
						return searchResults;
					end
				end
			end
			local excludedZones = {
				[12] = 1,	-- Kalimdor
				[13] = 1, -- Eastern Kingdoms
				[101] = 1,	-- Outland
				[113] = 1,	-- Northrend
				[424] = 1,	-- Pandaria
				[948] = 1,	-- The Maelstrom
				[572] = 1,	-- Draenor
				[619] = 1,	-- The Broken Isles
				[905] = 1,	-- Argus
				[876] = 1,	-- Kul'Tiras
				[875] = 1,	-- Zandalar
			};
			function self:SelectZone()
				if searchCache["randomzone"] then
					return searchCache["randomzone"];
				else
					local searchResults = {};
					local func = function(o)
						return (((o.total or 0) - (o.progress or 0)) > 0) and not o.instanceID and not excludedZones[o.mapID];
					end
					SearchRecursively(app:GetWindow("Prime").data, "mapID", searchResults, func);
					if #searchResults > 0 then
						searchCache["randomzone"] = searchResults;
						return searchResults;
					end
				end
			end
			local mainHeader, filterHeader;
			local rerollOption = {
				['text'] = L["REROLL"],
				['icon'] = "Interface\\Icons\\ability_monk_roll",
				['description'] = L["REROLL_DESC"],
				['visible'] = true,
				['OnClick'] = function(row, button)
					self:Reroll();
					return true;
				end,
				['OnUpdate'] = app.AlwaysShowUpdate,
			};
			filterHeader = {
				['text'] = L["APPLY_SEARCH_FILTER"],
				['icon'] = "Interface\\Icons\\TRADE_ARCHAEOLOGY.blp",
				["description"] = L["APPLY_SEARCH_FILTER_DESC"],
				['visible'] = true,
				['expanded'] = true,
				['OnUpdate'] = app.AlwaysShowUpdate,
				["indent"] = 0,
				['back'] = 1,
				['g'] = {
					setmetatable({
						['description'] = L["SEARCH_EVERYTHING_BUTTON_OF_DOOM"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "AllTheThings");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					}, { __index = function(t, key)
						if key == "text" or key == "icon" or key == "preview" or key == "texcoord" or key == "previewtexcoord" then
							return app:GetWindow("Prime").data[key];
						end
					end}),
					{
						['text'] = L["ACHIEVEMENT"],
						['icon'] = "Interface\\Icons\\Achievement_FeatsOfStrength_Gladiator_10",
						['description'] = L["ACHIEVEMENT_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Achievement");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["ITEM"],
						['icon'] = "Interface\\Icons\\INV_Box_02",
						['description'] = L["ITEM_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Item");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["INSTANCE"],
						['icon'] = "Interface\\Icons\\Achievement_Dungeon_HEROIC_GloryoftheRaider",
						['description'] = L["INSTANCE_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Instance");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["DUNGEON"],
						['icon'] = "Interface\\Icons\\Achievement_Dungeon_GloryoftheHERO",
						['description'] = L["DUNGEON_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Dungeon");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["RAID"],
						['icon'] = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider",
						['description'] = L["RAID_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Raid");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["MOUNT"],
						['icon'] = "Interface\\Icons\\Ability_Mount_AlliancePVPMount",
						['description'] = L["MOUNT_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Mount");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["PET"],
						['icon'] = "Interface\\Icons\\INV_Box_02",
						['description'] = L["PET_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Pet");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["QUEST"],
						['icon'] = "Interface\\GossipFrame\\AvailableQuestIcon",
						['preview'] = "Interface\\Icons\\Achievement_Quests_Completed_08",
						['description'] = L["QUEST_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Quest");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["TOY"],
						['icon'] = "Interface\\Icons\\INV_Misc_Toy_10",
						['description'] = L["TOY_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Toy");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					{
						['text'] = L["ZONE"],
						['icon'] = "Interface\\Icons\\INV_Misc_Map_01",
						['description'] = L["ZONE_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app.SetDataMember("RandomSearchFilter", "Zone");
							self:SetData(mainHeader);
							self:Reroll();
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
				},
			};
			mainHeader = {
				['text'] = L["GO_GO_RANDOM"],
				['icon'] = "Interface\\Icons\\Ability_Rogue_RolltheBones.blp",
				["description"] = L["GO_GO_RANDOM_DESC"],
				['visible'] = true,
				['expanded'] = true,
				['OnUpdate'] = app.AlwaysShowUpdate,
				['back'] = 1,
				["indent"] = 0,
				['options'] = {
					{
						['text'] = L["CHANGE_SEARCH_FILTER"],
						['icon'] = "Interface\\Icons\\TRADE_ARCHAEOLOGY.blp",
						["description"] = L["CHANGE_SEARCH_FILTER_DESC"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							self:SetData(filterHeader);
							self:Update(true);
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					rerollOption,
				},
				['g'] = { },
			};
			self:SetData(mainHeader);
			self.Rebuild = function(self, no)
				-- Rebuild all the datas
				wipe(self.data.g);

				-- Call to our method and build a list to draw from
				local method = app.GetDataMember("RandomSearchFilter", "Instance");
				if method then
					rerollOption.text = L["REROLL_2"] .. (method ~= "AllTheThings" and L[method:upper()] or method);
					method = "Select" .. method;
					local temp = self[method]() or app.EmptyTable;
					local totalWeight = 0;
					for i,o in ipairs(temp) do
						totalWeight = totalWeight + ((o.total or 1) - (o.progress or 0));
					end
					if totalWeight > 0 and #temp > 0 then
						local weight, selected = math.random(totalWeight), nil;
						totalWeight = 0;
						for i,o in ipairs(temp) do
							totalWeight = totalWeight + ((o.total or 1) - (o.progress or 0));
							if weight <= totalWeight then
								selected = o;
								break;
							end
						end
						if not selected then selected = temp[#temp - 1]; end
						if selected then
							NestObject(self.data, selected, true);
						else
							app.print(L["NOTHING_TO_SELECT_FROM"]);
						end
					else
						app.print(L["NOTHING_TO_SELECT_FROM"]);
					end
				else
					app.print(L["NO_SEARCH_METHOD"]);
				end
				for i=#self.data.options,1,-1 do
					tinsert(self.data.g, 1, self.data.options[i]);
				end
				BuildGroups(self.data, self.data.g);
				if not no then self:Update(); end
			end
			self.Reroll = function(self)
				Push(self, "Rebuild", self.Rebuild);
			end
			for i,o in ipairs(self.data.options) do
				tinsert(self.data.g, o);
			end
			local method = app.GetDataMember("RandomSearchFilter", "Instance");
			rerollOption.text = L["REROLL_2"] .. (method ~= "AllTheThings" and L[method:upper()] or method);
		end

		-- Update the window and all of its row data
		self.data.progress = 0;
		self.data.total = 0;
		self.data.indent = 0;
		BuildGroups(self.data, self.data.g);
		self:BaseUpdate(true);
	end
end;
customWindowUpdates["Sync"] = function(self)
	if self:IsVisible() then
		if not self.initialized then
			self.initialized = true;

			local function OnRightButtonDeleteCharacter(row, button)
				if button == "RightButton" then
					app:ShowPopupDialog("CHARACTER DATA: " .. (row.ref.text or RETRIEVING_DATA) .. L["CONFIRM_DELETE"],
					function()
						ATTCharacterData[row.ref.datalink] = nil;
						app:RecalculateAccountWideData();
						self:Reset();
					end);
				end
				return true;
			end
			local function OnRightButtonDeleteLinkedAccount(row, button)
				if button == "RightButton" then
					app:ShowPopupDialog("LINKED ACCOUNT: " .. (row.ref.text or RETRIEVING_DATA) .. L["CONFIRM_DELETE"],
					function()
						AllTheThingsAD.LinkedAccounts[row.ref.datalink] = nil;
						app:SynchronizeWithPlayer(row.ref.datalink);
						self:Reset();
					end);
				end
				return true;
			end
			local function OnTooltipForCharacter(t)
				local character = ATTCharacterData[t.unit];
				if character then
					-- last login info
					local login = character.lastPlayed;
					if login then
						local d = C_DateAndTime.GetCalendarTimeFromEpoch(login * 1e6);
						GameTooltip:AddDoubleLine(PLAYED, sformat("%d-%02d-%02d %02d:%02d", d.year, d.month, d.monthDay, d.hour, d.minute), 0.8, 0.8, 0.8);
					else
						GameTooltip:AddDoubleLine(PLAYED, NEVER, 0.8, 0.8, 0.8);
					end
					local total = 0;
					for i,field in ipairs({ "Achievements", "Buildings", --[["Exploration",]] "Factions", "FlightPaths", "Followers", "Spells", "Titles", "Quests" }) do
						local values = character[field];
						if values then
							local subtotal = 0;
							for key,value in pairs(values) do
								if value then
									subtotal = subtotal + 1;
								end
							end
							total = total + subtotal;
							GameTooltip:AddDoubleLine(field, tostring(subtotal), 1, 1, 1);
						end
					end
					GameTooltip:AddLine(" ", 1, 1, 1);
					GameTooltip:AddDoubleLine("Total", tostring(total), 0.8, 0.8, 1);
					GameTooltip:AddLine(L["DELETE_CHARACTER"], 1, 0.8, 0.8);
				end
			end
			local function OnTooltipForLinkedAccount(t)
				if t.unit then
					GameTooltip:AddLine(L["LINKED_ACCOUNT_TOOLTIP"], 0.8, 0.8, 1, true);
					GameTooltip:AddLine(L["DELETE_LINKED_CHARACTER"], 1, 0.8, 0.8);
				else
					GameTooltip:AddLine(L["DELETE_LINKED_ACCOUNT"], 1, 0.8, 0.8);
				end
			end

			local syncHeader;
			syncHeader = {
				['text'] = L["ACCOUNT_MANAGEMENT"],
				['icon'] = "Interface\\Icons\\Achievement_Dungeon_HEROIC_GloryoftheRaider",
				["description"] = L["ACCOUNT_MANAGEMENT_TOOLTIP"],
				['visible'] = true,
				['expanded'] = true,
				['back'] = 1,
				['OnUpdate'] = app.AlwaysShowUpdate,
				['g'] = {
					{
						['text'] = L["ADD_LINKED_CHARACTER_ACCOUNT"],
						['icon'] = "Interface\\Icons\\Ability_Priest_VoidShift",
						['description'] = L["ADD_LINKED_CHARACTER_ACCOUNT_TOOLTIP"],
						['visible'] = true,
						['OnClick'] = function(row, button)
							app:ShowPopupDialogWithEditBox(L["ADD_LINKED_POPUP"], "", function(cmd)
								if cmd and cmd ~= "" then
									AllTheThingsAD.LinkedAccounts[cmd] = true;
									self:Reset();
								end
							end);
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
					-- Characters Section
					{
						['text'] = L["CHARACTERS"],
						['icon'] = "Interface\\FriendsFrame\\Battlenet-Portrait",
						["description"] = L["SYNC_CHARACTERS_TOOLTIP"],
						['OnUpdate'] = function(data)
							data.g = {};
							for guid,character in pairs(ATTCharacterData) do
								if character then
									table.insert(data.g, app.CreateUnit(guid, {
										['datalink'] = guid,
										['OnClick'] = OnRightButtonDeleteCharacter,
										['OnTooltip'] = OnTooltipForCharacter,
										['OnUpdate'] = app.AlwaysShowUpdate,
										['visible'] = true,
									}));
								end
							end

							if #data.g < 1 then
								table.insert(data.g, {
									['text'] = L["NO_CHARACTERS_FOUND"],
									['icon'] = "Interface\\FriendsFrame\\Battlenet-Portrait",
									['visible'] = true,
								});
							end
							app.Sort(data.g, syncHeader.Sort);
							BuildGroups(data, data.g);
							return app.AlwaysShowUpdate(data);
						end,
						['visible'] = true,
						['expanded'] = true,
						['g'] = {},
					},

					-- Linked Accounts Section
					{
						['text'] = L["LINKED_ACCOUNTS"],
						['icon'] = "Interface\\FriendsFrame\\Battlenet-Portrait",
						["description"] = L["LINKED_ACCOUNTS_TOOLTIP"],
						['OnUpdate'] = function(data)
							data.g = {};
							local charactersByName = {};
							for guid,character in pairs(ATTCharacterData) do
								if character.name then
									charactersByName[character.name] = character;
								end
							end

							for playerName,allowed in pairs(AllTheThingsAD.LinkedAccounts) do
								local character = charactersByName[playerName];
								if character then
									table.insert(data.g, app.CreateUnit(playerName, {
										['datalink'] = playerName,
										['OnClick'] = OnRightButtonDeleteLinkedAccount,
										['OnTooltip'] = OnTooltipForLinkedAccount,
										['OnUpdate'] = app.AlwaysShowUpdate,
										['visible'] = true,
									}));
								elseif string.find("#", playerName) then
									-- Garbage click handler for unsync'd account data.
									table.insert(data.g, {
										['text'] = playerName,
										['datalink'] = playerName,
										['icon'] = "Interface\\FriendsFrame\\Battlenet-Portrait",
										['OnClick'] = OnRightButtonDeleteLinkedAccount,
										['OnTooltip'] = OnTooltipForLinkedAccount,
										['OnUpdate'] = app.AlwaysShowUpdate,
										['visible'] = true,
									});
								else
									-- Garbage click handler for unsync'd character data.
									table.insert(data.g, {
										['text'] = playerName,
										['datalink'] = playerName,
										['icon'] = "Interface\\FriendsFrame\\Battlenet-WoWicon",
										['OnClick'] = OnRightButtonDeleteLinkedAccount,
										['OnTooltip'] = OnTooltipForLinkedAccount,
										['OnUpdate'] = app.AlwaysShowUpdate,
										['visible'] = true,
									});
								end
							end

							if #data.g < 1 then
								table.insert(data.g, {
									['text'] = L["NO_LINKED_ACCOUNTS"],
									['icon'] = "Interface\\FriendsFrame\\Battlenet-Portrait",
									['visible'] = true,
								});
							end
							BuildGroups(data, data.g);
							return app.AlwaysShowUpdate(data);
						end,
						['visible'] = true,
						['expanded'] = true,
						['g'] = {},
					},
				},
				['Sort'] = function(a, b)
					return b.text > a.text;
				end,
			};

			self.Reset = function()
				self:SetData(syncHeader);
				self:Update(true);
			end
			self:Reset();
		end

		-- Update the groups without forcing Debug Mode.
		if self.data.OnUpdate then self.data.OnUpdate(self.data, self); end
		self:BuildData();
		for i,g in ipairs(self.data.g) do
			if g.OnUpdate then g.OnUpdate(g, self); end
		end
		self:BaseUpdate(true);
	end
end;
customWindowUpdates["quests"] = function(self, force, got)
	if not self.initialized then
		-- temporarily prevent a force refresh from exploding the game if this window is open
		self.doesOwnUpdate = true;
		self.initialized = true;
		self.PartitionSize = 1000;
		self.Limit = 80000;
		force = true;
		local HaveQuestData = HaveQuestData;
		local DGU, Run = app.DirectGroupUpdate, app.FunctionRunner.Run;

		-- custom params for initialization
		local onlyMissing = app.GetCustomWindowParam("quests", "missing");
		local onlyCached = app.GetCustomWindowParam("quests", "cached");
		-- print("Quests - onlyMissing",onlyMissing)

		-- info about the Window
		self:SetData({
			["text"] = L["QUESTS_CHECKBOX"],
			["icon"] = app.asset("Interface_Quest_header"),
			["description"] = L["QUESTS_DESC"].."\n\n1 - "..self.Limit,
			["visible"] = true,
			["expanded"] = true,
			["indent"] = 0,
		});

		-- add a bunch of raw, delay-loaded quests in order into the window
		local groupCount = self.Limit / self.PartitionSize - 1;
		local g, overrides = {}, {
			visible = true,
			indent = 2,
			back = function(o, key)
				return o._missing and 1 or 0;
			end,
			text = function(o, key)
				if o.text and o.text ~= RETRIEVING_DATA then
					return "#"..o.questID..": "..o.text;
				end
			end,
			OnLoad = function(self)
				-- app.PrintDebug("DGU-OnLoad:",self.hash)
				Run(DGU, self);
			end,
		};
		if onlyMissing then
			if onlyCached then
				overrides.visible = function(o, key)
					return o._missing and HaveQuestData(o.questID);
				end
			else
				overrides.visible = function(o, key)
					return o._missing;
				end
			end
		end
		local partition, partitionStart, partitionGroups;
		local dlo = app.DelayLoadedObject;
		for j=0,groupCount,1 do
			partitionStart = j * self.PartitionSize;
			partitionGroups = {};
			-- define a sub-group for a range of quests
			partition = {
				["text"] = tostring(partitionStart + 1).."+",
				["icon"] = app.asset("Interface_Quest_header"),
				["visible"] = true,
				["g"] = partitionGroups,
			};
			for i=1,self.PartitionSize,1 do
				tinsert(partitionGroups, dlo(GetPopulatedQuestObject, "text", overrides, partitionStart + i));
			end
			tinsert(g, partition);
		end
		self.data.g = g;
		self:BuildData();
	end
	if self:IsVisible() then
		self:BaseUpdate(force);
	end
end
customWindowUpdates["Tradeskills"] = function(self, force, got)
	if not self.initialized then
		-- cache some common functions
		local C_TradeSkillUI = C_TradeSkillUI;
		local C_TradeSkillUI_GetCategoryInfo = C_TradeSkillUI.GetCategoryInfo;
		local C_TradeSkillUI_GetRecipeInfo = C_TradeSkillUI.GetRecipeInfo;
		local C_TradeSkillUI_GetRecipeSchematic = C_TradeSkillUI.GetRecipeSchematic;

		self.initialized = true;
		self.SkillsInit = {};
		self.force = true;
		self:SetMovable(false);
		self:SetUserPlaced(false);
		self:SetClampedToScreen(false);
		self:RegisterEvent("TRADE_SKILL_SHOW");
		self:RegisterEvent("TRADE_SKILL_LIST_UPDATE");
		self:RegisterEvent("TRADE_SKILL_CLOSE");
		self:RegisterEvent("GARRISON_TRADESKILL_NPC_CLOSED");
		self:RegisterEvent("NEW_RECIPE_LEARNED");
		self:SetData({
			['text'] = L["PROFESSION_LIST"],
			['icon'] = "Interface\\Icons\\INV_Scroll_04.blp",
			["description"] = L["PROFESSION_LIST_DESC"],
			['visible'] = true,
			['expanded'] = true,
			["indent"] = 0,
			['back'] = 1,
			['g'] = { },
		});

		-- Adds the pertinent information about a given recipeID to the reagentcache
		local function CacheRecipeSchematic(recipeID, skipcaching, reagentCache)
			local schematic = C_TradeSkillUI_GetRecipeSchematic(recipeID, false);
			local craftedItemID = schematic.outputItemID;
			-- app.PrintDebug("Recipe",recipeID,"==>",craftedItemID)
			local reagentItem, reagentCount;
			-- Recipes now have Slots for available Regeants...
			for _,reagentSlot in ipairs(schematic.reagentSlotSchematics) do
				-- reagentType: 1 = required, 0 = optional
				if reagentSlot.reagentType == 1 then
					reagentCount = reagentSlot.quantityRequired;
					-- Each available Reagent for the Slot can be associated to the Recipe/Output Item
					for _,reagentItemID in ipairs(reagentSlot.reagents) do
						-- Make sure a cache table exists for this item.
						-- Index 1: The Recipe Skill IDs => { craftedID, reagentCount }
						-- Index 2: The Crafted Item IDs => reagentCount
						-- TODO: potentially re-design this structure
						if reagentItemID then
							reagentItem = reagentCache[reagentItemID];
							if skipcaching then
								-- remove any existing cached recipes
								if reagentItem then
									-- app.PrintDebug("removing reagent cache info",reagentItemID,recipeID,craftedItemID)
									reagentItem[1][recipeID] = nil;
									reagentItem[2][craftedItemID] = nil;
								end
							else
								if not reagentItem then
									reagentItem = { {}, {} };
									reagentCache[reagentItemID] = reagentItem;
								end
								reagentItem[1][recipeID] = { craftedItemID, reagentCount };
								reagentItem[2][craftedItemID] = reagentCount;
							end
						end

					end
				end
			end
		end
		local function UpdateLocalizedCategories(self, updates)
			if not updates["Categories"] then
				-- app.PrintDebug("UpdateLocalizedCategories",self.lastTradeSkillID)
				local currentCategoryID, categories = -1, AllTheThingsAD.LocalizedCategoryNames;
				updates["Categories"] = true;
				local categoryIDs = { C_TradeSkillUI.GetCategories() };
				for i = 1,#categoryIDs do
					currentCategoryID = categoryIDs[i];
					if not categories[currentCategoryID] then
						local categoryData = C_TradeSkillUI_GetCategoryInfo(currentCategoryID);
						if categoryData then
							categories[currentCategoryID] = categoryData.name;
						end
					end
				end
			end
		end
		local function UpdateLearnedRecipes(self, updates)
			-- Cache learned recipes
			if not updates["Recipes"] then
				-- app.PrintDebug("UpdateLearnedRecipes",self.lastTradeSkillID)
				updates["Recipes"] = true;
				local learned, recipeID = {};
				local reagentCache = app.GetDataMember("Reagents", {});
				local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs();
				local acctSpells, charSpells = ATTAccountWideData.Spells, app.CurrentCharacter.Spells;
				local skipcaching, spellRecipeInfo, categoryData, cachedRecipe, currentCategoryID;
				local categories = AllTheThingsAD.LocalizedCategoryNames;
				-- print("Scanning recipes",#recipeIDs)
				for i = 1,#recipeIDs do
					spellRecipeInfo = C_TradeSkillUI_GetRecipeInfo(recipeIDs[i]);
					if spellRecipeInfo then
						skipcaching = nil;
						recipeID = spellRecipeInfo.recipeID;
						currentCategoryID = spellRecipeInfo.categoryID;
						if not categories[currentCategoryID] then
							categoryData = C_TradeSkillUI_GetCategoryInfo(currentCategoryID);
							if categoryData then
								categories[currentCategoryID] = categoryData.name;
							end
						end
						-- cannot be crafted, so don't cache the outputs for reagent tooltips
						if spellRecipeInfo.disabled then
							skipcaching = true;
						end
						-- recipe is learned, so cache that it's learned regardless of being craftable
						if spellRecipeInfo.learned then
							-- Shadowlands recipes are weird...
							local rank = spellRecipeInfo.unlockedRecipeLevel or 0;
							if rank > 0 then
								-- when the recipeID specifically is available, it will show as available for ALL possible ranks
								-- so we can check if the next known rank is also considered available for this recipeID
								spellRecipeInfo = C_TradeSkillUI_GetRecipeInfo(recipeID, rank + 1);
								-- app.PrintDebug("NextRankCheck",recipeID,rank + 1, spellRecipeInfo.learned)
							end
						end
						-- recipe is learned, so cache that it's learned regardless of being craftable
						if spellRecipeInfo.learned then
							charSpells[recipeID] = 1;
							if not acctSpells[recipeID] then
								acctSpells[recipeID] = 1;
								tinsert(learned, recipeID);
							end
						else
							-- unlearned recipes shouldn't be marked as known by the character
							if charSpells[recipeID] then
								charSpells[recipeID] = nil;
								-- local link = app:Linkify(recipeID, app.Colors.ChatLink, "search:spellID:"..recipeID);
								-- app.PrintDebug("Unlearned Recipe", link);
							end
							-- enabled, unlearned recipes should be checked against ATT data to verify they CAN actually be learned
							-- also, don't remove the data if *any* character on the account is marked as knowing the recipe
							if not spellRecipeInfo.disabled and not acctSpells[recipeID] then
								-- print("unlearned, enabled RecipeID",recipeID)
								cachedRecipe = app.SearchForMergedObject("spellID", recipeID);
								-- verify the merged cached version is not 'super' unobtainable
								if cachedRecipe and cachedRecipe.u and cachedRecipe.u < 3 then
									-- print("Ignoring Unobtainable RecipeID",recipeID,cachedRecipe.u)
									skipcaching = true;
								end
							end
						end

						-- Does this Recipe craft an Item?
						if spellRecipeInfo.createsItem then
							CacheRecipeSchematic(recipeID, skipcaching, reagentCache);
						end
					end
				end
				-- If something new was "learned", then refresh the data.
				UpdateRawIDs("spellID", learned);
				if #learned > 0 then
					app:PlayRareFindSound();
					app:TakeScreenShot("Recipes");
					self.force = true;
				end
			end
		end
		local function UpdateData(self, updates)
			-- Open the Tradeskill list for this Profession
			local data = updates["Data"];
			if not data then
				-- app.PrintDebug("UpdateData",self.lastTradeSkillID)
				data = app.CreateProfession(self.lastTradeSkillID);
				app.BuildSearchResponse_IgnoreUnavailableRecipes = true;
				NestObjects(data, app:BuildSearchResponse(app:GetDataCache().g, "requireSkill", data.requireSkill));
				app.BuildSearchResponse_IgnoreUnavailableRecipes = nil;
				data.indent = 0;
				data.visible = true;
				BuildGroups(data, data.g);
				updates["Data"] = data;
				-- only expand the list if this is the first time it is being generated
				self.ExpandInfo = { Expand = true };
				self.force = true;
			end
			self:SetData(data);
			self:Update(self.force);
		end
		-- Can trigger multiple times quickly, but will only run once per profession in a row
		self.RefreshRecipes = function(self)
			-- app.PrintDebug("RefreshRecipes")
			if app.CollectibleRecipes then
				-- Cache Learned Spells
				local skillCache = fieldCache["spellID"];
				if not skillCache then return; end

				local tradeSkillID = app.GetTradeSkillLine();
				if not tradeSkillID or tradeSkillID == self.lastTradeSkillID then return; end

				-- If it's not yours, don't take credit for it.
				if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then return; end

				self.lastTradeSkillID = tradeSkillID;
				local updates = self.SkillsInit[tradeSkillID] or {};
				self.SkillsInit[tradeSkillID] = updates;

				app.FunctionRunner.SetPerFrame(1);
				app.FunctionRunner.Run(UpdateLocalizedCategories, self, updates);
				app.FunctionRunner.Run(UpdateLearnedRecipes, self, updates);
				app.FunctionRunner.Run(UpdateData, self, updates);
			end
		end

		-- TSM Shenanigans
		self.TSMCraftingVisible = nil;
		self.SetTSMCraftingVisible = function(self, visible)
			visible = not not visible;
			if visible == self.TSMCraftingVisible then
				return;
			end
			self.TSMCraftingVisible = visible;
			self:SetMovable(true);
			self:ClearAllPoints();
			if visible and self.cachedTSMFrame then
				if self.cachedTSMFrame.queue and self.cachedTSMFrame.queue:IsShown() then
					self:SetPoint("TOPLEFT", self.cachedTSMFrame.queue, "TOPRIGHT", 0, 0);
					self:SetPoint("BOTTOMLEFT", self.cachedTSMFrame.queue, "BOTTOMRIGHT", 0, 0);
				else
					self:SetPoint("TOPLEFT", self.cachedTSMFrame, "TOPRIGHT", 0, 0);
					self:SetPoint("BOTTOMLEFT", self.cachedTSMFrame, "BOTTOMRIGHT", 0, 0);
				end
				self:SetMovable(false);
			-- Skillet compatibility
			elseif SkilletFrame then
				self:SetPoint("TOPLEFT", SkilletFrame, "TOPRIGHT", 0, 0);
				self:SetPoint("BOTTOMLEFT", SkilletFrame, "BOTTOMRIGHT", 0, 0);
				self:SetMovable(true);
			elseif TradeSkillFrame then
				-- Default Alignment on the WoW UI.
				self:SetPoint("TOPLEFT", TradeSkillFrame, "TOPRIGHT", 0, 0);
				self:SetPoint("BOTTOMLEFT", TradeSkillFrame, "BOTTOMRIGHT", 0, 0);
				self:SetMovable(false);
			elseif ProfessionsFrame then
				-- Default Alignment on the 10.0 WoW UI
				self:SetPoint("TOPLEFT", ProfessionsFrame, "TOPRIGHT", 0, 0);
				self:SetPoint("BOTTOMLEFT", ProfessionsFrame, "BOTTOMRIGHT", 0, 0);
				self:SetMovable(false);
			else
				self:SetMovable(false);
				StartCoroutine("TSMWHY", function()
					while InCombatLockdown() or not TradeSkillFrame do coroutine.yield(); end
					StartCoroutine("TSMWHYPT2", function()
						local thing = self.TSMCraftingVisible;
						self.TSMCraftingVisible = nil;
						self:SetTSMCraftingVisible(thing);
					end);
				end);
				return;
			end
			AfterCombatCallback(self.Update, self);
		end
		-- Setup Event Handlers and register for events
		self:SetScript("OnEvent", function(self, e, ...)
			-- print("Tradeskills.event",e,...)
			if e == "TRADE_SKILL_LIST_UPDATE" then
				if self:IsVisible() then
					-- If it's not yours, don't take credit for it.
					if C_TradeSkillUI.IsTradeSkillLinked() or C_TradeSkillUI.IsTradeSkillGuild() then
						self:SetVisible(false);
						return false;
					end

					-- Check to see if ATT has information about this profession.
					local tradeSkillID = app.GetTradeSkillLine();
					if not tradeSkillID or not fieldCache["professionID"][tradeSkillID] then
						self:SetVisible(false);
						return false;
					end
				end
				self:RefreshRecipes();
			elseif e == "TRADE_SKILL_SHOW" then
				if self.TSMCraftingVisible == nil then
					self:SetTSMCraftingVisible(false);
				end
				if app.Settings:GetTooltipSetting("Auto:ProfessionList") then
					-- Check to see if ATT has information about this profession.
					local tradeSkillID = app.GetTradeSkillLine();
					if not tradeSkillID or not fieldCache["professionID"][tradeSkillID] then
						self:SetVisible(false);
					else
						self:SetVisible(true);
					end
				end
				self:RefreshRecipes();
			elseif e == "NEW_RECIPE_LEARNED" then
				-- spellID, rank, previousSpellID
				local spellID = ...;
				if spellID then
					local previousState = ATTAccountWideData.Spells[spellID];
					ATTAccountWideData.Spells[spellID] = 1;
					if not app.CurrentCharacter.Spells[spellID] then
						app.CurrentCharacter.Spells[spellID] = 1;
						UpdateSearchResults(SearchForField("spellID",spellID));
						if not previousState or not app.Settings:Get("AccountWide:Recipes") then
							app:PlayFanfare();
							app:TakeScreenShot("Recipes");
							if app.Settings:GetTooltipSetting("Report:Collected") then
								local link = app:Linkify(spellID, app.Colors.ChatLink, "search:spellID:"..spellID);
								print(NEW_RECIPE_LEARNED_TITLE, link);
							end
						end
						wipe(searchCache);
					end
				end
			elseif e == "TRADE_SKILL_CLOSE"
				or e == "GARRISON_TRADESKILL_NPC_CLOSED" then
				self:SetVisible(false);
			end
		end);
		return;
	end
	if self:IsVisible() then
		if TSM_API and TSMAPI_FOUR then
			if not self.cachedTSMFrame then
				for i,f in ipairs({UIParent:GetChildren()}) do
					if f.headerBgCenter then
						self.cachedTSMFrame = f;
						local oldSetVisible = f.SetVisible;
						local oldShow = f.Show;
						local oldHide = f.Hide;
						f.SetVisible = function(s, visible)
							oldSetVisible(s, visible);
							self:SetTSMCraftingVisible(visible);
						end
						f.Hide = function(s)
							oldHide(s);
							self:SetTSMCraftingVisible(false);
						end
						f.Show = function(s)
							oldShow(s);
							self:SetTSMCraftingVisible(true);
						end
						if self.gettinMadAtDumbNamingConventions then
							TSMAPI_FOUR.UI.NewElement = self.OldNewElement;
							self.gettinMadAtDumbNamingConventions = nil;
							self.OldNewElement = nil;
						end
						self:SetTSMCraftingVisible(f:IsShown());
						return;
					end
				end
				if not self.gettinMadAtDumbNamingConventions then
					self.gettinMadAtDumbNamingConventions = true;
					self.OldNewElement = TSMAPI_FOUR.UI.NewElement;
					TSMAPI_FOUR.UI.NewElement = function(...)
						AfterCombatCallback(self.Update, self);
						return self.OldNewElement(...);
					end
				end
			end
		elseif TSMCraftingTradeSkillFrame then
			-- print("TSMCraftingTradeSkillFrame")
			if not self.cachedTSMFrame then
				local f = TSMCraftingTradeSkillFrame;
				self.cachedTSMFrame = f;
				local oldSetVisible = f.SetVisible;
				local oldShow = f.Show;
				local oldHide = f.Hide;
				f.SetVisible = function(s, visible)
					oldSetVisible(s, visible);
					self:SetTSMCraftingVisible(visible);
				end
				f.Hide = function(s)
					oldHide(s);
					self:SetTSMCraftingVisible(false);
				end
				f.Show = function(s)
					oldShow(s);
					self:SetTSMCraftingVisible(true);
				end
				if f.queueBtn then
					local setScript = f.queueBtn.SetScript;
					f.queueBtn.SetScript = function(s, e, callback)
						if e == "OnClick" then
							setScript(s, e, function(...)
								if callback then callback(...); end

								local thing = self.TSMCraftingVisible;
								self.TSMCraftingVisible = nil;
								self:SetTSMCraftingVisible(thing);
							end);
						else
							setScript(s, e, callback);
						end
					end
					f.queueBtn:SetScript("OnClick", f.queueBtn:GetScript("OnClick"));
				end
				self:SetTSMCraftingVisible(f:IsShown());
				return;
			end
		end

		-- Update the window and all of its row data
		self:BaseUpdate(force or self.force or got, got);
		self.force = nil;
	end
end;
customWindowUpdates["WorldQuests"] = function(self, force, got)
	-- localize some APIs
	local C_TaskQuest_GetQuestsForPlayerByMapID = C_TaskQuest.GetQuestsForPlayerByMapID;
	local C_QuestLine_RequestQuestLinesForMap = C_QuestLine.RequestQuestLinesForMap;
	local C_QuestLine_GetAvailableQuestLines = C_QuestLine.GetAvailableQuestLines;
	local C_Map_GetMapChildrenInfo = C_Map.GetMapChildrenInfo;
	local C_AreaPoiInfo_GetAreaPOISecondsLeft = C_AreaPoiInfo.GetAreaPOISecondsLeft;
	local C_QuestLog_GetBountiesForMapID = C_QuestLog.GetBountiesForMapID;
	local SecondsToTime = SecondsToTime;
	local GetNumRandomDungeons, GetLFGDungeonInfo, GetLFGRandomDungeonInfo, GetLFGDungeonRewards, GetLFGDungeonRewardInfo =
		  GetNumRandomDungeons, GetLFGDungeonInfo, GetLFGRandomDungeonInfo, GetLFGDungeonRewards, GetLFGDungeonRewardInfo;

	if self:IsVisible() then
		if not self.initialized then
			self.initialized = true;
			force = true;
			local data = {
				['text'] = L["WORLD_QUESTS"],
				['icon'] = "Interface\\Icons\\INV_Misc_Map08.blp",
				["description"] = L["WORLD_QUESTS_DESC"],
				['visible'] = true,
				['expanded'] = true,
				["indent"] = 0,
				['back'] = 1,
				['g'] = {
					{
						['text'] = L["UPDATE_WORLD_QUESTS"],
						['icon'] = "Interface\\Icons\\INV_Misc_Map_01",
						['description'] = L["UPDATE_WORLD_QUESTS_DESC"],
						['hash'] = "funUpdateWorldQuests",
						['OnClick'] = function(data, button)
							Push(self, "WorldQuests-Rebuild", self.Rebuild);
							return true;
						end,
						['OnUpdate'] = app.AlwaysShowUpdate,
					},
				},
			};
			self:SetData(data);
			-- Build the initial heirarchy
			self:BuildData();
			local emissaryMapIDs = {
				{ 619, 650 },	-- Broken Isles, Highmountain
				{ app.FactionID == Enum.FlightPathFaction.Horde and 875 or 876, 895 },	-- Kul'Tiras or Zandalar, Stormsong Valley
			};
			local worldMapIDs = {
				-- Shadowlands Continents
				{
					1550,	-- Shadowlands
					{
						-- TODO: callings?
					}
				},
				-- BFA Continents
				{
					875,	-- Zandalar
					{
						{ 863, 5969, { 54135, 54136 }},	-- Nazmir (Romp in the Swamp [H] / March on the Marsh [A])
						{ 864, 5970, { 53885, 54134 }},	-- Voldun (Isolated Victory [H] / Many Fine Heroes [A])
						{ 862, 5973, { 53883, 54138 }},	-- Zuldazar (Shores of Zuldazar [H] / Ritual Rampage [A])
					}
				},
				{
					876,	-- Kul'Tiras
					{
						{ 896, 5964, { 54137, 53701 }},	-- Drustvar (In Every Dark Corner [H] / A Drust Cause [A])
						{ 942, 5966, { 54132, 51982 }},	-- Stormsong Valley (A Horde of Heroes [H] / Storm's Rage [A])
						{ 895, 5896, { 53939, 53711 }},	-- Tiragarde Sound (Breaching Boralus [H] / A Sound Defense [A])
					}
				},
				{ 1355 },	-- Nazjatar
				-- Legion Continents
				{
					619, 	-- Broken Isles
					{
						{ 627 },	-- Dalaran (not a Zone, so doesn't list automatically)
						{ 630, 5175, { 47063 }},	-- Azsuna
						{ 650, 5177, { 47063 }},	-- Highmountain
						{ 634, 5178, { 47063 }},	-- Stormheim
						{ 641, 5210, { 47063 }},	-- Val'Sharah
					}
				},
				{ 905 },	-- Argus
				-- WoD Continents
				{ 572 },	-- Draenor
				-- MoP Continents
				{
					424,	-- Pandaria
					{
						{ 1530, 6489, { 56064 }},	-- Assault: The Black Empire
						{ 1530, 6491, { 57728 }},	-- Assault: The Endless Swarm
						{ 1530, 6490, { 57008 }},	-- Assault: The Warring Clans
					},
				},
				-- Cataclysm Continents
				{ 948 },	-- The Maelstrom
				-- WotLK Continents
				{ 113 },	-- Northrend
				-- BC Continents
				{ 101 }, 	-- Outland
				-- Vanilla Continents
				{
					12,		-- Kalimdor
					{
						{ 1527, 6486, { 57157 }},	-- Assault: The Black Empire
						{ 1527, 6488, { 56308 }},	-- Assault: Aqir Unearthed
						{ 1527, 6487, { 55350 }},	-- Assault: Amathet Advance
						{ 62 },	-- Darkshore
					},
				},
				{	13,		-- Eastern Kingdoms
					{
						{ 14 },	-- Arathi Highlands
					},
				},
			};
			self.Clear = function(self)
				local temp = self.data.g[1];
				wipe(self.data.g);
				tinsert(self.data.g, temp);
				self:Update(true);
			end
			-- World Quests (Tasks)
			self.MergeTasks = function(self, mapObject)
				local mapID = mapObject.mapID;
				if not mapID then return; end
				local pois = C_TaskQuest_GetQuestsForPlayerByMapID(mapID);
				-- print(#pois,"WQ in",mapID);
				if pois then
					for i,poi in ipairs(pois) do
						-- only include Tasks on this actual mapID since each Zone mapID is checked individually
						if poi.mapID == mapID then
							local questObject = GetPopulatedQuestObject(poi.questId);
							if self.includeAll or
								-- include the quest in the list if holding shift and tracking quests
								(self.includePermanent and self.includeQuests) or
								-- or if it is repeatable (i.e. one attempt per day/week/year)
								questObject.repeatable or
								-- or if it has time remaining
								(questObject.timeRemaining or 0 > 0) then
								-- if mapID == 1355 then
									-- app.PrintDebug("WQ",questObject.questID);
								-- end
								NestObject(mapObject, questObject);
								-- see if need to retry based on missing data
								-- if not self.retry and questObject.missingData then self.retry = true; end
							end
						-- else app.PrintDebug("Skipped WQ",mapID,poi.mapID,poi.questId)
						end
					end
				end
			end
			-- Storylines/Map Quest Icons
			self.MergeStorylines = function(self, mapObject)
				local mapID = mapObject.mapID;
				if not mapID then return; end
				C_QuestLine_RequestQuestLinesForMap(mapID);
				local questLines = C_QuestLine_GetAvailableQuestLines(mapID)
				if questLines then
					for id,questLine in pairs(questLines) do
						-- dont show 'hidden' quest lines... not sure what this is exactly
						if not questLine.hidden then
							local questObject = GetPopulatedQuestObject(questLine.questID);
							if self.includeAll or
								-- include the quest in the list if holding shift and tracking quests
								(self.includePermanent and self.includeQuests) or
								-- or if it is repeatable (i.e. one attempt per day/week/year)
								questObject.repeatable or
								-- or if it has time remaining
								(questObject.timeRemaining or 0 > 0) then
								NestObject(mapObject, questObject);
								-- see if need to retry based on missing data
								-- if not self.retry and questObject.missingData then self.retry = true; end
							end
						end
					end
				else
					-- print("No questline data yet for mapID:",mapID);
					self.retry = true;
				end
			end
			self.BuildMapAndChildren = function(self, mapObject)
				if not mapObject.mapID then return; end

				-- print("Build Map",mapObject.mapID,mapObject.text);

				-- Merge Tasks for Zone
				self:MergeTasks(mapObject);

				-- Merge Storylines for Zone
				self:MergeStorylines(mapObject);

				-- look for quests on map child maps as well
				local mapChildInfos = C_Map_GetMapChildrenInfo(mapObject.mapID, 3);
				if mapChildInfos then
					for _,mapInfo in ipairs(mapChildInfos) do
						-- start fetching the data while other stuff is setup
						C_QuestLine_RequestQuestLinesForMap(mapInfo.mapID);
						local subMapObject = app.CreateMapWithStyle(mapInfo.mapID);

						-- Merge Tasks for Zone
						self:MergeTasks(subMapObject);

						-- Merge Storylines for Zone
						self:MergeStorylines(subMapObject);

						-- Build children of this map as well
						self:BuildMapAndChildren(subMapObject);

						NestObject(mapObject, subMapObject);
					end
				end
			end
			self.Rebuild = function(self, no)
				-- Already filled with data and nothing needing to retry, just give it a forced update pass since data for quests should now populate dynamically
				if not self.retry and #self.data.g > 1 then
					-- print("Already WQ data, just update again")
					-- Force Update Callback
					Callback(self.Update, self, true);
					return;
				end
				-- Rebuild all World Quest data
				-- print("Rebuild WQ Data")
				self.retry = nil;
				-- Put a 'Clear World Quests' click first in the list
				local temp = {{
					['text'] = L["CLEAR_WORLD_QUESTS"],
					['icon'] = "Interface\\Icons\\ability_racial_haymaker",
					['description'] = L["CLEAR_WORLD_QUESTS_DESC"],
					['hash'] = "funClearWorldQuests",
					['OnClick'] = function(data, button)
						Push(self, "WorldQuests-Clear", self.Clear);
						return true;
					end,
					['OnUpdate'] = app.AlwaysShowUpdate,
				}};

				-- options when refreshing the list
				self.includeAll = app.MODE_DEBUG;
				self.includeQuests = app.CollectibleQuests or app.CollectibleQuestsLocked;
				self.includePermanent = IsAltKeyDown() or self.includeAll;

				-- Acquire all of the world mapIDs
				for _,pair in ipairs(worldMapIDs) do
					local mapID = pair[1];
					-- print("WQ.WorldMapIDs." , mapID)
					-- start fetching the data while other stuff is setup
					C_QuestLine_RequestQuestLinesForMap(mapID);
					local mapObject = app.CreateMapWithStyle(mapID);

					-- Build top-level maps all the way down
					self:BuildMapAndChildren(mapObject);

					-- Invasions
					local mapIDPOIPairs = pair[2];
					if mapIDPOIPairs then
						for i,arr in ipairs(mapIDPOIPairs) do
							-- Sub-Map with Quest information to track
							if #arr >= 3 then
								for j,questID in ipairs(arr[3]) do
									if not IsQuestFlaggedCompleted(questID) then
										local timeLeft = C_AreaPoiInfo_GetAreaPOISecondsLeft(arr[2]);
										if timeLeft and timeLeft > 0 then
											local questObject = GetPopulatedQuestObject(questID);

											-- Custom time remaining based on the map POI since the quest itself does not indicate time remaining
											if not questObject.timeRemaining then
												local description = BONUS_OBJECTIVE_TIME_LEFT:format(SecondsToTime(timeLeft * 60));
												if timeLeft < 30 then
													description = "|cFFFF0000" .. description .. "|r";
												elseif timeLeft < 60 then
													description = "|cFFFFFF00" .. description .. "|r";
												end
												if not questObject.description then
													questObject.description = description;
												else
													questObject.description = questObject.description .. "\n\n" .. description;
												end
											end

											local subMapObject = app.CreateMapWithStyle(arr[1]);
											NestObject(subMapObject, questObject);
											NestObject(mapObject, subMapObject);
										end
									end
								end
							else
								-- Basic Sub-map
								local subMap = app.CreateMapWithStyle(arr[1]);

								-- Build top-level maps all the way down for the sub-map
								self:BuildMapAndChildren(subMap);

								NestObject(mapObject, subMap);
							end
						end
					end

					-- Merge everything for this map into the list
					app.Sort(mapObject.g);
					if mapObject.g then
						-- Sort the sub-groups as well
						for i,mapGrp in ipairs(mapObject.g) do
							if mapGrp.mapID then
								app.Sort(mapGrp.g);
							end
						end
					end
					MergeObject(temp, mapObject);
				end

				-- Acquire all of the emissary quests
				for _,pair in ipairs(emissaryMapIDs) do
					local mapID = pair[1];
					-- print("WQ.EmissaryMapIDs." .. tostring(mapID))
					local mapObject = app.CreateMapWithStyle(mapID);
					local bounties = C_QuestLog_GetBountiesForMapID(pair[2]);
					if bounties and #bounties > 0 then
						for _,bounty in ipairs(bounties) do
							local questObject = GetPopulatedQuestObject(bounty.questID);
							NestObject(mapObject, questObject);
						end
					end
					app.Sort(mapObject.g);
					if mapObject.g then
						-- Sort the sub-groups as well
						for i,mapGrp in ipairs(mapObject.g) do
							if mapGrp.mapID then
								app.Sort(mapGrp.g);
							end
						end
					end
					MergeObject(temp, mapObject);
				end

				-- Heroic Deeds
				if self.includePermanent and not (CompletedQuests[32900] or CompletedQuests[32901]) then
					local mapObject = app.CreateMapWithStyle(424);
					NestObject(mapObject, GetPopulatedQuestObject(app.FactionID == Enum.FlightPathFaction.Alliance and 32900 or 32901));
					MergeObject(temp, mapObject);
				end

				local OnUpdateForLFGHeader = function(group)
					local meetLevelrange = app.FilterGroupsByLevel(group);
					if meetLevelrange or app.MODE_DEBUG_OR_ACCOUNT then
						-- default logic for available LFG category/Debug/Account
						return false;
					else
						group.visible = nil;
						return true;
					end
				end

				-- Get the LFG Rewards Available at this level
				local numRandomDungeons = GetNumRandomDungeons();
				-- print(numRandomDungeons,"numRandomDungeons");
				if numRandomDungeons > 0 then
					local groupFinder = { achID = 4476, text = DUNGEONS_BUTTON, collectible = false, trackable = false, g = {} };
					for index=1,numRandomDungeons,1 do
						local dungeonID = GetLFGRandomDungeonInfo(index);
						-- app.PrintDebug("RandInfo",index,GetLFGRandomDungeonInfo(index));
						-- app.PrintDebug("NormInfo",dungeonID,GetLFGDungeonInfo(dungeonID))
						-- app.PrintDebug("DungeonAppearsInRandomLFD(dungeonID)",DungeonAppearsInRandomLFD(dungeonID)); -- useless
						local name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel, expansionLevel, groupID, textureFilename, difficulty, maxPlayers, description, isHoliday, bonusRepAmount, minPlayers, isTimeWalker, name2, minGearLevel = GetLFGDungeonInfo(dungeonID);
						-- print(dungeonID,name, typeID, subtypeID, minLevel, maxLevel, recLevel, minRecLevel, maxRecLevel, expansionLevel, groupID, textureFilename, difficulty, maxPlayers, description, isHoliday, bonusRepAmount, minPlayers, isTimeWalker, name2, minGearLevel);
						local _, gold, unknown, xp, unknown2, numRewards, unknown = GetLFGDungeonRewards(dungeonID);
						-- print("GetLFGDungeonRewards",dungeonID,GetLFGDungeonRewards(dungeonID));
						local header = { dungeonID = dungeonID, text = name, description = description, lvl = { minRecLevel or 1, maxRecLevel }, OnUpdate = OnUpdateForLFGHeader, g = {}};
						if expansionLevel and not isHoliday then
							header.icon = setmetatable({["tierID"]=expansionLevel + 1}, app.BaseTier).icon;
						elseif isTimeWalker then
							header.icon = app.asset("Difficulty_Timewalking");
						end
						for rewardIndex=1,numRewards,1 do
							local itemName, icon, count, claimed, rewardType, itemID, quality = GetLFGDungeonRewardInfo(dungeonID, rewardIndex);
							-- common logic
							local idType = (rewardType or "item").."ID";
							local thing = { [idType] = itemID };
							_cache = SearchForField(idType, itemID);
							if _cache then
								for _,data in ipairs(_cache) do
									-- copy any sourced data for the dungeon reward into the list
									if GroupMatchesParams(data, idType, itemID, true) then
										MergeProperties(thing, data);
									end
									local lvl;
									if isTimeWalker then
										lvl = (data.lvl and type(data.lvl) == "table" and data.lvl[1]) or
												data.lvl or
												(data.parent and data.parent.lvl and type(data.parent.lvl) == "table" and data.parent.lvl[1]) or
												data.parent.lvl or 0;
									else
										lvl = 0;
									end
									-- Should the rewards be listed in the window based on the level of the rewards
									if lvl <= minRecLevel then
										NestObjects(thing, data.g);	-- no need to clone, everything is re-created at the end
									end
								end
							end
							NestObject(header, thing);
						end
						NestObject(groupFinder, header);
					end
					tinsert(temp, CreateObject(groupFinder));
				end

				-- put all the things into the window data, turning them into objects as well
				NestObjects(self.data, temp);
				-- Build the heirarchy
				self:BuildData();
				-- Force Update
				self:Update(true);
			end
		end

		self:BaseUpdate(force or got);
	end
end;

-- Only need to immediately load any Windows which are able to be immediately visible on load depending on settings
app:GetWindow("Prime"):SetSize(425, 305);
app:GetWindow("Bounty");
app:GetWindow("CurrentInstance");
app:GetWindow("RaidAssistant");
app:GetWindow("Sync");
app:GetWindow("Tradeskills");
app:GetWindow("WorldQuests");
end)();

-- ATT Debugger Logic
app.LoadDebugger = function()
	-- CLEU binding only happens when debugger is enabled because of how expensive it can get in large mob farms
	app:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");
	app.events.COMBAT_LOG_EVENT_UNFILTERED = function()
		local _,event = CombatLogGetCurrentEventInfo();
		if event == "UNIT_DIED" or event == "UNIT_DESTROYED" then
			app.RefreshQuestInfo();
		end
	end
	-- This event is helpful for world objects used as treasures. Won't help with objects without rewards (e.g. cat statues in Nazjatar)
	app:RegisterEvent("LOOT_OPENED")
	app.events.LOOT_OPENED = function()
		local guid = GetLootSourceInfo(1)
		if guid then
			local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-",guid);
			if(type == "GameObject") then
			local text = GameTooltipTextLeft1:GetText()
			print('ObjectID: '..(npc_id or 'UNKNOWN').. ' || ' .. 'Name: ' .. (text or 'UNKNOWN'))
			app.RefreshQuestInfo();
		end
		end
	end
	local debuggerWindow = app:GetWindow("Debugger", UIParent, function(self, force)
		if not self.initialized then
			self.initialized = true;
			force = true;
			local CleanFields = {
				["parent"] = 1,
				["sourceParent"] = 1,
				["total"] = 1,
				["text"] = 1,
				["forceShow"] = 1,
				["progress"] = 1,
				["OnUpdate"] = 1,
				["expanded"] = 1,
				["hash"] = 1,
				["rawlink"] = 1,
				["modItemID"] = 1,
				["f"] = 1,
				["key"] = 1,
				["visible"] = 1,
				["displayInfo"] = 1,
			};
			local function CleanObject(obj)
				local clean = {};
				if obj[1] then
					for _,o in ipairs(obj) do
						tinsert(clean, CleanObject(o));
					end
				else
					for k,v in pairs(obj) do
						if not CleanFields[k] then
							rawset(clean, k, v);
						end
					end
					if clean.g then
						local g = {};
						for _,o in ipairs(clean.g) do
							tinsert(g, CleanObject(o));
						end
						clean.g = g;
					end
				end
				return clean;
			end
			local function InitDebuggerData()
				if not self.rawData then
					self.rawData = LocalizeGlobal("AllTheThingsDebugData", true);
					if self.rawData[1] then
						-- need to clean and create again to get different tables used as the actual 'objects' within the rows, otherwise the object data gets saved into the Global as well
						NestObjects(self.data, CreateObject(CleanObject(self.rawData)));
					end
					if not self.data.g then self.data.g = {}; end
					for i=#self.data.options,1,-1 do
						tinsert(self.data.g, 1, self.data.options[i]);
					end
					BuildGroups(self.data, self.data.g);
					AfterCombatCallback(self.Update, self, true);
				end
			end
			-- batch operation to clear the rawData, and re-populate with a cleaned version of the current debugger content
			self.BackupData = function(self)
				wipe(self.rawData);
				-- skip clickable rows
				for _,o in ipairs(self.data.g) do
					if not o.OnClick then
						tinsert(self.rawData, CleanObject(o));
					end
				end
				app.print("Debugger Data Saved");
			end
			local IgnoredNPCs = {
				[142668] = 1,	-- Merchant Maku (Brutosaur)
				[142666] = 1,	-- Collector Unta (Brutosaur)
				[62821] = 1,	-- Mystic Birdhat (Grand Yak)
				[62822] = 1,	-- Cousin Slowhands (Grand Yak)
				[32642] = 1,	-- Mojodishu (Mammoth)
				[32641] = 1,	-- Drix Blackwrench (Mammoth)
			};
			self:SetData({
				['text'] = "Session History",
				['icon'] = "Interface\\Icons\\Achievement_Dungeon_GloryoftheRaider.blp",
				["description"] = "This keeps a visual record of all of the quests, maps, loot, and vendors that you have come into contact with since the session was started.",
				["OnUpdate"] = app.AlwaysShowUpdate,
				['expanded'] = true,
				['back'] = 1,
				['options'] = {
					{
						["hash"] = "clearHistory",
						['text'] = "Clear History",
						['icon'] = "Interface\\Icons\\Ability_Rogue_FeignDeath.blp",
						["description"] = "Click this to fully clear this window.\n\nNOTE: If you click this by accident, use the dynamic Restore Buttons that this generates to reapply the data that was cleared.\n\nWARNING: If you reload the UI, the data stored in the Reload Button will be lost forever!",
						["OnUpdate"] = app.AlwaysShowUpdate,
						['count'] = 0,
						['OnClick'] = function(row, button)
							local copy = {};
							for i,o in ipairs(self.data.g) do
								-- only backup non-button groups
								if not o.OnClick then
									tinsert(copy, o);
								end
							end
							if #copy < 1 then
								app.print("There is nothing to clear.");
								return true;
							end
							row.ref.count = row.ref.count + 1;
							tinsert(self.data.options, {
								["hash"] = "restore" .. row.ref.count,
								['text'] = "Restore Button " .. row.ref.count,
								['icon'] = "Interface\\Icons\\ability_monk_roll.blp",
								["description"] = "Click this to restore your cleared data.\n\nNOTE: Each Restore Button houses different data.\n\nWARNING: This data will be lost forever when you reload your UI!",
								["OnUpdate"] = app.AlwaysShowUpdate,
								['data'] = copy,
								['OnClick'] = function(row, button)
									for i,info in ipairs(row.ref.data) do
										NestObject(self.data, CreateObject(info));
									end
									BuildGroups(self.data, self.data.g);
									AfterCombatCallback(self.Update, self, true);
									return true;
								end,
							});
							wipe(self.rawData);
							wipe(self.data.g);
							for i=#self.data.options,1,-1 do
								tinsert(self.data.g, 1, self.data.options[i]);
							end
							BuildGroups(self.data, self.data.g);
							AfterCombatCallback(self.Update, self, true);
							return true;
						end,
					},
				},
				['g'] = {},
			});

			local AddObject = function(info)
				-- print("Debugger.AddObject")
				-- app.PrintTable(info)
				-- print("---")
				-- Bubble Up the Maps
				local mapInfo;
				local mapID = app.GetCurrentMapID();
				if mapID then
					if info then
						local pos = C_Map.GetPlayerMapPosition(mapID, "player");
						if pos then
							local px, py = pos:GetXY();
							info.coord = { math.ceil(px * 10000) / 100, math.ceil(py * 10000) / 100, mapID };
						end
					end
					repeat
						mapInfo = C_Map_GetMapInfo(mapID);
						if mapInfo then
							if not info then
								info = { ["mapID"] = mapInfo.mapID };
								-- print("Added mapID",mapInfo.mapID)
							else
								info = { ["mapID"] = mapInfo.mapID, ["g"] = { info } };
								-- print("Pushed into mapID",mapInfo.mapID)
							end
							mapID = mapInfo.parentMapID
						end
					until not mapInfo or not mapID;
				end

				if info then
					NestObject(self.data, CreateObject(info));
					self:BuildData();
					AfterCombatCallback(self.Update, self, true);
					-- trigger the delayed backup
					DelayedCallback(self.BackupData, 15, self);
				end
			end

			-- Merchant Additions
			local AddMerchant = function(guid)
				-- print("AddMerchant",guid)
				local guid = guid or UnitGUID("npc");
				if guid then
					local ty, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-",guid);
					if npc_id then
						npc_id = tonumber(npc_id);

						if IgnoredNPCs[npc_id] then return true; end

						local numItems = GetMerchantNumItems();
						if app.DEBUG_PRINT then print("MERCHANT DETAILS", ty, npc_id, numItems); end

						local rawGroups = {};
						for i=1,numItems,1 do
							local link = GetMerchantItemLink(i);
							if link then
								local name, texture, cost, quantity, numAvailable, isPurchasable, isUsable, extendedCost = GetMerchantItemInfo(i);
								-- Parse as an ITEM LINK.
								local item = { ["itemID"] = tonumber(link:match("item:(%d+)")), ["rawlink"] = link, ["cost"] = cost };
								if extendedCost then
									cost = {};
									local itemCount = GetMerchantItemCostInfo(i);
									for j=1,itemCount,1 do
										local itemTexture, itemValue, itemLink = GetMerchantItemCostItem(i, j);
										if itemLink then
											-- print("  ", itemValue, itemLink, gsub(itemLink, "\124", "\124\124"));
											local m = itemLink:match("currency:(%d+)");
											if m then
												-- Parse as a CURRENCY.
												tinsert(cost, {"c", tonumber(m), itemValue});
											else
												-- Parse as an ITEM.
												tinsert(cost, {"i", tonumber(itemLink:match("item:(%d+)")), itemValue});
											end
										end
									end
									if cost[1] then
										item.cost = cost;
									end
								end

								tinsert(rawGroups, item);
							end
						end

						local info = { [(ty == "GameObject") and "objectID" or "npcID"] = npc_id };
						local faction = UnitFactionGroup("npc");
						if faction then
							info.r = faction == "Horde" and Enum.FlightPathFaction.Horde or Enum.FlightPathFaction.Alliance;
						end
						info.isVendor = 1;
						info.g = rawGroups;
						AddObject(info);
					end
				end
			end

			-- Setup Event Handlers and register for events
			self:SetScript("OnEvent", function(self, e, ...)
				if app.DEBUG_PRINT then print(e, ...); end
				if e == "ZONE_CHANGED_NEW_AREA" or e == "NEW_WMO_CHUNK" then
					AddObject();
				elseif e == "MERCHANT_SHOW" or e == "MERCHANT_UPDATE" then
					MerchantFrame_SetFilter(MerchantFrame, 1);
					DelayedCallback(AddMerchant, 1, UnitGUID("npc"));
				elseif e == "TRADE_SKILL_LIST_UPDATE" then
					local tradeSkillID = AllTheThings.GetTradeSkillLine();
					local currentCategoryGroup, currentCategoryID, categories = {}, -1, {};
					local categoryList, rawGroups = {}, {};
					local categoryIDs = { C_TradeSkillUI.GetCategories() };
					for i = 1,#categoryIDs do
						currentCategoryID = categoryIDs[i];
						local categoryData = C_TradeSkillUI.GetCategoryInfo(currentCategoryID);
						if categoryData then
							if not categories[currentCategoryID] then
								local category = {
									["parentCategoryID"] = categoryData.parentCategoryID,
									["categoryID"] = currentCategoryID,
									["name"] = categoryData.name,
									["g"] = {}
								};
								categories[currentCategoryID] = category;
								tinsert(categoryList, category);
							end
						end
					end

					local recipeIDs = C_TradeSkillUI.GetAllRecipeIDs();
					for i = 1,#recipeIDs do
						local spellRecipeInfo = C_TradeSkillUI.GetRecipeInfo(recipeIDs[i]);
						if spellRecipeInfo then
							currentCategoryID = spellRecipeInfo.categoryID;
							if not categories[currentCategoryID] then
								local categoryData = C_TradeSkillUI.GetCategoryInfo(currentCategoryID);
								if categoryData then
									local category = {
										["parentCategoryID"] = categoryData.parentCategoryID,
										["categoryID"] = currentCategoryID,
										["name"] = categoryData.name,
										["g"] = {}
									};
									categories[currentCategoryID] = category;
									tinsert(categoryList, category);
								end
							end
							local recipe = {
								["recipeID"] = spellRecipeInfo.recipeID,
								["requireSkill"] = tradeSkillID,
								["name"] = spellRecipeInfo.name,
							};
							if spellRecipeInfo.previousRecipeID then
								recipe.previousRecipeID = spellRecipeInfo.previousRecipeID;
							end
							if spellRecipeInfo.nextRecipeID then
								recipe.nextRecipeID = spellRecipeInfo.nextRecipeID;
							end
							tinsert(categories[currentCategoryID].g, recipe);
						end
					end

					-- Make each category parent have children. (not as gross as that sounds)
					for i=#categoryList,1,-1 do
						local category = categoryList[i];
						if category.parentCategoryID then
							local parentCategory = categories[category.parentCategoryID];
							category.parentCategoryID = nil;
							if parentCategory then
								tinsert(parentCategory.g, 1, category);
								table.remove(categoryList, i);
							end
						end
					end

					-- Now merge the categories into the raw groups table.
					for i,category in ipairs(categoryList) do
						tinsert(rawGroups, category);
					end
					local info = {
						["professionID"] = tradeSkillID,
						["icon"] = C_TradeSkillUI.GetTradeSkillTexture(tradeSkillID),
						["name"] = C_TradeSkillUI.GetTradeSkillDisplayName(tradeSkillID),
						["g"] = rawGroups
					};
					NestObject(self.data, CreateObject(info));
					BuildGroups(self.data, self.data.g);
					AfterCombatCallback(self.Update, self, true);
					-- trigger the delayed backup
					DelayedCallback(self.BackupData, 15, self);
				-- Capture quest NPC dialogs
				elseif e == "QUEST_DETAIL" or e == "QUEST_PROGRESS" then
					local questStartItemID = ...;
					local questID = GetQuestID();
					if questID == 0 then return false; end
					local npc = "questnpc";
					local guid = UnitGUID(npc);
					if not guid then
						npc = "npc";
						guid = UnitGUID(npc);
					end
					local type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid;
					if guid then type, zero, server_id, instance_id, zone_uid, npc_id, spawn_uid = strsplit("-",guid); end
					if app.DEBUG_PRINT then print("QUEST_DETAIL", questStartItemID, " => Quest #", questID, type, npc_id, app.NPCNameFromID[npc_id]); end

					local rawGroups = {};
					for i=1,GetNumQuestRewards(),1 do
						local link = GetQuestItemLink("reward", i);
						if link then tinsert(rawGroups, { ["itemID"] = GetItemInfoInstant(link) }); end
					end
					for i=1,GetNumQuestChoices(),1 do
						local link = GetQuestItemLink("choice", i);
						if link then tinsert(rawGroups, { ["itemID"] = GetItemInfoInstant(link) }); end
					end
					for i=1,GetNumQuestLogRewardSpells(questID),1 do
						local texture, name, isTradeskillSpell, isSpellLearned, hideSpellLearnText, isBoostSpell, garrFollowerID, genericUnlock, spellID = GetQuestLogRewardSpell(i, questID);
						if garrFollowerID then
							tinsert(rawGroups, { ["followerID"] = garrFollowerID, ["name"] = name });
						elseif spellID then
							if isTradeskillSpell then
								tinsert(rawGroups, { ["recipeID"] = spellID, ["name"] = name });
							else
								tinsert(rawGroups, { ["spellID"] = spellID, ["name"] = name });
							end
						end
					end

					local info = { ["questID"] = questID, ["g"] = rawGroups };
					if questStartItemID and questStartItemID > 0 then info.provider = { "i", questStartItemID }; end
					if npc_id then
						npc_id = tonumber(npc_id);
						if type == "GameObject" then
							info = { ["objectID"] = npc_id, ["text"] = UnitName(npc), ["g"] = { info } };
						else
							info.qgs = { npc_id };
						end
						local faction = UnitFactionGroup(npc);
						if faction then
							info.r = faction == "Horde" and Enum.FlightPathFaction.Horde or Enum.FlightPathFaction.Alliance;
						end
					end
					AddObject(info);
				-- Capture various personal/party loot received
				elseif e == "CHAT_MSG_LOOT" then
					local msg, player, a, b, c, d, e, f, g, h, i, j, k, l = ...;
					-- "You receive item: item:###" will break the match
					-- this probably doesn't work in other locales
					msg = msg:gsub("item: ", "");
					-- print("Loot parse",msg)
					local itemString = string.match(msg, "item[%-?%d:]+");
					if itemString then
						-- print("Looted Item",itemString)
						local itemID = GetItemInfoInstant(itemString);
						AddObject({ ["unit"] = j, ["g"] = { { ["itemID"] = itemID, ["rawlink"] = itemString } } });
					end
				-- Capture personal loot sources
				elseif e == "LOOT_READY" then
					local slots = GetNumLootItems();
					-- print("Loot Slots:",slots);
					local loot, source, itemID, info;
					local type, zero, server_id, instance_id, zone_uid, id, spawn_uid;
					for i=1,slots,1 do
						loot = GetLootSlotLink(i);
						if loot then
							itemID = GetItemInfoInstant(loot);
							if itemID then
								source = { GetLootSourceInfo(i) };
								for s=1,#source,2 do
									type, zero, server_id, instance_id, zone_uid, id, spawn_uid = strsplit("-",source[s]);
									-- TODO: test this with Item containers
									if app.DEBUG_PRINT then print("Add Loot",itemID,"from",type,id) end
									info = { [(type == "GameObject") and "objectID" or "npcID"] = tonumber(id), ["g"] = { { ["itemID"] = itemID, ["rawlink"] = loot } } };
									-- print("Add Loot")
									-- app.PrintTable(info);
									AddObject(info);
								end
							elseif app.DEBUG_PRINT then
								print("No ItemID!",loot)
							end
						end
					end
				end
			end);
			self:RegisterEvent("QUEST_DETAIL");
			self:RegisterEvent("QUEST_PROGRESS");
			self:RegisterEvent("QUEST_LOOT_RECEIVED");
			self:RegisterEvent("TRADE_SKILL_LIST_UPDATE");
			self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
			self:RegisterEvent("NEW_WMO_CHUNK");
			self:RegisterEvent("MERCHANT_SHOW");
			self:RegisterEvent("MERCHANT_UPDATE");
			self:RegisterEvent("LOOT_READY");
			self:RegisterEvent("CHAT_MSG_LOOT");
			--self:RegisterAllEvents();

			InitDebuggerData();
			-- Ensure the current Zone is added when the Window is initialized
			AddObject();
			BuildGroups(self.data, self.data.g);
		end

		-- Update the window and all of its row data
		self:BaseUpdate(force);
	end);
	app.TopLevelUpdateGroup(debuggerWindow.data, debuggerWindow);
	debuggerWindow:Show();
	app.LoadDebugger = function()
		debuggerWindow:Toggle();
	end
end	-- app.LoadDebugger

hooksecurefunc(GameTooltip, "SetToyByItemID", function(self, itemID, ...)
	if CanAttachTooltips() then
		local link = C_ToyBox.GetToyLink(itemID);
		if link then
			AttachTooltipSearchResults(self, 1, link, SearchForLink, link);
			self:Show();
		end
	end
end)
hooksecurefunc(GameTooltip, "SetRecipeReagentItem", function(self, recipeID, reagentID, ...)
	if CanAttachTooltips() then
		local link = C_TradeSkillUI.GetRecipeFixedReagentItemLink(recipeID, reagentID);
		if link then
			AttachTooltipSearchResults(self, 1, link, SearchForLink, link);
			self:Show();
		end
	end
end)
-- GameTooltip:HookScript("OnUpdate", CheckAttachTooltip);
GameTooltip:HookScript("OnShow", AttachTooltip);
GameTooltip:HookScript("OnTooltipSetQuest", AttachTooltip);
GameTooltip:HookScript("OnTooltipSetItem", AttachTooltip);
GameTooltip:HookScript("OnTooltipSetUnit", AttachTooltip);
GameTooltip:HookScript("OnTooltipCleared", ClearTooltip);
ItemRefTooltip:HookScript("OnShow", AttachTooltip);
ItemRefTooltip:HookScript("OnTooltipSetQuest", AttachTooltip);
ItemRefTooltip:HookScript("OnTooltipSetItem", AttachTooltip);
ItemRefTooltip:HookScript("OnTooltipCleared", ClearTooltip);
ItemRefShoppingTooltip1:HookScript("OnShow", AttachTooltip);
ItemRefShoppingTooltip1:HookScript("OnTooltipSetQuest", AttachTooltip);
ItemRefShoppingTooltip1:HookScript("OnTooltipSetItem", AttachTooltip);
ItemRefShoppingTooltip1:HookScript("OnTooltipCleared", ClearTooltip);
ItemRefShoppingTooltip2:HookScript("OnShow", AttachTooltip);
ItemRefShoppingTooltip2:HookScript("OnTooltipSetQuest", AttachTooltip);
ItemRefShoppingTooltip2:HookScript("OnTooltipSetItem", AttachTooltip);
ItemRefShoppingTooltip2:HookScript("OnTooltipCleared", ClearTooltip);

--[[
hooksecurefunc("EmbeddedItemTooltip_SetCurrencyByID", function(self, id, ...)
	print("EmbeddedItemTooltip_SetCurrencyByID", ...);
	AttachTooltip(self.Tooltip);
end);
]]--
hooksecurefunc("EmbeddedItemTooltip_SetItemByID", function(self, itemID, ...)
	ClearTooltip(self.Tooltip);
	AttachTooltip(self.Tooltip);
	self.Tooltip:Show();
end);
hooksecurefunc("EmbeddedItemTooltip_SetItemByQuestReward", function(self, ...)
	ClearTooltip(self.Tooltip);
	AttachTooltip(self.Tooltip);
	self.Tooltip:Show();
end);
--hooksecurefunc("BattlePetTooltipTemplate_SetBattlePet", AttachBattlePetTooltip); -- Not ready yet.

-- Auction House Lib
(function()
local auctionFrame = CreateFrame("Frame");
app.AuctionFrame = auctionFrame;
app.ProcessAuctionData = function()
	-- If we have no auction data, then simply return now.
	if not AllTheThingsAuctionData then return end;
	local count = 0;
	for _ in pairs(AllTheThingsAuctionData) do count = count+1 end
	if count < 1 then return end;

	-- Search the ATT Database for information related to the auction links (items, species, etc)
	local filterID;
	local searchResultsByKey, searchResult, searchResults, key, keys, value, data = {};
	for k,v in pairs(AllTheThingsAuctionData) do
		searchResults = SearchForLink(v.itemLink);
		if searchResults then
			if #searchResults > 0 then
				searchResult = searchResults[1];
				key = searchResult.key;
				if key == "npcID" then
					if searchResult.itemID then
						key = "itemID";
					end
				elseif key == "spellID" then
					local AuctionDataItemKeyOverrides = {
						[92426] = "itemID", -- Sealed Tome of the Lost Legion
					};
					if AuctionDataItemKeyOverrides[searchResult.itemID] then
						key = AuctionDataItemKeyOverrides[searchResult.itemID]
					end
				end
				value = searchResult[key];
				keys = searchResultsByKey[key];

				-- Make sure that the key type is represented.
				if not keys then
					keys = {};
					searchResultsByKey[key] = keys;
				end

				-- First time this key value was used.
				data = keys[value];
				if not data then
					data = CreateObject(searchResult);
					for i=2,#searchResults,1 do
						MergeObject(data, CreateObject(searchResults[i]));
					end
					if data.key == "npcID" then setmetatable(data, app.BaseItem); end
					data.auctions = {};
					keys[value] = data;
				end
				tinsert(data.auctions, v.itemLink);
			end
		end
	end

	-- Move all achievementID-based items into criteriaID
	if searchResultsByKey.achievementID then
		local criteria = searchResultsByKey.criteriaID;
		if criteria then
			for key,entry in pairs(searchResultsByKey.achievementID) do
				criteria[key] = entry;
			end
		else
			searchResultsByKey.criteriaID = searchResultsByKey.achievementID;
		end
		searchResultsByKey.achievementID = nil;
	end

	-- Apply a sub-filter to items with spellID-based identifiers.
	if searchResultsByKey.spellID then
		local filteredItems = {};
		for key,entry in pairs(searchResultsByKey.spellID) do
			filterID = entry.filterID or entry.f;
			if filterID then
				local filterData = filteredItems[filterID];
				if not filterData then
					filterData = {};
					filteredItems[filterID] = filterData;
				end
				filterData[key] = entry;
			else
				print("Spell " .. entry.spellID .. " (Item ID #" .. (entry.itemID or "???") .. ") is missing a filterID?");
			end
		end

		if filteredItems[100] then searchResultsByKey.mountID = filteredItems[100]; end	-- Mounts
		if filteredItems[200] then searchResultsByKey.recipeID = filteredItems[200]; end -- Recipes
		searchResultsByKey.spellID = nil;
	end

	if searchResultsByKey.s then
		local filteredItems = {};
		local cachedS = searchResultsByKey.s;
		searchResultsByKey.s = {};
		for sourceID,entry in pairs(cachedS) do
			filterID = entry.filterID or entry.f;
			if filterID then
				local filterData = filteredItems[entry.f];
				if not filterData then
					filterData = setmetatable({ ["filterID"] = filterID, ["g"] = {} }, app.BaseFilter);
					filteredItems[filterID] = filterData;
					tinsert(searchResultsByKey.s, filterData);
				end
				tinsert(filterData.g, entry);
			end
		end
		for f,entry in pairs(filteredItems) do
			app.Sort(entry.g, function(a,b)
				return a.u and not b.u;
			end);
		end
	end

	-- Process the Non-Collectible Items for Reagents
	local reagentCache = app.GetDataMember("Reagents");
	if reagentCache and searchResultsByKey.itemID then
		local cachedItems = searchResultsByKey.itemID;
		searchResultsByKey.itemID = {};
		searchResultsByKey.reagentID = {};
		for itemID,entry in pairs(cachedItems) do
			if reagentCache[itemID] then
				searchResultsByKey.reagentID[itemID] = entry;
				if not entry.g then entry.g = {}; end
				for itemID2,count in pairs(reagentCache[itemID][2]) do
					local searchResults = app.SearchForField("itemID", itemID2);
					if searchResults and #searchResults > 0 then
						tinsert(entry.g, CloneData(searchResults[1]));
					end
				end
			else
				-- Push it back into the itemID table
				searchResultsByKey.itemID[itemID] = entry;
			end
		end
	end

	-- Insert Buttons into the groups.
	wipe(window.data.g);
	for i,option in ipairs(window.data.options) do
		tinsert(window.data.g, option);
	end

	local ObjectTypeMetas = {
		["criteriaID"] = setmetatable({	-- Achievements
			["filterID"] = 105,
			["icon"] = "INTERFACE/ICONS/ACHIEVEMENT_BOSS_LICHKING",
			["description"] = L["ITEMS_FOR_ACHIEVEMENTS_DESC"],
			["priority"] = 1,
		}, app.BaseFilter),
		["s"] = setmetatable({			-- Appearances
			["headerID"] = -10032,
			["icon"] = "INTERFACE/ICONS/INV_SWORD_06",
			["description"] = L["ALL_APPEARANCES_DESC"],
			["priority"] = 2,
		}, app.BaseHeader),
		["mountID"] = setmetatable({	-- Mounts
			["filterID"] = 100,
			["description"] = L["ALL_THE_MOUNTS_DESC"],
			["priority"] = 3,
		}, app.BaseFilter),
		["speciesID"] = setmetatable({	-- Battle Pets
			["filterID"] = 101,
			["icon"] = "INTERFACE/ICONS/ICON_PETFAMILY_CRITTER",
			["description"] = L["ALL_THE_BATTLEPETS_DESC"],
			["priority"] = 4,
		}, app.BaseFilter),
		["questID"] = setmetatable({	-- Quests
			["headerID"] = -9956,
			["icon"] = "INTERFACE/ICONS/ACHIEVEMENT_GENERAL_100KQUESTS",
			["description"] = L["ALL_THE_QUESTS_DESC"],
			["priority"] = 5,
		}, app.BaseHeader),
		["recipeID"] = setmetatable({	-- Recipes
			["filterID"] = 200,
			["icon"] = "INTERFACE/ICONS/INV_SCROLL_06",
			["description"] = L["ALL_THE_RECIPES_DESC"],
			["priority"] = 6,
		}, app.BaseFilter),
		["itemID"] = {					-- General
			["text"] = "General",
			["icon"] = "INTERFACE/ICONS/INV_MISC_FROSTEMBLEM_01",
			["description"] = L["ALL_THE_ILLUSIONS_DESC"],
			["priority"] = 7,
		},
		["reagentID"] = setmetatable({	-- Reagent
			["filterID"] = 56,
			["icon"] = "INTERFACE/ICONS/SPELL_FROST_FROZENCORE",
			["description"] = L["ALL_THE_REAGENTS_DESC"],
			["priority"] = 8,
		}, app.BaseFilter),
	};

	-- Display Test for Raw Data + Filtering
	for key, searchResults in pairs(searchResultsByKey) do
		local subdata = {};
		subdata.visible = true;
		if ObjectTypeMetas[key] then
			setmetatable(subdata, { __index = ObjectTypeMetas[key] });
		else
			subdata.description = "Container for '" .. key .. "' object types.";
			subdata.text = key;
		end
		subdata.g = {};
		for i,j in pairs(searchResults) do
			tinsert(subdata.g, j);
		end
		tinsert(window.data.g, subdata);
	end
	app.Sort(window.data.g, function(a, b)
		return (b.priority or 0) > (a.priority or 0);
	end);
	BuildGroups(window.data, window.data.g);
	app.TopLevelUpdateGroup(window.data, window);
	window:Show();
	window:Update();
end

app.OpenAuctionModule = function(self)
	-- TODO: someday someone might fix this AH functionality...
	if true then return; end

	if IsAddOnLoaded("TradeSkillMaster") then -- Why, TradeSkillMaster, why are you like this?
		C_Timer.After(2, function() end);
	end
	if app.Blizzard_AuctionHouseUILoaded then
		-- Localize some global APIs
		local C_AuctionHouse_GetNumReplicateItems = C_AuctionHouse.GetNumReplicateItems;
		local C_AuctionHouse_GetReplicateItemInfo = C_AuctionHouse.GetReplicateItemInfo;
		local C_AuctionHouse_GetReplicateItemLink = C_AuctionHouse.GetReplicateItemLink;

		-- Create the Auction Tab for ATT.
		local tabID = AuctionHouseFrame.numTabs+1;
		local button = CreateFrame("Button", "AuctionHouseFrameTab"..tabID, AuctionHouseFrame, "AuctionHouseFrameDisplayModeTabTemplate");
		button:SetID(tabID);
		button:SetText(L["AUCTION_TAB"]);
		button:SetNormalFontObject(GameFontHighlightSmall);
		button:SetPoint("LEFT", AuctionHouseFrame.Tabs[tabID-1], "RIGHT", -15, 0);
		tinsert(AuctionHouseFrame.Tabs, button);

		PanelTemplates_SetNumTabs (AuctionHouseFrame, tabID);
		PanelTemplates_EnableTab  (AuctionHouseFrame, tabID);

		-- Garbage collect the function after this is executed.
		app.OpenAuctionModule = function() end;
		app.AuctionModuleTabID = tabID;

		-- Create the movable Auction Data window.
		local window = app:GetWindow("AuctionData", AuctionHouseFrame);
		auctionFrame:SetScript("OnEvent", function(self, e, ...)
			if e == "REPLICATE_ITEM_LIST_UPDATE" then
				self:UnregisterEvent("REPLICATE_ITEM_LIST_UPDATE");
				AllTheThingsAuctionData = {};
				local items = {};
				local auctionItems = C_AuctionHouse_GetNumReplicateItems();
				for i=0,auctionItems-1 do
					local itemLink;
					local count, _, _, _, _, _, _, price, _, _, _, _, _, _, itemID, status = select(3, C_AuctionHouse_GetReplicateItemInfo(i));
					if price and itemID and status then
						itemLink = C_AuctionHouse_GetReplicateItemLink(i);
						if itemLink then
							AllTheThingsAuctionData[itemID] = { itemLink = itemLink, count = count, price = (price/count) };
						end
					else
						local item = Item:CreateFromItemID(itemID);
						items[item] = true;

						item:ContinueOnItemLoad(function()
							count, _, _, _, _, _, _, price, _, _, _, _, _, _, itemID, status = select(3, C_AuctionHouse_GetReplicateItemInfo(i));
							items[item] = nil;
							if itemID and status then
								itemLink = C_AuctionHouse_GetReplicateItemLink(i);
								if itemLink then
									AllTheThingsAuctionData[itemID] = { itemLink = itemLink, count = count, price = (price/count) };
								end
							end
							if not next(items) then
								items = {};
							end
						end);
					end
				end
				if not next(items) then
					items = {};
				end
				print(L["TITLE"] .. L["AH_SCAN_SUCCESSFUL_1"] .. auctionItems .. L["AH_SCAN_SUCCESSFUL_2"]);
				StartCoroutine("ProcessAuctionData", app.ProcessAuctionData, 1);
			end
		end);
		window:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 0, -10);
		window:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMRIGHT", 0, 10);
		window:Hide();

		-- Cache some functions to make them faster
		local _GetAuctionItemInfo, _GetAuctionItemLink = GetAuctionItemInfo, GetAuctionItemLink;
		local origSideDressUpFrameHide, origSideDressUpFrameShow = SideDressUpFrame.Hide, SideDressUpFrame.Show;
		SideDressUpFrame.Hide = function(...)
			origSideDressUpFrameHide(...);
			window:ClearAllPoints();
			window:SetPoint("TOPLEFT", AuctionHouseFrame, "TOPRIGHT", 0, -10);
			window:SetPoint("BOTTOMLEFT", AuctionHouseFrame, "BOTTOMRIGHT", 0, 10);
		end
		SideDressUpFrame.Show = function(...)
			origSideDressUpFrameShow(...);
			window:ClearAllPoints();
			window:SetPoint("LEFT", SideDressUpFrame, "RIGHT", 0, 0);
			window:SetPoint("TOP", AuctionHouseFrame, "TOP", 0, -10);
			window:SetPoint("BOTTOM", AuctionHouseFrame, "BOTTOM", 0, 10);
		end

		button:SetScript("OnClick", function(self) -- This is the "ATT" button at the bottom of the auction house frame
			if self:GetID() == tabID then
				window:Show();
			end
		end);
	end
end
end)();

do -- Setup and Startup Functionality
-- Creates the data structures and initial 'Default' profiles for ATT
app.SetupProfiles = function()
	-- base profiles containers
	local ATTProfiles = {
		Profiles = {},
		Assignments = {},
	};
	AllTheThingsProfiles = ATTProfiles;
	local default = app.Settings:NewProfile(DEFAULT);
	-- copy various existing settings that are now Profiled
	if AllTheThingsSettings then
		-- General Settings
		if AllTheThingsSettings.General then
			for k,v in pairs(AllTheThingsSettings.General) do
				rawset(default.General, k, v);
			end
		end
		-- Tooltip Settings
		if AllTheThingsSettings.Tooltips then
			for k,v in pairs(AllTheThingsSettings.Tooltips) do
				rawset(default.Tooltips, k, v);
			end
		end
		-- Seasonal Filters
		if AllTheThingsSettings.Seasonal then
			for k,v in pairs(AllTheThingsSettings.Seasonal) do
				rawset(default.Seasonal, k, v);
			end
		end
		-- Unobtainable Filters
		if AllTheThingsSettings.Unobtainable then
			for k,v in pairs(AllTheThingsSettings.Unobtainable) do
				rawset(default.Unobtainable, k, v);
			end
		end
	end

	-- pull in window data for the default profile
	for _,window in pairs(app.Windows) do
		window:StorePosition();
	end

	app.print("Initialized ATT Profiles!");

	-- delete old variables
	AllTheThingsSettings = nil;
	AllTheThingsAD.UnobtainableItemFilters = nil;
	AllTheThingsAD.SeasonalFilters = nil;

	-- initialize settings again due to profiles existing now
	app.Settings:Initialize();
end

-- Called when the Addon is loaded to process initial startup information
app.Startup = function()
	local v = GetAddOnMetadata("AllTheThings", "Version");
	-- if placeholder exists as the Version tag, then assume we are not on the Release version
	if string.match(v, "version") then
		app.Version = "[Git]";
		-- adjust the Setting screen version display since it was already set from metadata
		if app.Settings.version then
			app.Settings.version:SetText("[Git]");
		end
	else
		app.Version = "v" .. v;
	end

	AllTheThingsAD = LocalizeGlobal("AllTheThingsAD", true);	-- For account-wide data.
	-- Cache the Localized Category Data
	AllTheThingsAD.LocalizedCategoryNames = setmetatable(AllTheThingsAD.LocalizedCategoryNames or {}, { __index = app.CategoryNames });
	app.CategoryNames = nil;

	-- Cache the Localized Flight Path Data
	--AllTheThingsAD.LocalizedFlightPathDB = setmetatable(AllTheThingsAD.LocalizedFlightPathDB or {}, { __index = app.FlightPathDB });
	--app.FlightPathDB = nil;	-- TODO: Deprecate this.

	-- Cache information about the player.
	local class, classID = UnitClassBase("player");
	local raceName, race, raceID = UnitRace("player");
	app.Class = class;
	app.ClassIndex = classID;
	app.Level = UnitLevel("player");
	local raceIndex = app.RaceDB[race];
	if type(raceIndex) == "table" then
		local factionGroup = UnitFactionGroup("player");
		raceIndex = raceIndex[factionGroup];
	end
	app.Race = race;
	app.RaceID = raceID;
	app.RaceIndex = raceIndex;
	-- 1 = unknown, 2 = male, 3 = female
	app.Gender = UnitSex("player");
	local name, realm = UnitName("player");
	realm = realm or GetRealmName();
	local className = GetClassInfo(classID);
	app.GUID = UnitGUID("player");
	app.Me = "|c"..RAID_CLASS_COLORS[class].colorStr..name.."-"..realm.."|r";
	app.ClassName = "|c"..RAID_CLASS_COLORS[class].colorStr..className.."|r";
	app.ActiveCustomCollects = {};

	LibStub:GetLibrary("LibDataBroker-1.1"):NewDataObject(L["TITLE"], {
		type = "launcher",
		icon = app.asset("logo_32x32"),
		OnClick = MinimapButtonOnClick,
		OnEnter = MinimapButtonOnEnter,
		OnLeave = MinimapButtonOnLeave,
	});

	-- Character Data Storage
	local characterData = LocalizeGlobal("ATTCharacterData", true);
	local currentCharacter = characterData[app.GUID];
	if not currentCharacter then
		currentCharacter = {};
		characterData[app.GUID] = currentCharacter;
	end
	if name then currentCharacter.name = name; end
	if realm then currentCharacter.realm = realm; end
	if app.Me then currentCharacter.text = app.Me; end
	if app.GUID then currentCharacter.guid = app.GUID; end
	if app.Level then currentCharacter.lvl = app.Level; end
	if app.FactionID then currentCharacter.factionID = app.FactionID; end
	if app.ClassIndex then currentCharacter.classID = app.ClassIndex; end
	if app.RaceIndex then currentCharacter.raceID = app.RaceIndex; end
	if class then currentCharacter.class = class; end
	if race then currentCharacter.race = race; end
	if not currentCharacter.Achievements then currentCharacter.Achievements = {}; end
	if not currentCharacter.ArtifactRelicItemLevels then currentCharacter.ArtifactRelicItemLevels = {}; end
	if not currentCharacter.AzeriteEssenceRanks then currentCharacter.AzeriteEssenceRanks = {}; end
	if not currentCharacter.Buildings then currentCharacter.Buildings = {}; end
	if not currentCharacter.CommonItems then currentCharacter.CommonItems = {}; end
	if not currentCharacter.CustomCollects then currentCharacter.CustomCollects = {}; end
	if not currentCharacter.Deaths then currentCharacter.Deaths = 0; end
	if not currentCharacter.Factions then currentCharacter.Factions = {}; end
	if not currentCharacter.FlightPaths then currentCharacter.FlightPaths = {}; end
	if not currentCharacter.Followers then currentCharacter.Followers = {}; end
	if not currentCharacter.Lockouts then currentCharacter.Lockouts = {}; end
	if not currentCharacter.Professions then currentCharacter.Professions = {}; end
	if not currentCharacter.Quests then currentCharacter.Quests = {}; end
	if not currentCharacter.Spells then currentCharacter.Spells = {}; end
	if not currentCharacter.Titles then currentCharacter.Titles = {}; end
	-- not needed, account-wide by blizzard
	currentCharacter.RuneforgeLegendaries = nil;
	if not currentCharacter.Conduits then currentCharacter.Conduits = {}; end
	currentCharacter.lastPlayed = time();
	app.CurrentCharacter = currentCharacter;

	-- Convert over the deprecated Characters table.
	local characters = GetDataMember("Characters");
	if characters then
		for guid,text in pairs(characters) do
			if not characterData[guid] then
				characterData[guid] = { ["text"] = text };
			end
		end
	end

	-- Convert over the deprecated AzeriteEssenceRanksPerCharacter table.
	local azeriteEssenceRanksPerCharacter = GetDataMember("AzeriteEssenceRanksPerCharacter");
	if azeriteEssenceRanksPerCharacter then
		for guid,data in pairs(azeriteEssenceRanksPerCharacter) do
			local character = characterData[guid];
			if character then character.AzeriteEssenceRanks = data; end
		end
	end

	-- Convert over the deprecated CollectedBuildingsPerCharacter table.
	local collectedBuildingsPerCharacter = GetDataMember("CollectedBuildingsPerCharacter");
	if collectedBuildingsPerCharacter then
		for guid,buildings in pairs(collectedBuildingsPerCharacter) do
			local character = characterData[guid];
			if character then character.Buildings = buildings; end
		end
	end

	-- Convert over the deprecated DeathsPerCharacter table.
	local deathsPerCharacter = GetDataMember("DeathsPerCharacter");
	if deathsPerCharacter then
		for guid,deaths in pairs(deathsPerCharacter) do
			local character = characterData[guid];
			if character then character.Deaths = deaths; end
		end
	end

	-- Convert over the deprecated CollectedFactionsPerCharacter table.
	local collectedFactionsPerCharacter = GetDataMember("CollectedFactionsPerCharacter");
	if collectedFactionsPerCharacter then
		for guid,factions in pairs(collectedFactionsPerCharacter) do
			local character = characterData[guid];
			if character then character.Factions = factions; end
		end
	end

	-- Convert over the deprecated CollectedFlightPathsPerCharacter table.
	local collectedFlightPathsPerCharacter = GetDataMember("CollectedFlightPathsPerCharacter");
	if collectedFlightPathsPerCharacter then
		for guid,flightPaths in pairs(collectedFlightPathsPerCharacter) do
			local character = characterData[guid];
			if character then character.FlightPaths = flightPaths; end
		end
	end

	-- Convert over the deprecated CollectedFollowersPerCharacter table.
	local collectedFollowersPerCharacter = GetDataMember("CollectedFollowersPerCharacter");
	if collectedFollowersPerCharacter then
		for guid,followers in pairs(collectedFollowersPerCharacter) do
			local character = characterData[guid];
			if character then character.Followers = followers; end
		end
	end

	-- Convert over the deprecated lockouts table.
	local lockouts = GetDataMember("lockouts");
	if lockouts then
		for guid,locks in pairs(lockouts) do
			local character = characterData[guid];
			if character then character.Lockouts = locks; end
		end
	end

	-- Convert over the deprecated CollectedQuestsPerCharacter table.
	local collectedQuestsPerCharacter = GetDataMember("CollectedQuestsPerCharacter");
	if collectedQuestsPerCharacter then
		for guid,quests in pairs(collectedQuestsPerCharacter) do
			local character = characterData[guid];
			if character then character.Quests = quests; end
		end
	end

	-- Convert over the deprecated CollectedSpellsPerCharacter table.
	local collectedSpellsPerCharacter = GetDataMember("CollectedSpellsPerCharacter");
	if collectedSpellsPerCharacter then
		for guid,spells in pairs(collectedSpellsPerCharacter) do
			local character = characterData[guid];
			if character then character.Spells = spells; end
		end
	end

	-- Convert over the deprecated CollectedTitlesPerCharacter table.
	local collectedTitlesPerCharacter = GetDataMember("CollectedTitlesPerCharacter");
	if collectedTitlesPerCharacter then
		for guid,titles in pairs(collectedTitlesPerCharacter) do
			local character = characterData[guid];
			if character then character.Titles = titles; end
		end
	end

	-- Account Wide Data Storage
	ATTAccountWideData = LocalizeGlobal("ATTAccountWideData", true);
	local accountWideData = ATTAccountWideData;
	if not accountWideData.Achievements then accountWideData.Achievements = {}; end
	if not accountWideData.Artifacts then accountWideData.Artifacts = {}; end
	if not accountWideData.AzeriteEssenceRanks then accountWideData.AzeriteEssenceRanks = {}; end
	if not accountWideData.Buildings then accountWideData.Buildings = {}; end
	if not accountWideData.CommonItems then accountWideData.CommonItems = {}; end
	if not accountWideData.Factions then accountWideData.Factions = {}; end
	if not accountWideData.FactionBonus then accountWideData.FactionBonus = {}; end
	if not accountWideData.FlightPaths then accountWideData.FlightPaths = {}; end
	if not accountWideData.Followers then accountWideData.Followers = {}; end
	if not accountWideData.HeirloomRanks then accountWideData.HeirloomRanks = {}; end
	if not accountWideData.Illusions then accountWideData.Illusions = {}; end
	if not accountWideData.Quests then accountWideData.Quests = {}; end
	if not accountWideData.Sources then accountWideData.Sources = {}; end
	if not accountWideData.Spells then accountWideData.Spells = {}; end
	if not accountWideData.Titles then accountWideData.Titles = {}; end
	if not accountWideData.Toys then accountWideData.Toys = {}; end
	if not accountWideData.OneTimeQuests then accountWideData.OneTimeQuests = {}; end
	if not accountWideData.RuneforgeLegendaries then accountWideData.RuneforgeLegendaries = {}; end
	if not accountWideData.Conduits then accountWideData.Conduits = {}; end

	-- Update the total account wide death counter.
	local deaths = 0;
	for guid,character in pairs(characterData) do
		if character and character.Deaths and character.Deaths > 0 then
			deaths = deaths + character.Deaths;
		end
	end
	accountWideData.Deaths = deaths;

	-- Convert over the deprecated account wide tables.
	local data = GetDataMember("CollectedAchievements");
	if data then accountWideData.Achievements = data; end
	data = GetDataMember("CollectedArtifacts");
	if data then
		if not data.V then
			wipe(data);
			C_Timer.After(30, function() app.print(L["ARTIFACT_CACHE_OUT_OF_DATE"]); end);
		else
			data.V = nil;
		end
		accountWideData.Artifacts = data;
	elseif accountWideData.Artifacts.V then
		accountWideData.Artifacts.V = nil;
	end
	data = GetDataMember("AzeriteEssenceRanks");
	if data then accountWideData.AzeriteEssenceRanks = data; end
	data = GetDataMember("CollectedBuildings");
	if data then accountWideData.Buildings = data; end
	data = GetDataMember("CollectedFactions");
	if data then accountWideData.Factions = data; end
	data = GetDataMember("CollectedFactionBonusReputation");
	if data then accountWideData.FactionBonus = data; end
	data = GetDataMember("CollectedFlightPaths");
	if data then accountWideData.FlightPaths = data; end
	data = GetDataMember("CollectedFollowers");
	if data then accountWideData.Followers = data; end
	data = GetDataMember("HeirloomUpgradeRanks");
	if data then accountWideData.HeirloomRanks = data; end
	data = GetDataMember("CollectedIllusions");
	if data then accountWideData.Illusions = data; end
	data = GetDataMember("CollectedQuests");
	if data then accountWideData.Quests = data; end
	data = GetDataMember("CollectedSources");
	if data then accountWideData.Sources = data; end
	data = GetDataMember("CollectedSpells");
	if data then accountWideData.Spells = data; end
	data = GetDataMember("CollectedTitles");
	if data then accountWideData.Titles = data; end
	data = GetDataMember("CollectedToys");
	if data then accountWideData.Toys = data; end

	-- Clean up settings
	local oldsettings = {};
	for i,key in ipairs({
		"LinkedAccounts",
		"LocalizedCategoryNames",
		--"LocalizedFlightPathDB",
		"Position",
		"RandomSearchFilter",
		"Reagents",
	}) do
		rawset(oldsettings, key, rawget(AllTheThingsAD, key));
	end
	wipe(AllTheThingsAD);
	for key,value in pairs(oldsettings) do
		rawset(AllTheThingsAD, key, value);
	end
	GetDataMember("LinkedAccounts", {});

	-- Init the Settings before working with data
	app.Settings:Initialize();

	-- Attempt to register for the addon message prefix.
	C_ChatInfo.RegisterAddonMessagePrefix("ATT");

	-- Register remaining addon-related events
	app:RegisterEvent("BOSS_KILL");
	app:RegisterEvent("CHAT_MSG_ADDON");
	app:RegisterEvent("PLAYER_ENTERING_WORLD");
	app:RegisterEvent("NEW_PET_ADDED");
	app:RegisterEvent("PET_JOURNAL_PET_DELETED");
	app:RegisterEvent("PLAYER_DIFFICULTY_CHANGED");
	app:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_ADDED");
	app:RegisterEvent("TRANSMOG_COLLECTION_SOURCE_REMOVED");
	app:RegisterEvent("PET_BATTLE_OPENING_START")
	app:RegisterEvent("PET_BATTLE_CLOSE")
	app:RegisterEvent("VIGNETTE_MINIMAP_UPDATED")
	app:RegisterEvent("VIGNETTES_UPDATED")

	StartCoroutine("InitDataCoroutine", app.InitDataCoroutine);
end

-- Function which is triggered after Startup
app.InitDataCoroutine = function()
	-- First, load the addon data
	app:GetDataCache();

	-- Then wait for the player to actually be 'in the game' to do further logic
	while not app.InWorld do coroutine.yield(); end

	local accountWideData = LocalizeGlobal("ATTAccountWideData");
	local characterData = LocalizeGlobal("ATTCharacterData");
	local currentCharacter = characterData[app.GUID];

	-- Clean up other matching Characters with identical Name-Realm but differing GUID
	Callback(function()
		local myGUID = app.GUID;
		local myName, myRealm = currentCharacter.name, currentCharacter.realm;
		local myRegex = "%|cff[A-z0-9][A-z0-9][A-z0-9][A-z0-9][A-z0-9][A-z0-9]"..myName.."%-"..myRealm.."%|r";
		local otherName, otherRealm, otherText;
		local toClean;
		for guid,character in pairs(characterData) do
			-- simple check on name/realm first
			otherName = character.name;
			otherRealm = character.realm;
			otherText = character.text;
			if guid ~= myGUID then
				if otherName == myName and otherRealm == myRealm then
					if toClean then tinsert(toClean, guid)
					else toClean = { guid }; end
				elseif otherText and otherText:match(myRegex) then
					if toClean then tinsert(toClean, guid)
					else toClean = { guid }; end
				end
			end
		end
		if toClean then
			local copyTables = { "Buildings","Factions","FlightPaths","Quests" };
			local cleanCharacterFunc = function(guid)
				-- copy the set of QuestIDs from the duplicate character (to persist repeatable Quests collection)
				local character = characterData[guid];
				for _,tableName in ipairs(copyTables) do
					local copyTable = character[tableName];
					if copyTable then
						-- app.PrintDebug("Copying Dupe",tableName)
						local currentTable = currentCharacter[tableName];
						for ID,complete in pairs(copyTable) do
							-- app.PrintDebug("Check",ID,complete,"?",currentTable[ID])
							if complete and not currentTable[ID] then
								-- app.PrintDebug("Copied Completed",ID)
								currentTable[ID] = complete;
							end
						end
					end
				end
				-- Remove the actual dupe data afterwards
				-- move to a backup table temporarily in case anyone reports weird issues, we could potentially resolve them?
				local backups = accountWideData["_CharacterBackups"];
				if not backups then
					backups = {};
					accountWideData["_CharacterBackups"] = backups;
				end
				backups[guid] = character;
				characterData[guid] = nil;
				-- app.print("Removed & Backed up Duplicate Data of Current Character:",character.text,guid)
			end
			app.FunctionRunner.SetPerFrame(1);
			for _,guid in ipairs(toClean) do
				app.FunctionRunner.Run(cleanCharacterFunc, guid);
			end
		end
	end);

	-- Harvest the Spell IDs for Conversion.
	app:UnregisterEvent("PET_JOURNAL_LIST_UPDATE");

	-- Verify that reagent cache is of the correct format by checking a special key
	local reagentCache, reagentCacheVer = app.GetDataMember("Reagents", {}), 2;
	if not reagentCache[-1] or reagentCache[-1] < reagentCacheVer then
		C_Timer.After(30, function() app.print(L["REAGENT_CACHE_OUT_OF_DATE"]); end);
		wipe(reagentCache);
		reagentCache[-1] = reagentCacheVer;
	end

	-- Mark all previously completed quests.
	app.QueryCompletedQuests();

	-- Update character known professions
	app.RefreshTradeSkillCache();

	-- Current character collections shouldn't use '2' ever... so clear any 'inaccurate' data
	local currentQuestsCache = currentCharacter.Quests;
	for questID,completion in pairs(currentQuestsCache) do
		if completion == 2 then currentQuestsCache[questID] = nil; end
	end

	-- Cache some collection states for account wide quests that aren't actually granted account wide and can be flagged using an achievementID. (Allied Races)
	local collected;
	local acctQuests, oneTimeQuests = accountWideData.Quests, accountWideData.OneTimeQuests;
	-- achievement collection state isn't readily available when ADDON_LOADED fires, so we do it here to ensure we get a valid state for matching
	for _,achievementQuests in ipairs({
		{ 12453, { 49973, 49613, 49354, 49614 } },	-- Allied Races: Nightborne
		{ 12517, { 53466, 53467, 53354, 53353, 53355, 52942, 52943, 52945, 52955, 51479 } },	-- Allied Races: Mag'har
		{ 13156, { 53831, 53823, 53824, 54419, 53826, 54301, 54925, 54300, 53825, 53827, 53828, 54031, 54033, 54032, 54034, 53830, 53719 } },	-- Allied Races: Zandalari Troll
		{ 12452, { 48066, 48067, 49756, 48079, 41884, 41764, 48185, 41799, 48190, 41800, 48434, 41815, 41840, 41882, 41841, 48403, 48433 } },	-- Allied Races: Highmountain Tauren
		{ 12450, { 49787, 48962 } },	-- Allied Races: Void Elf
		{ 12516, { 51813, 53351, 53342, 53352, 51474, 53566 } },	-- Allied Races: Dark Iron Dwarf
		{ 12451, { 49698, 49266, 50071 } },	-- Allied Races: Lightforged Draenei
		{ 13157, { 54706, 55039, 55043, 54708, 54721, 54723, 54725, 54726, 54727, 54728, 54730, 54731, 54729, 54732, 55136, 54733, 54734, 54735, 54851, 53720 } },	-- Allied Races: Kul Tiran
		{ 14012, { 58214, 57486, 57487, 57488, 57490, 57491, 57492, 57493, 57494, 57496, 57495, 57497 } },	-- Allied Races: Mechagnome
		{ 13207, { 53870, 53889, 53890, 53891, 53892, 53893, 53894, 53895, 53897, 53898, 54026, 53899, 58087, 53901, 53900, 53902, 54027, 53903, 53904, 53905, 54036, 53906, 53907, 53908, 57448 } },	-- Allied Races: Vulpera
		-- Garrison Shipyard Equipment Blueprints
		{ 10372, { 38932 } }, -- Equipment Blueprint: Bilge Pump
		{ 10373, { 39366 } }, -- Equipment Blueprint: Felsmoke Launchers
		{ 10374, { 39356 } }, -- Equipment Blueprint: High Intensity Fog Lights
		{ 10375, { 39365 } }, -- Equipment Blueprint: Ghostly Spyglass
		{ 10376, { 39364 } }, -- Equipment Blueprint: Gyroscopic Internal Stabilizer
		{ 10377, { 39363 } }, -- Equipment Blueprint: Ice Cutter
		{ 10378, { 39355 } }, -- Equipment Blueprint: Trained Shark Tank
		{ 10379, { 39360 } }, -- Equipment Blueprint: True Iron Rudder
		-- stupid pet tamer breadcrumbs that are once per account (there may be more breadcrumbs for the questline that need to be added here)
		-- these aren't really 'once per account' in that only a single character gets credit.
		-- all 5 quests of the faction are marked completed account-wide, and the other 5 can never be completed on that account
		-- { 6603, { 32008 } },	-- Taming Eastern Kingdoms / Audrey Burnhep (A)
		-- { 6602, { 32009 } },	-- Taming Kalimdor / Varzok (H)
	}) do
		-- If you completed the achievement, then mark the associated quests.
		collected = select(4, GetAchievementInfo(achievementQuests[1]));
		for _,questID in ipairs(achievementQuests[2]) do
			if collected then
				-- Mark the quest as completed for the Account
				acctQuests[questID] = 1;
				if not oneTimeQuests[questID] and CompletedQuests[questID] then
					-- this once-per-account quest only counts for a specific character
					oneTimeQuests[questID] = app.GUID;
				end
			end
			-- otherwise indicate the one-time-nature of the quest
			if oneTimeQuests[questID] == nil then
				oneTimeQuests[questID] = false;
			end
		end
	end
	-- Cache some collection states for account wide quests that aren't actually granted account wide and can be flagged using a known sourceID.  (Secrets)
	for _,appearanceQuests in ipairs({
		-- Waist of Time isn't technically once-per-account, so don't fake the cached data
		-- { 98614, { 52829, 52830, 52831, 52898, 52899, 52900, 52901, 52902, 52903, 52904, 52905, 52906, 52907, 52908, 52909, 52910, 52911, 52912, 52913, 52914, 52915, 52916, 52917, 52918, 52919, 52920, 52921, 52922, 52822, 52823, 52824, 52826} },	-- Waist of Time
	}) do
		-- If you have the appearance, then mark the associated quests.
		local sourceInfo = C_TransmogCollection_GetSourceInfo(appearanceQuests[1]);
		collected = sourceInfo.isCollected;
		for _,questID in ipairs(appearanceQuests[2]) do
			if collected then
				-- Mark the quest as completed for the Account
				acctQuests[questID] = 1;
				if not oneTimeQuests[questID] and CompletedQuests[questID] then
					-- this once-per-account quest only counts for a specific character
					oneTimeQuests[questID] = app.GUID;
				end
			end
			-- otherwise indicate the one-time-nature of the quest
			if oneTimeQuests[questID] == nil then
				oneTimeQuests[questID] = false;
			end
		end
	end
	-- Cache some collection states for misc. once-per-account quests
	for _,questID in ipairs({
		-- BFA Mission/Outpost Quests which trigger locking Account-Wide HQTs
		52478,	-- Hillcrest Pasture (Mission Completion)
		52479,	-- Hillcrest Pasture (BFA Horde Outpost Unlock)
		52313,	-- Mudfisher Cove (Mission Completion)
		52314,	-- Mudfisher Cove (BFA Horde Outpost Unlock)
		52221,	-- Stonefist Watch (Mission Completion)
		52222,	-- Stonefist Watch (BFA Horde Outpost Unlock)
		52776,	-- Stonetusk Watch (Mission Completion)
		52777,	-- Stonetusk Watch (BFA Horde Outpost Unlock)
		52275,	-- Swiftwind Post (Mission Completion)
		52276,	-- Swiftwind Post (BFA Horde Outpost Unlock)
		52319,	-- Windfall Cavern (Mission Completion)
		52320,	-- Windfall Cavern (BFA Horde Outpost Unlock)
		52005,	-- The Wolf's Den (Mission Completion)
		52127,	-- The Wolf's Den (BFA Horde Outpost Unlock)
		53151,	-- Wolves For The Den (Mission Completion)
		53152,	-- Wolves For The Den (BFA Horde Outpost Upgrade)

		53006,	-- Grimwatt's Crash (Mission Completion)
		53007,	-- Grimwatt's Crash (BFA Alliance Outpost Unlock)
		52801,	-- Veiled Grotto (Mission Completion)
		52802,	-- Veiled Grotto (BFA Alliance Outpost Unlock)
		52962,	-- Mistvine Ledge (Mission Completion)
		52963,	-- Mistvine Ledge (BFA Alliance Outpost Unlock)
		52851,	-- Mugamba Overlook (Mission Completion)
		52852,	-- Mugamba Overlook (BFA Alliance Outpost Unlock)
		52886,	-- Verdant Hollow (Mission Completion)
		52888,	-- Verdant Hollow (BFA Alliance Outpost Unlock)
		53043,	-- Vulture's Nest (Mission Completion)
		53044,	-- Vulture's Nest (BFA Alliance Outpost Unlock)

		-- These are BOTH once-per-account (single character) completion & shared account-wide lockout groups (likely due to locking Account-Wide HQTs)
		53063,	-- A Mission of Unity (BFA Alliance WQ Unlock)
		53064,	-- A Mission of Unity (BFA Horde WQ Unlock)

		53061,	-- The Azerite Advantage (BFA Alliance Island Unlock / AWHQT 51994)
		53062,	-- The Azerite Advantage (BFA Horde Island Unlock / AWHQT 51994)

		53055,	-- Pushing Our Influence (BFA Horde PreQ for 1st Foothold)
		53056,	-- Pushing Our Influence (BFA Alliance PreQ for 1st Foothold)

		53207,	-- The Warfront Looms (BFA Horde Warfront Breadcrumb)
		53175,	-- The Warfront Looms (BFA Alliance Warfront Breadcrumb)

		-- Shard Labor
		61229,	-- forging the Crystal Mallet of the Heralds
		61191,	-- ringing the Vesper of the Silver Wind
		61183,	-- looting the Gift of the Silver Wind

		-- Ve'nari Items (The Quest Bonus is Accwide but quests itself are not accwide)
		63193,	-- Bangle of Seniority
		63523,	-- Broker Traversam Enhancer
		63183, 	-- Extradimensional Pockets
		63201,	-- Loupe of Unusual Charm
		61144,	-- Possibility Matrix
		63200,	-- Rang Insignia: Acquisitionist
		63204,	-- Ritual Prism of Fortune
		63202,	-- Vessel of Unfortunate Spirits

		-- Druid forms
		65047, 	-- Mark of the Nightwing Raven
		-- etc.
	}) do
		-- If this Character has the Quest completed and it is not marked as completed for Account or not for specific Character
		if not oneTimeQuests[questID] and CompletedQuests[questID] then
			-- Mark the quest as completed for the Account
			acctQuests[questID] = 1;
			-- Mark the character which completed the Quest
			oneTimeQuests[questID] = app.GUID;
		end
		-- otherwise indicate the one-time-nature of the quest
		if oneTimeQuests[questID] == nil then
			oneTimeQuests[questID] = false;
		end
	end

	-- if we ever erroneously add an account-wide quest and find out it isn't (or Blizzard actually fixes it to give account-wide credit)
	-- put it here so it reverts back to being handled as a normal quest
	for _,questID in ipairs({
		32008,	-- Audrey Burnhep (A)
		32009,	-- Varzok (H)

		62038,	-- Handful of Oats
		62042,	-- Grooming Brush
		62047,	-- Sturdy Horseshoe
		62049,	-- Bucket of Clean Water
		62048,	-- Comfortable Saddle Blanket
		62050,	-- Dredhollow Apple
	}) do
		oneTimeQuests[questID] = nil;
	end

	local anyComplete;
	-- Check for fixing Blizzard's incompetence in consistency for shared account-wide quest eligibility which is only granted to some of the shared account-wide quests
	for _,questGroup in ipairs({
		{ 32008, 32009, 31878, 31879, 31880, 31881, 31882, 31883, 31884, 31885, },	-- Pet Battle Intro quests
		{
			53063, 	-- A Mission of Unity (BFA Alliance WQ Unlock)
			53064, 	-- A Mission of Unity (BFA Horde WQ Unlock)
		},
		{
			53061, 	-- The Azerite Advantage (BFA Alliance Island Unlock / AWHQT 51994)
			53062,  -- The Azerite Advantage (BFA Horde Island Unlock / AWHQT 51994)
		},
		{
			53055, 	-- Pushing Our Influence (BFA Horde PreQ for 1st Foothold)
			53056,	-- Pushing Our Influence (BFA Alliance PreQ for 1st Foothold)
		},
		{
			53207,	-- The Warfront Looms (BFA Horde Warfront Breadcrumb)
			53175,	-- The Warfront Looms (BFA Alliance Warfront Breadcrumb)
		},
		{
			31977 ,	-- The Returning Champion (Horde Winterspring Pass Pet Battle Quest)
			31975 ,	-- The Returning Champion (Alliance Winterspring Pass Pet Battle Quest)
		},
		{
			31980 ,	-- The Returning Champion (Horde Deadwind Pass Pet Battle Quest)
			31976 ,	-- The Returning Champion (Alliance Deadwind Pass Pet Battle Quest)
		},
	}) do
		for _,questID in ipairs(questGroup) do
			-- If this Character has the Quest completed
			if CompletedQuests[questID] then
				-- Mark the quest as completed for the Account
				acctQuests[questID] = 1;
				anyComplete = true;
			end
		end
		-- if any of the quest group is considered complete, then the rest need to be considered 'complete' as well since they can never be actually completed on the account
		if anyComplete then
			for _,questID in ipairs(questGroup) do
				-- Mark the quest completion since it's not 'really' completed
				if not acctQuests[questID] then
					acctQuests[questID] = 2;
				end
			end
		end
		anyComplete = nil;
	end

	wipe(DirtyQuests);

	app:RegisterEvent("QUEST_LOG_UPDATE");
	app:RegisterEvent("QUEST_TURNED_IN");
	app:RegisterEvent("QUEST_ACCEPTED");
	app:RegisterEvent("QUEST_REMOVED");
	app:RegisterEvent("HEIRLOOMS_UPDATED");
	app:RegisterEvent("ARTIFACT_UPDATE");
	app:RegisterEvent("CRITERIA_UPDATE");
	app:RegisterEvent("TOYS_UPDATED");
	app:RegisterEvent("LOOT_OPENED");
	app:RegisterEvent("QUEST_DATA_LOAD_RESULT");
	app:RegisterEvent("LEARNED_SPELL_IN_TAB");

	local needRefresh;
	-- NOTE: The auto refresh only happens once per version
	if not accountWideData.LastAutoRefresh or (accountWideData.LastAutoRefresh ~= app.Version) then
		accountWideData.LastAutoRefresh = app.Version;
		needRefresh = true;
	end

	-- check if we are in a Party Sync session when loading in
	app.IsInPartySync = C_QuestSession.Exists();

	-- finally can say the app is ready
	-- even though RefreshData starts a coroutine, this failed to get set one time when called after the coroutine started...
	app.IsReady = true;
	-- print("ATT is Ready!");

	app.RefreshSaves();

	-- Let a frame go before hitting the initial refresh to make sure as much time as possible is allowed for the operation
	-- print("Yield prior to Refresh")
	coroutine.yield();

	if needRefresh then
		-- print("Force Refresh")
		-- collection refresh includes data refresh
		app.RefreshCollections();
	else
		-- print("Refresh")
		app:RefreshData(false);
	end

	-- Setup the use of profiles after a short delay to ensure that the layout window positions are collected
	if not AllTheThingsProfiles then DelayedCallback(app.SetupProfiles, 5); end

	-- do a settings apply to ensure ATT windows which have now been created, are moved according to the current Profile
	app.Settings:ApplyProfile();

	-- now that the addon is ready, make sure the minilist is updated to the current location if necessary
	DelayedCallback(app.LocationTrigger, 3);
end
end -- Setup and Startup Functionality

-- Slash Command List
SLASH_AllTheThings1 = "/allthethings";
SLASH_AllTheThings2 = "/things";
SLASH_AllTheThings3 = "/att";
SlashCmdList["AllTheThings"] = function(cmd)
	if cmd then
		-- print(cmd)
		local args = { strsplit(" ", string_lower(cmd)) };
		cmd = args[1];
		-- app.print(args)
		-- first arg is always the window/command to execute
		for k=2,#args do
			local customArg, customValue = args[k];
			customArg, customValue = strsplit("=",customArg);
			-- app.PrintDebug("Split custom arg:",customArg,customValue)
			app.SetCustomWindowParam(cmd, customArg, customValue or true);
		end
		if not cmd or cmd == "" or cmd == "main" or cmd == "mainlist" then
			app.ToggleMainList();
			return true;
		elseif cmd == "bounty" then
			app:GetWindow("Bounty"):Toggle();
			return true;
		elseif cmd == "debugger" then
			app.LoadDebugger();
			return true;
		elseif cmd == "filters" then
			app:GetWindow("ItemFilter"):Toggle();
			return true;
		elseif cmd == "finder" then
			app:GetWindow("ItemFinder"):Toggle();
			return true;
		elseif cmd == "ra" then
			app:GetWindow("RaidAssistant"):Toggle();
			return true;
		elseif cmd == "ran" or cmd == "rand" or cmd == "random" then
			app:GetWindow("Random"):Toggle();
			return true;
		elseif cmd == "quests" then
			app:GetWindow("quests"):Toggle();
			return true;
		elseif cmd == "wq" then
			app:GetWindow("WorldQuests"):Toggle();
			return true;
		elseif cmd == "unsorted" then
			app:GetWindow("Unsorted"):Toggle();
			return true;
		elseif cmd == "harvest12345" then
			StartCoroutine("Harvesting", function()
				print("Harvesting...");
				local totalItems = 200000;
				local itemsPerYield = 25;
				local counts = {};
				local items = GetDataMember("ItemDB", {});
				for itemID=1,totalItems do
					tinsert(counts, {itemID=itemID,retries=0});
				end
				local slots = {
					["INVTYPE_AMMO"] = INVSLOT_AMMO;
					["INVTYPE_HEAD"] = INVSLOT_HEAD;
					["INVTYPE_NECK"] = INVSLOT_NECK;
					["INVTYPE_SHOULDER"] = INVSLOT_SHOULDER;
					["INVTYPE_BODY"] = INVSLOT_BODY;
					["INVTYPE_CHEST"] = INVSLOT_CHEST;
					["INVTYPE_ROBE"] = INVSLOT_CHEST;
					["INVTYPE_WAIST"] = INVSLOT_WAIST;
					["INVTYPE_LEGS"] = INVSLOT_LEGS;
					["INVTYPE_FEET"] = INVSLOT_FEET;
					["INVTYPE_WRIST"] = INVSLOT_WRIST;
					["INVTYPE_HAND"] = INVSLOT_HAND;
					["INVTYPE_FINGER"] = INVSLOT_FINGER1;
					["INVTYPE_TRINKET"] = INVSLOT_TRINKET1;
					["INVTYPE_CLOAK"] = INVSLOT_BACK;
					["INVTYPE_WEAPON"] = INVSLOT_MAINHAND;
					["INVTYPE_SHIELD"] = INVSLOT_OFFHAND;
					["INVTYPE_2HWEAPON"] = INVSLOT_MAINHAND;
					["INVTYPE_WEAPONMAINHAND"] = INVSLOT_MAINHAND;
					["INVTYPE_WEAPONOFFHAND"] = INVSLOT_OFFHAND;
					["INVTYPE_HOLDABLE"] = INVSLOT_OFFHAND;
					["INVTYPE_RANGED"] = INVSLOT_RANGED;
					["INVTYPE_THROWN"] = INVSLOT_RANGED;
					["INVTYPE_RANGEDRIGHT"] = INVSLOT_RANGED;
					["INVTYPE_RELIC"] = INVSLOT_RANGED;
					["INVTYPE_TABARD"] = INVSLOT_TABARD;
					["INVTYPE_BAG"] = CONTAINER_BAG_OFFSET;
					["INVTYPE_QUIVER"] = CONTAINER_BAG_OFFSET;
				};
				while #counts > 0 do
					for i=math.min(#counts,itemsPerYield),1,-1 do
						local o = counts[i];
						local itemID = o.itemID;
						local _, itemType, itemSubType, itemEquipLoc, icon, itemClassID, itemSubClassID = GetItemInfoInstant(itemID);
						if itemType then
							local info = {};
							info.itemID = itemID;
							if itemClassID then info.class = itemClassID; end
							if itemSubClassID then info.subclass = itemSubClassID; end
							if itemEquipLoc then info.inventoryType = slots[itemEquipLoc]; end

							-- Extra information
							local itemName, itemLink, itemRarity, itemLevel, itemMinLevel, itemType, itemSubType, itemStackCount, itemEquipLoc, itemIcon, itemSellPrice, itemClassID, itemSubClassID, bindType, expacID, itemSetID, isCraftingReagent = GetItemInfo(itemID);
							local spellName, spellID = GetItemSpell(itemID);
							if itemName then
								info.name = itemName;
								if expacID then info.expacID = expacID; end
								if itemMinLevel then info.lvl = itemMinLevel; end
								if itemRarity then info.q = itemRarity; end
								if itemLevel then info.ilvl = itemLevel; end
								if bindType then info.b = bindType; end
								if spellID then info.spellID = spellID; end
								items[itemID] = info;
								print("Added item ", itemID, itemName);
								o.retries = o.retries + 100;
							else
								o.retries = o.retries + 1;
							end
						else
							o.retries = o.retries + 1;
						end
						if o.retries > 5 then
							table.remove(counts, i);
						end
					end
					print((totalItems - #counts) .. " / " .. totalItems);
					coroutine.yield();
				end
				print("Harvest Done.");
			end);
			return true;
		elseif strsub(cmd, 1, 4) == "mini" then
			app:ToggleMiniListForCurrentZone();
			return true;
		else
			if strsub(cmd, 1, 6) == "mapid:" then
				app:GetWindow("CurrentInstance"):SetMapID(tonumber(strsub(cmd, 7)));
				return true;
			end
		end

		-- Search for the Link in the database
		app.SetSkipPurchases(2);
		local group = GetCachedSearchResults(cmd, SearchForLink, cmd);
		app.SetSkipPurchases(0);
		-- make sure it's 'something' returned from the search before throwing it into a window
		if group and (group.link or group.name or group.text or group.key) then
			app:CreateMiniListForGroup(group);
			return true;
		end
		app.print("Unknown Command: ", cmd);
	else
		-- Default command
		app.ToggleMainList();
	end
end

SLASH_AllTheThingsBOUNTY1 = "/attbounty";
SlashCmdList["AllTheThingsBOUNTY"] = function(cmd)
	app:GetWindow("Bounty"):Toggle();
end

SLASH_AllTheThingsHARVESTER1 = "/attharvest";
SLASH_AllTheThingsHARVESTER2 = "/attharvester";
SlashCmdList["AllTheThingsHARVESTER"] = function(cmd)
	if cmd then
		local min,max,reset = strsplit(",",cmd);
		app.customHarvestMin = tonumber(min) or 1;
		app.customHarvestMax = tonumber(max) or 210000;
		app.print("Set Harvest ItemID Bounds:",app.customHarvestMin,app.customHarvestMax);
		AllTheThingsHarvestItems = reset and {} or AllTheThingsHarvestItems or {};
		AllTheThingsArtifactsItems = reset and {} or AllTheThingsArtifactsItems or {};
		if reset then app.print("Harvest Data Reset!"); end
	end
	app:GetWindow("Harvester"):Toggle();
end

SLASH_AllTheThingsMAPS1 = "/attmaps";
SlashCmdList["AllTheThingsMAPS"] = function(cmd)
	app:GetWindow("CosmicInfuser"):Toggle();
end

SLASH_AllTheThingsMINI1 = "/attmini";
SLASH_AllTheThingsMINI2 = "/attminilist";
SlashCmdList["AllTheThingsMINI"] = function(cmd)
	app:ToggleMiniListForCurrentZone();
end

SLASH_AllTheThingsRA1 = "/attra";
SLASH_AllTheThingsRA2 = "/attraid";
SlashCmdList["AllTheThingsRA"] = function(cmd)
	app:GetWindow("RaidAssistant"):Toggle();
end

SLASH_AllTheThingsRAN1 = "/attran";
SLASH_AllTheThingsRAN2 = "/attrandom";
SlashCmdList["AllTheThingsRAN"] = function(cmd)
	app:GetWindow("Random"):Toggle();
end

SLASH_AllTheThingsU1 = "/attu";
SLASH_AllTheThingsU2 = "/attyou";
SLASH_AllTheThingsU3 = "/attwho";
SlashCmdList["AllTheThingsU"] = function(cmd)
	local name,server = UnitName("target");
	if name then SendResponseMessage("?", server and (name .. "-" .. server) or name); end
end

SLASH_AllTheThingsWQ1 = "/attwq";
SlashCmdList["AllTheThingsWQ"] = function(cmd)
	app:GetWindow("WorldQuests"):Toggle();
end

-- Clickable ATT Chat Link Handling
(function()
	hooksecurefunc("SetItemRef", function(link, text)
		-- print("Chat Link Click",link,string.gsub(text, "\|","&"));
		-- if IsShiftKeyDown() then
		-- 	ChatEdit_InsertLink(text);
		-- else
		local type, info, data1, data2, data3 = strsplit(":", link);
		-- print(type, info, data1, data2, data3)
		if type == "garrmission" and info == "ATT" then
			-- local op = string.sub(link, 17)
			-- print("ATT Link",op)
			-- local type, paramA, paramB = strsplit(":", data);
			-- print(type,paramA,paramB)
			if data1 == "search" then
				local cmd = data2 .. ":" .. data3;
				app.SetSkipPurchases(2);
				local group = GetCachedSearchResults(cmd, SearchForLink, cmd);
				app.SetSkipPurchases(0);
				app:CreateMiniListForGroup(group);
				return true;
			elseif data1 == "dialog" then
				return app:TriggerReportDialog(data2);
			-- elseif type == "nav" then
			-- 	print(type,paramA,paramB)
			end
		elseif type == "quest" then
			-- Attach Quest info to Quest links in chat
			if ItemRefTooltip then
				-- print("show quest info",info)
				AttachTooltipSearchResults(ItemRefTooltip, 1, "quest:"..info, SearchForField, "questID", info);
				ItemRefTooltip:Show();
			end
		end
	end);

	-- Turns a bit of text into a colored link which ATT will attempt to understand
	function app:Linkify(text, color, operation)
		text = "|Hgarrmission:ATT:"..operation.."|h|c"..color.."["..text.."]|r|h";
		-- print("Linkify",text)
		return text;
	end
	-- Turns a bit of text into a chat-sendable link which other ATT users will attempt to understand
	-- function app:ChatLink(text, operation)
	-- 	text = "|Hgarrmission:ATT:"..operation.."|h["..text.."]|h";
	-- 	print("ChatLink",text)
	-- 	return text;
	-- end

	-- local function GetNavPath(group)
	-- 	local current, nav, hash = group;
	-- 	repeat
	-- 		hash = current.hash;
	-- 		if hash then
	-- 			if nav then
	-- 				nav = hash .. ">" .. nav;
	-- 			else
	-- 				nav = hash;
	-- 			end
	-- 		end
	-- 		current = current.parent;
	-- 	until not current;
	-- 	return nav;
	-- end

	-- function app:GroupNavLink(group)
	-- 	local nav = GetNavPath(group);
	-- 	if nav then
	-- 		print("nav:",nav)
	-- 		return app:Linkify(group.text, app.Colors.ChatLink, "nav:"..nav);
	-- 		-- return app:ChatLink(group.text, "nav:"..nav);
	-- 	end
	-- end

	-- Stores some information for use by a report popup by id
	function app:SetupReportDialog(id, reportMessage, text)
		if not app.popups then app.popups = {}; end
		if not app.popups[id] then
			local popupID;
			if type(text) == "table" then
				popupID = { ["msg"] = reportMessage, ["text"] = app.TableConcat(text, nil, "", "\n") };
			else
				popupID = { ["msg"] = reportMessage, ["text"] = text };
			end
			-- print("Setup PopupID",id)
			-- app.PrintTable(popupID);
			app.popups[id] = popupID;
			return true;
		end
	end

	-- function app:TestReportDialog()
	-- 	local coord;
	-- 	local mapID = app.GetCurrentMapID();
    -- 	local position = C_Map.GetPlayerMapPosition(mapID, "player")
	-- 	if position then
    --     	local x,y = position:GetXY();
    --         x = math.floor(x * 1000) / 10;
    --         y = math.floor(y * 1000) / 10;
	-- 		coord = x..","..y;
	-- 	end
	-- 	app:SetupReportDialog("test", "TEST Report Dialog",
	-- 				{
	-- 					"```",	-- discord fancy box

	-- 					"race:"..app.RaceID,
	-- 					"class:"..app.ClassIndex,
	-- 					"lvl:"..app.Level,
	-- 					"mapID:"..app.GetCurrentMapID(),
	-- 					"coord:"..coord,

	-- 					"```",	-- discord fancy box
	-- 				}
	-- 				-- TODO: put more info in here as it will be copy-paste into Discord
	-- 			);
	-- end

	-- Retrieves stored information for a report dialog and attempts to display the dialog if possible
	function app:TriggerReportDialog(id)
		if app.popups then
			local popupID = app.popups[id];
			if popupID then
				app:ShowPopupDialogToReport(popupID.msg, popupID.text);
				return true;
			end
		end
	end
end)();

-- Register Event for startup
app:RegisterEvent("ADDON_LOADED");

-- Define Event Behaviours
app.events.ARTIFACT_UPDATE = function(...)
	local itemID = C_ArtifactUI.GetArtifactInfo();
	if itemID then
		local count = C_ArtifactUI.GetNumRelicSlots();
		if count and count > 0 then
			local myArtifactData = app.CurrentCharacter.ArtifactRelicItemLevels[itemID];
			if not myArtifactData then
				myArtifactData = {};
				app.CurrentCharacter.ArtifactRelicItemLevels[itemID] = myArtifactData;
			end
			for relicSlotIndex=1,count,1 do
				local name, relicItemID, relicType, relicLink = C_ArtifactUI.GetRelicInfo(relicSlotIndex);
				myArtifactData[relicSlotIndex] = {
					["relicType"] = relicType,
					["iLvl"] = relicLink and select(1, GetDetailedItemLevelInfo(relicLink)) or 0,
				};
			end
		end
	end
end
app.events.PLAYER_ENTERING_WORLD = function(...)
	app.InWorld = true;
	-- refresh any custom collects for this character
	app.RefreshCustomCollectibility();
	-- send a location trigger now that the character is 'in the world'
	-- DelayedCallback(app.LocationTrigger, 3); -- maybe not necessary?
end
app.AddonLoadedTriggers = {
	["AllTheThings"] = function()
		app.Startup();
	end,
	["Blizzard_AuctionHouseUI"] = function()
		app.Blizzard_AuctionHouseUILoaded = true;
		if app.Settings:GetTooltipSetting("Auto:AH") then
			app:OpenAuctionModule();
		end
	end,
	["Blizzard_AchievementUI"] = function()
		if app.IsReady then RefreshAchievementCollection(); end
	end,
};
app.events.ADDON_LOADED = function(addonName)
	local addonTrigger = app.AddonLoadedTriggers[addonName];
	if addonTrigger then addonTrigger(); end
end
app.events.CHAT_MSG_ADDON = function(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
	if prefix == "ATT" then
		--print(prefix, text, channel, sender, target, zoneChannelID, localID, name, instanceID)
		local args = { strsplit("\t", text) };
		local cmd = args[1];
		if cmd then
			local a = args[2];
			if cmd == "?" then		-- Query Request
				local response;
				if a then
					if a == "a" then
						response = "a";
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (select(app.AchievementFilter, GetAchievementInfo(b)) and 1 or 0);
						end
					--[[
					-- Exploration is not yet a thing in Retail... soon!
					elseif a == "e" then
						response = a;
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (app.CurrentCharacter.Exploration[b] and 1 or 0);
						end
					]]--
					elseif a == "f" then
						response = a;
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (app.CurrentCharacter.Factions[b] and 1 or 0);
						end
					elseif a == "fp" then
						response = a;
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (app.CurrentCharacter.FlightPaths[b] and 1 or 0);
						end
					elseif a == "p" then
						response = a;
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. C_PetJournal_GetNumCollectedInfo(b);
						end
					elseif a == "q" then
						response = "q";
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (IsQuestFlaggedCompleted(b) and 1 or 0);
						end
					elseif a == "s" then
						response = "s";
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (ATTAccountWideData.Sources[b] or 0);
						end
					elseif a == "sp" then
						response = a;
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (app.CurrentCharacter.Spells[b] and 1 or 0);
						end
					elseif a == "t" then
						response = a;
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (app.CurrentCharacter.Titles[b] and 1 or 0);
						end
					elseif a == "toy" then
						response = a;
						for i=3,#args,1 do
							local b = tonumber(args[i]);
							response = response .. "\t" .. b .. "\t" .. (ATTAccountWideData.Toys[b] and 1 or 0);
						end
					elseif a == "sync" then
						app:ReceiveSyncRequest(target, a);
					elseif a == "syncsum" then
						table.remove(args, 1);
						table.remove(args, 1);
						app:ReceiveSyncSummary(target, args);
					end
				else
					local data = app:GetWindow("Prime").data;
					response = "ATT\t" .. (data.progress or 0) .. "\t" .. (data.total or 0) .. "\t" .. app.Settings:GetShortModeString();
				end
				if response then SendResponseMessage("!\t" .. response, sender); end
			elseif cmd == "!" then	-- Query Response
				if a == "ATT" then
					print(sender .. ": " .. GetProgressColorText(tonumber(args[3]), tonumber(args[4])) .. " " .. args[5]);
				else
					local response;
					if a == "s" then
						response = " ";
						for i=3,#args,2 do
							local b = tonumber(args[i]);
							local c = tonumber(args[i + 1]);
							response = response .. b .. ": " .. GetCollectionIcon(c) .. " - ";
						end
					elseif a == "q" then
						response = " ";
						for i=3,#args,2 do
							local b = tonumber(args[i]);
							local c = tonumber(args[i + 1]);
							response = response .. b .. ": " .. GetCompletionIcon(c == 1) .. " - ";
						end
					elseif a == "a" then
						response = " ";
						for i=3,#args,2 do
							local b = tonumber(args[i]);
							local c = tonumber(args[i + 1]);
							response = response .. b .. ": " .. GetCompletionIcon(c == 1) .. " - ";
						end
					elseif a == "syncsum" then
						table.remove(args, 1);
						table.remove(args, 1);
						app:ReceiveSyncSummaryResponse(target, args);
					end
					if response then print(response .. sender); end
				end
			elseif cmd == "to" then	-- To Command
				local myName = UnitName("player");
				local name,server = strsplit("-", a);
				if myName == name and (not server or GetRealmName() == server) then
					app.events.CHAT_MSG_ADDON(prefix, strsub(text, 5 + strlen(a)), "WHISPER", sender);
				end
			elseif cmd == "chks" then	-- Total Chunks Command [sender, uid, total]
				app:AcknowledgeIncomingChunks(target, tonumber(a), tonumber(args[3]));
			elseif cmd == "chk" then	-- Incoming Chunk Command [sender, uid, index, chunk]
				app:AcknowledgeIncomingChunk(target, tonumber(a), tonumber(args[3]), args[4]);
			elseif cmd == "chksack" then	-- Chunks Acknowledge Command [sender, uid]
				app:SendChunk(target, tonumber(a), 1, 1);
			elseif cmd == "chkack" then	-- Chunk Acknowledge Command [sender, uid, index, success]
				app:SendChunk(target, tonumber(a), tonumber(args[3]) + 1, tonumber(args[4]));
			end
		end
	end
end
app.events.PLAYER_LEVEL_UP = function(newLevel)
	-- print("PLAYER_LEVEL_UP")
	app.RefreshQuestInfo();
	app.Level = newLevel;
	app.Settings:Refresh();
end
app.events.BOSS_KILL = function(id, name, ...)
	-- print("BOSS_KILL")
	app.RefreshQuestInfo();
	-- This is so that when you kill a boss, you can trigger
	-- an automatic update of your saved instance cache.
	-- (It does lag a little, but you can disable this if you want.)
	-- Waiting until the LOOT_CLOSED occurs will prevent the failed Auto Loot bug.
	-- print("BOSS_KILL", id, name, ...);
	app:UnregisterEvent("LOOT_CLOSED");
	app:RegisterEvent("LOOT_CLOSED");
end
app.events.LEARNED_SPELL_IN_TAB = function(spellID, skillInfoIndex, isGuildPerkSpell)
	-- seems to be a reliable way to notice a player has changed professions? not sure how else often it actually triggers... hopefully not too excessive...
	if skillInfoIndex == 7 then
		DelayedCallback(app.RefreshTradeSkillCache, 2);
	end
end
app.events.LOOT_CLOSED = function()
	-- Once the loot window closes after killing a boss, THEN trigger the update.
	app:UnregisterEvent("LOOT_CLOSED");
	app:UnregisterEvent("UPDATE_INSTANCE_INFO");
	app:RegisterEvent("UPDATE_INSTANCE_INFO");
	RequestRaidInfo();
end
app.events.LOOT_OPENED = function()
	-- print("LOOT_OPENED")
	-- When the player loots something, trigger a refresh of quest info (for treasures/rares/etc.)
	-- Since quest refresh is 1/sec max and not during combat, it should be fine
	app.RefreshQuestInfo();
end
app.events.UPDATE_INSTANCE_INFO = function()
	-- We got new information, now refresh the saves. :D
	app:UnregisterEvent("UPDATE_INSTANCE_INFO");
	app.RefreshSaves();
end
app.events.HEIRLOOMS_UPDATED = function(itemID, kind, ...)
	-- print("HEIRLOOMS_UPDATED",itemID,kind)
	if itemID then
		app.RefreshQuestInfo();
		UpdateSearchResults(SearchForField("itemID", itemID));
		app:PlayFanfare();
		app:TakeScreenShot("Heirlooms");
		wipe(searchCache);

		if app.Settings:GetTooltipSetting("Report:Collected") then
			local _, link = GetItemInfo(itemID);
			if link then print(format(L["ITEM_ID_ADDED_RANK"], link, itemID, (select(5, C_Heirloom.GetHeirloomInfo(itemID)) or 1))); end
		end
	end
end
-- Seems to be some sort of hidden tracking for HQTs and other sorts of things...
app.events.CRITERIA_UPDATE = function(...)
	-- print("CRITERIA_UPDATE",...)
	-- sometimes triggers many times at once but RefreshQuestInfo unhooks CRITERIA_UPDATE until quest refresh completes
	app.RefreshQuestInfo();
end
app.events.QUEST_TURNED_IN = function(questID)
	-- print("QUEST_TURNED_IN")
	app.LastQuestTurnedIn = questID;
	app.RefreshQuestInfo(questID);
end
app.events.QUEST_LOG_UPDATE = function()
	-- print("QUEST_LOG_UPDATE")
	app.RefreshQuestInfo();
end
-- app.events.QUEST_FINISHED = function()
-- 	-- print("QUEST_FINISHED")
-- 	app.RefreshQuestInfo();
-- end
app.events.QUEST_REMOVED = function(questID)
	-- app.PrintDebug("QUEST_REMOVED",questID)
	-- Make sure windows refresh incase any show the removed quest
	app:RefreshWindows();
end
app.events.QUEST_ACCEPTED = function(questID)
	-- print("QUEST_ACCEPTED",questID)
	if questID then
		local logIndex = C_QuestLog.GetLogIndexForQuestID(questID);
		local freq, title;
		if logIndex then
			local info = C_QuestLog.GetInfo(logIndex);
			if info then
				title = info.title;
				if info.frequency == 1 then
					freq = " (D)";
				elseif info.frequency == 2 then
					freq = " (W)";
				end
			end
		end
		PrintQuestInfo(questID, true, freq);
		-- Check if this quest is a nextQuest of a non-collected breadcrumb (users may care to get the breadcrumb before it becomes locked, simply due to tracking quests as well)
		if app.CollectibleQuests or app.CollectibleQuestsLocked then
			-- Run this warning check after a small delay in case addons pick up quests before the turned in quest is registered as complete
			DelayedCallback(app.CheckForBreadcrumbPrevention, 1, title, questID);
		end
		-- Make sure windows refresh incase any show the picked up quest
		app:RefreshWindows();
	end
end
app.events.PET_BATTLE_OPENING_START = function(...)
	-- check for open ATT windows
	for _,window in pairs(app.Windows) do
		if window:IsVisible() then
			if not app.PetBattleClosed then app.PetBattleClosed = {}; end
			tinsert(app.PetBattleClosed, window);
			window:Toggle();
		end
	end
end
-- this fires twice when pet battle ends
app.events.PET_BATTLE_CLOSE = function(...)
	if app.PetBattleClosed then
		for _,window in ipairs(app.PetBattleClosed) do
			-- special open for Current Instance list
			if window.Suffix == "CurrentInstance" then
				DelayedCallback(app.ToggleMiniListForCurrentZone, 1);
			else
				window:Toggle();
			end
		end
		app.PetBattleClosed = nil;
	end
end
app.events.PLAYER_DIFFICULTY_CHANGED = function()
	wipe(searchCache);
end
app.events.PLAYER_REGEN_ENABLED = function()
	app:UnregisterEvent("PLAYER_REGEN_ENABLED");
	-- print("PLAYER_REGEN_ENABLED:Begin")
	if app.__combatcallbacks and #app.__combatcallbacks > 0 then
		local i = #app.__combatcallbacks;
		for c=i,1,-1 do
			-- print("PLAYER_REGEN_ENABLED:",c)
			app.__combatcallbacks[c]();
			app.__combatcallbacks[c] = nil;
		end
	end
	-- print("PLAYER_REGEN_ENABLED:End")
end
app.events.QUEST_SESSION_JOINED = function()
	-- print("QUEST_SESSION_JOINED")
	app:UnregisterEvent("QUEST_SESSION_JOINED");
	app:RegisterEvent("QUEST_SESSION_LEFT");
	app:RegisterEvent("QUEST_SESSION_DESTROYED");
	app.IsInPartySync = true;
	app:UpdateWindows(true);
end
app.events.QUEST_SESSION_LEFT = function()
	-- print("QUEST_SESSION_LEFT")
	app.LeavePartySync();
end
app.events.QUEST_SESSION_DESTROYED = function()
	-- print("QUEST_SESSION_DESTROYED")
	app.LeavePartySync();
end
app.LeavePartySync = function()
	app:UnregisterEvent("QUEST_SESSION_LEFT");
	app:UnregisterEvent("QUEST_SESSION_DESTROYED");
	app:RegisterEvent("QUEST_SESSION_JOINED");
	app.IsInPartySync = false;
	app:UpdateWindows(true);
end
app.events.TOYS_UPDATED = function(itemID, new)
	if itemID and not ATTAccountWideData.Toys[itemID] and PlayerHasToy(itemID) then
		ATTAccountWideData.Toys[itemID] = 1;
		UpdateSearchResults(SearchForField("itemID", itemID));
		app:PlayFanfare();
		app:TakeScreenShot("Toys");
		wipe(searchCache);

		if app.Settings:GetTooltipSetting("Report:Collected") then
			local name, link = GetItemInfo(itemID);
			if link then print(format(L["ITEM_ID_ADDED"], link, itemID)); end
		end
	end
end
app.events.TRANSMOG_COLLECTION_SOURCE_ADDED = function(sourceID)
	-- print("TRANSMOG_COLLECTION_SOURCE_ADDED",sourceID)
	if sourceID then
		-- Cache the previous state. This will help keep lag under control.
		local oldState = ATTAccountWideData.Sources[sourceID] or 0;

		-- Only do work if we weren't already learned.
		-- We check here because Blizzard likes to double notify for items with timers.
		if oldState ~= 1 then
			ATTAccountWideData.Sources[sourceID] = 1;
			app.ActiveItemCollectionHelper(sourceID, oldState);
			wipe(searchCache);
			SendSocialMessage("S\t" .. sourceID .. "\t" .. oldState .. "\t1");
		end
	end
end
app.events.TRANSMOG_COLLECTION_SOURCE_REMOVED = function(sourceID)
	-- print("TRANSMOG_COLLECTION_SOURCE_REMOVED",sourceID)
	local oldState = sourceID and ATTAccountWideData.Sources[sourceID];
	if oldState then
		local unlearnedSourceIDs = { sourceID };
		local sourceInfo = C_TransmogCollection_GetSourceInfo(sourceID);
		ATTAccountWideData.Sources[sourceID] = nil;

		-- If the user is a Completionist
		if app.Settings:Get("Completionist") then
			if app.Settings:GetTooltipSetting("Report:Collected") then
				-- Oh shucks, that was nice of you to give this item to your friend.
				-- WAIT, WHAT? A VENDOR?! OH GOD NO! TODO: Warn a user when they vendor an appearance?
				local name, link = GetItemInfo(sourceInfo.itemID);
				print(format(L["ITEM_ID_REMOVED"], link or name or ("|cffff80ff|Htransmogappearance:" .. sourceID .. "|h[Source " .. sourceID .. "]|h|r"), sourceInfo.itemID));
			end
		else
			local shared = 0;
			local categoryID, appearanceID, canEnchant, texture, isCollected, itemLink = C_TransmogCollection_GetAppearanceSourceInfo(sourceID);
			if categoryID then
				for i, otherSourceID in ipairs(C_TransmogCollection_GetAllAppearanceSources(appearanceID)) do
					if ATTAccountWideData.Sources[otherSourceID] then
						local otherSourceInfo = C_TransmogCollection_GetSourceInfo(otherSourceID);
						if not otherSourceInfo.isCollected and otherSourceInfo.categoryID == categoryID then
							tinsert(unlearnedSourceIDs, otherSourceID);
							ATTAccountWideData.Sources[otherSourceID] = nil;
							shared = shared + 1;
						end
					end
				end
			end

			if app.Settings:GetTooltipSetting("Report:Collected") then
				-- Oh shucks, that was nice of you to give this item to your friend.
				-- WAIT, WHAT? A VENDOR?! OH GOD NO! TODO: Warn a user when they vendor an appearance?
				local name, link = GetItemInfo(sourceInfo.itemID);
				print(format(L[shared > 0 and "ITEM_ID_REMOVED_SHARED" or "ITEM_ID_REMOVED"], link or name or ("|cffff80ff|Htransmogappearance:" .. sourceID .. "|h[Source " .. sourceID .. "]|h|r"), sourceInfo.itemID, shared));
			end
		end

		-- Refresh the Data and Cry!
		UpdateRawIDs("s", unlearnedSourceIDs);
		Callback(app.PlayRemoveSound);
		wipe(searchCache);
		SendSocialMessage("S\t" .. sourceID .. "\t" .. oldState .. "\t0");
	end
end

-- Vignette Functionality Scope
(function()
app.CurrentVignettes = {
	["npcID"] = {},
	["objectID"] = {},
};
local C_VignetteInfo_GetVignetteInfo = C_VignetteInfo.GetVignetteInfo;
local C_VignetteInfo_GetVignettes = C_VignetteInfo.GetVignettes;
local tonumber, strsplit, ipairs, wipe = tonumber, strsplit, ipairs, wipe;

local function DelVignette(vignetteGUID)
	local vignetteInfo = C_VignetteInfo_GetVignetteInfo(vignetteGUID);
	if vignetteInfo and vignetteInfo.objectGUID then
		local type, _, _, _, _, id, _ = strsplit("-",vignetteInfo.objectGUID);
		id = id and tonumber(id);
		if id then
			local searchType = type == "Creature" and "npcID" or "objectID";
			-- app.PrintDebug("Hidden Vignette",searchType,id)
			app.CurrentVignettes[searchType][id] = nil;
		end
	end
end
local function AddVignette(vignetteGUID)
	local vignetteInfo = C_VignetteInfo_GetVignetteInfo(vignetteGUID);
	if vignetteInfo and vignetteInfo.objectGUID then
		-- app.PrintDebug("Add Vignette",vignetteInfo.objectGUID)
		local type, _, _, _, _, id, _ = strsplit("-",vignetteInfo.objectGUID);
		id = id and tonumber(id);
		if id then
			local searchType = type == "Creature" and "npcID" or "objectID";
			if vignetteInfo.isDead then
				-- app.PrintDebug("Dead Vignette",searchType,id)
				app.CurrentVignettes[searchType][id] = nil;
			else
				-- app.PrintDebug("Visible Vignette",searchType,id)
				-- app.PrintTable(vignetteInfo)
				app.CurrentVignettes[searchType][id] = true;
				-- potentially can add groups into another window?
				local vignetteGroup = app.SearchForObject(searchType,id);
				if vignetteGroup then
					-- app.PrintDebug("Found Vignette Group")
					-- force the related vignette group to be visible (this currently would only affect the Main list...)
					vignetteGroup.visible = true;
				end
			end
		end
	end
end
app.events.VIGNETTE_MINIMAP_UPDATED = function(vignetteGUID, onMinimap)
	if onMinimap then
		AddVignette(vignetteGUID);
	else
		DelVignette(vignetteGUID);
	end
	-- app.UpdateWindows(); -- maybe just a refresh?
end
app.events.VIGNETTES_UPDATED = function()
	-- clear current vignettes as they will now be re-populated
	wipe(app.CurrentVignettes["objectID"]);
	wipe(app.CurrentVignettes["npcID"]);
	local vignettes = C_VignetteInfo_GetVignettes();
	if vignettes then
		for _,vignetteGUID in ipairs(vignettes) do
			AddVignette(vignetteGUID);
		end
	end
end
end)();
