program powertool;

uses
  Forms,
  Unit1 in 'Unit1.pas' {mainform};

{$R *.res}

begin
  Application.Initialize;
  Application.ShowMainForm := False;
  Application.CreateForm(Tmainform, mainform);
  Application.Run;
end.
