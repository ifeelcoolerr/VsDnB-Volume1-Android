package ui.menu.settings;

import controls.PlayerSettings;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxSlider;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.math.FlxPoint.FlxCallbackPoint;
import flixel.group.FlxGroup;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxSpriteContainer;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.util.FlxSignal;
import play.PauseSubState;

import graphics.GameCamera;

import ui.menu.settings.*;
import ui.menu.settings.categories.*;
import ui.menu.settings.components.*;

import util.FileUtil;
import util.GradientUtil;
import util.TweenUtil;

#if mobileC
import mobile.MobileControlsSubState;
#end

enum SelectState
{
	SelectingCategory;
	SelectingOption;
}

class SettingsMenu extends MusicBeatSubstate
{
	static var curCategorySelection:Int = 0;
	
	/**
	 * Map of the classes that represent a category.
	 * TODO: Make this more modular instead of several arrays?
	 */
	final categoryMap:Map<String, Class<SettingsCategory>> = [
		'general' => Options_General,
		'accessibility' => Options_Accessibility,
		'window' => Options_Window,
		'audio' => Options_Audio,
		'ui' => Options_UI,
		'misc' => Options_Misc,
	];

	/**
	 * The ids of all of the categories.
	 */
	final categories:Array<String> = ['general', 'accessibility', 'window', 'audio', 'ui', 'misc'];
	
	/**
	 * The current state of the menu. This can either be you selecting a setting category, or you changing a setting from a category.
	 */
	var curState(default, set):SelectState = SelectingCategory;

	/**
	 * The current category the user is in.
	 */
	var curCategory:SettingsCategory;

	/**
	 * The separate keybinds menu used to help configure the user's keybinds.
	 */
	var keybindsMenu:ConfigureKeybinds;
	

	/**
	 * The gradient menu background behind the clipboard.
	 */
	var bg:FlxSprite;

	/**
	 * The group that holds all the objects in the menu. This exists to help with transitions.
	 */
	var clipboard:FlxSpriteGroup = new FlxSpriteGroup();

	/**
	 * The group that contains all of elements of the selected category.
	 */
	public var categorySelectGroup:FlxSpriteGroup = new FlxSpriteGroup();

	/**
	 * The sprite that holds all of the settings.
	 */
	var clipboardSpr:FlxSprite;

	/**
	 * The text that displays the current section the user is in.
	 */
	var sectionText:FlxText;

	/**
	 * The left arrow sprite used to move categories back.
	 */
	var arrowLeft:FlxSprite;
	
	/**
	 * The right arrow sprite used to move categories forward.
	 */
	var arrowRight:FlxSprite;
	
	/**
	 * Whether the user's allowed to interact with the menu, or any options.
	 */
	public var canInteract:Bool = true;

	public override function create()
	{
		super.create();

		new FlxTimer().start(0.5, function(timer:FlxTimer)
		{
			init();
			showClipboard();
		});

		camera = new GameCamera();
		camera.bgColor.alpha = 0;

		FlxG.cameras.add(camera, false);

		#if mobileC
		addVirtualPad(LEFT_FULL, A_B_C);
		addVirtualPadCamera();
		#end
	}

	public function init()
	{
		bg = new FlxSprite().loadGraphic(FileUtil.randomizeBG());
		bg.setGraphicSize(FlxG.width, FlxG.height);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		GradientUtil.applyGradientToSprite(bg, [FlxColor.GREEN, FlxColor.BLUE]);
		
		clipboard.scrollFactor.set();
		add(clipboard);

		clipboardSpr = new FlxSprite().loadGraphic(Paths.image('settings/clipboard'));
		clipboardSpr.screenCenter(X);
		clipboard.add(clipboardSpr);

		clipboard.add(categorySelectGroup);

		sectionText = new FlxText(0, 200, 0, 'General');
		sectionText.setFormat(Paths.font('comic_normal.ttf'), 30, FlxColor.BLACK, FlxTextAlign.CENTER);
		sectionText.screenCenter(X);
		categorySelectGroup.add(sectionText);

		arrowLeft = new FlxSprite();
		arrowRight = new FlxSprite();

		// Flip the right arrow so it faces to the right.
		arrowRight.flipX = true;

		for (arrow in [arrowLeft, arrowRight])
		{
			arrow.frames = Paths.getSparrowAtlas('settings/arrow');
			arrow.animation.addByPrefix('idle', 'settings_arrow_static', 24);
			arrow.animation.play('idle', true);
			categorySelectGroup.add(arrow);

			arrow.scale.set(0.8, 0.8);
			arrow.updateHitbox();
		}
		switchCategory(categories[curCategorySelection]);
		updateHeaderText();
	}

