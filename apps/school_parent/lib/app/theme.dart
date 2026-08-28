library;

/// This app's theme now lives in `packages/school_shared`, shared by all
/// four apps — see `design-system/MASTER.md` "Theme architecture". Kept as
/// a re-export so existing `import 'theme.dart';` call sites in this app
/// don't need to change.
export 'package:school_shared/school_shared.dart' show buildAppTheme, AppBrand;
