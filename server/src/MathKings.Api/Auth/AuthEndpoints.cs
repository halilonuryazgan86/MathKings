using System.Net.Mail;
using System.Security.Claims;
using MathKings.Api.Data;
using Microsoft.AspNetCore.Authentication.BearerToken;
using Microsoft.AspNetCore.Http.HttpResults;
using Microsoft.AspNetCore.Identity;
using Microsoft.Extensions.Options;

namespace MathKings.Api.Auth;

/// <summary>
/// Yetişkin hesabı uç noktaları. Kimlik doğrulama: ASP.NET Core Identity bearer belirteçleri.
/// Hesap varlığını sızdırmamak için kayıt/şifre sıfırlama her durumda aynı yanıtı verir.
/// </summary>
public static class AuthEndpoints
{
    public sealed record RegisterRequest(string Email, string Password, bool IsAdult, string ConsentVersion);
    public sealed record EmailRequest(string Email);
    public sealed record EmailCodeRequest(string Email, string Code);
    public sealed record LoginRequest(string Email, string Password);
    public sealed record RefreshRequest(string RefreshToken);
    public sealed record ResetPasswordRequest(string Email, string Code, string NewPassword);
    public sealed record PasswordRequest(string Password);
    public sealed record AccountResponse(string Email, DateTimeOffset CreatedAt, string ConsentVersion);

    public const string RateLimitPolicy = "auth";

    public static void MapAuth(this RouteGroupBuilder api)
    {
        var auth = api.MapGroup("/auth").RequireRateLimiting(RateLimitPolicy);
        auth.MapPost("/register", Register);
        auth.MapPost("/confirm-email", ConfirmEmail);
        auth.MapPost("/resend-confirmation", ResendConfirmation);
        auth.MapPost("/login", Login);
        auth.MapPost("/refresh", Refresh);
        auth.MapPost("/forgot-password", ForgotPassword);
        auth.MapPost("/reset-password", ResetPassword);
        auth.MapPost("/logout", Logout).RequireAuthorization();

        api.MapGet("/account", GetAccount).RequireAuthorization();
        api.MapPost("/account/delete", DeleteAccount).RequireAuthorization().RequireRateLimiting(RateLimitPolicy);
    }

    private static async Task<IResult> Register(RegisterRequest req, UserManager<AppUser> users,
        IAccountEmailSender mail, IConfiguration config, TimeProvider time)
    {
        var errors = new Dictionary<string, string[]>();
        if (!req.IsAdult)
            errors["isAdult"] = ["Hesap yalnızca 18 yaşından büyük bir yetişkin tarafından açılabilir."];
        if (req.ConsentVersion != config["Consent:CurrentVersion"])
            errors["consentVersion"] = ["Güncel aydınlatma metni ve rıza onaylanmalıdır."];
        if (!IsValidEmail(req.Email))
            errors["email"] = ["Geçerli bir e-posta adresi girin."];
        if (errors.Count > 0)
            return TypedResults.ValidationProblem(errors);

        // Şifre kuralları hesap varlığından önce kontrol edilir; yanıt farkı hesabı ele vermesin.
        var passwordErrors = new List<IdentityError>();
        foreach (var validator in users.PasswordValidators)
        {
            var check = await validator.ValidateAsync(users, new AppUser(), req.Password ?? "");
            passwordErrors.AddRange(check.Errors);
        }
        if (passwordErrors.Count > 0)
            return TypedResults.ValidationProblem(IdentityErrors(IdentityResult.Failed([.. passwordErrors])));

        var email = req.Email.Trim();
        if (await users.FindByEmailAsync(email) is not null)
        {
            await mail.SendAccountExistsAsync(email);
            return TypedResults.Accepted((string?)null);
        }

        var now = time.GetUtcNow();
        var user = new AppUser
        {
            Id = Guid.CreateVersion7(),
            UserName = email,
            Email = email,
            CreatedAt = now,
            ConsentVersion = req.ConsentVersion,
            ConsentAcceptedAt = now,
        };
        var result = await users.CreateAsync(user, req.Password ?? "");
        if (!result.Succeeded)
            return TypedResults.ValidationProblem(IdentityErrors(result));

        await mail.SendConfirmationCodeAsync(email, await users.GenerateEmailConfirmationTokenAsync(user));
        return TypedResults.Accepted((string?)null);
    }

