const fs = require('fs');

// 1. Fix AuthProvider
let auth = fs.readFileSync('vylithra_mobile/lib/providers/auth_provider.dart', 'utf8');
if (!auth.includes('import \'dart:convert\';')) {
    auth = 'import \'dart:convert\';\n' + auth;
}
if (!auth.includes('String? get currentUserId')) {
    const userIdGetter = `
  String? get currentUserId {
    if (_vylithraToken == null) return null;
    try {
      final parts = _vylithraToken!.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = utf8.decode(base64Url.decode(normalized));
      final data = jsonDecode(payload);
      return data['user']?['id'] ?? data['id'] ?? data['_id'];
    } catch(e) {
      return null;
    }
  }
`;
    auth = auth.replace('String? get token => _vylithraToken;', 'String? get token => _vylithraToken;\n' + userIdGetter);
    fs.writeFileSync('vylithra_mobile/lib/providers/auth_provider.dart', auth);
}

// 2. Fix home_screen.dart
let home = fs.readFileSync('vylithra_mobile/lib/screens/home_screen.dart', 'utf8');

// replace .user?['id'] with .currentUserId
home = home.replace(/Provider\.of<AuthProvider>\(context, listen: false\)\.user\?\['id'\]/g, "Provider.of<AuthProvider>(context, listen: false).currentUserId");

// fix withOpacity to withValues(alpha: ...)
home = home.replace(/\.withOpacity\((.*?)\)/g, ".withValues(alpha: $1)");

// fix CachedNetworkImageProvider context warning
// Actually the warning was "The method 'CachedNetworkImageProvider' isn't defined for the type '_HomeScreenState'."
// wait, CachedNetworkImageProvider is a class from 'package:cached_network_image/cached_network_image.dart'. It's not a method. 
// Ah! In Flutter, if a package is not imported or missing from pubspec, the compiler thinks it's an undefined method if used like `CachedNetworkImageProvider(...)`.
// We added it to pubspec, and I injected the import in fix_home_flutter.js: `import 'package:cached_network_image/cached_network_image.dart';`
// Wait, looking at the error log, there were two imports of cached_network_image. Let's make sure it's imported at the top correctly.
if (!home.includes("import 'package:cached_network_image/cached_network_image.dart';")) {
    home = "import 'package:cached_network_image/cached_network_image.dart';\n" + home;
}

// fix mounted warning
home = home.replace("if (mounted) setState(() {});", "if (!mounted) return; setState(() {});");

fs.writeFileSync('vylithra_mobile/lib/screens/home_screen.dart', home);

// 3. Fix post_card.dart
let postCard = fs.readFileSync('vylithra_mobile/lib/widgets/post_card.dart', 'utf8');
postCard = postCard.replace(/Provider\.of<AuthProvider>\(context, listen: false\)\.user\?\['id'\]/g, "Provider.of<AuthProvider>(context, listen: false).currentUserId");
fs.writeFileSync('vylithra_mobile/lib/widgets/post_card.dart', postCard);

console.log("Flutter files patched successfully");
