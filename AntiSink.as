//AntiSink 29/09 v1

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nexy" );
	g_Module.ScriptInfo.SetContactInfo( "steamcommunity.com/id/nexytpowa" );
	
	g_Hooks.RegisterHook(Hooks::Player::PlayerEnteredObserver, @PlayerEnteredObserver);
}

void SinkCheck(int idx)
{
	CBaseEntity@ ent = g_EntityFuncs.Instance(idx);
	if(ent !is null && ent.pev.classname == "deadplayer")
	{
		if(ent.pev.velocity.z < 0)
		{
			ent.pev.origin.z += 5;
			ent.pev.velocity = Vector(0,0,0);
			ent.pev.movetype = MOVETYPE_NOCLIP;
		}
	}
}

CBaseEntity@[] pEnts(256);
void FixBody(CBaseEntity@ plr, float sz)
{	
	Vector boxSize = Vector(sz,sz,sz);
	int foundCount = g_EntityFuncs.EntitiesInBox( @pEnts, plr.pev.origin - boxSize, plr.pev.origin + boxSize, 0 );
		
	for(int i = 0; i < foundCount; ++i)
	{
		if(pEnts[i] !is null && pEnts[i].pev.classname == "deadplayer")
		{
			pEnts[i].pev.movetype = MOVETYPE_FLY;
			pEnts[i].pev.origin.z += 20;
			pEnts[i].pev.velocity.z -= 128.0;
			pEnts[i].pev.solid = 0;
			//pEnts[i].pev.movetype = 0;
			//TraceResult tr;
			//Vector vecSrc = pEnts[i].pev.origin;
			//Vector vecEnd = vecSrc - Vector(0,0,100);
			//g_Utility.TraceLine( vecSrc, vecEnd, ignore_monsters, null, tr );
			//if(pEnts[i].pev.velocity.z < 0 || tr.fStartSolid != 0)
			//{
			//	pEnts[i].pev.origin.z += 5;
			//	pEnts[i].pev.velocity = Vector(0,0,0);
			//	pEnts[i].pev.movetype = MOVETYPE_FLY;
			//	g_Scheduler.SetTimeout("SinkCheck", 0.2f, pEnts[i].entindex());
			//}
		}
	}
}

HookReturnCode PlayerEnteredObserver(CBasePlayer@ plr)
{	
	FixBody(plr, 100.f);
	return HOOK_CONTINUE;
}