package util.tools;

import flixel.FlxG;
import flixel.FlxState;
import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.system.FlxAssets.FlxShader;
import flixel.system.FlxAssets.FlxSoundAsset;
import openfl.Assets;
import openfl.display.BitmapData;
import openfl.media.Sound;
import openfl.utils.AssetType;
import openfl.system.System;
import play.notes.NoteStyle;
import play.PlayState;
import play.character.Character;
import ui.menu.ost.OSTMenuState;
import ui.select.charSelect.CharacterSelect;
import ui.select.playerSelect.PlayerSelect;
#if cpp
import cpp.vm.Gc;
#end
#if sys
import sys.FileSystem;
#end
#if android
import util.AndroidUtil;
#end

/**
 * Utility for providing, and management cache for assets.
 * Keeps tracks of the previous cached assets from states, cache purging, and more to prevent memory stacking, and more. 
 */
class Preloader
{
	/**
	 * A list of directories, and asset keys that should NOT be cleared from the cache no matter what.
	 * These are usually assets that are used frequently in-game, and have no reason to be consistently cleared and re-cached.
	 */
	public static final noClear:Array<String> = [
		// These are used in a lot of menus, and are big.
		'assets/images/backgrounds',

		// This is VERY frequently used.
		'assets/images/alphabet.png',

		// This checkered bg is always used when paused.
		'shared:assets/shared/images/checkeredBG.png',

		// Cache default notestyle related directories.
		'shared:assets/shared/images/ui/notes',
		'shared:assets/shared/images/ui/combo',
		'shared:assets/shared/images/ui/countdown/normal',
		
		// Cache UI elements.
		'shared:assets/shared/images/ui/accuracy.png',
		'shared:assets/shared/images/ui/misses.png',
		'shared:assets/shared/images/ui/score.png',
		'shared:assets/shared/images/ui/timer.png',
		'shared:assets/shared/images/ui/timer-3d.png',
		
		'assets/music/freakyMenu.ogg',
	];

	/**
	 * Tracks a list of the last cached graphics.
	 * If a graphic is requested, and is from this list, it'll fetch the entry from here.
	 */
	public static var previousTrackedGraphics:Map<String, FlxGraphic> = [];
	
	/**
	 * Tracks a list of the last cached sound.
	 * If a sound is requested, and is from this list, it'll fetch the entry from here.
	 */
	public static var previousTrackedSounds:Map<String, Sound> = [];

	/**
	 * Tracks a list of all of the currently cached characters.
	 * Used for preloading characters, so when a character is requested its entry is simply fetched from here to prevent lag.
	 */
	public static var trackedCharacters:Map<String, Character> = [];

	/**
	 * The currently tracked graphics that are cached.
	 */
	public static var trackedGraphics:Map<String, FlxGraphic> = [];
	
	/**
	 * The currently tracked sounds that are cached.
	 */
	public static var trackedSounds:Map<String, Sound> = [];

	/**
	 * These states will clear the cache list upon exiting them.
	 * These happen to use up a ton of memory where it would be good to just immediately clear the cache upon exit.
	 */
	public static var clearOnExit:Array<Class<FlxState>> = [
		CharacterSelect,
		PlayerSelect,
		PlayState,
		OSTMenuState,
	];

	/**
	 * Initalizes the Preloader. 
	 * Calls, and initalizes any functions needed for the preloader to work.
	 */
	public static function initalize():Void
	{
		FlxG.signals.preStateSwitch.add(() -> 
		{
			// If we're exiting out of any state from this list, we don't want to keep the song assets in the cache, and any additional ones from the state.
			// We purge the cache entirely to completely free up memory.
			if (clearOnExit.contains(Type.getClass(FlxG.state)))
			{
				clearTrackedCache();
				runGc();

				previousTrackedGraphics = [];
				previousTrackedSounds = [];

				trackedGraphics = [];
				trackedSounds = [];
			}
			else
			{
				// Move the cache to the previous
				moveCacheToPrevious();
				clearTrackedCache();
				runGc();
			}
		});
	}

