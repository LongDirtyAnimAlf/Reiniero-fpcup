unit installerManager;
{ Installer state machine
Copyright (C) 2012-2014 Ludo Brands, Reinier Olislagers

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
  Classes, SysUtils,
  m_crossinstaller,
  installerCore,
  installerFpc,
  {$ifndef FPCONLY}
  installerLazarus,
  {$endif}
  installerHelp, installerUniversal,
  fpcuputil
  {$ifdef UNIX}
  ,dynlibs,Unix
  {$endif UNIX}
  ;

// These sequences determine standard installation/uninstallation order/content:
// Note that a single os/cpu/sequence combination will only be executed once (the state machine checks for this)
Const
  Sequences=
    //default sequence. Using declare makes this show up in the module list given by fpcup --help
    // If you don't want that, use DeclareHidden
    _DECLARE+_DEFAULT+_SEP+ //keyword Declare gives a name to a sequence of commands
    {$ifndef FPCONLY}
    // CheckDevLibs has stubs for anything except Linux, where it does check development library presence
    _EXECUTE+_CHECKDEVLIBS+_SEP+ //keyword Exec executes a function/procedure; must be defined in TSequencer.DoExec
    {$endif}
    _DO+_FPC+_SEP+ //keyword Do means run the specified declared sequence
    {$ifndef FPCONLY}
    _DO+_LAZARUS+_SEP+
    _DO+_LCLCROSS+_SEP+
    {$endif}
    _END+ //keyword End specifies the end of the sequence

    {$ifdef mswindows}
    {$ifdef win32}
    //default sequences for win32
    _DECLARE+_DEFAULT+'win32'+_SEP+
    {$endif win32}
    {$ifdef win64}
    _DECLARE+_DEFAULT+'win64'+_SEP+
    {$endif win64}
    _DO+_FPC+_SEP+
    _DO+_FPC+_CROSSWIN+_SEP+
    {$ifndef FPCONLY}
    _DO+_LAZARUS+_SEP+
    _DO+_LCLCROSS+_SEP+
    _DO+_LAZARUS+_CROSSWIN+_SEP+
    {$endif FPCONLY}
    _END+
    {$endif mswindows}

    //default simple sequence: some packages give errors and memory is limited, so keep it simple
    _DECLARE+_DEFAULTSIMPLE+_SEP+
    {$ifndef FPCONLY}
    _EXECUTE+_CHECKDEVLIBS+_SEP+
    {$endif}
    _DO+_FPC+_SEP+
    {$ifndef FPCONLY}
    _DO+_LAZARUSSIMPLE+_SEP+
    {$endif}
    _END+

//default clean sequence
    _DECLARE+_DEFAULT+_CLEAN+_SEP+
    _DO+_FPC+_CLEAN+_SEP+
    {$ifndef FPCONLY}
    _DO+_LAZARUS+_CLEAN+_SEP+
    _DO+_HELPLAZARUS+_CLEAN+_SEP+
    //_CLEANMODULE+'DOCEDITOR'+_SEP+
    _DO+_UNIVERSALDEFAULT+_CLEAN+_SEP+
    {$endif}
    _END+

//default uninstall sequence
    _DECLARE+_DEFAULT+_UNINSTALL+_SEP+
    _DO+_FPC+_UNINSTALL+_SEP+
    {$ifndef FPCONLY}
    _DO+_LAZARUS+_UNINSTALL+_SEP+
    _DO+_HELP+_UNINSTALL+_SEP+
    //'UninstallModule DOCEDITOR'+_SEP+
    _DO+_UNIVERSALDEFAULT+_UNINSTALL+_SEP+
    {$endif}
    _END+

//default uninstall sequence for win32
    _DECLARE+_DEFAULT+'win32'+_UNINSTALL+_SEP+
    _DO+_DEFAULT+_UNINSTALL+_SEP+
    _END+

//default uninstall sequence for win64
    _DECLARE+_DEFAULT+'win64'+_UNINSTALL+_SEP+
    _DO+_DEFAULT+_UNINSTALL+_SEP+
    _END+

//default install sequence for docker
    _DECLARE+_DOCKER+_SEP+
    _CLEANMODULE+_FPC+_SEP+
    _CHECKMODULE+_FPC+_SEP+
    _GETMODULE+_FPC+_SEP+
    _BUILDMODULE+_FPC+_SEP+
    {$ifndef FPCONLY}
    _DO+_LAZBUILD+_ONLY+_SEP +
    {$endif}
    _END+

//default check sequence
    _DECLARE+_DEFAULT+_CHECK+_SEP+
    _CHECKMODULE+_FPC+_SEP+
    {$ifndef FPCONLY}
    _CHECKMODULE+_LAZARUS+_SEP+
    {$endif}
    _END+

    _DECLARE+_CREATESCRIPT+_SEP+
    _EXECUTE+_CREATEFPCUPSCRIPT+_SEP+
    {$ifndef FPCONLY}
    _EXECUTE+_CREATELAZARUSSCRIPT+_SEP+
    {$endif}

    _ENDFINAL;

type
  TSequencer=class; //forward

  TResultCodes=(rMissingCrossLibs,rMissingCrossBins);
  TResultSet = Set of TResultCodes;

  { TFPCupManager }

  TFPCupManager=class(TObject)
  private
    FHTTPProxyHost: string;
    FHTTPProxyPassword: string;
    FHTTPProxyPort: integer;
    FHTTPProxyUser: string;
    FPersistentOptions: string;
    FBaseDirectory: string;
    FCompilerOverride: string;
    FBootstrapCompiler: string;
    FBootstrapCompilerDirectory: string;
    FClean: boolean;
    FConfigFile: string;
    {$ifndef FPCONLY}
    FLCL_Platform: string; //really LCL widgetset
    {$endif}
    FCrossOPT: string;
    FCrossCPU_Target: TCPU;
    FCrossOS_Target: TOS;
    FCrossOS_SubArch: TSUBARCH;
    FFPCDesiredRevision: string;
    FFPCSourceDirectory: string;
    FFPCInstallDirectory: string;
    FFPCOPT: string;
    FFPCURL: string;
    FFPCBranch: string;
    FFPCTAG: string;
    FIncludeModules: string;
    FKeepLocalDiffs: boolean;
    FUseSystemFPC: boolean;
    {$ifndef FPCONLY}
    FLazarusDesiredRevision: string;
    FLazarusSourceDirectory: string;
    FLazarusInstallDirectory: string;
    FLazarusOPT: string;
    FLazarusPrimaryConfigPath: string;
    FLazarusURL: string;
    FLazarusBranch: string;
    FLazarusTAG: string;
    {$endif}
    FCrossToolsDirectory: string;
    FCrossLibraryDirectory: string;
    FMakeDirectory: string;
    FOnlyModules: string;
    FPatchCmd: string;
    FReApplyLocalChanges: boolean;
    {$ifndef FPCONLY}
    FShortCutNameLazarus: string;
    FContext: boolean;
    {$endif}
    FShortCutNameFpcup: string;
    FSkipModules: string;
    FFPCPatches:string;
    FFPCPreInstallScriptPath:string;
    FFPCPostInstallScriptPath:string;
    {$ifndef FPCONLY}
    FLazarusPatches:string;
    FLazarusPreInstallScriptPath:string;
    FLazarusPostInstallScriptPath:string;
    {$endif}
    FUninstall:boolean;
    FVerbose: boolean;
    FUseWget: boolean;
    FExportOnly:boolean;
    FNoJobs:boolean;
    FSoftFloat:boolean;
    FOnlinePatching:boolean;
    FUseGitClient:boolean;
    FSwitchURL:boolean;
    FNativeFPCBootstrapCompiler:boolean;
    FForceLocalRepoClient:boolean;
    FSequencer: TSequencer;
    FSolarisOI:boolean;
    FMUSL:boolean;
    FAutoTools:boolean;
    FRunInfo:string;
    procedure SetURL(ATarget,AValue: string);
    procedure SetTAG(ATarget,AValue: string);
    procedure SetBranch(ATarget,AValue: string);
    function GetCrossCombo_Target:string;
    {$ifndef FPCONLY}
    function GetLazarusPrimaryConfigPath: string;
    procedure SetLazarusSourceDirectory(AValue: string);
    procedure SetLazarusInstallDirectory(AValue: string);
    procedure SetLazarusURL(AValue: string);
    procedure SetLazarusTAG(AValue: string);
    procedure SetLazarusBranch(AValue: string);
    {$endif}
    function GetLogFileName: string;
    procedure SetBaseDirectory(AValue: string);
    procedure SetBootstrapCompilerDirectory(AValue: string);
    procedure SetFPCSourceDirectory(AValue: string);
    procedure SetFPCInstallDirectory(AValue: string);
    procedure SetFPCURL(AValue: string);
    procedure SetFPCTAG(AValue: string);
    procedure SetFPCBranch(AValue: string);
    procedure SetCrossToolsDirectory(AValue: string);
    procedure SetCrossLibraryDirectory(AValue: string);
    procedure SetLogFileName(AValue: string);
    procedure SetMakeDirectory(AValue: string);
    function  GetTempDirectory:string;
    function  GetRunInfo:string;
    procedure SetRunInfo(aValue:string);
    procedure SetNoJobs(aValue:boolean);
  protected
    FShortcutCreated:boolean;
    FLog:TLogger;
    FModuleList:TStringList;
    FModuleEnabledList:TStringList;
    FModulePublishedList:TStringList;
    // Write msg to log with line ending. Can also write to console
    procedure WritelnLog(msg:string;ToConsole:boolean=true);overload;
    procedure WritelnLog(EventType: TEventType;msg:string;ToConsole:boolean=true);overload;
 public
    property ShortcutCreated:boolean read FShortcutCreated;
    property Sequencer: TSequencer read FSequencer;
   {$ifndef FPCONLY}
    property ShortCutNameLazarus: string read FShortCutNameLazarus write FShortCutNameLazarus; //Name of the shortcut that points to the fpcup-installed Lazarus
    property Context: boolean read FContext write FContext; //Name of the shortcut that points to the fpcup-installed Lazarus
    {$endif}
    property ShortCutNameFpcup:string read FShortCutNameFpcup write FShortCutNameFpcup; //Name of the shortcut that points to fpcup
    // Options that are to be saved in shortcuts/batch file/shell scripts.
    // Excludes temporary options like --verbose
    property PersistentOptions: string read FPersistentOptions write FPersistentOptions;
    // Full path to bootstrap compiler
    property BootstrapCompiler: string read FBootstrapCompiler write FBootstrapCompiler;
    property BaseDirectory: string read FBaseDirectory write SetBaseDirectory;
    // Directory where bootstrap compiler is installed/downloaded
    property BootstrapCompilerDirectory: string read FBootstrapCompilerDirectory write SetBootstrapCompilerDirectory;
    property TempDirectory: string read GetTempDirectory;
    // Compiler override
    property CompilerOverride: string read FCompilerOverride write FCompilerOverride;
    property Clean: boolean read FClean write FClean;
    property ConfigFile: string read FConfigFile write FConfigFile;
    property CrossCPU_Target:TCPU read FCrossCPU_Target write FCrossCPU_Target;
    property CrossOS_Target:TOS read FCrossOS_Target write FCrossOS_Target;
    property CrossOS_SubArch:TSUBARCH read FCrossOS_SubArch write FCrossOS_SubArch;
    property CrossCombo_Target:string read GetCrossCombo_Target;

    // Widgetset for which the user wants to compile the LCL (not the IDE).
    // Empty if default LCL widgetset used for current platform
    {$ifndef FPCONLY}
    property LCL_Platform:string read FLCL_Platform write FLCL_Platform;
    {$endif}
    property CrossOPT:string read FCrossOPT write FCrossOPT;
    property CrossToolsDirectory:string read FCrossToolsDirectory write SetCrossToolsDirectory;
    property CrossLibraryDirectory:string read FCrossLibraryDirectory write SetCrossLibraryDirectory;
    property FPCSourceDirectory: string read FFPCSourceDirectory write SetFPCSourceDirectory;
    property FPCInstallDirectory: string read FFPCInstallDirectory write SetFPCInstallDirectory;
    property FPCURL: string read FFPCURL write SetFPCURL;
    property FPCBranch: string read FFPCBranch write SetFPCBranch;
    property FPCTAG: string read FFPCTAG write SetFPCTAG;
    property FPCOPT: string read FFPCOPT write FFPCOPT;
    property FPCDesiredRevision: string read FFPCDesiredRevision write FFPCDesiredRevision;
    property HTTPProxyHost: string read FHTTPProxyHost write FHTTPProxyHost;
    property HTTPProxyPassword: string read FHTTPProxyPassword write FHTTPProxyPassword;
    property HTTPProxyPort: integer read FHTTPProxyPort write FHTTPProxyPort;
    property HTTPProxyUser: string read FHTTPProxyUser write FHTTPProxyUser;
    property KeepLocalChanges: boolean read FKeepLocalDiffs write FKeepLocalDiffs;
    property UseSystemFPC:boolean read FUseSystemFPC write FUseSystemFPC;
   {$ifndef FPCONLY}
    property LazarusSourceDirectory: string read FLazarusSourceDirectory write SetLazarusSourceDirectory;
    property LazarusInstallDirectory: string read FLazarusInstallDirectory write SetLazarusInstallDirectory;
    property LazarusPrimaryConfigPath: string read GetLazarusPrimaryConfigPath write FLazarusPrimaryConfigPath ;
    property LazarusURL: string read FLazarusURL write SetLazarusURL;
    property LazarusBranch:string read FLazarusBranch write SetLazarusBranch;
    property LazarusTAG: string read FLazarusTAG write SetLazarusTAG;
    property LazarusOPT:string read FLazarusOPT write FLazarusOPT;
    property LazarusDesiredRevision:string read FLazarusDesiredRevision write FLazarusDesiredRevision;
    {$endif}
    // Location where fpcup log will be written to.
    property LogFileName: string read GetLogFileName write SetLogFileName;
    // Directory where make is. Can be empty.
    // On Windows, also a directory where the binutils can be found.
    property MakeDirectory: string read FMakeDirectory write SetMakeDirectory;
    // List of all default enabled sequences available
    property ModuleEnabledList: TStringList read FModuleEnabledList;
    // List of all publicly visible sequences
    property ModulePublishedList: TStringList read FModulePublishedList;
    // List of modules that must be processed in addition to the default ones
    property IncludeModules:string read FIncludeModules write FIncludeModules;
    // Patch utility to use. Defaults to '(g)patch'
    property PatchCmd:string read FPatchCmd write FPatchCmd;
    // Whether or not to back up locale changes to .diff and reapply them before compiling
    property ReApplyLocalChanges: boolean read FReApplyLocalChanges write FReApplyLocalChanges;
    // List of modules that must not be processed
    property SkipModules:string read FSkipModules write FSkipModules;
    property FPCPatches:string read FFPCPatches write FFPCPatches;
    property FPCPreInstallScriptPath:string read FFPCPreInstallScriptPath write FFPCPreInstallScriptPath;
    property FPCPostInstallScriptPath:string read FFPCPostInstallScriptPath write FFPCPostInstallScriptPath;
    {$ifndef FPCONLY}
    property LazarusPatches:string read FLazarusPatches write FLazarusPatches;
    property LazarusPreInstallScriptPath:string read FLazarusPreInstallScriptPath write FLazarusPreInstallScriptPath;
    property LazarusPostInstallScriptPath:string read FLazarusPostInstallScriptPath write FLazarusPostInstallScriptPath;
    {$endif}
    // Exhaustive/exclusive list of modules that must be processed; no other
    // modules may be processed.
    property OnlyModules:string read FOnlyModules write FOnlyModules;
    property Uninstall: boolean read FUninstall write FUninstall;
    property Verbose:boolean read FVerbose write FVerbose;
    property UseWget:boolean read FUseWget write FUseWget;
    property ExportOnly:boolean read FExportOnly write FExportOnly;
    property NoJobs:boolean read FNoJobs write SetNoJobs;
    property SoftFloat:boolean read FSoftFloat write FSoftFloat;
    property OnlinePatching:boolean read FOnlinePatching write FOnlinePatching;
    property UseGitClient:boolean read FUseGitClient write FUseGitClient;
    property SwitchURL:boolean read FSwitchURL write FSwitchURL;
    property NativeFPCBootstrapCompiler:boolean read FNativeFPCBootstrapCompiler write FNativeFPCBootstrapCompiler;
    property ForceLocalRepoClient:boolean read FForceLocalRepoClient write FForceLocalRepoClient;
    property SolarisOI:boolean read FSolarisOI write FSolarisOI;
    property MUSL:boolean read FMUSL write FMUSL;
    property AutoTools:boolean read FAutoTools write FAutoTools;
    property RunInfo:string read GetRunInfo write SetRunInfo;
    // Fill in ModulePublishedList and ModuleEnabledList and load other config elements
    function LoadFPCUPConfig:boolean;
    function CheckValidCPUOS(aCPU:TCPU=TCPU.cpuNone;aOS:TOS=TOS.osNone): boolean;
    function ParseSubArchsFromSource: TStringList;
    procedure GetCrossToolsFileName(out BinsFileName,LibsFileName:string);
    procedure GetCrossToolsPath(out BinPath,LibPath:string);
    function GetCrossBinsURL(out BaseBinsURL:string; var BinsFileName:string):boolean;
    function GetCrossLibsURL(out BaseLibsURL:string; var LibsFileName:string):boolean;

    // Stop talking. Do it! Returns success status
    function Run: boolean;

    constructor Create;
    destructor Destroy; override;
  end;


  // Was this sequence already executed before? Which result?
  TExecState=(ESNever,ESFailed,ESSucceeded);

  TSequenceAttributes=record
    EntryPoint:integer;  //instead of rescanning the sequence table everytime, we can as well store the index in the table
    Executed:TExecState; //  Reset to ESNever at sequencer start up
  end;
  PSequenceAttributes=^TSequenceAttributes;

  TKeyword=(SMdeclare, SMdeclareHidden, SMdo, SMrequire, SMexec, SMend, SMcleanmodule, SMgetmodule, SMbuildmodule,
    SMcheckmodule, SMuninstallmodule, SMconfigmodule{$ifndef FPCONLY}, SMResetLCL{$endif}, SMSetOS, SMSetCPU, SMInvalid);

  TState=record
    instr:TKeyword;
    param:string;
  end;

  { TSequencer }

  TSequencer=class(TObject)
    private
      FParent:TFPCupManager;
      FInstaller:TInstaller;  //current installer
      property Installer:TInstaller read FInstaller;
    protected
      FCurrentModule:String;
      FSkipList:TStringList;
      FStateMachine:array of TState;
      procedure AddToModuleList(ModuleName:string;EntryPoint:integer);
      function DoCheckModule(ModuleName:string):boolean;
      function DoBuildModule(ModuleName:string):boolean;
      function DoCleanModule(ModuleName:string):boolean;
      function DoConfigModule(ModuleName:string):boolean;
      function DoExec(FunctionName:string):boolean;
      function DoGetModule(ModuleName:string):boolean;
      function DoSetCPU(aCPU:string):boolean;
      function DoSetOS(aOS:string):boolean;
      // Resets memory of executed steps so LCL widgetset can be rebuild
      // e.g. using different platform
      {$ifndef FPCONLY}
      function DoResetLCL:boolean;
      {$endif}
      function DoUnInstallModule(ModuleName:string):boolean;
      function GetInstaller(ModuleName:string):boolean;
      function GetText:string;
      function IsSkipped(ModuleName:string):boolean;
      // Reset memory of executed steps, allowing sequences with e.g. new OS to be rerun
    public
      // set Executed to ESNever for all sequences
      procedure ResetAllExecuted(SkipFPC:boolean=false);
      // Text representation of sequence; for diagnostic purposes
      property Text:String read GetText;
      // parse a sequence source code and append to the FStateMachine
      function AddSequence(Sequence:string):boolean;
      // Add the "only" sequence from the FStateMachine based on the --only list
      function CreateOnly(OnlyModules:string):boolean;
      // deletes the "only" sequence from the FStateMachine
      function DeleteOnly:boolean;
      // run the FStateMachine starting at SequenceName
      function Run(SequenceName:string):boolean;
      // Force quit
      function Kill: boolean;
      constructor Create(aParent:TFPCupManager);
      destructor Destroy; override;
    end;

implementation

uses
  {$IFNDEF FPCONLY}
  {$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION > 30000)}
  InterfaceBase,
  {$ENDIF}
  {$ENDIF}
  StrUtils,
  fpjson,
  processutils;

