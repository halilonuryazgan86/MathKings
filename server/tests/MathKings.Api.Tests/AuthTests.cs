using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using MathKings.Api.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace MathKings.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class AuthTests(ApiFactory api, LowRateLimitFactory lowLimitApi)
{
    private readonly HttpClient _client = api.CreateClient();

    [Fact]
    public async Task Register_requires_adult_declaration_and_current_consent()
    {
        var notAdult = await api.Register(_client, ApiFactory.NewEmail(), isAdult: false);
        var oldConsent = await api.Register(_client, ApiFactory.NewEmail(), consent: "eski");

        Assert.Equal(HttpStatusCode.BadRequest, notAdult.StatusCode);
        Assert.Contains("isAdult", await notAdult.Content.ReadAsStringAsync());
        Assert.Equal(HttpStatusCode.BadRequest, oldConsent.StatusCode);
        Assert.Contains("consentVersion", await oldConsent.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Register_rejects_weak_password_with_turkish_message()
    {
        var res = await api.Register(_client, ApiFactory.NewEmail(), password: "kisa");
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
        Assert.Contains("en az 8 karakter", await res.Content.ReadAsStringAsync());
    }

    [Fact]
    public async Task Login_requires_confirmed_email_then_returns_tokens()
    {
        var email = ApiFactory.NewEmail();
        Assert.Equal(HttpStatusCode.Accepted, (await api.Register(_client, email)).StatusCode);

        var beforeConfirm = await api.Login(_client, email);
        Assert.Equal(HttpStatusCode.Forbidden, beforeConfirm.StatusCode);
        Assert.Equal("email_not_confirmed", await Code(beforeConfirm));

        var wrongCode = await _client.PostAsJsonAsync("/api/v1/auth/confirm-email", new { email, code = "000000" });
        Assert.Equal(HttpStatusCode.BadRequest, wrongCode.StatusCode);

        var code = api.LastCode(email, "confirm");
        Assert.Matches("^[0-9]{6}$", code);
        Assert.Equal(HttpStatusCode.OK,
            (await _client.PostAsJsonAsync("/api/v1/auth/confirm-email", new { email, code })).StatusCode);

        var login = await api.Login(_client, email);
        Assert.Equal(HttpStatusCode.OK, login.StatusCode);
        var tokens = await login.Content.ReadFromJsonAsync<Tokens>();
        Assert.False(string.IsNullOrEmpty(tokens!.AccessToken));
        Assert.False(string.IsNullOrEmpty(tokens.RefreshToken));
        Assert.Equal(15 * 60, tokens.ExpiresIn);
    }

    [Fact]
    public async Task Existing_email_and_unknown_email_get_identical_responses()
    {
        var tokens = await api.CreateConfirmedAccount(_client);

        var again = await api.Register(_client, tokens.Email);
        var forgotUnknown = await _client.PostAsJsonAsync("/api/v1/auth/forgot-password", new { email = ApiFactory.NewEmail() });
        var forgotKnown = await _client.PostAsJsonAsync("/api/v1/auth/forgot-password", new { email = tokens.Email });

        Assert.Equal(HttpStatusCode.Accepted, again.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, forgotUnknown.StatusCode);
        Assert.Equal(HttpStatusCode.Accepted, forgotKnown.StatusCode);
        Assert.Contains(api.Mail.SentTo(tokens.Email), m => m.Kind == "exists");
    }

    [Fact]
    public async Task Wrong_password_is_generic_and_account_locks_after_five_failures()
    {
        var tokens = await api.CreateConfirmedAccount(_client);
        var unknown = await api.Login(_client, ApiFactory.NewEmail());
        Assert.Equal(HttpStatusCode.Unauthorized, unknown.StatusCode);

        for (var i = 0; i < 5; i++)
            await api.Login(_client, tokens.Email, "YanlisSifre9");
        var locked = await api.Login(_client, tokens.Email); // doğru şifre bile reddedilir

        Assert.Equal(HttpStatusCode.TooManyRequests, locked.StatusCode);
        Assert.Equal("locked_out", await Code(locked));
    }

    [Fact]
    public async Task Protected_endpoints_require_token()
    {
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync("/api/v1/account")).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await _client.GetAsync("/api/v1/profiles")).StatusCode);
    }

    [Fact]
    public async Task Expired_access_token_is_rejected_and_refresh_issues_new_one()
    {
        var tokens = await api.CreateConfirmedAccount(_client);
        var authed = api.AuthedClient(tokens);
        Assert.Equal(HttpStatusCode.OK, (await authed.GetAsync("/api/v1/account")).StatusCode);

        api.Time.Advance(TimeSpan.FromMinutes(16));
        Assert.Equal(HttpStatusCode.Unauthorized, (await authed.GetAsync("/api/v1/account")).StatusCode);

        var refresh = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = tokens.RefreshToken });
        Assert.Equal(HttpStatusCode.OK, refresh.StatusCode);
        var renewed = (await refresh.Content.ReadFromJsonAsync<Tokens>())!;
        Assert.Equal(HttpStatusCode.OK, (await api.AuthedClient(renewed).GetAsync("/api/v1/account")).StatusCode);
    }

    [Fact]
    public async Task Refresh_token_expires_after_30_days()
    {
        var tokens = await api.CreateConfirmedAccount(_client);
        api.Time.Advance(TimeSpan.FromDays(31));
        var refresh = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = tokens.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
    }

    [Fact]
    public async Task Garbage_refresh_token_is_rejected()
    {
        var refresh = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = "sahte-belirtec" });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
    }

    [Fact]
    public async Task Logout_revokes_refresh_tokens()
    {
        var tokens = await api.CreateConfirmedAccount(_client);
        Assert.Equal(HttpStatusCode.NoContent,
            (await api.AuthedClient(tokens).PostAsync("/api/v1/auth/logout", null)).StatusCode);

        var refresh = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = tokens.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, refresh.StatusCode);
    }

    [Fact]
    public async Task Password_reset_with_code_changes_password_and_ends_old_sessions()
    {
        var tokens = await api.CreateConfirmedAccount(_client);
        await _client.PostAsJsonAsync("/api/v1/auth/forgot-password", new { email = tokens.Email });
        var code = api.LastCode(tokens.Email, "reset");

        var bad = await _client.PostAsJsonAsync("/api/v1/auth/reset-password",
            new { email = tokens.Email, code = "123456", newPassword = "YeniSifre22" });
        var ok = await _client.PostAsJsonAsync("/api/v1/auth/reset-password",
            new { email = tokens.Email, code, newPassword = "YeniSifre22" });

        Assert.Equal(HttpStatusCode.BadRequest, bad.StatusCode);
        Assert.Equal(HttpStatusCode.OK, ok.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await api.Login(_client, tokens.Email)).StatusCode);
        Assert.Equal(HttpStatusCode.OK, (await api.Login(_client, tokens.Email, "YeniSifre22")).StatusCode);
        var oldRefresh = await _client.PostAsJsonAsync("/api/v1/auth/refresh", new { refreshToken = tokens.RefreshToken });
        Assert.Equal(HttpStatusCode.Unauthorized, oldRefresh.StatusCode);
    }

    [Fact]
    public async Task Delete_account_requires_password_and_removes_everything()
    {
        var tokens = await api.CreateConfirmedAccount(_client);
        var authed = api.AuthedClient(tokens);
        var created = await authed.PostAsJsonAsync("/api/v1/profiles", new { nickname = "Cesur Tilki", grade = 5, characterId = "arin" });
        var profileId = (await created.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid();

        var wrong = await authed.PostAsJsonAsync("/api/v1/account/delete", new { password = "YanlisSifre9" });
        var ok = await authed.PostAsJsonAsync("/api/v1/account/delete", new { password = ApiFactory.Password });

        Assert.Equal(HttpStatusCode.Unauthorized, wrong.StatusCode);
        Assert.Equal(HttpStatusCode.NoContent, ok.StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await api.Login(_client, tokens.Email)).StatusCode);
        using var scope = api.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        Assert.False(await db.Profiles.AnyAsync(p => p.Id == profileId));
        Assert.False(await db.ProfileSaves.AnyAsync(s => s.ProfileId == profileId));
    }

    [Fact]
    public async Task Auth_endpoints_are_rate_limited()
    {
        var client = lowLimitApi.CreateClient();
        var statuses = new List<HttpStatusCode>();
        for (var i = 0; i < 4; i++)
            statuses.Add((await lowLimitApi.Login(client, ApiFactory.NewEmail())).StatusCode);
        Assert.Equal(HttpStatusCode.TooManyRequests, statuses[^1]);
    }

    private static async Task<string?> Code(HttpResponseMessage res) =>
        JsonDocument.Parse(await res.Content.ReadAsStringAsync()).RootElement.GetProperty("code").GetString();
}
