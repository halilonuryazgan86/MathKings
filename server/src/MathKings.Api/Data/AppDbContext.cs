using Microsoft.AspNetCore.Identity.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore;

namespace MathKings.Api.Data;

/// <summary>Identity kullanıcı tabloları (rol yok) + profil ve ilerleme tabloları.</summary>
public sealed class AppDbContext(DbContextOptions<AppDbContext> options)
    : IdentityUserContext<AppUser, Guid>(options)
{
    public DbSet<PlayerProfile> Profiles => Set<PlayerProfile>();
    public DbSet<ProfileSave> ProfileSaves => Set<ProfileSave>();

    protected override void OnModelCreating(ModelBuilder b)
    {
        base.OnModelCreating(b);

        b.Entity<AppUser>(e =>
        {
            e.Property(u => u.ConsentVersion).HasMaxLength(32);
            e.HasMany(u => u.Profiles).WithOne().HasForeignKey(p => p.AccountId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<PlayerProfile>(e =>
        {
            e.ToTable("player_profiles", t =>
                t.HasCheckConstraint("ck_player_profiles_grade", "\"Grade\" BETWEEN 4 AND 7"));
            e.HasKey(p => p.Id);
            e.HasIndex(p => p.AccountId);
            e.Property(p => p.Nickname).HasMaxLength(PlayerProfile.MaxNicknameLength).IsRequired();
            e.Property(p => p.CharacterId).HasMaxLength(16).IsRequired();
            e.HasOne(p => p.Save).WithOne().HasForeignKey<ProfileSave>(s => s.ProfileId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        b.Entity<ProfileSave>(e =>
        {
            e.ToTable("profile_saves");
            e.HasKey(s => s.ProfileId);
            e.Property(s => s.Data).HasColumnType("jsonb").IsRequired();
            e.Property(s => s.Version).IsConcurrencyToken();
        });
    }
}
