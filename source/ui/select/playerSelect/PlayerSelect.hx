package ui.select.playerSelect;

import backend.Conductor;
import data.player.PlayerData;
import data.song.SongRegistry;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText.FlxTextBorderStyle;
import flixel.text.FlxText.FlxTextAlign;
import flixel.util.FlxColor;
import flixel.text.FlxText;
import flixel.math.FlxPoint;
import flixel.effects.FlxFlicker;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;
import play.PlayStatePlaylist;
import play.LoadingState;
import play.PlayState;
import play.character.Character;
import play.save.Preferences;
import play.song.Song;
import ui.menu.freeplay.FreeplayState;

enum abstract SelectedPlayerType(Int) from Int to Int
{
    var OPPONENT = 0;
    var PLAYER = 1;
}

/**
 * A selection menu used to be able to select between playing as the opponent, or player of a song.
 * 
 * This class represents the base functionaility of the menu. 
 * Each variation should derived, and have the specified functions overwritten. 
 */
abstract class PlayerSelect extends MusicBeatState
{
    public static var selectedPlayer:Null<SelectedPlayerType> = null;

    // CONSTANTS //
    
    /**
     * The constant base position used used for the portraits.
     */
    final BASE_PORTRAIT_POSITION_X:Float = 800;
    
    /**
     * The constant y position of every portrait.
     */
    final BASE_PORTRAIT_POSITION_Y:Float = 350;
    
    /**
     * The constant x position to offset each portrait that's added.
     */
    final BASE_PORTRAIT_OFFSET_X:Float = 250;
    

    // PROPERTIES //
     
    /**
     * The song that was selected for this player select.
     */
    final song:Song;

    /**
     * A list of all of the selectable portraits in this menu.
     */
    var players:Array<PlayerData>;

    var canInteract:Bool = true;

    /**
     * A list of all of the character instances in this selection.
     * `String` => The character id.
     * `Character` => The character instance.
     */
    var characterMap:Map<String, Character> = [];

    /**
     * The currently selected portrait, in index terms.
     */
    var currentSelectedPortrait:Int = 0;

    /**
     * The currently selected portrait based on selected index.
     */
    var selectedPlayerData(get, never):PlayerData;

    function get_selectedPlayerData():PlayerData
    {
        return players[currentSelectedPortrait];
    }

    var lastSelectedPortrait:CharacterPortrait;

    /**
     * The currently selected portrait based on selected index.
     */
    var selectedPortrait(get, never):CharacterPortrait;

    function get_selectedPortrait():CharacterPortrait
    {
        return portraitGroup.members[currentSelectedPortrait];
    }

    // RENDER OBJECTS //

	/**
	 * The current character the user has selected.
	 */
	var char:Character;

    /**
     * The selection logo that's shown at the right side of the menu.
     */
    var selectLogo:FlxSprite;

    /**
     * The group that holds all of the current rendering portraits.
     */
    var portraitGroup:FlxTypedSpriteGroup<CharacterPortrait> = new FlxTypedSpriteGroup<CharacterPortrait>();
    
	/**
	 * The text that displays the current player selected.
	 */
	var playerText:FlxText;


    /**
     * Initalizes a new player select menu.
     * @param songId The id of the song for this player.
     */
    public function new(songId:String)
    {
        super();

        this.song = SongRegistry.instance.fetchEntry(songId);
    }

    public override function create():Void
    {
        super.create();
        
        // Stop any existing music.
        SoundController?.music?.stop();
        
        // Cache the portrait data into a variable for easy use.
        players = getAllPortraits();

        // Cache all of the characters to be used in the menu.
        buildCharacters();

        buildBackground();
        buildSelectLogo();
        buildPortraits();
        buildCharacterText();
        
        buildMusic();

        updateSelection();

        #if mobileC
        addVirtualPad(LEFT_RIGHT, A_B);
        addVirtualPadCamera();
        #end
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (SoundController.music != null)
        {
            Conductor.instance.update(SoundController.music.time);
        }

        if (canInteract)
        {
            if (controls.BACK)
            {
                SoundController.playMusic(Paths.music('freakyMenu'));
                FlxG.switchState(() -> new FreeplayState());
            }
            if (controls.LEFT_P)
                changeSelection(-1);

            if (controls.RIGHT_P)
                changeSelection(1);

            if (controls.ACCEPT)
                selectPlayer();
        }
    }

    /**
     * Creates all of the characters for this select.
     */
    function buildCharacters():Void
    {
        for (player in players)
        {
            var charFile:Character = Character.create(player.charId, PLAYER);
            characterMap.set(player.charId, charFile);
        }
    }

