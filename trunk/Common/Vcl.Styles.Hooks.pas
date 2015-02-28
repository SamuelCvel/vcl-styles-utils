//**************************************************************************************************
//
// Unit Vcl.Styles.Hooks
// unit for the VCL Styles Utils
// http://code.google.com/p/vcl-styles-utils/
//
// The contents of this file are subject to the Mozilla Public License Version 1.1 (the "License");
// you may not use this file except in compliance with the License. You may obtain a copy of the
// License at http://www.mozilla.org/MPL/
//
// Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF
// ANY KIND, either express or implied. See the License for the specific language governing rights
// and limitations under the License.
//
// The Original Code is Vcl.Styles.Hooks.pas.
//
// The Initial Developer of the Original Code is Rodrigo Ruz V.
// Portions created by Rodrigo Ruz V. are Copyright (C) 2013-2015 Rodrigo Ruz V.
// All Rights Reserved.
//
//**************************************************************************************************
unit Vcl.Styles.Hooks;

interface

implementation

{$DEFINE HOOK_UXTHEME}
{$DEFINE HOOK_TDateTimePicker}
{$DEFINE HOOK_TProgressBar}

uses
  DDetours,
  System.SyncObjs,
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  WinApi.Windows,
  WinApi.Messages,
  Vcl.Graphics,
{$IFDEF HOOK_UXTHEME}
  Vcl.Styles.UxTheme,
{$ENDIF}
  Vcl.Styles.Utils.SysControls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ComCtrls,
  Vcl.Themes;

type
  TListStyleBrush = TObjectDictionary<Integer, TBrush>;

var
  VCLStylesBrush   : TObjectDictionary<string, TListStyleBrush>;
  VCLStylesLock    : TCriticalSection = nil;

  TrampolineGetSysColor           : function (nIndex: Integer): DWORD; stdcall =  nil;
  TrampolineGetSysColorBrush      : function (nIndex: Integer): HBRUSH; stdcall=  nil;
  //TrampolineCreateSolidBrush      : function (p1: COLORREF): HBRUSH; stdcall  = nil;
  //TrampolineSelectObject          : function (DC: HDC; p2: HGDIOBJ): HGDIOBJ; stdcall = nil;
  //TrampolineGetStockObject        : function (Index: Integer): HGDIOBJ; stdcall = nil;
  //TrampolineSetBkColor            : function (DC: HDC; Color: COLORREF): COLORREF; stdcall = nil;
  TrampolineFillRect              : function (hDC: HDC; const lprc: TRect; hbr: HBRUSH): Integer; stdcall = nil;
  TrampolineDrawEdge              : function (hdc: HDC; var qrc: TRect; edge: UINT; grfFlags: UINT): BOOL; stdcall = nil;
  //TrampolineFrameRect             : function (hDC: HDC; const lprc: TRect; hbr: HBRUSH): Integer; stdcall = nil;


//function  Detour_FrameRect(hDC: HDC; const lprc: TRect; hbr: HBRUSH): Integer; stdcall;
//begin
//  OutputDebugString(PChar('Detour_FrameRect hbr '+IntToStr(hbr)));
//  Result:=TrampolineFrameRect(hDC, lprc, hbr);
//end;


function Detour_DrawEdge(hdc: HDC; var qrc: TRect; edge: UINT; grfFlags: UINT): BOOL; stdcall;
begin
 if StyleServices.IsSystemStyle or not TSysStyleManager.Enabled  then
   Exit(TrampolineDrawEdge(hdc, qrc, edge, grfFlags));

    case  edge of
      BDR_RAISEDOUTER,
      BDR_SUNKENOUTER,
      BDR_RAISEDINNER,
      BDR_SUNKENINNER,
      EDGE_SUNKEN,
      EDGE_ETCHED,
      EDGE_BUMP,
      EDGE_RAISED :
        begin
          DrawStyleEdge(hdc, qrc, TStyleElementEdges(edge), TStyleElementEdgeFlags(grfFlags));
          Exit(True);
        end;
    end;
   Exit(TrampolineDrawEdge(hdc, qrc, edge, grfFlags));
end;

//function  Detour_CreateSolidBrush(p1: COLORREF): HBRUSH; stdcall;
//begin
//  OutputDebugString(PChar('Detour_CreateSolidBrush p1 '+IntToStr(p1)));
//  result:= TrampolineCreateSolidBrush(p1);
//end;

//function  Detour_SelectObject(DC: HDC; p2: HGDIOBJ): HGDIOBJ; stdcall; //need decode p2
//begin
//  OutputDebugString(PChar('Detour_SelectObject p2 '+IntToStr(p2)));
// Result:= TrampolineSelectObject(DC, p2);
//end;

//function  Detour_GetStockObject(Index: Integer): HGDIOBJ; stdcall;   //returns 4,5,13
//begin
//  OutputDebugString(PChar('Detour_GetStockObject Index '+IntToStr(Index)));
//  Result:=TrampolineGetStockObject(Index);
//end;

//function  Detour_SetBkColor(DC: HDC; Color: COLORREF): COLORREF; stdcall;
//begin
// //OutputDebugString(PChar('Detour_SetBkColor Color '+IntToStr(Color)));
// Result:=TrampolineSetBkColor(DC, Color);
//end;


