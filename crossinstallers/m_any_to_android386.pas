unit m_any_to_android386;
{ Cross compiles from any platform (with supported crossbin utils0 to Android AMD 64 bit (x64)
Copyright (C) 2013 Reinier Olislagers

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Library General Public License as published by
the Free Software Foundation; either version 2 of the License, or (at your
option) any later version with the following modification:

As a special exception, the copyright holders of this library give you
permission to link this library with independent modules to produce an
executable, regardless of the license terms of these independent modules,and
to copy and distribute the resulting executable under terms of your choice,
provided that you also meet, for each linked independent module, the terms
and conditions of the license of that module. An independent module is a
module which is not derived from or based on this library. If you modify
this library, you may extend this exception to your version of the library,
but you are not obligated to do so. If you do not wish to do so, delete this
exception statement from your version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU Library General Public License
for more details.

You should have received a copy of the GNU Library General Public License
along with this library; if not, write to the Free Software Foundation,
Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

implementation

uses
  StrUtils,
  {$IFDEF UNIX}
  baseunix,
  {$ENDIF}
  FileUtil, m_crossinstaller, fpcuputil;

const
  ARCH='i386';
  ARCHSHORT='x86';
  OS='android';
  NDKVERSIONBASENAME=OS+'-ndk-r';
  NDKTOOLCHAINVERSIONS:array[0..0] of string = (ARCH+'-4.9');
  NDKARCHDIRNAME='arch-'+ARCHSHORT;
  PLATFORMVERSIONBASENAME=OS+'-';

type

{ TAny_Android386 }
TAny_Android386 = class(TCrossInstaller)
private
  FAlreadyWarned: boolean; //did we warn user about errors and fixes already?
public
  function GetLibs(Basepath:string):boolean;override;
  function GetBinUtils(Basepath:string):boolean;override;
  constructor Create;
  destructor Destroy; override;
end;

{ TAny_Android386 }

function TAny_Android386.GetLibs(Basepath:string): boolean;
  // we presume, libc.so has to be present in a cross-library for arm
  // we presume, libandroid.so has to be present in a cross-library for arm
  //LibName='libandroid.so';
var
  delphiversion,ndkversion,platform:byte;
  PresetLibPath:string;
begin
  result:=FLibsFound;

  if result then exit;

  // begin simple: check presence of library file in basedir
  result:=SearchLibrary(Basepath,LIBCNAME);

  // if binaries already found, search for library belonging to these binaries !!
  if (not result) AND (Length(FBinUtilsPath)>0) AND (SearchModeUsed=TSearchSetting.ssAuto) then
  begin
    ndkversion:=Pos(NDKVERSIONBASENAME,FBinUtilsPath);
    if ndkversion>0 then
    begin
      ndkversion:=PosEx(DirectorySeparator,FBinUtilsPath,ndkversion);
      if ndkversion>0 then
      begin
        PresetLibPath:=LeftStr(FBinUtilsPath,ndkversion);
        for platform:=High(PLATFORMVERSIONSNUMBERS) downto Low(PLATFORMVERSIONSNUMBERS) do
        begin
          FLibsPath := ConcatPaths([PresetLibPath,'platforms',PLATFORMVERSIONBASENAME + InttoStr(PLATFORMVERSIONSNUMBERS[platform]),NDKARCHDIRNAME,'usr','lib']);
          result:=DirectoryExists(FLibsPath);
          if not result
             then ShowInfo('Searched but not found: libspath '+FLibsPath,etDebug)
             else break;
        end;
      end;
    end;
  end;

  // first search local paths based on libbraries provided for or adviced by fpc itself
  if not result then
    result:=SimpleSearchLibrary(BasePath,DirName,LIBCNAME);

  // search for a library provide by a standard android libraries install

  //C:\Users\<username>\AppData\Local\Android\sdk

  if (not result) AND (SearchModeUsed=TSearchSetting.ssAuto) then
  begin
    for ndkversion:=High(NDKVERSIONNAMES) downto Low(NDKVERSIONNAMES) do
    begin
      if not result then
      begin
        for platform:=High(PLATFORMVERSIONSNUMBERS) downto Low(PLATFORMVERSIONSNUMBERS) do
        begin
          // check libs in userdir\

          FLibsPath := ConcatPaths([GetUserDir,NDKVERSIONBASENAME+NDKVERSIONNAMES[ndkversion],'platforms',PLATFORMVERSIONBASENAME + InttoStr(PLATFORMVERSIONSNUMBERS[platform]),NDKARCHDIRNAME,'usr','lib']);
          result:=DirectoryExists(FLibsPath);
          if not result then
          begin
            ShowInfo('Searched but not found libspath '+FLibsPath,etDebug)
          end else break;
          // check libs in userdir\Andoid
          FLibsPath := ConcatPaths([GetUserDir,UppercaseFirstChar(OS),NDKVERSIONBASENAME+NDKVERSIONNAMES[ndkversion],'platforms',PLATFORMVERSIONBASENAME + InttoStr(PLATFORMVERSIONSNUMBERS[platform]),NDKARCHDIRNAME,'usr','lib']);
          result:=DirectoryExists(FLibsPath);
          if not result then
          begin
            ShowInfo('Searched but not found libspath '+FLibsPath,etDebug)
          end else break;
          // check libs in userdir\AppData\Local\Andoid
          FLibsPath := ConcatPaths([GetUserDir,'AppData','Local',UppercaseFirstChar(OS),NDKVERSIONBASENAME+NDKVERSIONNAMES[ndkversion],'platforms',PLATFORMVERSIONBASENAME + InttoStr(PLATFORMVERSIONSNUMBERS[platform]),NDKARCHDIRNAME,'usr','lib']);
          result:=DirectoryExists(FLibsPath);
          if not result then
          begin
            ShowInfo('Searched but not found libspath '+FLibsPath,etDebug)
          end else break;

        end;
      end else break;
    end;
  end;

  {$IFDEF MSWINDOWS}
  // find Delphi android libs
  if (not result) AND (SearchModeUsed=TSearchSetting.ssAuto) then
  begin
    ShowInfo('Searched but not found libspath '+FLibsPath,etDebug);
    for delphiversion:=MAXDELPHIVERSION downto MINDELPHIVERSION do
    begin
      if not result then
      begin
        for ndkversion:=High(NDKVERSIONNAMES) downto Low(NDKVERSIONNAMES) do
        begin
          if not result then
          begin
            for platform:=High(PLATFORMVERSIONSNUMBERS) downto Low(PLATFORMVERSIONSNUMBERS) do
            begin
              FLibsPath:='C:\Users\Public\Documents\Embarcadero\Studio\'+InttoStr(delphiversion)+
              '.0\PlatformSDKs\'+NDKVERSIONBASENAME+NDKVERSIONNAMES[ndkversion]+'\platforms\'+PLATFORMVERSIONBASENAME + InttoStr(PLATFORMVERSIONSNUMBERS[platform])+'\'+NDKARCHDIRNAME+'\usr\lib';
              result:=DirectoryExists(FLibsPath);
              if not result
                 then ShowInfo('Searched but not found libspath '+FLibsPath,etDebug)
                 else break;
            end;
          end else break;
        end;
      end else break;
    end;
  end;
  {$ENDIF}

  SearchLibraryInfo(result);

  if result then
  begin
    FLibsFound:=true;
    FFPCCFGSnippet:=FFPCCFGSnippet+LineEnding+
    '-Xd'+LineEnding+ {buildfaq 3.4.1 do not pass parent /lib etc dir to linker}
    '-Fl'+IncludeTrailingPathDelimiter(FLibsPath)+LineEnding+ {buildfaq 1.6.4/3.3.1: the directory to look for the target  libraries}
    //'-XR'+IncludeTrailingPathDelimiter(FLibsPath)+LineEnding+
    '-FLlibdl.so'; {buildfaq 3.3.1: the name of the dynamic linker on the target}
    //'-FLlibandroid.so'; {buildfaq 3.3.1: the name of the dynamic linker on the target}

    {
    //todo: check if -XR is needed for fpc root dir Prepend <x> to all linker search paths
    '-XR'+IncludeTrailingPathDelimiter(FLibsPath);
    }
    //todo: possibly adapt for android:
    //'-Xr/usr/lib'+LineEnding+ //buildfaq 3.3.1: makes the linker create the binary so that it searches in the specified directory on the target system for libraries
  end
  else
  begin
    //Infoln(FCrossModuleName + ': Please fill '+SafeExpandFileName(IncludeTrailingPathDelimiter(BasePath)+'lib'+DirectorySeparator+DirName)+
    //' with Android libs, e.g. from the Android NDK. See http://wiki.lazarus.freepascal.org/Android.'
    //,etError);
    FAlreadyWarned:=true;
  end;
end;

function TAny_Android386.GetBinUtils(Basepath:string): boolean;
var
  AsFile: string;
  PresetBinPath:string;
  ndkversion,delphiversion,toolchain:byte;
begin
  result:=inherited;
  if result then exit;

  FBinUtilsPrefix:='i686-linux-'+GetOS(TargetOS)+'-';//standard eg in Android NDK 9

  AsFile:=BinUtilsPrefix+'as'+GetExeExt;

  result:=SearchBinUtil(Basepath,AsFile);

  // if libs already found, search for binutils belonging to this lib !!
  if (not result) AND (Length(FLibsPath)>0) AND (SearchModeUsed=TSearchSetting.ssAuto) then
  begin
    ndkversion:=Pos(NDKVERSIONBASENAME,FLibsPath);
    if ndkversion>0 then
    begin
      ndkversion:=PosEx(DirectorySeparator,FLibsPath,ndkversion);
      if ndkversion>0 then
      begin
        PresetBinPath:=LeftStr(FLibsPath,ndkversion);
        for toolchain:=High(NDKTOOLCHAINVERSIONS) downto Low(NDKTOOLCHAINVERSIONS) do
        begin
          PresetBinPath:=IncludeTrailingPathDelimiter(PresetBinPath)+'toolchains'+DirectorySeparator+NDKTOOLCHAINVERSIONS[toolchain]+DirectorySeparator+'prebuilt'+DirectorySeparator;
          PresetBinPath:=IncludeTrailingPathDelimiter(PresetBinPath)+
          {$IFDEF MSWINDOWS}
          {$IFDEF CPU64}
          'windows-x86_64'+
          {$ELSE}
          'windows'+
          {$ENDIF}
          {$ENDIF}
          {$IFDEF LINUX}
          {$IFDEF CPU64}
          'linux-x86_64'+
          {$ELSE}
          'linux-x86'+
          {$ENDIF}
          {$ENDIF}
          {$IFDEF DARWIN}
          {$IFDEF CPU64}
          'darwin-x86_64'+
          {$ELSE}
          'darwin-x86'+
          {$ENDIF}
          {$ENDIF}
          DirectorySeparator+'bin';
          result:=SearchBinUtil(PresetBinPath,AsFile);
          if result then break;
        end;
      end;
    end;
  end;

  if not result then
    result:=SimpleSearchBinUtil(BasePath,DirName,AsFile);

  if (not result) AND (SearchModeUsed=TSearchSetting.ssAuto) then
  begin
    for ndkversion:=High(NDKVERSIONNAMES) downto Low(NDKVERSIONNAMES) do
    begin
      if not result then
      begin
        for toolchain:=High(NDKTOOLCHAINVERSIONS) downto Low(NDKTOOLCHAINVERSIONS) do
        begin
          PresetBinPath:=IncludeTrailingPathDelimiter(GetUserDir);
          {$IFDEF LINUX}
          if FpGetEUid=0 then PresetBinPath:='/usr/local/';
          {$ENDIF}
          PresetBinPath:=NDKVERSIONBASENAME+NDKVERSIONNAMES[ndkversion]+DirectorySeparator+'toolchains'+DirectorySeparator+NDKTOOLCHAINVERSIONS[toolchain]+DirectorySeparator+'prebuilt'+DirectorySeparator;
          PresetBinPath:=IncludeTrailingPathDelimiter(PresetBinPath)+
          {$IFDEF MSWINDOWS}
          {$IFDEF CPU64}
          'windows-x86_64'+
          {$ELSE}
          'windows'+
          {$ENDIF}
          {$ENDIF}
          {$IFDEF LINUX}
          {$IFDEF CPU64}
          'linux-x86_64'+
          {$ELSE}
          'linux-x86'+
          {$ENDIF}
          {$ENDIF}
          {$IFDEF DARWIN}
          {$IFDEF CPU64}
          'darwin-x86_64'+
          {$ELSE}
          'darwin-x86'+
          {$ENDIF}
          {$ENDIF}
          DirectorySeparator+'bin';
          result:=SearchBinUtil(PresetBinPath,AsFile);
          if result then break;
        end;
      end else break;
    end;
  end;


  {$IFDEF MSWINDOWS}
  if (not result) AND (SearchModeUsed=TSearchSetting.ssAuto) then
  begin
    for ndkversion:=High(NDKVERSIONNAMES) downto Low(NDKVERSIONNAMES) do
    begin
      if not result then
      begin
        for toolchain:=High(NDKTOOLCHAINVERSIONS) downto Low(NDKTOOLCHAINVERSIONS) do
        begin
          if not result then
          begin
            {$IFDEF CPU64}
            result:=SearchBinUtil(IncludeTrailingPathDelimiter(GetEnvironmentVariable('ProgramFiles(x86)'))+
            UppercaseFirstChar(OS)+'\'+NDKVERSIONBASENAME+NDKVERSIONNAMES[ndkversion]+'\toolchains\'+NDKTOOLCHAINVERSIONS[toolchain]+
            '\prebuilt\windows\bin',AsFile);
            if result then break else
            {$ENDIF}
            begin
              result:=SearchBinUtil(IncludeTrailingPathDelimiter(GetEnvironmentVariable('ProgramFiles'))+
              UppercaseFirstChar(OS)+'\'+NDKVERSIONBASENAME+NDKVERSIONNAMES[ndkversion]+'\toolchains\'+NDKTOOLCHAINVERSIONS[toolchain]+
              '\prebuilt\windows\bin',AsFile);
              if result then break;
            end;
          end else break;
        end;
      end else break;
    end;
  end;

  // check Delphi auto installed android libraries
  if (not result) AND (SearchModeUsed=TSearchSetting.ssAuto) then
  begin
    for delphiversion:=MAXDELPHIVERSION downto MINDELPHIVERSION do
    begin
      if not result then
      begin
        for ndkversion:=High(NDKVERSIONNAMES) downto Low(NDKVERSIONNAMES) do
        begin
          if not result then
          begin
            for toolchain:=High(NDKTOOLCHAINVERSIONS) downto Low(NDKTOOLCHAINVERSIONS) do
            begin
              if not result then
              begin
                result:=SearchBinUtil(
                'C:\Users\Public\Documents\Embarcadero\Studio\'+InttoStr(delphiversion)+
                '.0\PlatformSDKs\'+NDKVERSIONBASENAME+NDKVERSIONNAMES[ndkversion]+
                '\toolchains\'+NDKTOOLCHAINVERSIONS[toolchain]+'\prebuilt\windows\bin',AsFile);
                if result then break;
              end else break;
            end;
          end else break;
        end;
      end else break;
    end;
  end;
  {$ENDIF}

  SearchBinUtilsInfo(result);

  if result then
  begin
    FBinsFound:=true;

    // Configuration snippet for FPC
    FFPCCFGSnippet:=FFPCCFGSnippet+LineEnding+
      '-FD'+IncludeTrailingPathDelimiter(FBinUtilsPath)+LineEnding+
      '-XP'+BinUtilsPrefix; {Prepend the binutils names};
  end
  else
  begin
    FAlreadyWarned:=true;
  end;
end;

constructor TAny_Android386.Create;
begin
  inherited Create;
  FTargetCPU:=TCPU.i386;
  FTargetOS:=TOS.android;
  Reset;
  FAlreadyWarned:=false;
  ShowInfo;
end;

destructor TAny_Android386.Destroy;
begin
  inherited Destroy;
end;

var
  Any_Android386:TAny_Android386;

initialization
  Any_Android386:=TAny_Android386.Create;
  RegisterCrossCompiler(Any_Android386.RegisterName,Any_Android386);

finalization
  Any_Android386.Destroy;
end.

