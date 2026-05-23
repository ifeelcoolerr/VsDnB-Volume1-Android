package ui.menu.story;

import data.animation.Animation;
import data.language.LanguageManager;
import data.song.Highscore;
import data.song.SongRegistry;

import play.PlayStatePlaylist;
import play.LoadingState;
import play.song.Song;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.transition.FlxTransitionableState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import ui.MusicBeatState;
import ui.menu.freeplay.FreeplayState;
import ui.menu.story.MenuItem;
import flixel.util.FlxTimer;
#if desktop
import api.Discord.DiscordClient;
#end

using StringTools;

typedef StoryModeRender = 
{
	/**
	 * The asset path for the render.
	 */
	var assetPath:String;

	/**
	 * The animation data for this render.
	 */
	var animation:AnimationData;
}

class StoryMenuState extends MusicBeatState
{
	var canInteract:Bool = true;

	var movedBack:Bool = false;
	var selectedWeek:Bool = false;

	var easeScore:Int = 0;
	var intendedScore:Int = 0;

	var scoreText:FlxText;

	var txtWeekTitle:FlxText;

	var curWeek:Int = 0;

	var yellowBG:FlxSprite;
	var gradientBg:FlxSprite;

	var txtTracklist:FlxText;
	var txtTrackdeco:FlxText;

	var grpWeekText:FlxTypedGroup<MenuItem>;

	var grpLocks:FlxTypedGroup<FlxSprite>;

	var weeks:Array<Week> = [
		// WARMUP
		new Week(['warmup'], LanguageManager.getTextString('story_tutorial'), [0xFF8A42B7], 'warmup', {
			assetPath: 'daverender_warmup',
			animation: {name: 'render', prefix: 'warmup', loop: true, offsets: [0, 86]}
		}), 
		// DAVE
		new Week(['house', 'insanity', 'polygonized'], LanguageManager.getTextString('story_daveWeek'), [0xFF4965FF], 'DaveHouse', {
			assetPath: 'daverender',
			animation: {name: 'render', prefix: 'davestuff', loop: true, offsets: [0, 95]}
		}), 
		// MISTER BAMBI bro
		new Week(['blocked', 'corn-theft', 'maze'], LanguageManager.getTextString('story_bambiWeek'), [0xFF00B515], 'bamboi', {
			assetPath: 'bambirender',
			animation: {name: 'render', prefix: 'bambiweek', loop: true, offsets: [0, 84]}
		}), 
		// SPLIT THE THONNNNN
		new Week(['splitathon'], LanguageManager.getTextString('story_finale'), [0xFF4965FF, 0xFF00B515], 'splitathon', {
			assetPath: 'daverender-splitathon',
			animation: {name: 'render', prefix: 'davesplitathon', loop: true, offsets: [0, 90]}
		}),
		// FESTEVAL
		new Week(['warmup', 'house', 'insanity'], LanguageManager.getTextString('story_festivalWeek'), [0xFF800080], 'festival', {
			assetPath: 'festivalrender',
			animation: {name: 'render', prefix: 'festival', loop: true, offsets: [0, 50]}
		}),
	];

	var awaitingToPlayMasterWeek:Bool;

	var weekBanners:FlxSpriteGroup = new FlxSpriteGroup();
	var weekRenders:FlxSpriteGroup = new FlxSpriteGroup();

