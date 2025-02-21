AddCSLuaFile()

ENT.Base = "base_entity"
ENT.Type = "brush"

ENT.mins = 0
ENT.maxs = 0
ENT.target_side = nil -- Цель (противоположная сторона)
ENT.target_offset = nil -- Смещение цели

local NoMapBordersOn = GetConVar("NoMapBorders_enabled")
local list_mode = GetConVar("nmb_list_mode")
local EasyMode = GetConVar("noborders_EasyMode")

local source_bounds = 2^14 - 64
local blacklist = {
	["prop_vehicle_jeep"] = false,
	["prop_vehicle_airboat"] = false,
	["lvs_wheeldrive_wheel"] = false,
	["gmod_sent_vehicle_fphysics_wheel"] = false,
	["car"] = false,
	["tank"] = false
}

local function FindMainEntity(ent)
    local entity_lookup = {}
    local max_count = 0
    local main_ent = ent

    local function recursive_find(current_ent)
        if entity_lookup[current_ent] then return end
        entity_lookup[current_ent] = true

        if current_ent:IsValid() then
            local constraints = constraint.GetTable(current_ent)
            for _, v in pairs(constraints) do
                if v.Ent1 then recursive_find(v.Ent1) end
                if v.Ent2 then recursive_find(v.Ent2) end
            end

            local count = table.Count(constraint.GetTable(current_ent))
            if count > max_count then
                main_ent = current_ent
                max_count = count
            end
        end
    end

    recursive_find(ent)
    return main_ent
end

