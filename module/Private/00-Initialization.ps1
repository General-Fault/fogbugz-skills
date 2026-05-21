Set-StrictMode -Version Latest

if (-not ('FogBugzCredentialStore' -as [type])) {
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

public static class FogBugzCredentialStore {
    private const uint CRED_TYPE_GENERIC     = 1;
    private const uint CRED_PERSIST_LOCAL_MACHINE = 2;

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct CREDENTIAL {
        public uint  Flags;
        public uint  Type;
        public string TargetName;
        public string Comment;
        public long  LastWritten;
        public uint  CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint  Persist;
        public uint  AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredWrite([In] ref CREDENTIAL cred, uint flags);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredRead(string target, uint type, uint flags, out IntPtr ptr);

    [DllImport("advapi32.dll", SetLastError = true)]
    private static extern bool CredFree(IntPtr ptr);

    [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    private static extern bool CredDelete(string target, uint type, uint flags);

    public static void Write(string target, string userName, string secret) {
        if (secret == null) secret = string.Empty;
        byte[] blob = Encoding.Unicode.GetBytes(secret);
        IntPtr blobPtr = Marshal.AllocHGlobal(blob.Length);
        try {
            Marshal.Copy(blob, 0, blobPtr, blob.Length);
            var cred = new CREDENTIAL {
                Type               = CRED_TYPE_GENERIC,
                TargetName         = target,
                Comment            = "FogBugzSkills",
                CredentialBlobSize = (uint)blob.Length,
                CredentialBlob     = blobPtr,
                Persist            = CRED_PERSIST_LOCAL_MACHINE,
                UserName           = userName
            };
            if (!CredWrite(ref cred, 0))
                throw new InvalidOperationException("CredWrite failed: " + Marshal.GetLastWin32Error());
        } finally {
            Marshal.FreeHGlobal(blobPtr);
        }
    }

    public static string[] Read(string target) {
        IntPtr ptr = IntPtr.Zero;
        try {
            if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr)) return null;
            var cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            string secret = null;
            if (cred.CredentialBlob != IntPtr.Zero && cred.CredentialBlobSize > 0) {
                byte[] blob = new byte[cred.CredentialBlobSize];
                Marshal.Copy(cred.CredentialBlob, blob, 0, blob.Length);
                secret = Encoding.Unicode.GetString(blob).TrimEnd('\0');
            }
            return new[] { cred.UserName ?? string.Empty, secret ?? string.Empty };
        } finally {
            if (ptr != IntPtr.Zero) CredFree(ptr);
        }
    }

    public static void Delete(string target) {
        CredDelete(target, CRED_TYPE_GENERIC, 0);
    }
}
'@ -Language CSharp
}