    /**
     * Generates all of the portraits used for the selection.
     */
    function buildPortraits():Void
    {
        for (i in 0...players.length)
        {
            var playerData:PlayerData = players[i];

            var portrait:CharacterPortrait = new CharacterPortrait(0, BASE_PORTRAIT_POSITION_Y, playerData.charSelect);
            portrait.x = BASE_PORTRAIT_POSITION_X + (i * BASE_PORTRAIT_OFFSET_X);
            portrait.showGfIcon = false;
            portraitGroup.add(portrait);
        }
        add(portraitGroup);
    }

    function buildCharacterText():Void
    {
		playerText = new FlxText(0, Preferences.downscroll ? 50 : 600, 0, selectedPlayerData.name);
		playerText.setFormat(Paths.font('comic.ttf'), 55, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		playerText.borderSize = 3;
		add(playerText);
    }

    /**
     * Changes the portrait selection from a given index amount.
     * @param amount How much to change the selection by.
     */
    function changeSelection(amount:Int = 0)
    {
        if (amount != 0)
        {
            lastSelectedPortrait = selectedPortrait;

            SoundController.play(Paths.sound('scrollMenu'));   
        }
        currentSelectedPortrait += amount;
        
        if (currentSelectedPortrait > players.length - 1)
            currentSelectedPortrait = 0;

        if (currentSelectedPortrait < 0)
            currentSelectedPortrait = players.length - 1;
        
        updateSelection();
    }

    /**
     * Updates any visuals based on the current selected index.
     */
    function updateSelection():Void
    {
        lastSelectedPortrait?.deselect();
        selectedPortrait.select();
        
        updateCharacter();
    }

    function updateCharacter():Void
    {
        var position:FlxPoint = getCharacterPosition();
        var offsetPosition:FlxPoint = getSelectedCharacterOffset(currentSelectedPortrait) ?? FlxPoint.get(0, 0);

        position.x += offsetPosition.x;
        position.y += offsetPosition.y;

        if (char != null)
        {
            remove(char);
        }
        char = characterMap.get(selectedPlayerData.charId);
        char.setPosition(position.x, position.y);

        char.x += char.globalOffset[0];
        char.y += char.globalOffset[1];

        char.flipX = false;
        char.dance(true);
        add(char);
        
		playerText.text = selectedPlayerData.name;
		playerText.x = 250 - (playerText.textField.textWidth / 2);
		playerText.color = char.characterColor;
    }

    /**
     * Handles functionaility for when the user has selected a player.
     */
    function selectPlayer():Void
    {
        canInteract = false;

        char.playAnim('hey', true);
		char.canDance = false;
        
        for (i in 0...portraitGroup.members.length)
		{
			var curPortrait:CharacterPortrait = portraitGroup.members[i];

			if (curPortrait != selectedPortrait)
			{
				FlxTween.tween(curPortrait, {alpha: 0.4}, 0.5, {ease: FlxEase.circOut});
			}
			else
			{
				FlxFlicker.flicker(curPortrait, 2, 0.1);
			}
		}

        SoundController.music.fadeOut();
		SoundController.play(Paths.sound('confirmMenu'));

		new FlxTimer().start(1, function(timer:FlxTimer)
		{
            PlayStatePlaylist.isStoryMode = false;
			LoadingState.loadAndSwitchState(() -> new PlayState({targetSong: song, targetVariation: '', playerType: players.indexOf(selectedPlayerData)}));
		});
    }

    // TO OVERWRITE/ /

    /**
     * Builds the graphic logo that's shown at the right side of the screen that prompts the user.
     * This can be used in-case you want the logo to be animated, or have other effects.
     */
    abstract function buildSelectLogo():Void;

    /**
     * Builds the background used for the selection.
     * Is able to be overwritten to allow for custom made backgrounds.
     */
    abstract function buildBackground():Void;

    /**
     * Gets a list of all of the portaits used for this select.
     * @return An `Array<CharacterPortraitData`
     */
    abstract function getAllPortraits():Array<PlayerData>;
    
    /**
     * Builds the music used for the player select.
     * Helpful in-case the select has custom music to be used.
     */
    abstract function buildMusic():Void;

    /**
     * Returns the base position that the selected character should be positioned
     * @return An `FlxPoint` to use.
     */
    abstract function getCharacterPosition():FlxPoint;
    
    /**
     * Returns the point that's used to offset the selected character's position.
     * @return An `FlxPoint`
     */
    abstract function getSelectedCharacterOffset(playerType:SelectedPlayerType):FlxPoint;
}