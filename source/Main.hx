package;

import audio.GameSoundTray;
import backend.debug.FPSDisplay;
import flixel.FlxG;
import flixel.FlxGame;
import flixel.FlxState;
import graphics.GameCameraFrontEnd;
import openfl.Lib;
import openfl.events.Event;
import openfl.display.Sprite;
import openfl.text.TextFormat;

import ui.intro.InitState;

#if desktop
import api.ALSoftConfig; // Longest yeah boi ever
#end

#if android
import util.AndroidUtil;
#end

class Main extends Sprite
{
	public static var VERSION:String = '1.0.9';
	
	public static var frameRate:Int = 144;

	var gameWidth:Int = 1280;
	var gameHeight:Int = 720;
	
	var initialState:Class<FlxState> = InitState;
	var zoom:Float = -1;

	var startFullscreen:Bool = false;

	public static var fps:FPSDisplay;

	public static var applicationName:String = "VS. Dave and Bambi";

	public static function main():Void
	{
		Lib.current.addChild(new Main());
	}

	public function new()
	{
		super();
		AndroidUtil.uncaughtErrorHandler();
		stage != null ? init() : addEventListener(Event.ADDED_TO_STAGE, init);
	}

	private function init(?E:Event):Void
	{
		if (hasEventListener(Event.ADDED_TO_STAGE))
			removeEventListener(Event.ADDED_TO_STAGE, init);

		setupGame();
	}

	public static function toggleFuckedFPS(toggle:Bool)
	{
		fps.fuckFps = toggle;
	}

	private function setupGame():Void
	{
		modding.PolymodManager.initalize();

		fps = new FPSDisplay(10, 3, 0xFFFFFF);
		var fpsFormat = new TextFormat("Comic Sans MS Bold", 15, 0xFFFFFF, true);
		fps.defaultTextFormat = fpsFormat;

		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		#if mobile
		gameWidth = 1280;
		gameHeight = 720;
		zoom = 1;
		#end

		if (zoom == -1)
		{
			var ratioX:Float = stageWidth / gameWidth;
			var ratioY:Float = stageHeight / gameHeight;
			zoom = Math.min(ratioX, ratioY);
			gameWidth = Math.ceil(stageWidth / zoom);
			gameHeight = Math.ceil(stageHeight / zoom);
		}
		var game = new FlxGame(gameWidth, gameHeight, initialState, #if (flixel < "5.0.0") zoom, #end frameRate, frameRate, true, startFullscreen);

		@:privateAccess
		game._customSoundTray = GameSoundTray;

		@:privateAccess
		untyped FlxG.cameras = new GameCameraFrontEnd();

		#if android
		AndroidUtil.checkFiles();
		#end

		addChild(game);
		addChild(fps);

		#if android
		FlxG.android.preventDefaultKeys = [BACK];
		#end
	}
}
