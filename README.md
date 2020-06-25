# HighOnSkins SourceMod plugin

This is the official SourceMod plugin for [highonskins.com](https://highonskins.com), a global network that allows CS:GO players to build their own custom CS:GO inventory which is consistently available across all participating game servers.

Gloves skins, knife skins and weapon skins are supported.

You can check this [demo video](https://www.youtube.com/watch?v=mRRvWAZ5tX0).

# Installation

### 1. Get yourself some Steam game server tokens

You should never use this plugin with your own [Steam game server tokens](https://steamcommunity.com/dev/managegameservers). Never! Steam does not like everyone to benefit from free skins. They will permanently ban all your game server tokens and you will not be able to create new ones.

But there is an easy solution for this: [csgotokens.com](https://csgotokens.com) provides an awesome service. You can buy tokens for your CS:GO server there. Those tokens will get banned every 2-3 days but that's not an issue because csgotokens provides you with a plugin that automatically uses a brand new token everytime that your current token gets banned. Tokens for one whole month will cost you about $2. Awesome, isn't it?

### 2. Download the plugin

You bought some game server tokens? Okay, nice! The next step is to [download this repository](https://github.com/chescos/highonskins-sm/archive/master.zip) and extract the .zip file.

### 3. Configure the plugin

Now you need to configure the plugin. Navigate to *cfg/sourcemod* and open the file *hos.cfg* with a text editor. The plugin needs an API key to work. Go to [highonskins.com](https://highonskins.com) and login with your Steam account. Then navigate to [this page](https://highonskins.com/account/apikey) and create your API key. Copy the API key and use it as the value for the variable `sm_hos_apikey` inside the file *hos.cfg*.

The rest of the configuration is up to you. Note that setting `sm_hos_spawnweapons` to `1` will allow players to equip any weapon through the HighOnSkins web interface, at any time. It is recommended to only enable this feature on fun servers.

### 4. Upload files to your CS:GO server

After providing the config file with your API key, you can now upload the files to your game server. You only need to upload the *addons* and the *cfg* folder, they go into the game root folder (usually called *csgo*) of your server.

### 5. Change the SourceMod config

On your game server, navigate to *addons/sourcemod/configs* and open the file *core.cfg*. Search for `FollowCSGOServerGuidelines` and set it to `no`. Save and close the file.

### 6. Restart your server and test the plugin

The plugin will require a server restart in order to work. After your server has been restarted, you can go to [your inventory](https://highonskins.com/inventory), select some skins and see if everything works as intended.

# Updates

This plugin uses [Updater](https://forums.alliedmods.net/showthread.php?t=169095) for automatic plugin updates, so you don't need perform any updates manually. It is not needed but highly recommended. If you do not use it, please make sure to regularily check for updates in this repository. HighOnSkins is a fairly new project and there will be plenty of patches and bug fixes, as well as backwards-incompatibel API changes. We would be happy if you do not remove the updater plugin, so we can offer a better service for you and your players.

# Requirements

All requirements are already included in the repository, you don't need to download and install them yourself.

* [SteamWorks](https://forums.alliedmods.net/showthread.php?t=229556) - Used for communication with the HighOnSkins API
* [Socket](https://forums.alliedmods.net/showthread.php?t=67640) - Used for live updates from HighOnSkins
* [SMJansson](https://forums.alliedmods.net/showthread.php?t=184604) - Used for JSON encoding and decoding
* [Updater](https://forums.alliedmods.net/showthread.php?t=169095) - Used for automatic plugin updates


# Debugging

You can set the console variable `debug_hos` to `32` and the plugin will log detailed messages to *addons/sourcemod/logs/debug_hos.log*. The plugin uses Dr. McKay's logdebug implementation, more information can be found at the [AlliedMods thread](https://forums.alliedmods.net/showthread.php?t=258855).

# ConVars

* **sm_hos_apikey** - API key from highonskins.com (DEFAULT: "")
* **sm_hos_instaskins** - Enable or disable that live updates can give players new weapons. (0 = disabled, 1 = enabled, DEFAULT: 0)

# Commands

Skins can only be selected on highonskins.com, there is no in-game menu.

Following commands will open an in-game browser popup that display the HighOnSkins inventory page:

* !ws
* !hos
* !knife
* !gloves
* !skins

**Note:** You can also use `SHIFT` + `TAB` to open the Steam overlay, click on *WEB BROWSER* at the bottom and then navigate to highonskins.com. This results in a better user experience because the website will stay open in the background and you can then select your skins much easier and faster.
