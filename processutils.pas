unit processutils;

{$mode objfpc}{$H+}

{$ifdef LCL}
{$define THREADEDEXECUTE}
{$endif}

interface

uses
  Classes, SysUtils,
  Process;

const
  {$ifdef LCL}
  BeginSnippet='fpcupdeluxe:'; //helps identify messages as coming from fpcupdeluxe instead of make etc
  {$else}
  {$ifndef FPCONLY}
  BeginSnippet='fpclazup:'; //helps identify messages as coming from fpclazup instead of make etc
  {$else}
  BeginSnippet='fpcup:'; //helps identify messages as coming from fpcup instead of make etc
  {$endif}
  {$endif}

  {$IFDEF MSWINDOWS}
  PATHVARNAME = 'Path'; //Name for path environment variable
  {$ELSE}
  //Unix/Linux
  PATHVARNAME = 'PATH';
  {$ENDIF MSWINDOWS}

resourcestring
  lisExitCode = 'Exit code %s';
  lisToolHasNoExecutable = 'tool "%s" has no executable';
  lisCanNotFindExecutable = 'cannot find executable "%s"';
  lisMissingExecutable = 'missing executable "%s"';
  lisExecutableIsADirectory = 'executable "%s" is a directory';
  lisExecutableLacksThePermissionToRun = 'executable "%s" lacks the permission to run';
  lisSuccess = 'Success';
  lisAborted = 'Aborted';
  lisCanNotExecute = 'cannot execute "%s"';
  lisMissingDirectory = 'missing directory "%s"';
  lisUnableToExecute = 'unable to execute: %s';
  lisUnableToReadProcessExitStatus = 'unable to read process ExitStatus';
  lisFreeingBufferLines = 'freeing buffer lines: %s';

const
  AbortedExitCode = 12321;

