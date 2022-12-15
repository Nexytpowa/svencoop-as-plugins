//Blocks players from using annoying playermodels

const string g_ReplacementModel = "scientist"; //Replace the annoying player model by kleiner



const string g_Blacklist = "scripts/plugins/cfg/PlayerModel_Blacklist.txt";
dictionary g_BlockedModels;
int g_asyncPlayerItt = 0;

void PluginInit()
{
	g_Module.ScriptInfo.SetAuthor( "Nexy" );
	g_Module.ScriptInfo.SetContactInfo( "steamcommunity.com/id/nexytpowa" );

	ReadBlacklist();
	g_Scheduler.SetInterval("BlockPlayerModels", 0.100f);
}

void ReadBlacklist()
{
	File@ file = g_FileSystem.OpenFile(g_Blacklist, OpenFile::READ);
	if (file !is null && file.IsOpen())
	{
		while (!file.EOFReached())
		{
			string sLine;
			file.ReadLine(sLine);

			if (sLine.SubString(0, 1) == "#" || sLine.IsEmpty())
				continue;

            g_BlockedModels[sLine.ToLowercase()] = true;
		}
		file.Close();
    }
}

void CheckPlayerModel(CBasePlayer@ pPlayer )
{
    if(pPlayer !is null)
    {
        if(pPlayer.edict() !is null)
        {
            KeyValueBuffer@ kvBuffer = g_EngineFuncs.GetInfoKeyBuffer(pPlayer.edict());
            string model = kvBuffer.GetValue("model");

            if(g_BlockedModels.exists(model.ToLowercase()))
            {
                kvBuffer.SetValue("model", g_ReplacementModel);
            }
        }
    }
}

void BlockPlayerModels()
{
    if(g_asyncPlayerItt >= g_Engine.maxClients)
        g_asyncPlayerItt = 0;

    CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(g_asyncPlayerItt);
    CheckPlayerModel(pPlayer);

    g_asyncPlayerItt++;
}