	/**
	 * Recursively checks through a directory to see if a given key can be removed from the cache.
	 * 
	 * @param keyToCheck The key to check if it can be removed from the cache.
	 * @param absolutePath The path without the library, the directory that's read.
	 * @param library The library this directory is in.
	 * 
	 * @return Whether the key exists within any directory, and thus shouldn't be removed.
	 */
	static function readDirectory(keyToCheck:String, absolutePath:String, library:String):Bool
	{
		var directoryFiles:Array<String> = FileSystem.readDirectory(AndroidUtil.getStorageDirectory() + absolutePath);
		for (file in directoryFiles)
		{
			var fullPath:String = absolutePath + '/' + file;
			var fullLibraryPath:String = '$library:$fullPath';

			// Use the non-library asset path to check if the current iterated item is a directory.
			if (FileSystem.isDirectory(AndroidUtil.getStorageDirectory() + fullPath))
			{
				var value:Bool = readDirectory(keyToCheck, fullPath, library);
				if (!value)
				{
					return false;
				}
			}
			else
			{
				// If the asset path is a file, and is a key from the list.
				// This shouldn't be removed.
				if (fullLibraryPath == keyToCheck)
				{
					return false;
				}
			}
		}
		return true;
	}

	/**
	 * Checks whether a key is able to be removed from the cache.
	 * If the key is in a directory, or an entry from the `noClear` list, it can't be removed.
	 * @param key The key to check.
	 * @return Whether it's able to be removed from the cache, or not.
	 */
	static function canKeyBeRemoved(key:String):Bool
	{
		var keyLibrary:String = Paths.stripLibrary(key);

		// To prevent some unnecessary iterations of directories that don't need to be checked
		// Filter out any entries from the list that aren't from the same library.
		var noClearFilter:Array<String> = noClear.filter((path:String) ->
		{
			path.startsWith(keyLibrary);
		});

		for (assetPath in noClearFilter)
		{
			var library:String = Paths.stripLibrary(assetPath);
			var path:String = Paths.absolutePath(assetPath);

			if (FileSystem.isDirectory(AndroidUtil.getStorageDirectory() + path))
			{
				// The requested path is a directory.
				// We need to recursively check each of the file (and directories if needed)
				// To see if any of the asset paths are the requested key. If so, it shouldn't be removed.
				var value:Bool = readDirectory(key, path, library);
				if (!value)
				{
					return false;
				}
			}
			else
			{	
				// The requested key is from the list, this shouldn't be removed.
				if (assetPath == key)
				{
					return false;
				}
			}
		}
		return true;
	}

	/**
	 * Moves the cache list to the previous cache to be stored for later.
	 */
	public static function moveCacheToPrevious():Void
	{
		// Move the currently tracked graphics to the previous graphics
		previousTrackedGraphics = trackedGraphics;
		previousTrackedSounds = trackedSounds;

		trackedGraphics = [];
		trackedSounds = [];
	}

	/**
	 * Loads, and caches an image graphic to add it into cache list.
	 * Useful for easy preloading, and reusability.
	 * @param key The asset key of the image to cache.
	 * @return The cached graphic.
	 */
	public static function cacheImage(key:FlxGraphicAsset):FlxGraphic
	{
		var graphic:FlxGraphic = null;

		if (key is FlxGraphic)
		{
			var keyGraphic:FlxGraphic = cast key;
			
			graphic = keyGraphic;
			trackedGraphics.set(keyGraphic.assetsKey, graphic);
		}
		else if (key is String)
		{
			if (Assets.exists(key, IMAGE) && !trackedGraphics.exists(key))
			{
				var image:BitmapData = Assets.getBitmapData(key);

				graphic = FlxGraphic.fromBitmapData(image, false, cast key);
				trackedGraphics.set(key, graphic);
			}
		}
		if (graphic != null)
		{
			graphic.persist = true;
			graphic.destroyOnNoUse = false;
		}
		return graphic;
	}

	/**
	 * Loads, and caches a sound asset to add it to it's cache list.
	 * Useful for easy preloading, and reusability.
	 * @param key The asset key of the sound to cache.
	 */
	public static function cacheSound(key:String):Sound
	{
		if (!trackedSounds.exists(key) && Assets.exists(key, SOUND) || Assets.exists(key, MUSIC))
		{
			var sound:Sound = Assets.getSound(key);
			trackedSounds.set(key, sound);
			
			return sound;
		}
		return null;
	}

	/**
	 * Loads, and caches a character, and adds it to it's cache list.
	 * Useful to prevent lag when loading in, or switching a character.
	 * @param charKey The id of the character to cache. 
	 */
	public static function cacheCharacter(charKey:String, type:CharacterType)
	{
		if (trackedCharacters.exists(charKey))
			return;

		var char:Character = Character.create(0, 0, charKey, type);
		trackedCharacters.set(charKey, char);
	}

