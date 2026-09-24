program VisualFileManager;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {FrmVisualFileManager};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFrmVisualFileManager, FrmVisualFileManager);
  Application.Run;
end.
