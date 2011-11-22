object mainform: Tmainform
  Left = 211
  Top = 1
  Caption = 'Powertool Info'
  ClientHeight = 316
  ClientWidth = 563
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesigned
  OnClose = FormClose
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object debuginfo: TMemo
    Left = 8
    Top = 8
    Width = 538
    Height = 276
    Ctl3D = False
    ParentCtl3D = False
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object Button1: TButton
    Left = 481
    Top = 290
    Width = 65
    Height = 20
    Caption = 'Close'
    TabOrder = 1
    OnClick = Button1Click
  end
  object resumetimer: TTimer
    Interval = 2500
    OnTimer = resumetimerTimer
    Left = 8
    Top = 288
  end
end
