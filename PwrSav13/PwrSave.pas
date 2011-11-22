unit PwrSave;
//==============================================================================
// PwrSave: Delphi Component for Delphi 4,5,6,7
// Version 1.3
// Date 11 June 2004
// Copyright Jan Mitrovics 2002, 2003, 2004
//
// Send comments to: Mitrovics@web.de
//
// This is a freeware component! Use at own risk!
//
// COPYRIGHT:
// Copyright Jan Mitrovics 2002, 2003, 2004.
//
// DISCLAIMER:
// THIS COMPONENT IS PROVIDED AS IS! THE AUTHOR WILL TAKE NO RESPONSIBILITY
// FOR ANY DAMAGES RESULTING FORM THE USE OF THIS COMPONENT!
// The author disclaims any and all warranties, express or implied,
// oral or written, including any implied warranties of merchantability or
// fitness for a particular purpose.
// The author does not and cannot warrant the performance or results you may
// obtain by using the software or documentation.
//
// DISTRIBUTION:
// This component maybe freely distributed under following conditions:
//   Charging for the component is prohibited.
//   Distribution must be complete with all original files unchanged.
//   If you add own files, clearly identify that you are providing them.
//
// -----------------------------------------------------------------------------
//
// Purpose:
// Windows has the ability to shutdown / hibernate / standby when no user
// interaction takes place for a certain time. When writing programs for
// data aqcuisition, control systems or servers this might be very undesired.
// This component will prevent these events and/or gives you the opportunity
// to take necessary action when such events occur.
// In addition this program can as well prevent shutdown / log off initiated
// by the user.
//
// Function:
// This little component will catch the listed Windows messages that might
// intercept program execution.
//   WM_POWERBROADCAST with
//     PBT_APMQUERYSUSPEND   -> OnQuerySuspend
//     PBT_APMQUERYSTANDBY   -> OnQueryStandby
//   WM_QUERYENDSESSION  -> OnQueryEndSession, OnQueryLogoff, OnQueryShutdown
//
// It will fire the corresponding events, if an eventhandler has been assigned.
// If no eventhandler is assigned or user interaction is not allowed by Windows,
// then it will respond to the messages as defined by the properties:
//   AllowSuspend, AllowStandby, AllowEndSession
//
// In addition to this, events for the other APM messages are included.
//
// Usage:
// Drop the component on your main form.
// If you do not assign any event handlers and do not change the default values,
// then Windows will not shutdown / hibernate / standby (unless this is forced
// by a program / driver) and the user can not log off / shutdown while the
// program is running.
// Use the Events and the proporties to fine tune the behaviour.
// The Query events will give you a chance to e.g. display a dialog to ask the
// user what to do.
//
// If WM_QUERYENDSESSION is received, OnQueryEndSession and OnQueryLogoff or
// OnQueryShutdown will fire. OnQueryLogoff/Shutdown will fire first, then
// if Allow was true, OnQueryEndSession will fire.
// If any of events is returned with false in their parameter Allow, then the
// action (Logoff/Shutdown) is canceled.
// Note: Windows is querying applications one after the other. Therefor, it may
//       (and will) happen, that some application close, but your application
//       prevents Windows from Logoff/Shutdown when you set Allow to false.
//
// I have tested the component with Delphi 4, 5, 6, 7 and Windows XP pro, 2000
// and 98. However, testing has not been extensive. If you experience any
// problems, please let me know. (email: Mitrovics@web.de)
// If you test this component in other versions of Windows / Delphi, please
// send me a short report, so I can include it with the documentation.
//
// Check the Windows SDK Help or MSDN for more information
//
// History:
//
// Version 1.0, 22 July 2002:
//   # First official release only for Delphi 6
//
// Version 1.1, 22 August 2002:
//   # Support for Delphi 5 and Delhi 4 added
//     Remarks: This was simple, just added Forms to the uses statement.
//
// Version 1.2, 04 Ferbuary 2003:
//   # Bugfix: Windows could not exit when program was running
//     Remarks: wrong Message captured:
//              WM_ENDSESSION changed to WM_QUERYENDSESSION
//   # Support for Delphi 7 added
//     Remarks: Nothing to be done, just tested.
//
// Version 1.3, 11 June 2004:
//   # Added events: OnQueryLogoff, OnQueryShutdown
//
//==============================================================================