{ TFPCupManager }

{$ifndef FPCONLY}
function TFPCupManager.GetLazarusPrimaryConfigPath: string;
const
  // This should be a last resort as FLazarusPrimaryConfigPath should be used really
  DefaultPCPSubdir='lazarusdevsettings'; //Include the name lazarus for easy searching Caution: shouldn't be the same name as Lazarus dir itself.
begin
  if FLazarusPrimaryConfigPath='' then
  begin
    {$IFDEF MSWINDOWS}
    // Somewhere in local appdata special folder
    FLazarusPrimaryConfigPath:=IncludeTrailingPathDelimiter(GetWindowsAppDataFolder)+DefaultPCPSubdir;
    {$ELSE}
    // Note: normal GetAppConfigDir gets ~/.config/fpcup/.lazarusdev or something
    // XdgConfigHome normally resolves to something like ~/.config
    // which is a reasonable default if we have no Lazarus primary config path set
    FLazarusPrimaryConfigPath:=ExcludeTrailingPathDelimiter(XdgConfigHome)+DefaultPCPSubdir;
    {$ENDIF MSWINDOWS}
  end;
  result:=FLazarusPrimaryConfigPath;
end;
{$endif}

function TFPCupManager.GetLogFileName: string;
begin
  result:=FLog.LogFile;
end;

procedure TFPCupManager.SetBaseDirectory(AValue: string);
begin
  FBaseDirectory:=SafeExpandFileName(AValue);
  ForceDirectoriesSafe(FBaseDirectory);
end;

procedure TFPCupManager.SetBootstrapCompilerDirectory(AValue: string);
begin
  FBootstrapCompilerDirectory:=ExcludeTrailingPathDelimiter(SafeExpandFileName(AValue));
end;

procedure TFPCupManager.SetFPCSourceDirectory(AValue: string);
begin  
  FFPCSourceDirectory:=SafeExpandFileName(AValue);
end;

procedure TFPCupManager.SetFPCInstallDirectory(AValue: string);
begin
  FFPCInstallDirectory:=SafeExpandFileName(AValue);
end;

procedure TFPCupManager.SetURL(ATarget,AValue: string);
var
  LocalURL:string;
  URLLookupMagic:string;
begin
  if ((ATarget<>_FPC) {$ifndef FPCONLY}AND (ATarget<>_LAZARUS){$endif}) then
  begin
    WritelnLog(etError,'Gitlab alias lookup of '+ATarget+' tag/branch/url error.');
    exit;
  end;

  if (ATarget=_FPC) then
  begin
    LocalURL:=FFPCURL;
    URLLookupMagic:=FPCURLLOOKUPMAGIC;
  end;

  {$ifndef FPCONLY}
  if (ATarget=_LAZARUS) then
  begin
    LocalURL:=FLazarusURL;
    URLLookupMagic:=LAZARUSURLLOOKUPMAGIC;
  end;
  {$endif}

  if LocalURL=AValue then exit;

  if (Pos('://',AValue)>0) then
    LocalURL:=AValue
  else
    LocalURL:=installerUniversal.GetAlias(URLLookupMagic,AValue);

  if (ATarget=_FPC) then FFPCURL:=LocalURL;
  {$ifndef FPCONLY}
  if (ATarget=_LAZARUS) then FLazarusURL:=LocalURL;
  {$endif}

  if ( (Length(LocalURL)=0) AND (Length(AValue)>0) ) then
  begin
    if (NOT AnsiEndsText(GITLABEXTENSION,AValue)) then
      SetTAG(ATarget,AValue+GITLABEXTENSION)
    else
      SetTAG(ATarget,AValue);
  end;
end;

procedure TFPCupManager.SetTAG(ATarget,AValue: string);
var
  s:string;
  LocalURL,LocalTag,LocalBranch:string;
  RemoteURL,BranchLookupMagic,TagLookupMagic:string;
