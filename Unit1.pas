unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ShellAPI, ExtCtrls, SyncObjs;

const
  WM_ICONTRAY = WM_USER + 1;
  // APM messages
 (*
  PBT_APMQUERYSUSPEND       = $0000;
  PBT_APMQUERYSTANDBY       = $0001;
  PBT_APMQUERYSUSPENDFAILED = $0002;
  PBT_APMQUERYSTANDBYFAILED = $0003;
  PBT_APMSUSPEND            = $0004;
  PBT_APMSTANDBY            = $0005;
  PBT_APMRESUMECRITICAL     = $0006;
  PBT_APMRESUMESUSPEND      = $0007;
  PBT_APMRESUMESTANDBY      = $0008;
  PBT_APMBATTERYLOW         = $0009;
  PBT_APMPOWERSTATUSCHANGE  = $000A;
  PBT_APMOEMEVENT           = $000B;
  PBTF_APMRESUMEFROMFAILURE = $00000001;
  PBT_APMRESUMEAUTOMATIC    = $0012;
                                *)
  // SetThreadExecutionState flags
const
  ES_CONTINUOUS              =  $80000000;
  ES_DISPLAY_REQUIRED        =  $00000002;
  ES_SYSTEM_REQUIRED         =  $00000001;
  ES_USER_PRESENT            =  $00000004;

function SetThreadExecutionState(esFlags: DWORD): DWORD; stdcall; external 'kernel32.dll';

type
  EXECUTION_STATE=DWORD;

const
    UnixStartDate : tdatetime = 719163.0;

type
  Tmainform = class(TForm)
    debuginfo: TMemo;
    Button1: TButton;
    resumetimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure Button1Click(Sender: TObject);
    procedure resumetimerTimer(Sender: TObject);
  private
     TrayIconData: TNotifyIconData;
     function DelphiDateTimeToUnix(ConvDate:TdateTime):longint;
     function UnixToDelphiDateTime(USec:longint):TDateTime;
    { Private-Deklarationen }
  public
      procedure Icontray(var Msg: TMessage); message WM_ICONTRAY;
      procedure WMPOWERBROADCAST( var Message: TMessage); message WM_POWERBROADCAST;
      procedure WMSysCommand(var Msg: TWMSysCommand); message WM_SYSCOMMAND;
      procedure WMQUERYENDSESSION(var msg: TMessage); message WM_QUERYENDSESSION;
      procedure WMENDSESSION(var msg: TMessage); message WM_ENDSESSION;
      procedure OnResume(var Msg: TMessage; ignorerunning : Boolean);
      procedure OnSuspend(var Msg: TMessage; ignorerunning : Boolean);
    { Public-Deklarationen }
  end;

var
  mainform : Tmainform;
  KernelHandle : Thandle;
  resumerunning : Boolean = false;
  suspendrunning : Boolean = false;
  resumerunning_start : longint = 0;
  suspendrunning_start : longint = 0;
  lastresumetimer_run : longint = 0;
  we_suspended : Boolean = false;
  we_resumed : Boolean = true; // wir sind ja am laufen normal ab start
  critical : TCriticalSection;

implementation

{$R *.dfm}

function getdatum : String;
var tmp : String;
begin
 DateTimetoString(tmp, 'dd.mm.yyyy hh:mm:ss', now);
 getdatum := tmp;
end;

function Tmainform.DelphiDateTimeToUnix(ConvDate:TdateTime):longint;
begin
  Result:=round((ConvDate-UnixStartDate)*86400);
 end;

function Tmainform.UnixToDelphiDateTime(USec:longint):TDateTime;
begin
  Result:=(Usec/86400)+UnixStartDate;
 end;

procedure Tmainform.Icontray(var Msg: TMessage);
var
  CursorPos : TPoint;
begin
  if Msg.lParam = WM_LBUTTONDOWN then begin
//    GetCursorPos(CursorPos);
//    SetForegroundWindow(Handle);        // suggested by Berend Radstaat
//    Application.BringToFront;
    Show();
//    SetForegroundWindow(Handle);        // suggested by Berend Radstaat
//    PostMessage(Handle, WM_NULL, 0, 0); // suggested by Berend Radstaat
//    SetForegroundWindow(Handle);        // suggested by Berend Radstaat
  end else
    inherited;
end;

procedure Tmainform.Button1Click(Sender: TObject);
begin
 Application.Terminate;
end;

procedure Tmainform.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Action := caNone;
  Hide;
end;

