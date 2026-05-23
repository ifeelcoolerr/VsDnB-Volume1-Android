package play;

import audio.GameSound;
import data.language.LanguageManager;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxBackdrop;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.typeLimit.NextState;
import graphics.GameCamera;
import lime.app.Application;
import play.PlayStatePlaylist;
import ui.Alphabet;
import ui.Cursor;
import ui.MusicBeatSubstate;
import ui.menu.MainMenuState;
import ui.menu.freeplay.FreeplayState;
import ui.menu.settings.SettingsMenu;
import ui.menu.story.StoryMenuState;
import ui.secret.MathGameState;
import ui.select.charSelect.CharacterSelect;
import ui.select.playerSelect.BackseatSelect;


typedef PauseOption = 
{
	/**
	 * The name of the option.
	 */
	var name:String;

	/**
	 * Called when the option is selected.
	 */
	var callback:PauseSubState->Void;
}

/**
 * A sub-menu shown whenever the user pauses.
 */
class PauseSubState extends MusicBeatSubstate
{
	/**
	 * The list of pause options for when the user's in story mode.
	 */
	static final STORY_MODE_OPTIONS:Array<PauseOption> =
	[
		{name: 'Resume', callback: closeMenu},
		{name: 'Restart Song', callback: restartSong},
		#if debug
		{name: 'No Miss Mode', callback: toggleNoMiss},
		#end
		{name: 'Options', callback: openSettingsMenu},
		{name: 'Exit to menu', callback: returnBackToMenu}
	];
	
	/**
	 * The list of pause options for when the user's in a dialogue session.
	 */
	static final STORY_MODE_DIALOGUE_OPTIONS:Array<PauseOption> =
	[
		{name: 'Resume', callback: closeMenu},
		{name: 'Skip Dialogue', callback: finishDialogue},
		{name: 'Options', callback: openSettingsMenu},
		{name: 'Exit to menu', callback: returnBackToMenu},
	];

	/**
	 * The list of pause options for when the user's playing a song in freeplay.
	 */
	static final FREEPLAY_OPTIONS:Array<PauseOption> =
	[
		{name: 'Resume', callback: closeMenu},
		{name: 'Restart Song', callback: restartSong},
		#if debug
		{name: 'No Miss Mode', callback: toggleNoMiss},
		#end
		{name: 'Change Character', callback: changeCharacter},
		{name: 'Options', callback: openSettingsMenu},
		{name: 'Exit to menu', callback: returnBackToMenu},
	];

	/**
	 * The list of pause option's when the user's unable to select a character.
	 */
	static final NO_SELECT_OPTIONS:Array<PauseOption> =
	[
		{name: 'Resume', callback: closeMenu},
		{name: 'Restart Song', callback: restartSong},
		#if debug
		{name: 'No Miss Mode', callback: toggleNoMiss},
		#end
		{name: 'Options', callback: openSettingsMenu},
		{name: 'Exit to menu', callback: returnBackToMenu},
	];

	/**
	 * The list of pause options for when the user's on a song where you're able to select the player.
	 */
	static final FREEPLAY_PLAYER_SELECT_OPTIONS:Array<PauseOption> =
	[
		{name: 'Resume', callback: closeMenu},
		{name: 'Restart Song', callback: restartSong},
		#if debug
		{name: 'No Miss Mode', callback: toggleNoMiss},
		#end
		{name: 'Change Player', callback: returnToPlayerSelect},
		{name: 'Options', callback: openSettingsMenu},
		{name: 'Exit to menu', callback: returnBackToMenu},
	];
	
	var menuItems:Array<PauseOption>;

	/**
	 * A scrolling background used throughout the song.
	 */
	var bg:FlxBackdrop;

	/**
	 * A list of all of the current options.
	 */
	var grpMenuShit:FlxTypedGroup<Alphabet>;
	
	/**
	 * The music that plays while the menu is active.
	 */
	var pauseMusic:GameSound;

	/**
	 * The currently selected option.
	 */
	var curSelected:Int = 0;