begin
  if ((ATarget<>_FPC) {$ifndef FPCONLY}AND (ATarget<>_LAZARUS){$endif}) then
  begin
    WritelnLog(etError,'Gitlab alias lookup of '+ATarget+' tag/branch/url error.');
    exit;
  end;

  if (ATarget=_FPC) then
  begin
    LocalTag:=FFPCTAG;
    LocalBranch:=FFPCBranch;
    LocalURL:=FFPCURL;
    RemoteURL:=FPCGITLABREPO;
    BranchLookupMagic:=FPCBRANCHLOOKUPMAGIC;
    TagLookupMagic:=FPCTAGLOOKUPMAGIC;
  end;

  {$ifndef FPCONLY}
  if (ATarget=_LAZARUS) then
  begin
    LocalTag:=FLazarusTAG;
    LocalBranch:=FLazarusBranch;
    LocalURL:=FLazarusURL;
    RemoteURL:=LAZARUSGITLABREPO;
    BranchLookupMagic:=LAZARUSBRANCHLOOKUPMAGIC;
    TagLookupMagic:=LAZARUSTAGLOOKUPMAGIC;
  end;
  {$endif}

  if AnsiEndsText(GITLABEXTENSION,AValue) then
  begin
    LocalURL:='';
    s:=installerUniversal.GetAlias(TagLookupMagic,AValue);
    if (Length(s)>0) then
    begin
      LocalTag:=s;
      LocalBranch:='';
    end
    else
    begin
      s:=installerUniversal.GetAlias(BranchLookupMagic,AValue);
      if (Length(s)>0) then
      begin
        LocalTag:='';
        if AnsiContainsText(s,'gitlab.com/') then
        begin
          LocalURL:=s;
          LocalBranch:='';
        end
        else
          LocalBranch:=s;
      end;
    end;
    if (Length(s)>0) then
    begin
      if (Length(LocalURL)=0) then
        LocalURL:=RemoteURL;
    end
    else
      WritelnLog(etError,'Gitlab alias lookup of '+ATarget+' tag/branch/url failed. Expect errors.');
  end
  else
  begin
    LocalTag:=aValue;
    LocalBranch:='';
  end;

  if (ATarget=_FPC) then
  begin
    FFPCTAG:=LocalTag;
    FFPCBranch:=LocalBranch;
    FFPCURL:=LocalURL;
  end;

  {$ifndef FPCONLY}
  if (ATarget=_LAZARUS) then
  begin
    FLazarusTAG:=LocalTag;
    FLazarusBranch:=LocalBranch;
    FLazarusURL:=LocalURL;
  end;
  {$endif}
end;

procedure TFPCupManager.SetBranch(ATarget,AValue: string);
var
  s:string;
  LocalURL,LocalTag,LocalBranch:string;
  RemoteURL,BranchLookupMagic:string;
begin
  if ((ATarget<>_FPC) {$ifndef FPCONLY}AND (ATarget<>_LAZARUS){$endif}) then
  begin
    WritelnLog(etError,'Gitlab alias lookup of '+ATarget+' tag/branch/url error.');
    exit;
  end;

  if (ATarget=_FPC) then
  begin
    LocalTag:=FFPCTAG;
    LocalBranch:=FFPCBranch;
    LocalURL:=FFPCURL;
    RemoteURL:=FPCGITLABREPO;
    BranchLookupMagic:=FPCBRANCHLOOKUPMAGIC;
  end;

  {$ifndef FPCONLY}
  if (ATarget=_LAZARUS) then
  begin
    LocalTag:=FLazarusTAG;
    LocalBranch:=FLazarusBranch;
    LocalURL:=FLazarusURL;
    RemoteURL:=LAZARUSGITLABREPO;
    BranchLookupMagic:=LAZARUSBRANCHLOOKUPMAGIC;
  end;
  {$endif}

  if AnsiEndsText(GITLABEXTENSION,AValue) then
  begin
    s:=installerUniversal.GetAlias(BranchLookupMagic,AValue);
    if (Length(s)>0) then
    begin
      LocalTag:='';
      LocalBranch:=s;
      LocalURL:=RemoteURL;
    end
    else
    begin
      WritelnLog(etError,'Gitlab alias lookup of '+ATarget+' branch failed. Expect errors.');
    end;
  end
  else
  begin
    LocalBranch:=aValue;
    LocalTag:='';
  end;

  if (ATarget=_FPC) then
  begin
    FFPCTAG:=LocalTag;
    FFPCBranch:=LocalBranch;
    FFPCURL:=LocalURL;
  end;

  {$ifndef FPCONLY}
  if (ATarget=_LAZARUS) then
  begin
    FLazarusTAG:=LocalTag;
    FLazarusBranch:=LocalBranch;
    FLazarusURL:=LocalURL;
  end;
  {$endif}
end;

procedure TFPCupManager.SetFPCURL(AValue: string);
begin
  SetURL(_FPC,AValue);
end;

procedure TFPCupManager.SetFPCTAG(AValue: string);
begin
  SetTAG(_FPC,AValue);
end;

procedure TFPCupManager.SetFPCBranch(AValue: string);
begin
  SetBranch(_FPC,AValue);
end;

procedure TFPCupManager.SetCrossToolsDirectory(AValue: string);
begin
  //FCrossToolsDirectory:=SafeExpandFileName(AValue);
  FCrossToolsDirectory:=AValue;
end;

procedure TFPCupManager.SetCrossLibraryDirectory(AValue: string);
begin
  //FCrossLibraryDirectory:=SafeExpandFileName(AValue);
  FCrossLibraryDirectory:=AValue;
end;

{$ifndef FPCONLY}
procedure TFPCupManager.SetLazarusSourceDirectory(AValue: string);
begin
  FLazarusSourceDirectory:=SafeExpandFileName(AValue);
end;
procedure TFPCupManager.SetLazarusInstallDirectory(AValue: string);
begin
  FLazarusInstallDirectory:=SafeExpandFileName(AValue);
end;

procedure TFPCupManager.SetLazarusURL(AValue: string);
begin
  SetURL(_LAZARUS,AValue);
end;

procedure TFPCupManager.SetLazarusTAG(AValue: string);
begin
  SetTAG(_LAZARUS,AValue);
end;

procedure TFPCupManager.SetLazarusBranch(AValue: string);
begin
  SetBranch(_LAZARUS,AValue);
end;
{$endif}

procedure TFPCupManager.SetLogFileName(AValue: string);
begin
  // Don't change existing log file
  if (AValue<>'') and (FLog.LogFile=AValue) then Exit;
  // Defaults if empty value specified
  if AValue='' then
  begin
    {$IFDEF MSWINDOWS}
    FLog.LogFile:=SafeGetApplicationPath+'fpcup.log'; //exe directory
    {$ELSE}
    FLog.LogFile:=SafeExpandFileName('~')+DirectorySeparator+'fpcup.log'; //home directory
    {$ENDIF MSWINDOWS}
  end
  else
  begin
    FLog.LogFile:=AValue;
  end;
end;

procedure TFPCupManager.SetMakeDirectory(AValue: string);
begin
  FMakeDirectory:=SafeExpandFileName(AValue);
end;

function TFPCupManager.GetTempDirectory:string;
begin
  if DirectoryExists(FBaseDirectory) then
  begin
    result:=ConcatPaths([FBaseDirectory,'tmp']);
    ForceDirectoriesSafe(result);
  end;
end;

procedure TFPCupManager.WritelnLog(msg: string; ToConsole: boolean);
begin
  // Set up log if it doesn't exist yet
  FLog.WriteLog(msg);
  if ToConsole then
  begin
    if Assigned(Sequencer.Installer) then
      Sequencer.Installer.Infoln(msg)
    else
      ThreadLog(msg);
  end;
end;

procedure TFPCupManager.WritelnLog(EventType: TEventType; msg: string; ToConsole: boolean);
begin
  // Set up log if it doesn't exist yet
  FLog.WriteLog(EventType,msg);
  if ToConsole then
  begin
    if Assigned(Sequencer.Installer) then
      Sequencer.Installer.Infoln(msg,EventType)
    else
      ThreadLog(msg,EventType);
  end;
end;

function TFPCupManager.LoadFPCUPConfig: boolean;
begin
  installerUniversal.SetConfigFile(FConfigFile);
  FSequencer.AddSequence(Sequences);
  FSequencer.AddSequence(installerFPC.Sequences);
  {$ifndef FPCONLY}
  FSequencer.AddSequence(installerLazarus.Sequences);
  {$endif}
  FSequencer.AddSequence(installerHelp.Sequences);
  FSequencer.AddSequence(installerUniversal.Sequences);
  // append universal modules to the lists
  FSequencer.AddSequence(installerUniversal.GetModuleList);
  result:=installerUniversal.GetModuleEnabledList(FModuleEnabledList);
end;

function TFPCupManager.CheckValidCPUOS(aCPU:TCPU;aOS:TOS): boolean;
var
  s           : string;
  x           : integer;
  sl          : TStringList;
  aLocalCPU   : TCPU;
  aLocalOS    : TOS;
begin
  result:=false;

  aLocalCPU:=aCPU;
  if aLocalCPU=TCPU.cpuNone then aLocalCPU:=CrossCPU_Target;
  aLocalOS:=aOS;
  if aLocalOS=TOS.osNone then aLocalOS:=CrossOS_Target;

  if ((aLocalCPU=TCPU.cpuNone) OR (aLocalOS=TOS.osNone)) then exit;

  //parsing systems.inc or .pas for valid CPU / OS system
  s:=ConcatPaths([FPCSourceDirectory,'compiler'])+DirectorySeparator+'systems.inc';
  if (NOT FileExists(s)) then s:=ConcatPaths([FPCSourceDirectory,'compiler'])+DirectorySeparator+'systems.pas';
  if FileExists(s) then
  begin
    sl:=TStringList.Create;
    try
      sl.LoadFromFile(s);
      s:='system_'+GetCPU(aLocalCPU)+'_'+GetOS(aLocalOS);
      x:=StringListContains(sl,s);
      if (x<>-1) then
      begin
        s:=sl[x];
        if (Pos('obsolete_',s)=0) then result:=true;
      end;
    finally
      sl.Free;
    end;
  end;
end;

function TFPCupManager.ParseSubArchsFromSource: TStringList;
const
  REQ1='ifeq ($(ARCH),';
  REQ2='ifeq ($(SUBARCH),';
var
  TxtFile:Text;
  s,arch,subarch:string;
  x:integer;
begin
  Result := TStringList.Create;
  Result.Sorted := True;
  Result.Duplicates := dupIgnore;

  s:=IncludeTrailingPathDelimiter(FPCSourceDirectory)+'rtl'+DirectorySeparator+GetOS(CrossOS_Target)+DirectorySeparator+FPCMAKEFILENAME;

  if FileExists(s) then
  begin
    AssignFile(TxtFile,s);
    Reset(TxtFile);
    while NOT EOF (TxtFile) do
    begin

      Readln(TxtFile,s);
      x:=Pos(REQ1,s);
      if x=1 then
      begin
        arch:=s;
        Delete(arch,1,x+Length(REQ1)-1);
        x:=Pos(')',arch);
        if x>0 then
        begin
          Delete(arch,x,MaxInt);
        end;
      end;

      if Length(arch)>0 then
      begin
        x:=Pos(REQ2,s);
        if x=1 then
        begin
          subarch:=s;
          Delete(subarch,1,x+Length(REQ2)-1);
          x:=Pos(')',subarch);
          if x>0 then
          begin
            Delete(subarch,x,MaxInt);
            if Length(subarch)>0 then with Result {%H-}do Add(Concat(arch, NameValueSeparator, subarch));
          end;
        end;
      end;
    end;

    CloseFile(TxtFile);

  end;
end;

procedure TFPCupManager.GetCrossToolsFileName(out BinsFileName,LibsFileName:string);
var
  s:string;
