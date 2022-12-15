//Slide like in apex when crouching
//v1.1

class PlayerSlide
{
	bool enabled = false;
	bool sliding = false;
	float oldHeight = 0;
	float oldZVel = 0;
	float lastJump = 0;
	float slideStart = 0;
	
	void disableSliding(CBasePlayer@ plr)
	{
		plr.pev.friction = 1.0f;
		sliding = false;
	};
};

array<PlayerSlide> g_player_slide(33);

CClientCommand g_ToggleSlide("toggle_slide", "Enable sliding", @toggle_slide);

void PluginInit(){
	g_Module.ScriptInfo.SetAuthor( "Nexy" );
	g_Module.ScriptInfo.SetContactInfo( "steamcommunity.com/id/nexytpowa" );

	g_Hooks.RegisterHook(Hooks::Player::PlayerPreThink, @PlayerPreThink);
}

void MapInit()
{
	g_player_slide.resize(0);
	g_player_slide.resize(33);
}

void toggle_slide(const CCommand@ pArgs)
{
	CBasePlayer@ plr = g_ConCommandSystem.GetCurrentPlayer();
	int idx = plr.entindex();
	PlayerSlide@ slider = g_player_slide[idx];
	slider.enabled = !slider.enabled;
	
	if(slider.enabled)
		g_PlayerFuncs.SayText(plr, "Sliding enabled!\n");
	else
		g_PlayerFuncs.SayText(plr, "Sliding disabled!\n");
}

HookReturnCode PlayerPreThink(CBasePlayer@ plr, uint& out uiFlags)
{	
	int buttons = plr.m_afButtonPressed | plr.m_afButtonLast;
	int idx = plr.entindex();
	PlayerSlide@ slider = g_player_slide[idx];
	
	if(!slider.enabled || !plr.IsAlive())
		return HOOK_CONTINUE;
	
	if(buttons & IN_DUCK != 0)
	{
		//g_PlayerFuncs.SayTextAll(null, ""+plr.pev.friction);
		TraceResult tr;
		g_Utility.TraceLine( plr.pev.origin + Vector(0,0,5), plr.pev.origin - Vector(0,0,100), ignore_monsters, plr.edict(), tr );
		
		if( tr.flFraction < 0.5f )
		{		
			Vector planeForward = Vector(tr.vecPlaneNormal.x, tr.vecPlaneNormal.y, 0).Normalize();
			Vector velDir = plr.pev.velocity.Normalize();
			
			float planeDot = DotProduct(velDir, planeForward);
			float curSpeed = plr.pev.velocity.Length2D();
			
			//g_PlayerFuncs.SayTextAll(null, ""+curSpeed+" "+slider.FOV);
			//
			
			if(plr.pev.velocity.z == 0 && slider.oldZVel < 0 && curSpeed < 500.f && g_Engine.time - slider.lastJump > 1.2f)
			{
				//g_PlayerFuncs.SayTextAll(null, "Landed! "+curSpeed);
				slider.lastJump = g_Engine.time;
				plr.pev.velocity = plr.pev.velocity - velDir * slider.oldZVel * 0.28f;
				slider.sliding = true;
			}
			
			if(curSpeed < 150.f)
			{
				slider.disableSliding(plr);
			}
			else
			{
				if(slider.sliding)
				{
					float zVel = plr.pev.origin.z - slider.oldHeight;
					float off = (zVel > 0.f ? 0.45f : 0.05f);
					
					if(tr.vecPlaneNormal.z < 0.9995f && planeDot > 0.4f)
					{
						float friction = tr.vecPlaneNormal.z - 0.94f;
						if(friction < -0.07f)
							friction = -0.07f;
							
						plr.pev.friction = friction;
						plr.pev.velocity = plr.pev.velocity * 0.9990f + plr.pev.velocity.Length() * planeForward * 0.001f;
					
					}
					else
					{
						plr.pev.friction = 0.25f;
					}
					
					//g_PlayerFuncs.SayTextAll(null, ""+planeDot);
				}
			}
			
			
			
			slider.oldHeight = plr.pev.origin.z;
			
		}
		slider.oldZVel = plr.pev.velocity.z;
		
	}
	else
	{
		if(slider.sliding)
		{
			slider.disableSliding(plr);
		}
	}
	
	return HOOK_CONTINUE;
}