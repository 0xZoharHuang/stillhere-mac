using System;
using System.Drawing;
using System.Windows.Forms;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading.Tasks;

namespace StillHere.Windows {
    internal sealed class PrivacySurface : NativeWindow,IDisposable {
        private Color color;
        internal readonly Rectangle Bounds;
        internal Image Wallpaper;
        internal PrivacySurface(Rectangle bounds,Color color,Image image,bool exclude) {
            Bounds=bounds; this.color=color; Wallpaper=image;
            try {
                // A raw popup has no Form activation or active-control handling.
                // WS_EX_NOACTIVATE is in place before the HWND is created.
                CreateHandle(new CreateParams {
                    Caption="StillHere Privacy Wallpaper",X=bounds.X,Y=bounds.Y,Width=bounds.Width,Height=bounds.Height,
                    Style=unchecked((int)0x88000000), // WS_POPUP | WS_DISABLED: wallpaper has no input controls.
                    ExStyle=Native.NoActivate|Native.Transparent|Native.Layered|Native.ToolWindow|0x8
                });
                if(!Native.SetLayeredWindowAttributes(Handle,0,255,2)) throw new Win32Exception(Marshal.GetLastWin32Error());
                if(exclude) SetExcluded();
            } catch { Dispose(); throw; }
        }
        internal bool IsHandleCreated { get { return Handle!=IntPtr.Zero; } }
        internal Color BackColor { get { return color; } set { color=value; Invalidate(); } }
        internal void Invalidate() { if(IsHandleCreated) Native.InvalidateRect(Handle,IntPtr.Zero,false); }
        internal void Update() { if(IsHandleCreated) Native.UpdateWindow(Handle); }
        public void Dispose() { if(IsHandleCreated) DestroyHandle(); }
        internal void SetExcluded() {
            uint actual;
            if(!Native.SetWindowDisplayAffinity(Handle,Native.ExcludeFromCapture) ||
               !Native.GetWindowDisplayAffinity(Handle,out actual) || actual!=Native.ExcludeFromCapture)
                throw new Win32Exception(Marshal.GetLastWin32Error(),"无法启用截图排除，未开启防窥。");
        }
        internal void Present() {
            if(!Native.SetWindowPos(Handle,new IntPtr(-1),Bounds.X,Bounds.Y,Bounds.Width,Bounds.Height,0x10|0x40))
                throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        protected override void WndProc(ref Message m) {
            if(m.Msg==0x21) { m.Result=new IntPtr(3); return; }
            if(m.Msg==0x84) { m.Result=new IntPtr(-1); return; }
            if(m.Msg==0x3D) { m.Result=IntPtr.Zero; return; }
            if(m.Msg==0x14) { m.Result=new IntPtr(1); return; }
            if(m.Msg==0x0F) {
                Native.PaintValue paint;
                IntPtr dc=Native.BeginPaint(Handle,out paint);
                try { using(Graphics graphics=Graphics.FromHdc(dc)) Paint(graphics); }
                finally { Native.EndPaint(Handle,ref paint); }
                m.Result=IntPtr.Zero; return;
            }
            base.WndProc(ref m);
        }
        private void Paint(Graphics graphics) {
            graphics.Clear(color);
            if(Wallpaper==null) return;
            double scale=Math.Min((double)Bounds.Width/Wallpaper.Width,(double)Bounds.Height/Wallpaper.Height);
            int width=(int)(Wallpaper.Width*scale),height=(int)(Wallpaper.Height*scale);
            graphics.DrawImage(Wallpaper,new Rectangle((Bounds.Width-width)/2,(Bounds.Height-height)/2,width,height));
            using(Font font=new Font(SystemFonts.MessageBoxFont.FontFamily,10f))
            using(Brush brush=new SolidBrush(Color.FromArgb(125,40,40,40))) {
                string hint="Ctrl + Alt + Shift + P  输入密码返回桌面";
                SizeF size=graphics.MeasureString(hint,font);
                graphics.DrawString(hint,font,brush,(Bounds.Width-size.Width)/2,Bounds.Height-size.Height-12);
            }
        }
    }
    internal static class CaptureProbe {
        internal static CaptureResult Run() {
            CaptureResult result=null;
            using(ApplicationContext context=new ApplicationContext())
            using(Timer kickoff=new Timer { Interval=1 }) {
                kickoff.Tick+=async delegate {
                    kickoff.Stop();
                    try { result=await RunAsync(); }
                    finally { context.ExitThread(); }
                };
                kickoff.Start(); Application.Run(context);
            }
            return result;
        }
        internal static async Task<CaptureResult> RunAsync() {
            CaptureResult result=new CaptureResult { OS=Environment.OSVersion.Version.ToString() };
            if(Environment.OSVersion.Version.Build<19041) { result.Error="需要 Windows 10 2004 或更新版本。"; return result; }
            IntPtr before=Native.GetForegroundWindow();
            Rectangle work=Screen.PrimaryScreen.WorkingArea;
            Rectangle bounds=new Rectangle(work.X+24,work.Y+24,260,140);
            PrivacySurface target=null,mask=null;
            try {
                target=new PrivacySurface(bounds,Color.Lime,null,false); target.Present();
                mask=new PrivacySurface(bounds,Color.Magenta,null,false); mask.Present();
                await Task.Delay(250); result.Normal=Sample(bounds);
                mask.SetExcluded(); result.AffinityApplied=true;
                await Task.Delay(250); result.Excluded=Sample(bounds);
                target.BackColor=Color.Cyan; target.Invalidate(); target.Update();
                await Task.Delay(250); result.LiveUpdate=Sample(bounds);
            } catch(Exception e) { result.Error=e.Message; }
            finally {
                IntPtr foreground=Native.GetForegroundWindow();
                result.ProbeTookFocus=(mask!=null && mask.IsHandleCreated && foreground==mask.Handle) || (target!=null && target.IsHandleCreated && foreground==target.Handle);
                result.ForegroundUnchanged=before==foreground;
                if(mask!=null) mask.Dispose(); if(target!=null) target.Dispose();
            }
            return result;
        }
        private static string Sample(Rectangle bounds) {
            using(Bitmap image=new Bitmap(bounds.Width,bounds.Height))
            using(Graphics g=Graphics.FromImage(image)) {
                IntPtr target=g.GetHdc(),source=Native.GetDC(IntPtr.Zero);
                try {
                    if(!Native.BitBlt(target,0,0,bounds.Width,bounds.Height,source,bounds.X,bounds.Y,0x00CC0020|0x40000000))
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                } finally { g.ReleaseHdc(target); Native.ReleaseDC(IntPtr.Zero,source); }
                int green=0,cyan=0,magenta=0,total=0;
                for(int y=10;y<image.Height-10;y+=5) for(int x=10;x<image.Width-10;x+=5) {
                    Color c=image.GetPixel(x,y); total++;
                    if(c.G>190 && c.R<100 && c.B<100) green++;
                    if(c.G>190 && c.B>190 && c.R<100) cyan++;
                    if(c.R>190 && c.B>190 && c.G<100) magenta++;
                }
                if(green>total*.9) return "green";
                if(cyan>total*.9) return "cyan";
                if(magenta>total*.9) return "magenta";
                return "unexpected";
            }
        }
    }
}