type
  { TProcessEnvironment }

  TProcessEnvironment = class(TObject)
  private
    FEnvironmentList:TStringList;
    FCaseSensitive:boolean;
    function GetVarIndex(VarName:string):integer;
  public
    // Get environment variable
    function GetVar(VarName:string):string;
    // Set environment variable
    procedure SetVar(VarName,VarValue:string);
    // List of all environment variables (name and value)
    property EnvironmentList:TStringList read FEnvironmentList;
    constructor Create;
    destructor Destroy; override;
  end;

  TExternalToolStage = (
    etsInit,            // just created, set your parameters, then call Execute
    etsInitializing,    // set in Execute, during resolving macros
    etsWaitingForStart, // waiting for a process slot
    etsStarting,        // creating the thread and process
    etsRunning,         // process started
    etsWaitingForStop,  // waiting for process to stop
    etsStopped,         // process has stopped
    etsDestroying       // during destructor
    );
  TExternalToolStages = set of TExternalToolStage;

  TExternalToolNewOutputEvent = procedure(Sender: TObject;
                                          FirstNewMsgLine: integer) of object;

  TExternalToolHandler = (
    ethNewOutput,
    ethStopped
    );

  TAbstractExternalTool = class(TComponent)
  private
    FCritSec: TRTLCriticalSection;
    FData: TObject;
    FExitCode: integer;
    FExitStatus: integer;
    FFreeData: boolean;
    FReadStdOutBeforeErr: boolean;
    FTitle: string;
    FProcessEnvironment:TProcessEnvironment;
    FCmdLineExe: string;
    function GetCmdLineParams: string;
    procedure SetCmdLineParams(aParams: string);
    procedure SetCmdLineExe(aExe: string);
    procedure SetTitle(const AValue: string);
    procedure RunEvent(Sender,Context : TObject;Status:TRunCommandEventCode;const Message:string);
  protected
    FErrorMessage: string;
    FTerminated: boolean;
    FStage: TExternalToolStage;
    FWorkerOutput: TStringList;
    FProcess: TProcess;
    function GetProcessEnvironment: TProcessEnvironment;
    procedure DoExecute; virtual; abstract;
    function CanFree: boolean; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EnterCriticalSection;
    procedure LeaveCriticalSection;
    procedure AutoFree;

    property Title: string read FTitle write SetTitle;
    property Data: TObject read FData write FData;
    property FreeData: boolean read FFreeData write FFreeData default false;

    // process
    property Process: TProcess read FProcess;
    property Executable: string read FCmdLineExe write SetCmdLineExe;
    property CmdLineParams: string read GetCmdLineParams write SetCmdLineParams;
    property Stage: TExternalToolStage read FStage;
    procedure Execute; virtual; abstract;
    procedure Terminate; virtual; abstract;
    procedure WaitForExit; virtual; abstract;
    property Terminated: boolean read FTerminated;
    property ExitCode: integer read FExitCode write FExitCode;
    property ExitStatus: integer read FExitStatus write FExitStatus;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property ReadStdOutBeforeErr: boolean read FReadStdOutBeforeErr write FReadStdOutBeforeErr;
    property Environment:TProcessEnvironment read GetProcessEnvironment;

    // output
    property WorkerOutput: TStringList read FWorkerOutput; // the raw output
  end;

  TExternalTool = class;

  { TExternalToolThread }

  {$ifdef THREADEDEXECUTE}
  TExternalToolThread = class(TThread)
  {$else}
  TExternalToolThread = class(TObject)
  {$endif}
  private
    fLines: TStringList;
    FTool: TExternalTool;
    procedure SetTool(AValue: TExternalTool);
  public
    property Tool: TExternalTool read FTool write SetTool;
    {$ifdef THREADEDEXECUTE}
    procedure Execute; override;
    {$else}
    procedure Execute;
    {$endif}
    destructor Destroy; override;
  end;

  { TExternalTool }

  TExternalTool = class(TAbstractExternalTool)
  private
    FThread: TExternalToolThread;
    FVerbose:boolean;
    procedure ProcessRunning;
    procedure ProcessStopped;
    procedure AddOutputLines(Lines: TStringList);
    procedure SetThread(AValue: TExternalToolThread);
    procedure DoTerminate;
    procedure SyncAutoFree({%H-}aData: PtrInt=0);
  protected
    procedure DoExecute; override;
    procedure DoStart;
    function CanFree: boolean; override;
    procedure QueueAsyncAutoFree;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
    property Thread: TExternalToolThread read FThread write SetThread;
    property Verbose: boolean read FVerbose write FVerbose;
    procedure Execute; override;
    procedure Terminate; override;
    procedure WaitForExit; override;
    function GetExeInfo:string;
    function CanStart: boolean;
    function ExecuteAndWait:integer;
  end;

  procedure ThreadLog(const aMsg: string;{%H-}const aEvent:TEventType=etInfo);

implementation

uses
  {$ifdef LCL}
  Forms,
  Controls, // for crHourGlass
  LCLIntf,
  LMessages,
  {$endif}
  Pipes,
  Math,
  FileUtil,
  LazFileUtils;


{ TProcessEnvironment }

function TProcessEnvironment.GetVarIndex(VarName: string): integer;
var
  idx:integer;

  function ExtractVar(VarVal:string):string;
  begin
    result:='';
    if length(Varval)>0 then
      begin
      if VarVal[1] = '=' then //windows
        delete(VarVal,1,1);
      result:=trim(copy(VarVal,1,pos('=',VarVal)-1));
      if not FCaseSensitive then
        result:=UpperCase(result);
      end
  end;

begin
  if (Length(VarName)=0) then
  begin
    result:=-1;
  end
  else
  begin
    if not FCaseSensitive then
      VarName:=UpperCase(VarName);
    idx:=0;
    while idx<FEnvironmentList.Count  do
    begin
      if VarName = ExtractVar(FEnvironmentList[idx]) then
        break;
      idx:=idx+1;
    end;
    if idx<FEnvironmentList.Count then
      result:=idx
    else
      result:=-1;
  end;
end;

