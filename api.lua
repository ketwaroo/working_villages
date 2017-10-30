working_villages.animation_frames = {
	STAND     = { x=  0, y= 79, },
	LAY       = { x=162, y=166, },
	WALK      = { x=168, y=187, },
	MINE      = { x=189, y=198, },
	WALK_MINE = { x=200, y=219, },
	SIT       = { x= 81, y=160, },
}

working_villages.registered_villagers = {}

working_villages.registered_jobs = {}

working_villages.registered_eggs = {}

working_villages.homes = {}

-- working_villages.is_job reports whether a item is a job item by the name.
function working_villages.is_job(item_name)
	if working_villages.registered_jobs[item_name] then
		return true
	end
	return false
end

-- working_villages.is_villager reports whether a name is villager's name.
function working_villages.is_villager(name)
	if working_villages.registered_villagers[name] then
		return true
	end
	return false
end

---------------------------------------------------------------------

-- working_villages.villager represents a table that contains common methods
-- for villager object.
-- this table must be contains by a metatable.__index of villager self tables.
-- minetest.register_entity set initial properties as a metatable.__index, so
-- this table's methods must be put there.
working_villages.villager = {}

-- working_villages.villager.get_inventory returns a inventory of a villager.
function working_villages.villager.get_inventory(self)
	return minetest.get_inventory {
		type = "detached",
		name = self.inventory_name,
	}
end

-- working_villages.villager.get_job_name returns a name of a villager's current job.
function working_villages.villager.get_job_name(self)
	local inv = self:get_inventory()
	return inv:get_stack("job", 1):get_name()
end

-- working_villages.villager.get_job returns a villager's current job definition.
function working_villages.villager.get_job(self)
	local name = self:get_job_name()
	if name ~= "" then
		return working_villages.registered_jobs[name]
	end
	return nil
end

-- working_villages.villager.get_nearest_player returns a player object who
-- is the nearest to the villager.
function working_villages.villager.get_nearest_player(self, range_distance)
	local player, min_distance = nil, range_distance
	local position = self.object:getpos()

	local all_objects = minetest.get_objects_inside_radius(position, range_distance)
	for _, object in pairs(all_objects) do
		if object:is_player() then
			local player_position = object:getpos()
			local distance = vector.distance(position, player_position)

			if distance < min_distance then
				min_distance = distance
				player = object
			end
		end
	end
	return player
end

-- woriking_villages.villager.get_nearest_item_by_condition returns the position of
-- an item that returns true for the condition
function working_villages.villager.get_nearest_item_by_condition(self, cond, range_distance)
	local max_distance=range_distance
	if type(range_distance) == "table" then
		max_distance=math.max(math.max(range_distance.x,range_distance.y),range_distance.z)
	end
	local item = nil
	local min_distance = max_distance
	local position = self.object:getpos()

	local all_objects = minetest.get_objects_inside_radius(position, max_distance)
	for _, object in pairs(all_objects) do
		if not object:is_player() and object:get_luaentity() and object:get_luaentity().name == "__builtin:item" then
			local found_item = ItemStack(object:get_luaentity().itemstring):to_table()
			if found_item then
				if cond(found_item) then
					local item_position = object:getpos()
					local distance = vector.distance(position, item_position)

					if distance < min_distance then
						min_distance = distance
						item = object
					end
				end
			end
		end
	end
	return item;
end

-- working_villages.villager.get_front returns a position in front of the villager.
function working_villages.villager.get_front(self)
	local direction = self:get_look_direction()
	if math.abs(direction.x) >= 0.5 then
		if direction.x > 0 then	direction.x = 1	else direction.x = -1 end
	else
		direction.x = 0
	end

	if math.abs(direction.z) >= 0.5 then
		if direction.z > 0 then	direction.z = 1	else direction.z = -1 end
	else
		direction.z = 0
	end
	
	direction.y = direction.y - 1

	return vector.add(vector.round(self.object:getpos()), direction)
end

-- working_villages.villager.get_front_node returns a node that exists in front of the villager.
function working_villages.villager.get_front_node(self)
	local front = self:get_front()
	return minetest.get_node(front)
end

-- working_villages.villager.get_back returns a position behind the villager.
function working_villages.villager.get_back(self)
	local direction = self:get_look_direction()
	if math.abs(direction.x) >= 0.5 then
		if direction.x > 0 then	direction.x = -1
		else direction.x = 1 end
	else
		direction.x = 0
	end

	if math.abs(direction.z) >= 0.5 then
		if direction.z > 0 then	direction.z = -1
		else direction.z = 1 end
	else
		direction.z = 0
	end
	
	direction.y = direction.y - 1

	return vector.add(vector.round(self.object:getpos()), direction)
