namespace Nyika.Hosting.Self
{
    using Mono.Unix;
    using Mono.Unix.Native;
    using Nancy.Hosting.Self;
    using System;

    class Program
    {
        static void Main(string[] args)
        {
            int port = args.Length > 0 && int.TryParse(args[0], out port) ? port : 6543;
            string url = string.Format("http://localhost:{0}", port);

            var hostConfigs = new HostConfiguration
            {
                UrlReservations = new UrlReservations() { CreateAutomatically = true }
            };

            using (var host = new NancyHost(hostConfigs, new Uri(url)))
            {
                host.Start();
                Console.WriteLine(string.Format("Running on {0}", url));
                if (IsRunningOnMono() && IsRunningOnNix())
                {
                    Console.WriteLine("Running on *nix | Momo .Net");
                    var terminationSignals = GetUnixTerminationSignals();
                    UnixSignal.WaitAny(terminationSignals);
                }
                else
                {
                    Console.WriteLine("Running on Windows");
                    Console.ReadLine();
                }
            }
        }

        /// <summary>
        /// Detecting runtime is Mono
        /// </summary>
        private static bool IsRunningOnMono() => Type.GetType("Mono.Runtime") != null;

        /// <summary>
        /// Detecting OS platform is Linux/Unix 
        /// </summary>
        private static bool IsRunningOnNix()
        {
            int p = (int)Environment.OSVersion.Platform;
            return ((p == 4) || (p == 6) || (p == 128));
        }

        private static UnixSignal[] GetUnixTerminationSignals()
        {
            return new[]
            {
                new UnixSignal(Signum.SIGINT),
                new UnixSignal(Signum.SIGTERM),
                new UnixSignal(Signum.SIGQUIT),
                new UnixSignal(Signum.SIGHUP)
            };
        }

    }
}
