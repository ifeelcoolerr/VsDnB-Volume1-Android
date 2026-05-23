package ui.select.charSelect;

import audio.GameSound;
import audio.SoundGroup;
import backend.Conductor;
import controls.Controls.Device;
import controls.Controls.Control;
import data.song.SongRegistry;
import data.language.LanguageManager;
import data.player.PlayerRegistry;
import play.player.PlayableCharacter;
import flixel.FlxG;
import flixel.FlxCamera.FlxCameraFollowStyle;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.effects.FlxFlicker;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.sound.FlxSound;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import graphics.GameCamera;
import modding.PolymodManager;
import play.LoadingState;
import play.character.Character;
import play.notes.Strumline;
import play.save.Preferences;
import play.stage.BGSprite;
import play.song.Song;
import ui.MusicBeatState;
import ui.menu.freeplay.FreeplayState;

typedef CharacterSelectParams = 
{
	/**
	 * The song to enter when the user exits this menu.
	 */
	var targetSong:Song;
}

/**
 * A menu that allows the user to select a character to play as before opening a song.
 */
class CharacterSelect extends MusicBeatState
{
	/**
	 * The id of the character that was selected by the player.
	 */
	public static var selectedCharacter:Null<String> = null;

	/**
	 * The last parameters that were given by the user.
	 * Used as a fallback in-case 0 parameters were given into this state.
	 */
	static var lastParams:CharacterSelectParams;

	/**
	 * The current parameters that were given by the user when exiting this selection.
	 * These parameters will be later used to initalize PlayState.
	 */
	var params:CharacterSelectParams;

	/**
	 * The target song to be played when the character exits out of this menu.1
	 */
	public var targetSong:Song;

	/**
	 * The data for the none portrait.
	 * 
	 * This is used for if a character is lockedIt's not able to be selected.
	 */
	final LOCKED_CHARACTER:PlayableCharacter = PlayerRegistry.instance.fetchEntry('locked');

	/**
	 * The data for the none portrait.
	 * 
	 * This is used for if a slot is unavailable. It's not able to be selected.
	 */
	final NONE_CHARACTER:PlayableCharacter = PlayerRegistry.instance.fetchEntry('none');

	/**
	 * A list of all of the characters that are selectable, and displayed on this menu.
	 * `Int` => The page number.
	 * `Array<PlayableCharacter>` => All of the characters available to choose on this page. 
	 */
	var characters:Map<Int, Array<PlayableCharacter>> = new Map<Int, Array<PlayableCharacter>>();

	
	/**
	 * Whether the user's allowed to do inputs in the menu.
	 */
	var canInteract:Bool = true;

	/**
	 * The current character the user has selected.
	 */
	var char:Character;

	/**
	 * A sprite that shows whenever the character that was selected is either unavailable, or locked.
	 */
	var hiddenCharacter:FlxSprite;

	/**
	 * A map of the all of the selectable characters.
	 * All characters are added into this map so they're easily preloaded, making switching the characters simple.
	 * 
	 * `String` => The id of the character.
	 * `Boyfriend` => The character.
	 */
	var charMap:Map<String, Character> = [];

	// CAMERA // 

	/**
	 * The main in-game camera used in the menu. 
	 * The character, and background is rendered onto this sprite.
	 */
	var cameraWorld:GameCamera = new GameCamera();

	/*
	 * The camera used for any UI elements.
	 * The strumlines, and portrait selections, and other UI elements are rendered onto here.
	 */
	var cameraHUD:GameCamera = new GameCamera();
	
	var cameraFollow:FlxObject = new FlxObject(0, 0, 1, 1);


	// MUSIC //

	/**
	 * A sound group that handles all of the music for the characters.
	 * Each character song is added to this group to be synced up with each other.
	 */
	var musicGroup:SoundGroup = new SoundGroup();

	/**
	 * A map of the music for the character.
	 * 
	 * `String` => The id of the character.
	 * `GameSound` => The song for the character. Fallbacks to the default theme is none exist for it.
	 */
	var charThemeMap:Map<String, GameSound> = new Map<String, GameSound>();


	// UI //

	/**
	 * The strumline that displays over the character.
	 * This is used to display the note style this character uses, as well as previewing the animations for the strums.
	 */
	var strumLine:Strumline;

	/**
	 * The text that displays the name of the current character.
	 */
	var characterText:FlxText;