function TProcessEnvironment.GetVar(VarName: string): string;
var
  idx:integer;

  function ExtractVal(VarVal:string):string;
  begin
    result:='';
    if length(Varval)>0 then
      begin
      if VarVal[1] = '=' then //windows
        delete(VarVal,1,1);
      result:=trim(copy(VarVal,pos('=',VarVal)+1,length(VarVal)));
      end
  end;

begin
  idx:=GetVarIndex(VarName);
  if idx>=0 then
    result:=ExtractVal(FEnvironmentList[idx])
  else
    result:='';
end;

procedure TProcessEnvironment.SetVar(VarName, VarValue: string);
var
  idx:integer;
  s:string;
begin
  if (Length(VarName)=0) OR (Length(VarValue)=0) then exit;
  idx:=GetVarIndex(VarName);
  s:=trim(Varname)+'='+trim(VarValue);
  if idx>=0 then
    FEnvironmentList[idx]:=s
  else
    FEnvironmentList.Add(s);
end;

constructor TProcessEnvironment.Create;
var
  i: integer;
begin
  FEnvironmentList:=TStringList.Create;
  {$ifdef WINDOWS}
  FCaseSensitive:=false;
  {$else}
  FCaseSensitive:=true;
  {$endif WINDOWS}
  // GetEnvironmentVariableCount is 1 based
  for i:=1 to GetEnvironmentVariableCount do
    EnvironmentList.Add(trim(GetEnvironmentString(i)));
end;

destructor TProcessEnvironment.Destroy;
begin
  FEnvironmentList.Free;
  inherited Destroy;
end;

{ TAbstractExternalTool }

function TAbstractExternalTool.GetCmdLineParams: string;
var
  i: Integer;
begin
  Result:='';
  if Process.Parameters=nil then exit;
  for i:=0 to Pred(Process.Parameters.Count) do
  begin
    if i>0 then Result+=' ';
    Result:=Result+Process.Parameters[i];
  end;
end;

procedure TAbstractExternalTool.SetCmdLineParams(aParams: string);
var
  sl: TStringList;
begin
  sl:=TStringList.Create;
  try
    SplitCmdLineParams(aParams,sl);
    Process.Parameters:=sl;
  finally
    sl.Free;
  end;
end;

procedure TAbstractExternalTool.SetCmdLineExe(aExe: string);
begin
  FCmdLineExe:=aExe;
  Process.Executable:=FCmdLineExe;
end;

procedure TAbstractExternalTool.SetTitle(const AValue: string);
begin
  if FTitle=AValue then exit;
  FTitle:=AValue;
end;

procedure TAbstractExternalTool.RunEvent(Sender,Context : TObject;Status:TRunCommandEventCode;const Message:string);
begin
  if MainThreadID=ThreadID then
  begin
    //if IsMultiThread then
    {$ifdef LCL}
    Application.ProcessMessages;
    {$else}
    CheckSynchronize(0);
    {$endif}
  end;
  if status=RunCommandIdle then
    sleep(Process.RunCommandSleepTime);
end;

function TAbstractExternalTool.CanFree: boolean;
begin
  Result:=false;
  if csDestroying in ComponentState then exit;
  if (Process<>nil) and (Process.Running) then
    exit;
  Result:=true;
end;

constructor TAbstractExternalTool.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FStage:=etsInit;
  InitCriticalSection(FCritSec);
end;

destructor TAbstractExternalTool.Destroy;
begin
  EnterCriticalSection;
  try
    if FreeData then FreeAndNil(FData);
    if assigned(FProcessEnvironment) then FProcessEnvironment.Free;
  finally
    LeaveCriticalsection;
  end;
  DoneCriticalSection(FCritSec);
  inherited Destroy;
end;

procedure TAbstractExternalTool.EnterCriticalSection;
begin
  System.EnterCriticalsection(FCritSec);
end;

procedure TAbstractExternalTool.LeaveCriticalSection;
begin
  System.LeaveCriticalsection(FCritSec);
end;

procedure TAbstractExternalTool.AutoFree;
begin
  if MainThreadID<>GetCurrentThreadId then
    raise Exception.Create('AutoFree only via main thread');
  if CanFree then
    Free;