	/**
	 * Preloads a cache so it doesn't lag when first initalized.
	 * TODO: This doesn't work. Is this able to be done some way else?
	 * @param shader The `FlxShader` asset to cache.
	 */
	public static function cacheShader(shader:FlxShader)
	{
		@:privateAccess {
			shader.__initGL();
		}
	}

	/**
	 * Caches the graphics for the given note style.
	 * @param noteStyle The note style to cache.
	 */
	public static function cacheNoteStyle(noteStyle:NoteStyle)
	{		
		// Cache the NoteStyle graphics so they're easier to load.
		Preloader.cacheImage(noteStyle.path);
		Preloader.cacheImage(noteStyle.strumlinePath);
		Preloader.cacheImage(noteStyle.sustainPath);
	}

	/**
	 * Retrieves a previous asset for it to be re-cached, and used. 
	 * @param key The key of the asset.
	 * @param type The type of the asset.
	 */
	public static function fetchFromPreviousCache(key:String, type:AssetType):Any
	{
		switch (type)
		{
			case IMAGE:
				var graphic:FlxGraphic = previousTrackedGraphics.get(key);

				if (graphic != null)
				{
					previousTrackedGraphics.remove(key);
					trackedGraphics.set(key, graphic);

					return graphic;
				}
			case SOUND, MUSIC:
				var sound:Sound = previousTrackedSounds.get(key);

				if (sound != null)
				{
					previousTrackedSounds.remove(key);
					trackedSounds.set(key, sound);

					return sound;
				}
			default:
				return null;
		}
		return null;
	}

	/**
	 * Removes a cached graphic from it's list.
	 * @param key The asset key of the sound to remove.
	 */
	public static function removeCachedGraphic(key:String):Void
	{
		var graphic = trackedGraphics.get(key);

		if (graphic != null && canKeyBeRemoved(key))
		{
			Assets.cache.removeBitmapData(key);
			FlxG.bitmap.remove(graphic);

			graphic.persist = false;
			graphic.destroyOnNoUse = true;

			trackedGraphics.remove(key);
		}
	}

	/**
	 * Removes a cached sound from it's list.
	 * @param key The asset key of the sound to remove.
	 */
	public static function removeCachedSound(key:String):Void
	{
		if (trackedSounds.exists(key) && canKeyBeRemoved(key))
		{
			var sound = trackedSounds.get(key);
			sound.close();
			
			Assets.cache.removeSound(key);
			Assets.cache.clear(key);

			trackedSounds.remove(key);
		}
	}

	/**
	 * Completely removes, and destroys a cached character from it's list.
	 * @param charKey The id of the character to remove.
	 */
	public static function removeCachedCharacter(charKey:String):Void
	{
		var char:Character = trackedCharacters.get(charKey);

		char.destroy();
		char = null;
		trackedCharacters.remove(charKey);
	}

	/**
	 * Completely clears the internal cache list, and runs the garbage collector.
	 * Useful for freeing up memory, and preventing memory stacking.
	 */
	public static function clearTrackedCache():Void
	{
		/**
		 * CLEAR GRAPHICS
		 */

		for (key in trackedGraphics.keys())
		{
			removeCachedGraphic(key);
		}
		FlxG.bitmap.clearCache();
		FlxG.bitmap.clearUnused();

		trackedGraphics = [];

		
		/**
		 * CLEAR SOUNDS 
		 */

		var soundsPlaying:Array<Sound> = [];
		
		@:privateAccess
		for (s in FlxG.sound.list.members.concat([SoundController.music]))
		{
			if (s == null)
				continue;
			
			if (s.persist && s.playing)
			{
				soundsPlaying.push(s._sound);
			}
			else
			{
				s?.cleanup(false);
				s?.reset();
			}
		}
		for (key in trackedSounds.keys())
		{
			var sound:Sound = trackedSounds.get(key);
			
			if (!soundsPlaying.contains(sound))
			{
				removeCachedSound(key);
			}
		}
		trackedSounds = [];

		/**
		 * CLEAR CHARACTERS
		 */
		 
		for (key in trackedCharacters.keys())
		{
			removeCachedCharacter(key);
		}
		runGc();
	}

	/**
	 * Runs the c++ garbage collector.
	 * Useful for freeing up memory.
	 */
	public static function runGc()
	{
		#if cpp
		Gc.run(true);
		Gc.compact();
		Gc.run(false);
		#end
		System.gc();
	}
}
