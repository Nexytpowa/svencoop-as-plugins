//Gives you the ability to fake your death
//TODO:
// - get a life lel

bool g_enabled = true;
bool g_disableWhenSolo = false;
const float g_fdDelay = 0.6f; //delay between user laying on the ground and fake death
const float g_yawRange = 20.f; //left-right cam movement freedom;
const string g_deathSound = "hgrunt/gr_pain4.wav";

const string g_Banlist = "scripts/plugins/cfg/FD_mapbans.txt";
dictionary g_BannedMaps;
bool g_mapIsBanned = false;

array<int> g_player_buttons(33);
array<float> g_player_yaw(33);
array<float> g_player_afk(33);
array<float> g_player_lastdeath(33);
array<bool> g_player_fakedeath(33);

array<EHandle> g_player_sprite(33);
dictionary spr_keys;
string fd_spr = "sprites/sc_mazing/ase.spr";

int g_playersAlive = 0;


CClientCommand g_FakeDeath("fakedeath", "Fake your death!", @fakedeath);
CClientCommand g_ToggleDeath("toggle_fakedeath", "Enable fake death", @toggle_fakedeath);

void PluginInit(){
	g_Module.ScriptInfo.SetAuthor( "Nexy" );
	g_Module.ScriptInfo.SetContactInfo( "steamcommunity.com/id/nexytpowa" );
	
	if(g_enabled)
		setupHooks();
		
	setupBanlist();
	CountLivePlayers();
	g_mapIsBanned = g_BannedMaps.exists(g_Engine.mapname);
	
	spr_keys["model"] = fd_spr;
	spr_keys["rendermode"] = "4";
	spr_keys["renderamt"] = "70";
	spr_keys["rendercolor"] = "255 255 255";
	spr_keys["framerate"] = "10";
	spr_keys["scale"] = ".07";
	spr_keys["spawnflags"] = "1";
	
}

void MapInit() 
{
	g_SoundSystem.PrecacheSound(g_deathSound);
	g_Game.PrecacheModel(fd_spr);

	//Testing the way w00t clears his arrays
	g_player_afk.resize(0);
	g_player_afk.resize(33);
	g_player_fakedeath.resize(0);
	g_player_fakedeath.resize(33);
	g_player_lastdeath.resize(0);
	g_player_lastdeath.resize(33);
	
	if(g_enabled)
		setupHooks();
}

