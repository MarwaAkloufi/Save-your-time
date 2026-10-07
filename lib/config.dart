
class AdminConfig {
  AdminConfig._();

  static const String scriptUrl = 'https://script.google.com/macros/s/AKfycbw6UxES-sgMb6NswWMZs_XW0udugoVSqT34CtHAv7sO3UW957qQOEbtvaQ7ltLhYMuX/exec';

  static bool get isConfigured => scriptUrl.isNotEmpty;
}