begin
  // Setting the CPU part of the name[s] for the file to download
  if CrossCPU_Target=TCPU.arm then s:='ARM' else
    if CrossCPU_Target=TCPU.i386 then s:='i386' else
      if CrossCPU_Target=TCPU.x86_64 then s:='x64' else
        if CrossCPU_Target=TCPU.powerpc then s:='PowerPC' else
          if CrossCPU_Target=TCPU.powerpc64 then s:='PowerPC64' else
            if CrossCPU_Target=TCPU.avr then s:='AVR' else
              if CrossCPU_Target=TCPU.m68k then s:='m68k' else
                s:=UppercaseFirstChar(GetCPU(CrossCPU_Target));

  BinsFileName:=s;

  // Set special CPU names
  if CrossOS_Target=TOS.darwin then
  begin
    // Darwin has some universal binaries and libs
    if CrossCPU_Target=TCPU.i386 then BinsFileName:='All';
    if CrossCPU_Target=TCPU.x86_64 then BinsFileName:='All';
    if CrossCPU_Target=TCPU.aarch64 then BinsFileName:='All';
    if CrossCPU_Target=TCPU.powerpc then BinsFileName:='PowerPC';
    if CrossCPU_Target=TCPU.powerpc64 then BinsFileName:='PowerPC';
  end;

  if CrossOS_Target=TOS.ios then
  begin
    // iOS has some universal binaries and libs
    if CrossCPU_Target=TCPU.arm then BinsFileName:='All';
    if CrossCPU_Target=TCPU.aarch64 then BinsFileName:='All';
  end;

  if CrossOS_Target=TOS.aix then
  begin
    // AIX has some universal binaries
    if CrossCPU_Target=TCPU.powerpc then BinsFileName:='PowerPC';
    if CrossCPU_Target=TCPU.powerpc64 then BinsFileName:='PowerPC';
  end;

  // Set OS case
  if CrossOS_Target=TOS.morphos then s:='MorphOS' else
    if CrossOS_Target=TOS.freebsd then s:='FreeBSD' else
      if CrossOS_Target=TOS.dragonfly then s:='DragonFlyBSD' else
        if CrossOS_Target=TOS.openbsd then s:='OpenBSD' else
          if CrossOS_Target=TOS.netbsd then s:='NetBSD' else
            if CrossOS_Target=TOS.aix then s:='AIX' else
              if CrossOS_Target=TOS.msdos then s:='MSDos' else
                if CrossOS_Target=TOS.freertos then s:='FreeRTOS' else
                  if CrossOS_Target=TOS.win32 then s:='Windows' else
                    if CrossOS_Target=TOS.win64 then s:='Windows' else
                      if CrossOS_Target=TOS.ios then s:='IOS' else
                      s:=UppercaseFirstChar(GetOS(CrossOS_Target));

  if SolarisOI then s:=s+'OI';
  BinsFileName:=s+BinsFileName;

  if MUSL then BinsFileName:='MUSL'+BinsFileName;

  // normally, we have the same names for libs and bins URL
  LibsFileName:=BinsFileName;

  {$IF (defined(Windows)) OR (defined(Linux))}
  if (
    ((CrossOS_Target=TOS.darwin) AND (CrossCPU_Target in [TCPU.i386,TCPU.x86_64,TCPU.aarch64]))
    OR
    ((CrossOS_Target=TOS.ios) AND (CrossCPU_Target in [TCPU.arm,TCPU.aarch64]))
    ) then
  begin
    // Set special BinsFile for universal tools for Darwin
    BinsFileName:='AppleAll';
  end;

  if CrossOS_Target=TOS.android then
  begin
    // Android has universal binaries
    BinsFileName:='AndroidAll';
  end;
  {$endif}

  if CrossCPU_Target=TCPU.wasm32 then
  begin
    // wasm has some universal binaries
    BinsFileName:='AllWasm32';
  end;

  if CrossOS_Target=TOS.linux then
  begin
    // PowerPC64 is special: only little endian libs for now
    if (CrossCPU_Target=TCPU.powerpc64) then
    begin
      LibsFileName:=StringReplace(LibsFileName,'PowerPC64','PowerPC64LE',[rfIgnoreCase]);
    end;

    // ARM is special: can be hard or softfloat (Windows only binutils yet)
    {$ifdef MSWINDOWS}
    if (CrossCPU_Target=TCPU.arm) then
    begin
      if (Pos('SOFT',UpperCase(CrossOPT))>0) OR (Pos('FPC_ARMEL',UpperCase(FPCOPT))>0) then
      begin
        // use softfloat binutils
        BinsFileName:=StringReplace(LibsFileName,'BinsLinuxARM','BinsLinuxARMSoft',[rfIgnoreCase]);
      end;
    end;
    {$endif}
  end;

  //{$IF defined(CPUAARCH64) AND defined(DARWIN)}
  {$ifndef MSWINDOWS}
  // For most targets, FreeRTOS is a special version of embedded, so just use the embedded tools !!
  if CrossOS_Target=TOS.freertos then
  begin
    // use embedded tools for freertos:
    if (CrossCPU_Target in SUBARCH_CPU) then
    begin
      BinsFileName:=StringReplace(BinsFileName,'FreeRTOS','Embedded',[]);
    end;
  end;
  {$endif}

  // All ready !!

  LibsFileName:='CrossLibs'+LibsFileName;
  {$ifdef MSWINDOWS}
  BinsFileName:='WinCrossBins'+BinsFileName;
  {$else}
  BinsFileName:='CrossBins'+BinsFileName;
  {$endif MSWINDOWS}
end;

procedure TFPCupManager.GetCrossToolsPath(out BinPath,LibPath:string);
begin
  // Setting the location of libs and bins on our system, so they can be found by fpcupdeluxe
  // Normally, we have the standard names for libs and bins paths
  LibPath:=ConcatPaths([{$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION < 30200)}UnicodeString{$ENDIF}(CROSSPATH),'lib',GetCPU(CrossCPU_Target)])+'-';
  BinPath:=ConcatPaths([{$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION < 30200)}UnicodeString{$ENDIF}(CROSSPATH),'bin',GetCPU(CrossCPU_Target)])+'-';

  if MUSL then
  begin
    LibPath:=LibPath+'musl';
    BinPath:=BinPath+'musl';
  end;
  LibPath:=LibPath+GetOS(CrossOS_Target);
  BinPath:=BinPath+GetOS(CrossOS_Target);
  if SolarisOI then
  begin
    LibPath:=LibPath+'-oi';
    BinPath:=BinPath+'-oi';
  end;

  {$IF (defined(Windows)) OR (defined(Linux))}
  // Set special Bins directory for universal tools for Darwin based on clang
  if (
    ((CrossOS_Target=TOS.darwin) AND (CrossCPU_Target in [TCPU.i386,TCPU.x86_64,TCPU.aarch64]))
    OR
    ((CrossOS_Target=TOS.ios) AND (CrossCPU_Target in [TCPU.arm,TCPU.aarch64]))
    ) then
  begin
    BinPath:=StringReplace(BinPath,GetCPU(CrossCPU_Target),'all',[]);
    BinPath:=StringReplace(BinPath,GetOS(CrossOS_Target),'apple',[]);
  end;

  // Set special Bins directory for universal tools for Android based on clang
  if CrossOS_Target=TOS.android then
  begin
    BinPath:=StringReplace(BinPath,GetCPU(CrossCPU_Target),'all',[]);
  end;
  {$endif}

  // Set special Bins directory for universal tools for wasm32
  if CrossCPU_Target=TCPU.wasm32 then
  begin
    BinPath:=StringReplace(BinPath,GetOS(CrossOS_Target),'all',[]);
  end;

  if CrossOS_Target=TOS.darwin then
  begin
    // Darwin is special: combined binaries and libs for i386 and x86_64 with osxcross
    if (CrossCPU_Target=TCPU.i386) OR (CrossCPU_Target=TCPU.x86_64) OR (CrossCPU_Target=TCPU.aarch64) then
    begin
      BinPath:=StringReplace(BinPath,GetCPU(CrossCPU_Target),'all',[]);
      LibPath:=StringReplace(LibPath,GetCPU(CrossCPU_Target),'all',[]);
    end;
    if (CrossCPU_Target=TCPU.powerpc) OR (CrossCPU_Target=TCPU.powerpc64) then
    begin
      BinPath:=StringReplace(BinPath,GetCPU(CrossCPU_Target),GetCPU(TCPU.powerpc),[]);
      LibPath:=StringReplace(LibPath,GetCPU(CrossCPU_Target),GetCPU(TCPU.powerpc),[]);
    end;
  end;

  if CrossOS_Target=TOS.ios then
  begin
    // iOS is special: combined libs for arm and aarch64
    if (CrossCPU_Target=TCPU.arm) OR (CrossCPU_Target=TCPU.aarch64) then
    begin
      BinPath:=StringReplace(BinPath,GetCPU(CrossCPU_Target),'all',[]);
      LibPath:=StringReplace(LibPath,GetCPU(CrossCPU_Target),'all',[]);
    end;
  end;

  if CrossOS_Target=TOS.aix then
  begin
    // AIX is special: combined binaries and libs for ppc and ppc64 with osxcross
    if (CrossCPU_Target=TCPU.powerpc) OR (CrossCPU_Target=TCPU.powerpc64) then
    begin
      BinPath:=StringReplace(BinPath,GetCPU(CrossCPU_Target),GetCPU(TCPU.powerpc),[]);
      LibPath:=StringReplace(LibPath,GetCPU(CrossCPU_Target),GetCPU(TCPU.powerpc),[]);
    end;
  end;

  //Put all windows stuff (not that much) in a single windows directory
  if (CrossOS_Target=TOS.win32) OR (CrossOS_Target=TOS.win64) then
  begin
    BinPath:=StringReplace(BinPath,GetOS(CrossOS_Target),'windows',[]);
    LibPath:=StringReplace(LibPath,GetOS(CrossOS_Target),'windows',[]);
  end;
end;

function TFPCupManager.GetCrossBinsURL(out BaseBinsURL:string; var BinsFileName:string):boolean;
var
  s:string;
  success:boolean;
  Json : TJSONData;
  Assets : TJSONArray;
  Item,Asset : TJSONObject;
  TagName, FileName, FileURL : string;
  i,iassets : integer;
