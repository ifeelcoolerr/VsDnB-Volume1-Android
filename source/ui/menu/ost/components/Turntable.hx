package ui.menu.ost.components;

import audio.GameSound;
import backend.Conductor;
import data.song.SongData.SongTimeChange;
import data.language.LanguageManager;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxStringUtil;
import graphics.audio.SpectrogramVisualizer;
import ui.menu.ost.OSTMenuState;
import util.tools.Preloader;
#if desktop
import api.Discord.DiscordClient;
#end

enum RemixModeType
{
    BPM;
    SPEED;
}
/**
 * A component used in the OST menu to play, edit, and manipulate features of a song.
 */
class Turntable extends FlxSpriteGroup
{
    /**
     * The default font used when there's text on this turntable.
     */
    static final DEFAULT_FONT:String = Paths.font('seven_segment.ttf');
    

    // GENERAL //

    /**
     * The OST menu that this turntable is on.
     */
    public var parent:OSTMenuState;

    /**
     * The current playing chart that's used to hold the song's data.
     * This is dependent on the song's selected variation, and may change the instrumental and vocals, etc.
     */
    public var currentPlayData(default, null):OSTPlayData;

    /**
     * The current instrumental track playing on the turntable. 
     */
    public var instrumentalTrack(default, null):GameSound = new GameSound();

    /**
     * The current vocals audio track that's playing on the turntable.
     */
    public var vocalsTrack(default, null):GameSound = new GameSound();

    /**
     * The spectrogram that's displayed in the audio monitor.
     */
    public var spectrogram:SpectrogramVisualizer;

    /**
     * Is the song from the turntable currently playing?
     */
    public var isSongPlaying:Bool = false;
    
    public var remixType:RemixModeType = RemixModeType.SPEED;

    /**
     * The current speed at which the turntable's going at.
     */
    var speed:Float = 1.0;

    /**
     * The speed at which the vinyl turns at.
     */
    var vinylSpeed:Float = 1.0;

    /**
     * The BPM added from the speed/slow buttons that's added on the song's pitch to simulate it's BPM change.
     */
    var bpmAddend:Float = 0;

    /**
     * The current speed of the song, based on the current BPM of the turntable.
     */
    var bpmSpeed(get, never):Float;

    function get_bpmSpeed():Float
    {
        return (Conductor.instance.currentTimeChange.bpm + bpmAddend) / Conductor.instance.currentTimeChange.bpm;
    }
    
    /**
     * The type of time that's being displayed by the time monitor;
     */
    var timeDisplay:String = 'timeLeft';

    /**
     * A tween meant to help simulate the turntable pausing and resuming.
     */
    public var speedTween:FlxTween;

    /**
     * The looping noise sound that plays while the turntable has a loaded song in.
     */
    public var grainLoop:GameSound;

    /**
     * The parent OST menu that this turntable is on.
     */
    var parentMenu:OSTMenuState;

    /**
     * The background of the turntable that displays under the vinyl.
     */
    var table:FlxSprite;

    /**
     * The turning disc that displays at the center of the turntable.
     */
    var vinyl:FlxSprite;


    // BUTTONS //

    /**
     * Plays the currently selected song when pressed.
     */
    var playButton:OSTButton;

    /**
     * Pauses the current song that's playing if anything is.
     */
    var pauseButton:OSTButton;

    /**
     * Speeds up the currently playing song by 0.05x.
     */
    var speedButton:OSTButton;
    
    /**
     * Slows down the currently playing song by 0.05x.
     */
    var slowButton:OSTButton;

    /**
     * Toggles the vocals of the currently playing song.
     */
    var vocalsButton:OSTButton;

    /**
     * Toggles the instrumental of the currently playing song.
     */
    var instrumentalButton:OSTButton;

    /**
     * A button that displays the tutorial manual on pressed.
     */
    var manualButton:OSTButton;

    /**
     * A button that switches between whether the BPM is changed, or the speed of the song is changed via the pitch.
     */
    var remixButton:OSTButton;


    // RENDER OBJECTS //

    /**
     * Text displayed on the turntable's left monitor that shows the song's time progress.
     */
    var timeText:FlxText;
    
