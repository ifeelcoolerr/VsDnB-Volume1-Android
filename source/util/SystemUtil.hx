package util;

// crazy system shit!!!!!
// lordryan wrote this :) (erizur added cross platform env vars)
import sys.io.File;
#if android
import util.AndroidUtil;
#end

class SystemUtil
{
	/**
	 * Gets the user's windows platform username.
	 * @return The platform username.
	 */
	public static function getUsername():String
	{
		// uhh this one is self explanatory
		#if windows
		return Sys.getEnv("USERNAME");
		#else
		return Sys.getEnv("USER");
		#end
	}

	/**
	 * Gets the path to the 'Users' folder.
	 * @return A string representing the path to the 'Users' folder.
	 */
	public static function getUserPath():String
	{
		#if windows
		return Sys.getEnv("USERPROFILE");
		#else
		return Sys.getEnv("HOME");
		#end
	}

	/**
	 * Gets the location of the 'TEMP' folder.
	 * @return A string containing the path to the 'TEMP' folder.
	 */
	public static function getTempPath():String
	{
		// gets appdata temp folder lol
		#if windows
		return Sys.getEnv("TEMP");
		#else
		// most non-windows os dont have a temp path, or if they do its not 100% compatible, so the user folder will be a fallback
		return Sys.getEnv("HOME");
		#end
	}

	/**
	 * Gets the file name of the executable. 
	 * @return The name of the executable.
	 */
	public static function executableFileName():String
	{
		#if windows
		var programPath = Sys.programPath().split("\\");
		#else
		var programPath = Sys.programPath().split("/");
		#end
		return programPath[programPath.length - 1];
	}

	/**
     * Generates a text file, puts it in the temp folder, and opens it.
     * @param fileContent The content of the file.
     * @param fileName The name of the file.
     */
    public static function generateTextFile(fileContent:String, fileName:String)
	{
		#if desktop
		var path = SystemUtil.getTempPath() + "/" + fileName + ".txt";

		#if desktop
		File.saveContent(path, fileContent);
		#else
		SUtil.saveContent(path, fileContent);
		#end
		
        FileUtil.openFile(path);
		#end
	}
}
