package ui.menu.ost;

import openfl.display.BitmapData;
import flixel.group.FlxSpriteGroup;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import play.song.Song;
import play.ui.HealthIcon;
import ui.menu.MainMenuState;
import ui.Cursor;
import ui.menu.freeplay.category.Category;
import ui.menu.ost.components.Turntable;
import ui.menu.ost.components.OSTButton;
import ui.menu.ost.components.OSTManual;
import util.FileUtil;
import util.GradientUtil;
import util.SortUtil;
#if desktop
import api.Discord.DiscordClient;
#end

enum OSTMenuSelectState
{
    CATEGORY;
    SONG;
}

/**
 * A menu used to view the soundtrack of the mod.
 */
@:allow(ui.menu.ost.components)
class OSTMenuState extends MusicBeatState
{
    /**
     * The grey background displayed under the menu.
     */
    var bg:FlxSprite;

    /**
     * The original menu BG graphic.
     * Used to apply gradients to the background.
     */
    var menuBgGraphic:BitmapData;

    /**
     * The turntable used to play the song.
     */
    var turnTable:Turntable;

    /**
     * Playrobot's button where on press will toggle whether the selection bar is visible, or not.
     */
    var playrobotButton:FlxSprite;

    /**
     * The manual that's shown on the OST menu when the "Manual" is opened.
     */
    var manual:OSTManual;

    /**
     * Whether this menu is interactable right now, or not.
     */
    var canInteract:Bool = true;

    // SELECTION BAR //
    
    /**
     * The list of categories the user is able to select in the menu.
     */
    final categoryList:Array<String> = ['main', 'extras', 'joke', 'misc'];

    /**
     * The current selection type that the user's on. This can either mean that the user's selecting a category, or selecting a song from the bar.
     */
    var currentSelectType:OSTMenuSelectState = CATEGORY;

    /**
     * The current category that the user has selected.
     */
    var currentCategory:Category;
    
    /**
     * The current category that's selected, in terms of the index.
     */
    var currentCategorySelected:Int = 0;

    /**
     * The index of the current selected song.
     */
    var currentSongSelected:Int = 0;

    /**
     * The amount of songs the user's able to select.
     */
    var categorySongsCount(get, never):Int;

    function get_categorySongsCount():Int
    {
        return grpSongsList.members.length - 1;
    }

    /**
     * Whether the selection bar is currently transitioning in, or out of the screen.
     */
    var isTransitioning:Bool = false;

    /**
     * Is the selection bar currently visible, or did the user disable it through playrobot?
     */
    var isSelectionBarVisible:Bool = true;

    /**
     * The current song option the user has selected.
     */
    var selectedSongOption:OSTSongOption;

    /**
     * The group that holds all of the sprites related to the song selection side of the menu.
     */
    var selectionBarGroup:FlxSpriteGroup;

    var selectSongTween:FlxTween;

    var grpSongSelection:FlxSpriteGroup = new FlxSpriteGroup();

    /**
     * A group that holds all of the song options that the user can select.
     */
    var grpSongsList:FlxTypedSpriteGroup<OSTSongOption> = new FlxTypedSpriteGroup<OSTSongOption>();

    /**
     * The left arrow button used for switching between categories.
     */
    var arrowLeft:FlxSprite;
    
    /**
     * The right arrow button used for switching between categories.
     */
    var arrowRight:FlxSprite;

    /**
     * The black border overlayed under the rest of the sprites.
     */
    var categoryBlackBorder:FlxSprite;
    
    /**
     * The icon used to display the current category selected.
     */
    var categoryIcon:FlxSprite;

    /**
     * A list of all the selectable variations for this song.
     * Populated on song selected. Dependent on the currently selected song.
     */
    var currentSongVariationsList:Array<String>;

    /**
     * The current selected variation, in terms of the index.
     */
    var selectedVariationIndex:Int = 0;

    /**
     * The id of the currently selected variation.
     */
    var selectedVariation(get, never):String;

    function get_selectedVariation():String
    {
        return currentSongVariationsList[selectedVariationIndex] ?? Song.DEFAULT_VARIATION;
    }

    /**
     * Does the current song selected have more variations than just the default variation?
     */
    var hasMultipleVariations(get, never):Bool;

    function get_hasMultipleVariations():Bool
    {
        return currentSongVariationsList.length > 1;
    }

    /**
     * The left arrow used to switch between variations.
     */
    var arrowLeftVariation:FlxText;
    
