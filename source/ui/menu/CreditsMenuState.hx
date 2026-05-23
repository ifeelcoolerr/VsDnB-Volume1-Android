package ui.menu;

import data.language.LanguageManager;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.math.FlxMath;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.text.FlxText.FlxTextAlign;
import flixel.system.FlxAssets.FlxGraphicAsset;
import flixel.util.FlxColor;
import flixel.util.FlxGradient;
import play.camera.FollowCamera;
import ui.MusicBeatState;
import ui.menu.MainMenuState;

typedef CreditsPersonParams = 
{
    var name:String;
    var description:String;
    var icon:String;
    var ?scale:Float;
    var ?antialiasing:Bool;
}

class CreditsMenuState extends MusicBeatState
{
    final DEFAULT_LANGUAGE_LIST = LanguageManager.currentCreditsList;

    final MIN_Y:Float = FlxG.height / 2;
    final MAX_Y:Float = 3000;
    final MOVE_SPEED:Float = 500;
    
    var followCamera:FollowCamera;

    var modTitleText:FlxText;
    var versionText:FlxText;
    var devTeamText:FlxText;
    
    var developersGroup:FlxSpriteGroup = new FlxSpriteGroup();
    var contributorsGroup:FlxSpriteGroup = new FlxSpriteGroup();
    var translatorsGroup:FlxSpriteGroup = new FlxSpriteGroup();
    var menuBackgroundGroup:FlxSpriteGroup = new FlxSpriteGroup();
    var specialThanksGroup:FlxSpriteGroup = new FlxSpriteGroup();
    var playtestersGroup:FlxSpriteGroup = new FlxSpriteGroup();

    // DEVELOPERS //

    var moldy:CreditsPerson;
    var rapparep:CreditsPerson;
    var t5mpler:CreditsPerson;

    var mtm101:CreditsPerson;
    var erizur:CreditsPerson;
    var tb:CreditsPerson;
    var longdonny:CreditsPerson;
    var fissh:CreditsPerson;

    // CONTRIBUTORS //

    var evdial:CreditsPerson;
    var steph:CreditsPerson;
    var billy:CreditsPerson;
    var sk0rbias:CreditsPerson;
    var magical:CreditsPerson;
    var alexanderCooper19:CreditsPerson;
    var cup:CreditsPerson;
    var sibottle:CreditsPerson;
    var mistiiful:CreditsPerson;
    var top10:CreditsPerson;
    var inguf:CreditsPerson;
    var ztgds:CreditsPerson;
    var yourMom:CreditsPerson;
    var zmac:CreditsPerson;
    var erin:CreditsPerson;
    var ray:CreditsPerson;

    // TRANSLATORS
    var windspel:CreditsPerson;
    var aizakku:CreditsPerson;
    var soulegal:CreditsPerson;
    
    // SPECIAL THANKS //
    var villezen:CreditsPerson;
    var statictigers:CreditsPerson;
    var sky:CreditsPerson;
    var shifty:CreditsPerson;