procedure Tmainform.FormCreate(Sender: TObject);
begin
  critical := TCriticalSection.Create;
  
  with TrayIconData do
  begin
    cbSize := SizeOf(TrayIconData);
    Wnd := Handle;
    uID := 0;
    uFlags := NIF_MESSAGE + NIF_ICON + NIF_TIP;
    uCallbackMessage := WM_ICONTRAY;
    hIcon := Application.Icon.Handle;
    StrPCopy(szTip, Application.Title);
  end;

  Shell_NotifyIcon(NIM_ADD, @TrayIconData);

  debuginfo.Lines.Insert(0, getdatum+'  started');
  mainform.Left := Screen.Width-mainform.Width;
end;

procedure Tmainform.FormDestroy(Sender: TObject);
begin
  Shell_NotifyIcon(NIM_DELETE, @TrayIconData);
  critical.Free;
end;

procedure Tmainform.WMENDSESSION(var msg: TMessage);
begin
  inherited;
  debuginfo.Lines.Insert(0, getdatum+' Windows shutdown mode executed');
  msg.Result := 0;
  Application.Terminate;
end;

procedure Tmainform.WMQUERYENDSESSION(var msg: TMessage);
begin
  inherited;
  debuginfo.Lines.Insert(0, getdatum+' Windows is requesting shutdown mode');
  msg.Result := 1;
end;

procedure Tmainform.WMPOWERBROADCAST( var Message: TMessage); //womMZ,2000,XP
begin
  debuginfo.Lines.Insert(0, getdatum+' Received WMPOWERBROADCAST Id: '+inttostr(Message.WParam));

  critical.Acquire;

  if (Message.WParam = PBT_APMQUERYSUSPEND) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows is asking for hibernate Mode');
  end
   else if (Message.WParam = PBT_APMQUERYSTANDBY) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows is asking for standby Mode');
  end
   else if (Message.WParam = PBT_APMQUERYSUSPENDFAILED) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows is denied to go to hibernate mode');
  end
   else if (Message.WParam = PBT_APMQUERYSTANDBYFAILED) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows is denied to go to standby mode');
  end
   else if (Message.WParam = PBT_APMSTANDBY) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows is going to standby');
     OnSuspend(Message, false);
  end
   else if (Message.WParam = PBT_APMSUSPEND) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows is going to hibernate');
     OnSuspend(Message, false);
  end
   else if (Message.WParam = PBT_APMRESUMECRITICAL) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows has resumed from critical hibernate mode');
     onResume(Message, false);
  end
   else if (Message.WParam = PBT_APMRESUMESUSPEND) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows has resumed from hibernate mode');
     onResume(Message, false);
  end
   else if (Message.WParam = PBT_APMRESUMESTANDBY) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows has resumed from standby mode');
     onResume(Message, false);
  end
   else if (Message.WParam = PBT_APMRESUMEAUTOMATIC) then
  begin
     debuginfo.Lines.Insert(0, getdatum+' Windows has resumed to handle an automatic event');
     onResume(Message, false);
  end

   else
  begin
     debuginfo.Lines.Insert(0, getdatum+' ### !!! This event is not handled! !!! ### ID: '+inttostr(Message.WParam));
  end;

  critical.Release;
end;

procedure Tmainform.OnResume(var Msg: TMessage; ignorerunning : Boolean);
var
  Info: TShellExecuteInfo;
  pInfo: PShellExecuteInfo;
  exitCode: DWord;
  startchecktime : longint;
  hWnd: DWORD;
