// Adds the ability to push grenades by shooting at them, or catching them to throw


//Change this to make the grenade bounce further
Vector g_ReflectBias = Vector(1,1,-0.7);
float g_ReflectForce = 400.f;
float g_ThrowForce = 600.f;

array<int> g_player_hasNade(33);

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nexy" );
	g_Module.ScriptInfo.SetContactInfo( "steamcommunity.com/id/nexytpowa" );
	
	g_Hooks.RegisterHook( Hooks::Weapon::WeaponPrimaryAttack, @WeaponPrimaryAttack);
	g_Hooks.RegisterHook( Hooks::Weapon::WeaponSecondaryAttack, @WeaponSecondaryAttack);
	g_Hooks.RegisterHook(Hooks::Player::PlayerPreThink, @PlayerPreThink);
}

void ReflectGrenade(CBaseEntity@ grenade, Vector dir)
{
	Vector vecReflect = dir - 2.f * (dir.z+1) * Vector(0,0,1);
	vecReflect = (vecReflect * g_ReflectBias).Normalize();
	
	grenade.pev.basevelocity = vecReflect * g_ReflectForce;
}

CBaseEntity@[] pEnts(128);
CBaseEntity@ FindGrenade(CBaseEntity@ pMe, float dist, float radius)
{
	Math.MakeVectors( pMe.pev.v_angle );
	Vector vecSrc = pMe.pev.origin + pMe.pev.view_ofs;
	Vector vecEnd = vecSrc + g_Engine.v_forward * dist;
		
	TraceResult tr;
	g_Utility.TraceLine( vecSrc, vecEnd, dont_ignore_monsters, pMe.edict(), tr );
	
	int foundCount = g_EntityFuncs.MonstersInSphere( @pEnts, tr.vecEndPos, (tr.flFraction > 0.5 ? radius*2.f : radius) );
		
	for(int i = 0; i < foundCount; ++i)
	{
		//string classname = pEnts[i].pev.classname; classname.Find("nade") != String::INVALID_INDEX
		if(pEnts[i] !is null && pEnts[i].pev.classname == "grenade")
			return pEnts[i];
	}
	
	return null;
}

void PushGrenade(CBasePlayer@ plr, float dist, float radius)
{
	CBaseEntity@ grenade = FindGrenade(plr, dist, radius);
	if(grenade !is null)
		ReflectGrenade(grenade, g_Engine.v_forward);
}

void TimedUnblock(int idx)
{
	CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(idx);
	if(plr !is null && plr.IsConnected())
	{
		plr.UnblockWeapons(plr);
		g_player_hasNade[idx] = 0;
	}
}

void MoveGrenade(int grenadeIdx, int playerIdx)
{
	CBaseEntity@ grenade = g_EntityFuncs.Instance(grenadeIdx);
	CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(playerIdx);

	if(	grenade !is null && plr !is null && 
		plr.IsConnected() && plr.IsAlive() && 
		g_player_hasNade[playerIdx] > 0 && 
		grenade.pev.flags != 4640 && g_Engine.time - grenade.pev.animtime <= 0.15f ) //Fly nade cheat fix
	{
		//g_PlayerFuncs.SayTextAll(null, ""+grenade.pev.solid+" "+grenade.pev.flags+"\n");
		Math.MakeVectors( plr.pev.v_angle );
		grenade.pev.angles = plr.pev.v_angle;
		grenade.pev.flags = 544;
		g_EntityFuncs.SetOrigin(grenade, plr.pev.origin + Vector(0,0,15) + g_Engine.v_forward*30);
	}
	else
	{
		g_player_hasNade[playerIdx] = 0;
		plr.UnblockWeapons(plr);
		
		CScheduledFunction@ thisfunc = g_Scheduler.GetCurrentFunction();
		g_Scheduler.RemoveTimer(thisfunc);
		
		if(grenade.pev.flags == 4640) //fly glitch nade punishment
		{
			grenade.pev.dmg = 150;
			cast<CGrenade@>(grenade).Explode(grenade.pev.origin, Vector(0,0,1));
		}
	}
}

void CatchGrenade(CBasePlayer@ plr, float dist, float radius)
{
	CBaseEntity@ grenade = FindGrenade(plr, dist, radius);
	if(grenade !is null)
	{
		if(g_Engine.time - grenade.pev.animtime > 0.15f || grenade.pev.flags == 4640)
			return;
			
		g_player_hasNade[plr.entindex()] = grenade.entindex();
		g_Scheduler.SetInterval("MoveGrenade", 0.016f, 60*10, grenade.entindex(), plr.entindex());
		grenade.pev.basevelocity = Vector(0,0,0);
		grenade.pev.velocity = Vector(0,0,0);
		grenade.pev.avelocity = Vector(0,0,0);
		plr.BlockWeapons(plr);
	}
	
}

HookReturnCode WeaponPrimaryAttack(CBasePlayer@ pPlayer, CBasePlayerWeapon@ pWeapon)
{
	if(pPlayer is null)
		return HOOK_CONTINUE;

	if(pWeapon.iItemSlot() > 1)
	{
		if(pWeapon.m_iClip != -1)
			PushGrenade(pPlayer, 500.f, 10.f);
	}
	else if(pWeapon.iItemSlot() == 1 && pWeapon.pev.classname == "weapon_crowbar")
	{
		PushGrenade(pPlayer, 50.f, 20.f);
	}

	return HOOK_CONTINUE;
}

HookReturnCode WeaponSecondaryAttack( CBasePlayer@ pPlayer, CBasePlayerWeapon@ pWeapon )
{
	if(pPlayer is null)
		return HOOK_CONTINUE;

	if(pWeapon.iItemSlot() > 1 && pWeapon.pev.classname == "weapon_shotgun")
	{
		if(pWeapon.m_iClip != -1)
			PushGrenade(pPlayer, 500.f, 20.f);
	}
	else if(pWeapon.iItemSlot() == 1 && pWeapon.pev.classname == "weapon_crowbar")
	{
		PushGrenade(pPlayer, 50.f, 20.f);
	}

	return HOOK_CONTINUE;
}

HookReturnCode PlayerPreThink(CBasePlayer@ plr, uint& out uiFlags)
{	
	int buttons = plr.m_afButtonPressed;
	int idx = plr.entindex();
	
	if(buttons & IN_USE != 0 && plr.IsAlive())
	{
		CatchGrenade(plr, 60.f, 30.f);
	}
	else if(buttons & IN_ATTACK != 0 && g_player_hasNade[idx] != 0)
	{
		CBaseEntity@ grenade = g_EntityFuncs.Instance(g_player_hasNade[idx]);
		if(grenade !is null)
		{
			Math.MakeVectors( plr.pev.v_angle );
			g_EntityFuncs.SetOrigin(grenade, plr.pev.origin + Vector(0,0,40) + g_Engine.v_forward*15);
			grenade.pev.basevelocity = grenade.pev.basevelocity + g_Engine.v_forward*g_ThrowForce;
		}
		
		g_player_hasNade[plr.entindex()] = 0;
		plr.UnblockWeapons(plr);
	}
	
	/*CBaseEntity@ grenade = FindGrenade(plr, 200.f, 20.f);
	if(grenade !is null)
	{
		g_PlayerFuncs.SayTextAll(null, ""+g_Engine.time+" "+grenade.pev.animtime+"\n");
	}*/
	
	
	return HOOK_CONTINUE;
}