using Microsoft.AspNetCore.Identity;

namespace MathKings.Api.Data;

/// <summary>Yetişkin hesabı (veli). Çocuklar hesap sahibi olmaz; profil olarak eklenir.</summary>
public sealed class AppUser : IdentityUser<Guid>
{
    public DateTimeOffset CreatedAt { get; set; }

    /// <summary>Kayıtta onaylanan aydınlatma/rıza metni sürümü ve zamanı (KVKK kanıtı).</summary>
    public string ConsentVersion { get; set; } = "";
    public DateTimeOffset ConsentAcceptedAt { get; set; }

    public List<PlayerProfile> Profiles { get; set; } = [];
}

/// <summary>Çocuk oyuncu profili. Gerçek ad, doğum tarihi vb. kişisel veri tutulmaz.</summary>
public sealed class PlayerProfile
{
    public const int MaxNicknameLength = 24;
    public const int MaxPerAccount = 5;

    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public string Nickname { get; set; } = "";
    public short Grade { get; set; }
    public string CharacterId { get; set; } = "";
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    public ProfileSave? Save { get; set; }
}

/// <summary>Profilin oyun ilerlemesi: istemciyle aynı biçimde JSONB belge.</summary>
public sealed class ProfileSave
{
    public Guid ProfileId { get; set; }
    public string Data { get; set; } = "{}";
    public int Version { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