end;

function TAbstractExternalTool.GetProcessEnvironment: TProcessEnvironment;
begin
  If not assigned(FProcessEnvironment) then
    FProcessEnvironment:=TProcessEnvironment.Create;
  result:=FProcessEnvironment;
end;

{ TExternalTool }

procedure TExternalTool.ProcessRunning;
begin
  EnterCriticalSection;
  try
    if FStage<>etsStarting then exit;
    FStage:=etsRunning;
  finally
    LeaveCriticalSection;
  end;
end;

procedure TExternalTool.ProcessStopped;
begin
  EnterCriticalSection;
  try
    if (not Terminated) and (ErrorMessage='') then
    begin
      if ExitCode<>0 then
        ErrorMessage:=Format(lisExitCode, [IntToStr(ExitCode)])
      else if ExitStatus<>0 then
        ErrorMessage:='ExitStatus '+IntToStr(ExitStatus);
    end;
    if FStage>=etsStopped then exit;
    if Assigned(FProcessEnvironment) then FProcessEnvironment.Destroy;
    FProcessEnvironment:=nil;
    FVerbose:=True;
    FStage:=etsStopped;
  finally
    LeaveCriticalSection;
  end;
  {$ifndef THREADEDEXECUTE}
  Thread.Destroy;
  {$endif}
  fThread:=nil;
end;

procedure TExternalTool.AddOutputLines(Lines: TStringList);
var
  Line: LongInt;
  OldOutputCount: LongInt;
  LineStr: String;
begin
  if (Lines=nil) or (Lines.Count=0) then exit;
  EnterCriticalSection;
  try
    OldOutputCount:=WorkerOutput.Count;
    WorkerOutput.AddStrings(Lines);
    for Line:=OldOutputCount to WorkerOutput.Count-1 do
    begin
      LineStr:=WorkerOutput[Line];
      if IsMultiThread then
      begin
      end;
      if Verbose
      //OR (NOT IsMultiThread)
      //{$ifdef LCL}OR True{$endif}
      then
      begin
        ThreadLog(LineStr);
      end;
    end;
  finally
    LeaveCriticalSection;
  end;
end;

procedure TExternalTool.SetThread(AValue: TExternalToolThread);
var
  CallAutoFree: Boolean;
begin
  // Note: in lazbuild ProcessStopped sets FThread:=nil, so SetThread is not called.
  EnterCriticalSection;
  try
    if FThread=AValue then Exit;
    FThread:=AValue;
    CallAutoFree:=CanFree;
  finally
    LeaveCriticalSection;
  end;
  if CallAutoFree then
  begin
    if MainThreadID=GetCurrentThreadId then
      AutoFree
    else
      QueueAsyncAutoFree;
  end;
end;

constructor TExternalTool.Create(aOwner: TComponent);
begin
  inherited Create(aOwner);
  FWorkerOutput:=TStringList.Create;
  FProcess:=TProcess.Create(nil);
  //FProcess:=DefaultTProcess.Create(nil);
  //Process.Options:= [poUsePipes{$IFDEF Windows},poStderrToOutPut{$ENDIF}];
  //Process.Options := FProcess.Options +[poUsePipes, poStderrToOutPut];
  Process.Options:= [{poWaitOnExit,}poRunIdle,poUsePipes{$ifdef Windows},poStderrToOutPut{$endif}];
  //Process.Options := FProcess.Options +[poRunIdle,poUsePipes, poStderrToOutPut]-[poRunSuspended,poWaitOnExit];
  {$ifdef LCL}
  FProcess.ShowWindow := swoHide;
  {$endif}

  Process.RunCommandSleepTime:=10; // rest the default sleep time to 0 (context switch only)
  Process.OnRunCommandEvent:=@RunEvent;

  FVerbose:=true;
end;

