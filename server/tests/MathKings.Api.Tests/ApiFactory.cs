using System.Net.Http.Headers;
using System.Net.Http.Json;
using MathKings.Api.Auth;
using MathKings.Api.Data;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Time.Testing;

namespace MathKings.Api.Tests;

/// <summary>
/// Gerçek PostgreSQL test veritabanına (mathkings_test) bağlı API.
/// Bağlantı: MATHKINGS_TEST_DB ortam değişkeni veya user-secrets "ConnectionStrings:Test".
/// </summary>
public class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    public const string Password = "GucluSifre1";

    public FakeTimeProvider Time { get; } = new(new DateTimeOffset(2026, 11, 3, 9, 0, 0, TimeSpan.Zero));
    protected virtual int AuthPerMinute => 10_000;

    public LogEmailSender Mail => Services.GetRequiredService<LogEmailSender>();

    private static string ConnectionString =>
        Environment.GetEnvironmentVariable("MATHKINGS_TEST_DB")
        ?? new ConfigurationBuilder().AddUserSecrets<ApiFactory>().Build().GetConnectionString("Test")
        ?? throw new InvalidOperationException("Test veritabanı bağlantısı tanımlı değil.");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Default", ConnectionString);
        builder.UseSetting("RateLimit:AuthPerMinute", AuthPerMinute.ToString());
        builder.ConfigureServices(s => s.AddSingleton<TimeProvider>(Time));
    }

    public async Task InitializeAsync()
    {
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await db.Database.MigrateAsync();
        await db.Database.ExecuteSqlRawAsync("TRUNCATE \"AspNetUsers\" CASCADE");
    }

    Task IAsyncLifetime.DisposeAsync() => base.DisposeAsync().AsTask();

    // --- Ortak test yardımcıları ---------------------------------------------

    public static string NewEmail() => $"veli-{Guid.NewGuid():N}@example.com";

    public string LastCode(string email, string kind) =>
        Mail.SentTo(email).Last(m => m.Kind == kind).Code!;

    public Task<HttpResponseMessage> Register(HttpClient c, string email, string password = Password,
        bool isAdult = true, string consent = "2026-11-taslak") =>
        c.PostAsJsonAsync("/api/v1/auth/register", new { email, password, isAdult, consentVersion = consent });

    public Task<HttpResponseMessage> Login(HttpClient c, string email, string password = Password) =>
        c.PostAsJsonAsync("/api/v1/auth/login", new { email, password });

    /// <summary>Kayıt + e-posta doğrulama + giriş; belirteçleri döndürür.</summary>
    public async Task<Tokens> CreateConfirmedAccount(HttpClient c, string? email = null)
    {
        email ??= NewEmail();
        (await Register(c, email)).EnsureSuccessStatusCode();
        (await c.PostAsJsonAsync("/api/v1/auth/confirm-email",
            new { email, code = LastCode(email, "confirm") })).EnsureSuccessStatusCode();
        var login = await Login(c, email);
        login.EnsureSuccessStatusCode();
        return (await login.Content.ReadFromJsonAsync<Tokens>())! with { Email = email };
    }

    public HttpClient AuthedClient(Tokens tokens)
    {
        var c = CreateClient();
        c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokens.AccessToken);
        return c;
    }
}

public sealed record Tokens(string AccessToken, string RefreshToken, long ExpiresIn, string Email = "");

/// <summary>İstek sınırı testi için düşük limitli ayrı uygulama örneği.</summary>
public sealed class LowRateLimitFactory : ApiFactory
{
    protected override int AuthPerMinute => 3;
}

[CollectionDefinition(Name)]
public sealed class ApiCollection : ICollectionFixture<ApiFactory>, ICollectionFixture<LowRateLimitFactory>
{
    public const string Name = "api";
}