{
From MSDN
The brush identified by the hbr parameter may be either a handle to a logical brush or a color value.
 ...
 ...
 If specifying a color value for the hbr parameter, it must be one of the standard system colors (the value 1 must be added to the chosen color).
 For example:
 FillRect(hdc, &rect, (HBRUSH) (COLOR_WINDOW+1));
}
function  Detour_FillRect(hDC: HDC; const lprc: TRect; hbr: HBRUSH): Integer; stdcall;
begin
 if StyleServices.IsSystemStyle or not TSysStyleManager.Enabled  then
  Exit(TrampolineFillRect(hDC, lprc, hbr))
 else
 if (hbr>0) and (hbr<COLOR_ENDCOLORS+1) then
  Exit(TrampolineFillRect(hDC, lprc, GetSysColorBrush(hbr-1)))
 else
  Exit(TrampolineFillRect(hDC, lprc, hbr));
end;

function Detour_GetSysColor(nIndex: Integer): DWORD; stdcall;
begin
  if StyleServices.IsSystemStyle or not TSysStyleManager.Enabled  then
    Result:= TrampolineGetSysColor(nIndex)
  else
  if nIndex= COLOR_HOTLIGHT then
    Result:= DWORD(StyleServices.GetSystemColor(clHighlight))
  else
    Result:= DWORD(StyleServices.GetSystemColor(TColor(nIndex or Integer($FF000000))));

  //OutputDebugString(PChar('Detour_GetSysColor nIndex '+IntToStr(nIndex)) );
end;

function Detour_GetSysColorBrush(nIndex: Integer): HBRUSH; stdcall;
var
  LCurrentStyleBrush : TListStyleBrush;
  LBrush : TBrush;
  LColor : TColor;
begin
  VCLStylesLock.Enter;
  try
    if StyleServices.IsSystemStyle or not TSysStyleManager.Enabled  then
     Exit(TrampolineGetSysColorBrush(nIndex))
    else
    begin
     if VCLStylesBrush.ContainsKey(StyleServices.Name) then
      LCurrentStyleBrush:=VCLStylesBrush.Items[StyleServices.Name]
     else
     begin
       VCLStylesBrush.Add(StyleServices.Name, TListStyleBrush.Create([doOwnsValues]));
       LCurrentStyleBrush:=VCLStylesBrush.Items[StyleServices.Name];
     end;

     if LCurrentStyleBrush.ContainsKey(nIndex) then
     begin
      LBrush:=LCurrentStyleBrush.Items[nIndex];
//      if GetObject(LBrush.Handle, SizeOf(TLogBrush), @LogBrush) <> 0 then
//        OutputDebugString(PChar(Format('nIndex %d Color %x RGB %x  GetObject %x', [nIndex, LBrush.Color, ColorToRGB(LBrush.Color), LogBrush.lbColor])));
      Exit(LBrush.Handle);
     end
     else
//     if LCurrentStyleBrush.ContainsKey(nIndex) then
//      LCurrentStyleBrush.Remove(nIndex);
     begin
       LBrush:=TBrush.Create;
       LCurrentStyleBrush.Add(nIndex, LBrush);
       if nIndex= COLOR_WINDOW then
       begin
         LBrush.Color:= StyleServices.GetSystemColor(clWindow);
         LColor := LBrush.Color;
         case LColor of
          $303030, $232323, $644239, $121212 : LBrush.Color:= LColor + 1;
         end;
       end
       else
       if nIndex= COLOR_HOTLIGHT then
         LBrush.Color:=StyleServices.GetSystemColor(clHighlight)
       else
         LBrush.Color:= StyleServices.GetSystemColor(TColor(nIndex or Integer($FF000000)));
       //OutputDebugString(PChar(Format('nIndex %d Color %x RGB %x', [nIndex, LBrush.Color, ColorToRGB(LBrush.Color)])));
       Exit(LBrush.Handle);
     end;
    end;
  finally
    VCLStylesLock.Leave;
  end;
end;


initialization
  VCLStylesLock := TCriticalSection.Create;
  VCLStylesBrush := TObjectDictionary<string, TListStyleBrush>.Create([doOwnsValues]);

 if StyleServices.Available then
 begin

   {$IFDEF  HOOK_TDateTimePicker}
   TCustomStyleEngine.RegisterStyleHook(TDateTimePicker, TStyleHook);
   {$ENDIF}
   {$IFDEF  HOOK_TProgressBar}
   TCustomStyleEngine.RegisterStyleHook(TProgressBar, TStyleHook);
   {$ENDIF}

   @TrampolineGetSysColor         :=  InterceptCreate(user32, 'GetSysColor', @Detour_GetSysColor);
   @TrampolineGetSysColorBrush    :=  InterceptCreate(user32, 'GetSysColorBrush', @Detour_GetSysColorBrush);
   @TrampolineFillRect            :=  InterceptCreate(user32, 'FillRect', @Detour_FillRect);
   @TrampolineDrawEdge            :=  InterceptCreate(user32, 'DrawEdge', @Detour_DrawEdge);
   //@TrampolineFrameRect           :=  InterceptCreate(user32, 'FrameRect', @Detour_FrameRect);
 end;

finalization
  InterceptRemove(@TrampolineGetSysColor);
  InterceptRemove(@TrampolineGetSysColorBrush);
  InterceptRemove(@TrampolineFillRect);
  InterceptRemove(@TrampolineDrawEdge);
  //InterceptRemove(@TrampolineFrameRect);

  VCLStylesBrush.Free;
  VCLStylesLock.Free;
  VCLStylesLock := nil;
end.
