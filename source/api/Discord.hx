package api;

#if desktop
import Sys;
import flixel.util.FlxStringUtil;
import hxdiscord_rpc.Discord;
import hxdiscord_rpc.Types;
import lime.app.Application;
import sys.thread.Thread;

/**
 * The type of RPC the Discord RPC should use.
 */
enum RPCType
{
	NORMAL(stats:Bool, time:Bool);
	PAUSED;
	GAMEOVER;
	CUSTOM(details:String, ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float, largeImageKey:String);
}

/**
 * Handles the API for adding, and changing Discord Rich Presence.
 */
class DiscordClient
{
	/**
	 * The ID of the app on the discord developers site.
	 */
	private inline static final _defaultID:String = '879181607666327553';

	/**
	 * The ID this client uses to connect to Discord.
	 */
	public static var clientID(default, set):String = '879181607666327553';
	
	/**
	 * Whether the game running right now is a dev build, and isn't supposed to be public.
	 * Changes the rich presence to make sure nothing is leaked through it.
	 */
	public static var devBuild:Bool = false;

	/**
	 * Is the client initalized yet?
	 */
	public static var isInitialized:Bool = false;


	/**
	 * The current instance of the rich presence.
	 */
	private static var presence:DiscordPresence = new DiscordPresence();

	/**
	 * The thread this RPC uses to help update it.
	 */
	// hides this field from scripts and reflection in general
	@:unreflective private static var __thread:Thread;

	/**
	 * Prepares the RPC client to be ready to used.
	 */
	public static function prepare()
	{
		if (!isInitialized)
			initialize();

		Application.current.window.onClose.add(function()
		{
			if (isInitialized)
				shutdown();
		});
	}

	/**
	 * Shuts down the RPC client.
	 * Dynamic function so it can easily be changed in-case you want custom functionality.
	 */
	public dynamic static function shutdown()
	{
		isInitialized = false;
		Discord.Shutdown();
	}

	/**
	 * Called when the RPC client is ready to be used.
	 * @param request Information about the client.
	 */
	private static function onReady(request:cpp.RawConstPointer<DiscordUser>):Void
	{
		final user = cast(request[0].username, String);
		final discriminator = cast(request[0].discriminator, String);

		var message = 'Connected to User ';
		if (discriminator != '0') // Old discriminators
			message += '($user#$discriminator)';
		else // New Discord IDs/Discriminator system
			message += '($user)';

		log(message);
		changePresence();
	}

	/**
	 * Called when the RPC client reaches an error.
	 * @param errorCode The code for the error.
	 * @param message The error message.
	 */
	private static function onError(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		log('Discord: Error ($errorCode: ${cast (message, String)})');
	}

	/**
	 * Called when the client disconnects.
	 * @param errorCode The code for the error.
	 * @param message The error message relating to the disconnect.
	 */
	private static function onDisconnected(errorCode:Int, message:cpp.ConstCharStar):Void
	{
		log('Discord: Disconnected ($errorCode: ${cast (message, String)})');
	}

	/**
	 * Initalizes the client to be ready to use in-game.
	 */
	public static function initialize()
	{
		var discordHandlers:DiscordEventHandlers = new DiscordEventHandlers();
		discordHandlers.ready = cpp.Function.fromStaticFunction(onReady);
		discordHandlers.disconnected = cpp.Function.fromStaticFunction(onDisconnected);
		discordHandlers.errored = cpp.Function.fromStaticFunction(onError);
		Discord.Initialize(clientID, cpp.RawPointer.addressOf(discordHandlers), true, null);

		if (!isInitialized)
			log("Discord Client initialized");

		if (__thread == null)
		{
			__thread = Thread.create(() ->
			{
				while (true)
				{
					if (isInitialized)
					{
						#if DISCORD_DISABLE_IO_THREAD
						Discord.UpdateConnection();
						#end
						Discord.RunCallbacks();
					}

					// Wait 1 second until the next loop...
					Sys.sleep(1.0);
				}
			});
		}
		isInitialized = true;
	}