destructor TExternalTool.Destroy;
begin
  EnterCriticalSection;
  try
    FStage:=etsDestroying;
    if Thread is TExternalToolThread then
      TExternalToolThread(Thread).Tool:=nil;
    FreeAndNil(FProcess);
    FreeAndNil(FWorkerOutput);
  finally
    LeaveCriticalSection;
  end;
  inherited Destroy;
end;

procedure TExternalTool.DoExecute;
// in main thread

  function CheckError: boolean;
  begin
    if (FStage>=etsStopped) then exit(true);
    if (ErrorMessage='') then exit(false);
    EnterCriticalSection;
    try
      if FStage>=etsStopped then exit(true);
      FStage:=etsStopped;
    finally
      LeaveCriticalSection;
    end;
    Result:=true;
  end;

var
  ExeFile: String;
begin
  if Terminated then exit;

  EnterCriticalSection;
  try
    if Stage<>etsInit then
      raise Exception.Create('TExternalTool.Execute: already initialized');
    FStage:=etsInitializing;
    WorkerOutput.Clear;
  finally
    LeaveCriticalSection;
  end;


  // init CurrentDirectory
  Process.CurrentDirectory:=TrimFilename(Process.CurrentDirectory);
  if not FilenameIsAbsolute(Process.CurrentDirectory) then
    Process.CurrentDirectory:=AppendPathDelim(GetCurrentDir)+Process.CurrentDirectory;

  // init Executable
  Process.Executable:=TrimFilename(Process.Executable);
  if not FilenameIsAbsolute(Process.Executable) then
  begin
    if ExtractFilePath(Process.Executable)<>'' then
      Process.Executable:=AppendPathDelim(GetCurrentDir)+Process.Executable
    else if Process.Executable='' then
    begin
      ErrorMessage:=Format(lisToolHasNoExecutable, [Title]);
      CheckError;
      exit;
    end else begin
      ExeFile:=FindDefaultExecutablePath(Process.Executable,GetCurrentDir);
      if ExeFile='' then
      begin
        ErrorMessage:=Format(lisCanNotFindExecutable, [Process.Executable]);
        CheckError;
        exit;
      end;
      Process.Executable:=ExeFile;
    end;
  end;
  ExeFile:=Process.Executable;
  if not FileExists(ExeFile) then
  begin
    ErrorMessage:=Format(lisMissingExecutable, [ExeFile]);
    CheckError;
    exit;
  end;
  if DirectoryExists(ExeFile) then
  begin
    ErrorMessage:=Format(lisExecutableIsADirectory, [ExeFile]);
    CheckError;
    exit;
  end;
  if not FileIsExecutable(ExeFile) then
  begin
    ErrorMessage:=Format(lisExecutableLacksThePermissionToRun, [ExeFile]);
    CheckError;
    exit;
  end;

  // init misc
  if Assigned(FProcessEnvironment) then
      Process.Environment:=FProcessEnvironment.EnvironmentList;

  EnterCriticalSection;
  try
    if Stage<>etsInitializing then
      raise Exception.Create('TExternalTool.Execute: bug in initialization');
    FStage:=etsWaitingForStart;
  finally
    LeaveCriticalSection;
  end;
end;

procedure TExternalTool.DoStart;
begin
  EnterCriticalSection;
  try
    if Stage<>etsWaitingForStart then
      raise Exception.Create('TExternalTool.Execute: already started');
    FStage:=etsStarting;
  finally
    LeaveCriticalSection;
  end;

  {$ifdef THREADEDEXECUTE}
  // start thread
  if Thread=nil then
  begin
    FThread:=TExternalToolThread.Create(true);
    Thread.Tool:=Self;
    FThread.FreeOnTerminate:=true;
  end;
  Thread.Start;
  {$else}
  if Thread=nil then
  begin
    FThread:=TExternalToolThread.Create;
    Thread.Tool:=Self;
  end;
  Thread.Execute;
  {$endif}
end;

procedure TExternalTool.DoTerminate;
var
  NeedProcTerminate: Boolean;
