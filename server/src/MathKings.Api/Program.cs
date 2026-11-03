using System.Threading.RateLimiting;
using MathKings.Api.Auth;
using MathKings.Api.Data;
using MathKings.Api.Profiles;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;
var env = builder.Environment;

builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 1_000_000);

builder.Services.AddDbContext<AppDbContext>(o => o.UseNpgsql(
    config.GetConnectionString("Default")
    ?? throw new InvalidOperationException("ConnectionStrings:Default tanımlı değil (dotnet user-secrets).")));

builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddProblemDetails();

builder.Services.AddAuthentication(IdentityConstants.BearerScheme)
    .AddBearerToken(IdentityConstants.BearerScheme, o =>
    {
        o.BearerTokenExpiration = TimeSpan.FromMinutes(15);
        o.RefreshTokenExpiration = TimeSpan.FromDays(30);
    });
builder.Services.AddAuthorization();

builder.Services.AddIdentityCore<AppUser>(o =>
    {
        o.User.RequireUniqueEmail = true;
        o.SignIn.RequireConfirmedEmail = true;
        o.Password.RequiredLength = 8;
        o.Password.RequireNonAlphanumeric = false;
        o.Lockout.MaxFailedAccessAttempts = 5;
        o.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
        // 6 haneli kodlar: veli e-postadaki kodu oyuna yazar.
        o.Tokens.EmailConfirmationTokenProvider = TokenOptions.DefaultEmailProvider;
        o.Tokens.PasswordResetTokenProvider = TokenOptions.DefaultEmailProvider;
    })
    .AddEntityFrameworkStores<AppDbContext>()
    .AddSignInManager()
    .AddDefaultTokenProviders();

if (!env.IsDevelopment() && !env.IsEnvironment("Testing"))
    throw new InvalidOperationException("Üretim için gerçek e-posta göndericisi yapılandırılmadı (LogEmailSender yalnızca geliştirme içindir).");
builder.Services.AddSingleton<LogEmailSender>();
builder.Services.AddSingleton<IAccountEmailSender>(sp => sp.GetRequiredService<LogEmailSender>());

builder.Services.AddRateLimiter(o =>
{
    o.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    o.AddPolicy(AuthEndpoints.RateLimitPolicy, ctx => RateLimitPartition.GetFixedWindowLimiter(
        ctx.Connection.RemoteIpAddress?.ToString() ?? "unknown",
        _ => new FixedWindowRateLimiterOptions
        {
            PermitLimit = config.GetValue("RateLimit:AuthPerMinute", 10),
            Window = TimeSpan.FromMinutes(1),
        }));
});

var app = builder.Build();

if (env.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    scope.ServiceProvider.GetRequiredService<AppDbContext>().Database.Migrate();
}
else
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseExceptionHandler();
app.UseStatusCodePages();
app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapGet("/health", () => TypedResults.Ok(new { status = "ok" }));

if (env.IsDevelopment())
{
    // Yalnızca geliştirme: gerçek e-posta yokken son doğrulama/sıfırlama kodunu okumak için.
    app.MapGet("/dev/last-code", (string email, string kind, LogEmailSender mail) =>
        mail.SentTo(email).LastOrDefault(m => m.Kind == kind) is { Code: { } code }
            ? Results.Ok(new { code })
            : Results.NotFound());
}
var api = app.MapGroup("/api/v1");
api.MapAuth();
api.MapProfiles();

app.Run();

public partial class Program;
