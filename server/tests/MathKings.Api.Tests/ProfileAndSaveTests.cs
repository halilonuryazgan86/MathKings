using System.Net;
using System.Net.Http.Json;
using System.Text.Json;

namespace MathKings.Api.Tests;

[Collection(ApiCollection.Name)]
public sealed class ProfileAndSaveTests(ApiFactory api)
{
    private readonly HttpClient _anon = api.CreateClient();

    private async Task<(HttpClient Client, Guid ProfileId)> AccountWithProfile()
    {
        var client = api.AuthedClient(await api.CreateConfirmedAccount(_anon));
        var res = await client.PostAsJsonAsync("/api/v1/profiles", new { nickname = "Zeki Panda", grade = 6, characterId = "lina" });
        Assert.Equal(HttpStatusCode.Created, res.StatusCode);
        return (client, (await res.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("id").GetGuid());
    }

    [Theory]
    [InlineData("A", 5, "arin")]                     // çok kısa
    [InlineData("Ali@mail.com", 5, "arin")]          // harf dışı karakter (e-posta vb. kişisel veri engellenir)
    [InlineData("Ali 0532", 5, "arin")]              // rakam (telefon vb.)
    [InlineData("Cesur Tilki", 8, "arin")]           // geçersiz sınıf
    [InlineData("Cesur Tilki", 5, "ejderha")]        // geçersiz karakter
    public async Task Invalid_profiles_are_rejected(string nickname, int grade, string characterId)
    {
        var client = api.AuthedClient(await api.CreateConfirmedAccount(_anon));
        var res = await client.PostAsJsonAsync("/api/v1/profiles", new { nickname, grade, characterId });
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    [Fact]
    public async Task Account_can_have_at_most_five_profiles()
    {
        var client = api.AuthedClient(await api.CreateConfirmedAccount(_anon));
        for (var i = 0; i < 5; i++)
            (await client.PostAsJsonAsync("/api/v1/profiles", new { nickname = "Hızlı Kartal", grade = 4, characterId = "bora" }))
                .EnsureSuccessStatusCode();
        var sixth = await client.PostAsJsonAsync("/api/v1/profiles", new { nickname = "Hızlı Kartal", grade = 4, characterId = "bora" });
        Assert.Equal(HttpStatusCode.Conflict, sixth.StatusCode);
    }

    [Fact]
    public async Task Other_accounts_profiles_are_invisible()
    {
        var (_, profileId) = await AccountWithProfile();
        var stranger = api.AuthedClient(await api.CreateConfirmedAccount(_anon));

        Assert.Equal(HttpStatusCode.NotFound, (await stranger.GetAsync($"/api/v1/profiles/{profileId}/save")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.PutAsJsonAsync($"/api/v1/profiles/{profileId}/save", new { })).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await stranger.DeleteAsync($"/api/v1/profiles/{profileId}")).StatusCode);
        Assert.Empty((await stranger.GetFromJsonAsync<JsonElement>("/api/v1/profiles")).EnumerateArray());
    }

    [Fact]
    public async Task Guest_progress_transfers_and_second_device_merges_without_loss()
    {
        var (client, id) = await AccountWithProfile();
        var url = $"/api/v1/profiles/{id}/save";

        // Misafir cihaz: 2 altın, 1 yıldız, savaş 2 yıldız.
        var guest = new
        {
            seenIntro = true,
            levels = new { forest_01 = new { completed = true, collected = new[] { "coin_6_10", "coin_8_10", "star_12_6" }, battleStars = 2 } },
            stats = new { mul = new { attempts = 4, correct = 3 } },
        };
        var first = await (await client.PutAsJsonAsync(url, guest)).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(2 * 1 + 10 + 20 + 2 * 5, first.GetProperty("gold").GetInt32());

        // İkinci cihaz: bir altın ortak, bir yeni yıldız, daha düşük savaş sonucu.
        var tablet = new
        {
            seenIntro = false,
            levels = new { forest_01 = new { completed = false, collected = new[] { "coin_6_10", "star_40_4" }, battleStars = 1 } },
            stats = new { div = new { attempts = 2, correct = 2 } },
        };
        var merged = await (await client.PutAsJsonAsync(url, tablet)).Content.ReadFromJsonAsync<JsonElement>();
        var level = merged.GetProperty("progress").GetProperty("levels").GetProperty("forest_01");

        Assert.Equal(4, level.GetProperty("collected").GetArrayLength());
        Assert.True(level.GetProperty("completed").GetBoolean());
        Assert.Equal(2, level.GetProperty("battleStars").GetInt32());
        Assert.True(merged.GetProperty("progress").GetProperty("seenIntro").GetBoolean());
        Assert.Equal(2, merged.GetProperty("progress").GetProperty("stats").EnumerateObject().Count());
        Assert.Equal(2 + 20 + 20 + 10, merged.GetProperty("gold").GetInt32());

        // Aynı veriyi tekrar göndermek altını artırmaz (ödül suistimali yok).
        var repeat = await (await client.PutAsJsonAsync(url, tablet)).Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(merged.GetProperty("gold").GetInt32(), repeat.GetProperty("gold").GetInt32());
        Assert.True(repeat.GetProperty("version").GetInt32() > merged.GetProperty("version").GetInt32());
    }

    [Fact]
    public async Task Client_supplied_gold_is_ignored()
    {
        var (client, id) = await AccountWithProfile();
        var res = await client.PutAsJsonAsync($"/api/v1/profiles/{id}/save",
            new { gold = 999999, levels = new { forest_01 = new { collected = new[] { "coin_1_1" } } }, stats = new { } });
        var body = await res.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(1, body.GetProperty("gold").GetInt32());
    }

    [Theory]
    [InlineData("""{"levels":{"forest_01":{"battleStars":9,"collected":[]}},"stats":{}}""")]
    [InlineData("""{"levels":{"forest_01":{"collected":["hack_1"]}},"stats":{}}""")]
    [InlineData("""{"levels":{"../etc":{"collected":[]}},"stats":{}}""")]
    [InlineData("""{"levels":{},"stats":{"mul":{"attempts":1,"correct":50}}}""")]
    [InlineData("""{"levels":null,"stats":{}}""")]
    public async Task Tampered_progress_is_rejected(string json)
    {
        var (client, id) = await AccountWithProfile();
        var res = await client.PutAsync($"/api/v1/profiles/{id}/save",
            new StringContent(json, System.Text.Encoding.UTF8, "application/json"));
        Assert.Equal(HttpStatusCode.BadRequest, res.StatusCode);
    }

    [Fact]
    public async Task Profile_update_and_delete()
    {
        var (client, id) = await AccountWithProfile();
        var update = await client.PutAsJsonAsync($"/api/v1/profiles/{id}", new { nickname = "Neşeli Yunus", grade = 7, characterId = "bora" });
        Assert.Equal(HttpStatusCode.OK, update.StatusCode);
        Assert.Equal("Neşeli Yunus", (await update.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("nickname").GetString());

        Assert.Equal(HttpStatusCode.NoContent, (await client.DeleteAsync($"/api/v1/profiles/{id}")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync($"/api/v1/profiles/{id}/save")).StatusCode);
    }
}
