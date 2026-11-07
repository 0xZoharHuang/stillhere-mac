using System;
using System.Drawing;
using System.Windows.Forms;

namespace StillHere.Windows {
    internal sealed class SettingsDialog : Form {
        internal SettingsDialog(Image image,Preferences preferences,Action chooseImage,Action<bool> keepAwake) {
            Text="在场 · StillHere"; ClientSize=new Size(520,390);
            FormBorderStyle=FormBorderStyle.FixedDialog; MaximizeBox=false; StartPosition=FormStartPosition.CenterScreen;
            Font=SystemFonts.MessageBoxFont; AutoScaleMode=AutoScaleMode.Font;
            Label heading=new Label { Left=22,Top=18,Width=475,Height=32,Text="人可以离席，工作继续在场。",Font=new Font(Font.FontFamily,17,FontStyle.Bold) };
            PictureBox preview=new PictureBox { Left=22,Top=60,Width=475,Height=190,Image=image,SizeMode=PictureBoxSizeMode.Zoom,BackColor=Color.FromArgb(250,240,220) };
            Button choose=new Button { Left=22,Top=261,Width=120,Text="选择壁纸…" };
            choose.Click+=delegate { chooseImage(); DialogResult=DialogResult.Retry; Close(); };
            CheckBox awake=new CheckBox { Left=22,Top=310,Width=475,Text="防窥期间保持电脑和显示器唤醒",Checked=preferences.KeepAwake };
            awake.CheckedChanged+=delegate { keepAwake(awake.Checked); };
            Label shortcut=new Label { Left=22,Top=350,Width=475,Text="Ctrl + Alt + Shift + P  开启 / 退出防窥" };
            Controls.AddRange(new Control[] { heading,preview,choose,awake,shortcut });
        }
    }
    internal sealed class AutomationFixture : Form {
        internal TextBox InputField;
        internal Button RecordButton;
        internal Label RecordedOutput;
        internal AutomationFixture() {
            Text="StillHere Windows Automation Laboratory"; ClientSize=new Size(530,260);
            StartPosition=FormStartPosition.CenterScreen; Font=SystemFonts.MessageBoxFont;
            TextBox input=new TextBox { Left=25,Top=80,Width=475,AccessibleName="输入验证短语" };
            Label output=new Label { Left=25,Top=165,Width=475,Height=30,Text="尚未记录",AccessibleName="验证结果" };
            Label clock=new Label { Left=25,Top=208,Width=475 };
            Button button=new Button { Left=25,Top=117,Width=110,Text="记录输入",AccessibleName="记录输入" };
            InputField=input; RecordButton=button; RecordedOutput=output;
            int count=0; button.Click+=delegate { count++; output.Text="已记录 #"+count+"："+input.Text; };
            Label title=new Label { Left=25,Top=24,Width=475,Text="防窥期间读屏、点击与输入验证",Height=32,Font=new Font(Font.FontFamily,16,FontStyle.Bold) };
            Timer timer=new Timer { Interval=1000 }; timer.Tick+=delegate { clock.Text="实时更新："+DateTime.Now.ToString("HH:mm:ss"); }; timer.Start();
            FormClosed+=delegate { timer.Dispose(); };
            Controls.AddRange(new Control[] { title,input,button,output,clock });
        }
    }
}
