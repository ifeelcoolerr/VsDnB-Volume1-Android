package ui;

import backend.Conductor;
import controls.Controls;
import controls.PlayerSettings;
import data.song.SongData.SongTimeChange;
import flixel.FlxG;
import scripting.ScriptEventDispatchSubState;
import scripting.events.ScriptEvent;
import scripting.module.ModuleHandler;
import util.SortUtil;
#if mobileC
import mobile.flixel.FlxVirtualPad;
import flixel.FlxCamera;
import graphics.GameCamera;
import flixel.input.actions.FlxActionInput;
import flixel.util.FlxDestroyUtil;
#end

/**
 * An `FlxSubState` linked to the Conductor to allow for bpm synced events such as step, beat, and measure hit events, and more.
 */
class MusicBeatSubstate extends ScriptEventDispatchSubState
{
	/**
	 * The current step of the Conductor.
	 */
	private var curStep(get, never):Int;

	function get_curStep():Int
		return Conductor.instance.curStep;

	/**
	 * The current beat of the Conductor.
	 */
	private var curBeat(get, never):Int;

	function get_curBeat():Int
		return Conductor.instance.curBeat;

	/**
	 * The current measure of the Conductor.
	 */
	private var curMeasure(get, never):Int;

	function get_curMeasure():Int
		return Conductor.instance.curMeasure;

	/**
	 * Alias for the user's controls.
	 */
	private var controls(get, never):Controls;

	inline function get_controls():Controls
		return PlayerSettings.controls;

	#if mobileC
	var virtualPad:FlxVirtualPad;
	var trackedInputsVirtualPad:Array<FlxActionInput> = [];

	public function addVirtualPad(DPad:FlxDPadMode, Action:FlxActionMode):Void
	{
		if (virtualPad != null)
			removeVirtualPad();

		virtualPad = new FlxVirtualPad(DPad, Action);
		add(virtualPad);

		controls.setVirtualPadUI(virtualPad, DPad, Action);
		trackedInputsVirtualPad = controls.trackedInputsUI;
		controls.trackedInputsUI = [];
	}

	public function removeVirtualPad():Void
	{
		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);

		if (virtualPad != null)
			remove(virtualPad);
	}

	public function addVirtualPadCamera():Void
	{
    	if (virtualPad != null)
    	{
        	var camVirtualPad:GameCamera = new GameCamera();
        	camVirtualPad.bgColor = 0x00000000;

        	FlxG.cameras.add(camVirtualPad, false);

       		camVirtualPad.follow(null);
        	camVirtualPad.scroll.set(0, 0);

        	virtualPad.cameras = [camVirtualPad];
    	}
	}
	#end


	override function create()
	{
		addSignals();

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		dispatchEvent(new UpdateScriptEvent(elapsed));
	}

	public function fancyOpenURL(schmancy:String)
	{
		#if linux
		Sys.command('/usr/bin/xdg-open', [schmancy, "&"]);
		#else
		FlxG.openURL(schmancy);
		#end
	}

	override function destroy()
	{
		removeSignals();

		#if mobileC
		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);
		#end

		super.destroy();

		#if mobileC
		if (virtualPad != null)
			virtualPad = FlxDestroyUtil.destroy(virtualPad);
		#end
	}

	/**
	 * Calls a script event to the given script functions.
	 * @param event The script event to dispatch.
	 */
	override function dispatchEvent(event:ScriptEvent)
	{
		ModuleHandler.callEvent(event);
	}
	
	function addSignals():Void
	{
		Conductor.instance.onStepHit.add(stepHit);
		Conductor.instance.onBeatHit.add(beatHit);
		Conductor.instance.onMeasureHit.add(measureHit);
		Conductor.instance.onTimeChangeHit.add(timeChange);
	}
	
	function removeSignals():Void
	{
		Conductor.instance.onStepHit.remove(stepHit);
		Conductor.instance.onBeatHit.remove(beatHit);
		Conductor.instance.onMeasureHit.remove(measureHit);
		Conductor.instance.onTimeChangeHit.remove(timeChange);
	}

	public function stepHit(step:Int):Bool
	{
		var event = new ConductorScriptEvent(STEP_HIT, step, curBeat, curMeasure, Conductor.instance.currentTimeChange);
		dispatchEvent(event);
		
		if (event.eventCanceled) 
			return false;

		return true;
	}

	public function beatHit(beat:Int):Bool
	{
		var event = new ConductorScriptEvent(BEAT_HIT, curStep, beat, curMeasure, Conductor.instance.currentTimeChange);
		dispatchEvent(event);

		if (event.eventCanceled) 
			return false;

		return true;
	}

	public function measureHit(measure:Int):Bool 
	{
		var event = new ConductorScriptEvent(MEASURE_HIT, curStep, curBeat, measure, Conductor.instance.currentTimeChange);
		dispatchEvent(event);

		if (event.eventCanceled) 
			return false;

		return true;
	}

	public function timeChange(timeChange:SongTimeChange):Bool
	{
		var event = new ConductorScriptEvent(TIME_CHANGE_HIT, curStep, curBeat, curMeasure, timeChange);
		dispatchEvent(event);

		if (event.eventCanceled) 
			return false;

		return true;
	}

	public function refresh():Void
	{
		sort(SortUtil.byZIndex);
	}
}