	override function create()
	{
		if (FlxG.save.data.masterWeekUnlocked)
		{
			var weekName:String = !FlxG.save.data.hasPlayedMasterWeek ? LanguageManager.getTextString('story_masterWeekToPlay') : LanguageManager.getTextString('story_masterWeek');

			// MASTERA BAMBI			
			var jokeWeek = new Week(['supernovae', 'glitch', 'master'], weekName, [0xFF116E1C], FlxG.save.data.hasPlayedMasterWeek ? 'masterweek' : 'masterweekquestion', {
				assetPath: 'jokerender',
				animation: {name: 'render', prefix: 'joke', loop: true, offsets: [0, 73.8]}
			});

			weeks.push(jokeWeek);
		}

		#if desktop
		DiscordClient.changePresence("In the Story Menu", null);
		#end

		transIn = FlxTransitionableState.defaultTransIn;
		transOut = FlxTransitionableState.defaultTransOut;

		if (SoundController.music != null)
		{
			if (!SoundController.music.playing)
				SoundController.playMusic(Paths.music('freakyMenu'));
		}

		persistentUpdate = persistentDraw = true;

		scoreText = new FlxText(10, 0, 0, "SCORE: 49324858", 36);
		scoreText.setFormat("Comic Sans MS Bold", 32);
		scoreText.antialiasing = true;

		txtWeekTitle = new FlxText(FlxG.width * 0.7, 0, 0, "", 32);
		txtWeekTitle.setFormat("Comic Sans MS Bold", 32, FlxColor.WHITE, RIGHT);
		txtWeekTitle.antialiasing = true;
		txtWeekTitle.alpha = 0.7;

		var rankText:FlxText = new FlxText(0, 10);
		rankText.text = 'RANK: GREAT';
		rankText.setFormat(Paths.font("comic.ttf"), 32);
		rankText.antialiasing = true;
		rankText.size = scoreText.size;
		rankText.screenCenter(X);

		yellowBG = new FlxSprite(0, 56).makeGraphic(FlxG.width, 400, FlxColor.WHITE);
		yellowBG.color = weeks[0].weekColor[0];

		gradientBg = new FlxSprite(0, 56).makeGraphic(Std.int(yellowBG.width), Std.int(yellowBG.height), yellowBG.color);
		gradientBg.alpha = 0;

		grpWeekText = new FlxTypedGroup<MenuItem>();
		add(grpWeekText);

		var blackBarThingie:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, 57, FlxColor.BLACK);
		add(blackBarThingie);

		grpLocks = new FlxTypedGroup<FlxSprite>();
		add(grpLocks);

		for (i in 0...weeks.length)
		{
			var weekThing:MenuItem = new MenuItem(0, yellowBG.y + yellowBG.height + 80, i);
			weekThing.x += ((weekThing.width + 20) * i);
			weekThing.targetX = i;
			weekThing.antialiasing = true;
			grpWeekText.add(weekThing);
		}

		add(yellowBG);
		add(gradientBg);

		txtTrackdeco = new FlxText(0, yellowBG.x + yellowBG.height + 50, FlxG.width, LanguageManager.getTextString('story_track').toUpperCase(), 28);
		txtTrackdeco.alignment = CENTER;
		txtTrackdeco.font = rankText.font;
		txtTrackdeco.color = 0xFFe55777;
		txtTrackdeco.antialiasing = true;
		txtTrackdeco.screenCenter(X);

		txtTracklist = new FlxText(0, yellowBG.x + yellowBG.height + 80, FlxG.width, '', 28);
		txtTracklist.alignment = CENTER;
		txtTracklist.font = rankText.font;
		txtTracklist.color = 0xFFe55777;
		txtTracklist.antialiasing = true;
		txtTracklist.screenCenter(X);
		add(txtTrackdeco);
		add(txtTracklist);
		add(scoreText);
		add(txtWeekTitle);

