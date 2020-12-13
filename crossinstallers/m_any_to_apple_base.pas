unit m_any_to_apple_base;

{ Cross compiles to Apple systems
Copyright (C) 2014 Reinier Olislagers / DonAlfredo

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
  Classes, SysUtils, m_crossinstaller;

type
  { Tany_apple }
  Tany_apple = class(TCrossInstaller)
  private
    FAlreadyWarned: boolean; //did we warn user about errors and fixes already?
  protected
    function GetOSName:string;virtual;abstract;
    function GetLibName:string;virtual;abstract;
    function GetTDBLibName:string;virtual;abstract;
  public
    function GetLibs(Basepath:string):boolean;override;
    function GetBinUtils(Basepath:string):boolean;override;
    constructor Create;
    destructor Destroy; override;
    property OSName:string read GetOSName;
    property LibName:string read GetLibName;
    property TDBLibName:string read GetTDBLibName;
  end;


implementation

uses
  FileUtil, fpcuputil;

{ Tany_apple }

function Tany_apple.GetLibs(Basepath:string): boolean;
var
  s:string;
  SDKVersion:string;
  Major,Minor,Release:integer;
  found:boolean;
begin
  result:=FLibsFound;

  if result then exit;

  found:=false;

  // begin simple: check presence of library file in basedir
  if not result then
    result:=SearchLibrary(Basepath,LibName);
  if not result then
    result:=SearchLibrary(Basepath,TDBLibName);

  if not result then
    result:=SearchLibrary(IncludeTrailingPathDelimiter(Basepath)+'usr'+DirectorySeparator+'lib',LibName);
  if not result then
    result:=SearchLibrary(IncludeTrailingPathDelimiter(Basepath)+'usr'+DirectorySeparator+'lib',TDBLibName);

  if not result then
    result:=SimpleSearchLibrary(BasePath,DirName,LibName);
  if not result then
    result:=SimpleSearchLibrary(BasePath,DirName,TDBLibName);

  // also for cctools or special fpcupdeluxe tools
  if not result then
  begin
    for Major:=MAXOSVERSION downto MINOSVERSION do
    begin
      if found then break;

      for Minor:=16 downto -1 do
      begin
        if found then break;

        if (TargetOS=TOS.darwin) then
        begin
          if (Major>11) then continue;
          if (Major=11) and (Minor>5) then continue;
          if (Major<10) then continue;

          if (TargetCPU=TCPU.i386) then
          begin
            if (Major>10) then continue;
            if (Major=10) and (Minor>13) then continue;
          end;

          if (TargetCPU in [TCPU.powerpc,TCPU.powerpc64]) then
          begin
            if (Major>10) then continue;
            if (Major=10) and (Minor>5) then continue;
          end;
        end;

        for Release:=15 downto -1 do
        begin
          if found then break;
          s:=InttoStr(Major);
          if Minor<>-1 then
          begin
            s:=s+'.'+InttoStr(Minor);
            if Release<>-1 then s:=s+'.'+InttoStr(Release);
          end;
          SDKVersion:=s;

          s:=ConcatPaths([DirName,OSNAME+SDKVersion+'.sdk','usr','lib']);
          result:=SimpleSearchLibrary(BasePath,s,LibName);
          if not result then
             result:=SimpleSearchLibrary(BasePath,s,TDBLibName);

          // universal libs : also search in x86-targetos if suitable
          if (not result) then
          begin
            if (TargetCPU in [TCPU.x86_64,TCPU.i386]) then
            begin
              s:=ConcatPaths(['x86-'+TargetOSName,OSNAME+SDKVersion+'.sdk','usr','lib']);
              result:=SimpleSearchLibrary(BasePath,s,LibName);
              if not result then
                 result:=SimpleSearchLibrary(BasePath,s,TDBLibName);
            end;
          end;

          // universal libs : also search in powerpc-targetos if suitable
          if (not result) then
          begin
            if (TargetCPU in [TCPU.powerpc64,TCPU.powerpc]) then
            begin
              s:=ConcatPaths(['powerpc-'+TargetOSName,OSNAME+SDKVersion+'.sdk','usr','lib']);
              result:=SimpleSearchLibrary(BasePath,s,LibName);
              if not result then
                 result:=SimpleSearchLibrary(BasePath,s,TDBLibName);
            end;
          end;

          // universal libs : also search in all-targetos
          if (not result) then
          begin
            if (TargetOS in [TOS.darwin,TOS.ios]) then
            begin
              s:=ConcatPaths(['all-'+TargetOSName,OSNAME+SDKVersion+'.sdk','usr','lib']);
              result:=SimpleSearchLibrary(BasePath,s,LibName);
              if not result then
                 result:=SimpleSearchLibrary(BasePath,s,TDBLibName);
            end;
          end;
          if result then found:=true;
        end;
      end;
    end;
  end;

  if not result then
  begin
    {$IFDEF UNIX}
    FLibsPath:='/usr/lib/'+RegisterName+'-gnu'; //debian Jessie+ convention
    result:=DirectoryExists(FLibsPath);
    if not result then
    ShowInfo('Searched but not found libspath '+FLibsPath);
    {$ENDIF}
  end;

  SearchLibraryInfo(result);

  if result then
  begin
    FLibsFound:=True;
    AddFPCCFGSnippet('-Fl'+IncludeTrailingPathDelimiter(FLibsPath));

    s:=IncludeTrailingPathDelimiter(FLibsPath)+'..'+DirectorySeparator+'..'+DirectorySeparator;
    s:=ExpandFileName(s);
    s:=ExcludeTrailingBackslash(s);

    AddFPCCFGSnippet('-Fl'+IncludeTrailingPathDelimiter(FLibsPath)+'system'+DirectorySeparator);
    AddFPCCFGSnippet('-k-framework -kAppKit');
    AddFPCCFGSnippet('-k-framework -kFoundation');
    AddFPCCFGSnippet('-k-framework -kCoreFoundation');
    AddFPCCFGSnippet('-Xd');
    AddFPCCFGSnippet('-XR'+s);

    if ((TargetCPU=TCPU.powerpc) OR (TargetCPU=TCPU.powerpc64)) then
    begin
      AddFPCCFGSnippet('-k-framework -kApplicationServices');
      AddFPCCFGSnippet('-k-syslibroot -k'+s);
      if TargetCPU=TCPU.powerpc64 then
        AddFPCCFGSnippet('-k-arch -kppc64');
      if TargetCPU=TCPU.powerpc then
        AddFPCCFGSnippet('-k-arch -kppc');
    end;

  end
  else
  begin
    ShowInfo('Hint: https://github.com/phracker/MacOSX-SDKs');
    ShowInfo('Hint: https://github.com/alexey-lysiuk/macos-sdk');
    ShowInfo('Hint: https://github.com/sirgreyhat/MacOSX-SDKs/releases');
  end;
end;

function Tany_apple.GetBinUtils(Basepath:string): boolean;
var
  AsFile: string;
  i,DarwinRelease:integer;
  //S,PresetBinPath: string;
begin
  result:=inherited;

  if result then exit;

  if not result then
  begin
    if (TargetOS in [TOS.darwin,TOS.ios]) AND (NOT (TargetCPU in [TCPU.powerpc64,TCPU.powerpc])) then
    begin
      // Search in special Apple directory for LD
      AsFile:=LDSEARCHFILE+GetExeExt;
      result:=SimpleSearchBinUtil(BasePath,'all-apple',AsFile);
      if (NOT result) then
      begin
        AsFile:=TargetCPUName+'-w64-mingw32-'+LDSEARCHFILE+GetExeExt;
        result:=SimpleSearchBinUtil(BasePath,'all-apple',AsFile);
      end;
    end;
  end;
  if not result then
  begin
    // Search in special all-targetos directory
    AsFile:=SEARCHFILE+GetExeExt;
    result:=SimpleSearchBinUtil(BasePath,'all-'+TargetOSName,AsFile);
  end;

  // Now start with the normal search sequence
  if not result then
  begin
    AsFile:=BinUtilsPrefix+SEARCHFILE+GetExeExt;
    result:=SearchBinUtil(BasePath,AsFile);
    if not result then
      result:=SimpleSearchBinUtil(BasePath,DirName,AsFile);
  end;

  // See https://en.wikipedia.org/wiki/Darwin_%28operating_system%29#Release_history
  // Shows relation between macOS and Darwin versions

  for DarwinRelease:=MAXDARWINVERSION downto MINDARWINVERSION do
  begin
    if not result then
    begin
      if DarwinRelease=MINDARWINVERSION then
        AsFile:=BinUtilsPrefix
      else
        AsFile:=StringReplace(BinUtilsPrefix,TargetOSName,TargetOSName+InttoStr(DarwinRelease),[]);
      AsFile:=AsFile+SEARCHFILE+GetExeExt;
      result:=SearchBinUtil(BasePath,AsFile);
      if not result then
        result:=SimpleSearchBinUtil(BasePath,DirName,AsFile);

      // Look in special all-directory
      if not result then
        result:=SimpleSearchBinUtil(BasePath,'all-'+TargetOSName,AsFile);

      if not result then
      begin
        // Look in special x86-directory
        if (TargetCPU in [TCPU.x86_64,TCPU.i386]) then
        begin
          result:=SimpleSearchBinUtil(BasePath,'x86-'+TargetOSName,AsFile);
        end;
      end;

      if not result then
      begin
        // Look in special ppc-directory for universal named powerpc tools
        if (TargetCPU in [TCPU.powerpc64,TCPU.powerpc]) then
        begin
          AsFile:=StringReplace(AsFile,TargetCPUName,'powerpc',[]);
          result:=SimpleSearchBinUtil(BasePath,'powerpc-'+TargetOSName,AsFile);
        end;
      end;

      if result then break;
    end;
  end;


  (*
  if (not result) then
  begin
    // do a brute force search of correct binutils
    PresetBinPath:=ConcatPaths([BasePath,CROSSPATH,'bin',TargetCPUName+'-'+TargetOSName]);
    if DirectoryExists(PresetBinPath) then
    begin
      for DarwinRelease:=MAXDARWINVERSION downto MINDARWINVERSION do
      begin
        if DarwinRelease=MINDARWINVERSION then
          AsFile:=BinUtilsPrefix
        else
          AsFile:=StringReplace(BinUtilsPrefix,TargetOSName,TargetOSName+InttoStr(DarwinRelease),[]);
        AsFile:=AsFile+SEARCHFILE+GetExeExt;
        S:=FindFileInDir(AsFile,PresetBinPath);
        if (Length(S)>0) then
        begin
          PresetBinPath:=ExtractFilePath(S);
          result:=SearchBinUtil(PresetBinPath,AsFile);
          if result then break;
        end;
      end;
    end;
    PresetBinPath:=ConcatPaths([BasePath,CROSSPATH,'bin','all-'+TargetOSName]);
    if DirectoryExists(PresetBinPath) then
    begin
      for DarwinRelease:=MAXDARWINVERSION downto MINDARWINVERSION do
      begin
        if DarwinRelease=MINDARWINVERSION then
          AsFile:=BinUtilsPrefix
        else
          AsFile:=StringReplace(BinUtilsPrefix,TargetOSName,TargetOSName+InttoStr(DarwinRelease),[]);
        AsFile:=AsFile+SEARCHFILE+GetExeExt;
        S:=FindFileInDir(AsFile,PresetBinPath);
        if (Length(S)>0) then
        begin
          PresetBinPath:=ExtractFilePath(S);
          result:=SearchBinUtil(PresetBinPath,AsFile);
          if result then break;
        end;
      end;
    end;
  end;
  *)

  if result then
  begin
    // Remove the searchfile itself to get the binutils prefix
    i:=Pos(SEARCHFILE+GetExeExt,AsFile);
    if i<1 then i:=Pos(LDSEARCHFILE+GetExeExt,AsFile);
    if i>0 then
    begin
      Delete(AsFile,i,MaxInt);
      FBinUtilsPrefix:=AsFile;
    end;
  end;

  SearchBinUtilsInfo(result);

  if result then
  begin
    FBinsFound:=true;
    // Configuration snippet for FPC
    AddFPCCFGSnippet('-FD'+IncludeTrailingPathDelimiter(FBinUtilsPath)); {search this directory for compiler utilities}
    AddFPCCFGSnippet('-XX');
    AddFPCCFGSnippet('-XP'+FBinUtilsPrefix); {Prepend the binutils names};
  end;
end;

constructor Tany_apple.Create;
begin
  inherited Create;
  FBinutilsPathInPath:=true;
  FAlreadyWarned:=false;
end;

destructor Tany_apple.Destroy;
begin
  inherited Destroy;
end;

end.

