package ui.menu.settings.categories;

import data.language.LanguageManager;
import play.save.Preferences;
import ui.menu.settings.SettingsMenu.CheckboxOption;
import ui.menu.settings.SettingsMenu.NumericStepperOption;

class Options_Window extends SettingsCategory
{
	#if (!mac && !mobile)
	var checkbox_darkMode:CheckboxOption;
	#end
	var stepper_fps:NumericStepperOption;

	public override function init()
	{
		#if (!mac && !mobile)
		checkbox_darkMode = new CheckboxOption(400, 600, {
			name: LanguageManager.getTextString('settings_window_darkMode'),
			description: LanguageManager.getTextString('settings_window_darkMode_description'),
			callback: function(value:Bool)
			{
				Preferences.darkMode = value;
			}
		});
		checkbox_darkMode.setChecked(Preferences.darkMode, false, true);
		checkbox_darkMode.canInteract = !Preferences.borderless;
		#end

		stepper_fps = new NumericStepperOption(375, 300, {
			name: LanguageManager.getTextString('settings_window_fps'),
			description: LanguageManager.getTextString('settings_window_fps_description'),
			min: 10,
			max: 240,
			stepper: 1,
			changeTimer: 0.02,
			callback: function(value:Float)
			{
				Preferences.fps = Std.int(value);
			}
		});
		stepper_fps.setValue(Preferences.fps);
		stepper_fps.canInteract = !Preferences.vsync;
		list.push(stepper_fps);
		add(stepper_fps);

		#if !android
		var checkbox_borderless = new CheckboxOption(400, 400, {
			name: LanguageManager.getTextString('settings_window_borderless'),
			description: LanguageManager.getTextString('settings_window_borderless_description'),
			callback: function(value:Bool)
			{
				Preferences.borderless = value;

				#if !mac
				checkbox_darkMode.canInteract = !value;
				#end
			}
		});
		checkbox_borderless.setChecked(Preferences.borderless, false, true);
		list.push(checkbox_borderless);
		add(checkbox_borderless);
		#end

		var checkbox_vsync = new CheckboxOption(400, #if android 400 #else 500 #end, {
			name: LanguageManager.getTextString('settings_window_VSync'),
			description: LanguageManager.getTextString('settings_window_VSync_description'),
			callback: function(value:Bool)
			{
				Preferences.vsync = value;
				stepper_fps.canInteract = !value;
			}
		});
		checkbox_vsync.setChecked(Preferences.vsync, false, true);
		list.push(checkbox_vsync);
		add(checkbox_vsync);

		// Make sure this gets added last so it fits last in the group.
		#if (!mac && !mobile)
		list.push(checkbox_darkMode);
		add(checkbox_darkMode);
		#end
	}
	
	override function getName():String
	{
		return LanguageManager.getTextString('settings_category_window');
	}
}