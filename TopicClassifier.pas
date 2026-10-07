{$CODEPAGE UTF8}
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
function CanReadIndexableFile(const AFileName: string): Boolean;

implementation

uses
  System.IOUtils, System.StrUtils, System.Types, System.Zip, System.ZLib,
  OcrSupport;

const
  MaxIndexedChars = 120000;
  MaxPdfBytes = 4194304;

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
  Index: Integer;
  Bytes: TBytes;
begin
  Result := '';
  Zip := TZipFile.Create;
  try
    Zip.Open(AFileName, zmRead);
    Index := Zip.IndexOf('word/document.xml');
    if Index >= 0 then
    begin
      Zip.Read(Index, Bytes);
      Result := StripXml(TEncoding.UTF8.GetString(Bytes));
    end;
  except
    Result := '';
  end;
  Zip.Free;
end;

function PrintableBytes(const ABytes: TBytes): string;
var
  I: Integer;
  C: Byte;
begin
  Result := '';
  for I := 0 to High(ABytes) do
  begin
    C := ABytes[I];
    if (C >= 32) and (C <= 126) then
      Result := Result + Char(C)
    else
      Result := Result + ' ';
    if Length(Result) >= MaxIndexedChars then
      Break;
  end;
end;

function PdfMarkerText(const ABytes: TBytes): string;
var
  I: Integer;
  C: Byte;
begin
  SetLength(Result, Length(ABytes));
  for I := 0 to High(ABytes) do
  begin
    C := ABytes[I];
    if (C >= 32) and (C <= 126) then
      Result[I + 1] := Char(C)
    else
      Result[I + 1] := ' ';
  end;
end;

function InflatePdfStream(const ABytes: TBytes; out AText: string): Boolean;
var
  Input, Output: TMemoryStream;
  ZStream: TZDecompressionStream;
  Buffer: array[0..8191] of Byte;
  ReadCount: Integer;
  Decoded: TBytes;
begin
  Result := False;
  AText := '';
  if Length(ABytes) = 0 then
    Exit;
  Input := TMemoryStream.Create;
  Output := TMemoryStream.Create;
  try
    try
      Input.WriteBuffer(ABytes[0], Length(ABytes));
      Input.Position := 0;
      ZStream := TZDecompressionStream.Create(Input);
      try
        repeat
          ReadCount := ZStream.Read(Buffer, SizeOf(Buffer));
          if ReadCount > 0 then
            Output.WriteBuffer(Buffer, ReadCount);
        until (ReadCount = 0) or (Output.Size >= MaxIndexedChars);
      finally
        ZStream.Free;
      end;
      SetLength(Decoded, Output.Size);
      if Output.Size > 0 then
      begin
        Output.Position := 0;
        Output.ReadBuffer(Decoded[0], Output.Size);
      end;
      AText := PrintableBytes(Decoded);
      Result := AText <> '';
    except
      AText := '';
      Result := False;
    end;
    finally
      Output.Free;
      Input.Free;
    end;
end;

function ReadPdfText(const AFileName: string): string;
var
  Bytes, StreamBytes: TBytes;
  Stream: TFileStream;
  Count, StartPos, EndPos, FilterPos, StreamPos: Integer;
  RawText, DecodedText, OcrText: string;
begin
  Result := '';
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      Count := Stream.Size;
      if Count > MaxPdfBytes then
        Count := MaxPdfBytes;
      SetLength(Bytes, Count);
      if Count > 0 then
        Stream.ReadBuffer(Bytes[0], Count);
    finally
      Stream.Free;
    end;
    RawText := PdfMarkerText(Bytes);
    Result := PrintableBytes(Bytes);
    FilterPos := 1;
    repeat
    begin
      FilterPos := PosEx('/FlateDecode', RawText, FilterPos);
      if FilterPos > 0 then
      begin
        StreamPos := PosEx('stream', RawText, FilterPos);
        EndPos := PosEx('endstream', RawText, StreamPos);
        if (StreamPos > 0) and (EndPos > StreamPos) then
        begin
          StartPos := StreamPos + Length('stream');
          while (StartPos <= Length(RawText)) and
            CharInSet(RawText[StartPos], [#10, #13, ' ']) do
            Inc(StartPos);
          StreamBytes := Copy(Bytes, StartPos - 1, EndPos - StartPos);
          if InflatePdfStream(StreamBytes, DecodedText) then
            Result := Result + ' ' + DecodedText;
          FilterPos := EndPos + Length('endstream');
        end
        else
          Inc(FilterPos);
      end;
    end;
    until FilterPos = 0;
    if TryOcrPdfFirstPage(AFileName, OcrText) then
      Result := Result + ' ' + OcrText;
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

function CanReadIndexableFile(const AFileName: string): Boolean;
var
  Stream: TFileStream;
begin
  Result := True;
  if not IsIndexable(AFileName) then
    Exit;
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      Result := True;
    finally
      Stream.Free;
    end;
  except
    Result := False;
  end;
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
  Finance, Legal, Project, Media, Personal, Education, Food, Commerce: Integer;
begin
  Haystack := LowerCase(ExtractFileName(AFileName) + ' ' + AText);
  Education := ScoreWords(Haystack, ['bilsem', 'eğitim', 'öğrenci', 'öyg',
    'müzik', 'yıllık plan', 'uyum grubu', 'kazanım']);
  Food := ScoreWords(Haystack, ['elma', 'meyve', 'tarif', 'saklama', 'mutfak',
    'gıda', 'vitamin']);
  Commerce := ScoreWords(Haystack, ['amazon', 'iade', 'sipariş', 'kargo',
    'barkod', 'teslimat', 'return']);
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
  AConfidence := Education;
  Result := 'Eğitim ve Öğretim';
  if Food > AConfidence then begin AConfidence := Food; Result := 'Gıda ve Tarifler'; end;
  if Commerce > AConfidence then begin AConfidence := Commerce; Result := 'E-Ticaret ve Lojistik'; end;
  if Finance > AConfidence then begin AConfidence := Finance; Result := 'Finans'; end;
  if Legal > AConfidence then begin AConfidence := Legal; Result := 'Hukuk'; end;
  if Project > AConfidence then begin AConfidence := Project; Result := 'Projeler'; end;
  if Media > AConfidence then begin AConfidence := Media; Result := 'Medya'; end;
  if Personal > AConfidence then begin AConfidence := Personal; Result := 'Kişisel'; end;
  if AConfidence = 0 then
  begin
    if SameText(ExtractFileExt(AFileName), '.pdf') then
      Result := 'OCR Bekliyor'
    else
      Result := 'Diğer';
    AConfidence := 0;
  end;
end;

end.
