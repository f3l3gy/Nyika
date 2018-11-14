#addin paket:?package=Cake.Figlet&group=build/setup

var target = Argument("target", "Default");

Task("Default")
  .Does(() =>
{
  Information(Figlet("Nyika Build System"));
});

RunTarget(target);
