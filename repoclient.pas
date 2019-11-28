unit repoclient;

{ Generic repository client class. Implementations for hg, svn,... are availalbe
  Copyright (C) 2012-2013 Reinier Olislagers, Ludo Brands

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
  Classes, SysUtils, processutils;

const
  // Custom return codes; note: keep separate from ProcessEx return codes (processutils.PROC_INTERNALERROR=-1)
  FRET_LOCAL_REMOTE_URL_NOMATCH = -10; //Return code that indicates remote and local repository URLs don't match
  FRET_WORKING_COPY_TOO_OLD = -11; //Return code for SVN problem with old client version used
  FRET_NONEXISTING_REPO = -12; // Repo client could not detect a local repository/local copy of the remote repository
  FRET_UNKNOWN_REVISION = 'FRET_UNKNOWN_REVISION';
  ERRORMAXRETRIES = 3;
  CONNECTIONMAXRETRIES = 10;

type
  ERepoClientError = class(Exception);

  { TRepoClient }

  TRepoClient = class(TObject)
  protected
    FDesiredRevision: string;
    FDesiredBranch: string;
    FHTTPProxyHost: string;
    FHTTPProxyPassword: string;
    FHTTPProxyPort: integer;
    FHTTPProxyUser: string;
    FLocalRepository: string;
    FLocalRevision: string;
    FRepoExecutable: string;
    FRepoExecutableName: string;
    FRepositoryURL: string;
    FReturnCode: integer;
    FReturnOutput: string;
    FVerbose: boolean;
    FModuleName: string;
    FExportOnly: boolean;
    FForceLocal: boolean;
    //Performs a checkout/initial download
    //Note: it's often easier to call CheckOutOrUpdate
    procedure CheckOut(UseForce:boolean=false); virtual;
    function GetLocalRevision: string; virtual;
    // Makes sure non-empty strings have a / at the end.
    function IncludeTrailingSlash(AValue: string): string; virtual;
    procedure SetDesiredRevision(AValue: string); virtual;
    procedure SetDesiredBranch(AValue: string); virtual;
    procedure SetLocalRepository(AValue: string); virtual;
    procedure SetRepositoryURL(AValue: string); virtual;
    procedure SetRepoExecutable(AValue: string); virtual;
    procedure SetVerbose(AValue: boolean); virtual;
    procedure SetExportOnly(AValue: boolean); virtual;
    function GetValidClient:boolean;
    // Search for installed version control client executable (might return just a filename if in the OS path)
    function GetRepoExecutable:string;virtual;
    function GetRepoExecutableName:string;virtual;
    function FindRepoExecutable: string; virtual;
    //Performs an update (pull)
    //Note: it's often easier to call CheckOutOrUpdate; that also has some more network error recovery built in
    procedure Update; virtual;
  public
    // Downloads from remote repo: runs checkout if local repository doesn't exist, else does an update
    procedure CheckOutOrUpdate; virtual;
    // Downloads only the whole tree from remote repo ... do not include .svn or .git
    procedure ExportRepo; virtual;
    // Commits local changes to local and remote repository
    function Commit(Message: string): boolean; virtual;
    // Executes command and returns result code
    // Note: caller is responsible for quoting: to do: find out again in processutils what rules apply?!?
    function Execute(Command: string): integer; virtual;
    // Creates diff of all changes in the local directory versus the remote version
    function GetDiffAll: string; virtual;
    // Shows commit log for local directory
    procedure Log(var Log: TStringList); virtual;
    // change (switch) the remote URL
    procedure SwitchURL; virtual;
    // Parses file lists generated by version control client, optionally limited to characters in FilterCodes
    procedure ParseFileList(const CommandOutput: string; var FileList: TStringList; const FilterCodes: array of string); virtual;
    // Reverts/removes local changes so we get a clean copy again. Note: will remove modifications to files!
    procedure Revert; virtual;
    // Get/set desired revision to checkout/pull to (if none given, use HEAD/tip/newest)
    property DesiredRevision: string read FDesiredRevision write SetDesiredRevision;
    // Get/set desired branch to checkout/pull
    property DesiredBranch: string read FDesiredBranch write SetDesiredBranch;
    // If using http transport, an http proxy can be used. Proxy hostname/ip address
    property HTTPProxyHost: string read FHTTPProxyHost write FHTTPProxyHost;
    // If using http transport, an http proxy can be used. Proxy port
    property HTTPProxyPort: integer read FHTTPProxyPort write FHTTPProxyPort;
    // If using http transport, an http proxy can be used. Proxy username (optional)
    property HTTPProxyUser: string read FHTTPProxyUser write FHTTPProxyUser;
    // If using http transport, an http proxy can be used. Proxy password (optional)
    property HTTPProxyPassword: string read FHTTPProxyPassword write FHTTPProxyPassword;
    // Shows list of files that have been modified locally (and not committed)
    procedure LocalModifications(var FileList: TStringList); virtual;
    // Checks to see if local directory is a valid repository for the repository URL given (if any)
    function LocalRepositoryExists: boolean; virtual;
    // Local directory that has a repository/checkout.
    // When setting, relative paths will be expanded; trailing path delimiters will be removed
    property LocalRepository: string read FLocalRepository write SetLocalRepository;
    // Revision number of local repository: branch revision number if we're in a branch.
    property LocalRevision: string read GetLocalRevision;
    // URL where central (remote) repository is placed
    property Repository: string read FRepositoryURL write SetRepositoryURL;
    // Exit code returned by last client command; 0 for success. Useful for troubleshooting
    property ReturnCode: integer read FReturnCode;
    // Output returned by last client command. Useful for troubleshooting
    property ReturnOutput: string read FReturnOutput;
    // Version control client executable. Can be set to explicitly determine which executable to use.
    property RepoExecutable: string read GetRepoExecutable write SetRepoExecutable;
    // Show additional console/log output?
    property Verbose: boolean read FVerbose write SetVerbose;
    property ModuleName: string read FModuleName write FModuleName;
    property ExportOnly: boolean read FExportOnly write SetExportOnly;
    property ForceLocal: boolean read FForceLocal write FForceLocal;
    property ValidClient: boolean read GetValidClient;
    property RepoExecutableName: string read GetRepoExecutableName;
    constructor Create;
    destructor Destroy; override;
  end;


implementation

uses
  fpcuputil;

{ TRepoClient }

function TRepoClient.GetLocalRevision: string;
begin
  // Inherited classes, please implement
  FLocalRevision := FRET_UNKNOWN_REVISION;
  raise Exception.Create('TRepoClient descendants must implement this themselves.');
end;

function TRepoClient.GetRepoExecutable: string;
begin
  { Inherited classes, please implement getting the client executable
  for your version control system, e.g. svn.exe, git, hg, bzr... or nothing}
  raise Exception.Create('TRepoClient descendants must implement this themselves.');
  Result := '';
end;

function TRepoClient.IncludeTrailingSlash(AValue: string): string;
begin
  // Default: either empty string or / already there
  Result := AValue;
  if (AValue <> '') and (RightStr(AValue, 1) <> '/') then
  begin
    Result := AValue + '/';
  end;
end;

procedure TRepoClient.SetDesiredRevision(AValue: string);
begin
  if FDesiredRevision = AValue then
    Exit;
  FDesiredRevision := AValue;
end;

procedure TRepoClient.SetDesiredBranch(AValue: string);
begin
  if FDesiredBranch = AValue then
    Exit;
  FDesiredBranch := AValue;
end;


procedure TRepoClient.SetLocalRepository(AValue: string);
 // Sets local repository, converting relative path to absolute path
 // and adding a trailing / or \
begin
  if FLocalRepository = AValue then
    Exit;
  // Avoid ExpandFilename expanding to current dir
  if AValue = '' then
    FLocalRepository := AValue
  else
    FLocalRepository := ExcludeTrailingPathDelimiter(AValue);
end;

procedure TRepoClient.SetRepositoryURL(AValue: string);
 // Make sure there's a trailing / in the URL.
 // This normalization helps matching remote and local URLs
begin
  if FRepositoryURL = AValue then
    Exit;
  FRepositoryURL := IncludeTrailingSlash(AValue);
end;

procedure TRepoClient.SetRepoExecutable(AValue: string);
begin
  if FRepoExecutable <> AValue then
  begin
    FRepoExecutable := AValue;
    // If it exists, assume it's the correct client; if not...
    if not (FileExists(FRepoExecutable)) then
      FindRepoExecutable; //... use fallbacks to get a working client
  end;
end;

procedure TRepoClient.SetVerbose(AValue: boolean);
begin
  if FVerbose = AValue then
    Exit;
  FVerbose := AValue;
end;

procedure TRepoClient.SetExportOnly(AValue: boolean);
begin
  if FExportOnly = AValue then
    Exit;
  FExportOnly := AValue;
end;


function TRepoClient.GetValidClient:boolean;
begin
  result:=( (Length(FRepoExecutable)<>0) AND (FileExists(FRepoExecutable)) );
end;

procedure TRepoClient.CheckOut(UseForce:boolean=false);
begin
  raise Exception.Create('TRepoClient descendants must implement CheckOut by themselves.');
end;

procedure TRepoClient.CheckOutOrUpdate;
begin
  raise Exception.Create('TRepoClient descendants must implement CheckOutOrUpdate by themselves.');
end;

procedure TRepoClient.ExportRepo;
begin
  raise Exception.Create('TRepoClient descendants must implement ExportRepo by themselves.');
end;


function TRepoClient.Commit(Message: string): boolean;
begin
  raise Exception.Create('TRepoClient descendants must implement Commit by themselves.');
end;

function TRepoClient.GetRepoExecutableName:string;
begin
  raise Exception.Create('TRepoClient descendants must implement GetRepoExecutableName by themselves.');
end;

function TRepoClient.Execute(Command: string): integer;
begin
  result:=ExecuteCommandInDir(DoubleQuoteIfNeeded(FRepoExecutable) + ' '+Command, LocalRepository, Verbose);
end;

function TRepoClient.GetDiffAll: string;
begin
  raise Exception.Create('TRepoClient descendants must implement GetDiffAll by themselves.');
end;

function TRepoClient.FindRepoExecutable: string;
begin
  raise Exception.Create('TRepoClient descendants must implement FindRepoExecutable by themselves.');
end;

procedure TRepoClient.Log(var Log: TStringList);
begin
  raise Exception.Create('TRepoClient descendants must implement Log by themselves.');
end;

procedure TRepoClient.SwitchURL;
begin
  raise Exception.Create('TRepoClient descendants must implement SwitchURL by themselves.');
end;

procedure TRepoClient.ParseFileList(const CommandOutput: string; var FileList: TStringList; const FilterCodes: array of string);
begin
  raise Exception.Create('TRepoClient descendants must implement ParseFileList by themselves.');
end;

procedure TRepoClient.Revert;
begin
  raise Exception.Create('TRepoClient descendants must implement Revert by themselves.');
end;

procedure TRepoClient.Update;
begin
  raise Exception.Create('TRepoClient descendants must implement Update by themselves.');
end;

procedure TRepoClient.LocalModifications(var FileList: TStringList);
begin
  raise Exception.Create('TRepoClient descendants must implement LocalModifications by themselves.');
end;

function TRepoClient.LocalRepositoryExists: boolean;
begin
  result:=False;
  raise Exception.Create('TRepoClient descendants must implement LocalRepositoryExists by themselves.');
end;

constructor TRepoClient.Create;
begin
  inherited Create;
  FLocalRepository := '';
  FRepositoryURL := '';
  FDesiredRevision := '';
  FLocalRevision := FRET_UNKNOWN_REVISION;
  FReturnCode := 0;
  FReturnOutput := '';
  FRepoExecutable := '';
  FForceLocal := False;
  FindRepoExecutable;
end;

destructor TRepoClient.Destroy;
begin
  inherited Destroy;
end;

end.
