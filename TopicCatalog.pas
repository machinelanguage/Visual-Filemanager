unit TopicCatalog;

interface

uses
  System.SysUtils, System.Classes, System.IniFiles;

type
  TTopicCatalog = class
  private
    FFileName: string;
    FIni: TMemIniFile;
    function HashPath(const AFileName: string): string;
    function KeyForPath(const AFileName: string): string;
    function Signature(const ASize: Int64; const AModifiedAt: TDateTime): string;
  public
    constructor Create;
    destructor Destroy; override;
    function TryGetTopic(const AFileName: string; const ASize: Int64;
      const AModifiedAt: TDateTime; out ATopic: string;
      out AConfidence: Integer): Boolean;
    procedure SaveTopic(const AFileName: string; const ASize: Int64;
      const AModifiedAt: TDateTime; const ATopic: string;
      const AConfidence: Integer);
    function LastFolder: string;
    procedure SetLastFolder(const AFolder: string);
    procedure Save;
  end;

implementation

uses
  System.IOUtils;

constructor TTopicCatalog.Create;
var
  Folder: string;
begin
  inherited;
  Folder := TPath.Combine(TPath.GetDocumentsPath, 'VisualFileManager');
  ForceDirectories(Folder);
  FFileName := TPath.Combine(Folder, 'topic-catalog.ini');
  FIni := TMemIniFile.Create(FFileName, TEncoding.UTF8);
end;

destructor TTopicCatalog.Destroy;
begin
  Save;
  FIni.Free;
  inherited;
end;

function TTopicCatalog.HashPath(const AFileName: string): string;
var
  I: Integer;
  Hash: Cardinal;
  Value: string;
begin
  Hash := 2166136261;
  Value := LowerCase(AFileName);
  for I := 1 to Length(Value) do
  begin
    Hash := Hash xor Ord(Value[I]);
    Hash := Hash * 16777619;
  end;
  Result := IntToHex(Hash, 8);
end;

function TTopicCatalog.KeyForPath(const AFileName: string): string;
var
  Key: string;
  Number: Integer;
begin
  Key := 'F' + HashPath(AFileName);
  Number := 1;
  while (FIni.ReadString('Path', Key, '') <> '') and
    not SameText(FIni.ReadString('Path', Key, ''), AFileName) do
  begin
    Inc(Number);
    Key := 'F' + HashPath(AFileName) + '_' + IntToStr(Number);
  end;
  Result := Key;
end;

function TTopicCatalog.Signature(const ASize: Int64;
  const AModifiedAt: TDateTime): string;
begin
  Result := IntToStr(ASize) + '|' + DateTimeToStr(AModifiedAt);
end;

function TTopicCatalog.TryGetTopic(const AFileName: string; const ASize: Int64;
  const AModifiedAt: TDateTime; out ATopic: string;
  out AConfidence: Integer): Boolean;
var
  Key: string;
begin
  ATopic := '';
  AConfidence := 0;
  Key := KeyForPath(AFileName);
  Result := SameText(FIni.ReadString('Stamp', Key, ''),
    Signature(ASize, AModifiedAt));
  if Result then
  begin
    ATopic := FIni.ReadString('Topic', Key, 'Diğer');
    AConfidence := FIni.ReadInteger('Confidence', Key, 0);
  end;
end;

procedure TTopicCatalog.SaveTopic(const AFileName: string; const ASize: Int64;
  const AModifiedAt: TDateTime; const ATopic: string;
  const AConfidence: Integer);
var
  Key: string;
begin
  Key := KeyForPath(AFileName);
  FIni.WriteString('Path', Key, AFileName);
  FIni.WriteString('Stamp', Key, Signature(ASize, AModifiedAt));
  FIni.WriteString('Topic', Key, ATopic);
  FIni.WriteInteger('Confidence', Key, AConfidence);
end;

function TTopicCatalog.LastFolder: string;
begin
  Result := FIni.ReadString('Settings', 'LastFolder', '');
end;

procedure TTopicCatalog.SetLastFolder(const AFolder: string);
begin
  FIni.WriteString('Settings', 'LastFolder', AFolder);
end;

procedure TTopicCatalog.Save;
begin
  FIni.UpdateFile;
end;

end.
