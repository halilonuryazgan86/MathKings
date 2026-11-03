using System.Security.Claims;
using System.Text.Json;
using System.Text.RegularExpressions;
using MathKings.Api.Data;
using MathKings.Api.Progress;
using Microsoft.EntityFrameworkCore;

namespace MathKings.Api.Profiles;

/// <summary>
/// Çocuk profilleri ve ilerleme senkronizasyonu. Her sorgu hesap kimliğiyle sınırlıdır;
/// başka hesabın profili "bulunamadı" olarak görünür.
/// </summary>
public static partial class ProfileEndpoints
{
    public sealed record ProfileRequest(string Nickname, int Grade, string CharacterId);
    public sealed record ProfileResponse(Guid Id, string Nickname, int Grade, string CharacterId, DateTimeOffset UpdatedAt);
    public sealed record SaveResponse(ProgressDocument Progress, int Gold, int Version, DateTimeOffset UpdatedAt);

    public static readonly string[] CharacterIds = ["arin", "lina", "bora"];
    private const int MaxSaveRetries = 3;

    [GeneratedRegex(@"^\p{L}+( \p{L}+)*$")]
    private static partial Regex NicknamePattern();

    public static void MapProfiles(this RouteGroupBuilder api)
    {
        var profiles = api.MapGroup("/profiles").RequireAuthorization();
        profiles.MapGet("/", List);
        profiles.MapPost("/", Create);
        profiles.MapPut("/{id:guid}", Update);
        profiles.MapDelete("/{id:guid}", Delete);
        profiles.MapGet("/{id:guid}/save", GetSave);
        profiles.MapPut("/{id:guid}/save", PutSave);
    }

    private static async Task<IResult> List(ClaimsPrincipal user, AppDbContext db)
    {
        var accountId = AccountId(user);
        var list = await db.Profiles.Where(p => p.AccountId == accountId).OrderBy(p => p.CreatedAt)
            .Select(p => new ProfileResponse(p.Id, p.Nickname, p.Grade, p.CharacterId, p.UpdatedAt))
            .ToListAsync();
        return TypedResults.Ok(list);
    }

    private static async Task<IResult> Create(ProfileRequest req, ClaimsPrincipal user, AppDbContext db, TimeProvider time)
    {
        if (Validate(req) is { Count: > 0 } errors)
            return TypedResults.ValidationProblem(errors);
        var accountId = AccountId(user);
        if (await db.Profiles.CountAsync(p => p.AccountId == accountId) >= PlayerProfile.MaxPerAccount)
            return TypedResults.Problem(statusCode: StatusCodes.Status409Conflict,
                detail: $"Bir hesapta en fazla {PlayerProfile.MaxPerAccount} profil olabilir.");

        var now = time.GetUtcNow();
        var profile = new PlayerProfile
        {
            Id = Guid.CreateVersion7(),
            AccountId = accountId,
            Nickname = req.Nickname.Trim(),
            Grade = (short)req.Grade,
            CharacterId = req.CharacterId,
            CreatedAt = now,
            UpdatedAt = now,
            Save = new ProfileSave { Data = Serialize(new ProgressDocument()), Version = 1, UpdatedAt = now },
        };
        db.Profiles.Add(profile);
        await db.SaveChangesAsync();
        return TypedResults.Created($"/api/v1/profiles/{profile.Id}", ToResponse(profile));
    }

    private static async Task<IResult> Update(Guid id, ProfileRequest req, ClaimsPrincipal user, AppDbContext db, TimeProvider time)
    {
        if (Validate(req) is { Count: > 0 } errors)
            return TypedResults.ValidationProblem(errors);
        var profile = await Find(db, user, id);
        if (profile is null)
            return TypedResults.NotFound();
        profile.Nickname = req.Nickname.Trim();
        profile.Grade = (short)req.Grade;
        profile.CharacterId = req.CharacterId;
        profile.UpdatedAt = time.GetUtcNow();
        await db.SaveChangesAsync();
        return TypedResults.Ok(ToResponse(profile));
    }

