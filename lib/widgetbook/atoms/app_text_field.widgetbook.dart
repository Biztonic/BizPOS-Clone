import 'package:flutter/material.dart';
import 'package:biztonic_pos/core/design/tokens/app_spacing.dart';

import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import '../../../core/design/components/atoms/app_text_field.dart';

@widgetbook.UseCase(
  name: 'Variants',
  type: AppTextField,
)
Widget appTextFieldVariantsUseCase(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(AppSpacing.md),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppTextField(
          labelText: 'Outlined Variant',
          hintText: 'Enter text here',
          variant: AppTextFieldVariant.outlined,
        ),
        SizedBox(height: AppSpacing.md),
        AppTextField(
          labelText: 'Filled Variant',
          hintText: 'Enter text here',
          variant: AppTextFieldVariant.filled,
        ),
        SizedBox(height: AppSpacing.md),
        AppTextField(
          labelText: 'Underlined Variant',
          hintText: 'Enter text here',
          variant: AppTextFieldVariant.underlined,
        ),
      ],
    ),
  );
}

@widgetbook.UseCase(
  name: 'Sizes',
  type: AppTextField,
)
Widget appTextFieldSizesUseCase(BuildContext context) {
  return const Padding(
    padding: EdgeInsets.all(AppSpacing.md),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AppTextField(
          labelText: 'Small Size',
          size: AppTextFieldSize.small,
        ),
        SizedBox(height: AppSpacing.md),
        AppTextField(
          labelText: 'Medium Size',
          size: AppTextFieldSize.medium,
        ),
        SizedBox(height: AppSpacing.md),
        AppTextField(
          labelText: 'Large Size',
          size: AppTextFieldSize.large,
        ),
      ],
    ),
  );
}
