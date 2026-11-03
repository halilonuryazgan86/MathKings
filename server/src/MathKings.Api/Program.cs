using System.Net;
using System.Threading.RateLimiting;
using MathKings.Api.Auth;
using MathKings.Api.Data;
using MathKings.Api.Profiles;
using Microsoft.AspNetCore.DataProtection;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);
var config = builder.Configuration;
var env = builder.Environment;
var isLocal = env.IsDevelopment() || env.IsEnvironment("Testing");

// Ters proxy (nginx vb.) arkasında gerçek istemci IP'si: istek sınırı herkesi tek IP saymasın.
// Yalnızca açıkça güvenilen proxy adreslerinden gelen başlıklar kabul edilir.
var knownProxies = config.GetSection("ReverseProxy:KnownProxies").Get<string[]>() ?? [];
if (knownProxies.Length > 0)
{
    builder.Services.Configure<ForwardedHeadersOptions>(o =>
    {
        o.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        foreach (var ip in knownProxies)
            o.KnownProxies.Add(IPAddress.Parse(ip));
    });
}

// Oturum belirteçlerini şifreleyen anahtarlar kalıcı olmalı; yoksa her yeniden başlatmada oturumlar düşer.
var keysPath = config["DataProtection:KeysPath"];
if (!string.IsNullOrEmpty(keysPath))
    builder.Services.AddDataProtection().PersistKeysToFileSystem(new DirectoryInfo(keysPath)).SetApplicationName("MathKings");
else if (!isLocal)
    throw new InvalidOperationException("Üretimde DataProtection:KeysPath zorunludur.");

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

// E-posta: "Smtp" (geliştirmede Laragon Mailpit, yayında gerçek sağlayıcı) veya "Log" (yalnızca test/geliştirme).
builder.Services.AddSingleton<LogEmailSender>();
if (config["Email:Mode"] == "Smtp")
{
    builder.Services.Configure<SmtpOptions>(config.GetSection("Email:Smtp"));
    builder.Services.AddSingleton<IAccountEmailSender, SmtpEmailSender>();
}
else
{
    if (!isLocal)
        throw new InvalidOperationException("Üretimde Email:Mode=Smtp ve SMTP ayarları zorunludur.");
    builder.Services.AddSingleton<IAccountEmailSender>(sp => sp.GetRequiredService<LogEmailSender>());
}

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

if (knownProxies.Length > 0)
    app.UseForwardedHeaders();

// Temel güvenlik başlıkları; yanıtlar kişisel veri içerebileceği için önbelleğe alınmaz.
app.Use(async (ctx, next) =>
{
    var h = ctx.Response.Headers;
    h.XContentTypeOptions = "nosniff";
    h.XFrameOptions = "DENY";
    h["Referrer-Policy"] = "no-referrer";
    h.CacheControl = "no-store";
    await next();
});

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
