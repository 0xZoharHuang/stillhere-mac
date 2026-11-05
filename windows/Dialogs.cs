using System;
using System.Drawing;
using System.Windows.Forms;

namespace StillHere.Windows {
    internal sealed class PasswordDialog : Form {
        internal PasswordDialog(bool quit,Func<string,string> verify) {
            Text=quit?"退出在场":"回到桌面"; ClientSize=new Size(390,205);
            FormBorderStyle=FormBorderStyle.FixedDialog; MaximizeBox=false; MinimizeBox=false;
            StartPosition=FormStartPosition.CenterScreen; TopMost=true; ShowInTaskbar=false;
            Font=SystemFonts.MessageBoxFont; AutoScaleMode=AutoScaleMode.Font;
            Label title=new Label { Text=quit?"输入密码，退出在场":"输入密码，解除防窥",Left=22,Top=20,Width=345,Height=28,Font=new Font(Font.FontFamily,14,FontStyle.Bold) };
            Label detail=new Label { Text="验证完成前，隐私壁纸继续保护屏幕。",Left=22,Top=56,Width=345 };
            TextBox input=new TextBox { Left=22,Top=85,Width=345,UseSystemPasswordChar=true,AccessibleName="退出密码" };
            Label error=new Label { Left=22,Top=118,Width=345,Height=28,ForeColor=Color.Firebrick };
            Button cancel=new Button { Text="取消",Left=185,Top=155,Width=85,DialogResult=DialogResult.Cancel };
            Button accept=new Button { Text=quit?"验证并退出":"解除防窥",Left=277,Top=155,Width=90 };
            accept.Click+=delegate {
                string message=verify(input.Text); input.Clear();
                if(message!=null) { error.Text=message; input.Focus(); return; }
                DialogResult=DialogResult.OK; Close();
            };
            Controls.AddRange(new Control[] { title,detail,input,error,cancel,accept });
            AcceptButton=accept; CancelButton=cancel;
            Shown+=delegate { input.Focus(); };
        }
    }
    internal sealed class SettingsDialog : Form {
        internal SettingsDialog(Image image,bool configured,Preferences preferences,Func<string,string,string,string> savePassword,Action chooseImage,Action<bool> keepAwake) {
            Text="在场 · StillHere"; ClientSize=new Size(520,540);
            FormBorderStyle=FormBorderStyle.FixedDialog; MaximizeBox=false; StartPosition=FormStartPosition.CenterScreen;
            Font=SystemFonts.MessageBoxFont; AutoScaleMode=AutoScaleMode.Font;
            Label heading=new Label { Left=22,Top=18,Width=475,Height=32,Text="人可以离席，工作继续在场。",Font=new Font(Font.FontFamily,17,FontStyle.Bold) };
            PictureBox preview=new PictureBox { Left=22,Top=60,Width=475,Height=190,Image=image,SizeMode=PictureBoxSizeMode.Zoom,BackColor=Color.FromArgb(250,240,220) };
            Button choose=new Button { Left=22,Top=261,Width=120,Text="选择壁纸…" };
            choose.Click+=delegate { chooseImage(); DialogResult=DialogResult.Retry; Close(); };
            TextBox old=new TextBox { Left=22,Top=300,Width=475,UseSystemPasswordChar=true,AccessibleName="当前密码" };
            TextBox next=new TextBox { Left=22,Top=337,Width=475,UseSystemPasswordChar=true,AccessibleName="新密码" };
            TextBox confirm=new TextBox { Left=22,Top=374,Width=475,UseSystemPasswordChar=true,AccessibleName="确认新密码" };
            Label oldLabel=new Label { Left=22,Top=282,Width=475,Text=configured?"当前退出密码":"首次设置：当前密码留空" };
            Label nextLabel=new Label { Left=22,Top=320,Width=475,Text="新退出密码（至少 6 位）" };
            Label confirmLabel=new Label { Left=22,Top=357,Width=475,Text="再次输入新密码" };
            Button save=new Button { Left=22,Top=410,Width=130,Text="保存退出密码" };
            Label feedback=new Label { Left=165,Top=414,Width=330,Height=35 };
            save.Click+=delegate {
                string error=savePassword(old.Text,next.Text,confirm.Text); old.Clear(); next.Clear(); confirm.Clear();
                feedback.ForeColor=error==null?Color.DarkGreen:Color.Firebrick; feedback.Text=error??"退出密码已保存。";
            };
            CheckBox awake=new CheckBox { Left=22,Top=457,Width=475,Text="防窥期间保持电脑和显示器唤醒",Checked=preferences.KeepAwake };
            awake.CheckedChanged+=delegate { keepAwake(awake.Checked); };
            Label shortcut=new Label { Left=22,Top=495,Width=475,Text="Ctrl + Alt + Shift + P  开启 / 请求密码退出" };
            Controls.AddRange(new Control[] { heading,preview,choose,oldLabel,old,nextLabel,next,confirmLabel,confirm,save,feedback,awake,shortcut });
        }
    }
    internal sealed class AutomationFixture : Form {
        internal AutomationFixture() {
            Text="StillHere Windows Automation Laboratory"; ClientSize=new Size(530,260);
            StartPosition=FormStartPosition.CenterScreen; Font=SystemFonts.MessageBoxFont;
            TextBox input=new TextBox { Left=25,Top=80,Width=475,AccessibleName="输入验证短语" };
            Label output=new Label { Left=25,Top=165,Width=475,Height=30,Text="尚未记录",AccessibleName="验证结果" };
            Label clock=new Label { Left=25,Top=208,Width=475 };
            Button button=new Button { Left=25,Top=117,Width=110,Text="记录输入",AccessibleName="记录输入" };
            int count=0; button.Click+=delegate { count++; output.Text="已记录 #"+count+"："+input.Text; };
            Label title=new Label { Left=25,Top=24,Width=475,Text="防窥期间读屏、点击与输入验证",Height=32,Font=new Font(Font.FontFamily,16,FontStyle.Bold) };
            Timer timer=new Timer { Interval=1000 }; timer.Tick+=delegate { clock.Text="实时更新："+DateTime.Now.ToString("HH:mm:ss"); }; timer.Start();
            FormClosed+=delegate { timer.Dispose(); };
            Controls.AddRange(new Control[] { title,input,button,output,clock });
        }
    }
}
