using System.Diagnostics;
using UpTextApi.Services;

if (args.Length != 1)
    throw new ArgumentException("Pass the built db-init password hasher DLL path.");

(string Hash, int ExitCode) Generate(string password)
{
    var start = new ProcessStartInfo("dotnet")
    {
        RedirectStandardInput = true,
        RedirectStandardOutput = true,
        RedirectStandardError = true,
        UseShellExecute = false
    };
    start.ArgumentList.Add(Path.GetFullPath(args[0]));
    using var process = Process.Start(start)!;
    process.StandardInput.Write(password);
    process.StandardInput.Close();
    var hash = process.StandardOutput.ReadToEnd();
    var error = process.StandardError.ReadToEnd();
    process.WaitForExit();
    return (hash, process.ExitCode);
}

foreach (var password in new[] { "default123+", "demo123+", "Admin-test-42!", " blåbær🔑'$=\n " })
{
    var first = Generate(password);
    var second = Generate(password);
    if (first.ExitCode != 0 || second.ExitCode != 0 ||
        !UpHasher.VerifyPassword(password, first.Hash) ||
        !UpHasher.VerifyPassword(password, second.Hash) ||
        UpHasher.VerifyPassword(password + "wrong", first.Hash) ||
        first.Hash == second.Hash)
        throw new Exception("db-init hashes must verify with UpTextApi, reject wrong passwords, and use random salts.");
}
foreach (var password in new[] { "", " \r\n\t" })
{
    var result = Generate(password);
    if (result.ExitCode == 0 || result.Hash.Length != 0)
        throw new Exception("Empty passwords must fail without producing a hash.");
}
Console.WriteLine("db-init password compatibility checks passed against UpTextApi's hasher.");