begin
  NeedProcTerminate:=false;
  EnterCriticalSection;
  try
    if Terminated then exit;
    if Stage=etsStopped then exit;

    if ErrorMessage='' then
      ErrorMessage:=lisAborted;
    fTerminated:=true;
    if Stage=etsRunning then
      NeedProcTerminate:=true;
    if Stage<etsStarting then
      FStage:=etsStopped
    else if Stage<=etsRunning then
      FStage:=etsWaitingForStop;
  finally
    LeaveCriticalSection;
  end;
  if NeedProcTerminate and (Process<>nil) then
  begin
    Process.Terminate(AbortedExitCode);
    {$IF FPC_FULLVERSION < 30300}
    Process.WaitOnExit;
    {$ELSE}
    Process.WaitOnExit(5000);
    {$ENDIF}
    //To check !!
    //fTerminated:=false;
  end;
end;

function TExternalTool.CanFree: boolean;
begin
  Result:=(FThread=nil) and inherited CanFree;
end;

procedure TExternalTool.SyncAutoFree(aData: PtrInt);
begin
  AutoFree;
end;

procedure TExternalTool.QueueAsyncAutoFree;
begin
  {$ifdef LCL}
  Application.QueueAsyncCall(@SyncAutoFree,0);
  {$endif}
end;

function TExternalTool.CanStart: boolean;
begin
  Result:=false;
  if Stage<>etsWaitingForStart then exit;
  if Terminated then exit;
  Result:=true;
end;

procedure TExternalTool.Execute;
begin
  if Stage<>etsInit then
  begin
    if Stage=etsStopped then
    begin
      EnterCriticalSection;
      try
        FStage:=etsInit;
      finally
        LeaveCriticalSection;
      end;
    end else raise Exception.Create('TExternalTool.Execute "'+Title+'" already started');
  end;
  DoExecute;
  if Stage<>etsWaitingForStart then
    exit
  else
    DoStart;
end;

procedure TExternalTool.Terminate;
begin
  DoTerminate;
end;

procedure TExternalTool.WaitForExit;
begin
  repeat
    try
      EnterCriticalSection;
      try
        if Stage=etsDestroying then break;
        if (Stage=etsStopped) then break;
        // still running => wait a bit to prevent cpu cycle burning
      finally
        LeaveCriticalSection;
      end;
    finally
      if MainThreadID=ThreadID then
      begin
        //if IsMultiThread then
        {$ifdef LCL}
        Application.ProcessMessages;
        {$else}
        CheckSynchronize(0); // if we use Thread.Synchronize
        {$endif}
        //TExternalToolsBase(Owner).HandleMesages;
      end;
    end;
    sleep(10)
  until false;
end;

function TExternalTool.GetExeInfo:string;
begin
  result:='Executing: '+Process.Executable+' '+CmdLineParams+' (working dir: '+ Process.CurrentDirectory +')';
end;

function TExternalTool.ExecuteAndWait:integer;
begin
  result:=-1;
  Execute;
  WaitForExit;
  //result:=ExitCode;
  result:=ExitStatus;
  //result:=(ErrorMessage='') and (not Terminated) and (ExitStatus=0);
end;


{ TExternalToolThread }

procedure TExternalToolThread.SetTool(AValue: TExternalTool);
begin
  if FTool=AValue then Exit;
  if FTool<>nil then FTool.Thread:=nil;
  FTool:=AValue;
  if FTool<>nil then FTool.Thread:=Self;
end;

procedure TExternalToolThread.Execute;
type
  TErrorFrame = record
    Addr: Pointer;
    Line: shortstring;
  end;
  PErrorFrame = ^TErrorFrame;

