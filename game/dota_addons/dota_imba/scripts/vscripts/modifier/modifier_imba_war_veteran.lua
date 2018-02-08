-- Author: EarthSalamander #42
-- 30/01/2018 // DD/MM/YYYY

modifier_imba_war_veteran_0 = class({})

function modifier_imba_war_veteran_0:IsPurgable() return false end
function modifier_imba_war_veteran_0:IsHidden() return false end
function modifier_imba_war_veteran_0:IsPermanent() return true end

function modifier_imba_war_veteran_0:OnCreated()
	self.hp_regen = 2				-- +50 health regen
	self.status_resistance = 1		-- +25% tenacity
end

function modifier_imba_war_veteran_0:GetTexture()
	return "custom/war_veteran_0"
end

function modifier_imba_war_veteran_0:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_HEALTH_REGEN_CONSTANT,
	}

	return funcs
end

function modifier_imba_war_veteran_0:GetModifierConstantHealthRegen()
	return self.hp_regen * (self:GetParent():GetLevel() - 25)
end

function modifier_imba_war_veteran_0:GetCustomTenacity()
	return self.status_resistance * (self:GetParent():GetLevel() - 25)
end

modifier_imba_war_veteran_1 = class({})

function modifier_imba_war_veteran_1:IsPurgable() return false end
function modifier_imba_war_veteran_1:IsHidden() return false end
function modifier_imba_war_veteran_1:IsPermanent() return true end

function modifier_imba_war_veteran_1:OnCreated()
	self.attack_speed = 3			-- +75 attack speed
	self.movespeed_pct = 1			-- +25% movespeed
end

function modifier_imba_war_veteran_1:GetTexture()
	return "custom/war_veteran_1"
end

function modifier_imba_war_veteran_1:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_ATTACKSPEED_BONUS_CONSTANT,
		MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE,
	}

	return funcs
end

function modifier_imba_war_veteran_1:GetModifierAttackSpeedBonus_Constant()
	return self.attack_speed * (self:GetParent():GetLevel() - 25)
end

function modifier_imba_war_veteran_1:GetModifierMoveSpeedBonus_Percentage()
	return self.movespeed_pct * (self:GetParent():GetLevel() - 25)
end

modifier_imba_war_veteran_2 = class({})

function modifier_imba_war_veteran_2:IsPurgable() return false end
function modifier_imba_war_veteran_2:IsHidden() return false end
function modifier_imba_war_veteran_2:IsPermanent() return true end

function modifier_imba_war_veteran_2:OnCreated()
	self.spell_amp = 2				-- +50% spell amp
	self.magic_resist = 1			-- +25% MR
end

function modifier_imba_war_veteran_2:GetTexture()
	return "custom/war_veteran_2"
end

function modifier_imba_war_veteran_2:DeclareFunctions()
	local funcs = {
		MODIFIER_PROPERTY_SPELL_AMPLIFY_PERCENTAGE,
		MODIFIER_PROPERTY_MAGICAL_RESISTANCE_BONUS,
	}

	return funcs
end

function modifier_imba_war_veteran_2:GetModifierSpellAmplify_Percentage()
	return self.spell_amp * (self:GetParent():GetLevel() - 25)
end

function modifier_imba_war_veteran_2:GetModifierMagicalResistanceBonus()
	return self.magic_resist * (self:GetParent():GetLevel() - 25)
end