    /**
     * Text that displays the current speed the turntable is playing the song.
     */
    var speedText:FlxText;

    /**
     * Text that displays the current remix the turntable is playing the song.
     */
    var remixText:FlxText;


    /**
     * Text that displays the name of the current song.
     */
    var songNameText:FlxText;
    
    /**
     * Text that displays the name of the composer(s) of the current song.
     */
    var songComposerText:FlxText;
    
    /**
     * Text that displays the current BPM of the song playing.
     */
    var songBPMText:FlxText;

    public function new(x:Float = 0, y:Float = 0, parent:OSTMenuState)
    {
        super(x, y);

        this.parent = parent;

        table = new FlxSprite().loadGraphic(Paths.image('ost/table'));
        add(table);

        vinyl = new FlxSprite().loadGraphic(Paths.image('ost/vinyl'));
        vinyl.x = (table.x - this.x) + (table.width - vinyl.width) / 2; // Center the vinyl with the table.
        vinyl.y = 22;
        add(vinyl);

        constructButtons();
        buildTextMetadata();
        buildAdditionalData();

        grainLoop = new GameSound().load(Paths.sound('ost/grain'));
        grainLoop.looped = true;

        // Add the instrumental and vocals track into the sound group so they're properly updated with every other sound.
        SoundController.add(instrumentalTrack);
        SoundController.add(vocalsTrack);
        SoundController.add(grainLoop);

        Conductor.instance.onStepHit.add(onStepHit);
        Conductor.instance.onBeatHit.add(onBeatHit);
        Conductor.instance.onMeasureHit.add(onMeasureHit);
        Conductor.instance.onTimeChangeHit.add(onTimeChangeHit);
    }

    override function update(elapsed:Float)
    {
        if (isSongPlaying)
        {
            vinyl.angle += 50 * vinylSpeed * elapsed;
            Conductor.instance.update(instrumentalTrack.time);

            switch (timeDisplay)
            {
                case 'timeElapsed':
                    var currentTime:String = FlxStringUtil.formatTime(instrumentalTrack.time / 1000);
                    var currentLength:String = FlxStringUtil.formatTime(instrumentalTrack.length / 1000);
                    setTimeText(currentTime);
                    #if desktop
                    DiscordClient.changePresence('In the OST Menu', 'Listening to ${currentPlayData.name} ($currentTime / $currentLength)');
                    #end
                case 'timeLeft':
                    var timeLeft:String = FlxStringUtil.formatTime((instrumentalTrack.length - instrumentalTrack.time) / 1000);

                    setTimeText(FlxStringUtil.formatTime((instrumentalTrack.length - instrumentalTrack.time) / 1000));
                    #if desktop
                    DiscordClient.changePresence('In the OST Menu', 'Listening to ${currentPlayData.name} ($timeLeft)');
                    #end
            }
        }

        if (FlxG.mouse.overlaps(timeText) && FlxG.mouse.justPressed)
        {
            timeDisplay = (timeDisplay == 'timeElapsed') ? 'timeLeft' : 'timeElapsed';
        }

        super.update(elapsed);
    }

    override function destroy():Void
    {
        SoundController.remove(instrumentalTrack);
        SoundController.remove(vocalsTrack);
        SoundController.remove(grainLoop);

        Conductor.instance.onStepHit.remove(onStepHit);
        Conductor.instance.onBeatHit.remove(onBeatHit);
        Conductor.instance.onMeasureHit.remove(onMeasureHit);
        Conductor.instance.onTimeChangeHit.remove(onTimeChangeHit);

        super.destroy();
    }

    function onStepHit(step:Int)
    {
        resyncVocals();
    }
    
    function onBeatHit(beat:Int) {}

    function onMeasureHit(measure:Int) {}
    
    function onTimeChangeHit(timeChange:SongTimeChange)
    {
        if (remixType == BPM)
        {
            // Update the speed of the song based on the new BPM;
            setBPM(timeChange.bpm + bpmAddend);
        }
        updateSpeedText();
        updateBPMText();
    }

