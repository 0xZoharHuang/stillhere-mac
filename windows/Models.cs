using System;
using System.IO;
using System.Text;
using System.Security.Cryptography;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;

namespace StillHere.Windows {
    [DataContract] internal sealed class Credential {
        [DataMember] public int Version=1;
        [DataMember] public int Iterations=310000;
        [DataMember] public byte[] Salt;
        [DataMember] public byte[] Verifier;
        internal static Credential Create(string password) {
            if(password==null || password.Length<6 || password.Length>256) throw new ArgumentException("密码需要 6 至 256 个字符。");
            Credential value=new Credential(); value.Salt=new byte[32];
            using(RandomNumberGenerator rng=RandomNumberGenerator.Create()) rng.GetBytes(value.Salt);
            value.Verifier=Derive(password,value.Salt,value.Iterations);
            return value;
        }
        internal static byte[] Derive(string password,byte[] salt,int iterations) {
            using(Rfc2898DeriveBytes kdf=new Rfc2898DeriveBytes(password,salt,iterations,HashAlgorithmName.SHA256)) return kdf.GetBytes(32);
        }
        internal void Validate() {
            if(Version!=1 || Iterations<100000 || Iterations>2000000 || Salt==null || Salt.Length!=32 || Verifier==null || Verifier.Length!=32)
                throw new InvalidDataException("退出密码配置损坏；没有开启防窥。");
        }
        internal bool Matches(string password) {
            Validate();
            if(String.IsNullOrEmpty(password) || password.Length>256) return false;
            byte[] candidate=Derive(password,Salt,Iterations); int difference=0;
            for(int i=0;i<32;i++) difference|=candidate[i]^Verifier[i];
            return difference==0;
        }
    }
    [DataContract] internal sealed class Preferences {
        [DataMember] public string Wallpaper;
        [DataMember] public bool KeepAwake=true;
    }
    [DataContract] internal sealed class CaptureResult {
        [DataMember] public string OS;
        [DataMember] public string Normal;
        [DataMember] public string Excluded;
        [DataMember] public string LiveUpdate;
        [DataMember] public bool AffinityApplied;
        [DataMember] public bool ForegroundUnchanged;
        [DataMember] public bool ProbeTookFocus;
        [DataMember] public string Error;
        internal bool Passed { get { return String.IsNullOrEmpty(Error) && Normal=="magenta" && Excluded=="green" && LiveUpdate=="cyan" && AffinityApplied && !ProbeTookFocus; } }
    }
    internal sealed class Store {
        internal readonly string Root;
        internal readonly string Scope;
        internal Store(string root) {
            Root=Path.GetFullPath(root); Directory.CreateDirectory(Root);
            using(SHA256 hash=SHA256.Create()) Scope=BitConverter.ToString(hash.ComputeHash(Encoding.UTF8.GetBytes(Root.ToLowerInvariant()))).Replace("-","").Substring(0,24);
        }
        internal string FilePath(string name) { return Path.Combine(Root,name); }
        internal T Read<T>(string name) where T:class {
            string path=FilePath(name);
            if(!File.Exists(path)) return null;
            using(FileStream stream=File.OpenRead(path)) return (T)new DataContractJsonSerializer(typeof(T)).ReadObject(stream);
        }
        internal Credential LoadCredential() {
            try { Credential value=Read<Credential>("credential.json"); if(value!=null) value.Validate(); return value; }
            catch(Exception e) { throw new InvalidDataException("无法读取退出密码配置。",e); }
        }
        internal void Save<T>(string name,T value) {
            string path=FilePath(name), temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
            try {
                using(FileStream stream=new FileStream(temp,FileMode.CreateNew,FileAccess.Write,FileShare.None))
                    new DataContractJsonSerializer(typeof(T)).WriteObject(stream,value);
                FileSecurity security=new FileSecurity(); security.SetAccessRuleProtection(true,false);
                security.AddAccessRule(new FileSystemAccessRule(WindowsIdentity.GetCurrent().User,FileSystemRights.FullControl,AccessControlType.Allow));
                security.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null),FileSystemRights.FullControl,AccessControlType.Allow));
                File.SetAccessControl(temp,security);
                if(File.Exists(path)) File.Replace(temp,path,null); else File.Move(temp,path);
                File.SetAccessControl(path,security);
            } finally { if(File.Exists(temp)) File.Delete(temp); }
        }
        internal bool Qualified() {
            try { CaptureResult result=Read<CaptureResult>("compatibility.json"); return result!=null && result.OS==Environment.OSVersion.Version.ToString() && result.Passed; }
            catch { return false; }
        }
        internal static string DefaultRoot { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"StillHere"); } }
    }
}