    /**
     * The right arrow used to switch between variations.
     */
    var arrowRightVariation:FlxText;

    override function create():Void
    {
        super.create();

        FlxG.signals.preStateSwitch.addOnce(() ->
        {
            FlxG.autoPause = true;
            Cursor.hide();
        });

        SoundController.music?.stop();
        SoundController.play(Paths.sound('ost/start_scratch'));

        // Build background.
        // This starts as a gray background, but when a song is selected it changes to a gradient.
		menuBgGraphic = FileUtil.randomizeBG().bitmap;
        
        bg = new FlxSprite().loadGraphic(menuBgGraphic);
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
        bg.color = FlxColor.GRAY;
		add(bg);

        // Generate the turntable, this is what'll be used to control the playing song.
        turnTable = new Turntable(this);
        turnTable.screenCenter();
        turnTable.x += 150;
        add(turnTable);

        buildSelectionBar();
        buildAdditionalUI();

        changeCategorySelection();
        
        Cursor.show();
        
        #if desktop
        DiscordClient.changePresence('In the OST Menu', null);
        #end

        #if mobileC
        addVirtualPad(LEFT_FULL, A_B);
        #end
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (controls.BACK #if mobileC || FlxG.android.justReleased.BACK #end)
        { 
            FlxG.autoPause = true;
            FlxG.switchState(() -> new MainMenuState());
        }
        
        if (!canInteract)
            return;

        if (isSelectionBarVisible)
        {
            switch (currentSelectType)
            {
                case CATEGORY:
                    if (FlxG.keys.justPressed.UP #if mobileC || virtualPad.buttonUp.justPressed #end || FlxG.mouse.wheel > 0)
                    {
                        toggleCategorySelect(false);
                        changeSongSelection(categorySongsCount - currentSongSelected);
                    }
                    if (FlxG.keys.justPressed.DOWN #if mobileC || virtualPad.buttonDown.justPressed #end || FlxG.mouse.wheel < 0)
                    {
                        toggleCategorySelect(false);
                        changeSongSelection(0 - currentSongSelected);
                    }

                    if (FlxG.keys.pressed.LEFT #if mobileC || virtualPad.buttonLeft.pressed #end || FlxG.mouse.wheel < 0)
                    {
                        arrowLeft.scale.set(0.8, 0.8);

                        if (FlxG.keys.justPressed.LEFT #if mobileC || virtualPad.buttonLeft.justPressed #end)
                            changeCategorySelection(-1);
                    }
                    else
                    {
                        arrowLeft.scale.set(1, 1);
                    }
                    
                    if (FlxG.keys.pressed.RIGHT #if mobileC || virtualPad.buttonRight.pressed #end)
                    {
                        arrowRight.scale.set(0.8, 0.8);

                        if (FlxG.keys.justPressed.RIGHT #if mobileC || virtualPad.buttonRight.justPressed #end)
                            changeCategorySelection(1);
                    }
                    else
                    {
                        arrowRight.scale.set(1, 1);
                    }
                case SONG:
                    if (FlxG.keys.justPressed.UP #if mobileC || virtualPad.buttonUp.justPressed #end)
                    {
                        if (currentSongSelected == 0)
                        {
                            toggleCategorySelect(true);
                        }
                        else
                        {
                            changeSongSelection(-1);
                        }
                    }
                    if (FlxG.keys.justPressed.DOWN #if mobileC || virtualPad.buttonDown.justPressed #end)
                    {
                        if (currentSongSelected == categorySongsCount)
                        {
                            toggleCategorySelect(true);
                        }
                        else
                        {
                            changeSongSelection(1);
                        }
                    }

                    if (hasMultipleVariations)
                    {
						if (FlxG.keys.pressed.LEFT #if mobileC || virtualPad.buttonLeft.pressed #end)
						{
                            arrowLeftVariation.color = FlxColor.LIME;
							arrowLeftVariation.scale.set(0.8, 0.8);

							if (FlxG.keys.justPressed.LEFT #if mobileC || virtualPad.buttonLeft.justPressed #end)
								changeVariationSelection(-1);
						}
						else
						{
                            arrowLeftVariation.color = FlxColor.WHITE;
							arrowLeftVariation.scale.set(1, 1);
						}

						if (FlxG.keys.pressed.RIGHT #if mobileC || virtualPad.buttonRight.pressed #end)
						{
                            arrowRightVariation.color = FlxColor.LIME;
							arrowRightVariation.scale.set(0.8, 0.8);

							if (FlxG.keys.justPressed.RIGHT #if mobileC || virtualPad.buttonRight.justPressed #end)
								changeVariationSelection(1);
						}
						else
						{
                            arrowRightVariation.color = FlxColor.WHITE;
							arrowRightVariation.scale.set(1, 1);
						}
                    }

                    if (FlxG.keys.justPressed.ENTER #if mobileC || virtualPad.buttonA.justPressed #end && selectedSongOption.getVariation(selectedVariation) != turnTable.currentPlayData)
                    {
                        loadSong(selectedSongOption.getVariation(selectedVariation));
                    }
            }
        }

        if (FlxG.mouse.overlaps(playrobotButton))
        {
            playrobotButton.color = FlxColor.GRAY;
            if (FlxG.mouse.justPressed && !isTransitioning)
            {
                toggleSelectionBar(!isSelectionBarVisible);
            }
        }
        else
        {
            playrobotButton.color = FlxColor.WHITE;
        }
    }

    /**
     * Generates the selection bar from the left that's used to select a song from a dropdown.
     */
    function buildSelectionBar():Void
    {
        selectionBarGroup = new FlxSpriteGroup();
        add(selectionBarGroup);

        categoryBlackBorder = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
        categoryBlackBorder.scale.set(325, FlxG.height);
        categoryBlackBorder.updateHitbox();
        categoryBlackBorder.alpha = 0.6;
        selectionBarGroup.add(categoryBlackBorder);

        selectionBarGroup.add(grpSongSelection);
        grpSongSelection.add(grpSongsList);

        categoryIcon = new FlxSprite(0, 10).loadGraphic(Category.getCategory(categoryList[0]).getIcon());
        categoryIcon.scale.set(0.35, 0.35);
        categoryIcon.updateHitbox();
        categoryIcon.x = (categoryBlackBorder.width - categoryIcon.width) / 2;
        selectionBarGroup.add(categoryIcon);

        arrowLeft = new FlxSprite();
        arrowLeft.frames = Paths.getSparrowAtlas('ost/arrow_left');
        arrowLeft.animation.addByPrefix('idle', 'arrowleft_unselect', 24, false);
        arrowLeft.animation.addByPrefix('select', 'arrowleft_click', 24, false);
        arrowLeft.animation.play('idle', true);
        arrowLeft.x = categoryIcon.x - arrowLeft.width - 10;
        arrowLeft.y = categoryIcon.y + (categoryIcon.height - arrowLeft.height) / 2;
        selectionBarGroup.add(arrowLeft);

        arrowRight = new FlxSprite();
        arrowRight.frames = Paths.getSparrowAtlas('ost/arrow_right');
        arrowRight.animation.addByPrefix('idle', 'arrowright_unselect', 24, false);
        arrowRight.animation.addByPrefix('select', 'arrowright_click', 24, false);
        arrowRight.animation.play('idle', true);
        arrowRight.x = (categoryIcon.x + categoryIcon.width) + 10;
        arrowRight.y = categoryIcon.y + (categoryIcon.height - arrowRight.height) / 2;
        selectionBarGroup.add(arrowRight);

        arrowLeftVariation = new FlxText(100, 200, 0, '<');
        arrowLeftVariation.setFormat(Paths.font('comic_normal.ttf'), 30, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        arrowLeftVariation.borderSize = 2;
        arrowLeftVariation.visible = false;
        grpSongSelection.add(arrowLeftVariation);

        arrowRightVariation = new FlxText(100, 200, 0, '>');
        arrowRightVariation.setFormat(Paths.font('comic_normal.ttf'), 30, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        arrowRightVariation.borderSize = 2;
        arrowRightVariation.visible = false;
        grpSongSelection.add(arrowRightVariation);
    }

    /**
     * Generate any additional needed UI such as playrobot, and any text that displays under, or up top.
     */
    function buildAdditionalUI():Void
    {
        playrobotButton = new FlxSprite();
        playrobotButton.frames = Paths.getSparrowAtlas('ost/playrobot_ost');
        playrobotButton.animation.addByPrefix('idle_select', 'playbot_selected', 24);
        playrobotButton.animation.addByPrefix('idle_unselect', 'playbot_unselected', 24);
        playrobotButton.animation.addByPrefix('transition_select', 'playbot_transitions', 24, false);
        playrobotButton.animation.addByPrefix('transition_unselect', 'playbot_transitionu', 24, false);
        playrobotButton.scale.set(0.9, 0.9);
        playrobotButton.updateHitbox();
        playrobotButton.x = FlxG.width - playrobotButton.width - 5;
        playrobotButton.y = FlxG.height - playrobotButton.height - 5;
        playrobotButton.animation.onFinish.add((anim:String) -> 
        {
            switch (anim)
            {
                case 'transition_select':
                    playPlayrobotAnimation('idle_select');
                    playrobotButton.animation.play('idle_select', true);
                case 'transition_unselect':
                    playPlayrobotAnimation('idle_unselect');
            }
        });
        playPlayrobotAnimation('idle_unselect');
        add(playrobotButton);

        manual = new OSTManual();
        manual.visible = false;
        manual.onManualOpen.add(() -> {
            turnTable.forEachButton((button:OSTButton) -> 
            {
                button.canInteract = false;
                canInteract = false;
            });
        });
        manual.onManualClose.add(() -> {
            manual.visible = false;
            
            turnTable.forEachButton((button:OSTButton) -> 
            {
                button.canInteract = true;
                canInteract = true;
            });
        });
        add(manual);

        if (FlxG.save.data.ostFirstTime == null || !FlxG.save.data.ostFirstTime)
        {
            this.openManual();

            FlxG.save.data.ostFirstTime = true;
            FlxG.save.flush();
        }
    }

    /**
     * Generates a list of songs that are able to be selected from based on the given category.
     * @param category The category to generate a list from.
     */
    function buildSongList(category:Category):Void
    {
        grpSongsList.clear();

        var categorySongs:Array<CategorySong> = category.getSongs();
        
        var index:Int = 0;
        for (catSong in categorySongs)
        {
            if (FlxG.save.data.locked.exists(catSong.id) && FlxG.save.data.locked.get(catSong.id) == 'locked')
                continue;

            var songPlayData:Map<String, OSTPlayData> = OSTPlayData.buildFromCategorySong(catSong);

            var option:OSTSongOption = new OSTSongOption(25, (200 + 75 * index), songPlayData, index + 1, categoryBlackBorder.width);
            grpSongsList.add(option);
            index++;
        }
    }

    function loadSong(playData:OSTPlayData)
    {
        turnTable.forcePauseSong();
        turnTable.loadSong(playData);

        var gradientBG:BitmapData = GradientUtil.applyGradientToBitmapData(menuBgGraphic, playData.colors);
        bg.loadGraphic(gradientBG);

        bg.color = FlxColor.GRAY;
    }

    /**
     * Toggles the selection bar to play an animation of it either appearing, or disappearing disabling it.
     * Useful for if you want
     * @param appear Whether the selection bar should be visible, or not.
     */
    function toggleSelectionBar(appear:Bool):Void
    {
        isTransitioning = true;
        isSelectionBarVisible = appear;

        SoundController.play(Paths.sound('ost/tick'), 0.8);

        if (isSelectionBarVisible)
        {
            playPlayrobotAnimation('transition_unselect');

            FlxTween.tween(selectionBarGroup, {x: 0.0}, 0.5, {ease: FlxEase.quadIn});
            FlxTween.tween(turnTable, {x: turnTable.x + 150}, 0.5, {
                ease: FlxEase.quadIn,
                onComplete: (t:FlxTween) -> {
                    isTransitioning = false;
                }
            });
        }
        else
        {
            playPlayrobotAnimation('transition_select');

            FlxTween.tween(selectionBarGroup, {x: -selectionBarGroup.width}, 0.5, {ease: FlxEase.quadIn});
            FlxTween.tween(turnTable, {x: turnTable.x - 150}, 0.5, {
                ease: FlxEase.quadIn,
                onComplete: (t:FlxTween) -> {
                    isTransitioning = false;
                }
            });
        }
        manual.onSelectionBarToggle(appear);
    }

    /**
     * Change the currently selected category based on the given amount.
     * @param change How much to change from the current select category.
     */
    function changeCategorySelection(change:Int = 0)
    {
        if (change != 0)
        {
            SoundController.play(Paths.sound('scrollMenu'), 0.7);
        }
        currentCategorySelected += change;

        if (currentCategorySelected > categoryList.length - 1)
            currentCategorySelected = 0;
        if (currentCategorySelected < 0)
            currentCategorySelected = categoryList.length - 1;

        currentCategory = Category.getCategory(categoryList[currentCategorySelected]);

        updateCategory();
    }
    
    /**
     * Updates the category based on the user's current selected one.
     */
    function updateCategory():Void
    {
        categoryIcon.loadGraphic(currentCategory.getIcon());

        buildSongList(currentCategory);
    }

    /**
     * Changes the currently selected song index based on the given amount.
     * @param amount The amount to change from the current selected index.
     */
    function changeSongSelection(amount:Int = 0)
    {
        if (amount != 0)
        {
            SoundController.play(Paths.sound('scrollMenu'), 0.7);
        }

        if (selectedSongOption != null)
            selectedSongOption.unselectOption();

        currentSongSelected += amount;

        if (currentSongSelected > categorySongsCount)
            currentSongSelected = 0;

        if (currentSongSelected < 0)
            currentSongSelected = categorySongsCount;

        updateSelectedSong();
        fadeOutSongs(currentSongSelected);
    }

    /**
     * Changes the variation from the given amount.
     * @param amount 
     */
    function changeVariationSelection(amount:Int = 0)
    {
        if (amount != 0)
        {
            SoundController.play(Paths.sound('scrollMenu'), 0.7);
        }

        selectedVariationIndex += amount;

        if (selectedVariationIndex > currentSongVariationsList.length - 1)
            selectedVariationIndex = 0;

        if (selectedVariationIndex < 0)
            selectedVariationIndex = currentSongVariationsList.length - 1;

        selectedSongOption.switchVariation(selectedVariation);
        
        arrowLeftVariation.x = selectedSongOption.x - 20;
        arrowLeftVariation.y = selectedSongOption.y + (selectedSongOption.height - arrowLeftVariation.textField.textHeight - 22) / 2; 
        
        arrowRightVariation.x = selectedSongOption.x + selectedSongOption.width + 5;
        arrowRightVariation.y = selectedSongOption.y + (selectedSongOption.height - arrowRightVariation.textField.textHeight - 22) / 2;
    }

    /**
     * Updates the song selection bar in accordance to the currently selected song.
     */
    function updateSelectedSong():Void
    {
        selectedSongOption = grpSongsList.members[currentSongSelected];
        selectedSongOption.selectOption();

        currentSongVariationsList = selectedSongOption.playData.keys().array();
        currentSongVariationsList.sort(SortUtil.defaultThenAlphabetically.bind(Song.DEFAULT_VARIATION));

        arrowLeftVariation.visible = hasMultipleVariations;
        arrowRightVariation.visible = hasMultipleVariations;
        
        // Update the selected variation index to make sure it matches with this song's current variation.
        selectedVariationIndex = currentSongVariationsList.indexOf(selectedSongOption.currentVariation);

        changeVariationSelection();

        setupSelectTween(currentSongSelected);
    }

    /**
     * Resets every song's state to be unselected.
     * Called when the user switches to being on a category.
     */
    function unselectOptions():Void
    {
        for (song in grpSongsList.members)
        {
            song.unselectOption();
        }
    }

    /**
     * Slowly fades out any songs under the given index.
     * @param index The index to start fading out songs to.
     */
    function fadeOutSongs(index:Int):Void
    {
        var targetIndex:Int = 0;
        for (song in grpSongsList.members)
        {
            var targetAlpha:Int = targetIndex - index;
            
            if (targetAlpha < 0)
            {
                var fadingAlpha:Float = FlxMath.remapToRange(targetAlpha, 0, -3, 1, 0);
                fadingAlpha -= 0.3;
                
                song.setAlphaDirectly(fadingAlpha);
            }
            targetIndex++;
        }
    }

    /**
     * Creates, and starts the tween used to move the song selection bar.
     * @param index The selection index.
     */
    function setupSelectTween(index:Int):Void
    {
        selectSongTween?.cancel();
        selectSongTween?.destroy();
        selectSongTween = null;
                
        selectSongTween = FlxTween.tween(grpSongSelection, {y: -75 * index}, 0.5, {
            ease: FlxEase.expoOut,
            onComplete: (t:FlxTween) -> {
                selectSongTween.destroy();
                selectSongTween = null;
            }
        });
    }
    

    /**
     * Toggles whether you're able to select a category, or not.
     * @param appear The state to change to.
     */
    function toggleCategorySelect(appear:Bool, playSound:Bool = true)
    {
        SoundController.play(Paths.sound('scrollMenu'), 0.7);
        if (appear)
        {
            currentSelectType = CATEGORY;
            categoryIcon.scale.set(0.35, 0.35);
        }
        else
        {
            currentSelectType = SONG;
            categoryIcon.scale.set(0.3, 0.3);
        }
        unselectOptions();
        setupSelectTween(0);
    }

    public function openManual():Void
    {
        manual.visible = true;
        manual.startManual();
    }

    /**
     * Plays an animation from playrobot while also accounting for animation offsets.
     * @param anim The animation to play.
     */
    function playPlayrobotAnimation(anim:String):Void
    {
        playrobotButton.updateHitbox();
        playrobotButton.animation.play(anim, true);
        switch (anim)
        {
            case 'transition_unselect':
                playrobotButton.offset.y -= 4;
            case 'idle_unselect':
                playrobotButton.offset.y -= 10;
            case 'transition_select':
                playrobotButton.offset.y += 2.5;
        }
    }
}

class OSTSongOption extends FlxSpriteGroup
{
    public var playData(default, null):Map<String, OSTPlayData>;

    public var currentVariation:String;

    public var icon:HealthIcon;

    public var songNameText:FlxText;
    public var songComposerText:FlxText;

    var index:Int;
    var maxWidth:Float;

    public function new(x:Float, y:Float, playData:Map<String, OSTPlayData>, index:Int, maxWidth:Float)
    {
        super(x, y);

        this.index = index;
        this.maxWidth = maxWidth;
        this.playData = playData;

        songNameText = new FlxText(0, 0, 0, '');
        songNameText.setFormat(Paths.font('comic_normal.ttf'), 24, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        songNameText.borderSize = 2;
        add(songNameText);

		icon = new HealthIcon('none');
		icon.setGraphicSize(60);
		icon.updateHitbox();
		icon.autoOffset = false;
		add(icon);

        songComposerText = new FlxText(0, 0, 0, '');
        songComposerText.setFormat(Paths.font('comic_normal.ttf'), 12, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        songComposerText.borderSize = 1.5;
        add(songComposerText);

        switchVariation(Song.DEFAULT_VARIATION);
        unselectOption();
    }

    public function switchVariation(variationId:String)
    {
        currentVariation = variationId;
        
        var playData = getVariation(variationId);

        songNameText.text = '$index. ' + playData.name;
        songNameText.size = 24;

        songComposerText.text = playData.composers.formatStringList();
        songComposerText.y = songNameText.y + songNameText.textField.textHeight;
        songComposerText.size = 12;

        if (playData.icon != null)
        {
            // Change the icon.
            if (icon != null)
                icon.char = playData.icon;
            else
                icon = new HealthIcon(playData.icon);

            icon.autoOffset = false;
            icon.setGraphicSize(60);
            icon.updateHitbox();
            add(icon);
        }
        else
        {
            // Remove the icon since the play data doesn't have a icon to display.
            if (icon != null)
            {
                this.remove(icon);

                icon.destroy();
                icon = null;
            }
        }

        // Trim each text so it cuts off before the end of the width.
        scaleTextToWidth(songNameText, maxWidth - (icon != null ? (icon.width + 5) : 0) - songComposerText.x);
        scaleTextToWidth(songComposerText, maxWidth);

        // Reposition the icon to be at the end of the name text.
        if (icon != null)
        {
            icon.x = (songNameText.x) + songNameText.width;
            icon.y = (songNameText.y) + (this.icon.height - songNameText.textField.textHeight) / 2 - 22;
        }
    }

    public function getVariation(variationId:String):OSTPlayData
    {
        return playData.get(variationId) ?? playData.get(Song.DEFAULT_VARIATION);
    }

    public function selectOption():Void
    {
        songNameText.color = FlxColor.LIME;
        songComposerText.color = FlxColor.LIME;
        
        setAlphaDirectly(1.0);
    }

    public function unselectOption():Void
    {
        songNameText.color = FlxColor.WHITE;
        songComposerText.color = FlxColor.WHITE;

        setAlphaDirectly(0.4);
    }

    public function setAlphaDirectly(alpha:Float):Void
    {
        songNameText.alpha = alpha;
        songComposerText.alpha = alpha;
        
        if (icon != null)
            icon.alpha = alpha;
    }

    public function scaleTextToWidth(text:FlxText, width:Float):Void
    {
        // The - 25 is to account for if this option has additional variations.
        if (playData.size() > 1)
            width -= 25;

        text.scale.set(1, 1);
        text.width = text.textField.textWidth;
        text.updateHitbox();

		if (text.textField.textWidth > width)
		{
			var textScale = width / text.width;

			text.scale.x *= textScale;
			text.width *= textScale;
			text.offset.x = ((text.frameWidth - text.width) / 2);
		}
    }
}