//Force gib player v1.2.1

int dmgNoGibFlags = 	DMG_BULLET |
						DMG_CRUSH | DMG_FALL | DMG_DROWN | 
						DMG_TIMEBASED | DMG_PARALYZE | DMG_NERVEGAS | DMG_POISON | DMG_RADIATION |
						DMG_ACID | DMG_SLOWBURN | DMG_SLOWFREEZE | DMG_MEDKITHEAL | 
						DMG_LAUNCH | DMG_DROWNRECOVER | DMG_NEVERGIB | DMG_BLAST
						;
						
						
const string g_Banlist = "scripts/plugins/cfg/GIB_mapbans.txt";
dictionary g_BannedMaps;

CClientCommand g_DebugDamage("debugdmg", "Debug damage taken", @debugDamage);
int g_debugPlr = -1;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nexy v1" );
	g_Module.ScriptInfo.SetContactInfo( "steamcommunity.com/id/nexytpowa" );
	
	g_Hooks.RegisterHook( Hooks::Player::ClientDisconnect, @ClientDisconnect);
	
	setupBanlist();
	CheckBan();
}

void MapActivate()
{
	CheckBan();
	g_debugPlr = -1;
}

void CheckBan()
{
	if(g_BannedMaps.exists(g_Engine.mapname))
	{
		g_Hooks.RemoveHook(Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage);
	}
	else
	{
		g_Hooks.RegisterHook(Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage);
	}
}

void setupBanlist()
{
	File@ file = g_FileSystem.OpenFile(g_Banlist, OpenFile::READ);
	if (file !is null && file.IsOpen())
	{
		while (!file.EOFReached())
		{
			string sLine;
			file.ReadLine(sLine);
			
			if (sLine.SubString(0, 1) == "#" || sLine.IsEmpty())
				continue;

			g_BannedMaps[sLine] = true;
		}
		file.Close();
	}
}

HookReturnCode PlayerTakeDamage( DamageInfo@ dmg_info )
{
	if(dmg_info.pVictim is null || !dmg_info.pVictim.IsPlayer())
		return HOOK_CONTINUE;
		
	if(dmg_info.pAttacker is null || !dmg_info.pAttacker.IsMonster())
		return HOOK_CONTINUE;
		
	CBasePlayer@ plr = cast<CBasePlayer@>(dmg_info.pVictim);
	CBaseMonster@ monster = dmg_info.pAttacker.MyMonsterPointer();
	int dmgFlag = dmg_info.bitsDamageType;
	
	//Just in case since we use a function instead of casting ent to monster
	if(monster is null)
		return HOOK_CONTINUE;
	
	//if(plr.pev.health > dmg_info.flDamage)
		//return HOOK_CONTINUE;
		
		
		
	string classname = monster.GetClassname();
	//To be replaced with dictionnaries
	
	if(dmgFlag & DMG_BULLET != 0)
	{
		//Bees will gib
		if(	classname.Find("alien_grunt") != String::INVALID_INDEX )
		{
			dmg_info.bitsDamageType |= DMG_ALWAYSGIB;
		}
	}
	
	else if(dmgFlag & DMG_SONIC != 0)
	{
		//Houndeye will gib
		if(	classname.Find("houndeye") != String::INVALID_INDEX )
		{
			dmg_info.bitsDamageType = dmg_info.bitsDamageType & ~DMG_NEVERGIB;
			dmg_info.bitsDamageType |= DMG_ALWAYSGIB;
		}
	}
	
	else if(dmgFlag & DMG_SLASH != 0)
	{
		//Slave & leech melee won't gib
		if(	classname.Find("slave") != String::INVALID_INDEX ||
			classname.Find("leech") != String::INVALID_INDEX )
		{
			dmg_info.bitsDamageType |= DMG_NEVERGIB;
		}
	}
	
	else if(dmgFlag & DMG_ENERGYBEAM != 0)
	{
		dmg_info.bitsDamageType |= DMG_NEVERGIB;
	}
	
	else if(dmgFlag & DMG_ACID != 0)
	{
		if(	classname.Find("volti") != String::INVALID_INDEX )
		{
			dmg_info.bitsDamageType |= DMG_ALWAYSGIB;
		}
	}
	else if(dmgFlag & DMG_POISON != 0)
	{
		if( classname.Find("shock") != String::INVALID_INDEX )
		{
			dmg_info.bitsDamageType = dmg_info.bitsDamageType & ~DMG_NEVERGIB;
			dmg_info.bitsDamageType |= DMG_ALWAYSGIB;
		}
	}
	else if(dmgFlag & DMG_CLUB != 0)
	{
		if(dmg_info.flDamage < 5)
		{
			dmg_info.bitsDamageType |= DMG_NEVERGIB;
		}
	}
	else if(dmgFlag & DMG_SHOCK != 0)
	{
		if(	classname.Find("volti") != String::INVALID_INDEX )
		{
			dmg_info.bitsDamageType |= DMG_NEVERGIB;
		}
	}
	else if(dmg_info.bitsDamageType == DMG_GENERIC)
	{
		if(	classname.Find("volti") != String::INVALID_INDEX )
		{
			dmg_info.bitsDamageType = DMG_NEVERGIB;
		}
	}
	
	if(dmg_info.bitsDamageType & dmgNoGibFlags == 0)
	{
		dmg_info.bitsDamageType |= DMG_ALWAYSGIB;
		//g_PlayerFuncs.SayTextAll(null, "---> Always gib!"+"\n");
	}
	
	
	
	
	
	if(g_debugPlr > 0)
	{
		//there's a better way of doing it
		CBasePlayer@ dbgplr = g_PlayerFuncs.FindPlayerByIndex(g_debugPlr);
		if(dbgplr !is null)
		{	
			string info = 	"[GOB] ---> "+monster.GetClassname()+
							" code["+dmg_info.bitsDamageType+"]"+
							" damage["+dmg_info.flDamage+"]"+
							( dmg_info.bitsDamageType & (DMG_ALWAYSGIB|DMG_NEVERGIB) == DMG_ALWAYSGIB ? " GIB DAMAGE" : "" )+
							"\n";
			g_PlayerFuncs.SayText(dbgplr, info);
		}
	}
	
	
	return HOOK_CONTINUE;
}








void debugDamage(const CCommand@ pArgs)
{
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	if(g_PlayerFuncs.AdminLevel(plr) < ADMIN_YES)
	{
		g_PlayerFuncs.SayText(plr, "You do not have enough permissions to toggle this feature.\n");
		return;
	}
	
	if(g_debugPlr > 0 && g_debugPlr == plr.entindex())
	{
		g_PlayerFuncs.SayText(plr, "GOB debugging is now OFF\n");
		g_debugPlr = -1;
	}
	else
	{
		g_debugPlr = plr.entindex();
		g_PlayerFuncs.SayText(plr, "GOB debugging is now ON\n");
	}		
	
}

HookReturnCode ClientDisconnect( CBasePlayer@ plr )
{
	if(plr.entindex() == g_debugPlr)
		g_debugPlr = -1;
	
	
	return HOOK_CONTINUE;
}