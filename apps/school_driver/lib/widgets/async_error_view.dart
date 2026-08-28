import 'package:school_shared/school_shared.dart';

/// This app's error state now shares one implementation
/// (`ErrorStateView`) with all four apps — see
/// `design-system/MASTER.md` "Theme architecture". Kept under this app's
/// original name and constructor shape so existing call sites don't need
/// to change.
class AsyncErrorView extends ErrorStateView {
  const AsyncErrorView({super.key, super.compact});
}
