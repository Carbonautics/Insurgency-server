#include <sourcemod>
#include <sdktools>

public Plugin:myinfo = {
    name = "[INS] Welcome Message",
    description = "Welcome message upon joining",
    author = "Neko-",
    version = "1.0.0",
};

public OnClientPostAdminCheck(client)
{
	PrintToChat(client, "\x0759b0f9[=F|A=] \x01Welcome To The Server! Type 'rules' into the console for our rules!");
	PrintToChat(client, "\x0759b0f9[=F|A=] \x01Our Website: http://fearless-assassins.com");
	PrintToChat(client, "\x0759b0f9[=F|A=] \x01Discord: http://discord.clan-fa.com");
    PrintToChat(client, "\x0759b0f9[=F|A=] \x03!info in Chat for more info");
}