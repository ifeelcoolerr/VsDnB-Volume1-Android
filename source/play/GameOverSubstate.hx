package play;

import backend.Conductor;
import data.song.SongRegistry;
import data.song.SongData.SongMusicData;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flash.system.System;
import lime.app.Application;
import openfl.utils.AssetType;
import play.character.Character;
import play.song.Song;
import scripting.events.ScriptEventDispatcher;
import scripting.events.ScriptEvent;
import ui.MusicBeatSubstate;
import ui.debug.AnimationDebug;
import ui.menu.freeplay.FreeplayState;
import ui.menu.story.StoryMenuState;
import util.tools.Preloader;

/**
 * A sub-menu that's shown whenever the user gets a game over.
 */
class GameOverSubstate extends MusicBeatSubstate
{
	
	/**
	 * A suffix used for to customize the song used that's used for the game over theme.
	 */
	public static var musicSuffix:String = '';

	/**
	 * A suffix used for customizing the SFX that plays in the game over.
	 */
	public static var deathSuffix:String = '';
	
	/**
	 * Whether the sub-state is being closed right now.
	 */
	var isEnding:Bool = false;

	/**
	 * The player character that got a game over.
	 */
	var bf:Character;
	
	/**
	 * An empty object for the camera to follow.
	 */
	var camFollow:FlxObject;


	public function new(x:Float, y:Float, char:Character)
	{
		super();

		// Reset the parameters just in case.
		// These get set in the death character's script file.
		reset();

		var deathChar:String = char.skins.get('deathSkin');

		bf = Character.create(x, y, deathChar, CharacterType.PLAYER);
		
		if (!bf.animation.exists('firstDeath'))
		{
			bf.destroy();
			bf = null;

			bf = Character.create(x, y, 'bf-dead', CharacterType.PLAYER);
		}
		bf.isDead = true;
		add(bf);

		camFollow = new FlxObject(bf.cameraFocusPoint.x, bf.cameraFocusPoint.y, 1, 1);
		add(camFollow);

		FlxG.camera.alpha = 1;
		FlxG.camera.filters = [];
		FlxG.camera.scroll.set();
		FlxG.camera.target = null;

		var hasMusicDataFile:Bool = SongRegistry.instance.hasMusicDataFile('game-over', musicSuffix);
		
		// If a variation exists for this game over variation, retrieve that, else just fallback to the default.
		var musicData:SongMusicData = SongRegistry.instance.loadMusicDataFile('game-over', hasMusicDataFile ? musicSuffix : '');
		musicSuffix = hasMusicDataFile ? musicSuffix : '';
		
		Conductor.instance.applyMusicData(musicData);

		// Cache the game over music.
		var gameOverMusic = Paths.music('gameOver/gameOver${Song.validateVariationPath(musicSuffix)}');
		var deathSfx = Paths.sound('death/fnf_loss_sfx' + deathSuffix, 'shared');

		Preloader.cacheSound(Paths.soundPath('gameOver/gameOver${Song.validateVariationPath(musicSuffix)}-end', 'music/', AssetType.MUSIC));
		
		SoundController.play(deathSfx);
		
		bf.playAnim('firstDeath', true);
		bf.animation.onFinish.add((anim:String) -> 
		{
			if (anim == 'firstDeath')
			{
				bf.playAnim('deathLoop', true);
				SoundController.playMusic(gameOverMusic);
			}
		});
		
		FlxG.camera.follow(camFollow, LOCKON, 0.01);
	}

	override function create():Void
	{
		super.create();

		#if mobileC
		addVirtualPad(NONE, A_B);
		addVirtualPadCamera();
        #end
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.ACCEPT)
			endBullshit();

		if (controls.BACK)
		{
			SoundController.playMusic(Paths.music('freakyMenu'));
			Conductor.instance.loadMusicData('freakyMenu');

			Application.current.window.title = Main.applicationName;

			if (PlayStatePlaylist.isStoryMode)
				FlxG.switchState(() -> new StoryMenuState());
			else
				FlxG.switchState(() -> new FreeplayState());
		}
		if (FlxG.keys.justPressed.SEVEN)
		{
			FlxG.switchState(() -> new AnimationDebug(bf));
		}
		Conductor.instance.update();
	}

	override function destroy():Void
	{
		// Remove cached audio to save memory.
		Preloader.removeCachedSound(Paths.soundPath('gameOver/gameOver${Song.validateVariationPath(musicSuffix)}', 'music/', MUSIC));
		Preloader.removeCachedSound(Paths.soundPath('gameOver/gameOver${Song.validateVariationPath(musicSuffix)}-end', 'music/', MUSIC));
		Preloader.removeCachedSound(Paths.soundPath('death/fnf_loss_sfx' + deathSuffix));
		
		// Reset GameOver substate properties after this state has been exited.
		reset();

		super.destroy();
	}

	public override function dispatchEvent(event:ScriptEvent):Void
	{
		super.dispatchEvent(event);

		ScriptEventDispatcher.callEvent(bf, event);
	}

	function endBullshit():Void
	{
		if (!isEnding)
		{
			isEnding = true;
			bf.playAnim('deathConfirm', true);
			SoundController.music.stop();
			SoundController.play(Paths.music('gameOver/gameOver${Song.validateVariationPath(musicSuffix)}-end'));
			new FlxTimer().start(0.7, function(tmr:FlxTimer)
			{
				FlxG.camera.fade(FlxColor.BLACK, 2, false, function()
				{
					LoadingState.loadPlayState(PlayState.lastParams, true);
				});
			});
		}
	}
	
	/**
	 * Reset the properties of the game over state.
	 */
	public static function reset():Void
	{
		musicSuffix = '';
		deathSuffix = '';
	}
}