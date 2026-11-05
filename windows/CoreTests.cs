using System;
using System.IO;
using System.Text;
using System.Linq;
using System.Collections.Generic;
using System.Runtime.Serialization;
using System.Security.AccessControl;
using System.Security.Principal;

namespace StillHere.Windows {
    [DataContract] internal sealed class CoreReport {
        [DataMember] public int Passed;
        [DataMember] public List<string> Failures=new List<string>();
    }
    internal static class CoreTests {
        private static void Check(CoreReport report,string name,Action test) {
            try { test(); report.Passed++; } catch(Exception e) { report.Failures.Add(name+": "+e.Message); }
        }
        private static void Expect(bool value) { if(!value) throw new Exception("Expectation failed"); }
        internal static int Run(string output) {
            CoreReport report=new CoreReport();
            Check(report,"PBKDF2 reference",delegate {
                byte[] hash=Credential.Derive("password",Encoding.UTF8.GetBytes("reference-salt-16"),4096);
                Expect(BitConverter.ToString(hash).Replace("-","").ToLowerInvariant()=="2197898fa33a688f1db870848ac37b1e71a0a77f8ed1d6d23face12346df113e");
            });
            Check(report,"password match and rejection",delegate {
                Credential value=Credential.Create("controlled-test-password");
                Expect(value.Matches("controlled-test-password") && !value.Matches("wrong-password") && !value.Matches(""));
            });
            Check(report,"independent random salts",delegate {
                Credential a=Credential.Create("controlled-test-password"),b=Credential.Create("controlled-test-password");
                Expect(!a.Salt.SequenceEqual(b.Salt) && !a.Verifier.SequenceEqual(b.Verifier));
            });
            Check(report,"unicode password",delegate { Expect(Credential.Create("在场密码测试六六").Matches("在场密码测试六六")); });
            Check(report,"credential corruption fails closed",delegate {
                bool threw=false; try { new Credential().Validate(); } catch(InvalidDataException) { threw=true; } Expect(threw);
            });
            string folder=Path.Combine(Path.GetTempPath(),"StillHere-Core-"+Guid.NewGuid().ToString("N"));
            try {
                Store store=new Store(folder); Credential value=Credential.Create("controlled-test-password"); store.Save("credential.json",value);
                Check(report,"private credential roundtrip",delegate {
                    Expect(store.LoadCredential().Matches("controlled-test-password"));
                    Expect(!File.ReadAllText(store.FilePath("credential.json")).Contains("controlled-test-password"));
                    AuthorizationRuleCollection rules=File.GetAccessControl(store.FilePath("credential.json")).GetAccessRules(true,true,typeof(SecurityIdentifier));
                    foreach(FileSystemAccessRule rule in rules) Expect(rule.IdentityReference.Equals(WindowsIdentity.GetCurrent().User) || rule.IdentityReference.Equals(new SecurityIdentifier(WellKnownSidType.LocalSystemSid,null)));
                });
                Check(report,"no capture qualification without visible control and live update",delegate {
                    CaptureResult result=new CaptureResult { OS=Environment.OSVersion.Version.ToString(),Normal="green",Excluded="green",LiveUpdate="cyan",AffinityApplied=true,ForegroundUnchanged=true };
                    Expect(!result.Passed); result.Normal="magenta"; Expect(result.Passed);
                    result.LiveUpdate="green"; Expect(!result.Passed);
                });
            } finally { if(Directory.Exists(folder)) Directory.Delete(folder,true); }
            Program.Output(report,output); return report.Failures.Count==0?0:1;
        }
    }
}