	public function new()
	{
		super();
		
		getPauseOptions();

		buildMusic();
		buildBackground();
		buildPauseUI();

		generatePauseOptions();
		changeSelection();
		setupPauseCamera();

		#if mobileC
		addVirtualPad(UP_DOWN, A);
		addVirtualPadCamera();
		#end
	}

	override function update(elapsed:Float)
	{
		var scrollSpeed:Float = 50;
		bg.x -= scrollSpeed * elapsed;
		bg.y -= scrollSpeed * elapsed;

		if (pauseMusic.volume < 0.75)
			pauseMusic.volume += 0.01 * elapsed;

		super.update(elapsed);

		var upP = controls.UP_P;
		var downP = controls.DOWN_P;
		var accepted = controls.ACCEPT;

		if (upP)
		{
			changeSelection(-1);
		}
		if (downP)
		{
			changeSelection(1);
		}
		if (accepted)
		{
			selectOption();
		}
	}

	override function destroy()
	{
		pauseMusic.destroy();
		FlxG.cameras.remove(camera);
		camera.destroy();

		super.destroy();
	}

	override function close()
	{
		SoundController.remove(pauseMusic);

		super.close();
	}

	/**
	 * Changes the currently selected option by the given amount.
	 * @param change The amount to change by.
	 */
	function changeSelection(change:Int = 0):Void
	{
		curSelected += change;

		if (curSelected < 0)
			curSelected = menuItems.length - 1;
		if (curSelected >= menuItems.length)
			curSelected = 0;

		var bullShit:Int = 0;

		for (item in grpMenuShit.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}
		updateSongPositions();
	}
	
	/**
	 * Selects the current option the user has selected.
	 */
	function selectOption():Void
	{
		menuItems[curSelected].callback(this);
	}

	/**
	 * Updates the positions of each song in the menu based on the current selection.
	 */
	function updateSongPositions():Void
	{
		for (item in grpMenuShit.members)
		{
			item.setupMenuTween(item.targetY);
		}
	}

	/**
	 * Retrieves the pause options based on the current state of the game the user is playing.
	 * @return A list of pause options.
	 */
	function getPauseOptions():Void
	{
		if (PlayStatePlaylist.isStoryMode)
		{
			if (PlayState.instance.currentDialogue != null && !PlayState.instance.currentDialogue.isDialogueEnding)
			{
				menuItems = STORY_MODE_DIALOGUE_OPTIONS;
			}
			else
			{
				menuItems = STORY_MODE_OPTIONS;
			}
		}
		else
		{
			if (PlayState.instance.currentSong.id.toLowerCase() == 'backseat')
			{
				menuItems = FREEPLAY_PLAYER_SELECT_OPTIONS;
			}
			else if (FreeplayState.skipSelect.contains(PlayState.instance.currentSong.id.toLowerCase()))
			{
				menuItems = NO_SELECT_OPTIONS;
			}
			else
			{
				menuItems = FREEPLAY_OPTIONS;
			}
		}
	}

	/**
	 * Sets up the pause music that slowly fades in when entering.
	 */
	function buildMusic():Void
	{
		pauseMusic = new GameSound(MUSIC).load(Paths.music('breakfast'));
		pauseMusic.looped = true;
		pauseMusic.autoDestroy = true;
		pauseMusic.volume = 0;
		pauseMusic.play(false, FlxG.random.int(0, Std.int(pauseMusic.length / 2)));

		SoundController.add(pauseMusic);
	}

