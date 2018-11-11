#addin paket:?package=Cake.Figlet&group=build/setup

var target = Argument("target", "Default");

Task("Default")
  .Does(() =>
{
  Information(Figlet("Nyka Build System"));
});

RunTarget(target);