begin
  result:=false;

  BaseBinsURL:='';

  if GetTargetOS=GetOS(TOS.win32) then BaseBinsURL:='wincrossbins'
  else
     if GetTargetOS=GetOS(TOS.win64) then BaseBinsURL:='wincrossbins'
     else
        if GetTargetOS=GetOS(TOS.linux) then
        begin
          if GetTargetCPU=GetCPU(TCPU.i386) then BaseBinsURL:='linuxi386crossbins';
          if GetTargetCPU=GetCPU(TCPU.x86_64) then BaseBinsURL:='linuxx64crossbins';
          if GetTargetCPU=GetCPU(TCPU.arm) then BaseBinsURL:='linuxarmcrossbins';
        end
        else
          if GetTargetOS=GetOS(TOS.freebsd) then
          begin
            if GetTargetCPU=GetCPU(TCPU.x86_64) then BaseBinsURL:='freebsdx64crossbins';
          end
          else
            if GetTargetOS=GetOS(TOS.solaris) then
            begin
              {if FPCupManager.SolarisOI then}
              begin
                if GetTargetCPU=GetCPU(TCPU.x86_64) then BaseBinsURL:='solarisoix64crossbins';
              end;
            end
            else
              if GetTargetOS=GetOS(TOS.darwin) then
              begin
                if GetTargetCPU=GetCPU(TCPU.i386) then BaseBinsURL:='darwini386crossbins';
                if GetTargetCPU=GetCPU(TCPU.x86_64) then BaseBinsURL:='darwinx64crossbins';
                if GetTargetCPU=GetCPU(TCPU.aarch64) then BaseBinsURL:='darwinarm64crossbins';
              end;

  s:=GetURLDataFromCache(FPCUPGITREPOAPIRELEASES+'?per_page=100');
  success:=(Length(s)>0);

  if success then
  begin
    json:=nil;
    try
      try
        Json:=GetJSON(s);
      except
        Json:=nil;
      end;
      if JSON.IsNull then success:=false;

      if (NOT success) then
      begin
        BaseBinsURL:='';
        exit;
      end;

      (*
      Ss := TStringStream.Create('');
      try
        success:=Download(False,FPCUPGITREPOAPI+'/git/refs/tags/'+BaseBinsURL,Ss);
        if (NOT success) then
        begin
          {$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION >= 30200)}
          Ss.Clear;
          {$ENDIF}
          Ss.Position:=0;
          success:=Download(True,FPCUPGITREPOAPI+'/git/refs/tags/'+BaseBinsURL,Ss);
        end;
        if success then s:=Ss.DataString;
      finally
        Ss.Free;
      end;

      if success then
      begin
        if (Length(s)>0) then
        begin
          try
            Json:=GetJSON(s);
          except
            Json:=nil;
          end;
          if JSON.IsNull then success:=false;
        end;
      end;

      if success then
      begin
        for i:=Pred(Json.Count) downto 0 do
        begin
          Item := TJSONObject(Json.Items[i]);
          TagName:=Item.Get('ref');
          Delete(TagName,1,Length('refs/tags/'));
        end;

      end;
      //FPCUPGITREPOAPI+'/git/refs/tags/'+BaseBinsURL;
      //FPCUPGITREPOAPIRELEASES+'/tags/wincrossbins_v1.0';
      *)

      success:=false;
      FileURL:='';
      for i:=0 to Pred(Json.Count) do
      begin
        Item := TJSONObject(Json.Items[i]);
        TagName:=Item{%H-}.Get('tag_name');
        if (Pos(BaseBinsURL,TagName)<>1) then continue;
        Assets:=Item.Get('assets',TJSONArray(nil));
        // Search zip
        for iassets:=0 to Pred(Assets.Count) do
        begin
          Asset := TJSONObject(Assets[iassets]);
          FileName:=Asset{%H-}.Get('name');
          if AnsiStartsText(BinsFileName+'.zip',FileName) then
          begin
            BinsFileName:=FileName;
            FileURL:=Asset{%H-}.Get('browser_download_url');
          end;
          success:=(Length(FileURL)>0);
          if success then break;
        end;
        if (NOT success) then
        begin
          // Search any
          for iassets:=0 to Pred(Assets.Count) do
          begin
            Asset := TJSONObject(Assets[iassets]);
            FileName:=Asset{%H-}.Get('name');
            if ((ExtractFileExt(FileName)<>'.zip') AND AnsiStartsText(BinsFileName,FileName)) then
            begin
              BinsFileName:=FileName;
              FileURL:=Asset{%H-}.Get('browser_download_url');
            end;
            success:=(Length(FileURL)>0);
            if success then break;
          end;
        end;
        if success then
        begin
          BaseBinsURL:=FileURL;
          BinsFileName:=FileName;
          result:=true;
          break;
        end;
      end;

    finally
      if (Json<>nil) AND (NOT Json.IsNull) then Json.Free;
    end;
  end;

end;

function TFPCupManager.GetCrossLibsURL(out BaseLibsURL:string; var LibsFileName:string):boolean;
var
  s:string;
  success:boolean;
  Json : TJSONData;
  Assets : TJSONArray;
  Item,Asset : TJSONObject;
  TagName, FileName, FileURL : string;
  i,iassets : integer;
begin
  result:=false;

  BaseLibsURL:='crosslibs';

  s:=GetURLDataFromCache(FPCUPGITREPOAPIRELEASES+'?per_page=100');
  success:=(Length(s)>0);

  if success then
  begin
    json:=nil;
    try

      try
        Json:=GetJSON(s);
      except
        Json:=nil;
      end;
      if JSON.IsNull then success:=false;

      if (NOT success) then
      begin
        BaseLibsURL:='';
        exit;
      end;

      success:=false;
      FileURL:='';
      for i:=0 to Pred(Json.Count) do
      begin
        Item := TJSONObject(Json.Items[i]);
        TagName:=Item{%H-}.Get('tag_name');
        if (Pos(BaseLibsURL,TagName)<>1) then continue;
        Assets:=Item.Get('assets',TJSONArray(nil));
        // Search zip
        for iassets:=0 to Pred(Assets.Count) do
        begin
          Asset := TJSONObject(Assets[iassets]);
          FileName:=Asset{%H-}.Get('name');
          if AnsiStartsText(LibsFileName+'.zip',FileName) then
          begin
            LibsFileName:=FileName;
            FileURL:=Asset{%H-}.Get('browser_download_url');
          end;
          success:=(Length(FileURL)>0);
          if success then break;
        end;
        if (NOT success) then
        begin
          // Search any
          for iassets:=0 to Pred(Assets.Count) do
          begin
            Asset := TJSONObject(Assets[iassets]);
            FileName:=Asset{%H-}.Get('name');
            if ((ExtractFileExt(FileName)<>'.zip') AND AnsiStartsText(LibsFileName,FileName)) then
            begin
              LibsFileName:=FileName;
              FileURL:=Asset{%H-}.Get('browser_download_url');
            end;
            success:=(Length(FileURL)>0);
            if success then break;
          end;
        end;
        if success then
        begin
          BaseLibsURL:=FileURL;
          LibsFileName:=FileName;
          result:=true;
          break;
        end;
      end;

    finally
      if (Json<>nil) AND (NOT Json.IsNull) then Json.Free;
    end;
  end;

end;


function TFPCupManager.GetRunInfo:string;
begin
  result:=FRunInfo;
  FRunInfo:='';
end;

procedure TFPCupManager.SetRunInfo(aValue:string);
begin
  if (Length(FRunInfo)>0) then
    FRunInfo:=FRunInfo+LineEnding+aValue
  else
    FRunInfo:=aValue;
end;

procedure TFPCupManager.SetNoJobs(aValue:boolean);
begin
  {$ifdef Haiku}
  FNoJobs:=True;
  RunInfo:='No make jobs on Haiku !';
  {$else}
  FNoJobs:=aValue;
  {$endif}
  if (GetLogicalCpuCount<=1) AND (NOT FNoJobs) then
  begin
    RunInfo:='No make jobs due to CPU count [smaller or] equal to 1 !';
    FNoJobs:=True;
  end;
end;

function TFPCupManager.Run: boolean;
var
  aSequence:string;
begin
  result:=false;

  FRunInfo:='';

  FShortcutCreated:=false;

  if
    (FSequencer.FParent.CrossCPU_Target=GetTCPU(GetTargetCPU))
    AND
    (FSequencer.FParent.CrossOS_Target=GetTOS(GetTargetOS))
  then
  begin
    //if (NOT FSequencer.FParent.MUSL) then
    {$ifdef Linux}
    if (NOT (Self.MUSL AND (GetTOS(GetTargetOS)=TOS.linux))) then
    {$endif}
    begin
      RunInfo:='No crosscompiling to own target !';
      RunInfo:='Native [CPU-OS] version is already installed !!';
      exit;
    end;
  end;

  try
    WritelnLog(DateTimeToStr(now)+': '+BeginSnippet+' V'+RevisionStr+' ('+VersionDate+') started.',false);
    WritelnLog('FPCUPdeluxe V'+DELUXEVERSION+' for '+GetTargetCPUOS+' running on '+GetDistro,false);
  except
    // Writing to log failed, probably duplicate run. Inform user and get out.
    RunInfo:='***ERROR***';
    RunInfo:='Could not open log file '+FLog.LogFile+' for writing.';
    RunInfo:='Perhaps another fpcup is running?';
    exit;
  end;

  try
    if SkipModules<>'' then
    begin
      FSequencer.FSkipList:=TStringList.Create;
      FSequencer.FSkipList.Delimiter:=',';
      FSequencer.FSkipList.DelimitedText:=SkipModules;
    end;

    if FOnlyModules<>'' then
    begin
      FSequencer.CreateOnly(FOnlyModules);
      result:=FSequencer.Run(_ONLY);
    end
    else
    begin
      aSequence:=_DEFAULT;
      {$ifdef win32}
      // Run Windows specific cross compiler or regular version
      if Pos(_CROSSWIN,SkipModules)=0 then aSequence:=_DEFAULT+'win32';
      {$endif}
      {$ifdef win64}
      //not yet
      //if Pos(_CROSSWIN,SkipModules)=0 then aSequence:=_DEFAULT+'win64';
      {$endif}
      {$IF defined(CPUAARCH64) or defined(CPUARM) or defined(CPUARMHF) or defined(HAIKU) or defined(CPUPOWERPC64)}
      aSequence:=_DEFAULTSIMPLE;
      {$ENDIF}

      result:=FSequencer.Run(aSequence);

      if (FIncludeModules<>'') and (result) then
      begin
        // run specified additional modules using the only mechanism
        FSequencer.CreateOnly(FIncludeModules);
        result:=FSequencer.Run(_ONLY);
      end;
    end;
  finally
    if assigned(FSequencer.FSkipList) then FSequencer.FSkipList.Free;
    FSequencer.FSkipList:=nil;
    FSequencer.DeleteOnly;
  end;
end;

constructor TFPCupManager.Create;
begin
  FVerbose:=false;
  FUseWget:=false;
  FExportOnly:=false;
  FNoJobs:=True;
  FUseGitClient:=false;
  FNativeFPCBootstrapCompiler:=true;
  ForceLocalRepoClient:=false;

  FSoftFloat:=true;
  FOnlinePatching:=false;
  FSwitchURL:=false;
  FSolarisOI:=false;
  FMUSL:=false;
  FAutoTools:=false;

  FCrossOS_Target:=TOS.osNone;
  FCrossCPU_Target:=TCPU.cpuNone;
  FCrossOS_SubArch:=TSUBARCH.saNone;

  {$if (defined(BSD) and not defined(DARWIN)) or (defined(Solaris))}
  FPatchCmd:='gpatch';
  {$else}
  FPatchCmd:='patch'+GetExeExt;
  {$endif}

  FModuleList:=TStringList.Create;
  FModuleEnabledList:=TStringList.Create;
  FModulePublishedList:=TStringList.Create;
  FSequencer:=TSequencer.Create(Self);
  FLog:=TLogger.Create;
  // Log filename will be set on first log write
end;

destructor TFPCupManager.Destroy;
var i:integer;
begin
  for i:=0 to FModuleList.Count-1 do Freemem(FModuleList.Objects[i]);
  FModuleList.Free;
  FModulePublishedList.Free;
  FModuleEnabledList.Free;
  FSequencer.free;
  FLog.Free;
  inherited Destroy;
end;

function TFPCupManager.GetCrossCombo_Target:string;
begin
  result:=GetCPU(CrossCPU_Target)+'-'+GetOS(CrossOS_Target);
  if (CrossOS_SubArch<>TSUBARCH.saNone) then
    result:=result+'-'+GetSubarch(CrossOS_SubArch);
end;

{ TSequencer }

procedure TSequencer.AddToModuleList(ModuleName: string; EntryPoint: integer);
var
  SeqAttr:PSequenceAttributes;
begin
  getmem(SeqAttr,sizeof(TSequenceAttributes));
  SeqAttr^.EntryPoint:=EntryPoint;
  SeqAttr^.Executed:=ESNever;
  FParent.FModuleList.AddObject(ModuleName,TObject(SeqAttr));
end;

function TSequencer.DoCheckModule(ModuleName: string): boolean;
begin
  result:= GetInstaller(ModuleName) and FInstaller.CheckModule(ModuleName);
end;

function TSequencer.DoBuildModule(ModuleName: string): boolean;
begin
  result:= GetInstaller(ModuleName) and FInstaller.BuildModule(ModuleName);
end;

function TSequencer.DoCleanModule(ModuleName: string): boolean;
begin
  result:= GetInstaller(ModuleName) and FInstaller.CleanModule(ModuleName);
end;

function TSequencer.DoConfigModule(ModuleName: string): boolean;
begin
  result:= GetInstaller(ModuleName) and FInstaller.ConfigModule(ModuleName);
end;