    private static async Task<IResult> ConfirmEmail(EmailCodeRequest req, UserManager<AppUser> users)
    {
        var user = await users.FindByEmailAsync(req.Email.Trim());
        if (user is null || user.EmailConfirmed || !(await users.ConfirmEmailAsync(user, req.Code.Trim())).Succeeded)
            return InvalidCode();
        return TypedResults.Ok();
    }

    private static async Task<IResult> ResendConfirmation(EmailRequest req, UserManager<AppUser> users,
        IAccountEmailSender mail)
    {
        var user = await users.FindByEmailAsync(req.Email.Trim());
        if (user is { EmailConfirmed: false })
            await mail.SendConfirmationCodeAsync(user.Email!, await users.GenerateEmailConfirmationTokenAsync(user));
        return TypedResults.Accepted((string?)null);
    }

    private static async Task<IResult> Login(LoginRequest req, SignInManager<AppUser> signIn)
    {
        signIn.AuthenticationScheme = IdentityConstants.BearerScheme;
        var user = await signIn.UserManager.FindByEmailAsync(req.Email.Trim());
        if (user is null)
            return WrongCredentials();

        var result = await signIn.PasswordSignInAsync(user, req.Password, isPersistent: false, lockoutOnFailure: true);
        if (result.Succeeded)
            return TypedResults.Empty; // Bearer işleyicisi belirteç yanıtını yazar.
        if (result.IsLockedOut)
            return Problem(StatusCodes.Status429TooManyRequests, "locked_out",
                "Çok fazla hatalı deneme. Lütfen 15 dakika sonra tekrar deneyin.");
        // NotAllowed, şifre kontrolünden önce döner; hesabın varlığını sızdırmamak için şifreyi doğrula.
        if (result.IsNotAllowed && await signIn.UserManager.CheckPasswordAsync(user, req.Password))
            return Problem(StatusCodes.Status403Forbidden, "email_not_confirmed", "Önce e-posta adresinizi doğrulayın.");
        return WrongCredentials();
    }

    private static async Task<IResult> Refresh(RefreshRequest req, SignInManager<AppUser> signIn,
        IOptionsMonitor<BearerTokenOptions> options, TimeProvider time)
    {
        var protector = options.Get(IdentityConstants.BearerScheme).RefreshTokenProtector;
        var ticket = protector.Unprotect(req.RefreshToken);
        if (ticket?.Properties.ExpiresUtc is not { } expires || time.GetUtcNow() >= expires
            || await signIn.ValidateSecurityStampAsync(ticket.Principal) is not { } user)
            return TypedResults.Challenge();

        var principal = await signIn.CreateUserPrincipalAsync(user);
        return TypedResults.SignIn(principal, authenticationScheme: IdentityConstants.BearerScheme);
    }

    /// <summary>Hesabın tüm yenileme belirteçlerini geçersiz kılar (tüm cihazlardan çıkış).</summary>
    private static async Task<IResult> Logout(ClaimsPrincipal principal, UserManager<AppUser> users)
    {
        if (await users.GetUserAsync(principal) is { } user)
            await users.UpdateSecurityStampAsync(user);
        return TypedResults.NoContent();
    }

    private static async Task<IResult> ForgotPassword(EmailRequest req, UserManager<AppUser> users,
        IAccountEmailSender mail)
    {
        var user = await users.FindByEmailAsync(req.Email.Trim());
        if (user is { EmailConfirmed: true })
            await mail.SendPasswordResetCodeAsync(user.Email!, await users.GeneratePasswordResetTokenAsync(user));
        return TypedResults.Accepted((string?)null);
    }