var
  ErrorFrames: array[0..30] of TErrorFrame;
  ErrorFrameCount: integer;

  function GetExceptionStackTrace: string;
  var
    FrameCount: LongInt;
    Frames: PPointer;
    Cnt: LongInt;
    f: PErrorFrame;
    i: Integer;
  begin
    Result:='';
    FrameCount:=ExceptFrameCount;
    Frames:=ExceptFrames;
    ErrorFrames[0].Addr:=ExceptAddr;
    ErrorFrames[0].Line:='';
    ErrorFrameCount:=1;
    Cnt:=FrameCount;
    for i:=1 to Cnt do begin
      ErrorFrames[i].Addr:=Frames[i-1];
      ErrorFrames[i].Line:='';
      ErrorFrameCount:=i+1;
    end;
    for i:=0 to ErrorFrameCount-1 do begin
      f:=@ErrorFrames[i];
      try
        f^.Line:=copy(BackTraceStrFunc(f^.Addr),1,255);
      except
        f^.Line:=copy(SysBackTraceStr(f^.Addr),1,255);
      end;
    end;
    for i:=0 to ErrorFrameCount-1 do begin
      Result+=ErrorFrames[i].Line+LineEnding;
    end;
  end;

var
  Buf: string;

  function ReadInputPipe(aStream: TInputPipeStream; var LineBuf: string;
    IsStdErr: boolean): boolean;
  // true if some bytes have been read
  var
    Count: DWord;
    StartPos: Integer;
    i: DWord;
  begin
    Result:=false;
    if aStream=nil then exit;
    Count:=aStream.NumBytesAvailable;
    if Count=0 then exit;
    Count:=aStream.Read(Buf[1],Min(length(Buf),Count));
    if Count=0 then exit;
    Result:=true;
    StartPos:=1;
    i:=1;
    while i<=Count do
    begin
      if Buf[i] in [#10,#13] then
      begin
        LineBuf:=LineBuf+copy(Buf,StartPos,i-StartPos);
        if IsStdErr then
          fLines.AddObject(LineBuf,fLines)
        else
          fLines.Add(LineBuf);
        LineBuf:='';
        if (i<Count) and (Buf[i+1] in [#10,#13]) and (Buf[i]<>Buf[i+1])
        then
          inc(i);
        StartPos:=i+1;
      end;
      inc(i);
    end;
    LineBuf:=LineBuf+copy(Buf,StartPos,Count-StartPos+1);
  end;

const
  UpdateTimeDiff = 1000 div 10; // update 10 times a second, even if there is still work
var
  OutputLine, StdErrLine: String;
  LastUpdate: QWord;
  ErrMsg: String;
  ok: Boolean;
  HasOutput: Boolean;
  ProcessCounter:integer;
  aExit:longword;
begin
  SetLength({%H-}Buf,4096);

  //FillChar(Buf[1],SizeOf(Buf)-1,0);
  FillChar(ErrorFrames,SizeOf(ErrorFrames),0);

  ErrorFrameCount:=0;
  ProcessCounter:=0;

  fLines:=TStringList.Create;
  try
    try
      if Tool.Stage<>etsStarting then exit;

      if not FileIsExecutable(Tool.Process.Executable) then
      begin
        Tool.ErrorMessage:=Format(lisCanNotExecute, [Tool.Process.Executable]);
        Tool.ProcessStopped;
        exit;
      end;
      if not DirectoryExists(ChompPathDelim(Tool.Process.CurrentDirectory)) then
      begin
        Tool.ErrorMessage:=Format(lisMissingDirectory, [Tool.Process.
          CurrentDirectory]);
        Tool.ProcessStopped;
        exit;
      end;

      ok:=false;
      try
        Tool.Process.PipeBufferSize:=Max(Tool.Process.PipeBufferSize,64*1024);
        Tool.Process.Execute;
        ok:=true;
      except
        on E: Exception do
        begin
          if Tool.ErrorMessage='' then
            Tool.ErrorMessage:=Format(lisUnableToExecute, [E.Message]);
        end;
      end;
      if (not ok) then
      begin
        Tool.ProcessStopped;
        exit;
      end;
      if Tool.Stage>=etsStopped then exit;

      Tool.ProcessRunning;

      if Tool.Stage>=etsStopped then exit;

      OutputLine:='';
      StdErrLine:='';
      LastUpdate:=GetTickCount64;
      while (Tool<>nil) and (Tool.Stage=etsRunning) do
      begin
        if Tool.ReadStdOutBeforeErr then begin
          HasOutput:=ReadInputPipe(Tool.Process.Output,OutputLine,false)
                  or ReadInputPipe(Tool.Process.Stderr,StdErrLine,true);
        end else begin
          HasOutput:=ReadInputPipe(Tool.Process.Stderr,StdErrLine,true)
                  or ReadInputPipe(Tool.Process.Output,OutputLine,false);
        end;
        if (not HasOutput) then
        begin
          if not Tool.Process.Running then break;
        end;
        if (fLines.Count>0)
        and (Abs(int64(GetTickCount64)-LastUpdate)>UpdateTimeDiff) then
        begin
          Tool.AddOutputLines(fLines);
          fLines.Clear;
          LastUpdate:=GetTickCount64;
        end;
        if (poRunIdle in Tool.Process.Options) and Assigned(Tool.Process.OnRunCommandEvent) then
        begin
          Tool.Process.OnRunCommandEvent(self,Nil,RunCommandIdle,'')
        end
        else
          if (not HasOutput) then sleep(50);
      end;
      // add rest of output

      if (OutputLine<>'') then fLines.Add(OutputLine);
      if (StdErrLine<>'') then fLines.Add(StdErrLine);

      if (Tool<>nil) and (fLines.Count>0) then
      begin
        Tool.AddOutputLines(fLines);
        fLines.Clear;
      end;

      if (Tool<>nil) and (poRunIdle in Tool.Process.Options) and Assigned(Tool.Process.OnRunCommandEvent) then
         Tool.Process.OnRunCommandEvent(self,Nil,RunCommandFinished,'');

      try
        if Tool.Stage>=etsStopped then exit;
        Tool.ExitStatus:=Tool.Process.ExitStatus;
        Tool.ExitCode:=Tool.Process.ExitCode;
      except
        Tool.ErrorMessage:=lisUnableToReadProcessExitStatus;
      end;
    except
      on E: Exception do begin
        if (Tool<>nil) and (Tool.ErrorMessage='') then
        begin
          Tool.ErrorMessage:=E.Message;
          ErrMsg:=GetExceptionStackTrace;
          Tool.ErrorMessage:=E.Message+LineEnding+ErrMsg;
        end;
      end;
    end;
  finally
    // clean up
    try
      Finalize(buf);
      FreeAndNil(fLines);
    except
      on E: Exception do
      begin
        if Tool<>nil then
          Tool.ErrorMessage:=Format(lisFreeingBufferLines, [E.Message]);
      end;
    end;
  end;
  if Tool.Stage>=etsStopped then exit;
  if Tool<>nil then Tool.ProcessStopped;
end;

destructor TExternalToolThread.Destroy;
begin
  FTool:=nil;
  inherited Destroy;
end;

procedure ThreadLog(const aMsg: string;const aEvent:TEventType);
{$ifdef LCL}
const
  WM_THREADINFO = LM_USER + 2010;
var
  aMessage:string;
  PInfo: PChar;
begin
  if aEvent=etError then
    aMessage:=BeginSnippet+' '+'ERROR: '+aMsg
  else
  if aEvent=etWarning then
    aMessage:=BeginSnippet+' '+'WARNING: '+aMsg
  else
  if aEvent=etCustom then
    aMessage:=BeginSnippet+' '+aMsg
  else
    aMessage:=aMsg;
  PInfo := StrAlloc(Length(aMessage)+1);
  StrCopy(PInfo, PChar(aMessage));
  if (Assigned(Application) AND Assigned(Application.MainForm)) then PostMessage(Application.MainForm.Handle, WM_THREADINFO, {%H-}NativeUInt(PInfo), 0);
end;
{$else}
begin
  if aEvent=etError then write(BeginSnippet+' '+'ERROR: ');
  if aEvent=etWarning then write(BeginSnippet+' '+'WARNING: ');
  if aEvent=etCustom then write(BeginSnippet+' ');
  writeln(aMsg);
end;
{$endif}

end.

