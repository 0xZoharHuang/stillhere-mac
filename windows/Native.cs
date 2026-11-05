using System;
using System.Runtime.InteropServices;

namespace StillHere.Windows {
    internal static class Native {
        internal const uint ExcludeFromCapture = 0x11;
        internal const int NoActivate = 0x08000000, Transparent = 0x20, Layered = 0x80000, ToolWindow = 0x80;
        internal const int HotKey = 0x0312, CopyData = 0x004A;
        [DllImport("user32.dll", SetLastError=true)] internal static extern bool SetWindowDisplayAffinity(IntPtr window, uint affinity);
        [DllImport("user32.dll", SetLastError=true)] internal static extern bool GetWindowDisplayAffinity(IntPtr window, out uint affinity);
        [DllImport("user32.dll", SetLastError=true)] internal static extern bool SetLayeredWindowAttributes(IntPtr window, uint key, byte alpha, uint flags);
        [DllImport("user32.dll")] internal static extern bool SetWindowPos(IntPtr window, IntPtr after, int x, int y, int width, int height, uint flags);
        [DllImport("user32.dll")] internal static extern IntPtr GetForegroundWindow();
        [DllImport("user32.dll", SetLastError=true)] internal static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);
        [DllImport("user32.dll")] internal static extern bool UnregisterHotKey(IntPtr window, int id);
        [DllImport("user32.dll", CharSet=CharSet.Unicode)] internal static extern IntPtr FindWindow(string cls, string title);
        [DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] internal static extern IntPtr SendMessageTimeout(IntPtr window, uint message, IntPtr wparam, ref CopyDataValue value, uint flags, uint timeout, out IntPtr result);
        [DllImport("user32.dll")] internal static extern IntPtr GetDC(IntPtr window);
        [DllImport("user32.dll")] internal static extern int ReleaseDC(IntPtr window, IntPtr dc);
        [DllImport("gdi32.dll", SetLastError=true)] internal static extern bool BitBlt(IntPtr dest, int x, int y, int width, int height, IntPtr source, int sourceX, int sourceY, uint flags);
        [DllImport("kernel32.dll")] internal static extern uint SetThreadExecutionState(uint flags);
        [DllImport("kernel32.dll")] internal static extern bool AttachConsole(uint pid);
        [DllImport("user32.dll")] internal static extern bool SetProcessDpiAwarenessContext(IntPtr context);
        [StructLayout(LayoutKind.Sequential)] internal struct CopyDataValue {
            internal IntPtr Tag;
            internal int Length;
            internal IntPtr Data;
        }
        internal static bool SendCommand(string title, string command) {
            IntPtr window=FindWindow(null,title);
            if(window==IntPtr.Zero) return false;
            IntPtr data=Marshal.StringToHGlobalUni(command);
            try {
                CopyDataValue message=new CopyDataValue { Tag=new IntPtr(1), Length=(command.Length+1)*2, Data=data };
                IntPtr result;
                return SendMessageTimeout(window,CopyData,IntPtr.Zero,ref message,2,2000,out result)!=IntPtr.Zero;
            } finally { Marshal.FreeHGlobal(data); }
        }
    }
}