	/**
	 * Changes, and displays the rich presence shown on Discord.
	 * @param details The details for the presence.
	 * @param state The current state of the presence.
	 * @param smallImageKey The image that displays on the bottom-right of the rich presence.
	 * @param hasStartTimestamp Whether the RPC should be given a start timestamp of the current time.
	 * @param endTimestamp The ending of the timestamp. Gets added onto the start timestamp.
	 * @param largeImageKey The large image that's displayed in the rich presence.
	 */
	public static function changePresence(details:String = 'In the Menus', ?state:String, ?smallImageKey:String, ?hasStartTimestamp:Bool, ?endTimestamp:Float,
			largeImageKey:String = 'icon_logo')
	{
		var startTimestamp:Float = 0;
		if (hasStartTimestamp)
			startTimestamp = Date.now().getTime();
		if (endTimestamp > 0)
			endTimestamp = startTimestamp + endTimestamp;

		if (!devBuild)
		{
			presence.state = state;
			presence.details = details;
			presence.smallImageKey = smallImageKey;
			presence.largeImageKey = largeImageKey;
			presence.largeImageText = "Vs. Dave and Bambi";

			// Obtained times are in milliseconds so they are divided so Discord can use it
			presence.startTimestamp = Std.int(startTimestamp / 1000);
			presence.endTimestamp = Std.int(endTimestamp / 1000);
			updatePresence();
		}
		else
		{
			presence.state = 'NO LEAKS';
			presence.details = 'Sorry';
			presence.smallImageKey = 'dave';
			presence.largeImageKey = 'icon_logo';
			presence.largeImageText = "Vs. Dave and Bambi";
			// Obtained times are in milliseconds so they are divided so Discord can use it
			presence.startTimestamp = Std.int(startTimestamp / 1000);
			presence.endTimestamp = Std.int(endTimestamp / 1000);
			updatePresence();
		}

		// log('Discord RPC Updated. Arguments: $details, $state, $smallImageKey, $hasStartTimestamp, $endTimestamp, $largeImageKey');
	}

	public static function updatePresence()
	{
		Discord.UpdatePresence(cpp.RawConstPointer.addressOf(presence.__presence));
	}

	inline public static function resetClientID()
	{
		clientID = _defaultID;
	}

	private static function set_clientID(newID:String)
	{
		var change:Bool = (clientID != newID);
		clientID = newID;

		if (change && isInitialized)
		{
			shutdown();
			initialize();
			updatePresence();
		}
		return newID;
	}

	/**
	 * Gets the icon to be used for the rich presence based on the given song, and character.
	 * @param song The song to check.
	 * @param char The character to check
	 * @return The icon that should be used in the rich presence.
	 */
	public static function getSongIcon(song:String, char:String):String
	{
		var iconRPC = '';
		iconRPC = switch (char)
		{
			case 'dave', 'dave-annoyed', 'dave-angey', '': 'dave';
			case 'bambi-new' | 'bambi-joke' | 'bambi-joke-mad': 'bambi';
			case 'tristan', 'tristan-opponent': 'tristan';
			case 'playrobot': 'playrobot';
			default: char;
		}
		iconRPC = switch (song.toLowerCase())
		{
			case 'splitathon':
				iconRPC = 'the-duo';
			case 'backseat':
				iconRPC = 'the-duo2';
			default: iconRPC;
		}
		return iconRPC;
	}
	
	static function log(message:String):Void
	{
		trace(' DISCORD '.bg_index(17).bright_blue().bold().italic() + ' ' + message);
	}
}

@:allow(util.Discord.DiscordClient)
private final class DiscordPresence
{
	public var state(get, set):String;
	public var details(get, set):String;
	public var smallImageKey(get, set):String;
	public var largeImageKey(get, set):String;
	public var largeImageText(get, set):String;
	public var startTimestamp(get, set):Int;
	public var endTimestamp(get, set):Int;

	@:noCompletion public var __presence:DiscordRichPresence;

	public function new()
	{
		__presence = new DiscordRichPresence();
	}

	@:noCompletion inline function get_state():String
	{
		return __presence.state;
	}

	@:noCompletion inline function set_state(value:String):String
	{
		return __presence.state = value;
	}

	@:noCompletion inline function get_details():String
	{
		return __presence.details;
	}

	@:noCompletion inline function set_details(value:String):String
	{
		return __presence.details = value;
	}

	@:noCompletion inline function get_smallImageKey():String
	{
		return __presence.smallImageKey;
	}

	@:noCompletion inline function set_smallImageKey(value:String):String
	{
		return __presence.smallImageKey = value;
	}

	@:noCompletion inline function get_largeImageKey():String
	{
		return __presence.largeImageKey;
	}

	@:noCompletion inline function set_largeImageKey(value:String):String
	{
		return __presence.largeImageKey = value;
	}

	@:noCompletion inline function get_largeImageText():String
	{
		return __presence.largeImageText;
	}

	@:noCompletion inline function set_largeImageText(value:String):String
	{
		return __presence.largeImageText = value;
	}

	@:noCompletion inline function get_startTimestamp():Int
	{
		return __presence.startTimestamp.toInt();
	}

	@:noCompletion inline function set_startTimestamp(value:Int):Int
	{
		return cast(__presence.startTimestamp = value, Int);
	}

	@:noCompletion inline function get_endTimestamp():Int
	{
		return __presence.endTimestamp.toInt();
	}

	@:noCompletion inline function set_endTimestamp(value:Int):Int
	{
		return cast(__presence.endTimestamp = value, Int);
	}
}
#end