	/**
	 * The text that shows the current page the user is on.
	 */
	var pageText:FlxText;

	/**
	 * The sign that shows whenever there's an empty slot in the character select.
	 */
	var customCharacterSign:FlxSprite;
	
	/**
	 * The group used to display all of the portraits.
	 */
	var portraitPages:Map<Int, PortraitPage> = new Map<Int, PortraitPage>();
	
	/**
	 * The last page that was selected by the user.
	 * If they first entered the menu this will be null, else this'll be disappeared and stored for use.
	 */
	var lastPageSelected:PortraitPage;

	/**
	 * The current page selected based on the select index.
	 */
	var currentPageSelected(get, never):PortraitPage;

	function get_currentPageSelected():PortraitPage
	{
		return portraitPages.get(currentPage);
	}

	/**
	 * Stores the last selected portrait to make sure it de-selects. 
	 */
	var lastSelectedPortrait:CharacterPortrait;

	/**
	 * The current portrait the user has selected.
	 */
	var selectedPortrait(get, never):CharacterPortrait;

	function get_selectedPortrait():CharacterPortrait
		return currentPageSelected.members[currentSelectedIndex];
	
	/**
	 * Stores the last selected portrait to make sure it de-selects. 
	 */
	var lastSelectedChar:PlayableCharacter;

	/**
	 * The current character the user has selected.
	 */
	var selectedChar(get, never):PlayableCharacter;

	function get_selectedChar():PlayableCharacter
		return currentPageCharacters[currentSelectedIndex];

	/**
	 * A list of the characters that are able to be choosed from the current page.
	 */
	var currentPageCharacters(get, never):Array<PlayableCharacter>;

	function get_currentPageCharacters():Array<PlayableCharacter>
		return characters.get(currentPage);


	// CONTROLS // 

	/**
	 * A list of `FlxKey` press to make the player sing.
	 * This is normally the first set of the player's keybinds.
	 */
	var singControls:Array<FlxKey> = [];
	
	/**
	 * A map of `FlxKey' to press for the user to interact with the menu.
	 * This is normally the second set of the player's keybinds.
	 */
	var selectControls:Map<Control, FlxKey> = [];
	
	/**
	 * The current page that the user's currently on.
	 */
	var currentPage:Int = 0;

	/**
	 * The current selected column, and row index in terms of 0-9
	 */
	var currentSelectedIndex(get, never):Int;

	function get_currentSelectedIndex():Int
	{
		return (curColumn * 3) + curRow;
	}

	/**
	 * The current column (the x) the user is on.
	 */
	var curColumn:Int;

	/**
	 * The current column (the y) the user is on.
	 */
	var curRow:Int;

	
	public function new(params:CharacterSelectParams)
	{
		super();

		if (params == null && lastParams == null)
			throw 'Tried initalizing CharacterSelect with 0 parameters.';
		else if (params == null && lastParams != null)
			params = lastParams;

		this.params = params;

		lastParams = params;

		this.targetSong = params.targetSong;
	}

	override function create()
	{
		initalizePortraits();
		setupControls();
		setupCameras();
		createBg();

		setupCharacter();

		setupUI();

		initalizeMusic();

		updatePageDisplay();
		updateSelection();

		#if mobileC
		addVirtualPad(LEFT_FULL, A_B);
		addVirtualPadCamera();
		#end

		super.create();
	}

