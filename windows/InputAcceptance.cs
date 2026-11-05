using System;
using System.IO;
using System.Drawing;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Runtime.Serialization;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace StillHere.Windows {
    [DataContract] internal sealed class InputAcceptance {
        [DataMember] public string Source="guarded Windows SendInput on the application's own temporary QA fixture";
        [DataMember] public string Phase="starting";
        [DataMember] public bool ShortcutEnabled;
        [DataMember] public bool ShortcutRegistered;
        [DataMember] public bool TypedAndClickedWhileProtected;
        [DataMember] public bool WrongPasswordRejected;
        [DataMember] public bool CancelKeptProtection;
        [DataMember] public bool QuitAcknowledged;
        [DataMember] public bool CorrectPasswordExited;
        [DataMember] public bool ProtectionReleased;
        [DataMember] public CaptureResult CaptureQualification;
        [DataMember] public string Error;
    }
    internal sealed partial class TrayContext {
        private InputAcceptance inputAcceptance;
        private string inputAcceptanceOutput;
        private Timer inputWatchdog;
        internal bool InputAcceptancePassed { get { return inputAcceptance!=null && inputAcceptance.Phase=="passed" && inputAcceptance.Error==null; } }
        private void SaveInputAcceptance() {
            if(inputAcceptance==null || inputAcceptanceOutput==null) return;
            inputAcceptance.CaptureQualification=store.Read<CaptureResult>("compatibility.json");
            Program.Output(inputAcceptance,inputAcceptanceOutput);
        }
        private async Task WaitFor(Func<bool> condition,int milliseconds) {
            DateTime until=DateTime.UtcNow.AddMilliseconds(milliseconds);
            while(!condition()) { if(DateTime.UtcNow>until) throw new TimeoutException("Native input step timed out: "+inputAcceptance.Phase); await Task.Delay(100); }
        }
        private static void Inject(List<Native.Input> input) {
            if(Native.SendInput((uint)input.Count,input.ToArray(),Marshal.SizeOf(typeof(Native.Input)))!=(uint)input.Count)
                throw new Win32Exception(Marshal.GetLastWin32Error(),"Windows input injection was not accepted.");
        }
        private static Native.Input Key(ushort key,bool up) { return new Native.Input { Type=1,Data=new Native.InputData { Keyboard=new Native.KeyboardInput { Key=key,Flags=up?2u:0u } } }; }
        private static void Press(ushort key) { Inject(new List<Native.Input> { Key(key,false),Key(key,true) }); }
        private static void Shortcut() {
            Inject(new List<Native.Input> { Key(0x11,false),Key(0x12,false),Key(0x10,false),Key(0x50,false),Key(0x50,true),Key(0x10,true),Key(0x12,true),Key(0x11,true) });
        }
        private static void TypeUnicode(string text) {
            List<Native.Input> inputs=new List<Native.Input>();
            foreach(char c in text) {
                inputs.Add(new Native.Input { Type=1,Data=new Native.InputData { Keyboard=new Native.KeyboardInput { Scan=c,Flags=4 } } });
                inputs.Add(new Native.Input { Type=1,Data=new Native.InputData { Keyboard=new Native.KeyboardInput { Scan=c,Flags=6 } } });
            }
            Inject(inputs);
        }
        private void ClickOwn(Control control) {
            if(Native.GetForegroundWindow()!=fixture.Handle) throw new InvalidOperationException("The QA fixture lost foreground ownership; input was not sent.");
            Point p=control.PointToScreen(new Point(control.Width/2,control.Height/2));
            Native.SetCursorPos(p.X,p.Y);
            Inject(new List<Native.Input> {
                new Native.Input { Type=0,Data=new Native.InputData { Mouse=new Native.MouseInput { Flags=2 } } },
                new Native.Input { Type=0,Data=new Native.InputData { Mouse=new Native.MouseInput { Flags=4 } } }
            });
        }
        private void AcquireOwnFixture() {
            fixture.TopMost=true; fixture.BringToFront();
            Point point=fixture.InputField.PointToScreen(new Point(fixture.InputField.Width/2,fixture.InputField.Height/2));
            if(Native.GetAncestor(Native.WindowFromPoint(point),2)!=fixture.Handle)
                throw new InvalidOperationException("The visible click target is not the QA fixture; input was not sent.");
            Native.SetCursorPos(point.X,point.Y);
            Inject(new List<Native.Input> {
                new Native.Input { Type=0,Data=new Native.InputData { Mouse=new Native.MouseInput { Flags=2 } } },
                new Native.Input { Type=0,Data=new Native.InputData { Mouse=new Native.MouseInput { Flags=4 } } }
            });
        }
        private void RequireOwnPasswordDialog() {
            Control form=Control.FromHandle(Native.GetForegroundWindow());
            if(!(form is PasswordDialog)) throw new InvalidOperationException("The password dialog is not the foreground window; input was not sent.");
        }
        private async void StartInputAcceptance(string password,string output) {
            if(String.IsNullOrEmpty(password)) return;
            inputAcceptance=new InputAcceptance(); inputAcceptanceOutput=output;
            inputWatchdog=new Timer { Interval=55000 };
            inputWatchdog.Tick+=delegate { inputAcceptance.Error="QA watchdog timeout"; HidePrivacy(); ExitThread(); };
            inputWatchdog.Start();
            try {
                await Task.Delay(600);
                inputAcceptance.ShortcutRegistered=commands.ShortcutRegistered;
                if(!commands.ShortcutRegistered) throw new InvalidOperationException("The QA shortcut was not registered; no shortcut input was sent.");
                AcquireOwnFixture(); await Task.Delay(250);
                if(Native.GetForegroundWindow()!=fixture.Handle) throw new InvalidOperationException("The QA fixture did not become the foreground window.");
                fixture.TopMost=false;
                inputAcceptance.Phase="enabling"; SaveInputAcceptance(); Shortcut();
                await WaitFor(delegate { return Active; },6000);
                inputAcceptance.ShortcutEnabled=true;
                ClickOwn(fixture.InputField); await Task.Delay(150); TypeUnicode("StillHere native HID input"); await Task.Delay(250);
                ClickOwn(fixture.RecordButton); await Task.Delay(400);
                if(!Active || fixture.RecordedOutput.Text!="已记录 #1：StillHere native HID input") throw new Exception("Input did not reach the real fixture under the privacy layer.");
                inputAcceptance.TypedAndClickedWhileProtected=true; inputAcceptance.Phase="protected-input-pass"; SaveInputAcceptance();
                // Leave time for an independent remote viewer to observe the changed
                // fixture while the physical display remains covered.
                await Task.Delay(15000);
                if(Native.GetForegroundWindow()!=fixture.Handle) throw new Exception("QA lost foreground ownership before unlock test.");
                inputAcceptance.Phase="wrong-password"; SaveInputAcceptance(); Shortcut();
                await WaitFor(delegate { return authenticationOpen; },3000); await Task.Delay(300); RequireOwnPasswordDialog();
                TypeUnicode("controlled-wrong-password"); Press(0x0D); await Task.Delay(500);
                if(failedAttempts!=1 || !Active || !authenticationOpen) throw new Exception("Wrong password did not leave protection active.");
                inputAcceptance.WrongPasswordRejected=true;
                RequireOwnPasswordDialog(); Press(0x1B); await WaitFor(delegate { return !authenticationOpen; },3000);
                if(!Active) throw new Exception("Cancel removed privacy.");
                inputAcceptance.CancelKeptProtection=true; inputAcceptance.Phase="quit-password"; SaveInputAcceptance();
                inputAcceptance.QuitAcknowledged=Native.SendCommand("StillHere.Command."+store.Scope,"quit");
                if(!inputAcceptance.QuitAcknowledged) throw new Exception("Quit request was not acknowledged.");
                await WaitFor(delegate { return authenticationOpen; },3000); await Task.Delay(300); RequireOwnPasswordDialog();
                TypeUnicode(password); Press(0x0D);
            } catch(Exception e) {
                inputAcceptance.Error=e.Message+" LastCommand="+(lastCommand??"none")+" CaptureQualified="+store.Qualified()+" Probing="+probing;
                inputAcceptance.Phase="failed"; SaveInputAcceptance(); HidePrivacy(); ExitThread();
            }
        }
        private void FinishInputAcceptance() {
            if(inputAcceptance==null) return;
            if(inputWatchdog!=null) { inputWatchdog.Stop(); inputWatchdog.Dispose(); }
            inputAcceptance.ProtectionReleased=!Active;
            if(inputAcceptance.CorrectPasswordExited && inputAcceptance.Error==null) inputAcceptance.Phase="passed";
            SaveInputAcceptance();
        }
    }
}
