void PluginInit(){
	g_Module.ScriptInfo.SetAuthor( "Nexy" );
	g_Module.ScriptInfo.SetContactInfo( "steamcommunity.com/id/nexytpowa" );
	
	g_Hooks.RegisterHook(Hooks::Player::PlayerKilled, @OnPlayerKilled);
}

HookReturnCode OnPlayerKilled(CBasePlayer@ pPlayer, CBaseEntity@ pAttacker, int iGib)
{	
	if(iGib != 2) //2 = gibbed
		pPlayer.pev.origin = pPlayer.pev.origin + Vector(0,0,20);
	
	return HOOK_CONTINUE;
}