end

-- working_villages.villager.get_back_node returns a node that exists behind the villager.
function working_villages.villager.get_back_node(self)
	local back = self:get_back()
	return minetest.get_node(back)
end

-- working_villages.villager.get_look_direction returns a normalized vector that is
-- the villagers's looking direction.
function working_villages.villager.get_look_direction(self)
	local yaw = self.object:getyaw()
	return vector.normalize{x = -math.sin(yaw), y = 0.0, z = math.cos(yaw)}
end

-- working_villages.villager.set_animation sets the villager's animation.
-- this method is wrapper for self.object:set_animation.
function working_villages.villager.set_animation(self, frame)
	self.object:set_animation(frame, 15, 0)
	if frame == working_villages.animation_frames.LAY then
		local dir = self:get_look_direction()
		local dirx = dir.x*0.5
		local dirz = dir.z*0.5
		self.object:set_properties({collisionbox={-0.5-dirx, -1, -0.5-dirz, 0.5+dirx, -0.5, 0.5+dirz}})
	else
		self.object:set_properties({collisionbox={-0.25, -1, -0.25, 0.25, 0.75, 0.25}})
	end
end

-- working_villages.villager.set_yaw_by_direction sets the villager's yaw
-- by a direction vector.
function working_villages.villager.set_yaw_by_direction(self, direction)
	self.object:setyaw(math.atan2(direction.z, direction.x) - math.pi / 2)
end

-- working_villages.villager.get_wield_item_stack returns the villager's wield item's stack.
function working_villages.villager.get_wield_item_stack(self)
	local inv = self:get_inventory()
	return inv:get_stack("wield_item", 1)
end

-- working_villages.villager.set_wield_item_stack sets villager's wield item stack.
function working_villages.villager.set_wield_item_stack(self, stack)
	local inv = self:get_inventory()
	inv:set_stack("wield_item", 1, stack)
end

-- working_villages.villager.add_item_to_main add item to main slot.
-- and returns leftover.
function working_villages.villager.add_item_to_main(self, stack)
	local inv = self:get_inventory()
	return inv:add_item("main", stack)
end

-- working_villages.villager.move_main_to_wield moves itemstack from main to wield.
-- if this function fails then returns false, else returns true.
function working_villages.villager.move_main_to_wield(self, pred)
	local inv = self:get_inventory()
	local main_size = inv:get_size("main")

	for i = 1, main_size do
		local stack = inv:get_stack("main", i)
		if pred(stack:get_name()) then
			local wield_stack = inv:get_stack("wield_item", 1)
			inv:set_stack("wield_item", 1, stack)
			inv:set_stack("main", i, wield_stack)
			return true
		end
	end
	return false
end

-- working_villages.villager.is_named reports the villager is still named.
function working_villages.villager.is_named(self)
	return self.nametag ~= ""
end

-- working_villages.villager.has_item_in_main reports whether the villager has item.
function working_villages.villager.has_item_in_main(self, pred)
	local inv = self:get_inventory()
	local stacks = inv:get_list("main")

	for _, stack in ipairs(stacks) do
		local itemname = stack:get_name()
		if pred(itemname) then
			return true
		end
	end
end

-- working_villages.villager.change_direction change direction to destination and velocity vector.
function working_villages.villager.change_direction(self, destination)
  local position = self.object:getpos()
  local direction = vector.subtract(destination, position)
	direction.y = 0
  local velocity = vector.multiply(vector.normalize(direction), 1.5)

  self.object:setvelocity(velocity)
	self:set_yaw_by_direction(direction)
end

-- working_villages.villager.change_direction_randomly change direction randonly.
function working_villages.villager.change_direction_randomly(self)
	local direction = {
		x = math.random(0, 5) * 2 - 5,
		y = 0,
		z = math.random(0, 5) * 2 - 5,
	}
	local velocity = vector.multiply(vector.normalize(direction), 1.5)
	self.object:setvelocity(velocity)
	self:set_yaw_by_direction(direction)
end

-- working_villages.villager.get_timer get the value of a counter.
function working_villages.villager.get_timer(self,timerId)
	return self.time_counters[timerId]
end

