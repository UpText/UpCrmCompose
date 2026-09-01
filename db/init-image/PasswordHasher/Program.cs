using System.Security.Cryptography;
using System.Text;

var password = Console.In.ReadToEnd();

using var sha = SHA256.Create();
var hash = sha.ComputeHash(Encoding.UTF8.GetBytes(password));

Console.Write(Convert.ToBase64String(hash));