	override function update(elapsed:Float)
	{
		Conductor.instance.update(musicGroup.time);

		if (canInteract)
		{
			var firstPressed = FlxG.keys.firstJustPressed();

			if (firstPressed != -1)
			{
				for (control => key in selectControls)
				{
					if (firstPressed == key)
					{
						switch (control)
						{
							case LEFT:
								changeRowSelection(-1);
							case DOWN:
								changeColumnSelection(1);
							case UP:
								changeColumnSelection(-1);
							case RIGHT:
								changeRowSelection(1);
							default:
						}
					}
				}

				if (singControls.contains(firstPressed))
				{
					var controlIndex = singControls.indexOf(firstPressed);

					char.sing(controlIndex);
					strumLine.strums.members[controlIndex].playAnim('confirm', true);
				}
			}

			#if mobileC
			if (virtualPad.buttonLeft.justPressed)
				changeRowSelection(-1);
			if (virtualPad.buttonDown.justPressed)
				changeColumnSelection(1);
			if (virtualPad.buttonUp.justPressed)
				changeColumnSelection(-1);
			if (virtualPad.buttonRight.justPressed)
				changeRowSelection(1);
			#end

			if (controls.ACCEPT)
				selectCharacter();

			if (controls.BACK #if android || FlxG.android.justReleased.BACK #end)
			{
				SoundController.playMusic(Paths.music('freakyMenu'));
				FlxG.switchState(() -> new FreeplayState());
			}
		}

		super.update(elapsed);
	}

	override function destroy()
	{
		for (id in charMap.keys())
		{
			if (charMap[id] != char)
			{
				var charId = charMap[id];

				charId.destroy();
				charId = null;
			}
		}

		super.destroy();
	}

	override function reloadAssets():Void
	{
		selectedCharacter = null;

		modding.PolymodManager.reloadAssets();

		params.targetSong = SongRegistry.instance.fetchEntry(targetSong.id);
		lastParams.targetSong = SongRegistry.instance.fetchEntry(targetSong.id);

		LoadingState.loadAndSwitchState(() -> new CharacterSelect({targetSong: params.targetSong}));
	}

	function changeColumnSelection(amount:Int)
	{
		if (amount != 0)
		{
			lastSelectedChar = selectedChar;
			lastSelectedPortrait = selectedPortrait;
			SoundController.play(Paths.sound('scrollMenu'));
		}
		curColumn += amount;

		if (curColumn < 0)
		{
			changePageSelection(-1);
			curColumn = 2;
		}
		
		if (curColumn > 2)
		{
			changePageSelection(1);
			curColumn = 0;
		}

		updateSelection();
	}

	function changeRowSelection(amount:Int)
	{
		if (amount != 0)
		{
			lastSelectedChar = selectedChar;
			lastSelectedPortrait = selectedPortrait;
			SoundController.play(Paths.sound('scrollMenu'));
		}
		curRow += amount;

		if (curRow < 0)
			curRow = 2;
		
		if (curRow > 2)
			curRow = 0;

		updateSelection();
	}

	function changePageSelection(amount:Int = 0)
	{
		if (amount != 0)
		{
			lastPageSelected = currentPageSelected;
		}
		currentPage += amount;

		if (currentPage < 0)
			currentPage = portraitPages.size() - 1;
		
		if (currentPage > portraitPages.size() - 1)
			currentPage = 0;

		updatePageDisplay();
	}

	function updatePageDisplay()
	{
		if (lastPageSelected != null)
		{
			lastPageSelected.setVisiblity(false);
		}
		currentPageSelected.setVisiblity(true);
		pageText.text = LanguageManager.getTextString('charSelect_page') + ' ' + '${currentPage + 1}/${portraitPages.size()}';
	}

	function updateSelection()
	{
		lastSelectedPortrait?.deselect();
		selectedPortrait.select();

		updateBF();

		characterText.text = selectedChar.name;
		characterText.x = 300 - (characterText.textField.textWidth / 2);
		characterText.color = (selectedChar.characterId == 'none' || selectedChar.characterId == 'locked') ? 0x909090 : char.characterColor;

		switchTheme(selectedChar.characterId);
	}

	function selectCharacter()
	{
		// Selected an invalid portrait.
		if (selectedChar.characterId == 'none' || selectedChar.characterId == 'locked')
		{
			FlxG.camera.shake(0.05, 0.1);
			SoundController.play(Paths.sound('missnote1'), 0.9);
			return;
		}
		canInteract = false;

		char.playAnim('hey', true);
		char.canDance = false;

		for (i in 0...currentPageSelected.members.length)
		{
			var curPortrait:CharacterPortrait = currentPageSelected.members[i];

			if (curPortrait != selectedPortrait)
			{
				FlxTween.tween(curPortrait, {alpha: 0.4}, 0.5, {ease: FlxEase.circOut});
			}
			else
			{
				FlxFlicker.flicker(curPortrait, 2, 0.1);
			}
		}

		musicGroup.fadeOut();
		SoundController.play(Paths.sound('confirmMenu'));

		new FlxTimer().start(1, function(timer:FlxTimer)
		{
			var targetVariationId:String = selectedChar.variationId;

			selectedCharacter = selectedChar.characterId;

			LoadingState.loadPlayState({targetSong: params.targetSong, targetVariation: targetVariationId}, true);
		});
	}

	function updateBF()
	{
		if (['locked', 'none'].contains(selectedChar.characterId))
		{
			customCharacterSign.visible = false;
			hiddenCharacter.visible = false;
			
			switch (selectedChar.id)
			{
				case 'locked':
					hiddenCharacter.visible = true;
				case 'none':
					customCharacterSign.visible = true;
			}
			if (char != null)
				char.visible = false;
			
			strumLine.visible = false;
		}
		else
		{
			hiddenCharacter.visible = false;
			customCharacterSign.visible = false;

			// If the last portrait was an unavailable one, reset the state.
			if (lastSelectedChar == null || ['locked', 'none'].contains(lastSelectedChar.characterId))
			{
				if (char != null)
					char.visible = true;
				
				strumLine.visible = true;
			}

			var oldNoteSkin = char?.skins.get('noteSkin') ?? 'normal';

			if (char != null)
			{
				// Update the character.
				remove(char);
			}
			char = charMap.get(selectedChar.characterId);
			add(char);

			char.setPosition(350, 250);
			char.dance(true);
			char.reposition();
			
			var newNoteSkin = char.skins.get('noteSkin');
			if (oldNoteSkin != newNoteSkin)
			{
				updateStrumLine();
			}
		}
	}

	function createPage(page:Int):Array<PlayableCharacter>
	{
		var pageCharacters:Array<PlayableCharacter> = new Array<PlayableCharacter>();
		for (i in 0...9)
		{
			pageCharacters.push(NONE_CHARACTER);
		}
		characters.set(page, pageCharacters);

		return pageCharacters;
	}

	function initalizePortraits():Void
	{
		// Create 2 pages, one for the default playable characters, and another to display that you can add more.
		createPage(0);
		createPage(1);

		// Sort the playable characters by their slot position.
		var playableChars = [for (entry in PlayerRegistry.instance.listEntryIds()) PlayerRegistry.instance.fetchEntry(entry)];
		playableChars.sort((a, b) -> {
			return (a.getCharSelectData().position - b.getCharSelectData().position) + (a.getCharSelectData().page - b.getCharSelectData().page);
		});

		for (player in playableChars)
		{
			// Skip initalize if it's none. it's used to initalize a page.
			if (player.characterId == 'none') continue;

			var playerToUse:PlayableCharacter = player.isUnlocked() ? player : NONE_CHARACTER;

			var page:Int = player.page;
			var position:Int = player.position % 9;

			// Make sure there's pages initalized up until this player's page
			for (i in 0...(page + 1))
			{
				if (!characters.exists(i))
				{
					createPage(i);
				}
			}

			var pageCharacters:Array<PlayableCharacter> = characters.get(page);
			while (pageCharacters[position].characterId != 'none')
			{
				if (position < pageCharacters.length - 1)
				{
					position++;
				}
				else
				{
					position = 0;
					page++;

					pageCharacters = characters.get(page);
					if (pageCharacters == null)
					{
						pageCharacters = createPage(page);
					}
				}
			}

			pageCharacters[position] = playerToUse;
			characters.set(page, pageCharacters);

			// Preload the character for this player.
			if (playerToUse.characterId != 'none' && playerToUse.characterId != 'locked')
			{	
				var charFile:Character = Character.create(playerToUse.characterId, PLAYER);
				charMap.set(player.characterId, charFile);
			}
		}
	}

	function setupControls()
	{
		for (control in [Control.LEFT, Control.DOWN, Control.UP, Control.RIGHT])
		{
			var actionKeys:Array<FlxKey> = controls.getInputsFor(control, Device.Keys);

			singControls.push(actionKeys[0]);

			selectControls[control] = actionKeys[1];
		}
	}

	function setupCameras()
	{
		cameraWorld.bgColor.alpha = 0;
		cameraWorld.zoom = 0.85;

		cameraHUD.bgColor.alpha = 0;

		FlxG.cameras.reset(cameraWorld);
		FlxG.cameras.add(cameraHUD, false);

		FlxG.cameras.setDefaultDrawTarget(cameraWorld, true);

		cameraFollow.screenCenter();
		cameraFollow.x += 350;

		cameraWorld.follow(cameraFollow, FlxCameraFollowStyle.LOCKON);
		cameraWorld.focusOn(cameraFollow.getPosition());
	}

	function createBg()
	{
		var bg:BGSprite = new BGSprite('bg', 212, -75, Paths.image('selectMenu/charSelect/charSelectBg'), null);
		bg.scale.set(0.8, 0.8);
		bg.updateHitbox();
		add(bg);
	}

	function setupCharacter():Void
	{
		if (selectedChar.characterId != 'none' || selectedChar.characterId == 'locked')
		{
			char = Character.create(350, 250, selectedChar.characterId, PLAYER);
			add(char);
		}

		hiddenCharacter = new FlxSprite(435, 50);
		hiddenCharacter.frames = Paths.getSparrowAtlas('selectMenu/charSelect/charselect_none');
		hiddenCharacter.animation.addByPrefix('idle', 'idle', 24);
		hiddenCharacter.animation.play('idle', true);
		add(hiddenCharacter);
		
		customCharacterSign = new FlxSprite(460, 345).loadGraphic(Paths.image('selectMenu/charSelect/custom_character'));
		add(customCharacterSign);
	}

	function setupUI()
	{
		characterText = new FlxText(0, Preferences.downscroll ? 50 : 600, 0, selectedChar.name);
		characterText.setFormat(Paths.font('comic.ttf'), 55, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		characterText.borderSize = 3;
		characterText.camera = cameraHUD;
		add(characterText);

		pageText = new FlxText(850, 5, 0, 'Page 1/2');
		pageText.setFormat(Paths.font('comic.ttf'), 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pageText.borderSize = 2;
		pageText.camera = cameraHUD;
		add(pageText);

		setupStrumLine();
		setupPortraits();
	}

	function setupStrumLine()
	{
		strumLine = new Strumline({isPlayer: false, noteStyle: char?.skins?.get('noteSkin') ?? 'normal'});
		strumLine.setPosition(75, Preferences.downscroll ? 575 : 50);
		strumLine.camera = cameraHUD;
		add(strumLine);
		strumLine.fadeNotes();
	}

	function updateStrumLine()
	{
		strumLine.noteStyle = char.skins.get('noteSkin');
		strumLine.regenerate();
	}

	function setupPortraits()
	{
		for (ind => pageCharacters in characters)
		{
			var portraitPage = new PortraitPage(600, 50, pageCharacters);
			portraitPage.camera = cameraHUD;
			portraitPage.visible = false;
			add(portraitPage);
			portraitPages.set(ind, portraitPage);
		}
	}

	function initalizeMusic()
	{
		SoundController.music?.stop();

		var normalTheme:GameSound = new GameSound(MUSIC).load(Paths.music('characterSelect/charSelect-normal'));
		normalTheme.looped = true;
		normalTheme.autoDestroy = true;
		SoundController.add(normalTheme);
		musicGroup.add(normalTheme);

		for (page in characters.values())
		{
			for (character in page)
			{
				if (Paths.music('characterSelect/charSelect-${character.characterId}') != null)
				{
					var theme:GameSound = new GameSound(MUSIC).load(Paths.music('characterSelect/charSelect-${character.characterId}'));
					theme.looped = true;
					theme.autoDestroy = true;
					SoundController.add(theme);
					musicGroup.add(theme);

					charThemeMap.set(character.characterId, theme);
				}
				else
				{
					charThemeMap.set(character.characterId, normalTheme);
				}
			}
		}

		musicGroup.forEach(function(sound:FlxSound)
		{
			if (normalTheme != sound)
				sound.volume = 0;
		});
		musicGroup.play();

		Conductor.instance.loadMusicData('characterSelect');
	}

	function switchTheme(character:String)
	{
		var charTheme:GameSound = charThemeMap.get(character);

		musicGroup.forEach(function(sound:FlxSound)
		{
			FlxTween.cancelTweensOf(sound);

			if (charTheme == sound)
				sound.fadeIn();
			else
				sound.fadeOut();
		});
	}

	public static function reset()
	{
		initSave();
		unlockCharacter('bf');
		unlockCharacter('bf-pixel');
	}

	public static function initSave()
	{
		if (FlxG.save.data.charactersUnlocked == null)
		{
			FlxG.save.data.charactersUnlocked = new Array<String>();
			FlxG.save.flush();
		}
	}

	public static function isLocked(character:String):Bool
	{
		return !FlxG.save.data.charactersUnlocked.contains(character);
	}

	public static function unlockCharacter(character:String)
	{
		if (!FlxG.save.data.charactersUnlocked.contains(character))
		{
			FlxG.save.data.charactersUnlocked.push(character);
			FlxG.save.flush();
		}
	}
}