-- working_villages.villager.set_timer set the value of a counter.
function working_villages.villager.set_timer(self,timerId,value)
	self.time_counters[timerId]=value
end

-- working_villages.villager.clear_timers set all counters to 0.
function working_villages.villager.clear_timers(self)
	for _, counter in pairs(self.time_counters) do
		counter=0
	end
end

-- working_villages.villager.count_timer count a counter up by 1.
function working_villages.villager.count_timer(self,timerId)
	self.time_counters[timerId] = self.time_counters[timerId] + 1
end

-- working_villages.villager.count_timers count all counters up by 1.
function working_villages.villager.count_timers(self)
	for _, counter in pairs(self.time_counters) do
		counter = counter + 1
	end
end

-- working_villages.villager.timer_exceeded if a timer exceeds the limit it will be reset and true is returned
function working_villages.villager.timer_exceeded(self,timerId,limit)
	if self:get_timer(timerId)>=limit then
		self:set_timer(timerId,0)
		return true
	else
		return false
	end
end

-- working_villages.villager.update_infotext updates the infotext of the villager.
function working_villages.villager.update_infotext(self)
	local infotext = ""
	local job_name = self:get_job_name()

	if job_name ~= "" then
		if self.pause then
			infotext = infotext .. "this villager is resting\n"
		else
			infotext = infotext .. "this villager is active\n"
		end
		infotext = infotext .. "[job] : " .. job_name .. "\n"
	else
		infotext = infotext .. "this villager is inactive\n[job] : None\n"
	end
	infotext = infotext .. "[Owner] : " .. self.owner_name
	self.object:set_properties{infotext = infotext}
end

---------------------------------------------------------------------

-- working_villages.manufacturing_data represents a table that contains manufacturing data.
-- this table's keys are product names, and values are manufacturing numbers
-- that has been already manufactured.
working_villages.manufacturing_data = (function()
	local file_name = minetest.get_worldpath() .. "/working_villages_data"

	minetest.register_on_shutdown(function()
		local file = io.open(file_name, "w")
		file:write(minetest.serialize(working_villages.manufacturing_data))
		file:close()
	end)

	local file = io.open(file_name, "r")
	if file ~= nil then
		local data = file:read("*a")
		file:close()
		return minetest.deserialize(data)
	end
	return {}
end) ()

--------------------------------------------------------------------

-- register empty item entity definition.
-- this entity may be hold by villager's hands.
do
	minetest.register_craftitem("working_villages:dummy_empty_craftitem", {
		wield_image = "working_villages_dummy_empty_craftitem.png",
	})

	local function on_activate(self, staticdata)
		-- attach to the nearest villager.
		local all_objects = minetest.get_objects_inside_radius(self.object:getpos(), 0.1)
		for _, obj in ipairs(all_objects) do
			local luaentity = obj:get_luaentity()

			if working_villages.is_villager(luaentity.name) then
				self.object:set_attach(obj, "Arm_R", {x = 0.065, y = 0.50, z = -0.15}, {x = -45, y = 0, z = 0})
				self.object:set_properties{textures={"working_villages:dummy_empty_craftitem"}}
				return
			end
		end
	end

	local function on_step(self, dtime)
		local all_objects = minetest.get_objects_inside_radius(self.object:getpos(), 0.1)
		for _, obj in ipairs(all_objects) do
			local luaentity = obj:get_luaentity()

			if working_villages.is_villager(luaentity.name) then
				local stack = luaentity:get_wield_item_stack()

				if stack:get_name() ~= self.itemname then
					if stack:is_empty() then
						self.itemname = ""
						self.object:set_properties{textures={"working_villages:dummy_empty_craftitem"}}
					else
						self.itemname = stack:get_name()
						self.object:set_properties{textures={self.itemname}}
					end
				end
				return
			end
		end
		-- if cannot find villager, delete empty item.
		self.object:remove()
		return
	end

	minetest.register_entity("working_villages:dummy_item", {
		hp_max		    = 1,
		visual		    = "wielditem",
		visual_size	  = {x = 0.025, y = 0.025},
		collisionbox	= {0, 0, 0, 0, 0, 0},
		physical	    = false,
		textures	    = {"air"},
		on_activate	  = on_activate,
		on_step       = on_step,
		itemname      = "",
	})
end

---------------------------------------------------------------------

