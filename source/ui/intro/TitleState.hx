package ui.intro;

import backend.Conductor;
import data.language.LanguageManager;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionSprite.GraphicTransTileDiamond;
import flixel.addons.transition.FlxTransitionableState;
import flixel.addons.transition.TransitionData;
import flixel.graphics.FlxGraphic;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import flixel.util.FlxTimer;
import flixel.input.gamepad.FlxGamepad;

import lime.app.Application;

import openfl.Assets;

import play.LoadingState;
import play.save.Preferences;

import ui.MusicBeatState;
import ui.secret.SusState;
import ui.menu.MainMenuState;

#if desktop
import api.Discord.DiscordClient;
#end

#if mobileC
import util.TouchUtil;
#end

using StringTools;

class TitleState extends MusicBeatState
{
	public static var initialized:Bool = false;

	var bg:FlxSprite;
	var logoBl:FlxSprite;
	var logo:FlxSprite;
	var version:FlxSprite;

	var pressEnter:FlxText;
	var introDisplayText:FlxText;

	var timer:FlxTimer;

	var transitioning:Bool = false;

	var introText:Array<String> = [];

	override public function create():Void
	{
		if (FlxG.random.int(0, 999) == 1)
			LoadingState.loadAndSwitchState(() -> new SusState());

		// Initalize intro text.
		introText = FlxG.random.getObject(getIntroText());
		
		new FlxTimer().start(1, function(tmr:FlxTimer)
		{
			startIntro();
		});
		
		super.create();
	}

	function startIntro()
	{
		persistentUpdate = true;

		var blackBg = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [
			FlxColor.interpolate(FlxColor.fromRGB(0, 0, 0), 0xFF4965FF, 0.6),
			FlxColor.interpolate(FlxColor.fromRGB(0, 0, 0), 0xFF00B515, 0.6)
		], 1, 180);
		add(blackBg);

		bg = new FlxSprite();
		bg.frames = Paths.getSparrowAtlas('title/title_bg');
		bg.animation.addByPrefix('idle', 'title_bg', 24, true);
		bg.animation.play('idle');
		bg.screenCenter();
		add(bg);

		logoBl = new FlxSprite(0, 40);
		logoBl.frames = Paths.getSparrowAtlas('title/logoBumpin');
		logoBl.screenCenter(X);
		logoBl.antialiasing = true;
		logoBl.animation.addByPrefix('bump', 'logo bumpin', 24);
		logoBl.animation.play('bump');
		add(logoBl);

		version = new FlxSprite(715, 440).loadGraphic(Paths.image('version'));
		version.scale.set(0.8, 0.8);
		version.updateHitbox();
		version.antialiasing = true;
		version.angle = -3;
		add(version);

		pressEnter = new FlxText(0, 600, 0, #if desktop LanguageManager.getTextString('title_pressEnter') #else LanguageManager.getTextString('title_pressEnter_mobile') #end, 20);
		pressEnter.setFormat(Paths.font('comic.ttf'), 48, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		pressEnter.screenCenter(X);
		pressEnter.borderSize = 3;
		pressEnter.active = false;
		add(pressEnter);

		if (!SoundController?.music?.playing ?? true)
		{
			SoundController.playMusic(Paths.music('freakyMenu'));
		}

		Conductor.instance.loadMusicData('freakyMenu');

		initalizeIntroText();

		FlxG.camera.fade(FlxColor.BLACK, 1, true);
	}

	override function update(elapsed:Float)
	{
		Conductor.instance.update();

		if (FlxG.keys.justPressed.F)
		{
			FlxG.fullscreen = !FlxG.fullscreen;
		}
		
		var pressedEnter:Bool = FlxG.keys.justPressed.ENTER;

		var gamepad:FlxGamepad = FlxG.gamepads.lastActive;

		if (gamepad != null)
		{
			if (gamepad.justPressed.START)
				pressedEnter = true;

			#if switch
			if (gamepad.justPressed.B)
				pressedEnter = true;
			#end
		}

		#if mobile
		if (TouchUtil.justPressed)
			pressedEnter = true;
		#end

		if (pressEnter != null && pressedEnter && !transitioning)
		{
			FlxTween.tween(pressEnter, {'scale.x': 0, 'scale.y': 0, angle: 10}, 0.5, {ease: FlxEase.backInOut});

			if (Preferences.flashingLights)
				FlxG.camera.flash(FlxColor.WHITE, 0.5);

			SoundController.play(Paths.sound('confirmMenu'), 0.7);

			transitioning = true;

			new FlxTimer().start(2, function(tmr:FlxTimer)
			{
				FlxG.switchState(() -> new MainMenuState());
			});
		}

		super.update(elapsed);
	}

	override function beatHit(beat:Int):Bool
	{
		if (!super.beatHit(beat)) return false;

		if (logoBl == null) return false;

		logoBl.animation.play('bump');
		
		FlxTween.cancelTweensOf(introDisplayText.scale);
		
		introDisplayText.scale.set(1.1, 1.1);
		FlxTween.tween(introDisplayText.scale, {x: 1.0, y: 1.0}, (Conductor.instance.crochet / 1100));

		return true;
	}

	function getIntroText():Array<Array<String>>
	{
		var fullText:String = Assets.getText(Paths.txt('introText')).trim();

		var values:Array<Array<String>> = [];

		var splitTextList:Array<String> = fullText.split('\n');
		for (splitText in splitTextList)
		{
			values.push(splitText.split('--'));
		}
		return values;
	}

	function initalizeIntroText():Void
	{
		introDisplayText = new FlxText(100, 0, 375, introText[0]);
		introDisplayText.setFormat(Paths.font('comic.ttf'), 24, FlxColor.fromString('#FF3FAC'), FlxTextAlign.CENTER, FlxTextBorderStyle.SHADOW_XY(3, 3), FlxColor.BLACK);
		introDisplayText.screenCenter();
		introDisplayText.borderSize = 2;
		introDisplayText.x = 250;
		introDisplayText.y = 440;
		introDisplayText.angle = 2;
		add(introDisplayText);

		var loopsElapsed:Int = 0;
		timer = new FlxTimer().start(Conductor.instance.measureLength / 1000, (t:FlxTimer) -> 
		{
			loopsElapsed++;			
			if (loopsElapsed % 2 == 1)
			{

				introDisplayText.text = introText[0];
			}
			else
			{
				introDisplayText.text = introText[1];
			}
			t.reset(Conductor.instance.measureLength / 1000);
		}, 0);
	}
}