	public override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!canInteract)
			return;

		var left = PlayerSettings.controls.LEFT;
		var right = PlayerSettings.controls.RIGHT;

		var leftP = PlayerSettings.controls.LEFT_P;
		var rightP = PlayerSettings.controls.RIGHT_P;
		var downP = PlayerSettings.controls.DOWN_P;
		var upP = PlayerSettings.controls.UP_P;
		var back = PlayerSettings.controls.BACK;

		#if mobileC
		var mobileControls = virtualPad.buttonC.justPressed;
		#end

		switch (curState)
		{
			case SelectingCategory:
				if (arrowLeft != null && canInteract)
				{
					if (left)
					{
						arrowLeft.scale.set(0.7, 0.7);
					}
					else
					{
						arrowLeft.scale.set(0.8, 0.8);
					}
					if (leftP)
					{
						changeCategorySelection(-1);
					}
				}
				if (arrowRight != null && canInteract)
				{
					if (right)
					{
						arrowRight.scale.set(0.7, 0.7);
					}
					else
					{
						arrowRight.scale.set(0.8, 0.8);
					}
					if (rightP)
					{
						changeCategorySelection(1);
					}
				}

				if (canInteract && curCategory != null)
				{
					if (downP)
					{
						curCategory.changeSelection(curCategory.firstAvailableOption - curCategory.curOptionSelected);
						curState = SelectingOption;
					}
					if (upP)
					{
						curCategory.changeSelection(curCategory.lastAvailableOption - curCategory.curOptionSelected);
						curState = SelectingOption;
					}
				}
			case SelectingOption:
				if (canInteract && curCategory != null)
				{
					if ((upP && curCategory.curOptionSelected == curCategory.firstAvailableOption) || (downP && curCategory.curOptionSelected == curCategory.lastAvailableOption))
					{
						curState = SelectingCategory;
						curCategory.deselectOption();
					}
					else
					{
						curCategory.handleInputs();
					}
				}
		}

		#if mobileC
		if (mobileControls)
		{
			FlxG.switchState(() -> new MobileControlsSubState());
		}
		#end

		if (back #if mobileC || FlxG.android.justReleased.BACK #end)
		{
			closeClipboard();
		}
	}

	public override function close()
	{
		FlxG.cameras.remove(camera);
		camera.destroy();
		super.close();
	}

	public function showClipboard()
	{
		canInteract = false;
		
		var expoOutStep = TweenUtil.easeSteps(20, FlxEase.expoOut);

		clipboard.y = clipboard.height;

		FlxTween.tween(clipboard, {y: 0}, 1, {
			ease: expoOutStep,
			onComplete: function(t:FlxTween)
			{
				new FlxTimer().start(0.2, function(timer:FlxTimer)
				{
					canInteract = true;
				});
			}
		});
	}

	public function closeClipboard()
	{
		canInteract = false;
		var self = this;
		
		var sineOutStep:EaseFunction = TweenUtil.easeSteps(20, FlxEase.sineOut);

		new FlxTimer().start(0.5, function(timer:FlxTimer)
		{
			FlxTween.tween(self.clipboard, {y: self.clipboard.height}, 0.5, {
				ease: sineOutStep,
				onComplete: function(t:FlxTween)
				{
					new FlxTimer().start(0.2, function(timer:FlxTimer)
					{
						FlxTween.tween(self.bg, {alpha: 0}, 0.5, {
							ease: sineOutStep,
							onComplete: function(t:FlxTween)
							{
								#if mobileC
								if (self._parentState != null && Std.isOfType(self._parentState, PauseSubState))
								{
    								var pause = cast(self._parentState, PauseSubState);
    								pause.addVirtualPad(UP_DOWN, A);
									pause.addVirtualPadCamera();
								}
								if (self._parentState != null && Std.isOfType(self._parentState, MainMenuState))
								{
    								var main = cast(self._parentState, MainMenuState);
    								main.addVirtualPad(LEFT_RIGHT, A_B);
								}
								#end
								self.close();
							}
						});
					});
				}
			});
		});
	}

	public function changeCategorySelection(selection:Int)
	{
		if (selection == 0)
			return;

		curCategorySelection += selection;

		SoundController.play(Paths.sound('scrollMenu'), 0.7);

		if (curCategorySelection < 0)
			curCategorySelection = categories.length - 1;
		if (curCategorySelection > categories.length - 1)
			curCategorySelection = 0;

		switchCategory(categories[curCategorySelection]);
	}

	public function switchCategory(groupName:String)
	{
		if (curCategory != null)
		{
			clipboard.remove(curCategory);
			curCategory.destroy();
			curCategory = null;
		}

		curCategory = Type.createInstance(categoryMap[groupName], [this]);
		clipboard.add(curCategory);

		updateHeaderText();
	}

	function updateHeaderText()
	{
		sectionText.text = curCategory.getName();
		sectionText.screenCenter(X);
		arrowLeft.setPosition(sectionText.x - arrowLeft.width - 10, sectionText.y + (sectionText.textField.textHeight - arrowLeft.height) / 2);
		arrowRight.setPosition(sectionText.x
			+ sectionText.textField.textWidth
			+ 10,
			sectionText.y
			+ (sectionText.textField.textHeight - arrowRight.height) / 2);
	}

	public function openKeybindsMenu()
	{
		categorySelectGroup.visible = false;
		curCategory.visible = false;
		canInteract = false;

		keybindsMenu = new ConfigureKeybinds(this);
		add(keybindsMenu);
	}

	public function closeKeybindsMenu()
	{
		categorySelectGroup.visible = true;
		curCategory.visible = true;

		remove(keybindsMenu, true);

		new FlxTimer().start(0.1, function(timer:FlxTimer)
		{
			canInteract = true;
		});
	}

	function set_curState(value:SelectState):SelectState
	{
		switch (value)
		{
			case SelectingCategory:
				for (i in [sectionText, arrowLeft, arrowRight])
				{
					i.alpha = 1;
				}
				sectionText.scale.set(1, 1);

				SoundController.play(Paths.sound('scrollMenu'), 0.7);
			case SelectingOption:
				for (i in [sectionText, arrowLeft, arrowRight])
				{
					i.alpha = 0.6;
				}
				sectionText.scale.set(0.8, 0.8);
		}
		return curState = value;
	}
}

