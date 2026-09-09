part of 'widgets.dart';

/// Internal bookmark link. Same constructor as `pw.Link`.
class Link extends Widget {
  /// Link API.
  const Link({required this.child, required this.destination});

  /// child API.
  final Widget child;

  /// destination API.
  final String destination;
}

/// External URL. Same constructor as `pw.UrlLink`.
class UrlLink extends Widget {
  /// UrlLink API.
  const UrlLink({required this.child, required this.destination});

  /// child API.
  final Widget child;

  /// destination API.
  final String destination;
}
