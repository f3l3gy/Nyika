namespace Nyika.Hosting.Netcore
{
    using Microsoft.AspNetCore.Builder;
    using Nancy.Owin;

    /// <summary>
    /// Netcore hosting Owin startup settigs
    /// </summary>
    public class Startup
    {
        /// <summary>
        /// Configures the specified application.
        /// </summary>
        /// <param name="app">The application.</param>
        public void Configure(IApplicationBuilder app)
        {
            app.UseOwin(x => x.UseNancy());
        }
    }
}