		add(weekBanners);
		add(weekRenders);
		for (i in 0...weeks.length)
		{
			var bannerX = i != 0 ? weekBanners.members[i - 1].x + weekBanners.members[i - 1].width : 0;
			var weekBanner:FlxSprite = new FlxSprite(bannerX, 56).loadGraphic(Paths.image('storyMenu/weekBanners/${weeks[i].bannerName}'));
			weekBanner.antialiasing = true;
			weekBanner.active = false;
			weekBanners.add(weekBanner);

			switch (i)
			{
				case 3:
					var hasBeatSplitathon:Bool = (FlxG.save.data.splitathonBeat != null && FlxG.save.data.splitathonBeat);
					if (hasBeatSplitathon)
					{
						weeks[3].render.assetPath = 'splitathonrender';
						weeks[3].render.animation = {name: 'render', prefix: 'splitathon', loop: true, offsets: [0, 91]}
					}
			}
			var weekRender:FlxSprite = new FlxSprite(bannerX, 56);

			weekRender.frames = Paths.getSparrowAtlas('storyMenu/renders/${weeks[i].render.assetPath}');
			Animation.addToSprite(weekRender, weeks[i].render.animation);
			weekRender.animation.play(weeks[i].render.animation.name, true);
			weekRender.screenCenter();
			weekRender.x += bannerX;
			weekRender.y = weeks[i].render.animation.offsets[1];
			weekRender.active = true;
			weekRenders.add(weekRender);

			// Make it so the master week only shows after playing the week.
			if (i == 5)
			{
				weekRender.visible = FlxG.save.data.hasPlayedMasterWeek;
			}
		}

		updateText();