    private static async Task<IResult> ResetPassword(ResetPasswordRequest req, UserManager<AppUser> users)
    {
        var user = await users.FindByEmailAsync(req.Email.Trim());
        if (user is not { EmailConfirmed: true })
            return InvalidCode();
        var result = await users.ResetPasswordAsync(user, req.Code.Trim(), req.NewPassword ?? "");
        if (!result.Succeeded)
            return result.Errors.Any(e => e.Code == "InvalidToken")
                ? InvalidCode()
                : TypedResults.ValidationProblem(IdentityErrors(result));
        await users.SetLockoutEndDateAsync(user, null);
        await users.ResetAccessFailedCountAsync(user);
        return TypedResults.Ok(); // ResetPasswordAsync güvenlik damgasını yeniler: eski oturumlar düşer.
    }

    private static async Task<Results<Ok<AccountResponse>, UnauthorizedHttpResult>> GetAccount(
        ClaimsPrincipal principal, UserManager<AppUser> users)
    {
        if (await users.GetUserAsync(principal) is not { } user)
            return TypedResults.Unauthorized();
        return TypedResults.Ok(new AccountResponse(user.Email!, user.CreatedAt, user.ConsentVersion));
    }

    /// <summary>Hesabı ve tüm çocuk profillerini/ilerlemeyi kalıcı olarak siler (KVKK, mağaza gereksinimi).</summary>
    private static async Task<IResult> DeleteAccount(PasswordRequest req, ClaimsPrincipal principal,
        UserManager<AppUser> users)
    {
        if (await users.GetUserAsync(principal) is not { } user)
            return TypedResults.Unauthorized();
        if (!await users.CheckPasswordAsync(user, req.Password))
            return WrongCredentials();
        var result = await users.DeleteAsync(user);
        return result.Succeeded ? TypedResults.NoContent() : TypedResults.ValidationProblem(IdentityErrors(result));
    }

    // --- Yardımcılar ---------------------------------------------------------

    private static bool IsValidEmail(string? email) =>
        !string.IsNullOrWhiteSpace(email) && email.Length <= 254
        && MailAddress.TryCreate(email.Trim(), out var parsed) && parsed.Address == email.Trim();

    private static IResult WrongCredentials() =>
        Problem(StatusCodes.Status401Unauthorized, "invalid_credentials", "E-posta veya şifre hatalı.");

    private static IResult InvalidCode() =>
        Problem(StatusCodes.Status400BadRequest, "invalid_code", "Kod geçersiz veya süresi dolmuş.");

    private static IResult Problem(int status, string code, string detail) =>
        TypedResults.Problem(detail: detail, statusCode: status,
            extensions: new Dictionary<string, object?> { ["code"] = code });

    private static Dictionary<string, string[]> IdentityErrors(IdentityResult result) =>
        result.Errors.GroupBy(e => e.Code.StartsWith("Password") ? "password" : "email")
            .ToDictionary(g => g.Key, g => g.Select(e => Translate(e)).Distinct().ToArray());

    private static string Translate(IdentityError e) => e.Code switch
    {
        "PasswordTooShort" => "Şifre en az 8 karakter olmalı.",
        "PasswordRequiresDigit" => "Şifre en az bir rakam içermeli.",
        "PasswordRequiresLower" => "Şifre en az bir küçük harf içermeli.",
        "PasswordRequiresUpper" => "Şifre en az bir büyük harf içermeli.",
        "DuplicateEmail" or "DuplicateUserName" => "Bu e-posta ile kayıt yapılamadı.",
        "InvalidEmail" or "InvalidUserName" => "Geçerli bir e-posta adresi girin.",
        _ => "İşlem tamamlanamadı.",
    };
}