interface

uses
  Windows, Messages, SysUtils, Classes, Forms;

const
  // APM messages

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

  // ACLineStatus values
  AC_Offline =   0;
  AC_Online  =   1;
  AC_Unkown  = 255;

  // BatteryFlag values
  BF_High      =   1;
  BF_Low       =   2;
  BF_Critical  =   4;
  BF_Charging  =   8;
  BF_NoBattery = 128;
  BF_Unkown    = 255;

type

  TQueryEvent  = procedure(Sender: TObject; var Allow: boolean) of object;
  TPowerEvent  = procedure(Sender: TObject) of object;
  TOEMEvent    = procedure(Sender: TObject; dwEventCode: integer) of object;
               // dwEventCode depends on the hardware manufacturer
  TStatusEvent = procedure(Sender: TObject;
                           ACLineStatus, BatteryFlag, BatteryLifePercent: byte;
                           BatteryLifeTime, BatteryFullLifeTime: longword)
                           of object;
               // BatteryLifeTime and BatteryFullLifeTime is given in seconds

  TPwrSave = class(TComponent)
  private
    { Private declarations }
    FHWnd: THandle;
    FAllowSuspend: boolean;
    FAllowStandby: boolean;
    FAllowEndSession: boolean;
    FOnQuerySuspend: TQueryEvent;
    FOnQueryStandby: TQueryEvent;
    FOnQueryEndSession: TQueryEvent;
    FOnQueryLogoff: TQueryEvent;
    FOnQueryShutdown: TQueryEvent;
    FOnBatteryLow: TPowerEvent;
    FOnPowerStatusChange: TStatusEvent;
    FOnOemEvent: TOEMEvent;
    FOnQuerySuspendFailed: TPowerEvent;
    FOnQueryStandbyFailed: TPowerEvent;
    FOnResumeCritical: TPowerEvent;
    FOnResumeSuspend: TPowerEvent;
    FOnResumeStandby: TPowerEvent;
    FOnSuspend: TPowerEvent;
    FOnStandby: TPowerEvent;
    procedure WndProc(var Msg: TMessage);
  protected
    { Protected declarations }
    function QuerySuspend: boolean;
    function QueryStandby: boolean;
    function QueryEndSession: boolean;
    procedure PowerStatusChange;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    { Published declarations }
    property AllowSuspend: boolean read FAllowSuspend write FAllowSuspend;
    property AllowStandby: boolean read FAllowStandby write FAllowStandby;
    property AllowEndSession: boolean read FAllowEndSession write FAllowEndSession;
    property OnQuerySuspend: TQueryEvent read FOnQuerySuspend write FOnQuerySuspend;
    property OnQueryStandby: TQueryEvent read FOnQueryStandby write FOnQueryStandby;
    property OnQueryEndSession: TQueryEvent read FOnQueryEndSession write FOnQueryEndSession;
    property OnQueryLogoff: TQueryEvent read FOnQueryLogOff write FOnQueryLogoff;
    property OnQueryShutdown: TQueryEvent read FOnQueryShutdown write FOnQueryShutdown;
    property OnBatteryLow: TPowerEvent read FOnBatteryLow write FOnBatteryLow;
    property OnPowerStatusChange: TStatusEvent read FOnPowerStatusChange write FOnPowerStatusChange;
    property OnOemEvent: TOEMEvent read FOnOemEvent write FOnOemEvent;
    property OnQuerySuspendFailed: TPowerEvent read FOnQuerySuspendFailed write FOnQuerySuspendFailed;
    property OnQueryStandbyFailed: TPowerEvent read FOnQueryStandbyFailed write FOnQueryStandbyFailed;
    property OnResumeCritical: TPowerEvent read FOnResumeCritical write FOnResumeCritical;
    property OnResumeSuspend: TPowerEvent read FOnResumeSuspend write FOnResumeSuspend;
    property OnResumeStandby: TPowerEvent read FOnResumeStandby write FOnResumeStandby;
    property OnSuspend: TPowerEvent read FOnSuspend write FOnSuspend;
    property OnStandby: TPowerEvent read FOnStandby write FOnStandby;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('System', [TPwrSave]);