    override function create():Void
    {
        buildBackground();
        buildUI();

        followCamera = new FollowCamera();
        followCamera.followLerpDuration = 0.01;
        followCamera.followPoint.set(FlxG.width / 2, MIN_Y);
        followCamera.snapToTarget();
		followCamera.bgColor.alpha = 0;

		FlxG.cameras.reset(followCamera);
		FlxG.cameras.setDefaultDrawTarget(followCamera, true);

        #if mobileC
        addVirtualPad(UP_DOWN, B);
        #end   
        
        super.create();
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.keys.pressed.UP #if mobileC || virtualPad.buttonUp.pressed #end)
        {
            followCamera.followPoint.y = FlxMath.bound(followCamera.followPoint.y - MOVE_SPEED * elapsed, MIN_Y, MAX_Y);
        }
        if (FlxG.keys.pressed.DOWN #if mobileC || virtualPad.buttonDown.pressed #end)
        {
            followCamera.followPoint.y = FlxMath.bound(followCamera.followPoint.y + MOVE_SPEED * elapsed, MIN_Y, MAX_Y);
        }

        if (controls.BACK #if mobileC || FlxG.android.justReleased.BACK #end)
        {
            FlxG.switchState(() -> new MainMenuState());
        }
    }

    function buildBackground():Void
    {   
		var blackBg = FlxGradient.createGradientFlxSprite(FlxG.width, FlxG.height, [
			FlxColor.interpolate(FlxColor.fromRGB(0, 0, 0), 0xFF4965FF, 0.4),
			FlxColor.interpolate(FlxColor.fromRGB(0, 0, 0), 0xFF00B515, 0.4)
		], 1, 180);
        blackBg.scrollFactor.set();
		add(blackBg);
    }

    function buildUI():Void
    {
        modTitleText = new FlxText(0, 0, 0, 'Vs. Dave & Bambi');
        modTitleText.setFormat(Paths.font("comic_normal.ttf"), 40, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        modTitleText.screenCenter(X);
        modTitleText.borderSize = 2;
        add(modTitleText);
        
        versionText = new FlxText(0, 0, 0, getLanguageText('credits_version'));
        versionText.setFormat(Paths.font("comic_normal.ttf"), 16, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        versionText.x = modTitleText.x + modTitleText.textField.textWidth + 10;
        versionText.y = modTitleText.y + (modTitleText.textField.textHeight - versionText.textField.textHeight) / 2;
        versionText.borderSize = 2;
        add(versionText);
        
        devTeamText = new FlxText(0, 0, 0, getLanguageText('credits_createdBy') + ' ' + 'Sad Guy Big Head Team');
        devTeamText.setFormat(Paths.font("comic.ttf"), 16, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        devTeamText.screenCenter(X);
        devTeamText.y = modTitleText.y + modTitleText.textField.textHeight;
        devTeamText.borderSize = 2;
        add(devTeamText);
        
        buildDevelopers();
        buildContributors();
        buildSpecialThanks();
        buildMenuBackgroundGroup();
        buildPlaytesters();
    }

    function buildDevelopers():Void
    {
        developersGroup = new FlxSpriteGroup();
        developersGroup.y = 25;
        add(developersGroup);

        var developersText = new FlxText(0, 0, 0, getLanguageText('credits_developers_title'));
        developersText.setFormat(Paths.font("comic.ttf"), 40, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        developersText.screenCenter(X);
        developersText.y = devTeamText.y + devTeamText.textField.textHeight + 5;
        developersText.borderSize = 3;
        developersGroup.add(developersText);

        moldy = new CreditsPerson(500, 175, {
            name: 'MoldyGangstaHero',
            description: getLanguageText('credits_moldy'),
            icon: 'developers/MoldyGH'
        });
        developersGroup.add(moldy);
        
        rapparep = new CreditsPerson(175, 150, {
            name: 'Rapparep',
            description: getLanguageText('credits_rapparep'),
            icon: 'developers/rapparep lol'
        });
        developersGroup.add(rapparep);
        
        t5mpler = new CreditsPerson(900, 175, {
            name: 'T5mpler',
            description: getLanguageText('credits_t5mpler'),
            icon: 'developers/T5mpler'
        });
        developersGroup.add(t5mpler);
        
        mtm101 = new CreditsPerson(100, 350, {
            name: 'MissingTextureMan101',
            description: getLanguageText('credits_mtm101'),
            icon: 'developers/MissingTextureMan101'
        });
        developersGroup.add(mtm101);
        
        erizur = new CreditsPerson(550, 350, {
            name: 'Erizur',
            description: getLanguageText('credits_erizur'),
            icon: 'developers/Erizur'
        });
        developersGroup.add(erizur);
        
        tb = new CreditsPerson(875, 375, {
            name: 'TheBuilderXD',
            description: getLanguageText('credits_tb'),
            icon: 'developers/TheBuilderXD',
            antialiasing: false
        });
        developersGroup.add(tb);
        
        longdonny = new CreditsPerson(325, 530, {
            name: 'LongDonny',
            description: getLanguageText('credits_longDonny'),
            icon: 'developers/jo'
        });
        developersGroup.add(longdonny);
        
        fissh = new CreditsPerson(775, 520, {
            name: 'fissh',
            description: getLanguageText('credits_fissh'),
            icon: 'developers/fissh'
        });
        developersGroup.add(fissh);
    }

    function buildContributors():Void
    {
        contributorsGroup = new FlxSpriteGroup();
        contributorsGroup.y = developersGroup.y + 600;
        add(contributorsGroup);

        var contributorsText = new FlxText(0, 0, 0, getLanguageText('credits_contributors_title'));
        contributorsText.setFormat(Paths.font("comic.ttf"), 40, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        contributorsText.screenCenter(X);
        contributorsText.y = devTeamText.y + devTeamText.textField.textHeight + 5;
        contributorsText.borderSize = 3;
        contributorsGroup.add(contributorsText);
        
        evdial = new CreditsPerson(125, 150, {
            name: 'evdial',
            description: getLanguageText('credits_evdial'),
            icon: 'contributors/evdial'
        });
        contributorsGroup.add(evdial);
        
        billy = new CreditsPerson(400, 150, {
            name: 'Billy Bobbo',
            description: getLanguageText('credits_billy'),
            icon: 'developers/Billy Bobbo',
        });
        contributorsGroup.add(billy);
        
        steph = new CreditsPerson(700, 150, {
            name: 'Steph45',
            description: getLanguageText('credits_steph'),
            icon: 'contributors/Steph45'
        });
        contributorsGroup.add(steph);

        sk0rbias = new CreditsPerson(925, 145, {
            name: 'sk0rbias',
            description: getLanguageText('credits_sk0rbias'),
            icon: 'contributors/sk0rbias'
        });
        contributorsGroup.add(sk0rbias);
        
        alexanderCooper19 = new CreditsPerson(60, 290, {
            name: 'Alexander Cooper 19',
            description: getLanguageText('credits_alexander'),
            icon: 'contributors/Alexander Cooper 19'
        });
        contributorsGroup.add(alexanderCooper19);
        
        magical = new CreditsPerson(700, 300, {
            name: 'Magical',
            description: getLanguageText('credits_magical'),
            icon: 'contributors/magical'
        });
        contributorsGroup.add(magical);
        
        mistiiful = new CreditsPerson(975, 300, {
            name: 'mistiiful',
            description: getLanguageText('credits_mistiiful'),
            icon: 'contributors/mistiiful'
        });
        contributorsGroup.add(mistiiful);
        
        cup = new CreditsPerson(425, 300, {
            name: 'Cup',
            description: getLanguageText('credits_cup'),
            icon: 'contributors/Cup'
        });
        contributorsGroup.add(cup);
        
        sibottle = new CreditsPerson(125, 425, {
            name: 'SiBottle',
            description: getLanguageText('credits_sibottle'),
            icon: 'contributors/sibottle'
        });
        contributorsGroup.add(sibottle);
        
        top10 = new CreditsPerson(400, 425, {
            name: 'Top 10 Awesome',
            description: getLanguageText('credits_top10'),
            icon: 'contributors/Top 10 Awesome',
            scale: 0.8,
        });
        contributorsGroup.add(top10);
        
        inguf = new CreditsPerson(700, 410, {
            name: 'Inguf341',
            description: getLanguageText('credits_inguf'),
            icon: 'contributors/inguf341'
        });
        contributorsGroup.add(inguf);
        
        ztgds = new CreditsPerson(1000, 425, {
            name: 'ztgds',
            description: getLanguageText('credits_ztgds'),
            icon: 'contributors/ztgds'
        });
        contributorsGroup.add(ztgds);
        
        yourMom = new CreditsPerson(825, 570, {
            name: 'Your Mom',
            description: getLanguageText('credits_yourMom'),
            icon: 'contributors/Your mom'
        });
        contributorsGroup.add(yourMom);
        
        zmac = new CreditsPerson(300, 575, {
            name: 'Zmac',
            description: getLanguageText('credits_zmac'),
            icon: 'developers/Zmac',
            antialiasing: false
        });
        contributorsGroup.add(zmac);
        
        erin = new CreditsPerson(525, 555, {
            name: 'pointyyESM',
            description: getLanguageText('credits_pointy'),
            icon: 'developers/pointy'
        });
        contributorsGroup.add(erin);

        buildTranslators();
    }

    function buildTranslators():Void
    {
        translatorsGroup = new FlxSpriteGroup();
        translatorsGroup.y = contributorsGroup.y + contributorsGroup.height + 150;
        add(translatorsGroup);

        var translatorsText = new FlxText(0, 0, 0, getLanguageText('credits_translators_title'));
        translatorsText.setFormat(Paths.font("comic.ttf"), 40, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        translatorsText.borderSize = 3;
        translatorsText.screenCenter(X);
        translatorsGroup.add(translatorsText);

        windspel = new CreditsPerson(275, 100, {
            name: 'Windspel',
            description: getLanguageText('credits_windspel'),
            icon: 'translators/windspel'
        });
        translatorsGroup.add(windspel);
        
        aizakku = new CreditsPerson(555, 90, {
            name: 'Aizakku',
            description: getLanguageText('credits_aizakku'),
            icon: 'translators/Aizakku'
        });
        translatorsGroup.add(aizakku);
        
        soulegal = new CreditsPerson(825, 75, {
            name: 'Soulegal',
            description: getLanguageText('credits_soulegal'),
            icon: 'translators/Soulegal'
        });
        translatorsGroup.add(soulegal);
    }

    function buildSpecialThanks():Void
    {
        specialThanksGroup.y = translatorsGroup.y + translatorsGroup.height + 50;
        add(specialThanksGroup);
        
        var specialThanksText = new FlxText(0, 0, 0, getLanguageText('credits_specialThanks_title'));
        specialThanksText.setFormat(Paths.font("comic.ttf"), 40, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        specialThanksText.borderSize = 3;
        specialThanksText.screenCenter(X);
        specialThanksGroup.add(specialThanksText);
        
        villezen = new CreditsPerson(425, 85, {
            name: 'Villezen',
            description: getLanguageText('credits_villezen'),
            icon: 'contributors/Villezen'
        });
        specialThanksGroup.add(villezen);

        shifty = new CreditsPerson(625, 85, {
            name: 'ShiftyTM',
            description: getLanguageText('credits_shifty'),
            icon: 'contributors/ShiftyTM'
        });
        specialThanksGroup.add(shifty);
        
        statictigers = new CreditsPerson(225, 210, {
            name: 'Statictigers',
            description: getLanguageText('credits_statictigers'),
            icon: 'contributors/statictigers'
        });
        specialThanksGroup.add(statictigers);

        sky = new CreditsPerson(520, 215, {
            name: 'SkyFactorial',
            description: getLanguageText('credits_skyFactorial'),
            icon: 'contributors/Sky!'
        });
        specialThanksGroup.add(sky);   

        ray = new CreditsPerson(825, 210, {
            name: 'Ray',
            description: getLanguageText('credits_ray'),
            icon: 'contributors/ray'
        });
        specialThanksGroup.add(ray);
    }

    function buildMenuBackgroundGroup():Void
    {
        menuBackgroundGroup = new FlxSpriteGroup();
        menuBackgroundGroup.y = specialThanksGroup.y + specialThanksGroup.height + 50;
        add(menuBackgroundGroup);
        
        var menuBackgroundText = new FlxText(0, 0, 0, getLanguageText('credits_menuBackground_title'));
        menuBackgroundText.setFormat(Paths.font("comic.ttf"), 40, FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        menuBackgroundText.borderSize = 3;
        menuBackgroundText.screenCenter(X);
        menuBackgroundGroup.add(menuBackgroundText);

        var menuBackgroundPeopleList = new FlxText(0, 100, 0, 
        'Aadsta, binos, BluHairMan, bubbscadex, divinityinterstella, odín\n
        fa0ndy, G9odDragons, ghostrified, GrassyCS, Inescapable, Jamarr Studios Bro, Jukebox\n
        kezyartz, knightguy12, lader_basic, Lancey, literalcereal, LOST GLITCHSTER, mamakotomi\n
        Maplebiscuit, MASONTHESHORTIE, Max Dimo, Moli, cometkinesis, PhoneyX, picher, ramzgaming\n
        ratobsessdj, shinsoku 65, sillyfer, sk0rbias, sweetnpeachie, syd, Terrysu, theferociousgamer\n
        tristan86, UNICORNY, yessirree, zxyuo
        ');
        menuBackgroundPeopleList.setFormat(Paths.font("comic.ttf"), 20, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        menuBackgroundPeopleList.borderSize = 1.5;
        menuBackgroundPeopleList.screenCenter(X);
        menuBackgroundPeopleList.x -= 35;
        menuBackgroundGroup.add(menuBackgroundPeopleList);
    }

    function buildPlaytesters():Void
    {
        playtestersGroup = new FlxSpriteGroup();
        playtestersGroup.y = menuBackgroundGroup.y + menuBackgroundGroup.height + 25;
        add(playtestersGroup);

        var playtestersText:FlxText = new FlxText(0, 0, 0, getLanguageText('credits_playtesters_title'));
        playtestersText.setFormat(Paths.font("comic.ttf"), 40, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        playtestersText.borderSize = 3;
        playtestersText.screenCenter(X);
        playtestersGroup.add(playtestersText);
        
        var playtestersList:FlxText = new FlxText(0, 50, 0, '
        Alexander Cooper 19, mistiiful, magical, ztgds, Noitar, TecheVent\n
        Villezen, wugalex, SilverEscaper, LongDonny, fisshcakes\n
        YourAverageMental, stevthebevchev, sibottle, statictigers, Jun3putt
        ');
        playtestersList.setFormat(Paths.font("comic.ttf"), 20, FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        playtestersList.borderSize = 1.5;
        playtestersList.updateHitbox();
        playtestersList.screenCenter(X);
        playtestersList.x -= 35;
        playtestersGroup.add(playtestersList);
    }

    function getLanguageText(id:String)
    {
        return LanguageManager.getTextString(id, DEFAULT_LANGUAGE_LIST);
    }
}

class CreditsPerson extends FlxSpriteGroup
{
    public function new(x:Float, y:Float, params:CreditsPersonParams)
    {
        super(x, y);

        params.scale ??= 1.0;
        params.antialiasing ??= true;
        
        var nameSize:Float = 24 * params.scale;
        var descSize:Float = 16 * params.scale;

        var iconGraphic = Paths.image('credits/${params.icon}');
        if (iconGraphic == null)
            iconGraphic = Paths.image('credits/placeholder');

        var icon = new FlxSprite().loadGraphic(Paths.image('credits/${params.icon}'));
        icon.setGraphicSize(75 * params.scale);
        icon.updateHitbox();
        icon.antialiasing = params.antialiasing;
        add(icon);

        var nameText:FlxText = new FlxText(0, 0, 0, params.name);
        nameText.setFormat(Paths.font("comic_normal.ttf"), Std.int(nameSize), FlxColor.WHITE, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        nameText.borderSize = 2.5;
        nameText.x = (icon.x - this.x) + icon.width + 10;
        nameText.y = (icon.y - this.y) + (icon.height - nameText.textField.textHeight) / 2;
        add(nameText);

        var creditWidth:Float = ((nameText.x + nameText.textField.textWidth) - icon.x);

        var descriptionText:FlxText = new FlxText(0, 0, 0, params.description);
        descriptionText.setFormat(Paths.font("comic_normal.ttf"), Std.int(descSize), FlxColor.WHITE, FlxTextAlign.CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
        descriptionText.borderSize = 2;
        add(descriptionText);
        descriptionText.x = icon.x + (creditWidth - descriptionText.textField.textWidth) / 2;
        descriptionText.y = icon.y + icon.height + 5;
    }
}