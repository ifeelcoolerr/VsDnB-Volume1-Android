package ui.intro;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import flixel.util.FlxColor;
import flixel.util.typeLimit.NextState;
import flixel.system.FlxSplash;
import openfl.Lib;
#if android
import util.TouchUtil;
#end

/**
 * The screen that shows when first loading the game.
 * Has an animated intro just like the flixel splash screen.
 */
class GameSplash extends FlxState
{
    var animatedIntro:FlxSprite;
    
    public override function create():Void
    {
		FlxG.cameras.bgColor = FlxColor.BLACK;
		FlxG.fixedTimestep = false;
		FlxG.autoPause = true;

		animatedIntro = new FlxSprite(0, 0);
		animatedIntro.frames = Paths.getSparrowAtlas('flixel_intro', 'preload');
		animatedIntro.animation.addByPrefix('intro', 'intro', 24);
		animatedIntro.animation.play('intro');
		animatedIntro.updateHitbox();
		animatedIntro.antialiasing = false;
		animatedIntro.screenCenter();
		add(animatedIntro);

		new FlxTimer().start(0.636, timerCallback);

		var stageWidth:Int = Lib.current.stage.stageWidth;
		var stageHeight:Int = Lib.current.stage.stageHeight;

		onResize(stageWidth, stageHeight);

        SoundController.play(Paths.sound("flixel"));
    }

    override public function update(elapsed:Float)
	{
		if (FlxG.keys.justPressed.ANY #if android || TouchUtil.justPressed #end)
		{
			onComplete(null);
		}
		super.update(elapsed);
	}

    override public function destroy():Void
	{
		super.destroy();
		animatedIntro.destroy();
	}

    function timerCallback(Timer:FlxTimer):Void
	{
		FlxTween.tween(animatedIntro, {alpha: 0}, 3.0, {ease: FlxEase.quadOut, onComplete: onComplete});
	}

	function onComplete(Tween:FlxTween):Void
	{
		#if FLX_KEYBOARD
		FlxG.keys.enabled = true;
		#end
		FlxG.autoPause = true;

		if (FlxG.save.data.hasSeenOptionsReminder == null || !FlxG.save.data.hasSeenOptionsReminder)
		{
			FlxG.switchState(() -> new OptionsReminderState());
		}
		else
		{
			FlxG.switchState(() -> new TitleState());
		}

		@:privateAccess
		FlxG.game._gameJustStarted = true;
	}
}