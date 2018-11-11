namespace Nyika.Hosting.Netcore
{
    using System.IO;
    using Microsoft.AspNetCore.Hosting;

    /// <summary>
    /// Netcore hosting runner
    /// </summary>
    public class Program
    {
        /// <summary>
        /// Mains the specified arguments.
        /// </summary>
        /// <param name="args">The arguments.</param>
        public static void Main(string[] args)
        {
            var host = new WebHostBuilder()
                   .UseKestrel().UseContentRoot(Directory.GetCurrentDirectory())
                   .UseIISIntegration().UseStartup<Startup>()
                   .Build();

            host.Run();
        }
    }
}
