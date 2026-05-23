package ui.menu;

import data.language.LanguageManager;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.effects.FlxFlicker;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import ui.MusicBeatState;
import ui.intro.TitleState.TitleState;
import ui.menu.freeplay.FreeplayState;
import ui.menu.ost.OSTMenuState;
import ui.menu.settings.SettingsMenu;
import ui.menu.story.StoryMenuState;
import util.FileUtil;
import util.PlatformUtil;

import play.save.Preferences;

#if desktop
import api.Discord.DiscordClient;
#end

using StringTools;

class MainMenuState extends MusicBeatState
{
	/**
	 * The currently selected option.
	 */
	public static var curSelected:Int = 0;
	
	/**
	 * Whether this is the first time we've entered this state.
	 */
	public static var firstStart:Bool = true;

	/**
	 * Whether the movement for the icons have finished.
	 * Stored as a static so it doesn't have several times.
	 */
	public static var finishedFunnyMove:Bool = false;

	/**
	 * Whether the user's able to interact with the menu.
	 */
	var canInteract:Bool = true;
	
	/**
	 * A list of all of the options that are able to be selected.
	 */
	var optionShit:Array<String> = ['story mode', 'freeplay', 'credits', 'ost', 'options'];

	/**
	 * The ids for all of the language data for the options name.
	 */
	var languagesOptions:Array<String> = ['main_story', 'main_freeplay', 'main_credits', 'main_ost', 'main_options'];

	/**
	 * The ids of all of the language data for the option descriptions.
	 */
	var languagesDescriptions:Array<String> = ['desc_story', 'desc_freeplay', 'desc_credits', 'desc_ost', 'desc_options'];

	/**
	 * Whether the user has selected an option and is exiting out of it.
	 */
	var selected:Bool;

	/**
	 * The randomized menu bg used.
	 */
	var bg:FlxSprite;
	
	/**
	 * The magenta variant of the menuBG used for when the user has selected an option. 
	 */
	var magenta:FlxSprite;

	/**
	 * The UI background used to cover the option icons.
	 */
	var selectUi:FlxSprite;

	/**
	 * The character art that represents an option.
	 */
	var bigIcons:FlxSprite;

	/**
	 * The text that displays the name of the current option.
	 */
	var curOptText:FlxText;

	/**
	 * The text that displays the description of the current option selected.
	 */
	var curOptDesc:FlxText;

	/**
	 * The group that contains all of the option icons.
	 */
	var menuItems:FlxTypedGroup<FlxSprite> = new FlxTypedGroup<FlxSprite>();

	override function create()
	{
		super.create();

		if (!SoundController.music.playing)
		{
			SoundController.playMusic(Paths.music('freakyMenu'));
		}
		persistentUpdate = persistentDraw = true;

		#if desktop
		DiscordClient.changePresence("In the Menus", null);
		#end

		bg = new FlxSprite(-80).loadGraphic(FileUtil.randomizeBG());
		bg.scrollFactor.set();
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.updateHitbox();
		bg.screenCenter();
		bg.antialiasing = true;
		bg.shader = null;
		bg.color = 0xFFFDE871;
		add(bg);

		magenta = new FlxSprite(-80).loadGraphic(bg.graphic);
		magenta.scrollFactor.set();
		magenta.setGraphicSize(Std.int(magenta.width * 1.1));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.antialiasing = true;
		magenta.color = 0xFFfd719b;
		add(magenta);

		selectUi = new FlxSprite(0, 0).loadGraphic(Paths.image('mainMenu/Select_Thing', 'preload'));
		selectUi.scrollFactor.set(0, 0);
		selectUi.antialiasing = true;
		selectUi.updateHitbox();
		add(selectUi);

		bigIcons = new FlxSprite(0, 20).loadGraphic(Paths.image('mainMenu/icons/story mode'));
		bigIcons.setGraphicSize(0, 350);
		bigIcons.updateHitbox();
		bigIcons.screenCenter(X);
		add(bigIcons);

		var optionString:String = LanguageManager.getTextString(languagesOptions[curSelected]);
		curOptText = new FlxText(0, 0, FlxG.width, optionString.format(' '));
		curOptText.setFormat("Comic Sans MS Bold", 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		curOptText.scrollFactor.set(0, 0);
		curOptText.borderSize = 2.5;
		curOptText.antialiasing = true;
		curOptText.screenCenter(X);
		curOptText.y = FlxG.height / 2 + 28;
		add(curOptText);

		curOptDesc = new FlxText(0, 0, FlxG.width, LanguageManager.getTextString(languagesDescriptions[curSelected]));
		curOptDesc.setFormat("Comic Sans MS Bold", 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		curOptDesc.scrollFactor.set(0, 0);
		curOptDesc.borderSize = 2;
		curOptDesc.antialiasing = true;
		curOptDesc.screenCenter(X);
		curOptDesc.y = FlxG.height - 58;
		add(curOptDesc);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (i in 0...optionShit.length)
		{
			var currentOptionShit = optionShit[i];
			var menuItem:FlxSprite = new FlxSprite(FlxG.width * 1.6, 0);
			menuItem.frames = Paths.getSparrowAtlas('mainMenu/main_menu_icons');
			menuItem.animation.addByPrefix('idle', currentOptionShit + " basic", 24);
			menuItem.animation.addByPrefix('selected', currentOptionShit + " white", 24);
			menuItem.animation.play('idle');
			menuItem.antialiasing = false;
			menuItem.setGraphicSize(128, 128);
			menuItem.ID = i;
			menuItem.updateHitbox();
			menuItems.add(menuItem);
			menuItem.scrollFactor.set(0, 1);
		}

		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.y = FlxG.height / 2 + 130;
		});

		transitionItems();

		firstStart = false;

		subStateClosed.add(function(subState:FlxSubState)
		{
			selectedSomethin = false;
			menuItems.forEach(function(spr:FlxSprite)
			{
				spr.revive();
				spr.visible = true;
				spr.alpha = 1;
			});
		});

		#if mobileC
		addVirtualPad(LEFT_RIGHT, A_B);
		#end

		super.create();
	}

