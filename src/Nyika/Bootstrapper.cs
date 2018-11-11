namespace Nyika
{
    using Nancy;
    using Nancy.Diagnostics;
    using Nancy.Configuration;

    public class Bootstrapper : DefaultNancyBootstrapper
    {
        public override void Configure(INancyEnvironment environment)
        {
            environment.Diagnostics(true, "password");
            base.Configure(environment);
        }
    }
}