    /**
     * Constructs all of the necessary buttons in this turntable.
     */
    function constructButtons():Void
    {
        playButton = new OSTButton(90, 53, {
            id: 'play',
            idle: {name: 'idle', prefix: 'buttonplay_norm'},
            pressed: {name: 'pressed', prefix: 'buttonplay_click'},
            pressType: SINGLE
        });
        playButton.onPress = () -> {
            playSong();   
        }
        add(playButton);

        pauseButton = new OSTButton(90, 121, {
            id: 'pause',
            idle: {name: 'idle', prefix: 'buttonpause_norm'},
            pressed: {name: 'pressed', prefix: 'buttonpause_click'},
            pressType: SINGLE,
        });
        pauseButton.onPress = pauseSong;
        add(pauseButton);
        
        speedButton = new OSTButton(90, 187, {
            id: 'speed',
            idle: {name: 'idle', prefix: 'buttonspeed_norm'},
            pressed: {name: 'pressed', prefix: 'buttonspeed_click'},
            pressType: SINGLE,
        });
        speedButton.onPress = () -> {
            switch (remixType)
            {
                case SPEED:
                    increaseSpeed(0.05);
                case BPM:
                    increaseBPM(1);
            }
        }
        add(speedButton);
        
        slowButton = new OSTButton(90, 251, {
            id: 'slow',
            idle: {name: 'idle', prefix: 'buttonslow_norm'},
            pressed: {name: 'pressed', prefix: 'buttonslow_click'},
            pressType: SINGLE,
        });
        slowButton.onPress = () -> {
            switch (remixType)
            {
                case SPEED:
                    decreaseSpeed(0.05);
                case BPM:
                    decreaseBPM(1);
            }
        }
        add(slowButton);

        vocalsButton = new OSTButton(689, 53, {
            id: 'vocals', 
            idle: {name: 'idle_toggle', prefix: 'buttonvocalno_norm'},
            pressed: {name: 'pressed_toggle', prefix: 'buttonvocalno_click'},
            toggleIdle: {name: 'idle', prefix: 'buttonvocal_norm'},
            togglePressed: {name: 'pressed', prefix: 'buttonvocal_click'},
            pressType: TOGGLE,
            startingSelect: true,
            forceSelect: true,
        });
        vocalsButton.onTogglePress = (v:Bool) -> {
            vocalsTrack.volume = v ? 1.0 : 0.0; 
        }
        add(vocalsButton);
        
        instrumentalButton = new OSTButton(689, 121, {
            id: 'instrumental', 
            idle: {name: 'idle_toggle', prefix: 'buttoninstno_norm'},
            pressed: {name: 'pressed_toggle', prefix: 'buttoninstno_click'},
            toggleIdle: {name: 'idle', prefix: 'buttoninst_norm'},
            togglePressed: {name: 'pressed', prefix: 'buttoninst_click'},
            pressType: TOGGLE,
            startingSelect: true,
            forceSelect: true,
        });
        instrumentalButton.onTogglePress = (v:Bool) -> {
            instrumentalTrack.volume = v ? 1.0 : 0.0;
        }
        add(instrumentalButton);

        remixButton = new OSTButton(689, 181, {
            id: 'remix', 
            idle: {name: 'idle', prefix: 'buttonremix_norm'},
            pressed: {name: 'pressed', prefix: 'buttonremix_click'},
            pressType: SINGLE,
        });
        remixButton.onPress = () -> {
            switch (remixType)
            {
                case SPEED:
                    remixType = BPM;
                    setBPM(Conductor.instance.currentTimeChange.bpm + bpmAddend);
                    setRemixText(LanguageManager.getTextString('ost_remixMode_bpm'));
                case BPM:
                    remixType = SPEED;
                    setSpeed(speed);
                    setRemixText(LanguageManager.getTextString('ost_remixMode_speed'));
            }
        }
        add(remixButton);
        
        manualButton = new OSTButton(689, 286, {
            id: 'manual', 
            idle: {name: 'idle', prefix: 'buttonmanual_norm'},
            pressed: {name: 'pressed', prefix: 'buttonmanual_click'},
            pressType: SINGLE,
        });
        manualButton.onPress = () -> {
            parent.canInteract = false;
            parent.openManual();
        }
        add(manualButton);
    }