begin
    // Resume läuft bereits also nicht doppelt starten
    if (resumerunning) then
    begin
      debuginfo.Lines.Insert(0, getdatum+' Resume is already running go to exit');
      exit;
    end;
    // Wir sind bereits resumed -> go to exit
    if (we_resumed) then
    begin
      debuginfo.Lines.Insert(0, getdatum+' We are already in resume state go to exit');
      exit;
    end;
    // suspend läuft und wir dürfen es NICHT ignorieren
    if (suspendrunning and not ignorerunning) then
    begin
      debuginfo.Lines.Insert(0, getdatum+' suspend is running wait for end');
      startchecktime := DelphiDateTimeToUnix(Now);
      while (suspendrunning) do
      begin
            Application.ProcessMessages;
            Sleep(500);
            // wait a minimum of 5 seconds AND suspendrunning_time is min. 5 seconds old
  (*          if (((startchecktime+5) < DelphiDateTimeToUnix(Now)) and ((suspendrunning_start+5) < DelphiDateTimeToUnix(Now))) then
            begin
              debuginfo.Lines.Insert(0, getdatum+' suspend running timed out > 5s');
              we_suspended := true;
              we_resumed := false;
              suspendrunning := false;
              resumerunning := false;
              resumerunning_start := 0;
            end; *)
      end;
      debuginfo.Lines.Insert(0, getdatum+' suspend running is done - go again to onResume');
      OnResume(Msg, false);
      exit;
    end;
    resumerunning := true;
    resumerunning_start := DelphiDateTimeToUnix(Now);

    // Wir kommen nicht aus dem suspend mode  und sollen es auch NICHT ignorieren - also suspend noch ausführen
    if (not we_suspended and not ignorerunning) then
    begin
      debuginfo.Lines.Insert(0, getdatum+' We got a resume but we did not suspend - so do a stop_mp');
      OnSuspend(Msg, true);
      we_suspended := false;
    end;
    // nochmal auf false setzen - damit es wirklich false ist
    we_suspended := false;

    debuginfo.Lines.Insert(0, getdatum+' Trying to wake up monitor / tv');
    SetThreadExecutionState(ES_DISPLAY_REQUIRED or ES_CONTINUOUS);
    SetThreadExecutionState(ES_USER_PRESENT);
    SetThreadExecutionState(ES_DISPLAY_REQUIRED or ES_CONTINUOUS or ES_USER_PRESENT);
    debuginfo.Lines.Insert(0, getdatum+' Starting '+ExtractFilePath(Application.ExeName)+'\start_mp.bat');

