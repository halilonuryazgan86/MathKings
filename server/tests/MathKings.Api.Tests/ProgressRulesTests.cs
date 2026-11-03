using MathKings.Api.Progress;

namespace MathKings.Api.Tests;

public sealed class ProgressRulesTests
{
    private static ProgressDocument Doc(bool completed, int battleStars, params string[] collected) => new()
    {
        Levels = new() { ["forest_01"] = new LevelProgress { Completed = completed, BattleStars = battleStars, Collected = [.. collected] } },
        Stats = new() { ["add"] = new TopicStats(3, 2) },
    };

    [Fact]
    public void Gold_matches_client_formula()
    {
        // Godot SaveData ile aynı: altın 1, yıldız 10, hazine 15, ilk zafer 20 + yıldız başına 5.
        var doc = Doc(true, 3, "coin_1_1", "coin_2_1", "star_3_1", "treasure_5_5");
        Assert.Equal(62, ProgressRules.ComputeGold(doc));
        Assert.Equal(0, ProgressRules.ComputeGold(new ProgressDocument()));
        Assert.Empty(ProgressRules.Validate(doc));
    }

    [Fact]
    public void Merge_is_commutative_and_idempotent()
    {
        var a = Doc(true, 1, "coin_1_1", "star_3_1");
        var b = Doc(false, 3, "coin_1_1", "coin_9_9");

        var ab = ProgressRules.Merge(a, b);
        var ba = ProgressRules.Merge(b, a);
        var abb = ProgressRules.Merge(ab, b);

        Assert.Equal(ProgressRules.ComputeGold(ab), ProgressRules.ComputeGold(ba));
        Assert.Equal(ab.Levels["forest_01"].Collected, ba.Levels["forest_01"].Collected);
        Assert.Equal(ab.Levels["forest_01"].Collected, abb.Levels["forest_01"].Collected);
        Assert.Equal(3, ab.Levels["forest_01"].BattleStars);
        Assert.True(ab.Levels["forest_01"].Completed);
        Assert.Equal(3, ab.Levels["forest_01"].Collected.Count);
    }

    [Fact]
    public void Merge_never_loses_progress()
    {
        var merged = ProgressRules.Merge(Doc(true, 2, "coin_1_1"), new ProgressDocument());
        Assert.Single(merged.Levels["forest_01"].Collected);
        Assert.Equal(2, merged.Levels["forest_01"].BattleStars);
    }
}