function TSequencer.DoExec(FunctionName: string): boolean;

  function CreateFpcupScript:boolean;
  begin
    result:=true;
    // Link to fpcup itself, with all options as passed when invoking it:
    if FParent.ShortCutNameFpcup<>EmptyStr then
    begin
      {$IFDEF MSWINDOWS}
      CreateDesktopShortCut(SafeGetApplicationPath+ExtractFileName(paramstr(0)),FParent.PersistentOptions,FParent.ShortCutNameFpcup);
      {$ELSE}
      FParent.PersistentOptions:=FParent.PersistentOptions+' $*';
      CreateHomeStartLink('"'+SafeGetApplicationPath+ExtractFileName(paramstr(0))+'"',FParent.PersistentOptions,FParent.ShortCutNameFpcup);
      {$ENDIF MSWINDOWS}
      FParent.FShortcutCreated:=true;
    end;
  end;

  {$ifndef FPCONLY}
  function CreateLazarusScript:boolean;
  // Find out InstalledLazarus location, create desktop shortcuts etc
  // Don't use this function when lazarus is not installed.
  var
    InstalledLazarus:string;
  begin
    result:=true;
    if FParent.ShortCutNameLazarus<>EmptyStr then
    begin
      //Infoln('TSequencer.DoExec (Lazarus): creating desktop shortcut:',etInfo);
      try
        // Create shortcut; we don't care very much if it fails=>don't mess with OperationSucceeded
        InstalledLazarus:=IncludeTrailingPathDelimiter(FParent.LazarusInstallDirectory)+'lazarus'+GetExeExt;
        {$IFDEF MSWINDOWS}
        CreateDesktopShortCut(InstalledLazarus,'--pcp="'+FParent.LazarusPrimaryConfigPath+'"',FParent.ShortCutNameLazarus);
        {$ENDIF MSWINDOWS}
        {$IFDEF UNIX}
        {$IFDEF DARWIN}
        CreateHomeStartLink(IncludeLeadingPathDelimiter(InstalledLazarus)+'.app/Contents/MacOS/lazarus','--pcp="'+FParent.LazarusPrimaryConfigPath+'"',FParent.ShortcutNameLazarus);
        {$ELSE}
        CreateHomeStartLink('"'+InstalledLazarus+'"','--pcp="'+FParent.LazarusPrimaryConfigPath+'"',FParent.ShortcutNameLazarus);
        {$ENDIF DARWIN}
        // Desktop shortcut creation will not always work. As a fallback, create the link in the home directory:
        CreateDesktopShortCut(InstalledLazarus,'--pcp="'+FParent.LazarusPrimaryConfigPath+'"',FParent.ShortCutNameLazarus,FParent.Context);
        {$ENDIF UNIX}
        FParent.FShortcutCreated:=true;
      except
        // Ignore problems creating shortcut
        //Infoln('CreateLazarusScript: Error creating shortcuts/links to Lazarus. Continuing.',etWarning);
      end;
    end;
  end;
  function DeleteLazarusScript:boolean;
  begin
  result:=true;
  if FParent.ShortCutNameLazarus<>EmptyStr then
  begin
    //Infoln('TSequencer.DoExec (Lazarus): deleting desktop shortcut:',etInfo);
    try
      //Delete shortcut; we don't care very much if it fails=>don't mess with OperationSucceeded
      {$IFDEF MSWINDOWS}
      DeleteDesktopShortCut(FParent.ShortCutNameLazarus);
      {$ENDIF MSWINDOWS}
      {$IFDEF UNIX}
      SysUtils.DeleteFile(FParent.ShortcutNameLazarus);
      {$ENDIF UNIX}
    finally
      //Ignore problems deleting shortcut
    end;
  end;
  end;

  {$ifdef linux}
  function CheckDevLibs(LCLPlatform: string): boolean;
  const
    LIBSCNT=5;
  type
    TLibList=array[1..LIBSCNT] of string;
    LibSource = record
      lib:string;
      source:string;
    end;

  const
    DEBIAN_INSTALL_COMMAND='sudo apt-get install';

    DEBIAN_LIBS : array [0..16] of string = (
    'unrar',
    'unzip',
    'p7zip',
    'wget',
    'make',
    'gcc',
    'build-essential',
    //'openssl-dev',
    'binutils',
    'gdb',
    'patch',
    'subversion',
    'git',
    'libxtst-dev',
    'libx11-dev',
    'libgtk2.0-dev',
    'libcairo2-dev',
    'libcanberra-gtk-module'
    );

    DEBIAN_LIBS_32 : array [0..5] of string = (
    'libc6-dev-i386',
    'gcc-multilib',
    'libxtst-dev:i386',
    'libpango1-dev:i386',
    'libgtk2.0-dev:i386',
    'libcairo2-dev:i386'
    );

    DEBIAN_LIBS_QT5 : array [0..3] of string = (
    'qt5-qmake',
    'qtbase5-dev',
    'qtbase5-dev-tools',
    'libqt5x11extras5-dev'
    );

    //Mint
    //'qt5-default'
    //'libqt5x11extras5-dev'

    //CentOS
    //qt5-qtbase
    //qt5-qtbase-devel
    //qt5-qtx11extras
    //qt5-qtx11extras-devel


    LCLLIBS:TLibList = ('libX11.so','libgdk_pixbuf-2.0.so','libpango-1.0.so','libcairo.so','libgdk-x11-2.0.so');
    QTLIBS:TLibList = ('libQt4Pas.so.1','','','','');
    QT5LIBS:TLibList = ('libQt5Pas.so.1','','','','');
  var
    i:integer;
    pll:^TLibList;
    Output: string;
    AdvicedLibs:string;
    AllOutput:TStringList;
    LS:array of LibSource;

    function TestLib(const LibName:string):boolean;
    var
      Lib : TLibHandle;
    begin
      result:=true;
      if LibName<>'' then
        begin
        Lib:=LoadLibrary(LibName);
        result:=Lib<>0;
        if result then
          UnloadLibrary(Lib);
        end;
    end;

  begin
    result:=true;

    pll:=nil;

    // these libs are always needed !!
    AdvicedLibs:='make gdb binutils gcc unrar unzip patch wget subversion';

    Output:=GetDistro;
    if (AnsiContainsText(Output,'arch') OR AnsiContainsText(Output,'manjaro')) then
    begin
      Output:='libx11 gtk2 gdk-pixbuf2 pango cairo';
      AdvicedLibs:=AdvicedLibs+'libx11 gtk2 gdk-pixbuf2 pango cairo ibus-gtk and ibus-gtk3 xorg-fonts-100dpi xorg-fonts-75dpi ttf-freefont ttf-liberation unrar';
    end
    else if (AnsiContainsText(Output,'debian') OR AnsiContainsText(Output,'ubuntu') OR AnsiContainsText(Output,'linuxmint')) then
    begin
      {
      SetLength(LS,12);
      LS[0].lib:='libX11.so';
      LS[0].source:='libx11-dev' ;

      LS[1].lib:='libgdk_pixbuf-2.0.so';
      LS[1].source:='libgdk-pixbuf2.0-dev' ;

      LS[2].lib:='libgtk-x11-2.0.so';
      LS[2].source:='libgtk2.0-0';
      LS[3].lib:='libgdk-x11-2.0.so';
      LS[3].source:='libgtk2.0-0';

      LS[4].lib:='libgobject-2.0.so';
      LS[4].source:='libglib2.0-0';

      LS[5].lib:='libglib-2.0.so';
      LS[5].source:='libglib2.0-0';

      LS[6].lib:='libgthread-2.0.so';

      LS[7].lib:='libgmodule-2.0.so';

      LS[8].lib:='libpango-1.0.so';
      LS[8].source:='libpango1.0-dev';

      LS[9].lib:='libcairo.so';
      LS[8].source:='libcairo2-dev';

      LS[10].lib:='libatk-1.0.so';
      LS[10].source:='libatk1.0-dev';

      LS[11].lib:='libpangocairo-1.0.so';
      }
      //apt-get install subversion make binutils gdb gcc libgtk2.0-dev
      {
       libatk1.0
       libc6
       libcairo2
       libgdk-pixbuf2.0
       libglib2.0
       libgtk2.0
       libpango-1.0
       libpangocairo-1.0
       libx11
      }
      Output:='libx11-dev libgtk2.0-dev libcairo2-dev libpango1.0-dev libxtst-dev libgdk-pixbuf2.0-dev libatk1.0-dev libghc-x11-dev';
      AdvicedLibs:=AdvicedLibs+
                   'make binutils build-essential gdb gcc subversion unrar devscripts libc6-dev freeglut3-dev libgl1-mesa libgl1-mesa-dev '+
                   'libglu1-mesa libglu1-mesa-dev libgpmg1-dev libsdl-dev libXxf86vm-dev libxtst-dev '+
                   'libxft2 libfontconfig1 xfonts-scalable gtk2-engines-pixbuf appmenu-gtk-module unrar';
    end
    else
    if (AnsiContainsText(Output,'rhel') OR AnsiContainsText(Output,'centos') OR AnsiContainsText(Output,'scientific') OR AnsiContainsText(Output,'fedora') OR AnsiContainsText(Output,'redhat'))  then
    begin
      Output:='libX11-devel libXtst libXtst-devel gtk2-devel gtk+extra gtk+-devel cairo-devel cairo-gobject-devel pango-devel';
    end
    else
    if AnsiContainsText(Output,'openbsd') then
    begin
      Output:='libiconv xorg-libraries libx11 libXtst xorg-fonts-type1 liberation-fonts-ttf gtkglext wget';
      //Output:='gmake gdk-pixbuf gtk+2';
    end
    else
    if (AnsiContainsText(Output,'freebsd') OR AnsiContainsText(Output,'netbsd')) then
    begin
      Output:='xorg-libraries libX11 libXtst gtkglext iconv xorg-fonts-type1 liberation-fonts-ttf';
    end
    else
    if (AnsiContainsText(Output,'alpine')) then
    begin
      AdvicedLibs:=AdvicedLibs+' musl-dev openssl-dev';
      Output:='the libraries to run xorg and xfce4, but also make, binutils, gcc, musl-dev and openssl-dev';
    end
    else Output:='the libraries to get libX11.so and libgdk_pixbuf-2.0.so and libpango-1.0.so and libgdk-x11-2.0.so, but also make and binutils';

    if Uppercase(LCLPlatform)='QT' then
      pll:=@QTLIBS
    else if Uppercase(LCLPlatform)='QT5' then
      pll:=@QT5LIBS
    else pll:=@LCLLIBS;

    if Assigned(pll) then
    begin
      for i:=1 to LIBSCNT do
      begin
        if not TestLib(pll^[i]) then
        begin
          if result=true then FParent.WritelnLog(etError,'Missing library:', true);
          FParent.WritelnLog(etError, pll^[i], true);
          result:=false;
        end;
      end;
    end;

    if (NOT result) AND (Length(Output)>0) then
    begin
      FParent.WritelnLog(etWarning,'You need to install at least '+Output+' to build Lazarus !!', true);
      FParent.WritelnLog(etWarning,'Make, binutils, git and gdb (optional) are also required !!', true);
    end;

    // do not error out ... user could only install FPC
    result:=true;

  end;
  {$else} //stub for other platforms for now
  function CheckDevLibs({%H-}LCLPlatform: string): boolean;
  begin
    result:=true;
  end;
  {$endif linux}
  {$endif}
var
  WidgetTypeName:string;
begin
  if FunctionName=_CREATEFPCUPSCRIPT then
    result:=CreateFpcupScript
  {$ifndef FPCONLY}
  else if FunctionName=_CREATELAZARUSSCRIPT then
    result:=CreateLazarusScript
  else if FunctionName=_DELETELAZARUSSCRIPT then
    result:=DeleteLazarusScript
  else if FunctionName=_CHECKDEVLIBS then
  begin
    WidgetTypeName:=FParent.LCL_Platform;
    {$IF DEFINED(FPC_FULLVERSION) AND (FPC_FULLVERSION > 30000)}
    if (Length(WidgetTypeName)=0) then WidgetTypeName:=GetLCLWidgetTypeName;
    {$ENDIF}
    FParent.WritelnLog(etInfo,'Checking dev-libs for: '+WidgetTypeName, true);
    result:=CheckDevLibs(WidgetTypeName);
  end
  {$endif}
  else
  begin
    result:=false;
    FParent.WritelnLog('Error: Trying to execute a non existing function: ' + FunctionName);
  end;
end;

function TSequencer.DoGetModule(ModuleName: string): boolean;
begin
  result:= GetInstaller(ModuleName) and FInstaller.GetModule(ModuleName);
end;

function TSequencer.DoSetCPU(aCPU: string): boolean;
begin
  if aCPU=GetTargetCPU
     then FParent.CrossCPU_Target:=TCPU.cpuNone
     else FParent.CrossCPU_Target:=GetTCPU(aCPU);
  ResetAllExecuted;
  result:=true;