    function buildAdditionalData():Void
    {
        spectrogram = new SpectrogramVisualizer({
            barCount: 10,
            width: 125, 
            height: 60, 
            spacing: 3,
            minFrequency: 50,
            maxFrequency: 30000,
            peakLines: false,
            color: FlxColor.WHITE,
        });
        spectrogram.setPosition(650, 497);
        spectrogram.visible = false;
        add(spectrogram);
    }

    /**
     * Builds all text that displays the current metadata related to this turntable.
     */
    function buildTextMetadata():Void
    {
        timeText = new FlxText(100, 483, 0);
        timeText.setFormat(DEFAULT_FONT, 72, FlxColor.WHITE, FlxTextAlign.CENTER);
        add(timeText);
        setTimeText('88:88');
        timeText.scale.set(0.8, 1);

        speedText = new FlxText(113, 437, 0);
        speedText.setFormat(DEFAULT_FONT, 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        speedText.borderSize = 1.5;
        add(speedText);
        
        remixText = new FlxText(626, 447, 0, 'Remix Mode: BPM');
        remixText.setFormat(DEFAULT_FONT, 24, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        remixText.borderSize = 1.5;
        add(remixText);

        songNameText = new FlxText(373, 479, 0);
        songNameText.setFormat(DEFAULT_FONT, 30, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        songNameText.borderSize = 1.5;
        add(songNameText);
        
        songComposerText = new FlxText(330, 519, 0);
        songComposerText.setFormat(DEFAULT_FONT, 30, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        songComposerText.borderSize = 1.5;
        add(songComposerText);
        
        songBPMText = new FlxText(410, 559, 0);
        songBPMText.setFormat(DEFAULT_FONT, 30, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        songBPMText.borderSize = 1.5;
        add(songBPMText);

        setRemixText('Remix Mode: SPEED');
        setSpeedText('1.00x');
        setSongNameText('???');
        setComposersText('???');
        setBPMText('???');
    }

    public function forEachButton(func:OSTButton->Void)
    {
        for (button in [playButton, pauseButton, speedButton, slowButton, vocalsButton, manualButton, remixButton])
            func(button);
    }
    
    /**
     * Load the turntable given an `OSTPlayData`
     * @param playData The play data to load. 
     */
    public function loadSong(playData:OSTPlayData)
    {
        // Unload the current audio to save memory.
        if (currentPlayData != null)
        {   
            Preloader.removeCachedSound(currentPlayData.instrumental);

            if (currentPlayData.vocals != null)
                Preloader.removeCachedSound(currentPlayData.vocals);
        }
        this.currentPlayData = playData;

        // Cache the song so it loads easier.
        // This'll also store the song into the cache to make sure it gets clear from memory.
        Preloader.cacheSound(this.currentPlayData.instrumental);
        if (currentPlayData.vocals != null)
            Preloader.cacheSound(this.currentPlayData.vocals);

        var vinylPath:String = currentPlayData.vinylPath ?? 'vinyl_extra';
        vinyl.loadGraphic(Paths.image('ost/vinyls/$vinylPath'));

        // Load the chart's audio tracks.
        instrumentalTrack.load(this.currentPlayData.instrumental);

        if (currentPlayData.vocals != null)
            vocalsTrack.load(this.currentPlayData.vocals);
        else
            vocalsTrack = new GameSound();

        instrumentalTrack.volume = instrumentalButton.selected ? 1.0 : 0.0; 
        vocalsTrack.volume = vocalsButton.selected ? 1.0 : 0.0; 

        instrumentalTrack.looped = true;
        vocalsTrack.looped = true;

        Conductor.instance.mapTimeChanges(currentPlayData.timeChanges);

        // Set the conductor to the beginning so it's at the right time change.
        Conductor.instance.update(0);

        // BPM was changed, make sure it's reset back.
        if (remixType == BPM)
        {
            setBPM(Conductor.instance.currentTimeChange.bpm + bpmAddend);   
        }
        else
        {
            // Else, reset the speed.
            setSpeed(this.speed);
        }

        // Update the track information based on the current song.
        setSongNameText(currentPlayData.name);
        setComposersText(currentPlayData.composers.formatStringList());
        updateSpeedText();
        updateBPMText();
        updateTimeText();

        spectrogram.gradientColor = currentPlayData.colors;
    }

    /**
     * Plays (or resumes) the current song loaded into the turntable.
     */
    function playSong():Void
    {
        // Cancel the transition if it's already happening, or no song is playing.
        if (isSongPlaying || speedTween != null || currentPlayData == null)
            return;

        isSongPlaying = true;
        FlxG.autoPause = false;

        grainLoop.play();

        var targetSpeed:Float = remixType == BPM ? bpmSpeed : this.speed;

        speedTween = FlxTween.num(0.01, targetSpeed, 0.5, {
            onComplete: (t:FlxTween) -> {
                speedTween.destroy();
                speedTween = null;
            }
        }, (t:Float) -> {
            vinylSpeed = t;
            setSongPitch(t);
        });
        
        instrumentalTrack.play();
        vocalsTrack.play();

        spectrogram.visible = true;
        spectrogram.start(this.instrumentalTrack);
    }

    /**
     * Pauses the current song loaded into the turntable, if anything is.
     */
    function pauseSong():Void
    {
        // Cancel the transition if it's already happening, or no song is playing.
        if (!isSongPlaying || speedTween != null)
            return;

        FlxG.autoPause = true;

        speedTween = FlxTween.num(speed, 0.01, 0.5, {
            onComplete: (t:FlxTween) -> {
                forcePauseSong();
                
                speedTween.destroy();
                speedTween = null;
            }
        }, (t:Float) -> {
            vinylSpeed = t;
            setSongPitch(t);
        });

        resetSongState();
    }

    /**
     * Force pauses a song in the case where it needed to be restarted/reset. 
     */
    public function forcePauseSong():Void
    {
		instrumentalTrack.pause();
		vocalsTrack.pause();

        resetSongState();
    }

    /**
     * Helper function to reset the state a song is in after it's either finished, or paused.
     */
    function resetSongState():Void
    {
        grainLoop.pause();

        isSongPlaying = false;
        spectrogram.visible = false;
        spectrogram.stop();

        #if desktop
        DiscordClient.changePresence('In the OST Menu', null);
        #end
    }

    /**
     * Sets the speed/pitch that the turntable's playing the song at.
     * @param speed The new speed.
     */
    function setSpeed(speed:Float):Void
    {
        this.speed = FlxMath.roundDecimal(speed, 2);
        this.vinylSpeed = speed;
        setSongPitch(speed);

        var speedText:String = Std.string(this.speed);
        var speedText:String = validateFloatSpeedText(this.speed);

        setSpeedText('${speedText}x');
        updateBPMText();
    }

    /**
     * Add the speed of the turntable by the given amount.
     * @param amount The amount to increase by.
     */
    function increaseSpeed(amount:Float):Void
    {
        setSpeed(Math.min(10, speed + amount));
    }
    
    /**
     * Subtract the speed of the turntable by the given amount.
     * @param amount The amount to decrease by.
     */
    function decreaseSpeed(amount:Float):Void
    {
        setSpeed(Math.max(0, speed - amount));
    }
    
    /**
     * Manually set the pitch of the current song playing to the given value.
     * @param pitch The new pitch value.
     */
    function setSongPitch(pitch:Float)
    {
        instrumentalTrack.pitch = Math.max(0, pitch);
        vocalsTrack.pitch = Math.max(0, pitch);
    }

    /**
     * Sets the BPM of the turntable
     * @param bpm The new bpm.
     */
    function setBPM(bpm:Float):Void
    {
        // Clamp BPM so it doesn't go below 1.
        bpm = Math.max(1, bpm);

        bpmAddend = bpm - Conductor.instance.currentTimeChange.bpm;

        var speedDifference:Float = bpm / Conductor.instance.currentTimeChange.bpm;
        var speedText:String = validateFloatSpeedText(FlxMath.roundDecimal(speedDifference, 2));

        this.vinylSpeed = speedDifference;

        setSongPitch(speedDifference);
        setSpeedText('${speedText}x');
        updateBPMText();
    }

    function increaseBPM(amount:Int)
    {
        setBPM((Conductor.instance.currentTimeChange.bpm + bpmAddend) + amount);
    }

    function decreaseBPM(amount:Int)
    {
        setBPM((Conductor.instance.currentTimeChange.bpm + bpmAddend) - amount);
    }
    
    /**
     * Resyncs the vocals of the song to make sure they're in sync with the instrumental playing.
     */
    function resyncVocals():Void
    {
        if (vocalsTrack.time > instrumentalTrack.time + 20 || vocalsTrack.time < instrumentalTrack.time - 20)
        {
            vocalsTrack.pause();
            vocalsTrack.time = instrumentalTrack.time;
            vocalsTrack.play();
            Conductor.instance.update();
        }
}
    
    function setTimeText(newText:String)
    {
        timeText.scale.set(1, 1);
        timeText.updateHitbox();
        timeText.text = newText;
        timeText.x = (100 + this.x) + (136 - timeText.textField.textWidth) / 2;
    }
    
    function updateTimeText():Void
    {
		switch (timeDisplay)
		{
			case 'timeElapsed':
				setTimeText(FlxStringUtil.formatTime(instrumentalTrack.time / 1000));
			case 'timeLeft':
				setTimeText(FlxStringUtil.formatTime((instrumentalTrack.length - instrumentalTrack.time) / 1000));
		}
    }

    function setSpeedText(newText:String):Void
    {
        newText = LanguageManager.getTextString('ost_speedLabel') + ': $newText';
        speedText.text = newText;

        speedText.x = (83 + this.x) + (162 - speedText.textField.textWidth) / 2;
    }

    function setRemixText(newText:String):Void
    {
        remixText.text = newText;
        remixText.x = (631 + this.x) + (162 - remixText.textField.textWidth) / 2;
    }

    function setSongNameText(newText:String)
    {
        songNameText.text = newText;
        trimTextToWidth(songNameText, 381);
        songNameText.x = vinyl.x + (vinyl.width - songNameText.textField.textWidth) / 2;
    }
    
    function setComposersText(newText:String)
    {
        songComposerText.text = newText;
        trimTextToWidth(songComposerText, 381);
        songComposerText.x = vinyl.x + (vinyl.width - songComposerText.textField.textWidth) / 2;
    }
    
    function setBPMText(newText:String)
    {
        songBPMText.text = newText;
        trimTextToWidth(songBPMText, 381);
        songBPMText.x = vinyl.x + (vinyl.width - songBPMText.textField.textWidth) / 2;
    }

    function updateSpeedText():Void
    {
        switch (remixType)
        {
            case SPEED:
                var speedText:String = validateFloatSpeedText(FlxMath.roundDecimal(speed, 2));
                setSpeedText('${speedText}x');
            case BPM:
                var bpmSpeedText:String = validateFloatSpeedText(FlxMath.roundDecimal(bpmSpeed, 2));
                setSpeedText('${bpmSpeedText}x');
        }
    }

    function validateFloatSpeedText(number:Float):String
    {
        var text:String = Std.string(FlxMath.roundDecimal(number, 2));
        var decimals:Int = FlxMath.getDecimals(number);

		if (decimals == 0)
			text += '.';

		for (i in 0...2 - decimals)
			text += '0';


        return text;
    }

    function updateBPMText():Void
    {
        if (currentPlayData != null)
        {
            switch (remixType)
            {
                case SPEED:
                    setBPMText('BPM: ${FlxMath.roundDecimal(Conductor.instance.currentTimeChange.bpm * speed, 2)}');
                case BPM:
                    setBPMText('BPM: ${FlxMath.roundDecimal(Conductor.instance.currentTimeChange.bpm + bpmAddend, 2)}');
            }
        }
    }
    
    function trimTextToWidth(text:FlxText, width:Float):Void
    {
        var wasTrimmed:Bool = false;

        // The - 40 is to account for adding `...` to the end of the text.
        while (text.textField.textWidth > width - 40)
        {
            wasTrimmed = true;
            text.text = text.text.substr(0, text.text.length - 1);
        }
        if (wasTrimmed)
        {
            text.text += "...";
        }
    }
}