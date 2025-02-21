AddCSLuaFile()

ENT.Type					= "anim"
ENT.Base					= "base_gmodentity"
ENT.Category				= "Half-life 2"

ENT.PrintName				= ""
ENT.Author					= ""
ENT.Contact					= ""

ENT.Spawnable				= false
ENT.AdminSpawnable			= false

--ENT.AutomaticFrameAdvance	= true

function ENT:Initialize(model)
	if SERVER then
	--self:SetNWString( "MapName", self.MapName )
	--self:SetModel(model)
	self:SetSolid(SOLID_BBOX)
	self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
	print(self.Mins)
	print(self.Maxs)
	self:SetCollisionBoundsWS(self.Mins, self.Maxs)
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:EnableMotion(false)
		phys:EnableGravity(false)
		phys:EnableDrag(false)
	end
	--self.CMins = SetNWVector( "BMins", self.Mins )
	--self.CMaxs = SetNWVector( "BMaxs", self.Maxs )
	end
end

function ENT:ToggleSwitch()
	
end

function ENT:OnRemove()
	if SERVER and false then
		for k, v in ipairs( ents.FindByClass( "trigger_changelevel" ) ) do
			local mins, maxs = v:GetCollisionBounds()
			local pos = Vector((mins + maxs) / 2)
			local button = ents.Create( "transfix_trigger_changelevel" )
			button.Mins = mins
			button.Maxs = maxs
			local ang = v:GetAngles()
			local trigger_data = file.Read("mapskeyvalues/"..game.GetMap()..".txt")
			trigger_data = util.JSONToTable(trigger_data)
			button.MapName = trigger_data[v:MapCreationID()].value
			button:Spawn()
			button:SetTriggerOn()
			local render_trigger = ents.Create("changemap_showtrigger")
			render_trigger:SetModel("models/props_junk/wood_crate001a.mdl")
			minsW = v:LocalToWorld(mins)
			maxsW = v:LocalToWorld(maxs)
			render_trigger:SetPos(pos)
			render_trigger:SetCollisionBoundsWS(mins, maxs)
			render_trigger:SetAngles(ang)
			render_trigger.MapName = trigger_data[v:MapCreationID()].value
			render_trigger.Mins = mins
			render_trigger.Maxs = maxs
			render_trigger:Spawn()
			render_trigger:SetNWString( "MapName", trigger_data[v:MapCreationID()].value )
			render_trigger:SetNWVector( "BMins", mins )
			render_trigger:SetNWVector( "BMaxs", maxs )
		end
	end 
end

function ENT:StartTouch( ent )
end

function ENT:EndTouch( ent )
end

function ENT:OnRemove()
	
end

function ENT:Think()
	if SERVER then
		--self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
		--self:SetNWString( "MapName", self.MapName )
		--self:SetNWVector( "BMins", self.Mins )
		--self:SetNWVector( "BMaxs", self.Maxs )
	end
end

function ENT:Touch( ent )
	--No need for this function.
end

function ENT:Use( activator, caller )
	--Garry's Mod has a Button STool.
end

function ENT:Draw()
	
	local mins, maxs = self:GetCollisionBounds()
	print(mins)
	--mins = v:LocalToWorld(mins)
	--maxs = v:LocalToWorld(maxs)
	local ang = self:GetAngles()
	--mins = self:LocalToWorld(self.Mins)
	--maxs = self:LocalToWorld(self.Maxs)
	cam.IgnoreZ( true )
	self:Draw()
	render.DrawBox( self:GetPos(), ang, mins, maxs, Color(207, 94, 152, 30) ) -- draws the box 
	render.DrawWireframeBox( self:GetPos(), ang, mins, maxs, Color(207, 94, 152, 10), true ) -- draws the box
	cam.IgnoreZ( false )
	--render.DrawQuad( mins, Vector(mins.x, maxs.y, mins.z), maxs, Vector(maxs.x, mins.y, maxs.z), Color(207, 94, 152, 250) )
	--print(ang)
	--print(LocalPlayer():GetAngles())
	local direction = (self:GetPos() - LocalPlayer():GetPos()):GetNormalized()
    local angles = direction:Angle()
	--local diff = self:GetPos() - LocalPlayer():GetShootPos()
	--print(LocalPlayer():GetAimVector():Dot(diff) / diff:Length())
	--[[cam.Start3D2D( self:GetPos(), ang - Angle(180,0,90), 0.1 )
		local text = self.MapName
		surface.SetFont( "DermaLarge" )
		local tW, tH = surface.GetTextSize( self.MapName )
		local pad = 50
		surface.SetDrawColor( 0, 0, 0, 255 )
		--surface.DrawRect( -tW / 2 - pad, -pad, tW + pad * 2, tH + pad * 2 )
		draw.SimpleTextOutlined( text, "MapNamesFont", -tW * 2, 0, color_white, 0, 0, 12, Color(0,0,0))
	cam.End3D2D() ]]
end