end;

function TSequencer.DoSetOS(aOS: string): boolean;
begin
  if aOS=GetTargetOS
     then FParent.CrossOS_Target:=TOS.osNone
     else FParent.CrossOS_Target:=GetTOS(aOS);
  ResetAllExecuted;
  result:=true;
end;

{$ifndef FPCONLY}
function TSequencer.DoResetLCL: boolean;
begin
  ResetAllExecuted(true);
  result:=true;
end;
{$endif}

function TSequencer.DoUnInstallModule(ModuleName: string): boolean;
begin
  result:= GetInstaller(ModuleName) and FInstaller.UnInstallModule(ModuleName);
end;

{GetInstaller gets a new installer for ModuleName and initialises parameters unless one exist already.}

function TSequencer.GetInstaller(ModuleName: string): boolean;
var
  Ultibo,CrossCompiling:boolean;
  aCompiler:string;
  LocalFPCSourceDir:string;
begin
  result:=true;

  Ultibo:=((Pos('github.com/ultibohub',FParent.FPCURL)>0){$ifndef FPCONLY} OR (Pos('github.com/ultibohub',FParent.LazarusURL)>0){$endif});

  CrossCompiling:=(FParent.CrossCPU_Target<>TCPU.cpuNone) OR (FParent.CrossOS_Target<>TOS.osNone);

  //if Ultibo then
  //  LocalFPCSourceDir:=IncludeTrailingPathDelimiter(FParent.FPCSourceDirectory)+'source'
  //else
  LocalFPCSourceDir:=FParent.FPCSourceDirectory;

  //check if this is a known module:

  // FPC:
  if ((ModuleName=_FPC) OR (ModuleName=_MAKEFILECHECKFPC)) then
  begin
    if assigned(FInstaller) then
    begin
      // Check for existing normal compiler, or exact same cross compiler
      if (not CrossCompiling and (FInstaller is TFPCNativeInstaller)) or
        ( CrossCompiling and
        (FInstaller is TFPCCrossInstaller) and
        (TFPCCrossInstaller(FInstaller).CrossInstaller.TargetOS=FParent.CrossOS_Target) and
        (TFPCCrossInstaller(FInstaller).CrossInstaller.TargetCPU=FParent.CrossCPU_Target)
        ) then
      begin
        exit; //all fine, continue with current FInstaller
      end
      else
        FInstaller.Free; // get rid of old FInstaller
    end;

    if CrossCompiling then
      FInstaller:=TFPCCrossInstaller.Create
    else
      FInstaller:=TFPCNativeInstaller.Create;

    (FInstaller as TFPCInstaller).BootstrapCompilerDirectory:=FParent.BootstrapCompilerDirectory;
    (FInstaller as TFPCInstaller).SourcePatches:=FParent.FPCPatches;
    (FInstaller as TFPCInstaller).PreInstallScriptPath:=FParent.FPCPreInstallScriptPath;
    (FInstaller as TFPCInstaller).PostInstallScriptPath:=FParent.FPCPostInstallScriptPath;

    (FInstaller as TFPCInstaller).SoftFloat:=FParent.SoftFloat;
    if FParent.MUSL then
      (FInstaller as TFPCInstaller).NativeFPCBootstrapCompiler:=false
    else
      (FInstaller as TFPCInstaller).NativeFPCBootstrapCompiler:=FParent.NativeFPCBootstrapCompiler;
    FInstaller.CompilerOptions:=FParent.FPCOPT;
    FInstaller.DesiredRevision:=FParent.FPCDesiredRevision;
    FInstaller.URL:=FParent.FPCURL;
    FInstaller.Branch:=FParent.FPCBranch;
    FInstaller.TAG:=FParent.FPCTag;
  end

  {$ifndef FPCONLY}
  // Lazarus:
  else
    if (ModuleName=_LAZARUS)
    or (ModuleName=_STARTLAZARUS)
    or (ModuleName=_LAZBUILD)
    or (ModuleName=_LCL)
    or (ModuleName=_COMPONENTS)
    or (ModuleName=_PACKAGER)
    or (ModuleName=_LCLCROSS)
    or (ModuleName=_IDE)
    or (ModuleName=_BIGIDE)
    or (ModuleName=_USERIDE)
    or (ModuleName=_INSTALLLAZARUS)
    or (ModuleName=_MAKEFILECHECKLAZARUS)
    or (ModuleName=_CONFIG+_LAZARUS)
  then
  begin
    if assigned(FInstaller) then
      begin
      if (not CrossCompiling and (FInstaller is TLazarusNativeInstaller)) or
        (CrossCompiling and (FInstaller is TLazarusCrossInstaller)) then
      begin
        exit; //all fine, continue with current FInstaller
      end
      else
        FInstaller.free; // get rid of old FInstaller
      end;

    if CrossCompiling then
      FInstaller:=TLazarusCrossInstaller.Create
    else
      FInstaller:=TLazarusNativeInstaller.Create;

    FInstaller.CompilerOptions:=FParent.LazarusOPT;

    FInstaller.DesiredRevision:=FParent.LazarusDesiredRevision;
    // LCL_Platform is only used when building LCL, but the Lazarus module
    // will take care of that.
    (FInstaller as TLazarusInstaller).LCL_Platform:=FParent.LCL_Platform;
    (FInstaller as TLazarusInstaller).SourcePatches:=FParent.LazarusPatches;
    (FInstaller as TLazarusInstaller).PreInstallScriptPath:=FParent.LazarusPreInstallScriptPath;
    (FInstaller as TLazarusInstaller).PostInstallScriptPath:=FParent.LazarusPostInstallScriptPath;

    FInstaller.URL:=FParent.LazarusURL;
    FInstaller.Branch:=FParent.LazarusBranch;
    FInstaller.TAG:=FParent.LazarusTag;
  end

  //Convention: help modules start with HelpFPC
  //or HelpLazarus
  {$endif}
  else if ModuleName=_HELPFPC
  then
  begin
    CrossCompiling:=false;
    if assigned(FInstaller) then
    begin
      if (FInstaller is THelpFPCInstaller) then
      begin
        exit; //all fine, continue with current FInstaller
      end
      else
        FInstaller.free; // get rid of old FInstaller
      end;
    FInstaller:=THelpFPCInstaller.Create;
  end
  {$ifndef FPCONLY}
  else if ModuleName=_HELPLAZARUS
  then
  begin
    CrossCompiling:=false;
    if assigned(FInstaller) then
    begin
      if (FInstaller is THelpLazarusInstaller) then
      begin
        exit; //all fine, continue with current FInstaller
      end
      else
        FInstaller.free; // get rid of old FInstaller
    end;
    FInstaller:=THelpLazarusInstaller.Create;
  end
  {$endif}
  else       // this is a universal module
  begin
      CrossCompiling:=false;
      if assigned(FInstaller) then
      begin
        if (FInstaller.InheritsFrom(TUniversalInstaller)) and
          (FCurrentModule=ModuleName) then
        begin
          exit; //all fine, continue with current FInstaller
        end
        else
          FInstaller.free; // get rid of old FInstaller
      end;

      case ModuleName of
        'awgg'             : FInstaller:=TAWGGInstaller.Create;
        'mORMotPXL'        : FInstaller:=TmORMotPXLInstaller.Create;
        'internettools'    : FInstaller:=TInternetToolsInstaller.Create;
        'develtools4fpc'   : FInstaller:=TDeveltools4FPCInstaller.Create;
        'xtensatools4fpc'  : FInstaller:=TXTensaTools4FPCInstaller.Create;
        'mbf-freertos-wio' : FInstaller:=TMBFFreeRTOSWioInstaller.Create;
        'mORMot2'          : FInstaller:=TmORMot2Installer.Create;
        'wst'              : FInstaller:=TWSTInstaller.Create;
        'pas2js-rtl'       : FInstaller:=TPas2jsInstaller.Create;
      else
        FInstaller:=TUniversalInstaller.Create;
      end;
      FCurrentModule:=ModuleName;
      // Use compileroptions for chosen FPC compile options...
      FInstaller.CompilerOptions:=FParent.FPCOPT;
      {$ifndef FPCONLY}
      (FInstaller as TUniversalInstaller).LazarusCompilerOptions:=FParent.FLazarusOPT;
      (FInstaller as TUniversalInstaller).LCL_Platform:=FParent.LCL_Platform;
      {$endif}
  end;

  if assigned(FInstaller) then
  begin
    FInstaller.BaseDirectory:=FParent.BaseDirectory;
    FInstaller.FPCSourceDir:=LocalFPCSourceDir;
    FInstaller.FPCInstallDir:=FParent.FPCInstallDirectory;
    {$ifndef FPCONLY}
    FInstaller.LazarusSourceDir:=FParent.LazarusSourceDirectory;
    FInstaller.LazarusInstallDir:=FParent.LazarusInstallDirectory;
    FInstaller.LazarusPrimaryConfigPath:=FParent.LazarusPrimaryConfigPath;
    {$endif}
    FInstaller.TempDirectory:=FParent.TempDirectory;
    {$IFDEF MSWINDOWS}
    FInstaller.SVNClient.ForceLocal:=FParent.ForceLocalRepoClient;
    FInstaller.GitClient.ForceLocal:=FParent.ForceLocalRepoClient;
    FInstaller.HGClient.ForceLocal:=FParent.ForceLocalRepoClient;
    {$ENDIF}
    FInstaller.HTTPProxyHost:=FParent.HTTPProxyHost;
    FInstaller.HTTPProxyPort:=FParent.HTTPProxyPort;
    FInstaller.HTTPProxyUser:=FParent.HTTPProxyUser;
    FInstaller.HTTPProxyPassword:=FParent.HTTPProxyPassword;
    FInstaller.KeepLocalChanges:=FParent.KeepLocalChanges;
    FInstaller.ReApplyLocalChanges:=FParent.ReApplyLocalChanges;
    if Length(FParent.PatchCmd)>0 then FInstaller.PatchCmd:=FParent.PatchCmd;
    FInstaller.Verbose:=FParent.Verbose;

    aCompiler:='';
    if FInstaller.InheritsFrom(TFPCInstaller) then
    begin
      // override bootstrapper only for FPC if needed
      if FParent.CompilerOverride<>'' then aCompiler:=FParent.CompilerOverride;
    end
    else
    begin
      if FParent.UseSystemFPC then aCompiler:=Which('fpc');
      if (NOT FParent.UseSystemFPC) OR (Length(aCompiler)=0) then aCompiler:=FInstaller.GetFPCInBinDir; // use FPC compiler itself
    end;
    FInstaller.Compiler:=aCompiler;

    // only curl / wget works on OpenBSD (yet)
    {$IFDEF OPENBSD}
    FInstaller.UseWget:=True;
    {$ELSE}
    FInstaller.UseWget:=FParent.UseWget;
    {$ENDIF}
    FInstaller.ExportOnly:=FParent.ExportOnly;
    FInstaller.NoJobs:=FParent.NoJobs;
    FInstaller.OnlinePatching:=FParent.OnlinePatching;
    FInstaller.Log:=FParent.FLog;
    FInstaller.MakeDirectory:=FParent.MakeDirectory;
    FInstaller.SwitchURL:=FParent.SwitchURL;
    if FParent.SolarisOI then FInstaller.SolarisOI:=true {else if FInstaller.SolarisOI then FParent.SolarisOI:=true};
    if FParent.MUSL then FInstaller.MUSL:=true {else if FInstaller.MUSL then FParent.MUSL:=true};
    FInstaller.Ultibo:=Ultibo;

    if CrossCompiling then
    begin
      // The below is used to get the right cross-installer !!
      // By setting the target.
      FInstaller.SetTarget(FParent.CrossCPU_Target,FParent.CrossOS_Target,FParent.CrossOS_SubArch);
      FInstaller.CrossOPT:=FParent.CrossOPT;
      if AnsiContainsText(FParent.CrossOPT,'-CAEABIHF') then
        FInstaller.SetABI(TABI.eabihf)
      else
        if AnsiContainsText(FParent.CrossOPT,'-CAEABI') then
          FInstaller.SetABI(TABI.eabi)
      else
        FInstaller.SetABI(TABI.default);
      FInstaller.CrossLibraryDirectory:=FParent.CrossLibraryDirectory;
      FInstaller.CrossToolsDirectory:=FParent.CrossToolsDirectory;
    end

  end;
