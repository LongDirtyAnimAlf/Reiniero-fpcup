unit m_any_to_freebsdx64;

{ Cross compiles from e.g. Linux 64 bit (or any other OS with relevant binutils/libs) to FreeBSD x86_64
Copyright (C) 2014 Reinier Olislagers

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

const
  MAXFREEBSDVERSION=13;
  MINFREEBSDVERSION=6;

implementation

uses
  FileUtil, m_crossinstaller;

type

{ Tany_freebsdx64 }
Tany_freebsdx64 = class(TCrossInstaller)
private
  FAlreadyWarned: boolean; //did we warn user about errors and fixes already?
public
  function GetLibs(Basepath:string):boolean;override;
  {$ifndef FPCONLY}
  function GetLibsLCL(LCL_Platform:string; Basepath:string):boolean;override;
  {$endif}
  function GetBinUtils(Basepath:string):boolean;override;
  constructor Create;
  destructor Destroy; override;
end;

{ Tany_freebsdx64 }

function Tany_freebsdx64.GetLibs(Basepath:string): boolean;
var
  aVersion:integer;
begin
  result:=FLibsFound;
  if result then exit;

  // begin simple: check presence of library file in basedir
  result:=SearchLibrary(Basepath,LIBCNAME);

  // first search local paths based on libbraries provided for or adviced by fpc itself
  if not result then
    result:=SimpleSearchLibrary(BasePath,DirName,LIBCNAME);

  if not result then
  begin
    // look for versioned libraries
    for aVersion:=13 downto 7 do
    begin
      result:=SimpleSearchLibrary(BasePath,DirName+InttoStr(aVersion),LIBCNAME);
      if result then break;
    end;
  end;

  if not result then
  begin
    {$IFDEF UNIX}
    FLibsPath:='/usr/lib/x86_64-freebsd-gnu'; //debian Jessie+ convention
    result:=DirectoryExists(FLibsPath);
    if not result then
    ShowInfo('Searched but not found libspath '+FLibsPath);
    {$ENDIF}
  end;

  SearchLibraryInfo(result);
  if result then
  begin
    FLibsFound:=True;
    AddFPCCFGSnippet('-Xd'); {buildfaq 3.4.1 do not pass parent /lib etc dir to linker}
    AddFPCCFGSnippet('-Fl'+IncludeTrailingPathDelimiter(FLibsPath)); {buildfaq 1.6.4/3.3.1: the directory to look for the target  libraries}
    //AddFPCCFGSnippet('-XR'+ExcludeTrailingPathDelimiter(FLibsPath)); {buildfaq 1.6.4/3.3.1: the directory to look for the target libraries ... just te be safe ...}
    AddFPCCFGSnippet('-Xr/usr/lib');
  end;
end;

{$ifndef FPCONLY}
function Tany_freebsdx64.GetLibsLCL(LCL_Platform: string; Basepath: string): boolean;
begin
  // todo: get gtk at least
  result:=inherited;
end;
{$endif}

function Tany_freebsdx64.GetBinUtils(Basepath:string): boolean;
var
  AsFile: string;
  AsDirectory: string;
  BinPrefixTry: string;
  i:integer;
begin
  result:=inherited;
  if result then exit;

  AsFile:=FBinUtilsPrefix+'as'+GetExeExt;

  result:=SearchBinUtil(BasePath,AsFile);
  if not result then
    result:=SimpleSearchBinUtil(BasePath,DirName,AsFile);

  if not result then
  begin
    // look for versioned binutils
    BinPrefixTry:=FBinUtilsPrefix;
    SetLength(BinPrefixTry,Length(BinPrefixTry)-1);
    for i:=MAXFREEBSDVERSION downto MINFREEBSDVERSION do
    begin
      AsFile:=BinPrefixTry+InttoStr(i)+'-'+'as'+GetExeExt;
      result:=SearchBinUtil(BasePath,AsFile);
      if not result then
        result:=SimpleSearchBinUtil(BasePath,DirName,AsFile);
      if result then
      begin
        FBinUtilsPrefix:=BinPrefixTry+InttoStr(i)+'-';
        break;
      end;
    end;
  end;

  if not result then
  begin
    // look for binutils in versioned directories
    AsFile:=FBinUtilsPrefix+'as'+GetExeExt;
    i:=MAXFREEBSDVERSION;
    while (i>=MINFREEBSDVERSION) do
    begin
      if i=MINFREEBSDVERSION then
        AsDirectory:=DirName
      else
        AsDirectory:=DirName+InttoStr(i);
      result:=SimpleSearchBinUtil(BasePath,AsDirectory,AsFile);
      if not result then
      begin
        // Also allow for (cross)binutils without prefix
        result:=SimpleSearchBinUtil(BasePath,AsDirectory,'as'+GetExeExt);
        if result then FBinUtilsPrefix:=''
      end;
      if result then break;
      Dec(i);
    end;
  end;

  SearchBinUtilsInfo(result);

  if result then
  begin
    FBinsFound:=true;
    // Configuration snippet for FPC
    AddFPCCFGSnippet('-FD'+IncludeTrailingPathDelimiter(FBinUtilsPath)); {search this directory for compiler utilities}
    AddFPCCFGSnippet('-XP'+FBinUtilsPrefix); {Prepend the binutils names}
  end;
end;

constructor Tany_freebsdx64.Create;
begin
  inherited Create;
  FTargetCPU:=TCPU.x86_64;
  FTargetOS:=TOS.freebsd;
  Reset;
  FAlreadyWarned:=false;
  ShowInfo;
end;

destructor Tany_freebsdx64.Destroy;
begin
  inherited Destroy;
end;

var
  any_freebsdx64:Tany_freebsdx64;

initialization
  any_freebsdx64:=Tany_freebsdx64.Create;
  RegisterCrossCompiler(any_freebsdx64.RegisterName,any_freebsdx64);

finalization
  any_freebsdx64.Destroy;

end.

