package ui.secret;

import data.language.LanguageManager;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import play.PlayState;
import ui.MusicBeatState;
import ui.menu.MainMenuState;

/**
 * A secret menu that's displayed in a 1/1000 chance whenever the user pauses.
 */
class GitarooPause extends MusicBeatState
{
	var params:PlayStateParams;

	var replayButton:FlxSprite;
	var cancelButton:FlxSprite;

	var replaySelect:Bool = false;

	var text:FlxText;

	public function new(params:PlayStateParams):Void
	{
		this.params = params;
		super();
	}

	override function create()
	{
		if (SoundController.music != null)
			SoundController.music.stop();
		
		SoundController.playMusic(Paths.music('daveshead'));

		text = new FlxText(0, 0, FlxG.width, LanguageManager.getTextString('gitaroo_text'));
		text.setFormat(Paths.font('comic_normal.ttf'), 24, FlxColor.WHITE, FlxTextAlign.CENTER);
		text.screenCenter();
		add(text);

		var bf:FlxSprite = new FlxSprite(0, 50);
		bf.frames = Paths.getSparrowAtlas('ui/pauseAlt/daveLol');
		bf.animation.addByPrefix('lol', "funnyThing", 13);
		bf.animation.play('lol');
		add(bf);
		bf.screenCenter(X);

		replayButton = new FlxSprite(FlxG.width * 0.28, FlxG.height * 0.7);
		replayButton.frames = Paths.getSparrowAtlas('ui/pauseAlt/pauseUI');
		replayButton.animation.addByPrefix('selected', 'bluereplay', 0, false);
		replayButton.animation.appendByPrefix('selected', 'yellowreplay');
		replayButton.animation.play('selected');
		add(replayButton);

		cancelButton = new FlxSprite(FlxG.width * 0.58, replayButton.y);
		cancelButton.frames = Paths.getSparrowAtlas('ui/pauseAlt/pauseUI');
		cancelButton.animation.addByPrefix('selected', 'bluecancel', 0, false);
		cancelButton.animation.appendByPrefix('selected', 'cancelyellow');
		cancelButton.animation.play('selected');
		add(cancelButton);

		changeThing();
		
		#if mobileC
		addVirtualPad(LEFT_RIGHT, A);
		#end

		super.create();
	}

	override function update(elapsed:Float)
	{
		if (controls.LEFT_P || controls.RIGHT_P)
			changeThing();

		if (controls.ACCEPT)
		{
			if (replaySelect)
			{
				FlxG.switchState(() -> new PlayState(params));
			}
			else
			{
				FlxG.switchState(() -> new MainMenuState());
			}
		}

		super.update(elapsed);
	}

	function changeThing():Void
	{
		replaySelect = !replaySelect;

		if (replaySelect)
		{
			cancelButton.animation.curAnim.curFrame = 0;
			replayButton.animation.curAnim.curFrame = 1;
		}
		else
		{
			cancelButton.animation.curAnim.curFrame = 1;
			replayButton.animation.curAnim.curFrame = 0;
		}
	}
}
