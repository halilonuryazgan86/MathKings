using System.Net;
using System.Net.Mail;
using Microsoft.Extensions.Options;

namespace MathKings.Api.Auth;

public sealed class SmtpOptions
{
    public string Host { get; set; } = "localhost";
    public int Port { get; set; } = 1025;
    public bool EnableSsl { get; set; }
    public string? User { get; set; }
    public string? Password { get; set; }
    public string From { get; set; } = "MathKings <no-reply@mathkings.local>";
}

/// <summary>
/// SMTP ile e-posta gönderir. Geliştirmede Laragon Mailpit'e (localhost:1025) gider ve
/// http://localhost:8025 adresinde görünür; yayında aynı sınıf gerçek sağlayıcı ayarlarıyla çalışır.
/// Geliştirmede kodlar ayrıca /dev/last-code için belleğe de kaydedilir.
/// </summary>
public sealed class SmtpEmailSender(IOptions<SmtpOptions> options, LogEmailSender devRecorder,
    IHostEnvironment env, ILogger<SmtpEmailSender> log) : IAccountEmailSender
{
    private readonly SmtpOptions _o = options.Value;

    public Task SendConfirmationCodeAsync(string email, string code) => Send(email, "confirm", code,
        "Matematik Krallığı - e-posta doğrulama kodu",
        $"Merhaba,\n\nMatematik Krallığı ebeveyn hesabınızı doğrulamak için kodunuz:\n\n    {code}\n\n" +
        "Kod birkaç dakika geçerlidir. Bu isteği siz yapmadıysanız bu e-postayı yok sayabilirsiniz.");

    public Task SendPasswordResetCodeAsync(string email, string code) => Send(email, "reset", code,
        "Matematik Krallığı - şifre sıfırlama kodu",
        $"Merhaba,\n\nŞifrenizi sıfırlamak için kodunuz:\n\n    {code}\n\n" +
        "Kod birkaç dakika geçerlidir. Bu isteği siz yapmadıysanız şifreniz değişmez.");

    public Task SendAccountExistsAsync(string email) => Send(email, "exists", null,
        "Matematik Krallığı - hesabınız zaten var",
        "Merhaba,\n\nBu e-posta adresiyle zaten bir hesabınız var. Giriş yapabilir veya " +
        "\"Şifremi unuttum\" ile şifrenizi sıfırlayabilirsiniz.");

    private async Task Send(string to, string kind, string? code, string subject, string body)
    {
        if (env.IsDevelopment())
            await devRecorder.Record(to, kind, code, writeLog: false);

        using var message = new MailMessage(_o.From, to, subject, body);
        using var client = new SmtpClient(_o.Host, _o.Port) { EnableSsl = _o.EnableSsl };
        if (!string.IsNullOrEmpty(_o.User))
            client.Credentials = new NetworkCredential(_o.User, _o.Password);
        try
        {
            await client.SendMailAsync(message);
        }
        catch (SmtpException ex)
        {
            // Hesap varlığını sızdırmamak için istemciye aynı yanıt döner; hata yalnızca log'a gider.
            log.LogError(ex, "E-posta gönderilemedi ({Kind})", kind);
        }
    }
}