	/**
	 * Generates the background used in the menu.
	 */
	function buildBackground():Void
	{
		var backBg:FlxSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		backBg.setGraphicSize(FlxG.width + 1, FlxG.height + 1);
		backBg.updateHitbox();
		backBg.screenCenter();
		backBg.alpha = FlxMath.EPSILON;
		backBg.scrollFactor.set();
		add(backBg);
		FlxTween.tween(backBg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
		
		bg = new FlxBackdrop(Paths.image('checkeredBG', 'shared'), XY, 1, 1);
		bg.alpha = FlxMath.EPSILON;
		bg.antialiasing = false;
		bg.scrollFactor.set();
		add(bg);
		FlxTween.tween(bg, {alpha: 0.6}, 0.4, {ease: FlxEase.quartInOut});
	}

	/**
	 * Generates the UI displaying the information of the current song, and any other additional information.
	 */
	function buildPauseUI():Void
	{
		var currentChart = PlayState.instance.currentChart;
		if (currentChart == null)
			return;

		var levelInfo:FlxText = new FlxText(20, 15, 0, currentChart.songName, 32);
		levelInfo.scrollFactor.set();
		levelInfo.setFormat(Paths.font("comic.ttf"), 32, FlxColor.WHITE, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		levelInfo.antialiasing = true;
		levelInfo.borderSize = 2.5;
		levelInfo.x = FlxG.width - (levelInfo.textField.textWidth + 20);
		levelInfo.alpha = 0;
		add(levelInfo);

		var composerInfo:FlxText = new FlxText(20, 15, 0, LanguageManager.getTextString('pause_composersText') + ': ${currentChart.songComposers.formatStringList()}');
		composerInfo.scrollFactor.set();
		composerInfo.setFormat(Paths.font("comic.ttf"), 20, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		composerInfo.antialiasing = true;
		composerInfo.borderSize = 2.5;
		composerInfo.x = FlxG.width - (composerInfo.textField.textWidth + 20);
		composerInfo.y = levelInfo.y + levelInfo.height + 5;
		composerInfo.alpha = 0;
		add(composerInfo);
		
		var artistInfo:FlxText = new FlxText(20, 15, 0, LanguageManager.getTextString('pause_artistsText') + ': ${currentChart.songArtists.formatStringList()}');
		artistInfo.scrollFactor.set();
		artistInfo.setFormat(Paths.font("comic.ttf"), 20, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		artistInfo.antialiasing = true;
		artistInfo.borderSize = 2.5;
		artistInfo.x = FlxG.width - (artistInfo.textField.textWidth + 20);
		artistInfo.y = composerInfo.y + composerInfo.height + 5;
		artistInfo.alpha = 0;
		add(artistInfo);

		var chartersInfo:FlxText = new FlxText(20, 15, 0, LanguageManager.getTextString('pause_chartersText') + ': ${currentChart.songCharters.formatStringList()}');
		chartersInfo.scrollFactor.set();
		chartersInfo.setFormat(Paths.font("comic.ttf"), 20, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		chartersInfo.antialiasing = true;
		chartersInfo.borderSize = 2.5;
		chartersInfo.x = FlxG.width - (chartersInfo.textField.textWidth + 20);
		chartersInfo.y = artistInfo.y + artistInfo.height + 5;
		chartersInfo.alpha = 0;
		add(chartersInfo);

		var codersInfo:FlxText = new FlxText(20, 15, 0, LanguageManager.getTextString('pause_codersText') + ': ${currentChart.songCoders.formatStringList()}');
		codersInfo.scrollFactor.set();
		codersInfo.setFormat(Paths.font("comic.ttf"), 20, FlxColor.WHITE, FlxTextAlign.RIGHT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		codersInfo.antialiasing = true;
		codersInfo.borderSize = 2.5;
		codersInfo.x = FlxG.width - (codersInfo.textField.textWidth + 20);
		codersInfo.y = chartersInfo.y + chartersInfo.textField.textHeight + 5;
		codersInfo.alpha = 0;
		add(codersInfo);

		composerInfo.x -= 30;
		artistInfo.x -= 40;
		chartersInfo.x -= 50;
		codersInfo.x -= 60;
		
		FlxTween.tween(levelInfo, {alpha: 1, y: 20}, 0.4, {ease: FlxEase.quartInOut, startDelay: 0.3});
		FlxTween.tween(composerInfo, {alpha: 1, x: composerInfo.x + 30}, 0.4, {ease: FlxEase.quartInOut, startDelay: 1});
		FlxTween.tween(artistInfo, {alpha: 1, x: artistInfo.x + 40}, 0.4, {ease: FlxEase.quartInOut, startDelay: 1.2});
		FlxTween.tween(chartersInfo, {alpha: 1, x: chartersInfo.x + 50}, 0.4, {ease: FlxEase.quartInOut, startDelay: 1.4});
		FlxTween.tween(codersInfo, {alpha: 1, x: codersInfo.x + 60}, 0.4, {ease: FlxEase.quartInOut, startDelay: 1.6});
	}

	/**
	 * Builds all of the selectable options based on the list of pause option entries.
	 */
	function generatePauseOptions():Void
	{
		grpMenuShit = new FlxTypedGroup<Alphabet>();
		add(grpMenuShit);

		for (i in 0...menuItems.length)
		{
			var songText:Alphabet = new Alphabet(0, (70 * i) + 30, LanguageManager.getTextString('pause_${menuItems[i].name}'));
			songText.isMenuItem = true;
			songText.menuItemGroup = grpMenuShit.members;
			songText.targetY = i;
			grpMenuShit.add(songText);
		}
	}

	/**
	 * Creates the camera used for the sub-menu.
	 * This is done to make sure the zoom of the menu isn't changed, and that nothing interferes.
	 */
	function setupPauseCamera():Void
	{
		camera = new GameCamera();
		camera.bgColor.alpha = 0;

		FlxG.cameras.add(camera, false);
	}


	// SELECTION OPTIONS //

	/**
	 * Closes this sub-menu.
	 * Used for the `Resume` option
	 */
	static function closeMenu(state:PauseSubState):Void
	{
		state.close();
	}

	/**
	 * Restarts the current song.
	 */
	static function restartSong(state:PauseSubState):Void
	{
		SoundController.music.volume = 0;
		PlayState.instance.vocals.volume = 0;

		PlayState.instance.camZooming = false;
		Cursor.hide();
		FlxG.resetState();
	}

	/**
	 * Toggles whether the player is able to miss notes.
	 * Used for the `No Miss Mode` option.
	 */
	static function toggleNoMiss(state:PauseSubState):Void
	{
		PlayState.instance.noMiss = !PlayState.instance.noMiss;
	}

	/**
	 * Opens the settings menu while still staying paused.
	 * Allows the user to change their options while still playing the song without having to restart.
	 */
	static function openSettingsMenu(state:PauseSubState):Void
	{
		#if mobileC
    	if (Std.isOfType(state, MusicBeatSubstate))
		{
       		(cast state:MusicBeatSubstate).removeVirtualPad();
    	}
    	#end
		state.openSubState(new SettingsMenu());
	}

	/**
	 * If we're in a dialogue, completes the current dialogue.
	 */
	static function finishDialogue(state:PauseSubState):Void
	{
		if (PlayState.instance.currentDialogue == null)
			return;

		PlayState.instance.currentDialogue.skipDialogue();
		state.close();
	}

	/**
	 * Opens the character selection menu.
	 * Will restart the song to make sure the changes are applied.
	 */
	static function changeCharacter(state:PauseSubState):Void
	{
		FlxG.switchState(() -> new CharacterSelect({targetSong: PlayState.instance.currentSong}));
	}
	
	/**
	 * Returns back to the user's last menu.
	 * 
	 * If we're in story mode, we go back to story mode.
	 * If we're in freeplay, we go back to the freeplay menu.
	 */
	static function returnBackToMenu(state:PauseSubState):Void
	{
		if (PlayStatePlaylist.isStoryMode)
			returnToMenu(() -> new StoryMenuState());
		else 
			returnToMenu(() -> new FreeplayState());
	}

	/**
	 * Returns to the player selection menu to allow the user what player they want to be, if available.
	 */
	static function returnToPlayerSelect(state:PauseSubState):Void
	{
		// TODO: See if there's a way to softcoded this ?
		var selectToGo:NextState = switch (PlayState.instance.currentSong.id.toLowerCase()) {
			case 'backseat': () -> new BackseatSelect(); 
			default: () -> new MainMenuState();
		}

		returnToMenu(selectToGo);
	}

	/**
	 * Returns back to the given menu.
	 * Reverts any needed changes before switching back
	 * @param state The state to return back to.
	 */
	static function returnToMenu(state:NextState)
	{
		if (MathGameState.failedGame)
			MathGameState.failedGame = false;

		Application.current.window.title = Main.applicationName;

		PlayState.instance.camZooming = false;
		Cursor.hide();
		
		if (!SoundController.music.playing)
		{
			SoundController.playMusic(Paths.music('freakyMenu'));
		}

		FlxG.switchState(state);
	}
}