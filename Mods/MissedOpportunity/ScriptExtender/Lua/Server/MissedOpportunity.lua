---@diagnostic disable: undefined-global
-- Missed Opportunity v2.0.0 by SEVNCE
-- Critical miss retaliation system powered by Grimoire library
--
-- When anyone rolls a critical miss (natural 1), their target can immediately
-- retaliate with weapons, blade cantrips, or offensive spells.
--
-- DEPENDENCIES:
-- - Grimoire library v1.0.0+
-- - Mod Configuration Menu (MCM) 1.38+
-- - BG3 Script Extender v29+

local MO = {
    ModUUID = "a7f3e2d1-9c4b-4e8a-b5f6-3d2c1a8e7b9f",
    Version = "2.0.0",
    Passive = "Passive_MissedOpportunity",
    Initialized = false,
    
    -- Configuration (loaded from MCM)
    Config = {
        enabled = true,
        criticalMissChance = 5,
        enableForPlayer = true,
        enableForAllies = true,
        enableForEnemies = true,
        enableBladeCantrips = true,
        enableMeleeWeapons = true,
        enableNaturalAttacks = true,
        enableUnarmed = true,
        enableRangedWeapons = true,
        enableOffensiveCantrips = true,
        meleeRange = 2,
        rangedMax = 18,
        enableDebug = false,
        debugLevel = "INFO"
    }
}

-- Initialize the mod
function MO:Initialize()
    if self.Initialized then
        return
    end
    
    -- Verify Grimoire is loaded
    if not Grimoire then
        _P("[Missed Opportunity] ERROR: Grimoire library not found! This mod requires Grimoire to function.")
        return
    end
    
    -- Check Grimoire version
    local compatible, message = Grimoire:CheckVersion("1.0.0")
    if not compatible then
        _P("[Missed Opportunity] ERROR: " .. message)
        return
    end
    
    _P("[Missed Opportunity] v" .. self.Version .. " initializing...")
    
    -- Load MCM settings
    self:LoadMCMSettings()
    
    -- Register MCM listeners
    self:RegisterMCMListeners()
    
    -- Register combat event
    self:RegisterCombatEvents()
    
    self.Initialized = true
    _P("[Missed Opportunity] ✓ Initialized successfully (powered by Grimoire)")
end

-- Load settings from MCM
function MO:LoadMCMSettings()
    if not MCM then
        _P("[Missed Opportunity] MCM not found - using default settings")
        return
    end
    
    self.Config.enabled = MCM.Get("enable_mod", self.ModUUID) or true
    self.Config.criticalMissChance = MCM.Get("critical_miss_chance", self.ModUUID) or 5
    self.Config.enableForPlayer = MCM.Get("enable_for_player", self.ModUUID) or true
    self.Config.enableForAllies = MCM.Get("enable_for_allies", self.ModUUID) or true
    self.Config.enableForEnemies = MCM.Get("enable_for_enemies", self.ModUUID) or true
    self.Config.enableBladeCantrips = MCM.Get("enable_blade_cantrips", self.ModUUID) or true
    self.Config.enableMeleeWeapons = MCM.Get("enable_melee_weapons", self.ModUUID) or true
    self.Config.enableNaturalAttacks = MCM.Get("enable_natural_attacks", self.ModUUID) or true
    self.Config.enableUnarmed = MCM.Get("enable_unarmed", self.ModUUID) or true
    self.Config.enableRangedWeapons = MCM.Get("enable_ranged_weapons", self.ModUUID) or true
    self.Config.enableOffensiveCantrips = MCM.Get("enable_offensive_cantrips", self.ModUUID) or true
    self.Config.meleeRange = MCM.Get("melee_range", self.ModUUID) or 2
    self.Config.rangedMax = MCM.Get("ranged_max", self.ModUUID) or 18
    self.Config.enableDebug = MCM.Get("enable_debug", self.ModUUID) or false
    self.Config.debugLevel = MCM.Get("debug_level", self.ModUUID) or "INFO"
end

-- Register MCM change listeners
function MO:RegisterMCMListeners()
    if not Ext.ModEvents or not Ext.ModEvents.BG3MCM then
        return
    end
    
    Ext.ModEvents.BG3MCM["MCM_Setting_Saved"]:Subscribe(function(payload)
        if not payload or payload.modUUID ~= MO.ModUUID then
            return
        end
        
        -- Update config when settings change
        MO:LoadMCMSettings()
        
        if MO.Config.enableDebug then
            _P("[Missed Opportunity] Setting updated: " .. payload.settingId .. " = " .. tostring(payload.value))
        end
    end)
end

-- Check if entity is allowed to retaliate based on config
function MO:IsAllowedToRetaliate(entity)
    -- Check if entity is player character
    if Osi.IsPlayer(entity) == 1 then
        return self.Config.enableForPlayer
    end
    
    -- Check if entity is in player's party (companion/summon)
    if Osi.IsPartyMember(entity, 1) == 1 then
        return self.Config.enableForPlayer
    end
    
    -- Check if entity is allied
    if Osi.IsAlly(Osi.GetHostCharacter(), entity) == 1 then
        return self.Config.enableForAllies
    end
    
    -- Must be an enemy
    return self.Config.enableForEnemies