end;

{ TPwrSave }

procedure TPwrSave.WndProc(var Msg: TMessage);
var Allow: boolean;
begin
  inherited;
  if Msg.Msg = WM_POWERBROADCAST then
    case Msg.WParam of
      PBT_APMQUERYSUSPEND:
       begin
        if (Msg.LParam and 1) = 1 then
          Allow := QuerySuspend // Check for User Interaction
        else
          Allow := AllowSuspend;
        if Allow then
          Msg.Result := integer(true)
        else
          Msg.Result := BROADCAST_QUERY_DENY;
       end;
      PBT_APMQUERYSTANDBY:
       begin
        if (Msg.LParam and 1) = 1 then
          Allow := QueryStandby // Check for User Interaction
        else
          Allow := AllowStandby;
        if Allow then
          Msg.Result := integer(true)
        else
          Msg.Result := BROADCAST_QUERY_DENY;
       end;
      PBT_APMBATTERYLOW:
        if Assigned(FOnBatteryLow) then
          FOnBatteryLow(Self);
      PBT_APMPOWERSTATUSCHANGE:
        PowerStatusChange;
      PBT_APMOEMEVENT:
        if Assigned(FOnOemEvent) then
          FOnOemEvent(Self, Msg.LParam);
      PBT_APMQUERYSUSPENDFAILED:
        if Assigned(FOnQuerySuspendFailed) then
          FOnQuerySuspendFailed(Self);
      PBT_APMQUERYSTANDBYFAILED:
        if Assigned(FOnQueryStandbyFailed) then
          FOnQueryStandbyFailed(Self);
      PBT_APMRESUMECRITICAL:
        if Assigned(FOnResumeCritical) then
          FOnResumeCritical(Self);
      PBT_APMRESUMESUSPEND:
        if Assigned(FOnResumeSuspend) then
          FOnResumeSuspend(Self);
      PBT_APMRESUMESTANDBY:
        if Assigned(FOnResumeStandby) then
          FOnResumeStandby(Self);
      PBT_APMSUSPEND:
        if Assigned(FOnSuspend) then
          FOnSuspend(Self);
      PBT_APMSTANDBY:
        if Assigned(FOnStandby) then
          FOnStandby(Self);
    end
  else
    if Msg.Msg = WM_QUERYENDSESSION then
     begin
       Allow := true;
       if Msg.LParam = 0 then  // Shutdown
        begin
         if Assigned(FOnQueryShutdown) then
           FOnQueryShutdown(Self, Allow);
        end
       else // Logoff
        begin
         if Assigned(FOnQueryLogoff) then
           FOnQueryLogoff(Self, Allow);
        end;
       if Allow then
         Allow := QueryEndSession;
       Msg.Result := integer(Allow);
     end;
end;

function TPwrSave.QuerySuspend: boolean;
begin
  if Assigned(FOnQuerySuspend) then
    FOnQuerySuspend(Self, Result)
  else
    Result := AllowSuspend;
end;

function TPwrSave.QueryStandby: boolean;
begin
  if Assigned(FOnQueryStandby) then
    FOnQueryStandby(Self, Result)
  else
    Result := AllowStandby;
end;

function TPwrSave.QueryEndSession: boolean;
begin
  if Assigned(FOnQueryEndSession) then
    FOnQueryEndSession(Self, Result)
  else
    Result := AllowEndSession;
end;

procedure TPwrSave.PowerStatusChange;
var Status: _SYSTEM_POWER_STATUS;
begin
  if Assigned(FOnPowerStatusChange) then
    if GetSystemPowerStatus(Status) then
     begin
      FOnPowerStatusChange(Self, Status.ACLineStatus, Status.BatteryFlag,
                           Status.BatteryLifePercent, Status.BatteryLifeTime,
                           Status.BatteryFullLifeTime);
     end;
end;

constructor TPwrSave.Create(AOwner: TComponent);
begin
  inherited;
  if not (csDesigning in ComponentState) then
    FHWnd := AllocateHWnd(WndProc);
end;

destructor TPwrSave.Destroy;
begin
  if not (csDesigning in ComponentState) then
    DeallocateHWnd(FHwnd);
  inherited;
end;

end.
