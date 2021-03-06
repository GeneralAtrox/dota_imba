--[[	Author: EarthSalamander #42
		Date: 29.01.2018	]]

courier_movespeed = class({})

function courier_movespeed:GetIntrinsicModifierName()
	return "modifier_courier_turbo"
end

LinkLuaModifier("modifier_courier_turbo", "components/courier/abilities.lua", LUA_MODIFIER_MOTION_NONE)

modifier_courier_turbo = modifier_courier_turbo or class({})

function modifier_courier_turbo:IsPurgable() return false end
function modifier_courier_turbo:IsHidden() return true end
function modifier_courier_turbo:RemoveOnDeath() return false end
--[[
function modifier_courier_turbo:OnCreated()
	if IsServer() then
		self:GetParent():AddNewModifier(self:GetParent(), nil, "modifier_courier_flying", {})
	end
end
--]]
function modifier_courier_turbo:CheckState()
	local state = {
		[MODIFIER_STATE_FLYING] = true,
	}

	return state
end

function modifier_courier_turbo:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_MOVESPEED_ABSOLUTE,
		MODIFIER_PROPERTY_MOVESPEED_MAX,
		MODIFIER_PROPERTY_MODEL_CHANGE,
	}

	return funcs
end

function modifier_courier_turbo:GetModifierModelChange()
    return "models/props_gameplay/donkey_wings.vmdl"
end

function modifier_courier_turbo:GetModifierMoveSpeed_Absolute()
	return self:GetAbility():GetSpecialValueFor("movespeed")
end

function modifier_courier_turbo:GetModifierMoveSpeed_Max()
	return self:GetAbility():GetSpecialValueFor("movespeed")
end

--------------------------------------------

imba_courier_autodeliver = class({})

function imba_courier_autodeliver:OnToggle()
--	local buff = self:GetCaster():FindModifierByName("modifier_imba_courier_autodeliver")

	-- if the ability is toggled on, add the autodeliver modifier
	if self:GetToggleState() == true then
		self:GetCaster():AddNewModifier(self:GetCaster(), self, "modifier_imba_courier_autodeliver", {})
	-- else remove the modifier
	else
		self:GetCaster():RemoveModifierByName("modifier_imba_courier_autodeliver")
	end
end

LinkLuaModifier("modifier_imba_courier_autodeliver", "components/courier/abilities.lua", LUA_MODIFIER_MOTION_NONE)

modifier_imba_courier_autodeliver = modifier_imba_courier_autodeliver or class({})

function modifier_imba_courier_autodeliver:IsPurgable() return false end
function modifier_imba_courier_autodeliver:IsHidden() return false end

function modifier_imba_courier_autodeliver:OnCreated()
	if IsServer() then
		self.deliver_time_check = 0.0
		self:StartIntervalThink(1.0)
	end
end

-- BUG TODO: courier don't deliver any items when it spawn until you give him any order
function modifier_imba_courier_autodeliver:OnIntervalThink()
--	print("Idle?", self:GetParent():IsIdle())

	-- if the courier is moving or is near secret shop, end the script
	if not self:GetParent():IsIdle() or IsNearEntity("ent_dota_shop", self:GetParent():GetAbsOrigin(), 100) == true then
		self.deliver_time_check = 0.0
		return
	end

	local has_item_to_deliver = false

	-- check if the courier have an item in inventory
	for itemSlot = 0, 8 do
		local item = self:GetParent():GetItemInSlot(itemSlot)

		if item then
			has_item_to_deliver = true
			break
		end
	end

	-- check if the owner have an item in stash
	for itemSlot = 9, 14 do
		local item = self:GetParent():GetOwner():GetItemInSlot(itemSlot)

		if item then
			has_item_to_deliver = true
			break
		end
	end

--	print("item to deliver?", has_item_to_deliver)

	if has_item_to_deliver == true then
		-- if the hero buy an item, reset the timer and end the function
		if self:GetParent():GetOwner().reset_turbo_deliver == true then
--			print("Hero bought an item, refresh timer!")
			self:GetParent():GetOwner().reset_turbo_deliver = false
			self.deliver_time_check = 0.0
			return
		-- if the hero didn't buy an item between the last check, increase the timer
		else
			self.deliver_time_check = self.deliver_time_check + 1.0
--			print("Increase timer check:", self.deliver_time_check)
		end

--		print("Timer check:", self.deliver_time_check.." / "..self:GetAbility():GetSpecialValueFor("delay"))
		-- if the timer is equal or higher than the autodeliver time, deliver items and reset timer to 0
		if self.deliver_time_check >= self:GetAbility():GetSpecialValueFor("delay") then
			-- check if the owner have free slots to receive items
			local has_empty_slot = false

			for itemSlot = 0, 8 do
				local item = self:GetParent():GetOwner():GetItemInSlot(itemSlot)

				if not item then
					has_empty_slot = true
					break
				end
			end

--			print("Hero have free slot?", has_empty_slot)

			-- if the hero have at least 1 free slot, auto-deliver and reset timer
			if has_empty_slot == true then
				self:GetParent():FindAbilityByName("courier_take_stash_and_transfer_items"):CastAbility()
				self.deliver_time_check = 0.0
			else
--				print("hero inventory is full!")
			end
		end
	end
end
