-- Custom Model Author: Champi Suicidaire

item_imba_rune_frost = item_imba_rune_frost or class({})

modifier_imba_frost_rune = modifier_imba_frost_rune or class({})

-- Modifier properties
function modifier_imba_frost_rune:IsHidden() return false end
function modifier_imba_frost_rune:IsPurgable() return true end
function modifier_imba_frost_rune:IsDebuff() return false end

function modifier_imba_frost_rune:GetTexture()
	return "custom/imba_rune_frost"
end

function modifier_imba_frost_rune:OnCreated()
	self.caster = self:GetCaster()
	self.radius = 900
	self.slow_duration = 3.0
end

-- Function declarations
function modifier_imba_frost_rune:DeclareFunctions()
	local funcs	=	{
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
	return funcs
end

function modifier_imba_frost_rune:OnAttackLanded(kv)
	if (kv.attacker == self:GetParent()) and (kv.target:GetTeamNumber() ~= self:GetParent():GetTeamNumber()) then
		kv.target:AddNewModifier(kv.attacker, nil, "modifier_imba_frost_rune_slow", {duration = self.slow_duration})
	end
end

function modifier_imba_frost_rune:OnTakeDamage(keys)
	if IsServer() then
		if self:GetParent() ~= keys.attacker then
			return
		end
		
		local target = keys.unit
		print(self:GetParent():GetUnitName())
		print(target)
		if self:GetParent():GetTeam() == target:GetTeam() then
			return
		end

		if self:GetParent() == target then
			target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_imba_frost_rune_slow", {duration = self.slow_duration})
		end
	end
end

-- Aura properties
function modifier_imba_frost_rune:IsAura() return true end
function modifier_imba_frost_rune:GetAuraRadius() return self.radius end
function modifier_imba_frost_rune:GetAuraSearchTeam() return DOTA_UNIT_TARGET_TEAM_FRIENDLY end
function modifier_imba_frost_rune:GetAuraSearchType() return DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC end
function modifier_imba_frost_rune:GetAuraSearchFlags() return DOTA_UNIT_TARGET_FLAG_NONE end

function modifier_imba_frost_rune:GetModifierAura()
	return "modifier_imba_frost_rune_aura"
end

function modifier_imba_frost_rune:GetAuraEntityReject(target)
	if target == self.caster then
        return true
    end
	return false
end

function modifier_imba_frost_rune:GetEffectName()
	return "particles/econ/courier/courier_greevil_blue/courier_greevil_blue_ambient_3.vpcf"
end

function modifier_imba_frost_rune:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

--- MINOR AURA MODIFIER
modifier_imba_frost_rune_aura = modifier_imba_frost_rune_aura or class({})

-- Modifier properties
function modifier_imba_frost_rune_aura:IsHidden() 	return false end
function modifier_imba_frost_rune_aura:IsPurgable()	return false end
function modifier_imba_frost_rune_aura:IsDebuff() 	return false end

function modifier_imba_frost_rune_aura:GetTextureName()
	return "custom/imba_rune_frost"
end

function modifier_imba_frost_rune_aura:OnCreated()
	self.slow_duration = 3.0
end

-- Function declarations
function modifier_imba_frost_rune:DeclareFunctions()
	local funcs	=	{
		MODIFIER_EVENT_ON_ATTACK_LANDED,
		MODIFIER_EVENT_ON_TAKEDAMAGE,
	}
	return funcs
end

function modifier_imba_frost_rune:OnAttackLanded(kv)
	if (kv.attacker == self:GetParent()) and (kv.target:GetTeamNumber() ~= self:GetParent():GetTeamNumber()) then
		kv.target:AddNewModifier(kv.attacker, nil, "modifier_imba_frost_rune_slow", {duration = self.slow_duration})
	end
end

function modifier_imba_frost_rune_aura:OnTakeDamage(keys)
	if IsServer() then
		if self:GetParent() ~= keys.attacker then
			return
		end
		
		local target = keys.unit
		print(self:GetParent():GetUnitName())
		print(target)
		if self:GetParent():GetTeam() == target:GetTeam() then
			return
		end

		if self:GetParent() == target then
			target:AddNewModifier(self:GetParent(), self:GetAbility(), "modifier_imba_frost_rune_slow", {duration = self.slow_duration})
		end
	end
end

function modifier_imba_frost_rune_aura:GetEffectName()
	return "particles/econ/courier/courier_greevil_blue/courier_greevil_blue_ambient_3.vpcf"
end

function modifier_imba_frost_rune_aura:GetEffectAttachType()
	return PATTACH_ABSORIGIN_FOLLOW
end

-----------------------------------------------------------------------------------

if modifier_imba_frost_rune_slow == nil then modifier_imba_frost_rune_slow = class({}) end
function modifier_imba_frost_rune_slow:IsHidden() return false end
function modifier_imba_frost_rune_slow:IsDebuff() return true end
function modifier_imba_frost_rune_slow:IsPurgable() return true end

-- Modifier status effect
function modifier_imba_frost_rune_slow:GetStatusEffectName()
	return "particles/status_fx/status_effect_frost_lich.vpcf" end

function modifier_imba_frost_rune_slow:StatusEffectPriority()
	return 10
end

-- Ability KV storage
function modifier_imba_frost_rune_slow:OnCreated(keys)
	self.slow_as = -100
	self.slow_ms = -20
end

-- Declare modifier events/properties
function modifier_imba_frost_rune_slow:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}
	return funcs
end

function modifier_imba_frost_rune_slow:GetModifierAttackSpeedBonus_Constant()
	return self.slow_as
end

function modifier_imba_frost_rune_slow:GetModifierMoveSpeedBonus_Percentage()
	return self.slow_ms
end