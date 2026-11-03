using System.Collections.Concurrent;

namespace MathKings.Api.Auth;

public interface IAccountEmailSender
{
    Task SendConfirmationCodeAsync(string email, string code);
    Task SendPasswordResetCodeAsync(string email, string code);
    Task SendAccountExistsAsync(string email);
}

public sealed record SentEmail(string Kind, string? Code);

/// <summary>
/// Geliştirme/test göndericisi: e-posta yerine log'a yazar ve bellekte tutar.
/// Üretimde kullanılamaz (Program.cs başlangıçta engeller). Gerçek SMTP sağlayıcısı yayın öncesi eklenecek.
/// </summary>
public sealed class LogEmailSender(ILogger<LogEmailSender> log) : IAccountEmailSender
{
    private readonly ConcurrentDictionary<string, ConcurrentQueue<SentEmail>> _sent =
        new(StringComparer.OrdinalIgnoreCase);

    public IReadOnlyList<SentEmail> SentTo(string email) =>
        _sent.TryGetValue(email, out var q) ? q.ToList() : [];

    public Task SendConfirmationCodeAsync(string email, string code) => Record(email, "confirm", code);
    public Task SendPasswordResetCodeAsync(string email, string code) => Record(email, "reset", code);
    public Task SendAccountExistsAsync(string email) => Record(email, "exists", null);

    private Task Record(string email, string kind, string? code)
    {
        _sent.GetOrAdd(email, _ => new()).Enqueue(new SentEmail(kind, code));
        log.LogInformation("[DEV E-POSTA] {Email} -> {Kind} {Code}", email, kind, code);
        return Task.CompletedTask;
    }
}
