library;

/// This app's theme now lives in `packages/school_shared`, shared by all
/// four apps — see `design-system/MASTER.md` "Theme architecture". This is
/// the first time this app has depended on `school_shared` at all; the
/// dependency is purely for design-system code (tokens/theme/components),
/// not its independent auth stack, which is unchanged. Kept as a
/// re-export so existing `import 'theme.dart';` call sites in this app
/// don't need to change.
export 'package:school_shared/school_shared.dart' show buildAppTheme, AppBrand;