typedef BaseOptionParams =
{
	var name:String;
	var description:String;
}

class SettingsOption extends FlxSpriteGroup
{
	public var menu:SettingsMenu;

	public var canInteract(default, set):Bool = true;

	function set_canInteract(value:Bool):Bool
	{
		return canInteract = value;
	}

	public var selected:Bool = false;

	public var onDeselected:FlxSignal = new FlxSignal();
	public var onSelected:FlxSignal = new FlxSignal();
	public var onAccept:FlxSignal = new FlxSignal();

	public function new(x:Float, y:Float)
	{
		super(x, y);

		onSelected.add(function()
		{
			if (canInteract && menu.canInteract)
				selected = true;
		});
		onDeselected.add(function()
		{
			if (canInteract && menu.canInteract)
				selected = false;
		});
	}
}

typedef CheckboxOptionParams =
{
	> BaseOptionParams,
	var callback:Bool->Void;
}

/**
 * An option that resides around being a toggle.
 */
class CheckboxOption extends SettingsOption
{
	override function set_canInteract(value:Bool):Bool
	{
		if (!value)
		{
			playCheckboxAnim('unavailable');
		}
		else
		{
			updateCheckbox(checked, true);
		}

		var targetAlpha = value ? 1 : 0.7;
		for (i in [checkbox, nameText, descriptionText])
		{
			i.alpha = targetAlpha;
		}
		return canInteract = value;
	}