		if (awaitingToPlayMasterWeek)
		{
			awaitingToPlayMasterWeek = false;
			changeWeek(5 - curWeek);
		}
		else
		{
			changeWeek(0);
		}
		#if mobileC
		addVirtualPad(LEFT_RIGHT, A_B);
		#end
		super.create();
	}

	var titleTween:FlxTween;

	override function update(elapsed:Float)
	{
		txtWeekTitle.text = weeks[curWeek].weekName.toUpperCase();
		txtWeekTitle.x = FlxG.width - (txtWeekTitle.width + 10);

		if (!selectedWeek && !movedBack && canInteract)
		{
			if (controls.LEFT_P || FlxG.mouse.wheel < 0)
			{
				changeWeek(-1);
			}
			if (controls.RIGHT_P || FlxG.mouse.wheel > 0)
			{
				changeWeek(1);
			}
			if (controls.ACCEPT)
			{
				selectWeek();
			}
			if (controls.BACK && !movedBack)
			{
				SoundController.play(Paths.sound('cancelMenu'));
				movedBack = true;
				FlxG.switchState(() -> new MainMenuState());
			}
		}

		if (FlxG.keys.justPressed.SEVEN #if mobileC || FlxG.android.justReleased.BACK #end && !FlxG.save.data.masterWeekUnlocked && canInteract)
		{
			canInteract = false;
			SoundController.music.fadeOut(1, 0);

			FlxG.camera.shake(0.01, 5.1);
			FlxG.camera.fade(FlxColor.WHITE, 5.05, false, function()
			{
				FlxG.save.data.masterWeekUnlocked = true;
				FlxG.save.data.hasPlayedMasterWeek = false;
				for (i in ['supernovae', 'glitch', 'master'])
				{
					FreeplayState.unlockSong(i);
				}
				awaitingToPlayMasterWeek = true;
				FlxG.save.flush();

				FlxG.resetState();
			});
			SoundController.play(Paths.sound('doom'));
		}

		super.update(elapsed);
	}

	function selectWeek()
	{
		if (curWeek == 4)
		{
			FlxG.camera.shake(0.05, 0.1);
			SoundController.play(Paths.sound('missnote1'), 0.9);

			return;
		}
		SoundController.play(Paths.sound('confirmMenu'));
		grpWeekText.members[curWeek].startFlashing();

		selectedWeek = true;

		PlayStatePlaylist.reset();
		PlayStatePlaylist.isStoryMode = true;
		PlayStatePlaylist.storyWeek = curWeek;
		PlayStatePlaylist.songList = weeks[curWeek].songList;

		var storySong:Song = SongRegistry.instance.fetchEntry(PlayStatePlaylist.songList.shift().toLowerCase());
		var params = {targetSong: storySong, targetVariation: ''}

		new FlxTimer().start(1, function(tmr:FlxTimer)
		{
			switch (PlayStatePlaylist.storyWeek)
			{
				case 1:
					SoundController.music.stop();
					LoadingState.loadPlayState(params, true);
				case 5:
					if (!FlxG.save.data.hasPlayedMasterWeek)
					{
						FlxG.save.data.hasPlayedMasterWeek = true;
						FlxG.save.flush();
					}
					LoadingState.loadPlayState(params, true);
				default:
					LoadingState.loadPlayState(params, true);
			}
		});
	}

	function changeWeek(change:Int = 0):Void
	{
		curWeek += change;

		if (curWeek > weeks.length - 1)
			curWeek = 0;
		if (curWeek < 0)
			curWeek = weeks.length - 1;

		var bullShit:Int = 0;

		for (item in grpWeekText.members)
		{
			item.changeTargetX(bullShit - curWeek);
			if (item.targetX == 0)
				item.alpha = 1;
			else
				item.alpha = 0.6;
			bullShit++;
		}
		updateBgColor();

		SoundController.play(Paths.sound('scrollMenu'));

		updateText();
		updateBgColor();

		
		if (titleTween != null)
		{
			titleTween.active = false;
			titleTween?.cancel();
			titleTween?.destroy();
			titleTween = null;
		}
		titleTween = FlxTween.tween(weekBanners, {x: -FlxG.width * curWeek}, MenuItem.easeTime, {
			type: ONESHOT,
			ease: MenuItem.easeType,
			onComplete: (t:FlxTween) -> {
				weekRenders.x = weekBanners.x;
		
				titleTween?.destroy();
				titleTween = null;
			},
			onUpdate: (t:FlxTween) -> {
				weekRenders.x = weekBanners.x;
			}
		});
	}
	
	function updateBgColor()
	{
		var colorList = weeks[curWeek].weekColor;

		if (colorList.length == 1)
		{
			FlxTween.color(yellowBG, 0.25, yellowBG.color, colorList[0]);
			FlxTween.tween(yellowBG, {alpha: 1}, 0.25);

			FlxTween.tween(gradientBg, {alpha: 0}, 0.25);
		}
		else
		{
			FlxGradient.overlayGradientOnFlxSprite(gradientBg, yellowBG.pixels.width, yellowBG.pixels.height, colorList, 1, 0);
			gradientBg.alpha = 0;

			FlxTween.tween(gradientBg, {alpha: 1}, 0.25);
			FlxTween.tween(yellowBG, {alpha: 0}, 0.25);
		}
	}

	function updateText()
	{
		txtTracklist.text = "";

		var stringThing:Array<String> = [for (songId in weeks[curWeek].songList) SongRegistry.instance.fetchEntry(songId).songName];
		switch (curWeek)
		{
			case 4:
				stringThing = ['???', '???', '???', '???'];
			case 5:
				if (!FlxG.save.data.hasPlayedMasterWeek)
					stringThing = ['???', '???', '???'];
		}
		txtTracklist.text = stringThing.join(' - ');

		#if !switch
		intendedScore = Highscore.getWeekScore(curWeek);
		if (currentScoreTween != null)
		{
			currentScoreTween.destroy();
		}
		currentScoreTween = FlxTween.num(easeScore, intendedScore, 0.35, {type: FlxTweenType.ONESHOT, ease: FlxEase.quadOut}, updateEaseScore);
		#end
	}

	var currentScoreTween:flixel.tweens.misc.NumTween;

	function updateEaseScore(value:Float):Void
	{
		easeScore = Std.int(value);
		scoreText.text = LanguageManager.getTextString('story_weekScore') + " " + easeScore;
	}
}

class Week
{
	public var songList:Array<String>;
	public var weekName:String;
	public var weekColor:Array<FlxColor>;
	public var bannerName:String;
	public var render:StoryModeRender;

	public function new(songList:Array<String>, weekName:String, weekColor:Array<FlxColor>, bannerName:String, ?render:StoryModeRender)
	{
		this.songList = songList;
		this.weekName = weekName;
		this.weekColor = weekColor;
		this.bannerName = bannerName;
		this.render = render;
	}
}