void MapActivate()
{
	g_playersAlive = 0;
	CountLivePlayers();
	g_Scheduler.SetInterval("CountLivePlayers", 15.0);
	
	g_mapIsBanned = g_BannedMaps.exists(g_Engine.mapname);
	g_Scheduler.SetTimeout("MapBanCheck", 5.0); //to be sure
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

void setupHooks()
{
	g_Hooks.RegisterHook(Hooks::Player::PlayerPreThink, @PlayerPreThink);
	//g_Hooks.RegisterHook(Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage);
	g_Hooks.RegisterHook(Hooks::Player::PlayerKilled, @PlayerDead);
	g_Hooks.RegisterHook(Hooks::Player::ClientSay, @ClientSay);
	g_Hooks.RegisterHook(Hooks::Player::PlayerSpawn, @PlayerSpawn);
}

void removeHooks()
{
	g_Hooks.RemoveHook(Hooks::Player::PlayerPreThink, @PlayerPreThink);
	//g_Hooks.RemoveHook(Hooks::Player::PlayerTakeDamage, @PlayerTakeDamage);
	g_Hooks.RemoveHook(Hooks::Player::PlayerKilled, @PlayerDead);
	g_Hooks.RemoveHook(Hooks::Player::ClientSay, @ClientSay);
	g_Hooks.RemoveHook(Hooks::Player::PlayerSpawn, @PlayerSpawn);
}

void MapBanCheck()
{
	g_mapIsBanned = g_BannedMaps.exists(g_Engine.mapname);
}

void CountLivePlayers()
{
	g_playersAlive = 0;
	for ( int i = 1; i <= g_Engine.maxClients; i++ )
	{
		CBasePlayer@ p = g_PlayerFuncs.FindPlayerByIndex(i);
		
		if (p is null or !p.IsConnected())
			continue;
			
		if (p.IsAlive())
			g_playersAlive++;
	}
}



//Scheduled function to use after player sends message
//sending a chat message resets your classify kv
void ResetClassify(int idx)
{
	CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(idx);
	
	
	if(g_player_fakedeath[idx]) //Recheck incase player spams command during the small interval
		plr.pev.flags = plr.pev.flags | FL_NOTARGET;
}

void ForceUnblock(int idx)
{
	CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(idx);
	if(plr is null || !plr.IsConnected())
		return;
	
	if(g_Engine.time - g_player_lastdeath[idx] < 2.5)
		plr.UnblockWeapons(plr);
}

void ForceCommand(CBasePlayer@ plr, string command)
{
	NetworkMessage msg(MSG_ONE, NetworkMessages::SVC_STUFFTEXT, plr.edict());
		msg.WriteString( command );
	msg.End();
}

void resetFD(CBasePlayer@ plr, int idx)
{
	if(!g_player_fakedeath[idx])
		return;
		
	plr.UnblockWeapons(plr);
	
	plr.pev.flags = plr.pev.flags & ~FL_NOTARGET;
	g_PlayerFuncs.SayText(plr, "You are no longer faking death.\n");
	ForceCommand(plr, ".e off");
	g_player_fakedeath[idx] = false;
	
	DetachFDSprite(plr);
}

void ResetEnemyTarget(EHandle hPlr)
{
	CBasePlayer@ plr = cast<CBasePlayer@>(hPlr.GetEntity());
	if(plr is null or !plr.IsConnected())
		return;
	if(!g_player_fakedeath[plr.entindex()])
		return;
	
	int foundCount = g_EntityFuncs.MonstersInSphere( @pEnts, plr.pev.origin, 3000 );

	for(int i = 0; i < foundCount; ++i)
	{
		//string classname = pEnts[i].pev.classname; classname.Find("nade") != String::INVALID_INDEX
		CBaseMonster@ pEnt = cast<CBaseMonster@>(pEnts[i]);
		CBaseEntity@ pTarget = pEnt.m_hTargetEnt.GetEntity();
		
		if(pEnt !is null && !pEnt.IsPlayerAlly() && pTarget !is null && pTarget == plr )
		{		
			pEnt.m_hTargetEnt = null;
			//g_PlayerFuncs.SayTextAll(null, ""+pEnt.m_MonsterState);
		}
	}
}




void DetachFDSprite(CBasePlayer@ plr)
{
	EHandle spr = g_player_sprite[plr.entindex()];
	if(spr.IsValid())
		g_EntityFuncs.Remove(spr);
}

void AttachFDSprite(CBasePlayer@ plr)
{
	CBaseEntity@ spr = g_EntityFuncs.CreateEntity("env_sprite", spr_keys, true);
	spr.pev.movetype = MOVETYPE_FOLLOW;
	@spr.pev.aiment = @plr.edict();
	
	g_player_sprite[plr.entindex()] = EHandle(spr);
}





void startDeath(int idx)
{
	CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(idx);
	if(g_Engine.time - g_player_afk[idx] < g_fdDelay + 0.9f || !plr.IsAlive())
		return;
		
	//g_EntityFuncs.DispatchKeyValue(plr.edict(), "classify", -1);
	plr.pev.flags = plr.pev.flags | FL_NOTARGET;
	plr.BlockWeapons(plr);	
	
	g_PlayerFuncs.SayText(plr, "You are now faking death...\n");
	g_player_fakedeath[idx] = true;
	
	
	AttachFDSprite(plr);
}

CBaseEntity@[] pEnts(128);
void startLaying(int idx)
{
	CBasePlayer@ plr = g_PlayerFuncs.FindPlayerByIndex(idx);
	if(plr is null || !plr.IsConnected() || !plr.IsAlive())
		return;
		
	if(g_Engine.time - g_player_afk[idx] < 0.9f)
		return;
		
	//Cancel fakedeath if theres enemies too close so they don't abuse it around corners
	int closeCount = g_EntityFuncs.MonstersInSphere( @pEnts, plr.pev.origin, 400 );
	
	for(int i = 0; i < closeCount; ++i)
	{
		//string classname = pEnts[i].pev.classname; classname.Find("nade") != String::INVALID_INDEX
		CBaseMonster@ pEnt = cast<CBaseMonster@>(pEnts[i]);
		CBaseEntity@ pTarget = pEnt.m_hEnemy.GetEntity();
		
		if(pEnt !is null && !pEnt.IsPlayerAlly() && pTarget !is null && pTarget == plr )
		{		
			g_PlayerFuncs.SayText(plr, "You cannot fakedeath too close to enemies!");
			return;
		}
	}
	
	//Find enemies around the player and force them to move to player even if faking death
	int foundCount = g_EntityFuncs.MonstersInSphere( @pEnts, plr.pev.origin, 1500 );
	
	for(int i = 0; i < foundCount; ++i)
	{
		//string classname = pEnts[i].pev.classname; classname.Find("nade") != String::INVALID_INDEX
		CBaseMonster@ pEnt = cast<CBaseMonster@>(pEnts[i]);
		CBaseEntity@ pTarget = pEnt.m_hEnemy.GetEntity();
		
		if(pEnt !is null && !pEnt.IsPlayerAlly() && pTarget !is null && pTarget == plr )
		{		
			pEnt.m_hTargetEnt = EHandle( plr );
		}
	}
	
	ForceCommand(plr, ".e oof freeze");	
	g_Scheduler.SetTimeout("ResetEnemyTarget", 20.0f, EHandle(plr));
	//
	
	g_Scheduler.SetTimeout("startDeath", g_fdDelay, idx);
}




void fakedeath(const CCommand@ pArgs)
{
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	int idx = plr.entindex();
	
	if(!g_enabled)
	{
		g_PlayerFuncs.SayText(plr, "FakeDeath plugin is currently not enabled.\n");
		return;
	}
	if(g_mapIsBanned)
	{
		g_PlayerFuncs.SayText(plr, "FakeDeath is currently restricted on this map.\n");
		return;
	}
	
	if(g_playersAlive <= 1 && g_disableWhenSolo)
	{
		g_PlayerFuncs.SayText(plr, "Cannot fake death when there's only 1 player alive");
		return;
	}
	
	if(plr.GetWeaponsBlocked() || !plr.IsAlive() || plr.m_afButtonLast != 0)
		return;
	
	if(g_Engine.time - g_player_lastdeath[idx] > 5.0f)
		g_SoundSystem.PlaySound(plr.edict(), CHAN_AUTO, g_deathSound, 0.7f, 0.4f, 0, 115);
	else
		return;

	g_player_lastdeath[idx] = g_Engine.time;
	
	ForceCommand(plr, ".e oof");
	
	g_Scheduler.SetTimeout("startLaying", 1.0, idx);
}

void toggle_fakedeath(const CCommand@ pArgs)
{
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	if(g_PlayerFuncs.AdminLevel(plr) < ADMIN_YES)
	{
		g_PlayerFuncs.SayText(plr, "You do not have enough permissions to toggle this feature.\n");
		return;
	}
	
	g_enabled = !g_enabled;
	g_PlayerFuncs.SayText(plr, (g_enabled ? "FakeDeath is now ON\n" : "FakeDeath is now OFF\n"));
	if(g_enabled)
	{
		setupHooks();
	}
	else
	{
		removeHooks();
		
		for(int i = 0; i < 33; i++)
		{
			if(!g_player_fakedeath[i])
				continue;
				
			CBasePlayer@ tplr = g_PlayerFuncs.FindPlayerByIndex(i);
			if(tplr is null || !tplr.IsConnected())
				continue;
			
			resetFD(tplr, i);
		}
	}
}







HookReturnCode ClientSay( SayParameters@ pParams )
{
	CBasePlayer@ plr = pParams.GetPlayer();
	int idx = plr.entindex();
	
	if(g_player_fakedeath[idx])
		g_Scheduler.SetTimeout("ResetClassify", 0.1, idx);
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerSpawn( CBasePlayer@ pPlayer)
{
	CountLivePlayers();	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerDead( CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib )
{
	int idx = pPlayer.entindex();
	
	if(g_player_fakedeath[idx])
	{	
		resetFD(pPlayer, idx);
	}
	
	CountLivePlayers();
	
	
	return HOOK_CONTINUE;
}

HookReturnCode PlayerPreThink(CBasePlayer@ plr, uint& out uiFlags)
{	
	int idx = plr.entindex();
	int buttons = (plr.m_afButtonPressed | plr.m_afButtonReleased) & ~32768 & ~32;

	if(buttons != g_player_buttons[idx])
	{
		g_player_afk[idx] = g_Engine.time;
		resetFD(plr, idx);
	}
	g_player_buttons[idx] = buttons;
	
	
	float yaw = abs(plr.pev.v_angle.y);
	if(abs(yaw - g_player_yaw[idx]) > g_yawRange)
	{
		g_player_afk[idx] = g_Engine.time;
		g_player_yaw[idx] = yaw;
		resetFD(plr, idx);
	}
	
	return HOOK_CONTINUE;
}