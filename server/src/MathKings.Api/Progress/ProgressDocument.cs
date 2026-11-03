using System.Text.Json;
using System.Text.RegularExpressions;

namespace MathKings.Api.Progress;

/// <summary>
/// Oyun ilerlemesi. Godot istemcisindeki SaveData ile aynı alan adları ve kurallar.
/// Altın saklanmaz; ilerlemeden hesaplanır (bkz. <see cref="ProgressRules.ComputeGold"/>).
/// </summary>
public sealed record ProgressDocument
{
    public bool SeenIntro { get; init; }
    public Dictionary<string, LevelProgress> Levels { get; init; } = [];
    public Dictionary<string, TopicStats> Stats { get; init; } = [];
}

public sealed record LevelProgress
{
    public bool Completed { get; init; }
    public List<string> Collected { get; init; } = [];
    public int BattleStars { get; init; }
}

public sealed record TopicStats(int Attempts, int Correct);

public static partial class ProgressRules
{
    // İstemcideki SaveData sabitleriyle aynı olmalıdır.
    public const int CoinGold = 1;
    public const int StarGold = 10;
    public const int TreasureGold = 15;
    public const int BattleFirstWinGold = 20;
    public const int BattleStarGold = 5;
    public const string CoinPrefix = "coin_";
    public const string StarPrefix = "star_";
    public const string TreasurePrefix = "treasure_";

    public static int ItemGold(string id) =>
        id.StartsWith(CoinPrefix) ? CoinGold
        : id.StartsWith(StarPrefix) ? StarGold
        : id.StartsWith(TreasurePrefix) ? TreasureGold
        : 0;

    public const int MaxLevels = 100;
    public const int MaxCollectedPerLevel = 1000;
    public const int MaxTopics = 50;
    public const int MaxAttempts = 1_000_000;

    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    [GeneratedRegex("^[a-z0-9_]{1,40}$")]
    private static partial Regex IdPattern();

    public static int ComputeGold(ProgressDocument doc)
    {
        var gold = 0;
        foreach (var level in doc.Levels.Values)
        {
            gold += level.Collected.Sum(ItemGold);
            if (level.BattleStars > 0)
                gold += BattleFirstWinGold + level.BattleStars * BattleStarGold;
        }
        return gold;
    }

    /// <summary>İki cihazdan gelen ilerlemeyi birleştirir. Değişmeli ve tekrarlanabilir (idempotent).</summary>
    public static ProgressDocument Merge(ProgressDocument a, ProgressDocument b)
    {
        var levels = new Dictionary<string, LevelProgress>();
        foreach (var id in a.Levels.Keys.Union(b.Levels.Keys))
        {
            a.Levels.TryGetValue(id, out var la);
            b.Levels.TryGetValue(id, out var lb);
            levels[id] = new LevelProgress
            {
                Completed = (la?.Completed ?? false) || (lb?.Completed ?? false),
                Collected = (la?.Collected ?? []).Union(lb?.Collected ?? []).Order(StringComparer.Ordinal).ToList(),
                BattleStars = Math.Max(la?.BattleStars ?? 0, lb?.BattleStars ?? 0),
            };
        }

        var stats = new Dictionary<string, TopicStats>();
        foreach (var topic in a.Stats.Keys.Union(b.Stats.Keys))
        {
            a.Stats.TryGetValue(topic, out var sa);
            b.Stats.TryGetValue(topic, out var sb);
            var attempts = Math.Max(sa?.Attempts ?? 0, sb?.Attempts ?? 0);
            var correct = Math.Min(Math.Max(sa?.Correct ?? 0, sb?.Correct ?? 0), attempts);
            stats[topic] = new TopicStats(attempts, correct);
        }

        return new ProgressDocument { SeenIntro = a.SeenIntro || b.SeenIntro, Levels = levels, Stats = stats };
    }

    /// <summary>İstemciden gelen belgeyi doğrular. Hata yoksa boş sözlük döner.</summary>
    public static Dictionary<string, string[]> Validate(ProgressDocument doc)
    {
        var errors = new Dictionary<string, string[]>();
        void Add(string key, string message) => errors[key] = [message];

        // JSON'da açıkça null gönderilen alanlar (deserializer varsayılanı ezer).
        if (doc.Levels is null || doc.Stats is null
            || doc.Levels.Values.Any(l => l is null || l.Collected is null) || doc.Stats.Values.Any(s => s is null))
        {
            Add("progress", "Eksik veya geçersiz alan.");
            return errors;
        }

        if (doc.Levels.Count > MaxLevels) Add("levels", "Çok fazla bölüm.");
        if (doc.Stats.Count > MaxTopics) Add("stats", "Çok fazla konu.");

        foreach (var (id, level) in doc.Levels)
        {
            if (!IdPattern().IsMatch(id)) Add($"levels.{id}", "Geçersiz bölüm kimliği.");
            if (level.BattleStars is < 0 or > 3) Add($"levels.{id}.battleStars", "0-3 arası olmalı.");
            if (level.Collected.Count > MaxCollectedPerLevel) Add($"levels.{id}.collected", "Çok fazla öğe.");
            else if (level.Collected.Any(item => !IdPattern().IsMatch(item) || ItemGold(item) == 0))
                Add($"levels.{id}.collected", "Geçersiz öğe kimliği.");
        }

        foreach (var (topic, s) in doc.Stats)
        {
            if (!IdPattern().IsMatch(topic)) Add($"stats.{topic}", "Geçersiz konu kimliği.");
            if (s.Attempts is < 0 or > MaxAttempts || s.Correct < 0 || s.Correct > s.Attempts)
                Add($"stats.{topic}", "Geçersiz istatistik.");
        }
        return errors;
    }
}
