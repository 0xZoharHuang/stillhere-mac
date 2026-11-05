using System;
using System.IO;
using System.Drawing;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using Microsoft.Win32;

namespace StillHere.Windows {
    [DataContract] internal sealed class RuntimeState {
        [DataMember] public string Version="0.1.0";
        [DataMember] public int PID=System.Diagnostics.Process.GetCurrentProcess().Id;
        [DataMember] public bool Running=true;
        [DataMember] public bool Protected;
        [DataMember] public int PrivacyWindows;
        [DataMember] public int Screens;
        [DataMember] public bool AuthenticationOpen;
        [DataMember] public bool CaptureQualified;
        [DataMember] public bool ShortcutRegistered;
        [DataMember] public string LastCommand;
        [DataMember] public int ShortcutPressCount;
        [DataMember] public string UpdatedAt;
    }
    internal sealed class CommandWindow : Form {
        private readonly Action<string> action;
        internal bool ShortcutRegistered;
        internal CommandWindow(string title,Action<string> handler) {
            action=handler; Text=title; ShowInTaskbar=false;
            FormBorderStyle=FormBorderStyle.None; StartPosition=FormStartPosition.Manual;
            Bounds=new Rectangle(-32000,-32000,1,1);
            ShortcutRegistered=Native.RegisterHotKey(Handle,1,0x4007,0x50);
        }
        protected override void WndProc(ref Message m) {
            if(m.Msg==Native.HotKey && m.WParam==new IntPtr(1)) {
                BeginInvoke((Action)delegate { action("toggle"); }); m.Result=IntPtr.Zero; return;
            }
            if(m.Msg==Native.CopyData) {
                Native.CopyDataValue value=(Native.CopyDataValue)Marshal.PtrToStructure(m.LParam,typeof(Native.CopyDataValue));
                if(value.Tag==new IntPtr(1) && value.Length>0 && value.Length<=512) {
                    string command=Marshal.PtrToStringUni(value.Data);
                    BeginInvoke((Action)delegate { action(command); });
                    m.Result=new IntPtr(1);
                }
                return;
            }
            base.WndProc(ref m);
        }
        protected override void Dispose(bool disposing) { if(IsHandleCreated) Native.UnregisterHotKey(Handle,1); base.Dispose(disposing); }
    }
    internal sealed partial class TrayContext : ApplicationContext {
        private readonly Store store;
        private readonly NotifyIcon tray;
        private readonly CommandWindow commands;
        private readonly System.Threading.SynchronizationContext ui;
        private Preferences preferences;
        private readonly List<PrivacySurface> surfaces=new List<PrivacySurface>();
        private Image image;
        private bool authenticationOpen,probing,quitting;
        private string lastCommand;
        private int shortcutPressCount;
        private int failedAttempts;
        private DateTime retryAfter=DateTime.MinValue;
        private AutomationFixture fixture;
        private ToolStripMenuItem status,toggle,settings;
        private bool Active { get { return surfaces.Count>0; } }
        internal TrayContext(Store storage,bool showFixture,string qaPassword=null,string qaOutput=null) {
            store=storage;
            try { preferences=store.Read<Preferences>("preferences.json")??new Preferences(); } catch { preferences=new Preferences(); }
            image=LoadImage();
            ui=new WindowsFormsSynchronizationContext();
            commands=new CommandWindow("StillHere.Command."+store.Scope,HandleCommand);
            ContextMenuStrip menu=new ContextMenuStrip();
            status=new ToolStripMenuItem("在场 · 正常显示") { Enabled=false };
            toggle=new ToolStripMenuItem("开启隐私壁纸",null,delegate { Toggle(); });
            settings=new ToolStripMenuItem("壁纸与退出密码…",null,delegate { Settings(); });
            menu.Items.Add(status); menu.Items.Add(new ToolStripSeparator()); menu.Items.Add(toggle); menu.Items.Add(settings);
            menu.Items.Add(new ToolStripMenuItem("检查采集兼容性",null,delegate { Diagnose(false); }));
            menu.Items.Add(new ToolStripSeparator());
            menu.Items.Add(new ToolStripMenuItem("退出在场",null,delegate { Quit(); }));
            tray=new NotifyIcon { Icon=Icon.ExtractAssociatedIcon(Application.ExecutablePath),Text="在场 · StillHere",ContextMenuStrip=menu,Visible=true };
            tray.DoubleClick+=delegate { Toggle(); };
            SystemEvents.DisplaySettingsChanged+=DisplaysChanged;
            Publish(true);
            Timer startup=new Timer { Interval=150 };
            startup.Tick+=delegate {
                startup.Stop(); startup.Dispose();
                if(showFixture) ShowFixture();
                else { try { if(store.LoadCredential()==null) Settings(); } catch(Exception e) { Error(e.Message); } }
                if(qaOutput!=null) StartInputAcceptance(qaPassword,qaOutput);
            };
            startup.Start();
        }
        private Image LoadImage() {
            try {
                if(!String.IsNullOrEmpty(preferences.Wallpaper) && Path.GetFileName(preferences.Wallpaper)==preferences.Wallpaper) {
                    using(Image source=Image.FromFile(store.FilePath(preferences.Wallpaper))) return new Bitmap(source);
                }
            } catch { }
            using(Stream stream=typeof(TrayContext).Assembly.GetManifestResourceStream("StillHere.DefaultWallpaper"))
            using(Image source=Image.FromStream(stream)) return new Bitmap(source);
        }
        private void HandleCommand(string command) {
            if(command!="toggle" && command!="shield" && command!="unlock" && command!="quit" && command!="settings" && command!="fixture") return;
            lastCommand=command;
            if(command=="toggle") shortcutPressCount++;
            Publish(true);
            switch(command) {
                case "toggle": Toggle(); break;
                case "shield": Enable(); break;
                case "unlock": if(Active) Authenticate(false); break;
                case "quit": Quit(); break;
                case "settings": if(!Active) Settings(); break;
                case "fixture": ShowFixture(); break;
            }
        }
        private void Toggle() { if(Active) Authenticate(false); else Enable(); }
        private void Enable() {
            if(Active || probing) return;
            try {
                if(store.LoadCredential()==null) { Settings(); return; }
                if(!commands.ShortcutRegistered) { Error("退出快捷键注册失败，未开启防窥。"); return; }
                if(!store.Qualified()) { Diagnose(true); return; }
                Rebuild();
            } catch(Exception e) { Error(e.Message); }
        }
        private void Rebuild() {
            List<PrivacySurface> next=new List<PrivacySurface>();
            try {
                foreach(Screen screen in Screen.AllScreens) {
                    PrivacySurface surface=new PrivacySurface(screen.Bounds,Color.FromArgb(250,240,220),image,true);
                    next.Add(surface); surface.Present();
                }
            } catch { foreach(PrivacySurface surface in next) surface.Dispose(); throw; }
            foreach(PrivacySurface surface in surfaces) surface.Dispose();
            surfaces.Clear(); surfaces.AddRange(next);
            Native.SetThreadExecutionState(preferences.KeepAwake?0x80000003:0x80000000);
            Publish(true);
        }
        private void HidePrivacy() {
            foreach(PrivacySurface surface in surfaces) surface.Dispose(); surfaces.Clear();
            Native.SetThreadExecutionState(0x80000000); Publish(true);
        }
        private async void Diagnose(bool enableAfter) {
            if(probing || Active) return;
            probing=true;
            try {
                CaptureResult result=await CaptureProbe.RunAsync();
                if(quitting) return;
                store.Save("compatibility.json",result);
                if(!result.Passed) Error("采集检查未通过，未开启全屏壁纸。请确认电脑已进入正常桌面。\n"+result.Error);
                else if(enableAfter) EnableAfterProbe();
                else MessageBox.Show("截图已排除保护层，下面画面能继续更新。请再验证实际自动化。","检查通过");
            } catch(Exception e) { Error(e.Message); }
            finally { probing=false; Publish(true); }
        }
        private void EnableAfterProbe() { Rebuild(); }
        private void Authenticate(bool quit) {
            if(authenticationOpen) return;
            authenticationOpen=true; Publish(true);
            try {
                using(PasswordDialog dialog=new PasswordDialog(quit,delegate(string password) {
                    if(DateTime.UtcNow<retryAfter) return "尝试次数较多，请稍后重试。";
                    try {
                        Credential value=store.LoadCredential();
                        if(value==null || !value.Matches(password)) {
                            failedAttempts++;
                            if(failedAttempts>=3) retryAfter=DateTime.UtcNow.AddSeconds(Math.Min(30,Math.Pow(2,Math.Min(5,failedAttempts-3))));
                            return "密码不正确，屏幕仍受保护。";
                        }
                        failedAttempts=0; retryAfter=DateTime.MinValue; return null;
                    } catch(Exception e) { return e.Message; }
                })) {
                    if(dialog.ShowDialog()==DialogResult.OK) { HidePrivacy(); if(quit) { if(inputAcceptance!=null) inputAcceptance.CorrectPasswordExited=true; ExitThread(); } }
                }
            } finally { authenticationOpen=false; if(!quitting) Publish(true); }
        }
        private void Quit() { if(Active) Authenticate(true); else ExitThread(); }
        private void Settings() {
            if(Active || authenticationOpen) return;
            try {
                bool again;
                do {
                    using(SettingsDialog dialog=new SettingsDialog(image,store.LoadCredential()!=null,preferences,
                        delegate(string current,string next,string confirmation) {
                            if(next!=confirmation) return "两次新密码不一致。";
                            try {
                                Credential old=store.LoadCredential();
                                if(old!=null && !old.Matches(current)) return "当前密码不正确。";
                                store.Save("credential.json",Credential.Create(next)); return null;
                            } catch(Exception e) { return e.Message; }
                        },ChooseImage,delegate(bool awake) { preferences.KeepAwake=awake; store.Save("preferences.json",preferences); })) {
                        again=dialog.ShowDialog()==DialogResult.Retry;
                    }
                } while(again);
            } catch(Exception e) { Error(e.Message); }
        }
        private void ChooseImage() {
            using(OpenFileDialog dialog=new OpenFileDialog { Filter="图片|*.png;*.jpg;*.jpeg;*.gif;*.bmp" }) {
                if(dialog.ShowDialog()!=DialogResult.OK) return;
                if(new FileInfo(dialog.FileName).Length>30*1024*1024) { Error("请选择小于 30 MB 的图片。"); return; }
                using(Image source=Image.FromFile(dialog.FileName)) {
                    string filename="wallpaper-"+Guid.NewGuid().ToString("N")+".png";
                    source.Save(store.FilePath(filename),System.Drawing.Imaging.ImageFormat.Png);
                    preferences.Wallpaper=filename; store.Save("preferences.json",preferences);
                    Image previous=image; image=new Bitmap(source); previous.Dispose();
                }
            }
        }
        private void ShowFixture() {
            if(fixture==null || fixture.IsDisposed) fixture=new AutomationFixture();
            fixture.Show(); fixture.Activate();
        }
        private void DisplaysChanged(object sender,EventArgs e) {
            ui.Post(delegate { if(Active && !quitting) { try { Rebuild(); } catch(Exception ex) { Error(ex.Message); } } },null);
        }
        private void Publish(bool running) {
            string text=Active?"在场 · 防窥中（"+surfaces.Count+" 屏）":"在场 · 正常显示";
            if(status!=null) { status.Text=text; toggle.Text=Active?"输入密码，解除防窥…":"开启隐私壁纸"; settings.Enabled=!Active; }
            if(tray!=null) tray.Text=text;
            try { store.Save("runtime.json",new RuntimeState { Running=running,Protected=Active,PrivacyWindows=surfaces.Count,Screens=Screen.AllScreens.Length,
                AuthenticationOpen=authenticationOpen,CaptureQualified=store.Qualified(),ShortcutRegistered=commands.ShortcutRegistered,
                LastCommand=lastCommand,ShortcutPressCount=shortcutPressCount,UpdatedAt=DateTime.UtcNow.ToString("o") }); }
            catch(Exception e) { System.Diagnostics.Debug.WriteLine(e.Message); }
        }
        private static void Error(string text) { MessageBox.Show(text,"在场 · StillHere",MessageBoxButtons.OK,MessageBoxIcon.Warning); }
        protected override void ExitThreadCore() {
            if(quitting) return; quitting=true;
            HidePrivacy(); Publish(false); SystemEvents.DisplaySettingsChanged-=DisplaysChanged;
            FinishInputAcceptance();
            if(fixture!=null) fixture.Dispose(); tray.Visible=false; tray.Dispose(); commands.Dispose(); image.Dispose();
            base.ExitThreadCore();
        }
    }
}
