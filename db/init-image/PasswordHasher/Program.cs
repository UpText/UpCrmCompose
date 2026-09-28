using UpTextApi.Services;

var password = Console.In.ReadToEnd();
if (string.IsNullOrWhiteSpace(password))
{
    Console.Error.WriteLine("Password must not be empty or whitespace.");
    return 1;
}
Console.Write(UpHasher.HashPassword(password));
return 0;