//    ShellExecute(Handle, NIL,PCHAR(ExtractFilePath(Application.ExeName)+'\start_mp.bat'),PCHAR(''),PCHAR(ExtractFilePath(Application.ExeName)),SW_SHOW);

  pInfo := @Info;
  with Info do
  begin
    cbSize := SizeOf(Info);
    fMask  := SEE_MASK_NOCLOSEPROCESS;
    wnd    := application.Handle;
    lpVerb := NIL;
    lpFile := PChar(ExtractFilePath(Application.ExeName)+'\start_mp.bat');
    lpParameters := PChar(#0);
    lpDirectory  := PCHAR(ExtractFilePath(Application.ExeName));
    nShow        := SW_SHOWNORMAL;
    hInstApp     := 0;
  end;
  ShellExecuteEx(pInfo);

  //  repeat
  resumerunning_start := DelphiDateTimeToUnix(Now);
  exitCode := WaitForSingleObject(Info.hProcess, 15000);
//    resumerunning_start := DelphiDateTimeToUnix(Now);
//    Application.ProcessMessages;
//  until (exitCode <> WAIT_TIMEOUT);

    debuginfo.Lines.Insert(0, getdatum+' Starting '+ExtractFilePath(Application.ExeName)+'\start_mp.bat'+ ' DONE');

(*    hWnd := FindWindow(nil, PChar('MediaPortal'));
    if hWnd <> 0 then
      hWnd := FindWindow(nil, PChar('MediaPortal.exe'));
    if hWnd <> 0 then
      hWnd := FindWindow(nil, PChar('MP'));

    if hWnd <> 0 then
    begin
      ShowWindow(hwnd, 1);
      BringWindowToTop(hwnd);
      SetForegroundWindow(hWnd);
      Windows.SetFocus(hWnd);
      SetWindowPos(hWnd, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOREPOSITION or SWP_NOMOVE);
    end;
    SetWindowPos(Application.Handle, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOREPOSITION or SWP_NOMOVE);  *)

    SetWindowPos(Application.Handle, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);

    we_resumed := true;
    we_suspended := false;
    suspendrunning := false;
    resumerunning := false;
    resumerunning_start := 0;
end;

procedure Tmainform.OnSuspend(var Msg: TMessage; ignorerunning : Boolean);
var
  Info: TShellExecuteInfo;
  pInfo: PShellExecuteInfo;
  exitCode: DWord;
  startchecktime : longint;
  i : longint;
begin
    if (suspendrunning) then
    begin
      debuginfo.Lines.Insert(0, getdatum+' Suspend is already running go to exit');
      exit;
    end;
    // Resume läuft und wir dürfen es NICHT ignorieren
    if (resumerunning and not ignorerunning) then
    begin
      debuginfo.Lines.Insert(0, getdatum+' resume is running wait for end');
      startchecktime := DelphiDateTimeToUnix(Now);
      while (resumerunning) do
      begin
            Application.ProcessMessages;
            Sleep(500);
            // wait a minimum of 3 seconds AND suspendrunning_time is min. 3 seconds old
//            if (((startchecktime+3) < DelphiDateTimeToUnix(Now)) and ((resumerunning_start+3) < DelphiDateTimeToUnix(Now))) then
//            begin
//              debuginfo.Lines.Insert(0, getdatum+' resume running timed out > 3s');
//              resumerunning_start := 0;
//              resumerunning := false;
//            end;
      end;
      debuginfo.Lines.Insert(0, getdatum+' resume running is done - go again to onSuspend');
      OnSuspend(Msg, false);
      exit;
    end;
    suspendrunning := true;
    suspendrunning_start := DelphiDateTimeToUnix(Now);
    we_resumed := false;
    SetThreadExecutionState(ES_SYSTEM_REQUIRED);

    debuginfo.Lines.Insert(0, getdatum+' Starting '+ExtractFilePath(Application.ExeName)+'\stop_mp.bat');

  pInfo := @Info;
  with Info do
  begin
    cbSize := SizeOf(Info);
    fMask  := SEE_MASK_NOCLOSEPROCESS or SEE_MASK_NO_CONSOLE;
    wnd    := application.Handle;
    lpVerb := NIL;
    lpFile := PChar(ExtractFilePath(Application.ExeName)+'\stop_mp.bat');
    lpParameters := PChar(#0);
    lpDirectory  := PCHAR(ExtractFilePath(Application.ExeName));
    nShow        := SW_SHOWNORMAL;
    hInstApp     := 0;
  end;

  SetThreadExecutionState(ES_SYSTEM_REQUIRED);
  ShellExecuteEx(pInfo);

  suspendrunning_start := DelphiDateTimeToUnix(Now);
  repeat
    exitCode := WaitForSingleObject(Info.hProcess, 15000);
  until (exitCode <> WAIT_TIMEOUT);

  debuginfo.Lines.Insert(0, getdatum+' Starting '+ExtractFilePath(Application.ExeName)+'\stop_mp.bat'+ ' DONE');
  SetThreadExecutionState(ES_CONTINUOUS);

  SetWindowPos(Application.Handle, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);

  we_suspended := true;
  we_resumed := false;
  suspendrunning := false;
  resumerunning := false;
  resumerunning_start := 0;
end;

procedure Tmainform.resumetimerTimer(Sender: TObject);
var startchecktime : longint;
    Message : TMessage;
begin
   resumetimer.Enabled := false;

   SetWindowPos(Application.Handle, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);

   // wir laufen das erste mal
   if (lastresumetimer_run = 0) then
   begin
     lastresumetimer_run := DelphiDateTimeToUnix(Now);
     resumetimer.Enabled := true;
     exit;
   end;

   // OK soll ausgeführt werden, wenn wir laufen aber NICHT resumed sind
   if (not we_resumed and not resumerunning and not suspendrunning) then
   begin
     debuginfo.Lines.Insert(0, getdatum+' We are not we_resumed and not resumerunning and not suspendrunning but timer is active wait 4s');
     if ((lastresumetimer_run+4) > DelphiDateTimeToUnix(Now)) then
     begin
       debuginfo.Lines.Insert(0, getdatum+' Last run is not older than 4s');
       lastresumetimer_run := DelphiDateTimeToUnix(Now);
       resumetimer.Enabled := true;
       exit;
     end;

     startchecktime := DelphiDateTimeToUnix(Now);
     while ((startchecktime+4) >= DelphiDateTimeToUnix(Now)) do
     begin
            Application.ProcessMessages;
            Sleep(50);
            if (we_resumed or resumerunning or suspendrunning) then
            begin
             debuginfo.Lines.Insert(0, getdatum+' Now Resume or suspend is running or we are in a state');
             lastresumetimer_run := DelphiDateTimeToUnix(Now);
             resumetimer.Enabled := true;
             exit;
            end;
     end;
     debuginfo.Lines.Insert(0, getdatum+' We are STILL not we_resumed and not resumerunning and not suspendrunning but time is active - so DO onresume');
     debuginfo.Lines.Insert(0, getdatum+' Windows has resumed from standby mode but does not want to tell us this');

     critical.Acquire;
     onResume(Message, false);
     critical.Release;
   end;

   SetWindowPos(Application.Handle, HWND_BOTTOM, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE or SWP_NOACTIVATE);

  lastresumetimer_run := DelphiDateTimeToUnix(Now);
   resumetimer.Enabled := true;
end;

procedure Tmainform.WMSysCommand(var Msg: TWMSysCommand);
begin
 inherited;
 Case Msg.CmdType of
  SC_MINIMIZE: begin
  Hide;  end;
 end;
 DefaultHandler(Msg);
end;

end.