local function get_all_constrained(main_ent)
    local entity_lookup = {}
    local entity_table = {}

    local function recursive_find(ent)
        if entity_lookup[ent] then return end
        entity_lookup[ent] = true

        if ent:IsValid() then
            entity_table[#entity_table + 1] = ent
            local constraints = constraint.GetTable(ent)
            for _, v in pairs(constraints) do
                if v.Ent1 then recursive_find(v.Ent1) end
                if v.Ent2 then recursive_find(v.Ent2) end
            end
        end
    end

    recursive_find(main_ent)
    return entity_table
end

local function calculate_teleport_direction(oldpos, newpos, side)
    if side == "front" or side == "back" then
        return Vector(newpos.x, oldpos.y, oldpos.z)
    elseif side == "left" or side == "right" then
        return Vector(oldpos.x, newpos.y, oldpos.z)
    end
end

local function teleport_entity(ent, target_pos, target_side)
    if not IsValid(ent) then return end
	if not NoMapBordersOn:GetBool() then return end

    local class = ent:GetClass()
    PrintTable(NMB_black_list)
    local is_blacklisted = NMB_black_list[class] ~= nil
    local is_included = not is_blacklisted

    if list_mode:GetInt() == 0 then -- Exclude mode (чёрный список)
        if is_blacklisted then return end
    else -- Include mode (белый список)
        if not is_included then return end
    end
    -- Check if entity has "last_teleported_tms" variable
    if ent.last_teleported_tms == nil then ent.last_teleported_tms = 0 end
    if IsValid(ent) and NMB_black_list[ent:GetClass()] ~= true and ent.last_teleported_tms + 1 < CurTime() then
		if ent:GetParent():IsValid() then return end -- Не телепортируем дочерние сущности (спасибо InfMap Base)
		if ent:IsPlayer() and ent:InVehicle() then return end
		ent:ForcePlayerDrop()
		ent:ForcePlayerDrop()
		local vehtype = nil
		local sent = FindMainEntity(ent)

		if ent.GetVehicleType then
			vehtype = sent:GetVehicleType()
		end
		print(vehtype)

		if ent:IsVehicle() and (ent:GetClass() == "prop_vehicle_jeep" or ent:GetClass() == "prop_vehicle_airboat") then

			-- Перемещаем колёса
			for i = 0, ent:GetWheelCount() do
				local wheel = ent:GetWheel( i )
				if IsValid(wheel) then
					print("wheel is.."..i)
					local wpos = wheel:GetPos()
					local offset = wheel:GetPos() - ent:GetPos()
					--wheel:SetVelocity(Vector(0,0,0))
					--wheel:AddAngleVelocity(-wheel:GetAngleVelocity())
					--wheel:SetPos(Vector(pos.x + 750, wpos.y, wpos.z + 1) + offset)
					--wheel:SetVelocity(Vector(0,0,0))
					--wheel:AddAngleVelocity(-wheel:GetAngleVelocity())
				end
			end

			-- Перемещаем сам автомобиль (транспорт)
			local oldpos = ent:GetPos()
			local oldang = ent:GetAngles()
			local oldvel = ent:GetVelocity()
			local phys = ent:GetPhysicsObject()
			local oldangvel = Vector(0,0,0)

			if IsValid(phys) then
				oldangvel = phys:GetAngleVelocity()
			end

			// clamp position inside source bounds incase contraption is massive
			// helps things like simphys cars not die
			oldpos[1] = math.Clamp(oldpos[1], -source_bounds, source_bounds)
			oldpos[2] = math.Clamp(oldpos[2], -source_bounds, source_bounds)
			oldpos[3] = math.Clamp(oldpos[3], -source_bounds, source_bounds)

			PrintTable( ent:GetChildren() )
            local finalPos = calculate_teleport_direction(oldpos, target_pos, target_side)
			ent:SetPos(finalPos)

			ent:Spawn()
			ent:StartEngine(true)
			ent:EnableEngine(true)
			phys = ent:GetPhysicsObject()

			if phys:IsValid() then 
				if oldang then phys:SetAngles(oldang) end
				--phys:Wake()
				local finalPos = calculate_teleport_direction(oldpos, target_pos, target_side)
				phys:SetPos(finalPos)
				phys:SetVelocity(oldvel)
				ent:SetVelocity(oldvel)
				phys:AddAngleVelocity(-phys:GetAngleVelocity())
				phys:AddAngleVelocity(oldangvel)
			else
				if oldang then ent:SetAngles(oldang) end
				ent:SetVelocity(oldvel)
			end

			if ent:GetClass() == "prop_vehicle_airboat" and ent:GetDriver() ~= NULL then
				local ply = ent:GetDriver()
				if IsValid(ply) then
					ply:ExitVehicle(ent)
					ply:EnterVehicle(ent)
				end
			end

			-- Закончили, ведь это транспорт
			return
		
		elseif vehtype == "car" or vehtype == "tank" then
			local mEnt = FindMainEntity(ent)
			local mphys = mEnt:GetPhysicsObject()
			if IsValid(mphys) then
				mphys:EnableMotion(false)
			end
			local mEntPos = mEnt:GetPos()
			local mAng = mEnt:GetAngles()
			print(mEnt)

			-- Получаем информацию о всех соединениях сущности, замораживаем, перемещаем:
			for k, lent in ipairs(get_all_constrained(ent)) do
				if lent == mEnt then continue end
				if lent:GetParent():IsValid() then return end -- Не телепортируем дочерние сущности (спасибо InfMap Base)

				local oldpos = lent:GetPos()
				local oldang = lent:GetAngles()
				local oldvel = lent:GetVelocity()
				local phys = lent:GetPhysicsObject()
				local oldangvel = Vector(0,0,0)
				local offset = lent:GetPos() - mEntPos
				local locpos = mEnt:WorldToLocal(lent:GetPos())
				print("LOCPOS ----")
				print(locpos)
				print("offset "..tostring(offset))

				if IsValid(phys) then
					oldangvel = phys:GetAngleVelocity()
				end

				// clamp position inside source bounds incase contraption is massive
				// helps things like simphys cars not die
				oldpos[1] = math.Clamp(oldpos[1], -source_bounds, source_bounds)
				oldpos[2] = math.Clamp(oldpos[2], -source_bounds, source_bounds)
				oldpos[3] = math.Clamp(oldpos[3], -source_bounds, source_bounds)

				-- Заморозка

				if IsValid(phys) then
					phys:EnableMotion(false)
				end

				-- Перемещаем сущности:
				print("Перемещение")
				print(lent)
				timer.Simple(0, function()
					if IsValid(lent) and lent:GetClass() == "prop_physics" or lent:GetClass() == "lvs_wheeldrive_steerhandler" then
						local finalPos = calculate_teleport_direction(oldpos, target_pos, target_side)
						lent:SetPos(finalPos)
					elseif IsValid(lent) then
                        local finalPos = calculate_teleport_direction(oldpos, target_pos, target_side)
			            lent:SetPos(finalPos)
						--lent:SetPos(LocalToWorld(locpos, oldang, Vector(pos.x + 750, mEntPos.y, mEntPos.z), mAng))
						--lent:SetPos(LocalToWorld(locpos, Angle(0,0,0), Vector(pos.x + 750, oldpos.y, oldpos.z), Angle(0,0,0)))
					end
				end)
				print("---- END -----")
				timer.Simple(0, function()
					if phys:IsValid() then 
						phys:EnableMotion(true)
						if oldang then phys:SetAngles(oldang) end
						phys:SetVelocity(oldvel)
						phys:AddAngleVelocity(-phys:GetAngleVelocity())
						phys:AddAngleVelocity(oldangvel)
					else
						if oldang then ent:SetAngles(oldang) end
						lent:SetVelocity(oldvel)
					end
				end)
			end


			local oldpos = mEnt:GetPos()
			local oldang = mEnt:GetAngles()
			local oldvel = mEnt:GetVelocity()
			local phys = mEnt:GetPhysicsObject()
			local oldangvel = Vector(0,0,0)

			if IsValid(phys) then
				phys:EnableMotion(false)
				oldangvel = phys:GetAngleVelocity()
			end

			// clamp position inside source bounds incase contraption is massive
			// helps things like simphys cars not die
			oldpos[1] = math.Clamp(oldpos[1], -source_bounds, source_bounds)
			oldpos[2] = math.Clamp(oldpos[2], -source_bounds, source_bounds)
			oldpos[3] = math.Clamp(oldpos[3], -source_bounds, source_bounds)

			-- Перемещаем сущности:
			timer.Simple(0, function()
				local finalPos = calculate_teleport_direction(oldpos, target_pos, target_side)
				mEnt:SetPos(finalPos)
			end)

			timer.Simple(0, function() 
				if phys:IsValid() then 
					phys:EnableMotion(true)
					if oldang then phys:SetAngles(oldang) end
					phys:SetVelocity(oldvel)
					phys:AddAngleVelocity(-phys:GetAngleVelocity())
					phys:AddAngleVelocity(oldangvel)
				else
					if oldang then mEnt:SetAngles(oldang) end
					mEnt:SetVelocity(oldvel)
				end
			end)

			return

		end
		
		-- Получаем информацию о всех соединениях сущности (если самолёт или что-то такое):
		if blacklist[ent:GetClass()] ~= false and blacklist[vehtype] ~= false then
		print("?--?-?-?-?")
		for k, lent in ipairs(get_all_constrained(ent)) do
			if lent == ent then continue end
			if lent:GetParent():IsValid() then return end -- Не телепортируем дочерние сущности (спасибо InfMap Base)

			local oldpos = lent:GetPos()
			local oldang = lent:GetAngles()
			local oldvel = lent:GetVelocity()
			local phys = lent:GetPhysicsObject()
			local oldangvel = Vector(0,0,0)
			local offset = lent:GetPos() - ent:GetPos()

			if IsValid(phys) then
				oldangvel = phys:GetAngleVelocity()
			end

			// clamp position inside source bounds incase contraption is massive
			// helps things like simphys cars not die
			oldpos[1] = math.Clamp(oldpos[1], -source_bounds, source_bounds)
			oldpos[2] = math.Clamp(oldpos[2], -source_bounds, source_bounds)
			oldpos[3] = math.Clamp(oldpos[3], -source_bounds, source_bounds)

			-- Перемещаем сущности:
			if IsValid(lent) and lent:GetClass() == "prop_physics" or lent:GetClass() == "lvs_wheeldrive_steerhandler" then
				--lent:SetPos(Vector(pos.x + 750, oldpos.y, oldpos.z))
                local finalPos = calculate_teleport_direction(oldpos, target_pos, target_side)
			    lent:SetPos(finalPos)
			elseif IsValid(lent) then
				--lent:SetPos(Vector(pos.x + 750, oldpos.y, oldpos.z) + offset)
                local finalPos = calculate_teleport_direction(oldpos, target_pos, target_side)
			    lent:SetPos(finalPos)
			end

			if phys:IsValid() then 
				if oldang then phys:SetAngles(oldang) end
				phys:SetVelocity(oldvel)
				phys:AddAngleVelocity(-phys:GetAngleVelocity())
				phys:AddAngleVelocity(oldangvel)
			else
				if oldang then ent:SetAngles(oldang) end
				lent:SetVelocity(oldvel)
			end
		end


		local oldpos = ent:GetPos()
			local oldang = ent:GetAngles()
			local oldvel = ent:GetVelocity()
			local phys = ent:GetPhysicsObject()
			local oldangvel = Vector(0,0,0)

			if IsValid(phys) then
				oldangvel = phys:GetAngleVelocity()
			end

			// clamp position inside source bounds incase contraption is massive
			// helps things like simphys cars not die
			oldpos[1] = math.Clamp(oldpos[1], -source_bounds, source_bounds)
			oldpos[2] = math.Clamp(oldpos[2], -source_bounds, source_bounds)
			oldpos[3] = math.Clamp(oldpos[3], -source_bounds, source_bounds)

			-- Перемещаем сущности:
			--ent:SetPos(Vector(pos.x + 750, oldpos.y, oldpos.z) )
            local finalPos = calculate_teleport_direction(oldpos, target_pos, target_side)
			ent:SetPos(finalPos)

			if phys:IsValid() then 
				if oldang then phys:SetAngles(oldang) end
				phys:SetVelocity(oldvel)
				phys:AddAngleVelocity(-phys:GetAngleVelocity())
				phys:AddAngleVelocity(oldangvel)
			else
				if oldang then ent:SetAngles(oldang) end
				ent:SetVelocity(oldvel)
			end

		print(ent:GetAngles())
		print(ent:GetPos())
		print(ent:GetVelocity())
		--print(phys:GetAngleVelocity())
	    end
    ent.last_teleported_tms = CurTime()
    end

    -- if ent:GetParent():IsValid() then return end -- Не телепортируем дочерние сущности
    -- if ent:IsPlayer() and ent:InVehicle() then return end

    -- ent:ForcePlayerDrop() -- Force player drop before teleporting

    -- local main_ent = FindMainEntity(ent) -- Используем оптимизированную функцию

    -- local oldpos = main_ent:GetPos()
    -- local oldang = main_ent:GetAngles()
    -- local oldvel = main_ent:GetVelocity()
    -- local phys = main_ent:GetPhysicsObject()
    -- local oldangvel = phys and phys:GetAngleVelocity() or Vector(0, 0, 0)

    -- oldpos[1] = math.Clamp(oldpos[1], -source_bounds, source_bounds)
    -- oldpos[2] = math.Clamp(oldpos[2], -source_bounds, source_bounds)
    -- oldpos[3] = math.Clamp(oldpos[3], -source_bounds, source_bounds)

    -- local target_pos = Vector(target_pos.x, target_pos.y, oldpos.z)
    -- main_ent:SetPos(target_pos)
    -- main_ent:SetAngles(oldang) -- Восстанавливаем угол
    -- main_ent:SetVelocity(oldvel) -- Восстанавливаем скорость

    -- if IsValid(phys) then
    --     phys:SetPos(target_pos)
    --     phys:SetAngles(oldang)
    --     phys:SetVelocity(oldvel)
    --     phys:SetAngleVelocity(oldangvel)
    -- end

    -- if main_ent:IsVehicle() and main_ent:GetClass() == "prop_vehicle_airboat" and main_ent:GetDriver() ~= NULL then
    --     local ply = main_ent:GetDriver()
    --     if IsValid(ply) then
    --         ply:ExitVehicle(main_ent)
    --         ply:EnterVehicle(main_ent)
    --     end
    -- end

    -- -- Обработка связанных сущностей (оптимизировано)
    -- for _, linked_ent in ipairs(get_all_constrained(main_ent)) do
    --     if linked_ent == main_ent then continue end
    --     if linked_ent:GetParent():IsValid() then return end

    --     local offset = linked_ent:GetPos() - oldpos -- Смещение относительно родительской сущности
    --     local linked_phys = linked_ent:GetPhysicsObject()

    --     linked_ent:SetPos(target_pos + offset) -- Телепортируем связанные сущности со смещением
    --     linked_ent:SetAngles(linked_ent:GetAngles()) -- Восстанавливаем угол
    --     linked_ent:SetVelocity(linked_ent:GetVelocity()) -- Восстанавливаем скорость

    --     if IsValid(linked_phys) then
    --         linked_phys:SetPos(target_pos + offset)
    --         linked_phys:SetAngles(linked_ent:GetAngles())
    --         linked_phys:SetVelocity(linked_ent:GetVelocity())
    --     end
    -- end
end

function ENT:Initialize()
    if SERVER then
        self:SetSolid(SOLID_BBOX)
        self:SetCollisionBoundsWS(self.Mins, self.Maxs)
        self.target_side = self:GetNWString("target_side", nil) -- Получаем цель при создании
    end
end

function ENT:StartTouch(ent)
    if SERVER and self.target_side then
        print(ent:GetClass())
        local target_border = ents.FindByName("mapborder_trigger_" .. self.target_side)[1]
        print(target_border)
        print(self.target_side)
        if IsValid(target_border) then
            local mins, maxs = target_border:GetCollisionBounds()
            mins = target_border:LocalToWorld(mins)
            maxs = target_border:LocalToWorld(maxs)
            local target_pos = (mins + maxs) / 2 + self.target_offset + Vector(0,0,2) -- Смещение телепорта
			teleport_entity(ent, target_pos, self.target_side)
        end
    end
end