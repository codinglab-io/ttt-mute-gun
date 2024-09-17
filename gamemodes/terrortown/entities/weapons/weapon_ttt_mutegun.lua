if SERVER then
    AddCSLuaFile("shared.lua")
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
        desc = "Shoot someone to mute them.\nOnly traitors can hear muted players."
    };
end

SWEP.Base = "weapon_tttbase"
SWEP.HoldType = "pistol"

SWEP.Primary.Ammo = "AR2AltFire"
SWEP.Primary.Recoil = 4
SWEP.Primary.Damage = 1
SWEP.Primary.Delay = 2.0
SWEP.Primary.Cone = 0.01
SWEP.Primary.ClipSize = 1
SWEP.Primary.Automatic = false
SWEP.Primary.DefaultClip = 1
SWEP.Primary.ClipMax = 1
SWEP.Primary.Sound = Sound("Weapon_USP.SilencedShot")

--- TTT config values

SWEP.Kind = WEAPON_EQUIP1
SWEP.CanBuy = {ROLE_TRAITOR} -- only traitors can buy
SWEP.LimitedStock = true -- only buyable once
SWEP.WeaponID = AMMO_MUTEGUN

SWEP.Tracer = "AR2Tracer"

SWEP.UseHands = true
SWEP.ViewModel = Model("models/weapons/c_357.mdl")
SWEP.WorldModel = Model("models/weapons/w_357.mdl")

-- If AutoSpawnable is true and SWEP.Kind is not WEAPON_EQUIP1/2, then this gun can
-- be spawned as a random weapon. Of course this AK is special equipment so it won't,
-- but for the sake of example this is explicitly set to false anyway.
SWEP.AutoSpawnable = false

-- The AmmoEnt is the ammo entity that can be picked up when carrying this gun.
SWEP.AmmoEnt = "item_ammo_smg1_ttt"

-- InLoadoutFor is a table of ROLE_* entries that specifies which roles should
-- receive this weapon as soon as the round starts. In this case, none.
SWEP.InLoadoutFor = nil

-- If LimitedStock is true, you can only buy one per round.
SWEP.LimitedStock = false

-- If AllowDrop is false, players can't manually drop the gun with Q
SWEP.AllowDrop = true

-- If IsSilent is true, victims will not scream upon death.
SWEP.IsSilent = true

-- If NoSights is true, the weapon won't have ironsights
SWEP.NoSights = false

-- Tell the server that it should download our icon to clients.
if SERVER then
    resource.AddFile("materials/VGUI/ttt/icon_mute_gun.vmt")
end

--- Utilities

-- Table to keep track of muted players
local mutedPlayers = {}

function MutePlayer(ply, target)
    mutedPlayers[target] = true
    print("Muting player " .. target:Nick())
end

--- Hooks / events

-- Hook to control who can hear who
hook.Add("PlayerCanHearPlayersVoice", "HandlePlayerMute", function(listener, talker)
    -- If the listener is the traitor, they can hear everyone
    if listener:IsTraitor() then
        return true
    end

    -- If the talker is muted, return false to block their voice
    if mutedPlayers[talker] then
        return false, false
    end
end)

-- Reset all muted players on round end
hook.Add("TTTEndRound", "ResetMutedPlayers", function()
    mutedPlayers = {} -- Clear the muted players table
    print("Reset all muted players.")
end)

-- Unmute player on death
hook.Add("PlayerDeath", "UnmuteOnDeath", function(victim)
    if mutedPlayers[victim] then
        mutedPlayers[victim] = nil -- Remove from muted players table
        print("Unmuting player " .. victim:Nick() .. " on death.")
    end
end)

-- Prevent muted players from sending chat messages
hook.Add("PlayerSay", "BlockChatForMutedPlayers", function(ply, text)
    if mutedPlayers[ply] then
        print("Blocked chat message from " .. ply:Nick() .. ": " .. text)
        return "" -- Block the message by returning an empty string
    end
end)

function SWEP:PrimaryAttack()
    -- handle delay (see above)
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    if not self:CanPrimaryAttack() then
        return
    end

    self:EmitSound(self.Primary.Sound)
    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
    self:TakePrimaryAmmo(1)

    -- recoil and animation on the client
    if IsValid(self:GetOwner()) then
        self:GetOwner():SetAnimation(PLAYER_ATTACK1)

        self:GetOwner():ViewPunch(Angle(math.Rand(-0.2, -0.1) * self.Primary.Recoil,
            math.Rand(-0.1, 0.1) * self.Primary.Recoil, 0))
    end

    -- get owner and target
    local owner = self:GetOwner()
    local tr = owner:GetEyeTrace(MASK_SHOT)
    local ent = tr.Entity

    -- check if the target is a player
    if not IsValid(ent) or not ent:IsPlayer() then
        return
    end

    -- Mute the target for everyone except the traitor
    MutePlayer(owner, ent)

end

-- disable secondary attack
function SWEP:SecondaryAttack()
end
