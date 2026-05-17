import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'app_button.dart';

@widgetbook.UseCase(
  name: 'Variants',
  type: AppButton,
)
Widget variantsUseCase(BuildContext context) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 16.0,
    children: [
      AppButton.primary(label: 'Primary', onPressed: () {}),
      AppButton.secondary(label: 'Secondary', onPressed: () {}),
      AppButton.danger(label: 'Danger', onPressed: () {}),
      AppButton.outline(label: 'Outline', onPressed: () {}),
      AppButton.ghost(label: 'Ghost', onPressed: () {}),
    ],
  );
}

@widgetbook.UseCase(
  name: 'Sizes',
  type: AppButton,
)
Widget sizesUseCase(BuildContext context) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 16.0,
    children: [
      AppButton.primary(label: 'Large', size: AppButtonSize.large, onPressed: () {}),
      AppButton.primary(label: 'Medium', size: AppButtonSize.medium, onPressed: () {}),
      AppButton.primary(label: 'Small', size: AppButtonSize.small, onPressed: () {}),
    ],
  );
}

@widgetbook.UseCase(
  name: 'States',
  type: AppButton,
)
Widget statesUseCase(BuildContext context) {
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    spacing: 16.0,
    children: [
      AppButton.primary(label: 'Loading', isLoading: true, onPressed: () {}),
      const AppButton.primary(label: 'Disabled', onPressed: null),
    ],
  );
}