	public var checked:Bool;

	public var callback:Bool->Void;
	public var checkboxScale:FlxCallbackPoint;

	var checkboxOffsets:Map<String, Array<Float>> = [
		'idle' => [0, 0],
		'check' => [0, 17],
		'check_idle' => [0.5, 4.5],
		'unavailable' => [0, 0],
	];

	public var checkbox:FlxSprite;

	var nameText:FlxText;
	var descriptionText:FlxText;

	public function new(x:Float, y:Float, params:CheckboxOptionParams)
	{
		super(x, y);

		checkbox = new FlxSprite();
		checkbox.frames = Paths.getSparrowAtlas('settings/checkbox');
		checkbox.animation.addByPrefix('idle', 'settings_box_none_static', 24);
		checkbox.animation.addByPrefix('check', 'settings_box_check0', 24, false);
		checkbox.animation.addByPrefix('check_idle', 'settings_box_check_static', 24);
		checkbox.animation.addByPrefix('unavailable', 'settings_box_unavailable', 24);
		checkbox.animation.play('idle', true);
		add(checkbox);

		checkboxScale = new FlxCallbackPoint(null, null, function(point:FlxPoint)
		{
			checkbox.scale.set(point.x, point.y);

			var offsets = getCheckboxOffsets(checkbox.animation.curAnim.name);
			checkbox.offset.set(offsets[0] * point.x, offsets[1] * point.y);
		});

		nameText = new FlxText(70, 0, 0, params.name);
		nameText.setFormat(Paths.font('comic_normal.ttf'), 20, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(nameText);

		descriptionText = new FlxText(75, 30, 0, params.description);
		descriptionText.setFormat(Paths.font('comic_normal.ttf'), 15, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(descriptionText);

		// 700 is the length of the fill of the clipboard
		// ~300 is the start x position of the fill.
		descriptionText.fieldWidth = 700 - (descriptionText.x - 300);

		this.callback = params.callback;

		onDeselected.add(function()
		{
			if (canInteract && menu.canInteract)
				checkboxScale.set(0.85, 0.85);
		});
		onSelected.add(function()
		{
			if (canInteract && menu.canInteract)
				checkboxScale.set(1, 1);
		});
		onAccept.add(function()
		{
			if (canInteract && menu.canInteract)
				setChecked(!checked);
		});

		checkboxScale.set(0.85, 0.85);
	}

	public function setChecked(value:Bool, fireCallback:Bool = true, instant:Bool = false)
	{
		checked = value;
		if (fireCallback)
		{
			if (value)
			{
				SoundController.play(Paths.sound('settings/checkbox_checked'), 1);
			}
			else
			{
				SoundController.play(Paths.sound('settings/checkbox_unchecked'), 1);
			}
			callback(checked);
		}
		updateCheckbox(value, instant);
	}

	public function updateCheckbox(state:Bool, instant:Bool = false)
	{
		playCheckboxAnim(state ? (instant ? 'check_idle' : 'check') : 'idle');
		checkbox.animation.onFinish.addOnce(function(anim:String)
		{
			if (anim == 'check')
			{
				playCheckboxAnim('check_idle');
			}
		});
	}

	function playCheckboxAnim(anim:String)
	{
		checkbox.animation.play(anim, true);
		checkbox.offset.set(getCheckboxOffsets(anim)[0] * checkboxScale.x, getCheckboxOffsets(anim)[1] * checkboxScale.y);
	}

	function getCheckboxOffsets(anim:String):Array<Float>
	{
		return checkboxOffsets[anim] ?? [0, 0];
	}
}

typedef CallbackOptionParams =
{
	> BaseOptionParams,
	var callback:Void->Void;
}

/**
 * An option that triggers a callback upon being clicked.
 */
class CallbackOption extends SettingsOption
{
	override function set_canInteract(value:Bool):Bool
	{
		var targetAlpha = value ? 1 : 0.7;

		for (i in [gear, nameText, descriptionText])
		{
			i.alpha = targetAlpha;
		}
		return canInteract = value;
	}

	public var callback:Void->Void;

	var gear:FlxSprite;
	var nameText:FlxText;
	var descriptionText:FlxText;

	public function new(x:Float, y:Float, params:CallbackOptionParams)
	{
		super(x, y);

		this.callback = params.callback;

		gear = new FlxSprite();
		gear.frames = Paths.getSparrowAtlas('settings/gear');
		gear.animation.addByPrefix('idle', 'settings_gear', 24);
		gear.animation.play('idle', true);
		gear.scale.set(0.9, 0.9);
		add(gear);

		nameText = new FlxText(70, 0, 0, params.name);
		nameText.setFormat(Paths.font('comic_normal.ttf'), 20, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(nameText);

		descriptionText = new FlxText(70, 30, 0, params.description);
		descriptionText.setFormat(Paths.font('comic_normal.ttf'), 15, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(descriptionText);
		
		// 700 is the length of the fill of the clipboard
		// ~300 is the start x position of the fill.
		descriptionText.fieldWidth = 700 - (descriptionText.x - 300);

		onSelected.add(function()
		{
			if (canInteract)
				gear.scale.set(1, 1);
		});
		onDeselected.add(function()
		{
			if (canInteract && menu.canInteract)
				gear.scale.set(0.9, 0.9);
		});
		onAccept.add(function()
		{
			if (canInteract && menu.canInteract)
			{
				SoundController.play(Paths.sound('settings/cog_accept'), 0.7);
				callback();
			}
		});
	}
}

typedef SliderOptionParams =
{
	> BaseOptionParams,

	var min:Float;
	var max:Float;
	var callback:Float->Void;
}

/**
 * An option that uses a slider for it's value.
 */
class SliderOption extends SettingsOption
{
	public var value(get, set):Float;

	function set_value(value:Float):Float
		return slider.value = value;

	function get_value():Float
		return slider.value;

	public var slider:SettingsSlider;

	public function new(x:Float, y:Float, params:SliderOptionParams)
	{
		super(x, y);

		slider = new SettingsSlider(0, 0, params.min, params.max, params.callback);
		slider.parent = this;
		add(slider);

		var name = new FlxText(260, 0, 0, params.name);
		name.setFormat(Paths.font('comic_normal.ttf'), 20, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(name);

		var description = new FlxText(260, 30, 0, params.description);
		description.setFormat(Paths.font('comic_normal.ttf'), 15, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(description);
		
		// 700 is the length of the fill of the clipboard
		// ~300 is the start x position of the fill.
		description.fieldWidth = 700 - (description.x - 300);

		onSelected.add(function()
		{
			if (canInteract && menu.canInteract)
			{
				slider.interactable = true;
			}
		});
		onDeselected.add(function()
		{
			if (canInteract && menu.canInteract)
			{
				slider.interactable = false;
			}
		});
		slider.interactable = false;
	}

	public function setValue(value:Float)
	{
		slider.setSliderValue(value);
	}
}

/**
 * The slider used for the settings menu.
 */
class SettingsSlider extends FlxSlider
{
	public var parent:SliderOption;

	public var minHandleX(get, never):Float;

	function get_minHandleX():Float
		return (x - handle.width / 2) + offset.x;

	public var maxHandleX(get, never):Float;

	function get_maxHandleX():Float
		return x + _width - handle.width / 2 + offset.x;

	public var interactable(default, set):Bool = false;

	function set_interactable(value:Bool):Bool
	{
		handle.alpha = value ? 1 : 0.7;
		handle.scale.set(value ? 0.8 : 0.7, value ? 0.8 : 0.7);

		return interactable = value;
	}

	public var onPress:FlxSignal = new FlxSignal();
	public var onRelease:FlxSignal = new FlxSignal();

	public function new(x:Float, y:Float, min:Float, max:Float, callback:Float->Void)
	{
		super(null, null, x, y, min, max);

		this.callback = callback;

		body.loadGraphic(Paths.image('settings/slider'));
		_width = Std.int(body.width);
		_height = Std.int(body.height);
		updateBounds();

		handle.frames = Paths.getSparrowAtlas('settings/gear');
		handle.animation.addByPrefix('idle', 'settings_gear', 24);
		handle.animation.play('idle');
		handle.scale.set(0.8, 0.8);
		handle.updateHitbox();
		handle.y = body.y + (body.height - handle.height) / 2;

		for (i in [nameLabel, valueLabel, minLabel, maxLabel])
		{
			i.visible = false;
		}
	}

	override public function update(elapsed:Float):Void
	{
		handle.update(elapsed);

		var left = PlayerSettings.controls.LEFT;
		var right = PlayerSettings.controls.RIGHT;

		var leftR = PlayerSettings.controls.LEFT_R;
		var rightR = PlayerSettings.controls.RIGHT_R;

		var canInteract = parent.menu.canInteract && parent.canInteract && interactable;

		if (left && canInteract)
		{
			handle.x -= (maxHandleX - minHandleX) * elapsed;
		}
		if (right && canInteract)
		{
			handle.x += (maxHandleX - minHandleX) * elapsed;
		}
		if ((left || right) && canInteract)
		{
			onPress.dispatch();
		}
		if ((leftR || rightR) && canInteract)
		{
			onRelease.dispatch();
		}
		updateValue();

		// Update the value variable
		if ((varString != null) && (Reflect.getProperty(_object, varString) != null))
		{
			value = Reflect.getProperty(_object, varString);
		}

		boundHandle();
	}

	override function updateValue()
	{
		if (_lastPos != relativePos)
		{
			if (callback != null)
				callback((relativePos * (maxValue - minValue)) + minValue);

			_lastPos = relativePos;
		}
		handle.angle = 360 * relativePos;
	}

	override function get_relativePos():Float
	{
		var pos:Float = FlxMath.remapToRange(handle.x, minHandleX, maxHandleX, 0, 1);

		// Relative position can't be bigger than 1
		if (pos > 1)
		{
			pos = 1;
		}

		return pos;
	}

	function boundHandle()
	{
		handle.x = FlxMath.bound(handle.x, minHandleX, maxHandleX);
	}

	public function setSliderValue(value:Float)
	{
		handle.x = FlxMath.remapToRange(value, minValue, maxValue, minHandleX, maxHandleX);
	}
}

typedef SelectOptionParams =
{
	> BaseOptionParams,
	var options:Array<String>;
	var optionsID:Array<String>;
	var selectCallback:String->Void;
}

/**
 * An option with multiple options for you to select via arrows.
 */
class SelectOption extends SettingsOption
{
	override function set_canInteract(value:Bool):Bool
	{
		var targetAlpha = value ? 1 : 0.7;
		for (i in [arrowLeft, arrowRight, selectedText, nameText, descriptionText])
		{
			i.alpha = targetAlpha;
		}

		return canInteract = value;
	}

	var options:Array<String>;
	var optionsID:Array<String>;
	var callback:String->Void;

	var selection:Int;

	var arrowLeft:FlxSprite;
	var arrowRight:FlxSprite;
	var selectedText:FlxText;
	var nameText:FlxText;
	var descriptionText:FlxText;

	public function new(x:Float, y:Float, params:SelectOptionParams)
	{
		super(x, y);

		this.options = params.options;
		this.optionsID = params.optionsID;

		this.callback = params.selectCallback;

		arrowLeft = new FlxSprite();
		arrowRight = new FlxSprite();

		arrowRight.flipX = true;

		for (arrow in [arrowLeft, arrowRight])
		{
			arrow.frames = Paths.getSparrowAtlas('settings/arrow');
			arrow.animation.addByPrefix('idle', 'settings_arrow_static', 24);
			arrow.animation.play('idle', true);
			add(arrow);

			arrow.scale.set(0.5, 0.5);
			arrow.updateHitbox();
		}

		selectedText = new FlxText(0, 15, 0, '');
		selectedText.setFormat(Paths.font('comic_normal.ttf'), 20, FlxColor.BLACK, FlxTextAlign.CENTER);
		selectedText.scale.set(0.8, 0.8);
		add(selectedText);

		nameText = new FlxText(250, 0, 0, params.name);
		nameText.setFormat(Paths.font('comic_normal.ttf'), 20, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(nameText);

		descriptionText = new FlxText(250, 30, 0, params.description);
		descriptionText.setFormat(Paths.font('comic_normal.ttf'), 15, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(descriptionText);
		
		// 700 is the length of the fill of the clipboard
		// ~300 is the start x position of the fill.
		descriptionText.fieldWidth = 700 - (descriptionText.x - 300);

		onSelected.add(function()
		{
			selectedText.scale.set(1, 1);
		});
		onDeselected.add(function()
		{
			selectedText.scale.set(0.8, 0.8);
		});

		changeOptionSelection(0, false);
	}

	public override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!canInteract || !menu.canInteract || !selected)
			return;

		var left = PlayerSettings.controls.LEFT;
		var leftP = PlayerSettings.controls.LEFT_P;

		var right = PlayerSettings.controls.RIGHT;
		var rightP = PlayerSettings.controls.RIGHT_P;

		if (left)
		{
			arrowLeft.scale.set(0.45, 0.45);
		}
		else
		{
			arrowLeft.scale.set(0.5, 0.5);
		}

		if (right)
		{
			arrowRight.scale.set(0.45, 0.45);
		}
		else
		{
			arrowRight.scale.set(0.5, 0.5);
		}

		if (leftP)
		{
			changeOptionSelection(-1);
		}
		if (rightP)
		{
			changeOptionSelection(1);
		}
	}

	public function changeOptionSelection(amount:Int = 0, fireCallback:Bool = true)
	{
		selection += amount;

		if (selection < 0)
			selection = options.length - 1;
		if (selection > options.length - 1)
			selection = 0;

		setOption(optionsID[selection], fireCallback);
	}

	public function setSelectedOption(option:String, fireCallback:Bool = true)
	{
		changeOptionSelection(optionsID.indexOf(option) - selection, fireCallback);
	}

	function setOption(option:String, fireCallback:Bool = true)
	{
		if (fireCallback)
		{
			SoundController.play(Paths.sound('scrollMenu'), 0.7);
			callback(option);
		}
		selectedText.text = options[optionsID.indexOf(option)];

		arrowLeft.setPosition(selectedText.x - arrowLeft.width - 10, selectedText.y + (selectedText.textField.textHeight - arrowLeft.height) / 2);
		arrowRight.setPosition(selectedText.x
			+ selectedText.textField.textWidth
			+ 10,
			selectedText.y
			+ (selectedText.textField.textHeight - arrowRight.height) / 2);
		nameText.x = descriptionText.x = arrowRight.x + arrowRight.width + 10;
	}
}


typedef NumericStepperOptionParams =
{
	> BaseOptionParams,

	var min:Float;
	var max:Float;
	var stepper:Float;
	var callback:Float->Void;

	var ?holdThreshold:Float;
	var ?changeTimer:Float;
}

/**
 * An option that allows for the user to increment a stepper value to change a setting.
 */
class NumericStepperOption extends SettingsOption
{
	override function set_canInteract(value:Bool):Bool
	{
		var targetAlpha = value ? 1 : 0.7;
		for (i in [arrowLeft, arrowRight, valueText, nameText, descriptionText])
		{
			i.alpha = targetAlpha;
		}

		return canInteract = value;
	}

	var value:Float;

	var min:Float;
	var max:Float;
	var stepper:Float;

	var callback:Float->Void;

	var arrowLeft:FlxSprite;
	var arrowRight:FlxSprite;
	var valueText:FlxText;
	var nameText:FlxText;
	var descriptionText:FlxText;

	var holdTimer:Float = 0;
	var changeTimer:Float = 0;

	var holdTimerThreshold:Float = 1;
	var changeTimerMax:Float = 1;

	public function new(x:Float, y:Float, params:NumericStepperOptionParams)
	{
		super(x, y);

		this.min = params.min;
		this.max = params.max;
		this.stepper = params.stepper;
		this.callback = params.callback;
		this.changeTimerMax = params?.changeTimer ?? 1.0;
		this.holdTimerThreshold = params?.holdThreshold ?? 1.0;

		arrowLeft = new FlxSprite();
		arrowRight = new FlxSprite();

		arrowRight.flipX = true;

		for (arrow in [arrowLeft, arrowRight])
		{
			arrow.frames = Paths.getSparrowAtlas('settings/arrow');
			arrow.animation.addByPrefix('idle', 'settings_arrow_static', 24);
			arrow.animation.play('idle', true);
			add(arrow);

			arrow.scale.set(0.5, 0.5);
			arrow.updateHitbox();
		}

		valueText = new FlxText(0, 15, 0, '');
		valueText.setFormat(Paths.font('comic_normal.ttf'), 20, FlxColor.BLACK, FlxTextAlign.CENTER);
		valueText.scale.set(0.8, 0.8);
		add(valueText);

		nameText = new FlxText(250, 0, 0, params.name);
		nameText.setFormat(Paths.font('comic_normal.ttf'), 20, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(nameText);

		descriptionText = new FlxText(250, 30, 0, params.description);
		descriptionText.setFormat(Paths.font('comic_normal.ttf'), 15, FlxColor.BLACK, FlxTextAlign.LEFT);
		add(descriptionText);
		
		// 700 is the length of the fill of the clipboard
		// ~300 is the start x position of the fill.
		descriptionText.fieldWidth = 700 - (descriptionText.x - 300);

		onSelected.add(function()
		{
			valueText.scale.set(1, 1);
		});
		onDeselected.add(function()
		{
			valueText.scale.set(0.8, 0.8);
		});
	}

	public override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!canInteract || !menu.canInteract || !selected)
			return;

		var left = PlayerSettings.controls.LEFT;
		var leftP = PlayerSettings.controls.LEFT_P;

		var right = PlayerSettings.controls.RIGHT;
		var rightP = PlayerSettings.controls.RIGHT_P;

		if (left)
		{
			arrowLeft.scale.set(0.45, 0.45);

			holdTimer += elapsed;
			if (holdTimer > holdTimerThreshold)
			{
				changeTimer -= elapsed;
				if (changeTimer <= 0)
				{
					incrementStepperValue(-stepper);
					changeTimer = changeTimerMax;
				}
			}
		}
		else
		{
			arrowLeft.scale.set(0.5, 0.5);
		}

		if (right)
		{
			arrowRight.scale.set(0.45, 0.45);
			
			holdTimer += elapsed;
			if (holdTimer > holdTimerThreshold)
			{
				changeTimer -= elapsed;
				if (changeTimer <= 0)
				{
					incrementStepperValue(stepper);
					changeTimer = changeTimerMax;
				}
			}
		}
		else
		{
			arrowRight.scale.set(0.5, 0.5);
		}

		if (leftP)
		{
			holdTimer = 0;
			incrementStepperValue(-stepper);
		}
		if (rightP)
		{
			holdTimer = 0;
			incrementStepperValue(stepper);
		}
	}

	public function setValue(value:Float)
	{
		this.value = FlxMath.bound(value, min, max);
		valueText.text = Std.string(this.value);

		arrowLeft.setPosition(valueText.x - arrowLeft.width - 10, valueText.y + (valueText.textField.textHeight - arrowLeft.height) / 2);
		arrowRight.setPosition(valueText.x + valueText.textField.textWidth + 10, valueText.y + (valueText.textField.textHeight - arrowRight.height) / 2);
		nameText.x = descriptionText.x = arrowRight.x + arrowRight.width + 10;
	}

	function incrementStepperValue(amount:Float, fireCallback:Bool = true)
	{
		setValue(this.value + amount);

		if (callback != null && fireCallback)
			callback(this.value);
	}
}