	var selectedSomethin:Bool = false;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!canInteract || selected)
			return;

		var leftP = controls.LEFT_P || FlxG.mouse.wheel < 0;
		var rightP = controls.RIGHT_P || FlxG.mouse.wheel > 0;
		var accept = controls.ACCEPT;
		var back = controls.BACK;

		if (leftP)
		{
			changeSelection(-1);
		}
		if (rightP)
		{
			changeSelection(1);
		}
		if (accept)
		{
			selectOption(curSelected);
			canInteract = false;
		}
		if (back #if android || FlxG.android.justReleased.BACK #end)
		{
			canInteract = false;
			SoundController.play(Paths.sound('cancelMenu'));
			FlxG.switchState(() -> new TitleState());
		}
	}

	function transitionItems()
	{
		canInteract = false;
		for (i in 0...menuItems.length)
		{
			var item = menuItems.members[i];
			item.x = FlxG.width * 1.6;
			item.scale.set(0.65, 0.65);
			item.updateHitbox();
			item.alpha = 1;
			item.visible = true;

			if (firstStart)
			{
				FlxTween.tween(item, {x: ((FlxG.width - item.width) / 2) + ((i - Math.floor(menuItems.length / 2)) * 160)}, 1 + (i * 0.25), {
					ease: FlxEase.expoInOut,
					onComplete: function(flxTween:FlxTween)
					{
						finishedFunnyMove = true;
						changeSelection(0);
					}
				});
			}
			else
			{
				
				item.x = ((FlxG.width - item.width) / 2) + ((i - Math.floor(menuItems.length / 2)) * 160);
				changeSelection(0);
			}
		}

		new FlxTimer().start(1, function(t:FlxTimer)
		{
			canInteract = true;

			changeSelection(0);
		});
	}

	function changeSelection(amount:Int = 0)
	{
		if (finishedFunnyMove)
		{
			curSelected += amount;

			if (curSelected >= menuItems.length)
				curSelected = 0;
			if (curSelected < 0)
				curSelected = menuItems.length - 1;
		}

		menuItems.forEach(function(spr:FlxSprite)
		{
			spr.animation.play('idle');

			if (spr.ID == curSelected && finishedFunnyMove)
			{
				spr.animation.play('selected');
			}
		});

		bigIcons.loadGraphic(Paths.image('mainMenu/icons/${optionShit[curSelected]}'));
		bigIcons.setGraphicSize(0, 350);
		bigIcons.updateHitbox();
		bigIcons.screenCenter(X);

		// Apply offsets so the characters are centered to each other.
		switch (optionShit[curSelected])
		{
			case 'credits':
				bigIcons.x += 50;
			case 'options':
				bigIcons.x -= 50;
		}

		var optionString:String = LanguageManager.getTextString(languagesOptions[curSelected]);
		curOptText.text = optionString.format(' ');
		curOptDesc.text = LanguageManager.getTextString(languagesDescriptions[curSelected]);

		if (amount != 0)
			SoundController.play(Paths.sound('scrollMenu'), 0.7);
	}

	function selectOption(index:Int)
	{
		SoundController.play(Paths.sound('confirmMenu'));

		selected = true;
		FlxFlicker.flicker(magenta, 1.1, Preferences.flashingLights ? 0.5 : 0.15, false);

		var selectedOption:String = optionShit[index];
		var selectedItem:FlxSprite = menuItems.members[index];

		for (i in 0...menuItems.length)
		{
			var spr = menuItems.members[i];

			switch (i)
			{
				case(_ == index) => true:
					FlxTween.tween(spr, {'scale.x': 0.7, 'scale.y': 0.7}, 0.5, {ease: FlxEase.circOut});
				default:
					FlxTween.tween(spr, {'scale.x': 0.6, 'scale.y': 0.6, alpha: 0.8}, 0.3 + (i * 0.1), {ease: FlxEase.circOut});
			}
			new FlxTimer().start(1, function(t:FlxTimer)
			{
				FlxTween.tween(spr, {x: -spr.width}, 0.3 + (i * 0.25), {ease: FlxEase.backOut});
			});
		}
		FlxFlicker.flicker(selectedItem, 1.5, 0.2, false, false, function(flick:FlxFlicker)
		{
			switch (selectedOption)
			{
				case 'story mode':
					FlxG.switchState(() -> new StoryMenuState());
				case 'freeplay':
					if (FlxG.random.bool(0.05))
					{
						PlatformUtil.openURL("https://www.youtube.com/watch?v=Z7wWa1G9_30%22");
					}
					FlxG.switchState(() -> new FreeplayState());
				case 'ost':
					FlxG.switchState(() -> new OSTMenuState());
				case 'options':
					var settings = new SettingsMenu();
					settings.closeCallback = function()
					{
						selected = false;
						firstStart = true;
						transitionItems();
					}
					#if mobileC
					removeVirtualPad();
					#end
					openSubState(settings);
				case 'credits':
					FlxG.switchState(() -> new CreditsMenuState());
			}
		});
	}
}
