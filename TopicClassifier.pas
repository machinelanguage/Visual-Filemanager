unit TopicClassifier;

interface

uses
  System.SysUtils, System.Classes;

type
  TManagedFile = record
    FullName: string;
    DisplayName: string;
    Extension: string;
    Topic: string;
    Size: Int64;
    ModifiedAt: TDateTime;
    Preview: string;
    Confidence: Integer;
  end;

function ReadIndexableText(const AFileName: string): string;
function ClassifyFile(const AFileName: string; const AText: string;
  out AConfidence: Integer): string;
function IsIndexable(const AFileName: string): Boolean;

implementation

uses
  System.IOUtils, System.StrUtils, System.Types, System.Zip;

const
  MaxIndexedChars = 120000;

function CompactWhitespace(const S: string): string;
var
  I: Integer;
  LastWasSpace: Boolean;
begin
  Result := '';
  LastWasSpace := False;
  for I := 1 to Length(S) do
    if CharInSet(S[I], [#9, #10, #13, ' ']) then
    begin
      if not LastWasSpace then
        Result := Result + ' ';
      LastWasSpace := True;
    end
    else
    begin
      Result := Result + S[I];
      LastWasSpace := False;
    end;
end;

function StripXml(const S: string): string;
var
  I: Integer;
  InTag: Boolean;
begin
  Result := '';
  InTag := False;
  for I := 1 to Length(S) do
  begin
    if S[I] = '<' then
      InTag := True
    else if S[I] = '>' then
    begin
      InTag := False;
      Result := Result + ' ';
    end
    else if not InTag then
      Result := Result + S[I];
  end;
  Result := CompactWhitespace(Result);
end;

function ReadPlainText(const AFileName: string): string;
begin
  try
    Result := TFile.ReadAllText(AFileName, TEncoding.UTF8);
  except
    try
      Result := TFile.ReadAllText(AFileName, TEncoding.Default);
    except
      Result := '';
    end;
  end;
end;

function ReadDocxText(const AFileName: string): string;
var
  Zip: TZipFile;
  Stream: TMemoryStream;
  Index: Integer;
begin
  Result := '';
  Zip := TZipFile.Create;
  Stream := TMemoryStream.Create;
  try
    Zip.Open(AFileName, zmRead);
    Index := Zip.IndexOf('word/document.xml');
    if Index >= 0 then
    begin
      Zip.Read(Index, Stream);
      Stream.Position := 0;
      Result := StripXml(TEncoding.UTF8.GetString(Stream.Memory, Stream.Size));
    end;
  except
    Result := '';
  end;
  Stream.Free;
  Zip.Free;
end;

function ReadPdfText(const AFileName: string): string;
var
  Bytes: TBytes;
  I: Integer;
  C: Byte;
  Stream: TFileStream;
  Count: Integer;
begin
  Result := '';
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      Count := Stream.Size;
      if Count > MaxIndexedChars then
        Count := MaxIndexedChars;
      SetLength(Bytes, Count);
      if Count > 0 then
        Stream.ReadBuffer(Bytes[0], Count);
    finally
      Stream.Free;
    end;
    for I := 0 to High(Bytes) do
    begin
      C := Bytes[I];
      if (C >= 32) and (C <= 126) then
        Result := Result + Char(C)
      else
        Result := Result + ' ';
      if Length(Result) >= MaxIndexedChars then
        Break;
    end;
    Result := CompactWhitespace(Result);
  except
    Result := '';
  end;
end;

function IsIndexable(const AFileName: string): Boolean;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  Result := MatchText(Ext, ['.txt', '.csv', '.log', '.md', '.json', '.xml',
    '.ini', '.pas', '.html', '.htm', '.css', '.js', '.pdf', '.docx']);
end;

function ReadIndexableText(const AFileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(AFileName));
  if Ext = '.docx' then
    Result := ReadDocxText(AFileName)
  else if Ext = '.pdf' then
    Result := ReadPdfText(AFileName)
  else if IsIndexable(AFileName) then
    Result := ReadPlainText(AFileName)
  else
    Result := '';
  if Length(Result) > MaxIndexedChars then
    SetLength(Result, MaxIndexedChars);
end;

function Occurrences(const AText, AWord: string): Integer;
var
  FromPos, FoundPos: Integer;
begin
  Result := 0;
  FromPos := 1;
  repeat
    FoundPos := PosEx(AWord, AText, FromPos);
    if FoundPos > 0 then
    begin
      Inc(Result);
      FromPos := FoundPos + Length(AWord);
    end;
  until FoundPos = 0;
end;

function ScoreWords(const AText: string; const Words: array of string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := Low(Words) to High(Words) do
    Inc(Result, Occurrences(AText, Words[I]));
end;

function ClassifyFile(const AFileName: string; const AText: string;
  out AConfidence: Integer): string;
var
  Haystack: string;
  Finance, Legal, Project, Media, Personal: Integer;
begin
  Haystack := LowerCase(ExtractFileName(AFileName) + ' ' + AText);
  Finance := ScoreWords(Haystack, ['fatura', 'invoice', 'ödeme', 'payment',
    'banka', 'bank', 'muhasebe', 'teklif', 'price']);
  Legal := ScoreWords(Haystack, ['sözleşme', 'contract', 'hukuk', 'kanun',
    'kvkk', 'gizlilik', 'privacy', 'protokol']);
  Project := ScoreWords(Haystack, ['proje', 'project', 'toplantı', 'meeting',
    'plan', 'görev', 'task', 'rapor', 'report']);
  Media := ScoreWords(Haystack, ['fotoğraf', 'photo', 'image', 'video',
    'müzik', 'music', 'tasarım', 'design']);
  Personal := ScoreWords(Haystack, ['özgeçmiş', 'cv', 'kişisel', 'personal',
    'notlar', 'notes', 'aile', 'family']);
  AConfidence := Finance;
  Result := 'Finans';
  if Legal > AConfidence then begin AConfidence := Legal; Result := 'Hukuk'; end;
  if Project > AConfidence then begin AConfidence := Project; Result := 'Projeler'; end;
  if Media > AConfidence then begin AConfidence := Media; Result := 'Medya'; end;
  if Personal > AConfidence then begin AConfidence := Personal; Result := 'Kişisel'; end;
  if AConfidence = 0 then
  begin
    Result := 'Diğer';
    AConfidence := 0;
  end;
end;

end.
