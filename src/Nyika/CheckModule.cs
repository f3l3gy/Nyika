namespace Nyika
{
    using Nancy;

    public class CheckModule : NancyModule
    {
        public CheckModule()
        {
            Get("/api/v1/ping", args => "Pong");
            Get("/api/v1/headers", args => Request.Headers);
        }
    }
}
