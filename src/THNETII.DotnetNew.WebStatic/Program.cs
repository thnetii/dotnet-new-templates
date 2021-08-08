using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace THNETII.DotnetNew.WebStatic
{
    public class Program
    {
        public static void Main(string[] args)
        {
            CreateHostBuilder(args).Build().Run();
        }

        public static IHostBuilder CreateHostBuilder(string[] args) =>
            Host.CreateDefaultBuilder(args)
                .ConfigureWebHostDefaults(webBuilder =>
                {
                    webBuilder.ConfigureServices(services =>
                    {
                        // This method gets called by the runtime. Use this method to add services to the container.
                        // For more information on how to configure your application, visit https://go.microsoft.com/fwlink/?LinkID=398940
                    });
                    webBuilder.Configure((context, app) =>
                    {
                        // This method gets called by the runtime. Use this method to configure the HTTP request pipeline.
                        var env = context.HostingEnvironment;
                        if (env.IsDevelopment())
                        {
                            app.UseDeveloperExceptionPage();
                        }
                        
                        app.UseRouting();
                        
                        app.UseEndpoints(endpoints =>
                        {
                            endpoints.MapGet("/", async context =>
                            {
                                await context.Response.WriteAsync("Hello World!");
                            });
                        });
                    });
                });
    }
}