-- working_villages.register_job registers a definition of a new job.
function working_villages.register_job(job_name, def)
	working_villages.registered_jobs[job_name] = def

	minetest.register_tool(job_name, {
		stack_max       = 1,
		description     = def.description,
		inventory_image = def.inventory_image,
	})
end

-- working_villages.register_egg registers a definition of a new egg.
function working_villages.register_egg(egg_name, def)
	working_villages.registered_eggs[egg_name] = def

	minetest.register_tool(egg_name, {
		description     = def.description,
		inventory_image = def.inventory_image,
		stack_max       = 1,

		on_use = function(itemstack, user, pointed_thing)
			if pointed_thing.above ~= nil and def.product_name ~= nil then
				-- set villager's direction.
				local new_villager = minetest.add_entity(pointed_thing.above, def.product_name)
				new_villager:get_luaentity():set_yaw_by_direction(
					vector.subtract(user:getpos(), new_villager:getpos())
				)
				new_villager:get_luaentity().owner_name = user:get_player_name()
				new_villager:get_luaentity():update_infotext()
				new_villager:setvelocity{x =0, y = 5, z = 0}

				itemstack:take_item()
				return itemstack
			end
			return nil
		end,
	})
end

--receive fields when villager was rightclicked
minetest.register_on_player_receive_fields(
	function(player, formname, fields)
		if string.find(formname,"villager:gui_") then
			local inv_name = string.sub(formname, string.len("villager:gui_")+1)
			local sender_name = player:get_player_name();
			if fields.home_pos == nil then
				return
			end
			local coords = {}
			coords.x, coords.y, coords.z = string.match(fields.home_pos, "^([%d.-]+)[, ] *([%d.-]+)[, ] *([%d.-]+)$")
			coords.x=tonumber(coords.x)
			coords.y=tonumber(coords.y)
			coords.z=tonumber(coords.z)
			if not (coords.x and coords.y and coords.z) then
				-- fail on illegal input of coordinates
				minetest.chat_send_player(sender_name, 'You failed to provide correct coordinates for the bed position. Please enter the X, Y, and Z coordinates of the desired destination in a comma seperated list. Example: The input "10,20,30" means the destination at the coordinates X=10, Y=20 and Z=30.')
				return
			end
			if(coords.x>30927 or coords.x<-30912 or coords.y>30927 or coords.y<-30912 or coords.z>30927 or coords.z<-30912) then
				minetest.chat_send_player(sender_name, 'The coordinates of your bed position do not exist in our coordinate system. Correct coordinates range from -30912 to 30927 in all axes.')
				return
			end
			if minetest.get_node(coords).name ~= "working_villages:home_marker" then
				minetest.chat_send_player(sender_name, 'No home marker could be found at the entered position.')
				return
			end
			if not minetest.get_meta(coords):get_string("bed") then
				minetest.chat_send_player(sender_name, 'Home marker not configured, please right-click the home marker to configure it.')
				return
			end
			working_villages.homes[inv_name]=coords
		end
	end
)

