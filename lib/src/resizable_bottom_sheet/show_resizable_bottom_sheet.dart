import 'package:flutter/material.dart';

/// Configuration for the appearance of the resizable bottom sheet
class BottomSheetAppearance {
  /// Creates a new BottomSheetAppearance
  const BottomSheetAppearance({
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.clipBehavior,
    this.modalBackgroundColor,
    this.barrierColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.showDragHandle = true,
    this.dragHandleColor,
    this.dragHandleSize,
    this.borderRadius,
  });

  /// The background color of the bottom sheet
  final Color? backgroundColor;

  /// The elevation of the bottom sheet
  final double? elevation;

  /// The shape of the bottom sheet
  final ShapeBorder? shape;

  /// The clip behavior of the bottom sheet
  final Clip? clipBehavior;

  /// The background color of the modal barrier
  final Color? modalBackgroundColor;

  /// The color of the modal barrier
  final Color? barrierColor;

  /// The color of the shadow below the sheet
  final Color? shadowColor;

  /// The surface tint color of the bottom sheet
  final Color? surfaceTintColor;

  /// Whether to show the drag handle
  final bool showDragHandle;

  /// The color of the drag handle
  final Color? dragHandleColor;

  /// The size of the drag handle
  final Size? dragHandleSize;

  /// The border radius of the bottom sheet
  final BorderRadius? borderRadius;

  /// Creates a shape based on the border radius
  ShapeBorder? get effectiveShape {
    if (shape != null) return shape;
    if (borderRadius != null) {
      return RoundedRectangleBorder(
        borderRadius: borderRadius!,
      );
    }
    return null;
  }
}

/// Shows a resizable bottom sheet with enhanced customization options.
///
/// This component provides a flexible UI element for displaying additional content
/// without navigating away from the current screen.
Future<T?> showResizableBottomSheet<T>({
  /// The context in which the bottom sheet will be shown.
  required BuildContext context,

  /// The child of the bottom sheet.
  required Widget child,

  /// Whether to use bottom padding 80.0.
  bool useBottomPadding = true,

  /// The minimum height of the bottom sheet.
  double? minHeight,

  /// The minimum width of the bottom sheet.
  double? minWidth,

  /// The maximum height of the bottom sheet.
  double? maxHeight,

  /// The maximum width of the bottom sheet.
  double? maxWidth,

  /// Whether to enable keyboard avoidance
  bool enableKeyboardAvoidance = false,

  /// Whether to use safe area
  bool useSafeArea = true,

  /// Whether the bottom sheet is dismissible by tapping outside
  bool isDismissible = true,

  /// Whether to enable drag to dismiss
  bool enableDrag = true,

  /// Appearance configuration for the bottom sheet
  BottomSheetAppearance? appearance,

  /// Callback when the bottom sheet is closed
  VoidCallback? onClosed,

  /// Snap points for the bottom sheet (fractions of available height)
  List<double>? snapPoints,
}) {
  final bottomSheetAppearance = appearance ?? const BottomSheetAppearance();

  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: useSafeArea,
    showDragHandle: bottomSheetAppearance.showDragHandle,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: bottomSheetAppearance.backgroundColor,
    elevation: bottomSheetAppearance.elevation,
    shape: bottomSheetAppearance.effectiveShape,
    clipBehavior: bottomSheetAppearance.clipBehavior,
    barrierColor: bottomSheetAppearance.barrierColor,
    builder: (BuildContext context) {
      // Get the keyboard height if keyboard avoidance is enabled
      final keyboardHeight = enableKeyboardAvoidance
          ? MediaQuery.of(context).viewInsets.bottom
          : 0.0;

      // Calculate bottom padding
      final bottomPadding = useBottomPadding ? 80.0 : 0.0;

      // If snap points are provided, use DraggableScrollableSheet
      if (snapPoints != null && snapPoints.isNotEmpty) {
        return DraggableScrollableSheet(
          initialChildSize: snapPoints.first,
          minChildSize: snapPoints.reduce((a, b) => a < b ? a : b),
          maxChildSize: snapPoints.reduce((a, b) => a > b ? a : b),
          snap: true,
          snapSizes: snapPoints,
          builder: (context, scrollController) {
            return Container(
              constraints: BoxConstraints(
                minWidth: minWidth ?? 0,
                maxWidth: maxWidth ?? double.infinity,
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: bottomPadding + keyboardHeight,
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
      }

      // Otherwise use regular container
      return Container(
        constraints: BoxConstraints(
          minHeight: minHeight ?? 0,
          minWidth: minWidth ?? 0,
          maxHeight: maxHeight ?? double.infinity,
          maxWidth: maxWidth ?? double.infinity,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: bottomPadding + keyboardHeight,
            ),
            child: child,
          ),
        ),
      );
    },
  ).then((value) {
    // Call onClosed callback if provided
    onClosed?.call();
    return value;
  });
}
