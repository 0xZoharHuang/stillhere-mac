using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Threading;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Cryptography;
using System.Windows.Forms;

namespace StillHere.Windows {
    [DataContract] internal sealed class QAInfo {
        [DataMember] public string DataDirectory;
        [DataMember] public string Password;
    }
    internal static class Program {
        internal static string Value(string[] args,string key) {
            int index=Array.IndexOf(args,key); return index>=0 && index+1<args.Length?args[index+1]:null;
        }
        internal static void Output<T>(T value,string path) {
            using(MemoryStream stream=new MemoryStream()) {
                new DataContractJsonSerializer(typeof(T)).WriteObject(stream,value);
                byte[] data=stream.ToArray();
                if(path!=null) { string parent=Path.GetDirectoryName(Path.GetFullPath(path)); Directory.CreateDirectory(parent); File.WriteAllBytes(path,data); }
                Console.WriteLine(Encoding.UTF8.GetString(data));
            }
        }
        [STAThread] private static int Main(string[] args) {
            string output=Value(args,"--output");
            try {
                if(args.Length>0 && !args.Contains("--qa") && !args.Contains("--fixture")) Native.AttachConsole(0xFFFFFFFF);
                if(args.Contains("--core-self-test")) return CoreTests.Run(output);
                if(args.Contains("--version")) { Console.WriteLine("0.1.0"); return 0; }
                try { Native.SetProcessDpiAwarenessContext(new IntPtr(-4)); } catch(EntryPointNotFoundException) { }
                Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
                string root=Environment.GetEnvironmentVariable("STILLHERE_DATA_DIR")??Store.DefaultRoot;
                bool qa=args.Contains("--qa") || args.Contains("--qa-run-ui");
                string qaPassword=null;
                if(qa) {
                    root=Path.Combine(Path.GetTempPath(),"StillHere-QA-"+Guid.NewGuid().ToString("N"));
                    byte[] bytes=new byte[8]; using(RandomNumberGenerator rng=RandomNumberGenerator.Create()) rng.GetBytes(bytes);
                    string password=BitConverter.ToString(bytes).Replace("-","");
                    qaPassword=password;
                    Store test=new Store(root); test.Save("credential.json",Credential.Create(password));
                    new Store(Store.DefaultRoot).Save("qa-session.json",new QAInfo { DataDirectory=root,Password=password });
                }
                Store store=new Store(root);
                if(args.Contains("--diagnose")) {
                    CaptureResult result=CaptureProbe.Run(); store.Save("compatibility.json",result); Output(result,output); return result.Passed?0:2;
                }
                if(args.Contains("--init-password-stdin")) {
                    if(store.LoadCredential()!=null) throw new InvalidOperationException("退出密码已设置，请在应用设置中修改。");
                    store.Save("credential.json",Credential.Create(Console.In.ReadToEnd().TrimEnd('\r','\n'))); return 0;
                }
                if(args.Contains("--status")) {
                    RuntimeState state=store.Read<RuntimeState>("runtime.json")??new RuntimeState { Running=false };
                    try { using(System.Diagnostics.Process p=System.Diagnostics.Process.GetProcessById(state.PID)) { if(p.HasExited || p.ProcessName!="StillHere") { state.Running=false; state.Protected=false; } } }
                    catch { state.Running=false; state.Protected=false; }
                    Output(state,output); return 0;
                }
                string action=null;
                foreach(string key in new string[] { "shield","unlock","quit","settings","fixture" }) if(args.Contains("--"+key)) { action=key; break; }
                bool created;
                using(Mutex mutex=new Mutex(true,"Local\\StillHere."+store.Scope,out created)) {
                    if(!created) return Native.SendCommand("StillHere.Command."+store.Scope,action??"settings")?0:3;
                    if(action!=null && action!="fixture") { mutex.ReleaseMutex(); return 3; }
                    string qaOutput=args.Contains("--qa-run-ui")?(output??Path.Combine(Store.DefaultRoot,"qa-last-result.json")):null;
                    try { Application.Run(new TrayContext(store,qa || action=="fixture",qaPassword,qaOutput)); }
                    finally {
                        mutex.ReleaseMutex();
                        if(qa) {
                            try { File.Delete(Path.Combine(Store.DefaultRoot,"qa-session.json")); Directory.Delete(root,true); } catch { }
                        }
                    }
                }
                return 0;
            } catch(Exception e) {
                Console.Error.WriteLine(e.ToString());
                if(output!=null) File.WriteAllText(output,e.ToString());
                if(args.Length==0) MessageBox.Show(e.Message,"在场 · StillHere",MessageBoxButtons.OK,MessageBoxIcon.Error);
                return 1;
            }
        }
    }
}