end

-- Determine which retaliation types are enabled for this attack
function MO:GetEnabledReactionTypes(attackType)
    local enabled = {}
    
    if attackType == "MELEE" then
        if self.Config.enableBladeCantrips then
            table.insert(enabled, Grimoire.Reactions.Types.BLADE_CANTRIP)
        end
        if self.Config.enableMeleeWeapons then
            table.insert(enabled, Grimoire.Reactions.Types.MELEE_WEAPON)
        end
        if self.Config.enableNaturalAttacks then
            table.insert(enabled, Grimoire.Reactions.Types.NATURAL_ATTACK)
        end
        if self.Config.enableUnarmed then
            table.insert(enabled, Grimoire.Reactions.Types.UNARMED)
        end
    elseif attackType == "RANGED" then
        if self.Config.enableRangedWeapons then
            table.insert(enabled, Grimoire.Reactions.Types.RANGED_WEAPON)
        end
        if self.Config.enableOffensiveCantrips then
            table.insert(enabled, Grimoire.Reactions.Types.OFFENSIVE_CANTRIP)
        end
    end
    
    return enabled
end

-- Main retaliation handler
function MO:HandleRetaliation(attacker, defender)
    -- Check if mod is enabled
    if not self.Config.enabled then
        return
    end
    
    -- Validate both entities are alive
    if not Osi.IsAlive(attacker) or not Osi.IsAlive(defender) then
        return
    end
    
    -- Check if defender can retaliate (using Grimoire)
    if not Grimoire:CanRetaliate(defender) then
        if self.Config.enableDebug then
            Grimoire.Debug:Debug("[MO] Defender cannot retaliate (blinded/invisible)")
        end
        return
    end
    
    -- Check if defender is allowed to retaliate based on config
    if not self:IsAllowedToRetaliate(defender) then
        if self.Config.enableDebug then
            Grimoire.Debug:Debug("[MO] Defender not allowed to retaliate (filtered by config)")
        end
        return
    end
    
    -- Get distance and attack type (using Grimoire)
    local attackType = Grimoire:GetAttackType(defender, attacker, self.Config.meleeRange, self.Config.rangedMax)
    
    if attackType == "OUT_OF_RANGE" then
        if self.Config.enableDebug then
            Grimoire.Debug:Debug("[MO] Target out of range for retaliation")
        end
        return
    end
    
    -- Get enabled reaction types for this range
    local enabledTypes = self:GetEnabledReactionTypes(attackType)
    
    if #enabledTypes == 0 then
        if self.Config.enableDebug then
            Grimoire.Debug:Debug("[MO] No retaliation types enabled for " .. attackType)
        end
        return
    end
    
    -- Build context for Grimoire reaction system
    local context = {
        grimoire = Grimoire,
        meleeRange = self.Config.meleeRange,
        rangedMax = self.Config.rangedMax,
        enabledTypes = enabledTypes
    }
    
    -- Execute highest priority available reaction (using Grimoire)
    local success = Grimoire.Reactions:ExecuteHighestPriority(defender, attacker, context)
    
    if success and self.Config.enableDebug then
        Grimoire.Debug:Info("[MO] Retaliation executed successfully", {
            defender = defender,
            attacker = attacker,
            attackType = attackType
        })
    end
end

-- Register combat events
function MO:RegisterCombatEvents()
    -- Listen for attack hits - this fires on ALL attacks
    Ext.Osiris.RegisterListener("AttackHit", 4, "after", function(attacker, defender, _, _)
        -- For now, we'll trigger on all hits
        -- TODO: Add actual critical miss detection when we figure out how to check attack rolls
        
        -- Simple probability check for critical miss
        -- 5% = natural 1 in D&D
        local roll = math.random(1, 100)
        if roll <= MO.Config.criticalMissChance then
            MO:HandleRetaliation(attacker, defender)
        end
    end)
    
    -- Apply passive to all combatants when combat starts
    Ext.Osiris.RegisterListener("CombatStarted", 1, "after", function(combatID)
        local row = Osi.DB_Is_InCombat:Get(nil, combatID)
        if row ~= nil then
            local combatant = row[1]
            if combatant ~= nil and Osi.IsCharacter(combatant) == 1 then
                Osi.AddPassive(combatant, MO.Passive)
            end
        end
    end)
end

-- Initialize on session load
Ext.Events.SessionLoaded:Subscribe(function()
    MO:Initialize()
end)

-- Also initialize on reset (for development)
Ext.Events.ResetCompleted:Subscribe(function()
    MO.Initialized = false
    MO:Initialize()
end)

_P("[Missed Opportunity] Module loaded - waiting for session start")