    private static async Task<IResult> Delete(Guid id, ClaimsPrincipal user, AppDbContext db)
    {
        var profile = await Find(db, user, id);
        if (profile is null)
            return TypedResults.NotFound();
        db.Profiles.Remove(profile);
        await db.SaveChangesAsync();
        return TypedResults.NoContent();
    }

    private static async Task<IResult> GetSave(Guid id, ClaimsPrincipal user, AppDbContext db)
    {
        var profile = await Find(db, user, id);
        if (profile?.Save is null)
            return TypedResults.NotFound();
        return TypedResults.Ok(ToSaveResponse(profile.Save));
    }

    /// <summary>
    /// Cihazdaki ilerlemeyi sunucudakiyle birleştirir (kayıp yok, tekrar gönderim güvenli).
    /// Altın istemciden alınmaz; birleşik ilerlemeden hesaplanır.
    /// </summary>
    private static async Task<IResult> PutSave(Guid id, ProgressDocument incoming, ClaimsPrincipal user,
        AppDbContext db, TimeProvider time)
    {
        if (ProgressRules.Validate(incoming) is { Count: > 0 } errors)
            return TypedResults.ValidationProblem(errors);

        for (var attempt = 1; ; attempt++)
        {
            var profile = await Find(db, user, id);
            if (profile?.Save is null)
                return TypedResults.NotFound();
            var save = profile.Save;
            var merged = ProgressRules.Merge(Deserialize(save.Data), incoming);
            save.Data = Serialize(merged);
            save.Version++;
            save.UpdatedAt = time.GetUtcNow();
            try
            {
                await db.SaveChangesAsync();
                return TypedResults.Ok(ToSaveResponse(save));
            }
            catch (DbUpdateConcurrencyException) when (attempt < MaxSaveRetries)
            {
                db.ChangeTracker.Clear(); // Başka cihaz aynı anda yazdı: yeniden oku ve birleştir.
            }
        }
    }

    // --- Yardımcılar ---------------------------------------------------------

    private static Guid AccountId(ClaimsPrincipal user) =>
        Guid.Parse(user.FindFirstValue(ClaimTypes.NameIdentifier)!);

    private static Task<PlayerProfile?> Find(AppDbContext db, ClaimsPrincipal user, Guid id)
    {
        var accountId = AccountId(user);
        return db.Profiles.Include(p => p.Save).SingleOrDefaultAsync(p => p.Id == id && p.AccountId == accountId);
    }

    private static Dictionary<string, string[]> Validate(ProfileRequest req)
    {
        var errors = new Dictionary<string, string[]>();
        var nick = req.Nickname?.Trim() ?? "";
        if (nick.Length is < 2 or > PlayerProfile.MaxNicknameLength || !NicknamePattern().IsMatch(nick))
            errors["nickname"] = ["Takma ad 2-24 harf olmalı (yalnızca harf ve boşluk)."];
        if (req.Grade is < 4 or > 7)
            errors["grade"] = ["Sınıf 4 ile 7 arasında olmalı."];
        if (!CharacterIds.Contains(req.CharacterId))
            errors["characterId"] = ["Geçersiz karakter."];
        return errors;
    }

    private static ProfileResponse ToResponse(PlayerProfile p) =>
        new(p.Id, p.Nickname, p.Grade, p.CharacterId, p.UpdatedAt);

    private static SaveResponse ToSaveResponse(ProfileSave s)
    {
        var doc = Deserialize(s.Data);
        return new SaveResponse(doc, ProgressRules.ComputeGold(doc), s.Version, s.UpdatedAt);
    }

    private static string Serialize(ProgressDocument doc) => JsonSerializer.Serialize(doc, ProgressRules.Json);

    private static ProgressDocument Deserialize(string json) =>
        JsonSerializer.Deserialize<ProgressDocument>(json, ProgressRules.Json) ?? new ProgressDocument();
}