-- working_villages.register_villager registers a definition of a new villager.
function working_villages.register_villager(product_name, def)
	working_villages.registered_villagers[product_name] = def

	-- initialize manufacturing number of a new villager.
	if working_villages.manufacturing_data[product_name] == nil then
		working_villages.manufacturing_data[product_name] = 0
	end

	-- create_inventory creates a new inventory, and returns it.
	local function create_inventory(self)
		self.inventory_name = self.product_name .. "_" .. tostring(self.manufacturing_number)
		local inventory = minetest.create_detached_inventory(self.inventory_name, {
			on_put = function(inv, listname, index, stack, player)
				if listname == "job" then
					local job_name = stack:get_name()
					local job = working_villages.registered_jobs[job_name]
					job.on_start(self)

					self:update_infotext()
				end
			end,

			allow_put = function(inv, listname, index, stack, player)
				-- only jobs can put to a job inventory.
				if listname == "main" then
					return stack:get_count()
				elseif listname == "job" and working_villages.is_job(stack:get_name()) then
					return stack:get_count()
				elseif listname == "wield_item" then
					return 0
				end
				return 0
			end,

			on_take = function(inv, listname, index, stack, player)
				if listname == "job" then
					local job_name = stack:get_name()
					local job = working_villages.registered_jobs[job_name]
					job.on_stop(self)

					self:update_infotext()
				end
			end,

			allow_take = function(inv, listname, index, stack, player)
				if listname == "wield_item" then
					return 0
				end
				return stack:get_count()
			end,

			on_move = function(inv, from_list, from_index, to_list, to_index, count, player)
				if to_list == "job" or from_list == "job" then
					local job_name = inv:get_stack(to_list, to_index):get_name()
					local job = working_villages.registered_jobs[job_name]

					if to_list == "job" then
						job.on_start(self)
					elseif from_list == "job" then
						job.on_stop(self)
					end

					self:update_infotext()
				end
			end,

			allow_move = function(inv, from_list, from_index, to_list, to_index, count, player)
				if to_list == "wield_item" then
					return 0
				end

				if to_list == "main" then
					return count
				elseif to_list == "job" and working_villages.is_job(inv:get_stack(from_list, from_index):get_name()) then
					return count
				end

				return 0
			end,
		})

		inventory:set_size("main", 16)
		inventory:set_size("job",  1)
		inventory:set_size("wield_item", 1)

		return inventory
	end

	-- create_formspec_string returns a string that represents a formspec definition.
	local function create_formspec_string(self)
		if not working_villages.homes[self.inventory_name] then
			working_villages.homes[self.inventory_name] = {x=0,y=0,z=0}
		end
		local home_pos = tostring(working_villages.homes[self.inventory_name].x) .. "," .. tostring(working_villages.homes[self.inventory_name].y) .. "," .. tostring(working_villages.homes[self.inventory_name].z)
		return "size[8,9]"
			.. default.gui_bg
			.. default.gui_bg_img
 			.. default.gui_slots
			.. "list[detached:"..self.inventory_name..";main;0,0;4,4;]"
			.. "label[4.5,1;job]"
			.. "list[detached:"..self.inventory_name..";job;4.5,1.5;1,1;]"
			.. "list[current_player;main;0,5;8,1;]"
			.. "list[current_player;main;0,6.2;8,3;8]"
			.. "label[5.5,1;wield]"
			.. "list[detached:"..self.inventory_name..";wield_item;5.5,1.5;1,1;]"
			.. "field[4.5,3;2.5,1;home_pos;home position;" .. home_pos .. "]"
			.. "button_exit[7,3;1,1;ok;set]"
	end

	-- on_activate is a callback function that is called when the object is created or recreated.
	local function on_activate(self, staticdata)
		-- parse the staticdata, and compose a inventory.
		if staticdata == "" then
			self.product_name = product_name
			self.manufacturing_number = working_villages.manufacturing_data[product_name]
			working_villages.manufacturing_data[product_name] = working_villages.manufacturing_data[product_name] + 1
			create_inventory(self)

			-- attach dummy item to new villager.
			minetest.add_entity(self.object:getpos(), "working_villages:dummy_item")
		else
			-- if static data is not empty string, this object has beed already created.
			local data = minetest.deserialize(staticdata)

			self.product_name = data["product_name"]
			self.manufacturing_number = data["manufacturing_number"]
			self.nametag = data["nametag"]
			self.owner_name = data["owner_name"]

			local inventory = create_inventory(self)
			working_villages.homes[self.inventory_name] = data["home_position"]
			for list_name, list in pairs(data["inventory"]) do
				inventory:set_list(list_name, list)
			end
		end

		self:update_infotext()

		self.object:set_nametag_attributes{
			text = self.nametag
		}

		local job = self:get_job()
		if job ~= nil then
			job.on_start(self)
		else
			self.object:setvelocity{x = 0, y = 0, z = 0}
			self.object:setacceleration{x = 0, y = -10, z = 0}
		end
	end

	-- get_staticdata is a callback function that is called when the object is destroyed.
	local function get_staticdata(self)
		local inventory = self:get_inventory()
		local data = {
			["product_name"] = self.product_name,
			["manufacturing_number"] = self.manufacturing_number,
			["nametag"] = self.nametag,
			["owner_name"] = self.owner_name,
			["inventory"] = {},
			["home_position"] = working_villages.homes[self.inventory_name],
		}

		-- set lists.
		for list_name, list in pairs(inventory:get_lists()) do
			data["inventory"][list_name] = {}

			for i, item in ipairs(list) do
				data["inventory"][list_name][i] = item:to_string()
			end
		end

		return minetest.serialize(data)
	end

	-- working_villages.villager.pickup_item pickup items placed and put it to main slot.
	local function pickup_item(self)
		local pos = self.object:getpos()
		local radius = 1.0
		local all_objects = minetest.get_objects_inside_radius(pos, radius)

		for _, obj in ipairs(all_objects) do
			if not obj:is_player() and obj:get_luaentity() and obj:get_luaentity().itemstring then
				local itemstring = obj:get_luaentity().itemstring
				local stack = ItemStack(itemstring)
				if stack and stack:to_table() then
					local name = stack:to_table().name

					if minetest.registered_items[name] ~= nil then
						local inv = self:get_inventory()
						local leftover = inv:add_item("main", stack)

						minetest.add_item(obj:getpos(), leftover)
						obj:get_luaentity().itemstring = ""
						obj:remove()
					end
				end
			end
		end
	end

	-- on_step is a callback function that is called every delta times.
	local function on_step(self, dtime)
		-- if owner didn't login, the villager does nothing.
		if not minetest.get_player_by_name(self.owner_name) then
			return
		end

		-- pickup surrounding item.
		pickup_item(self)

		-- do job method.
		local job = self:get_job()
		if (not self.pause) and job then
			job.on_step(self, dtime)
		end
	end

	-- on_rightclick is a callback function that is called when a player right-click them.
	local function on_rightclick(self, clicker)
		minetest.show_formspec(
			clicker:get_player_name(),
			"villager:gui_"..self.inventory_name,
			create_formspec_string(self)
		)
	end

	-- on_punch is a callback function that is called when a player punch then.
	local function on_punch(self, puncher, time_from_last_punch, tool_capabilities, dir)
		local job = self:get_job()
		if self.pause == true then
			self.pause = false
			if job then
				job.on_resume(self)
			end
		else
			self.pause = true
			if job then
				job.on_pause(self)
			end
		end

		self:update_infotext()
	end

	-- register a definition of a new villager.
	minetest.register_entity(product_name, {
		-- basic initial properties
		hp_max                       = def.hp_max,
		weight                       = def.weight,
		mesh                         = def.mesh,
		textures                     = def.textures,

		physical                     = true,
		visual                       = "mesh",
		visual_size                  = {x = 1, y = 1},
		collisionbox                 = {-0.25, -1, -0.25, 0.25, 0.75, 0.25},
		is_visible                   = true,
		makes_footstep_sound         = true,
		infotext                     = "",
		nametag                      = "",

		-- extra initial properties
		pause                        = false,
		product_name                 = "",
		manufacturing_number         = -1,
		owner_name                   = "",
		time_counters                = {},

		-- callback methods.
		on_activate                  = on_activate,
		on_step                      = on_step,
		on_rightclick                = on_rightclick,
		on_punch                     = on_punch,
		get_staticdata               = get_staticdata,

		-- extra methods.
		get_inventory                = working_villages.villager.get_inventory,
		get_job                      = working_villages.villager.get_job,
		get_job_name                 = working_villages.villager.get_job_name,
		get_nearest_player           = working_villages.villager.get_nearest_player,
		get_nearest_item_by_condition= working_villages.villager.get_nearest_item_by_condition,
		get_front                    = working_villages.villager.get_front,
		get_front_node               = working_villages.villager.get_front_node,
		get_back                     = working_villages.villager.get_back,
		get_back_node                = working_villages.villager.get_back_node,
		get_look_direction           = working_villages.villager.get_look_direction,
		set_animation                = working_villages.villager.set_animation,
		set_yaw_by_direction         = working_villages.villager.set_yaw_by_direction,
		get_wield_item_stack         = working_villages.villager.get_wield_item_stack,
		set_wield_item_stack         = working_villages.villager.set_wield_item_stack,
		add_item_to_main             = working_villages.villager.add_item_to_main,
		move_main_to_wield           = working_villages.villager.move_main_to_wield,
		is_named                     = working_villages.villager.is_named,
		has_item_in_main             = working_villages.villager.has_item_in_main,
		change_direction             = working_villages.villager.change_direction,
		change_direction_randomly    = working_villages.villager.change_direction_randomly,
		get_timer                    = working_villages.villager.get_timer,
		set_timer                    = working_villages.villager.set_timer,
		clear_timers                 = working_villages.villager.clear_timers,
		count_timer                  = working_villages.villager.count_timer,
		count_timers                 = working_villages.villager.count_timers,
		timer_exceeded               = working_villages.villager.timer_exceeded,
		update_infotext              = working_villages.villager.update_infotext,
	})

	-- register villager egg.
	working_villages.register_egg(product_name .. "_egg", {
		description     = product_name .. " egg",
		inventory_image = def.egg_image,
		product_name    = product_name,
	})
end
