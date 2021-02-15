unit m_any_to_aixpowerpc;
{ Cross compiles from any platform with correct binutils to AIX on 32 bit powerpc
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

{
Setup: currently aimed at using the crossfpc supplied binaries/libs
See
https://wiki.lazarus.freepascal.org/FPC_AIX_Port
- Get Windows binutils from ftp://ftp.freepascal.org/pub/fpc/contrib/aix/fpc-2.7.1.powerpc-aix-win32.zip
powerpc-aix-ar.exe
powerpc-aix-as.exe
powerpc-aix-ld.exe
powerpc-aix-nm.exe
powerpc-aix-strip.exe

- *nix: compile cross binutils yourself; see wiki page above
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

implementation

uses
  FileUtil, m_crossinstaller;

type

{ TAny_AIXPowerPC }
TAny_AIXPowerPC = class(TCrossInstaller)
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

{ TAny_AIXPowerPC }

function TAny_AIXPowerPC.GetLibs(Basepath:string): boolean;
const
  StaticLibName='libc.a';
begin
  result:=FLibsFound;

  if result then exit;

  // begin simple: check presence of library file in basedir
  result:=SearchLibrary(Basepath,LIBCNAME);
  // search local paths based on libbraries provided for or adviced by fpc itself
  if not result then
    result:=SimpleSearchLibrary(BasePath,DirName,LIBCNAME);

  // do the same as above, but look for a static lib
  result:=SearchLibrary(Basepath,StaticLibName);
  // search local paths based on libbraries provided for or adviced by fpc itself
  if not result then
    result:=SimpleSearchLibrary(BasePath,DirName,StaticLibName);

  if result then
  begin
    FLibsFound:=true;

    AddFPCCFGSnippet('-Xd'); {buildfaq 3.4.1 do not pass parent /lib etc dir to linker}
    AddFPCCFGSnippet('-Fl'+IncludeTrailingPathDelimiter(FLibsPath)); {buildfaq 1.6.4/3.3.1: the directory to look for the target  libraries}
    // http://wiki.freepascal.org/FPC_AIX_Port#Cross-compiling
    AddFPCCFGSnippet('-XR'+ExcludeTrailingPathDelimiter(FLibsPath)); {buildfaq 1.6.4/3.3.1: the directory to look for the target  libraries}
    AddFPCCFGSnippet('-Xr/usr/lib'); {buildfaq 3.3.1: makes the linker create the binary so that it searches in the specified directory on the target system for libraries}

    FCrossOpts.Add('-XR'+ExcludeTrailingPathDelimiter(FLibsPath)+' ');

    SearchLibraryInfo(result);
  end
  else
  begin
    //libs path is optional; it can be empty
    ShowInfo('Libspath ignored; it is optional for this cross compiler.');
    FLibsPath:='';
    result:=true;
  end;
  FLibsFound:=True;
end;

{$ifndef FPCONLY}
function TAny_AIXPowerPC.GetLibsLCL(LCL_Platform: string; Basepath: string): boolean;
begin
  // todo: get gtk at least, add to FFPCCFGSnippet
  ShowInfo('Implement lcl libs path from basepath '+BasePath+' for platform '+LCL_Platform,etdebug);
  result:=inherited;
end;
{$endif}

function TAny_AIXPowerPC.GetBinUtils(Basepath:string): boolean;
var
  AsFile: string;
  BinPrefixTry: string;
begin
  result:=inherited;
  if result then exit;

  // Start with any names user may have given
  AsFile:=FBinUtilsPrefix+'as'+GetExeExt;

  result:=SearchBinUtil(BasePath,AsFile);
  if not result then
    result:=SimpleSearchBinUtil(BasePath,DirName,AsFile);

  // Also allow for crossbinutils without prefix
  if not result then
  begin
    BinPrefixTry:='';
    AsFile:=BinPrefixTry+'as'+GetExeExt;
    result:=SearchBinUtil(BasePath,AsFile);
    if not result then result:=SimpleSearchBinUtil(BasePath,DirName,AsFile);
    if result then FBinUtilsPrefix:=BinPrefixTry;
  end;

  SearchBinUtilsInfo(result);

  if (not result) then
  begin
    ShowInfo('Suggestion for cross binutils: please check http://wiki.lazarus.freepascal.org/FPC_AIX_Port.',etInfo);
    FAlreadyWarned:=true;
  end
  else
  begin
    FBinsFound:=true;
    // Configuration snippet for FPC
    AddFPCCFGSnippet('-FD'+IncludeTrailingPathDelimiter(FBinUtilsPath)); {search this directory for compiler utilities}
    AddFPCCFGSnippet('-XP'+FBinUtilsPrefix); {Prepend the binutils names}
  end;
end;

constructor TAny_AIXPowerPC.Create;
begin
  inherited Create;
  FTargetCPU:=TCPU.powerpc;
  FTargetOS:=TOS.aix;
  Reset;
  FAlreadyWarned:=false;
  ShowInfo;
end;

destructor TAny_AIXPowerPC.Destroy;
begin
  inherited Destroy;
end;

var
  Any_AIXPowerPC:TAny_AIXPowerPC;

initialization
  Any_AIXPowerPC:=TAny_AIXPowerPC.Create;
  RegisterCrossCompiler(Any_AIXPowerPC.RegisterName,Any_AIXPowerPC);
finalization
  Any_AIXPowerPC.Destroy;
end.