end;

function TSequencer.GetText: string;
var
  i:integer;
begin
  result:='';
  for i:=Low(FStateMachine) to High(FStateMachine) do
  begin
    // todo: add translation of instr
    result:=result+
      'Instruction number: '+IntToStr(ord(FStateMachine[i].instr))+' '+
      FStateMachine[i].param;
    if i<High(FStateMachine) then
      result:=result+LineEnding;
  end;
end;

function TSequencer.IsSkipped(ModuleName: string): boolean;
begin
  try
    result:=assigned(FSkipList) and (FSkipList.IndexOf(ModuleName)>=0);
  except
    result:=false;
  end;
end;

procedure TSequencer.ResetAllExecuted(SkipFPC: boolean);
var
  idx:integer;
begin
  for idx:=0 to FParent.FModuleList.Count -1 do
    // convention: FPC sequences that are to be skipped start with 'FPC'. Used in SetLCL.
    // todo: skip also help???? Who would call several help installs in one sequence? SubSequences?
    if not SkipFPC or (pos(_FPC,FParent.FModuleList[idx])<>1) then
      PSequenceAttributes(FParent.FModuleList.Objects[idx])^.Executed:=ESNever;
end;

function TSequencer.AddSequence(Sequence: string): boolean;
//our mini parser
var
  line,key,param:string;
  PackageSettings:TStringList;
  i,j:integer;
  instr:TKeyword;
  sequencename:string='';

  function KeyStringToKeyword(Key:string):TKeyword;
  begin
    if key=Trim(_DECLARE) then result:=SMdeclare
    else if key=Trim(_DECLAREHIDDEN) then result:=SMdeclareHidden
    else if key=Trim(_DO) then result:=SMdo
    else if key=Trim(_REQUIRES) then result:=SMrequire
    else if key=Trim(_EXECUTE) then result:=SMexec
    else if key=Trim(_ENDFINAL) then result:=SMend
    else if key=Trim(_CLEANMODULE) then result:=SMcleanmodule
    else if key=Trim(_GETMODULE) then result:=SMgetmodule
    else if key=Trim(_BUILDMODULE) then result:=SMbuildmodule
    else if key=Trim(_CHECKMODULE) then result:=SMcheckmodule
    else if key=Trim(_UNINSTALLMODULE) then result:=SMuninstallmodule
    else if key=Trim(_CONFIGMODULE) then result:=SMconfigmodule
    {$ifndef FPCONLY}
    else if key=Trim(_RESETLCL) then result:=SMResetLCL
    {$endif}
    else if key=Trim(_SETOS) then result:=SMSetOS
    else if key=Trim(_SETCPU) then result:=SMSetCPU
    else result:=SMInvalid;
  end;

  //remove white space and line terminator
  function NoWhite(s:string):string;
  begin
    while (s[1]<=' ') or (s[1]=_SEP) do delete(s,1,1);
    while (s[length(s)]<=' ') or (s[length(s)]=_SEP) do delete(s,length(s),1);
    result:=s;
  end;

begin
while Sequence<>'' do
begin
  i:=pos(_SEP,Sequence);
  if i>0 then
    line:=copy(Sequence,1,i-1)
  else
    line:=Sequence;
  delete(Sequence,1,length(line)+1);
  line:=NoWhite(line);
  if line<>'' then
  begin
    i:=pos(' ',line);
    if i>0 then
    begin
      key:=copy(line,1,i-1);
      param:=NoWhite(copy(line,i,length(line)));
    end
    else
    begin
      key:=line;
      param:='';
    end;
    key:=NoWhite(key);
    if key<>'' then
    begin
      i:=Length(FStateMachine);
      SetLength(FStateMachine,i+1);
      instr:=KeyStringToKeyword(Trim(Key));
      FStateMachine[i].instr:=instr;
      if instr=SMInvalid then
        FParent.WritelnLog('Invalid instruction '+Key+' in sequence '+sequencename);
      FStateMachine[i].param:=param;
      if instr in [SMdeclare,SMdeclareHidden] then
      begin
        AddToModuleList(param,i);
        sequencename:=param;
      end;
      if instr = SMdeclare then
      begin
        key:='';
        if (Pos(_CLEAN,param)=0) AND (Pos(_UNINSTALL,param)=0) AND (Pos(_DEFAULT,param)=0) then
        begin
          j:=UniModuleList.IndexOf(param);
          if j>=0 then
          begin
            PackageSettings:=TStringList(UniModuleList.Objects[j]);
            key:=StringReplace(PackageSettings.Values[installerUniversal.INIKEYWORD_DESCRIPTION],'"','',[rfReplaceAll]);;
          end;
        end;
        with FParent.FModulePublishedList do Add(Concat(param, NameValueSeparator, key));
      end;
    end;
  end;
end;
result:=true;
end;


// create the sequence corresponding with the only parameters
function TSequencer.CreateOnly(OnlyModules: string): boolean;
var
  i:integer;
  seq:string;

begin
  AddToModuleList(_ONLY,Length(FStateMachine));
  while Onlymodules<>'' do
  begin
    i:=pos(',',Onlymodules);
    if i>0 then
      seq:=copy(Onlymodules,1,i-1)
    else
      seq:=Onlymodules;
    delete(Onlymodules,1,length(seq)+1);
    // We could build a sequence string and have it parsed by AddSequence.
    // Pro: no dependency on FStateMachine structure
    // Con: dependency on sequence format; double parsing
    if seq<>'' then
    begin
      i:=Length(FStateMachine);
      SetLength(FStateMachine,i+1);
      FStateMachine[i].instr:=SMdo;
      FStateMachine[i].param:=seq;
    end;
  end;
  i:=Length(FStateMachine);
  SetLength(FStateMachine,i+1);
  FStateMachine[i].instr:=SMend;
  FStateMachine[i].param:='';
  result:=true;
end;

function TSequencer.DeleteOnly: boolean;
var i,idx:integer;
  SeqAttr:^TSequenceAttributes;
begin
  idx:=FParent.FModuleList.IndexOf(_ONLY);
  if (idx >0) then
  begin
    SeqAttr:=PSequenceAttributes(pointer(FParent.FModuleList.Objects[idx]));
    i:=SeqAttr^.EntryPoint;
    while i<length(FStateMachine) do
    begin
      FStateMachine[i].param:='';
      i:=i+1;
    end;
    SetLength(FStateMachine,SeqAttr^.EntryPoint);
    Freemem(FParent.FModuleList.Objects[idx]);
    FParent.FModuleList.Delete(idx);
  end;
  result:=true;
end;

function TSequencer.Run(SequenceName: string): boolean;
var
  {$IFDEF DEBUG}
  EntryPoint:integer;
  {$ENDIF DEBUG}
  InstructionPointer:integer;
  idx:integer;
  SeqAttr:^TSequenceAttributes;
  localinfotext:string;
begin
  result:=true;
  localinfotext:=TrimLeft(Copy(UnCamel(Self.ClassName),2,MaxInt))+' ('+SequenceName+'): ';
  try
    if not assigned(FParent.FModuleList) then
    begin
      result:=false;
      FParent.WritelnLog(etError,localinfotext+'No sequences loaded while trying to find sequence name ' + SequenceName);
      FParent.RunInfo:=localinfotext+'No sequences loaded while trying to find sequence name ' + SequenceName;
      exit;
    end;
    // --clean or --install ??
    if FParent.Uninstall then  // uninstall overrides clean
    begin
      if (SequenceName<>_ONLY) and (NOT AnsiEndsText(_UNINSTALL,SequenceName)) then
        SequenceName:=SequenceName+_UNINSTALL;
    end
    else if FParent.Clean  then
    begin
      if (SequenceName<>_ONLY) and (NOT AnsiEndsText(_CLEAN,SequenceName)) then
        SequenceName:=SequenceName+_CLEAN;
    end;
    // find sequence
    idx:=FParent.FModuleList.IndexOf(SequenceName);
    if (idx>=0) then
    begin
      result:=true;
      SeqAttr:=PSequenceAttributes(pointer(FParent.FModuleList.Objects[idx]));
      // Don't run sequence if already run
      case SeqAttr^.Executed of
        ESFailed : begin
          FParent.RunInfo:=localinfotext+'Already ran sequence name '+SequenceName+' ending in failure. Not running again.';
          result:=false;
          exit;
          end;
        ESSucceeded : begin
          exit;
          end;
        end;
      // Get entry point in FStateMachine
      InstructionPointer:=SeqAttr^.EntryPoint;
      {$IFDEF DEBUG}
      EntryPoint:=InstructionPointer;
      {$ENDIF DEBUG}
      // run sequence until end or failure
      while true do
      begin
        case FStateMachine[InstructionPointer].instr of
          SMdeclare     :;
          SMdeclareHidden :;
          SMdo          : if not IsSkipped(FStateMachine[InstructionPointer].param) then
                            result:=Run(FStateMachine[InstructionPointer].param);
          SMrequire     : result:=Run(FStateMachine[InstructionPointer].param);
          SMexec        : result:=DoExec(FStateMachine[InstructionPointer].param);
          SMend         : begin
                            SeqAttr^.Executed:=ESSucceeded;
                            exit; //success
                          end;
          SMcleanmodule : result:=DoCleanModule(FStateMachine[InstructionPointer].param);
          SMgetmodule   : result:=DoGetModule(FStateMachine[InstructionPointer].param);
          SMbuildmodule : result:=DoBuildModule(FStateMachine[InstructionPointer].param);
          SMcheckmodule : result:=DoCheckModule(FStateMachine[InstructionPointer].param);
          SMuninstallmodule: result:=DoUnInstallModule(FStateMachine[InstructionPointer].param);
          SMconfigmodule: result:=DoConfigModule(FStateMachine[InstructionPointer].param);
          {$ifndef FPCONLY}
          SMResetLCL    : DoResetLCL;
          {$endif}
          SMSetOS       : DoSetOS(FStateMachine[InstructionPointer].param);
          SMSetCPU      : DoSetCPU(FStateMachine[InstructionPointer].param);
        end;
        if (NOT result) OR (SeqAttr^.Executed=ESFailed) then
        begin
          SeqAttr^.Executed:=ESFailed;
          {$IFDEF DEBUG}
          FParent.WritelnLog(etError,localinfotext+'Failure running '+BeginSnippet+' error executing sequence '+SequenceName+
            '; instr: '+GetEnumNameSimple(TypeInfo(TKeyword),Ord(FStateMachine[InstructionPointer].instr))+
            '; line: '+IntTostr(InstructionPointer - EntryPoint+1)+
            ', param: '+FStateMachine[InstructionPointer].param);
          {$ENDIF DEBUG}
          FParent.RunInfo:=localinfotext+'Failure running '+BeginSnippet+' error executing sequence '+SequenceName;
          exit; //failure, bail out
        end;
        InstructionPointer:=InstructionPointer+1;
        if InstructionPointer>=length(FStateMachine) then  //somebody forgot end
        begin
          SeqAttr^.Executed:=ESSucceeded;
          exit; //success
        end;
      end;
    end
    else
    begin
      result:=false;  // sequence not found
      FParent.WritelnLog(localinfotext+'Failed to load sequence :' + SequenceName);
      FParent.RunInfo:=localinfotext+'Failed to load sequence :' + SequenceName;
    end;
  finally
    if Assigned(FInstaller) then
    begin
      FInstaller.Destroy;
      FInstaller:=nil;
    end;
  end;
end;

function TSequencer.Kill: boolean;
  var
    idx:integer;
begin
  result:=false;

  if Assigned(Installer) AND Assigned(Installer.Processor) then
  begin
    Installer.Processor.Terminate;
  end;

  //Set all to failed to halt the statemachine
  for idx:=0 to FParent.FModuleList.Count -1 do
    PSequenceAttributes(FParent.FModuleList.Objects[idx])^.Executed:=ESFailed;

  FParent.RunInfo:='Process forcefully interrupted by user.';
end;

constructor TSequencer.Create(aParent:TFPCupManager);
begin
  inherited Create;
  FParent:=aParent;
end;

destructor TSequencer.Destroy;
begin
  inherited Destroy;
end;

end.

