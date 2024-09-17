if SERVER then
    AddCSLuaFile("weapon_ttt_mutegun.lua")
    resource.AddFile("materials/VGUI/ttt/icon_mute_gun.vmt")
end

--- Convars
local traitorCanBuy = CreateConVar("ttt_mutegun_traitor", 1,
    {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE}, "Should the Mute Gun be available for Traitors?")
local detectiveCanBuy = CreateConVar("ttt_mutegun_detective", 1,
    {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE}, "Should the Mute Gun be available for Detectives?")
local muteDuration = CreateConVar("ttt_mutegun_duration", 0,
    {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE}, "Sets mute duration in seconds, 0 for the whole round")
local ammoCount = CreateConVar("ttt_mutegun_ammo", 1, {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE},
    "Sets amount of ammo for the Mute Gun")
local autoSpawnable = CreateConVar("ttt_mutegun_autospawn", 0,
    {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE}, "Should the Mute Gun spawn automatically?")
local shouldTraitorHearMuted = CreateConVar("ttt_mutegun_traitor_hear_muted", 1,
    {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE}, "Should traitors hear muted players?")
local damageOnShoot = CreateConVar("ttt_mutegun_damage", 1, {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_SERVER_CAN_EXECUTE},
    "How much damage it deals to the target?")

--- Config logic
local durationMessage = muteDuration:GetInt() > 0 and "for " .. muteDuration:GetInt() .. " seconds." or
                            "for the whole round."

local canBuy = {}
if traitorCanBuy:GetBool() and detectiveCanBuy:GetBool() then
    canBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}
elseif traitorCanBuy:GetBool() then
    canBuy = {ROLE_TRAITOR}
elseif detectiveCanBuy:GetBool() then
    canBuy = {ROLE_DETECTIVE}
end

--- SWEP Info
if CLIENT then
    SWEP.PrintName = "Mute Gun"
    SWEP.Slot = 6

    SWEP.ViewModelFOV = 54
    SWEP.ViewModelFlip = false

    SWEP.Icon = "VGUI/ttt/icon_mute_gun"
    -- Text shown in the equip menu
    SWEP.EquipMenuData = {
        type = "Weapon",
        -- if duration is 0, it will mute for the whole round
        desc = "Shoot someone to mute them.\nOnly traitors can hear muted players.\nHas " .. ammoCount:GetInt() ..
            " shots.\nMutes the target " .. durationMessage
    };
end

SWEP.Base = "weapon_tttbase"
SWEP.HoldType = "pistol"

SWEP.Primary.Ammo = "AR2AltFire"
SWEP.Primary.Recoil = 4
SWEP.Primary.Damage = damageOnShoot:GetInt()
SWEP.Primary.Delay = 2.0
SWEP.Primary.Cone = 0.01
SWEP.Primary.ClipSize = ammoCount:GetInt()
SWEP.Primary.Automatic = false
SWEP.Primary.DefaultClip = ammoCount:GetInt()
SWEP.Primary.ClipMax = ammoCount:GetInt()
SWEP.Primary.Sound = Sound("Weapon_USP.SilencedShot")
SWEP.UseHands = true
SWEP.ViewModel = Model("models/weapons/c_357.mdl")
SWEP.WorldModel = Model("models/weapons/w_357.mdl")

--- TTT SWEP Info
SWEP.Kind = WEAPON_EQUIP1
SWEP.CanBuy = canBuy
SWEP.LimitedStock = false
SWEP.Tracer = "AR2Tracer"
SWEP.AutoSpawnable = autoSpawnable:GetBool()
SWEP.IsSilent = true

--- Hooks
local mutedPlayers = {}

-- Handle player voice chat muting
hook.Add("PlayerCanHearPlayersVoice", "HandlePlayerMute", function(listener, talker)
    -- If the listener is the traitor, can he hear muted players?
    if listener:IsTraitor() and shouldTraitorHearMuted:GetBool() then
        return true
    end

    -- If the talker is muted, return false to block their voice
    if mutedPlayers[talker] then
        return false, false
    end
end)

-- Reset all muted players on round end
hook.Add("TTTEndRound", "ResetMutedPlayers", function()
    mutedPlayers = {}
end)

-- Unmute player on death
hook.Add("PlayerDeath", "UnmuteOnDeath", function(victim)
    if mutedPlayers[victim] then
        mutedPlayers[victim] = nil
    end
end)

-- Prevent muted players from sending chat messages
hook.Add("PlayerSay", "BlockChatForMutedPlayers", function(ply, text)
    if mutedPlayers[ply] then
        print("Blocked chat message from " .. ply:Nick() .. ": " .. text)
        return "" -- Block the message by returning an empty string
    end
end)

--- SWEP Functions
function MuteTarget(target, path, dmginfo)
    local ent = path.Entity

    if not IsValid(ent) or not ent:IsPlayer() then
        return
    end

    -- Add the target to the muted players list
    mutedPlayers[ent] = true

    -- Unmute after the specified duration
    if muteDuration:GetInt() > 0 then
        timer.Simple(muteDuration:GetInt(), function()
            mutedPlayers[ent] = nil
        end)
    end

end

function SWEP:ShootMute()
    local cone = self.Primary.Cone
    local bullet = {}
    bullet.Num = 1
    bullet.Src = self.Owner:GetShootPos()
    bullet.Dir = self.Owner:GetAimVector()
    bullet.Spread = Vector(cone, cone, 0)
    bullet.Tracer = 1
    bullet.Force = 2
    bullet.Damage = self.Primary.Damage
    bullet.TracerName = self.Tracer
    bullet.Callback = MuteTarget

    self.Owner:FireBullets(bullet)
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if not self:CanPrimaryAttack() then
        return
    end

    self:EmitSound(self.Primary.Sound)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:ShootMute()
    self:TakePrimaryAmmo(1)

    -- recoil and animation on the client
    if IsValid(self:GetOwner()) then
        self:GetOwner():SetAnimation(PLAYER_ATTACK1)

        self:GetOwner():ViewPunch(Angle(math.Rand(-0.2, -0.1) * self.Primary.Recoil,
            math.Rand(-0.1, 0.1) * self.Primary.Recoil, 0))
    end

end

-- disable secondary attack
function SWEP:SecondaryAttack()
end
