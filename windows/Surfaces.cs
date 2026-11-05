using System;
using System.Drawing;
using System.Windows.Forms;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace StillHere.Windows {
    internal sealed class PrivacySurface : Form {
        private readonly bool excluded;
        internal Image Wallpaper;
        internal PrivacySurface(Rectangle bounds,Color color,Image image,bool exclude) {
            excluded=exclude; Wallpaper=image; FormBorderStyle=FormBorderStyle.None;
            StartPosition=FormStartPosition.Manual; Bounds=bounds; BackColor=color;
            TopMost=true; ShowInTaskbar=false; AutoScaleMode=AutoScaleMode.None;
            AccessibleRole=AccessibleRole.None; Text="StillHere Privacy Wallpaper";
            SetStyle(ControlStyles.AllPaintingInWmPaint|ControlStyles.UserPaint|ControlStyles.OptimizedDoubleBuffer,true);
        }
        protected override bool ShowWithoutActivation { get { return true; } }
        protected override CreateParams CreateParams {
            get { CreateParams p=base.CreateParams; p.ExStyle|=Native.NoActivate|Native.Transparent|Native.Layered|Native.ToolWindow; return p; }
        }
        protected override void OnHandleCreated(EventArgs e) {
            base.OnHandleCreated(e);
            if(!Native.SetLayeredWindowAttributes(Handle,0,255,2)) throw new Win32Exception(Marshal.GetLastWin32Error());
            if(excluded) SetExcluded();
        }
        internal void SetExcluded() {
            uint actual;
            if(!Native.SetWindowDisplayAffinity(Handle,Native.ExcludeFromCapture) ||
               !Native.GetWindowDisplayAffinity(Handle,out actual) || actual!=Native.ExcludeFromCapture)
                throw new Win32Exception(Marshal.GetLastWin32Error(),"无法启用截图排除，未开启防窥。");
        }
        internal void Present() {
            Show(); Native.SetWindowPos(Handle,new IntPtr(-1),Bounds.X,Bounds.Y,Bounds.Width,Bounds.Height,0x10|0x40);
        }
        protected override void WndProc(ref Message m) {
            if(m.Msg==0x21) { m.Result=new IntPtr(3); return; }
            if(m.Msg==0x84) { m.Result=new IntPtr(-1); return; }
            if(m.Msg==0x3D) { m.Result=IntPtr.Zero; return; }
            base.WndProc(ref m);
        }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);
            if(Wallpaper==null) return;
            double scale=Math.Min((double)ClientSize.Width/Wallpaper.Width,(double)ClientSize.Height/Wallpaper.Height);
            int width=(int)(Wallpaper.Width*scale),height=(int)(Wallpaper.Height*scale);
            e.Graphics.DrawImage(Wallpaper,new Rectangle((ClientSize.Width-width)/2,(ClientSize.Height-height)/2,width,height));
            using(Font font=new Font(SystemFonts.MessageBoxFont.FontFamily,10f))
            using(Brush brush=new SolidBrush(Color.FromArgb(125,40,40,40))) {
                string hint="Ctrl + Alt + Shift + P  输入密码返回桌面";
                SizeF size=e.Graphics.MeasureString(hint,font);
                e.Graphics.DrawString(hint,font,brush,(ClientSize.Width-size.Width)/2,ClientSize.Height-size.Height-12);
            }
        }
    }
    internal static class CaptureProbe {
        internal static CaptureResult Run() {
            CaptureResult result=new CaptureResult { OS=Environment.OSVersion.Version.ToString() };
            if(Environment.OSVersion.Version.Build<19041) { result.Error="需要 Windows 10 2004 或更新版本。"; return result; }
            IntPtr before=Native.GetForegroundWindow();
            Rectangle work=Screen.PrimaryScreen.WorkingArea;
            Rectangle bounds=new Rectangle(work.X+24,work.Y+24,260,140);
            PrivacySurface target=null,mask=null;
            try {
                target=new PrivacySurface(bounds,Color.Lime,null,false); target.Present();
                mask=new PrivacySurface(bounds,Color.Magenta,null,false); mask.Present();
                Settle(); result.Normal=Sample(bounds);
                mask.SetExcluded(); result.AffinityApplied=true;
                Settle(); result.Excluded=Sample(bounds);
                target.BackColor=Color.Cyan; target.Invalidate(); target.Update();
                Settle(); result.LiveUpdate=Sample(bounds);
            } catch(Exception e) { result.Error=e.Message; }
            finally {
                IntPtr foreground=Native.GetForegroundWindow();
                result.ProbeTookFocus=(mask!=null && foreground==mask.Handle) || (target!=null && foreground==target.Handle);
                result.ForegroundUnchanged=before==foreground;
                if(mask!=null) mask.Dispose(); if(target!=null) target.Dispose();
            }
            return result;
        }
        private static void Settle() {
            for(int i=0;i<5;i++) { Application.DoEvents(); System.Threading.Thread.Sleep(50); }
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
